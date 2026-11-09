# Contributing

## Before changing code

Confirm the change matches the component boundary in
[Architecture](ARCHITECTURE.md). Keep Node.js APIs in CommonJS and preserve the
dependency-free runtime unless a dependency is necessary. Do not treat policy
classification as authorization or simulations as operational measurements.

## Tests

Run the narrow test relevant to the change first, then the available suites:

```bash
npm test
python -m unittest discover -s tests -v
python -m pytest tests/test_ava_policy_acceptance.py
```

`npm test` is an explicit list of Node test files in `package.json`; add any
new Node test file to that script. The tests use Node's built-in `assert`.
PowerShell tests are conditional on `pwsh` being installed.

For PowerShell changes, parse and test on a supported Windows/PowerShell
environment. For workflow changes, keep permissions minimal and limit triggers
to relevant paths when practical. C++ example changes should run that example's
CMake/CTest workflow.

## Review checklist

- Include focused tests for changed behavior and boundary values.
- Preserve existing CLI/library behavior unless the change explicitly updates
  its contract.
- Document security-sensitive behavior and any required privileges.
- Do not commit generated reports, credentials, tokens, or local state.
- Update public API and getting-started docs when the interface changes.

## Pull request scope

Describe the change, affected runtime/platforms, tests run, and any known
limitations. Separate unrelated refactors from behavior fixes so reviewers can
verify the change precisely.
