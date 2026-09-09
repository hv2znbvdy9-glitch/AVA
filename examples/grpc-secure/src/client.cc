#include "hardening.h"

#include <grpcpp/grpcpp.h>

#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>

#include "helloworld.grpc.pb.h"

namespace {

struct ClientConfig {
	std::string target;
	std::filesystem::path client_certificate_path;
	std::filesystem::path client_private_key_path;
	std::filesystem::path server_ca_path;
};

ClientConfig LoadClientConfig() {
	ClientConfig config {
		ava::grpc_secure::GetOptionalEnvironmentValue("AVA_GRPC_TARGET", "127.0.0.1:50051"),
		ava::grpc_secure::GetRequiredEnvironmentValue("AVA_GRPC_CLIENT_CERT"),
		ava::grpc_secure::GetRequiredEnvironmentValue("AVA_GRPC_CLIENT_KEY"),
		ava::grpc_secure::GetRequiredEnvironmentValue("AVA_GRPC_SERVER_CA"),
	};
	ava::grpc_secure::ValidateBindAddress(config.target, false);
	ava::grpc_secure::ValidatePrivateKeyPermissions(config.client_private_key_path);
	return config;
}

int RunClient(const std::string& name) {
	if (!ava::grpc_secure::IsValidName(name)) {
		throw std::runtime_error("name must contain 1-128 bytes and no control characters");
	}
	const ClientConfig config = LoadClientConfig();

	grpc::SslCredentialsOptions tls;
	tls.pem_root_certs = ava::grpc_secure::ReadRequiredFile(config.server_ca_path);
	tls.pem_private_key = ava::grpc_secure::ReadRequiredFile(config.client_private_key_path);
	tls.pem_cert_chain = ava::grpc_secure::ReadRequiredFile(config.client_certificate_path);

	grpc::ChannelArguments channel_arguments;
	channel_arguments.SetMaxReceiveMessageSize(4 * 1024 * 1024);
	channel_arguments.SetMaxSendMessageSize(4 * 1024 * 1024);
	const std::shared_ptr<grpc::Channel> channel = grpc::CreateCustomChannel(
		config.target, grpc::SslCredentials(tls), channel_arguments);
	if (!channel->WaitForConnected(
			std::chrono::system_clock::now() + std::chrono::seconds(5))) {
		std::cerr << "connection failed before deadline\n";
		return 2;
	}

	std::unique_ptr<helloworld::Greeter::Stub> client = helloworld::Greeter::NewStub(channel);
	helloworld::HelloRequest request;
	request.set_name(name);
	helloworld::HelloReply reply;
	grpc::ClientContext context;
	context.set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(3));

	const grpc::Status status = client->SayHello(&context, request, &reply);
	if (!status.ok()) {
		std::cerr << "rpc failed (code " << static_cast<int>(status.error_code())
				  << "): " << status.error_message() << '\n';
		return 3;
	}

	std::cout << reply.message() << '\n';
	return EXIT_SUCCESS;
}

}  // namespace

int main(int argc, char* argv[]) {
	if (argc > 2) {
		std::cerr << "usage: ava_secure_greeter_client [name]\n";
		return EXIT_FAILURE;
	}
	try {
		return RunClient(argc == 2 ? argv[1] : "AVA");
	} catch (const std::exception& error) {
		std::cerr << "client configuration error: " << error.what() << '\n';
		return EXIT_FAILURE;
	}
}
