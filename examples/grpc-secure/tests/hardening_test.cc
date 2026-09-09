#include "hardening.h"

#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <set>
#include <stdexcept>
#include <string>

#if defined(__unix__) || defined(__APPLE__)
#include <sys/stat.h>
#include <unistd.h>
#endif

namespace {

void Check(bool condition, const std::string& message) {
	if (!condition) {
		throw std::runtime_error(message);
	}
}

void ExpectThrows(const std::function<void()>& operation, const std::string& message) {
	try {
		operation();
	} catch (const std::exception&) {
		return;
	}
	throw std::runtime_error(message);
}

void TestConfigurationParsers() {
	using ava::grpc_secure::ParseBoolean;
	using ava::grpc_secure::ParseBoundedInteger;
	using ava::grpc_secure::ParseIdentityAllowlist;

	Check(ParseBoolean(" true ", "flag"), "true should parse");
	Check(!ParseBoolean("0", "flag"), "zero should parse as false");
	ExpectThrows([] { static_cast<void>(ParseBoolean("yes", "flag")); },
				 "ambiguous booleans must be rejected");

	Check(ParseBoundedInteger(" 42 ", "number", 1, 100) == 42,
		  "bounded integer should parse");
	ExpectThrows([] { static_cast<void>(ParseBoundedInteger("42x", "number", 1, 100)); },
				 "trailing numeric content must be rejected");
	ExpectThrows([] { static_cast<void>(ParseBoundedInteger("101", "number", 1, 100)); },
				 "out-of-range integer must be rejected");

	const std::set<std::string> identities =
		ParseIdentityAllowlist("spiffe://ava.test/client,authorized.test,authorized.test");
	Check(identities.size() == 2U, "duplicate identities should collapse");
	Check(identities.count("spiffe://ava.test/client") == 1U,
		  "SPIFFE identity should be retained exactly");
	ExpectThrows([] { static_cast<void>(ParseIdentityAllowlist("one,,two")); },
				 "empty identity entries must be rejected");
	ExpectThrows([] { static_cast<void>(ParseIdentityAllowlist("contains whitespace")); },
				 "whitespace in an identity must be rejected");
}

void TestBindValidation() {
	using ava::grpc_secure::ValidateBindAddress;

	ValidateBindAddress("127.0.0.1:50051", false);
	ValidateBindAddress("10.0.0.5:50051", false);
	ValidateBindAddress("dns:///localhost:50051", false);
	ValidateBindAddress("[::1]:50051", false);
	ValidateBindAddress("localhost:0", false);
	ValidateBindAddress("0.0.0.0:50051", true);

	ExpectThrows([] { ValidateBindAddress("0.0.0.0:50051", false); },
				 "IPv4 wildcard must be rejected by default");
	ExpectThrows([] { ValidateBindAddress("dns:///[::]:50051", false); },
				 "IPv6 wildcard must be rejected by default");
	ExpectThrows([] { ValidateBindAddress("[0:0:0:0:0:0:0:0]:50051", false); },
				 "expanded IPv6 wildcard must be rejected by default");
	ExpectThrows([] { ValidateBindAddress("0:50051", false); },
				 "legacy numeric IPv4 wildcard must be rejected by default");
	ExpectThrows([] { ValidateBindAddress("0x0:50051", false); },
				 "hexadecimal IPv4 wildcard must be rejected by default");
	ExpectThrows([] { ValidateBindAddress("[::ffff:0.0.0.0]:50051", false); },
				 "IPv4-mapped wildcard must be rejected by default");
	ExpectThrows([] { ValidateBindAddress(":50051", false); },
				 "empty host must be rejected");
	ExpectThrows([] { ValidateBindAddress("localhost:not-a-port", false); },
				 "non-numeric port must be rejected");
}

void TestRequestValidation() {
	using ava::grpc_secure::IsValidName;

	Check(IsValidName("Danny"), "ordinary name should be accepted");
	Check(IsValidName("J\xC3\xB6rg"), "UTF-8 bytes should be accepted");
	Check(!IsValidName(""), "empty name must be rejected");
	Check(!IsValidName(std::string(129U, 'a')), "oversized name must be rejected");
	Check(!IsValidName("line\nbreak"), "control characters must be rejected");
}

void TestRateLimiter() {
	using ava::grpc_secure::TokenBucketRateLimiter;

	TokenBucketRateLimiter limiter({"authorized.test"}, 2, 2);
	const auto start = TokenBucketRateLimiter::Clock::now();
	Check(limiter.AllowAt("authorized.test", start), "first burst token should pass");
	Check(limiter.AllowAt("authorized.test", start), "second burst token should pass");
	Check(!limiter.AllowAt("authorized.test", start), "exhausted burst must be rejected");
	Check(limiter.AllowAt("authorized.test", start + std::chrono::milliseconds(500)),
		  "one token should refill after half a second");
	Check(!limiter.AllowAt("authorized.test", start + std::chrono::milliseconds(500)),
		  "refilled token must be consumed only once");
	Check(!limiter.AllowAt("unknown.test", start + std::chrono::seconds(10)),
		  "unknown identity must never create a bucket");
}

void TestInFlightLimiter() {
	ava::grpc_secure::InFlightLimiter limiter(2);
	Check(limiter.TryAcquire(), "first lease should pass");
	Check(limiter.TryAcquire(), "second lease should pass");
	Check(!limiter.TryAcquire(), "third lease must be rejected");
	Check(limiter.active() == 2, "active count should match held leases");
	limiter.Release();
	Check(limiter.TryAcquire(), "released capacity should be reusable");
	limiter.Release();
	limiter.Release();
	Check(limiter.active() == 0, "all leases should be released");
	limiter.Release();
	Check(limiter.active() == 0, "extra release must saturate at zero");
	Check(limiter.TryAcquire(), "capacity should remain valid after an extra release");
	Check(limiter.TryAcquire(), "second capacity slot should remain valid");
	Check(!limiter.TryAcquire(), "extra release must not create additional capacity");
	limiter.Release();
	limiter.Release();
}

void TestRequiredFileChecks() {
	const auto unique_suffix =
		std::chrono::steady_clock::now().time_since_epoch().count();
	const std::filesystem::path path = std::filesystem::temp_directory_path() /
		("ava-grpc-hardening-test-" + std::to_string(unique_suffix));
	{
		std::ofstream output(path, std::ios::binary);
		output << "test-data";
	}

#if defined(__unix__) || defined(__APPLE__)
	Check(chmod(path.c_str(), S_IRUSR | S_IWUSR) == 0, "test chmod 0600 should succeed");
#endif
	Check(ava::grpc_secure::ReadRequiredFile(path) == "test-data",
		  "required file should be read exactly");
	ExpectThrows([&path] { static_cast<void>(ava::grpc_secure::ReadRequiredFile(path, 4U)); },
				 "oversized file must be rejected");
	ava::grpc_secure::ValidatePrivateKeyPermissions(path);

#if defined(__unix__) || defined(__APPLE__)
	Check(chmod(path.c_str(), S_IRUSR | S_IWUSR | S_IRGRP) == 0,
		  "test chmod 0640 should succeed");
	ExpectThrows([&path] { ava::grpc_secure::ValidatePrivateKeyPermissions(path); },
				 "group-readable private key must be rejected");
#endif

	std::filesystem::remove(path);
	ExpectThrows([&path] { static_cast<void>(ava::grpc_secure::ReadRequiredFile(path)); },
				 "missing file must be rejected");
}

}  // namespace

int main() {
	try {
		TestConfigurationParsers();
		TestBindValidation();
		TestRequestValidation();
		TestRateLimiter();
		TestInFlightLimiter();
		TestRequiredFileChecks();
		std::cout << "hardening tests passed\n";
		return EXIT_SUCCESS;
	} catch (const std::exception& error) {
		std::cerr << "hardening test failed: " << error.what() << '\n';
		return EXIT_FAILURE;
	}
}
