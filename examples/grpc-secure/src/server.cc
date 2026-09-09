#include "hardening.h"

#include <grpc/grpc.h>
#include <grpcpp/grpcpp.h>

#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <set>
#include <stdexcept>
#include <string>
#include <utility>

#include <pthread.h>

#include "helloworld.grpc.pb.h"

namespace {

using ava::grpc_secure::InFlightLease;
using ava::grpc_secure::InFlightLimiter;
using ava::grpc_secure::ServerConfig;
using ava::grpc_secure::TokenBucketRateLimiter;

std::string JsonEscape(const std::string& value) {
	std::string escaped;
	escaped.reserve(value.size());
	for (const char raw_character : value) {
		const unsigned char character = static_cast<unsigned char>(raw_character);
		switch (character) {
			case '\\':
				escaped += "\\\\";
				break;
			case '"':
				escaped += "\\\"";
				break;
			case '\n':
				escaped += "\\n";
				break;
			case '\r':
				escaped += "\\r";
				break;
			case '\t':
				escaped += "\\t";
				break;
			default:
				if (character >= 0x20U) {
					escaped += static_cast<char>(character);
				}
				break;
		}
	}
	return escaped;
}

void LogEvent(const char* level, const char* event, const std::string& detail = {}) {
	std::cerr << "{\"level\":\"" << level << "\",\"event\":\"" << event << '"';
	if (!detail.empty()) {
		std::cerr << ",\"detail\":\"" << JsonEscape(detail) << '"';
	}
	std::cerr << "}\n";
}

void LogServerStarted(const std::string& configured_address, int selected_port) {
	std::cerr << "{\"level\":\"INFO\",\"event\":\"server_started\",\"address\":\""
			  << JsonEscape(configured_address) << "\",\"port\":" << selected_port << "}\n";
}

sigset_t BlockShutdownSignals() {
	sigset_t signals {};
	if (sigemptyset(&signals) != 0 || sigaddset(&signals, SIGINT) != 0 ||
		sigaddset(&signals, SIGTERM) != 0) {
		throw std::runtime_error("failed to initialize the POSIX signal set");
	}
	const int result = pthread_sigmask(SIG_BLOCK, &signals, nullptr);
	if (result != 0) {
		throw std::runtime_error(
			std::string("failed to block shutdown signals: ") + std::strerror(result));
	}
	return signals;
}

enum class AuthorizationState {
	authorized,
	unauthenticated,
	forbidden,
};

struct AuthorizationDecision {
	AuthorizationState state;
	std::string identity;
};

AuthorizationDecision AuthorizePeer(
	grpc::ServerContext* context, const std::set<std::string>& allowed_identities) {
	const auto authentication = context->auth_context();
	if (!authentication || !authentication->IsPeerAuthenticated()) {
		return {AuthorizationState::unauthenticated, {}};
	}

	for (const grpc::string_ref& peer_identity : authentication->GetPeerIdentity()) {
		const std::string identity(peer_identity.data(), peer_identity.size());
		if (allowed_identities.find(identity) != allowed_identities.end()) {
			return {AuthorizationState::authorized, identity};
		}
	}
	return {AuthorizationState::forbidden, {}};
}

class GreeterService final : public helloworld::Greeter::Service {
 public:
	explicit GreeterService(const ServerConfig& config)
		: allowed_identities_(config.allowed_identities),
		  rate_limiter_(
			  config.allowed_identities, config.rate_per_second, config.rate_burst),
		  in_flight_limiter_(config.max_concurrent_rpcs) {}

	grpc::Status SayHello(grpc::ServerContext* context,
						  const helloworld::HelloRequest* request,
						  helloworld::HelloReply* reply) override {
		if (!in_flight_limiter_.TryAcquire()) {
			return {grpc::StatusCode::RESOURCE_EXHAUSTED, "server concurrency limit reached"};
		}
		InFlightLease lease(&in_flight_limiter_);

		const AuthorizationDecision authorization = AuthorizePeer(context, allowed_identities_);
		if (authorization.state == AuthorizationState::unauthenticated) {
			return {grpc::StatusCode::UNAUTHENTICATED, "authenticated client certificate required"};
		}
		if (authorization.state == AuthorizationState::forbidden) {
			return {grpc::StatusCode::PERMISSION_DENIED, "client certificate identity is not allowed"};
		}
		if (!rate_limiter_.Allow(authorization.identity)) {
			context->AddTrailingMetadata("retry-after-ms", "1000");
			return {grpc::StatusCode::RESOURCE_EXHAUSTED, "per-identity rate limit exceeded"};
		}
		if (!ava::grpc_secure::IsValidName(request->name())) {
			return {grpc::StatusCode::INVALID_ARGUMENT,
					"name must contain 1-128 bytes and no control characters"};
		}

		reply->set_message("Hello " + request->name());
		return grpc::Status::OK;
	}

