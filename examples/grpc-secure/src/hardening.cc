#include "hardening.h"

#include <algorithm>
#include <cctype>
#include <charconv>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <memory>
#include <stdexcept>
#include <system_error>

#if defined(__unix__) || defined(__APPLE__)
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/stat.h>
#endif

namespace ava::grpc_secure {
namespace {

constexpr int kMinimumMessageBytes = 1024;
constexpr int kMaximumMessageBytes = 64 * 1024 * 1024;
constexpr int kMinimumQuotaBytes = 1024 * 1024;
constexpr int kMaximumQuotaBytes = 1024 * 1024 * 1024;
constexpr std::size_t kMaximumIdentities = 64U;
constexpr std::size_t kMaximumIdentityBytes = 512U;

std::string Trim(const std::string& value) {
	auto first = std::find_if_not(value.begin(), value.end(), [](unsigned char character) {
		return std::isspace(character) != 0;
	});
	auto last = std::find_if_not(value.rbegin(), value.rend(), [](unsigned char character) {
		return std::isspace(character) != 0;
	}).base();

	if (first >= last) {
		return {};
	}
	return std::string(first, last);
}

std::string ToLowerAscii(std::string value) {
	std::transform(value.begin(), value.end(), value.begin(), [](unsigned char character) {
		return static_cast<char>(std::tolower(character));
	});
	return value;
}

bool HasWhitespaceOrControlCharacter(const std::string& value) {
	return std::any_of(value.begin(), value.end(), [](unsigned char character) {
		return std::isspace(character) != 0 || std::iscntrl(character) != 0;
	});
}

bool IsIpv6WildcardOrMappedAny(const struct in6_addr& address) {
	if (IN6_IS_ADDR_UNSPECIFIED(&address)) {
		return true;
	}
	return IN6_IS_ADDR_V4MAPPED(&address) && address.s6_addr[12] == 0U &&
		address.s6_addr[13] == 0U && address.s6_addr[14] == 0U &&
		address.s6_addr[15] == 0U;
}

bool IsWildcardHost(const std::string& host) {
	if (host == "*") {
		return true;
	}
#if defined(__unix__) || defined(__APPLE__)
	struct in_addr ipv4 {};
	if (inet_pton(AF_INET, host.c_str(), &ipv4) == 1 && ipv4.s_addr == htonl(INADDR_ANY)) {
		return true;
	}
	struct in6_addr ipv6 {};
	if (inet_pton(AF_INET6, host.c_str(), &ipv6) == 1 && IsIpv6WildcardOrMappedAny(ipv6)) {
		return true;
	}

	// The resolver accepts legacy numeric forms such as "0" and "0x0" that
	// inet_pton() intentionally rejects. Resolve once during validation so those
	// forms and hostnames resolving to an unspecified address fail closed.
	struct addrinfo hints {};
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	struct addrinfo* raw_results = nullptr;
	const int resolve_result = getaddrinfo(host.c_str(), nullptr, &hints, &raw_results);
	if (resolve_result != 0) {
		throw std::runtime_error(
			"AVA_GRPC_BIND_ADDRESS host cannot be resolved: " +
			std::string(gai_strerror(resolve_result)));
	}
	const std::unique_ptr<struct addrinfo, decltype(&freeaddrinfo)> results(
		raw_results, freeaddrinfo);
	for (const struct addrinfo* entry = results.get(); entry != nullptr; entry = entry->ai_next) {
		if (entry->ai_family == AF_INET) {
			const auto* address = reinterpret_cast<const struct sockaddr_in*>(entry->ai_addr);
			if (address->sin_addr.s_addr == htonl(INADDR_ANY)) {
				return true;
			}
		} else if (entry->ai_family == AF_INET6) {
			const auto* address = reinterpret_cast<const struct sockaddr_in6*>(entry->ai_addr);
			if (IsIpv6WildcardOrMappedAny(address->sin6_addr)) {
				return true;
			}
		}
	}
#else
	if (host == "0" || host == "0x0" || host == "0.0.0.0" || host == "::" ||
		host == "0:0:0:0:0:0:0:0" || host == "::ffff:0.0.0.0") {
		return true;
	}
#endif
	return false;
}

}  // namespace

std::string GetRequiredEnvironmentValue(const char* name) {
	const char* value = std::getenv(name);
	if (value == nullptr || value[0] == '\0') {
		throw std::runtime_error(std::string("required environment variable is missing: ") + name);
	}
	return value;
}

std::string GetOptionalEnvironmentValue(const char* name, const std::string& fallback) {
	const char* value = std::getenv(name);
	if (value == nullptr || value[0] == '\0') {
		return fallback;
	}
	return value;
}

bool ParseBoolean(const std::string& value, const std::string& field_name) {
	const std::string normalized = ToLowerAscii(Trim(value));
	if (normalized == "true" || normalized == "1") {
		return true;
	}
	if (normalized == "false" || normalized == "0") {
		return false;
	}
	throw std::runtime_error(field_name + " must be true, false, 1, or 0");
}

int ParseBoundedInteger(const std::string& value,
						const std::string& field_name,
						int minimum,
						int maximum) {
	if (minimum > maximum) {
		throw std::logic_error("invalid numeric bounds");
	}

	const std::string normalized = Trim(value);
	int parsed = 0;
	const auto result = std::from_chars(
		normalized.data(), normalized.data() + normalized.size(), parsed);
	if (result.ec != std::errc{} || result.ptr != normalized.data() + normalized.size()) {
		throw std::runtime_error(field_name + " must be a base-10 integer");
	}
	if (parsed < minimum || parsed > maximum) {
		throw std::runtime_error(field_name + " is outside the permitted range");
	}
	return parsed;
}

std::set<std::string> ParseIdentityAllowlist(const std::string& value) {
	std::set<std::string> identities;
	std::size_t start = 0U;

	while (start <= value.size()) {
		const std::size_t separator = value.find(',', start);
		const std::size_t end = separator == std::string::npos ? value.size() : separator;
		const std::string identity = Trim(value.substr(start, end - start));
		if (identity.empty()) {
			throw std::runtime_error("AVA_GRPC_ALLOWED_IDENTITIES contains an empty entry");
		}
		if (identity.size() > kMaximumIdentityBytes || HasWhitespaceOrControlCharacter(identity)) {
			throw std::runtime_error(
				"AVA_GRPC_ALLOWED_IDENTITIES contains an invalid identity");
		}
		identities.insert(identity);
		if (identities.size() > kMaximumIdentities) {
			throw std::runtime_error("AVA_GRPC_ALLOWED_IDENTITIES contains too many entries");
		}

		if (separator == std::string::npos) {
			break;
		}
		start = separator + 1U;
	}

	if (identities.empty()) {
		throw std::runtime_error("AVA_GRPC_ALLOWED_IDENTITIES must not be empty");
	}
	return identities;
}

void ValidateBindAddress(const std::string& address, bool allow_wildcard) {
	if (address.empty() || address.size() > 255U || HasWhitespaceOrControlCharacter(address)) {
		throw std::runtime_error("AVA_GRPC_BIND_ADDRESS is empty or malformed");
	}

	std::string endpoint = address;
	constexpr char kDnsPrefix[] = "dns:///";
	if (endpoint.rfind(kDnsPrefix, 0U) == 0U) {
		endpoint.erase(0U, sizeof(kDnsPrefix) - 1U);
	}

	std::string host;
	std::string port;
	if (!endpoint.empty() && endpoint.front() == '[') {
		const std::size_t closing_bracket = endpoint.find(']');
		if (closing_bracket == std::string::npos || closing_bracket + 1U >= endpoint.size() ||
			endpoint[closing_bracket + 1U] != ':') {
			throw std::runtime_error("AVA_GRPC_BIND_ADDRESS has invalid bracketed IPv6 syntax");
		}
		host = endpoint.substr(1U, closing_bracket - 1U);
		port = endpoint.substr(closing_bracket + 2U);
	} else {
		const std::size_t separator = endpoint.rfind(':');
		if (separator == std::string::npos || endpoint.find(':') != separator) {
			throw std::runtime_error(
				"AVA_GRPC_BIND_ADDRESS must use host:port or [IPv6]:port syntax");
		}
		host = endpoint.substr(0U, separator);
		port = endpoint.substr(separator + 1U);
	}

	if (host.empty()) {
		throw std::runtime_error("AVA_GRPC_BIND_ADDRESS must name an explicit interface");
	}
	static_cast<void>(ParseBoundedInteger(port, "AVA_GRPC_BIND_ADDRESS port", 0, 65535));

	const bool wildcard = IsWildcardHost(ToLowerAscii(host));
	if (wildcard && !allow_wildcard) {
		throw std::runtime_error(
			"wildcard binding is disabled; set AVA_GRPC_ALLOW_WILDCARD_BIND=true only after network controls are verified");
	}
}

std::string ReadRequiredFile(const std::filesystem::path& path, std::size_t maximum_bytes) {
	if (maximum_bytes == 0U) {
		throw std::logic_error("maximum file size must be positive");
	}

	std::error_code error;
	if (!std::filesystem::is_regular_file(path, error) || error) {
		throw std::runtime_error("required file is missing or not a regular file: " + path.string());
	}
	const std::uintmax_t size = std::filesystem::file_size(path, error);
	if (error || size == 0U || size > maximum_bytes) {
		throw std::runtime_error("required file is empty, unreadable, or too large: " + path.string());
	}

	std::ifstream stream(path, std::ios::binary);
	if (!stream) {
		throw std::runtime_error("required file cannot be opened: " + path.string());
	}

	std::string content(static_cast<std::size_t>(size), '\0');
	stream.read(content.data(), static_cast<std::streamsize>(content.size()));
	if (!stream || static_cast<std::size_t>(stream.gcount()) != content.size()) {
		throw std::runtime_error("required file could not be read completely: " + path.string());
	}
	return content;
}

void ValidatePrivateKeyPermissions(const std::filesystem::path& path) {
#if defined(__unix__) || defined(__APPLE__)
	struct stat details {};
	if (stat(path.c_str(), &details) != 0) {
		throw std::runtime_error("cannot inspect private-key permissions: " + path.string());
	}
	if ((details.st_mode & (S_IRWXG | S_IRWXO)) != 0) {
		throw std::runtime_error(
			"private key must not grant group or other permissions (use mode 0600 or stricter): " +
			path.string());
	}
#else
	static_cast<void>(path);
#endif
}

bool IsValidName(const std::string& name) {
	if (name.empty() || name.size() > 128U) {
		return false;
	}
	return std::none_of(name.begin(), name.end(), [](unsigned char character) {
		return character < 0x20U || character == 0x7fU;
	});
}

ServerConfig LoadServerConfigFromEnvironment() {
	const bool allow_wildcard = ParseBoolean(
		GetOptionalEnvironmentValue("AVA_GRPC_ALLOW_WILDCARD_BIND", "false"),
		"AVA_GRPC_ALLOW_WILDCARD_BIND");
	ServerConfig config {
		GetOptionalEnvironmentValue("AVA_GRPC_BIND_ADDRESS", "127.0.0.1:50051"),
		GetRequiredEnvironmentValue("AVA_GRPC_SERVER_CERT"),
		GetRequiredEnvironmentValue("AVA_GRPC_SERVER_KEY"),
		GetRequiredEnvironmentValue("AVA_GRPC_CLIENT_CA"),
		ParseIdentityAllowlist(GetRequiredEnvironmentValue("AVA_GRPC_ALLOWED_IDENTITIES")),
		ParseBoundedInteger(
			GetOptionalEnvironmentValue("AVA_GRPC_MAX_MESSAGE_BYTES", "4194304"),
			"AVA_GRPC_MAX_MESSAGE_BYTES",
			kMinimumMessageBytes,
			kMaximumMessageBytes),
		static_cast<std::size_t>(ParseBoundedInteger(
			GetOptionalEnvironmentValue("AVA_GRPC_RESOURCE_QUOTA_BYTES", "67108864"),
			"AVA_GRPC_RESOURCE_QUOTA_BYTES",
			kMinimumQuotaBytes,
			kMaximumQuotaBytes)),
		ParseBoundedInteger(
			GetOptionalEnvironmentValue("AVA_GRPC_MAX_THREADS", "64"),
			"AVA_GRPC_MAX_THREADS",
			2,
			256),
		ParseBoundedInteger(
			GetOptionalEnvironmentValue("AVA_GRPC_MAX_CONCURRENT_STREAMS", "128"),
			"AVA_GRPC_MAX_CONCURRENT_STREAMS",
			1,
			4096),
		ParseBoundedInteger(
			GetOptionalEnvironmentValue("AVA_GRPC_MAX_CONCURRENT_RPCS", "128"),
			"AVA_GRPC_MAX_CONCURRENT_RPCS",
			1,
			4096),
		ParseBoundedInteger(
			GetOptionalEnvironmentValue("AVA_GRPC_RATE_PER_SECOND", "20"),
			"AVA_GRPC_RATE_PER_SECOND",
			1,
			100000),
		ParseBoundedInteger(
			GetOptionalEnvironmentValue("AVA_GRPC_RATE_BURST", "40"),
			"AVA_GRPC_RATE_BURST",
			1,
			100000),
		ParseBoundedInteger(
			GetOptionalEnvironmentValue("AVA_GRPC_SHUTDOWN_GRACE_SECONDS", "10"),
			"AVA_GRPC_SHUTDOWN_GRACE_SECONDS",
			1,
			300),
	};

	ValidateBindAddress(config.bind_address, allow_wildcard);
	ValidatePrivateKeyPermissions(config.server_private_key_path);
	return config;
}

TokenBucketRateLimiter::TokenBucketRateLimiter(const std::set<std::string>& identities,
										   int rate_per_second,
										   int burst)
	: rate_per_second_(rate_per_second), burst_(burst) {
	if (identities.empty() || rate_per_second <= 0 || burst <= 0) {
		throw std::invalid_argument("rate limiter requires identities and positive limits");
	}
	const Clock::time_point now = Clock::now();
	for (const std::string& identity : identities) {
		buckets_.emplace(identity, Bucket {burst_, now});
	}
}

bool TokenBucketRateLimiter::Allow(const std::string& identity) {
	return AllowAt(identity, Clock::now());
}

bool TokenBucketRateLimiter::AllowAt(const std::string& identity, Clock::time_point now) {
	std::lock_guard<std::mutex> lock(mutex_);
	const auto found = buckets_.find(identity);
	if (found == buckets_.end()) {
		return false;
	}

	Bucket& bucket = found->second;
	if (now > bucket.last_refill) {
		const double elapsed_seconds =
			std::chrono::duration<double>(now - bucket.last_refill).count();
		bucket.tokens = std::min(burst_, bucket.tokens + elapsed_seconds * rate_per_second_);
		bucket.last_refill = now;
	}
	if (bucket.tokens < 1.0) {
		return false;
	}
	bucket.tokens -= 1.0;
	return true;
}

InFlightLimiter::InFlightLimiter(int maximum) : maximum_(maximum) {
	if (maximum <= 0) {
		throw std::invalid_argument("in-flight limit must be positive");
	}
}

bool InFlightLimiter::TryAcquire() {
	int current = active_.load(std::memory_order_relaxed);
	while (current < maximum_) {
		if (active_.compare_exchange_weak(
				current, current + 1, std::memory_order_acquire, std::memory_order_relaxed)) {
			return true;
		}
	}
	return false;
}

void InFlightLimiter::Release() {
	int current = active_.load(std::memory_order_relaxed);
	while (current > 0) {
		if (active_.compare_exchange_weak(
				current, current - 1, std::memory_order_release, std::memory_order_relaxed)) {
			return;
		}
	}
}

int InFlightLimiter::active() const {
	return active_.load(std::memory_order_relaxed);
}

InFlightLease::InFlightLease(InFlightLimiter* limiter) : limiter_(limiter) {
	if (limiter_ == nullptr) {
		throw std::invalid_argument("in-flight lease requires a limiter");
	}
}

InFlightLease::~InFlightLease() {
	limiter_->Release();
}

}  // namespace ava::grpc_secure
