# Hardened C++ gRPC reference

This is a **production-oriented reference**, not a claim that one source file makes a
service production-ready. It replaces the unsafe tutorial defaults with mandatory
mutual TLS, certificate-identity authorization, bounded resources, input validation,
conservative HTTP/2 settings, and signal-safe graceful shutdown.

The example is intentionally isolated from AVA's Node.js runtime. It builds as its own
CMake project and does not add an npm dependency.

## Security properties

| Concern | Control in this example |
| --- | --- |
| Cleartext or anonymous transport | TLS is mandatory and the server requires a client certificate signed by the configured CA. |
| CA trust used as authorization | Each RPC also checks the exact peer identity reported by gRPC against an explicit allowlist. |
| Accidental network exposure | Default bind is `127.0.0.1:50051`; wildcard binds fail closed unless explicitly enabled. |
| Oversized input or metadata | Send/receive messages are capped at 4 MiB by default; metadata has soft/hard limits. |
| Resource exhaustion | gRPC memory/thread quotas, concurrent-stream limits, a process-wide RPC cap, and a per-identity token bucket are applied. |
| Ping abuse and stale connections | Client pings without calls are disallowed, ping strikes are bounded, and idle/old connections expire. |
| Unsafe signal callback | `SIGINT` and `SIGTERM` are blocked before gRPC starts and consumed with `sigwait()` on the main thread. |
| Abrupt termination | Shutdown gives active RPCs a bounded grace period and then forces termination. |
| Missing or weak key files | Missing, empty, oversized, non-regular, or group/world-accessible private-key files fail startup. |
| Untrusted request content | The demo name field is length-bounded and rejects control characters; request data is not logged. |

There is no static bearer token. If application-layer credentials are also required,
use short-lived OIDC/JWT credentials validated by a dedicated authorization layer or
an authenticated service proxy. Do not add a long-lived token to source control.

## Build

On Ubuntu/Debian, install the toolchain and packaged gRPC/protobuf development files:

```bash
sudo apt-get update
sudo apt-get install --no-install-recommends \
  build-essential cmake ninja-build \
  libgrpc++-dev libprotobuf-dev protobuf-compiler protobuf-compiler-grpc \
  openssl
```

Then configure, build, and test:

```bash
cmake -S examples/grpc-secure -B build/grpc-secure -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build/grpc-secure --parallel 2
ctest --test-dir build/grpc-secure --output-on-failure
```

The smoke test creates a one-day test CA and certificates in a private temporary
directory, verifies an allowed client, rejects a different CA-valid identity, and
checks `SIGTERM` shutdown. It deletes the temporary material on exit. Those test
certificates are never suitable for deployment.

## Server configuration

Required variables:

| Variable | Meaning |
| --- | --- |
| `AVA_GRPC_SERVER_CERT` | PEM server certificate chain path. |
| `AVA_GRPC_SERVER_KEY` | PEM private-key path; POSIX mode must be `0600` or stricter. |
| `AVA_GRPC_CLIENT_CA` | PEM CA bundle used to verify client certificates. |
| `AVA_GRPC_ALLOWED_IDENTITIES` | Comma-separated, exact peer identities, normally DNS or URI SAN values. Whitespace inside an identity is rejected. |

Optional variables:

| Variable | Default | Accepted range/behavior |
| --- | ---: | --- |
| `AVA_GRPC_BIND_ADDRESS` | `127.0.0.1:50051` | Explicit `host:port`, `dns:///host:port`, or `[IPv6]:port`. |
| `AVA_GRPC_ALLOW_WILDCARD_BIND` | `false` | `true` is an explicit opt-in for `0.0.0.0`, `[::]`, or `*`. |
| `AVA_GRPC_MAX_MESSAGE_BYTES` | `4194304` | 1 KiB-64 MiB. |
| `AVA_GRPC_RESOURCE_QUOTA_BYTES` | `67108864` | 1 MiB-1 GiB. |
| `AVA_GRPC_MAX_THREADS` | `64` | 2-256 gRPC quota threads. |
| `AVA_GRPC_MAX_CONCURRENT_STREAMS` | `128` | 1-4096 streams per HTTP/2 connection. |
| `AVA_GRPC_MAX_CONCURRENT_RPCS` | `128` | 1-4096 RPC handlers in this service. |
| `AVA_GRPC_RATE_PER_SECOND` | `20` | 1-100000 tokens added per identity per second. |
| `AVA_GRPC_RATE_BURST` | `40` | 1-100000 initial/maximum tokens per identity. |
| `AVA_GRPC_SHUTDOWN_GRACE_SECONDS` | `10` | 1-300 seconds. |