 private:
	const std::set<std::string> allowed_identities_;
	TokenBucketRateLimiter rate_limiter_;
	InFlightLimiter in_flight_limiter_;
};

std::shared_ptr<grpc::ServerCredentials> BuildMutualTlsCredentials(
	const ServerConfig& config) {
	grpc::SslServerCredentialsOptions::PemKeyCertPair key_and_certificate;
	key_and_certificate.private_key =
		ava::grpc_secure::ReadRequiredFile(config.server_private_key_path);
	key_and_certificate.cert_chain =
		ava::grpc_secure::ReadRequiredFile(config.server_certificate_path);

	grpc::SslServerCredentialsOptions options(
		GRPC_SSL_REQUEST_AND_REQUIRE_CLIENT_CERTIFICATE_AND_VERIFY);
	options.pem_root_certs = ava::grpc_secure::ReadRequiredFile(config.client_ca_path);
	options.pem_key_cert_pairs.push_back(std::move(key_and_certificate));
	return grpc::SslServerCredentials(options);
}

int RunServer() {
	const sigset_t shutdown_signals = BlockShutdownSignals();
	const ServerConfig config = ava::grpc_secure::LoadServerConfigFromEnvironment();
	const std::shared_ptr<grpc::ServerCredentials> credentials =
		BuildMutualTlsCredentials(config);
	if (!credentials) {
		throw std::runtime_error("gRPC could not create mTLS server credentials");
	}

	GreeterService service(config);
	grpc::ResourceQuota resource_quota("ava-secure-greeter");
	resource_quota.Resize(config.resource_quota_bytes).SetMaxThreads(config.max_threads);

	grpc::ServerBuilder builder;
	int selected_port = 0;
	builder.AddListeningPort(config.bind_address, credentials, &selected_port);
	builder.RegisterService(&service);
	builder.SetResourceQuota(resource_quota);
	builder.SetMaxReceiveMessageSize(config.max_message_bytes);
	builder.SetMaxSendMessageSize(config.max_message_bytes);
	builder.SetSyncServerOption(grpc::ServerBuilder::MIN_POLLERS, 1);
	builder.SetSyncServerOption(grpc::ServerBuilder::MAX_POLLERS, 4);

	// Conservative connection defaults. Coordinate changes with clients and proxies.
	builder.AddChannelArgument(GRPC_ARG_KEEPALIVE_TIME_MS, 120000);
	builder.AddChannelArgument(GRPC_ARG_KEEPALIVE_TIMEOUT_MS, 20000);
	builder.AddChannelArgument(GRPC_ARG_KEEPALIVE_PERMIT_WITHOUT_CALLS, 0);
	builder.AddChannelArgument(
		GRPC_ARG_HTTP2_MIN_RECV_PING_INTERVAL_WITHOUT_DATA_MS, 300000);
	builder.AddChannelArgument(GRPC_ARG_HTTP2_MAX_PING_STRIKES, 2);
	builder.AddChannelArgument(GRPC_ARG_MAX_CONNECTION_IDLE_MS, 600000);
	builder.AddChannelArgument(GRPC_ARG_MAX_CONNECTION_AGE_MS, 3600000);
	builder.AddChannelArgument(GRPC_ARG_MAX_CONNECTION_AGE_GRACE_MS, 30000);
	builder.AddChannelArgument(GRPC_ARG_SERVER_HANDSHAKE_TIMEOUT_MS, 10000);
	builder.AddChannelArgument(GRPC_ARG_MAX_CONCURRENT_STREAMS, config.max_concurrent_streams);
	builder.AddChannelArgument(GRPC_ARG_MAX_METADATA_SIZE, 8192);
#ifdef GRPC_ARG_ABSOLUTE_MAX_METADATA_SIZE
	builder.AddChannelArgument(GRPC_ARG_ABSOLUTE_MAX_METADATA_SIZE, 16384);
#endif
	builder.AddChannelArgument(GRPC_ARG_ALLOW_REUSEPORT, 0);

	std::unique_ptr<grpc::Server> server = builder.BuildAndStart();
	if (!server || selected_port == 0) {
		throw std::runtime_error("gRPC server failed to bind or start");
	}
	LogServerStarted(config.bind_address, selected_port);

	int received_signal = 0;
	const int wait_result = sigwait(&shutdown_signals, &received_signal);
	if (wait_result != 0) {
		LogEvent("ERROR", "signal_wait_failed", std::strerror(wait_result));
		server->Shutdown(
			std::chrono::system_clock::now() +
			std::chrono::seconds(config.shutdown_grace_seconds));
		server->Wait();
		return EXIT_FAILURE;
	}

	LogEvent("INFO", "shutdown_started", std::to_string(received_signal));
	server->Shutdown(
		std::chrono::system_clock::now() +
		std::chrono::seconds(config.shutdown_grace_seconds));
	server->Wait();
	LogEvent("INFO", "shutdown_complete");
	return EXIT_SUCCESS;
}

}  // namespace

int main() {
	try {
		return RunServer();
	} catch (const std::exception& error) {
		LogEvent("ERROR", "startup_failed", error.what());
		return EXIT_FAILURE;
	}
}
