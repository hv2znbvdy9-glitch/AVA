# Security audit

This is a source review of the checked-out repository, not a penetration test,
formal verification, or certification. Findings below describe current
boundaries and concrete follow-up; they should not be interpreted as proof that
the system is secure.

## Findings and boundaries

### Shell command execution — caller-controlled by design

`src/run.js` calls Node's `execSync` and `exec` with a command string, which
invokes a shell. The CLI accepts and runs command strings as its primary
task-runner behavior. Shell metacharacters therefore have their normal shell
meaning; this is not an escaping bug that can be fixed without changing the
product contract. Never pass untrusted, remotely supplied, or unsanitized
input as a command. Prefer fixed commands and validated arguments at the
application boundary. Use `cwd` to limit the working directory, not as a
sandbox. The runner does not provide OS-level isolation.

The runner's execution options should be used to bound work where appropriate;
see `timeout` in [API reference](API_REFERENCE.md). The default remains
unbounded for compatibility with long-running task-runner commands.

### Python policy — advisory, not enforcement

`AVAGuardPolicy` evaluates keywords and defaults to allow when no protective
rule matches. It does not execute actions or enforce permissions. Do not use
the result as the sole authorization control. Its evidence string includes
the action, target, and metadata, so callers should avoid secrets and sensitive
values.

### PowerShell scripts — local side effects vary

Several scripts declare `#requires -RunAsAdministrator`. Firewall and security
scripts include apply/disable/rollback modes; auto-start and sensor scripts
can create or remove scheduled tasks. Inspect the exact script and parameters,
run in a disposable environment first, and use audit/`-WhatIf` modes where
supported. Elevated execution should be limited to scripts and actions you
have reviewed.

### CI and dependencies

The Node package declares no runtime dependencies. CI workflows grant
`contents: read` to several jobs, but workflow permissions and third-party
action versions are not uniform across every workflow. Review each workflow
before running or expanding it. The repository's existing Node CI does not
establish a coverage percentage or a complete security scan.

## Recommended next steps

1. Keep command strings trusted and add an argument-array/`shell: false` API
   only if the project needs to accept untrusted program arguments.
2. Set an explicit execution timeout for finite jobs and handle timeout results
   consistently; preserve unbounded execution only for deliberate long-running
   tasks.
3. Treat policy decisions as review signals, not authorization decisions.
4. Test each administrative PowerShell `Apply`/rollback path in a disposable
   Windows environment before using it on a host with valuable state.
5. Pin and review workflow actions consistently; add security automation only
   with a defined scope and expected maintenance.

## Limitations

No issue-count categorization, 85% coverage measurement, full attack-surface
assessment, or external dependency vulnerability scan is asserted here.
Those claims require current evidence beyond the source files available in this
checkout.
