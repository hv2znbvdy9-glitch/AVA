cmake_minimum_required(VERSION 3.16)

project(ava_secure_grpc_example LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT UNIX)
	message(FATAL_ERROR "The shutdown implementation in this example requires POSIX sigwait().")
endif()

option(AVA_GRPC_BUILD_TESTS "Build the hardened gRPC example tests" ON)

find_package(Protobuf REQUIRED)
find_package(gRPC CONFIG REQUIRED)
find_package(Threads REQUIRED)

set(PROTO_FILE "${CMAKE_CURRENT_SOURCE_DIR}/proto/helloworld.proto")
set(PROTO_SOURCE "${CMAKE_CURRENT_BINARY_DIR}/helloworld.pb.cc")
set(PROTO_HEADER "${CMAKE_CURRENT_BINARY_DIR}/helloworld.pb.h")
set(GRPC_SOURCE "${CMAKE_CURRENT_BINARY_DIR}/helloworld.grpc.pb.cc")
set(GRPC_HEADER "${CMAKE_CURRENT_BINARY_DIR}/helloworld.grpc.pb.h")

add_custom_command(
	OUTPUT
		"${PROTO_SOURCE}"
		"${PROTO_HEADER}"
		"${GRPC_SOURCE}"
		"${GRPC_HEADER}"
	COMMAND
		"${Protobuf_PROTOC_EXECUTABLE}"
	ARGS
		--cpp_out "${CMAKE_CURRENT_BINARY_DIR}"
		--grpc_out "${CMAKE_CURRENT_BINARY_DIR}"
		--plugin=protoc-gen-grpc=$<TARGET_FILE:gRPC::grpc_cpp_plugin>
		--proto_path "${CMAKE_CURRENT_SOURCE_DIR}/proto"
		"${PROTO_FILE}"
	DEPENDS "${PROTO_FILE}"
	VERBATIM
)

add_library(ava_grpc_proto STATIC
	"${PROTO_SOURCE}"
	"${GRPC_SOURCE}"
)
target_include_directories(ava_grpc_proto PUBLIC "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(ava_grpc_proto PUBLIC protobuf::libprotobuf gRPC::grpc++)

add_library(ava_grpc_hardening STATIC
	src/hardening.cc
	src/hardening.h
)
target_include_directories(ava_grpc_hardening PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_link_libraries(ava_grpc_hardening PUBLIC Threads::Threads)

function(ava_enable_strict_warnings target)
	if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
		target_compile_options(${target} PRIVATE
			-Wall
			-Wextra
			-Wpedantic
			-Wconversion
			-Wsign-conversion
			-Werror
		)
	endif()
endfunction()

ava_enable_strict_warnings(ava_grpc_hardening)

add_executable(ava_secure_greeter_server src/server.cc)
target_link_libraries(ava_secure_greeter_server PRIVATE
	ava_grpc_hardening
	ava_grpc_proto
	Threads::Threads
)
ava_enable_strict_warnings(ava_secure_greeter_server)

add_executable(ava_secure_greeter_client src/client.cc)
target_link_libraries(ava_secure_greeter_client PRIVATE
	ava_grpc_hardening
	ava_grpc_proto
)
ava_enable_strict_warnings(ava_secure_greeter_client)

if(AVA_GRPC_BUILD_TESTS)
	enable_testing()

	add_executable(ava_grpc_hardening_tests tests/hardening_test.cc)
	target_link_libraries(ava_grpc_hardening_tests PRIVATE ava_grpc_hardening)
	ava_enable_strict_warnings(ava_grpc_hardening_tests)
	add_test(NAME hardening_unit COMMAND ava_grpc_hardening_tests)

	find_program(OPENSSL_EXECUTABLE openssl)
	if(OPENSSL_EXECUTABLE)
		add_test(
			NAME mtls_smoke
			COMMAND
				bash
				"${CMAKE_CURRENT_SOURCE_DIR}/tests/mtls_smoke.sh"
				"$<TARGET_FILE:ava_secure_greeter_server>"
				"$<TARGET_FILE:ava_secure_greeter_client>"
				"${OPENSSL_EXECUTABLE}"
		)
		set_tests_properties(mtls_smoke PROPERTIES TIMEOUT 45)
	else()
		message(WARNING "OpenSSL CLI not found; the mTLS smoke test is disabled.")
	endif()
endif()
