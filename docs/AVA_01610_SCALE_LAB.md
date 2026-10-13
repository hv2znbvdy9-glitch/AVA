# AVA / AVO 01610-1 — SCALE LAB: 690 million virtual identities

**Status:** model and local tests only. **Real servers created:** **zero**.

## What is demonstrated

A bounded, offline mathematical model addresses up to **690,000,000 logical node identifiers** and samples at most **100,000 virtual identities**. It uses deterministic pseudorandom independent synthetic failure events under a user-supplied probability and extrapolates counts to the namespace. A SHA-256 digest of the canonical JSON body makes repeated reports easy to compare. A hash is not a digital signature or proof of independent authenticity.

**This does not create 690 million processes, containers, VMs, cloud servers, user accounts or network connections.** It does not measure throughput, costs, network latency, actual availability, energy consumption, or successful infrastructure scale. The 690M figure is a **namespace parameter**, not a number of running machines. The extrapolation is only meaningful under the synthetic assumptions; it cannot establish production readiness.

## Reproduce locally

From the repository root, with Python 3.11+ and no extra packages:

```bash
python -m unittest discover -s tests -p 'test_ava_scale_lab.py' -v
python -m ava.scale_lab --nodes 690000000 --samples 10000 --failure-probability 0.01 --seed 1610
```

The script writes JSON to **stdout** only. It makes no network calls and does not read local system security settings or modify files. The CI workflow triggers only on matching pull requests or manual dispatch: no scheduled loops, no cloud provisioning permissions, and a five-minute job time limit.

## AVA evidence rules

1. Label all numbers `simulated`, `assumed`, `observed in sample`, or `extrapolated`.
2. Never interpret virtual IDs as deployed servers. Count real servers only from authorized provider inventories.
3. Keep operational deployment separate from offline models, with explicit credentials, billing budgets, approvals, safety guardrails and an incremental pilot when requested.
4. Store and version evidence and assumptions before scaling claims.

**Next meaningful experiment:** a bounded queue/load model with synthetic workloads, resource requirements and uncertainties; later a small, explicitly budgeted real pilot only after separate approval.
