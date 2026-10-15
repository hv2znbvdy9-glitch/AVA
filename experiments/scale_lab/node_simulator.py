"""Bounded, offline estimator for virtual AVA/AVO nodes.

This module does not create real servers or allocate one object per logical node.
"""
from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass


MAX_SAMPLE_SIZE = 1_000_000


@dataclass(frozen=True)
class ScaleReport:
    logical_nodes: int
    sample_size: int
    workers: int
    payload_bytes_per_node: int
    estimated_payload_bytes_total: int
    estimated_payload_gib_total: float
    real_servers_created: int = 0
    network_calls_made: int = 0


def estimate_scale(
    logical_nodes: int = 690_000_000,
    sample_size: int = 100_000,
    payload_bytes_per_node: int = 256,
    nodes_per_worker: int = 10_000,
) -> ScaleReport:
    """Return arithmetic estimates; never materialize the logical population."""
    if logical_nodes < 0:
        raise ValueError("logical_nodes must be >= 0")
    if not 0 <= sample_size <= MAX_SAMPLE_SIZE:
        raise ValueError(f"sample_size must be between 0 and {MAX_SAMPLE_SIZE}")
    if payload_bytes_per_node < 0:
        raise ValueError("payload_bytes_per_node must be >= 0")
    if nodes_per_worker < 1:
        raise ValueError("nodes_per_worker must be >= 1")

    total_bytes = logical_nodes * payload_bytes_per_node
    workers = (logical_nodes + nodes_per_worker - 1) // nodes_per_worker
    return ScaleReport(
        logical_nodes=logical_nodes,
        sample_size=min(sample_size, logical_nodes),
        workers=workers,
        payload_bytes_per_node=payload_bytes_per_node,
        estimated_payload_bytes_total=total_bytes,
        estimated_payload_gib_total=round(total_bytes / (1024 ** 3), 3),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nodes", type=int, default=690_000_000)
    parser.add_argument("--sample-size", type=int, default=100_000)
    parser.add_argument("--payload-bytes", type=int, default=256)
    parser.add_argument("--nodes-per-worker", type=int, default=10_000)
    args = parser.parse_args()
    report = estimate_scale(
        logical_nodes=args.nodes,
        sample_size=args.sample_size,
        payload_bytes_per_node=args.payload_bytes,
        nodes_per_worker=args.nodes_per_worker,
    )
    print(json.dumps(asdict(report), indent=2))


if __name__ == "__main__":
    main()
