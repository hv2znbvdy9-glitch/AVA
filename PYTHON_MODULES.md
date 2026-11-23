# Python modules

The Python code under `ava/` is a small, standalone utility package. It is not
the primary CLI/library implementation and currently contains no `cli`,
`clients`, `config`, `core`, `db`, `lsp`, or `monitoring` package hierarchy.

## `ava.policy`

`AVAGuardPolicy.evaluate(action, target="AVA", metadata=None)` returns a frozen
`PolicyDecision`. The decision includes `allowed`, `status`, a reason, matched
rule evidence, accepted-rule identifiers, and an ISO-8601 UTC timestamp.
`batch_evaluate(actions)` evaluates a sequence in order. `to_dict()` and
`to_json()` provide serializable output.

The guard uses regular expressions over normalized text. It gives explicit
protection rules precedence over allow rules and otherwise applies a
permissive default. It is a deterministic classifier, not an authorization
boundary: it neither performs nor blocks an external action. Metadata is
included in evidence text; do not pass secrets or sensitive data to it.

## `ava.policy_cli`

Provides the lightweight policy command-line entry point over
`AVAGuardPolicy`. Invoke it from the repository root with:

```bash
python -m ava.policy_cli "AVA angreifen"
```

## `ava.scale_lab`

Provides `virtual_node_id(index, total=MAX_LOGICAL_NODES)` and
`simulate(logical_nodes, samples, failure_probability, seed)`. Inputs are
validated and bounded (`MAX_LOGICAL_NODES` is 690,000,000 and `MAX_SAMPLES` is
100,000). Results are reproducible for a given seed and include an integrity
hash. The result is an estimate under a synthetic independent-failure
assumption—not measured uptime, deployed infrastructure, or a capacity claim.

```bash
python -m ava.scale_lab --nodes 690000000 --samples 1000 --seed 1610
```

## Python support and tests

The source uses modern built-in generic and union type syntax; use Python 3.10
or newer. The workflow currently exercises Python 3.11 for the scale lab and
Python 3.12 for policy tests. Run tests from the repository root:

```bash
python -m unittest discover -s tests -v
python -m pytest tests/test_ava_policy_acceptance.py
```

`pytest` is only needed for the policy acceptance tests and is installed by
`.github/workflows/ava-policy.yml`; the scale-lab tests use `unittest`.
