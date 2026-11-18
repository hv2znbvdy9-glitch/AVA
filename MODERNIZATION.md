# Modernization roadmap

This roadmap distinguishes actionable work from claims that cannot be
substantiated by the current checkout. Priorities are proposals, not promises
that a feature is already implemented.

## Near term

1. **Subprocess controls:** add optional, validated timeouts to synchronous and
   asynchronous runner calls; test timeouts and retain an opt-out for commands
   that are deliberately long-running. Keep shell execution explicit and warn
   against untrusted command strings.
2. **Documentation consistency:** maintain this architecture/API inventory
   alongside source changes. Keep script capability and privilege notes
   aligned with their parameters and implementation.
3. **CI coverage:** ensure the ordinary CI validates the core Node suite on
   supported platforms and trigger Python tests when Python code changes.
   Keep the Ubuntu `npm audit` job for lockfile dependency checks. Check whether
   overlapping CI workflows are necessary before expanding them.
4. **PowerShell verification:** declare supported versions per script, parse
   and test on Windows PowerShell 5.1 and/or PowerShell 7 where intended, and
   safely test system-changing modes with mocks or disposable hosts.

## Follow-up

- Consider a separate argument-array execution API using `shell: false` if
  callers need to handle untrusted program arguments.
- Measure test coverage before setting a target. No coverage instrumentation or
  verified `>85%` result exists in the current Node test setup.
- Add workflow action pinning and automated dependency/security checks after
  defining their update and triage process.
- Consolidate duplicated PowerShell code only after behavior and privilege
  differences between variants are covered by tests.
- Add performance benchmarks only for a concrete workload and report
  reproducible baselines rather than extrapolating simulation outputs.

## Compatibility constraints

The package is CommonJS and exposes its Node library through `src/index.js`.
Preserve current command-string semantics and long-running command support
unless a breaking change is explicitly approved. Python source currently uses
syntax requiring Python 3.10 or newer. Do not claim Python 3.8 compatibility
without changing and testing those syntax requirements.

## Not represented as completed

The repository does not provide a verified count/category breakdown of open
issues, a measured 85% coverage result, or a comprehensive security scan.
These require separate data collection and should not be claimed from
documentation alone.
