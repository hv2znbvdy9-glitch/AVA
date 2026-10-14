"""Bounded AVA/AVO logical-node scale model; does not provision real servers.

The 690,000,000 target is represented by aggregate arithmetic only. This module
never creates one Python object/process per logical node and makes no network
calls or infrastructure changes.
"""
from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass


MAX_TARGET = 690_000_000


@dataclass(frozen=True)
class ScaleEstimate:
    target_logical_nodes: int
    simulated_sample_nodes: int
    sample_memory_bytes: int
    estimated_total_memory_bytes: int
    estimated_total_memory_gib: float
    mode: str = "aggregate_estimate_not_real_infrastructure"


def estimate_scale(target: int = MAX_TARGET, sample_nodes: int = 1000,
                   bytes_per_node: int = 256) -> ScaleEstimate:
    """Estimate aggregate memory from a bounded sample, without allocating nodes."""
    if not 1 <= target <= MAX_TARGET:
        raise ValueError(f"target must be between 1 and {MAX_TARGET}")
    if not 1 <= sample_nodes <= min(target, 1_000_000):
        raise ValueError("sample_nodes must be 1..min(target, 1,000,000)")
    if not 1 <= bytes_per_node <= 10_000_000:
        raise ValueError("bytes_per_node must be between 1 and 10,000,000")
    sample_memory = sample_nodes * bytes_per_node
    total_memory = target * bytes_per_node
    return ScaleEstimate(
        target_logical_nodes=target,
        simulated_sample_nodes=sample_nodes,
        sample_memory_bytes=sample_memory,
        estimated_total_memory_bytes=total_memory,
        estimated_total_memory_gib=round(total_memory / (1024 ** 3), 3),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", type=int, default=MAX_TARGET)
    parser.add_argument("--sample-nodes", type=int, default=1000)
    parser.add_argument("--bytes-per-node", type=int, default=256)
    args = parser.parse_args()
    print(json.dumps(asdict(estimate_scale(
        args.target, args.sample_nodes, args.bytes_per_node
    )), indent=2))


if __name__ == "__main__":
    main()
