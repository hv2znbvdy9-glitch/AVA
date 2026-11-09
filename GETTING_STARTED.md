# Getting started

## Requirements

- Node.js 22 is used by the repository CI.
- Python 3.10+ is needed for the Python utilities.
- PowerShell 5.1+ is declared by some scripts; check each script because the
  declaration is not universal.
- `pytest` is required only for the Python policy tests. The Node package has
  no declared runtime dependencies.

## Install and run

From the repository root:

```bash
npm install
npm test
npx ava "echo hello"
```

Built-in report and simulation commands include:

```bash
node bin/cli.js --overview
node bin/cli.js --safe-local-node
node bin/cli.js --repair-windows-system-files
node bin/cli.js --neuron-model
node bin/cli.js --neuron-sim
node bin/cli.js --avatar-01610
node bin/cli.js --github-profile-report
```

The command runner executes shell command strings. Run only commands you
understand; see [Security audit](SECURITY_AUDIT.md).

## Python utilities

```bash
python -m unittest discover -s tests -v
python -m pytest tests/test_ava_policy_acceptance.py
python -m ava.scale_lab --nodes 10000 --samples 1000 --seed 1610
python -m ava.policy_cli "save local report"
```

## Learn more

- [Architecture](ARCHITECTURE.md)
- [Python modules](PYTHON_MODULES.md)
- [PowerShell scripts](POWERSHELL_SCRIPTS.md)
- [API reference](API_REFERENCE.md)
- [Contributing](CONTRIBUTING.md)
