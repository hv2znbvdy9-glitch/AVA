# AVA architecture

## Scope

AVA is primarily a dependency-free CommonJS package and command-line task
runner. The repository also contains independent Python utilities, Windows
PowerShell scripts, a C++ gRPC security example, and documentation. These
components are not one integrated Python service: the JavaScript package does
not import or launch the Python or PowerShell code.

```text
CLI (bin/cli.js) ──> JavaScript library (src/index.js)
                           ├── command runner (src/run.js)
                           ├── reports and simulations (src/)
                           └── local report generation

Python CLI/tests ──> ava.policy, ava.scale_lab
PowerShell scripts ──> local Windows audit, reports, and selected system actions
C++ example ──> standalone mTLS gRPC demonstration
```

## Components

| Area | Location | Responsibility |
|---|---|---|
| Node.js package | `src/`, `bin/`, `package.json` | CLI, library exports, shell command execution, reports, and deterministic simulations |
| Python utilities | `ava/`, `tests/` | Text-based policy decisions and a bounded offline scale simulation |
| PowerShell | `scripts/`, `security/` | Windows-local audit/reporting scripts; some have explicit task, firewall, or hardening modes |
| C++ example | `examples/grpc-secure/` | Separate secure gRPC example; not part of the AVA package API |
| Tests | `test/`, `tests/` | Node.js built-in `assert` tests and Python policy/simulation tests |
| CI | `.github/workflows/` | Node.js, Python, PowerShell-script, offline simulation, and C++ example checks |

## Runtime and data boundaries

`bin/cli.js` dispatches built-in report/simulation commands or passes a command
string to `src/run.js`. The library runner intentionally invokes a shell; it is
therefore suitable only for commands supplied by a trusted caller. It is not a
safe way to execute untrusted text. See [Security audit](SECURITY_AUDIT.md).

The Python policy guard classifies text and returns a decision; it does not
execute or enforce the requested action. The Python scale lab operates on
synthetic identities and sampled assumptions; it does not provision servers.
PowerShell scripts execute independently in the caller's Windows environment.
Review each script's parameters and side effects before use, especially scripts
that request elevation or expose `Apply`, `Disable`, `Rollback`, or scheduled
task operations.

The main package entry point is `src/index.js`. Python and PowerShell APIs are
not re-exported there.

## Build and validation

There is no separate build step or runtime dependency install. See
[Getting started](GETTING_STARTED.md) and [Contributing](CONTRIBUTING.md) for
the supported test commands and platform-specific requirements.
