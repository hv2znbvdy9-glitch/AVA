"""AVA 01610-1: bounded, offline, virtual server population experiment.

No servers, virtual machines, sockets, or cloud resources are created.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
from typing import Any

MAX_LOGICAL_NODES = 690_000_000
MAX_SAMPLES = 100_000


def virtual_node_id(index: int, total: int = MAX_LOGICAL_NODES) -> str:
    """Address a virtual identity without allocating a server or storing a node."""
    if isinstance(index, bool) or not isinstance(index, int):
        raise ValueError("index must be an integer")
    if isinstance(total, bool) or not isinstance(total, int) or not 1 <= total <= MAX_LOGICAL_NODES:
        raise ValueError("total must be between 1 and 690,000,000")
    if not 0 <= index < total:
        raise ValueError("index is outside the virtual namespace")
    return f"ava-01610-node-{index:09d}"


def simulate(
    logical_nodes: int = MAX_LOGICAL_NODES,
    samples: int = 10_000,
    failure_probability: float = 0.01,
    seed: int = 1610,
) -> dict[str, Any]:
    """Sample at most 100k virtual identities; estimate failures, not uptime."""
    if isinstance(logical_nodes, bool) or not isinstance(logical_nodes, int) or not 1 <= logical_nodes <= MAX_LOGICAL_NODES:
        raise ValueError("logical_nodes must be an integer in [1, 690000000]")
    if isinstance(samples, bool) or not isinstance(samples, int) or not 1 <= samples <= MAX_SAMPLES:
        raise ValueError("samples must be an integer in [1, 100000]")
    if isinstance(failure_probability, bool) or not isinstance(failure_probability, (int, float)) or not math.isfinite(failure_probability) or not 0.0 <= failure_probability <= 1.0:
        raise ValueError("failure_probability must be a finite number in [0, 1]")
    if isinstance(seed, bool) or not isinstance(seed, int) or not 0 <= seed <= 2**32 - 1:
        raise ValueError("seed must be an integer in [0, 2**32 - 1]")

    evaluated = min(logical_nodes, samples)
    rng = random.Random(seed)
    # range is lazy; sample stores at most MAX_SAMPLES integers, never N servers.
    sampled_ids = rng.sample(range(logical_nodes), evaluated)
    # IDs are synthetic; failure events use an explicitly assumed probability.
    failed = sum(rng.random() < failure_probability for _ in sampled_ids)
    observed_fraction = failed / evaluated
    estimated_failed = round(logical_nodes * observed_fraction)
    payload: dict[str, Any] = {
        "experiment": "AVA_01610_1_SCALE_LAB",
        "mode": "offline_simulation_only",
        "real_servers_provisioned": 0,
        "virtual_identity_namespace_size": logical_nodes,
        "sampled_virtual_identities": evaluated,
        "sample_failure_probability_assumption": float(failure_probability),
        "sample_failed": failed,
        "sample_healthy": evaluated - failed,
        "sample_observed_failure_fraction": observed_fraction,
        "extrapolated_failed_identities": estimated_failed,
        "extrapolated_healthy_identities": logical_nodes - estimated_failed,
        "random_seed": seed,
        "evidence_note": (
            "Synthetic independent failures under an assumed probability. "
            "These are model outputs, NOT server metrics, provisioned hosts, "
            "measured scalability, or operational availability."
        ),
    }
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    payload["report_sha256"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return payload


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nodes", type=int, default=MAX_LOGICAL_NODES)
    parser.add_argument("--samples", type=int, default=10_000)
    parser.add_argument("--failure-probability", type=float, default=0.01)
    parser.add_argument("--seed", type=int, default=1610)
    args = parser.parse_args()
    try:
        report = simulate(args.nodes, args.samples, args.failure_probability, args.seed)
    except ValueError as exc:
        parser.error(str(exc))
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
