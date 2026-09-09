#ifndef AVA_GRPC_SECURE_HARDENING_H_
#define AVA_GRPC_SECURE_HARDENING_H_

#include <atomic>
#include <chrono>
#include <cstddef>
#include <filesystem>
#include <map>
#include <mutex>
#include <set>
#include <string>

namespace ava::grpc_secure {

struct ServerConfig {
	std::string bind_address;
	std::filesystem::path server_certificate_path;
	std::filesystem::path server_private_key_path;
	std::filesystem::path client_ca_path;
	std::set<std::string> allowed_identities;
	int max_message_bytes;
	std::size_t resource_quota_bytes;
	int max_threads;
	int max_concurrent_streams;
	int max_concurrent_rpcs;
	int rate_per_second;
	int rate_burst;
	int shutdown_grace_seconds;
};

ServerConfig LoadServerConfigFromEnvironment();

std::string GetRequiredEnvironmentValue(const char* name);
std::string GetOptionalEnvironmentValue(const char* name,
										const std::string& fallback);
bool ParseBoolean(const std::string& value, const std::string& field_name);
int ParseBoundedInteger(const std::string& value,
						const std::string& field_name,
						int minimum,
						int maximum);
std::set<std::string> ParseIdentityAllowlist(const std::string& value);
void ValidateBindAddress(const std::string& address, bool allow_wildcard);
std::string ReadRequiredFile(const std::filesystem::path& path,
							 std::size_t maximum_bytes = 1024U * 1024U);
void ValidatePrivateKeyPermissions(const std::filesystem::path& path);
bool IsValidName(const std::string& name);

class TokenBucketRateLimiter final {
 public:
	using Clock = std::chrono::steady_clock;

	TokenBucketRateLimiter(const std::set<std::string>& identities,
						   int rate_per_second,
						   int burst);

	bool Allow(const std::string& identity);
	bool AllowAt(const std::string& identity, Clock::time_point now);

 private:
	struct Bucket {
		double tokens;
		Clock::time_point last_refill;
	};

	const double rate_per_second_;
	const double burst_;
	std::map<std::string, Bucket> buckets_;
	std::mutex mutex_;
};

class InFlightLimiter final {
 public:
	explicit InFlightLimiter(int maximum);

	bool TryAcquire();
	void Release();
	int active() const;

 private:
	const int maximum_;
	std::atomic<int> active_{0};
};

class InFlightLease final {
 public:
	explicit InFlightLease(InFlightLimiter* limiter);
	~InFlightLease();

	InFlightLease(const InFlightLease&) = delete;
	InFlightLease& operator=(const InFlightLease&) = delete;

 private:
	InFlightLimiter* limiter_;
};

}  // namespace ava::grpc_secure

#endif  // AVA_GRPC_SECURE_HARDENING_H_