Example startup:

```bash
export AVA_GRPC_BIND_ADDRESS='127.0.0.1:50051'
export AVA_GRPC_SERVER_CERT='/etc/ava-grpc/tls/server.crt'
export AVA_GRPC_SERVER_KEY='/etc/ava-grpc/tls/server.key'
export AVA_GRPC_CLIENT_CA='/etc/ava-grpc/tls/client-ca.crt'
export AVA_GRPC_ALLOWED_IDENTITIES='spiffe://example.internal/ava-client'

./build/grpc-secure/ava_secure_greeter_server
```

The allowlist comparison is case-sensitive and uses the values returned by
`grpc::AuthContext::GetPeerIdentity()`. Issue certificates with a deliberate SAN and
put that SAN value in the allowlist. A client certificate merely chaining to the CA is
not enough.

## Test client

The included client always sets a three-second RPC deadline and requires its own mTLS
material:

```bash
export AVA_GRPC_TARGET='127.0.0.1:50051'
export AVA_GRPC_CLIENT_CERT='./client.crt'
export AVA_GRPC_CLIENT_KEY='./client.key'
export AVA_GRPC_SERVER_CA='./server-ca.crt'

./build/grpc-secure/ava_secure_greeter_client 'Danny'
```

## Deployment notes

- Bind to loopback when a local proxy handles ingress. Otherwise bind one specific
  internal address and restrict the firewall/security group to the expected source
  networks. A wildcard bind is not automatically exploitable, but it expands the
  reachable surface.
- Keep the service unprivileged. A reasonable `systemd` baseline includes
  `User=ava-grpc`, `Group=ava-grpc`, `UMask=0077`, `NoNewPrivileges=true`,
  `PrivateTmp=true`, `ProtectSystem=strict`, `ProtectHome=true`,
  `RestrictSUIDSGID=true`, and an empty `CapabilityBoundingSet=`. Validate sandbox
  directives against the actual certificate and logging paths before rollout.
- The process writes JSON lifecycle events to stderr and never logs the request name,
  certificate, private key, or allowlist. Route stderr to the normal service log and
  add metrics/tracing through the deployment's standard observability layer.
- The in-process token bucket protects one instance. Enforce tenant-wide quotas and
  distributed rate limits at a trusted gateway or service mesh as well.
- Certificate files are loaded at startup. Rotate with an atomic file replacement and
  a supervised graceful restart. The one-hour connection age prevents connections
  from surviving indefinitely, but it is not certificate hot reload.
- gRPC health/reflection services are deliberately not enabled. If needed, expose
  them through the same authentication and authorization policy; do not accidentally
  create a weaker side channel.
- Keepalive values must be coordinated with clients, load balancers, and service
  owners. The server rejects overly frequent idle pings instead of setting
  `GRPC_ARG_HTTP2_MAX_PINGS_WITHOUT_DATA=0`, which would mean unlimited pings.
- Pin supported gRPC/protobuf versions in the real build, scan the produced image and
  dependencies, and test certificate expiry, revocation/rotation, overload, proxy
  behavior, and forced-shutdown paths before release.

## Scope and references

This reference is POSIX-only because its shutdown design uses `pthread_sigmask()` and
`sigwait()`. A Windows service should use a console/service control handler only to
signal a normal thread; the handler must not call gRPC directly.

- [gRPC C++ `ServerBuilder`](https://grpc.github.io/grpc/cpp/classgrpc_1_1_server_builder.html)
- [gRPC C++ `AuthContext`](https://grpc.github.io/grpc/cpp/classgrpc_1_1_auth_context.html)
- [gRPC C++ `ResourceQuota`](https://grpc.github.io/grpc/cpp/classgrpc_1_1_resource_quota.html)
- [gRPC keepalive guide](https://grpc.io/docs/guides/keepalive/)
- [gRPC authentication guide](https://grpc.io/docs/guides/auth/)
