# API reference

The package is CommonJS. Its package entry point is `src/index.js`; require
the package name after installation or the relative entry point in the
repository.

```js
const ava = require('ava');
```

## Command runner

```js
run(command, options?)
runAll(commands, options?)
runAsync(command, options?)
runAllParallel(commands, options?)
```

`command` is a shell command string; it is executed as supplied. `commands`
must be an array for the multi-command functions. `options` supports:

| Property | Type | Default | Meaning |
|---|---|---|---|
| `silent` | boolean | `false` | Suppress captured output from being written to the parent process streams. |
| `cwd` | string | `process.cwd()` | Working directory for the child process. |
| `timeout` | positive integer (milliseconds) | unset | Terminate a command after the given duration. Unset preserves the existing unbounded behavior. |

Synchronous functions return `{stdout, stderr, exitCode}`. Asynchronous
functions resolve to the same result shape; `runAllParallel` preserves input
order in its result array. Invalid/empty command strings are rejected. The
runner is not a sandbox; do not pass untrusted strings. See
[Security audit](SECURITY_AUDIT.md).

## Other Node.js exports

The following are exported by `src/index.js`:

| Export | Purpose |
|---|---|
| `AVA_COLOR`, `hexToRgb`, `colorize`, `ava` | Color constants and helpers |
| `overview`, `OVERVIEW_TEXT` | Built-in overview text |
| `runSafeLocalNode` | Generate local safe-node snapshot/report output |
| `repairWindowsSystemFilesReport`, `repairWindowsSystemFilesData`, `REPAIR_WINDOWS_SYSTEM_FILES_REPORT`, `REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES` | Windows recovery guide report/data and reference constants; does not itself perform repair |
| `STATE_LABELS`, `clampScore`, `classifyState`, `calculateScore` | State classification helpers |
| `neuronModelReport`, `neuronModelData`, `NEURON_MODEL_REPORT`, `NEURON_MODEL_REFERENCES` | Neuron-model explanation/data and reference constants |
| `avatar01610Report`, `avatar01610Data`, `AVATAR_01610_REPORT`, `AVATAR_01610_LAYERS`, `AVATAR_01610_CYCLE`, `AVATAR_01610_PRINCIPLES` | AVATAR-01610 report and structured data |
| `HodgkinHuxleyCompartment`, `neuronRates`, `simulateNeuron`, `neuronSteadyState` | Hodgkin-Huxley teaching model |
| `AVA_RADIO_PROFILE`, `processAudio` | Offline voice-profile metadata and PCM processing |
| `MAX_TARGET_NODES`, `simulateScale` | Bounded scale simulation |

Not every source module is re-exported. For example, the GitHub-profile CLI
report implementation is currently used by the CLI and is not exported from
`src/index.js`.

## CLI commands

`bin/cli.js` supports these flags and command aliases:

| Feature | Flag | Command form |
|---|---|---|
| Run one shell command | — | `ava run <command>` or `ava <command>` |
| Run shell commands concurrently | `--parallel <cmd...>` | — |
| Overview | `--overview` | — |
| Safe local node report | `--safe-local-node` | `safe-local-node` |
| Windows repair guide report | `--repair-windows-system-files` | `repair-windows-system-files` |
| Neuron model report | `--neuron-model` | `neuron-model` |
| Neuron simulation JSON | `--neuron-sim` | `neuron-sim` |
| AVATAR-01610 report | `--avatar-01610` | `avatar-01610` |
| GitHub profile report | `--github-profile-report`, `--profile-report` | `github-profile-report`, `profile-report` |
| Color output | `--color` | — |

CLI shell commands are passed to the operating system shell. Do not use the
runner to execute untrusted input.

## Python interfaces

`ava.policy.AVAGuardPolicy.evaluate(action, *, target="AVA", metadata=None)`
returns a `PolicyDecision`; `batch_evaluate(actions)` returns decisions.
`ava.scale_lab.virtual_node_id(index, total=MAX_LOGICAL_NODES)` formats a
validated virtual identity, and `simulate(logical_nodes=..., samples=...,
failure_probability=..., seed=...)` returns a reproducible model report. See
[Python modules](PYTHON_MODULES.md) for limits and interpretation.
