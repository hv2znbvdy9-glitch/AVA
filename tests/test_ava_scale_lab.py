"""Bounded, pure-Python tests; run with python -m unittest discover -s tests."""

import unittest

from ava.scale_lab import MAX_LOGICAL_NODES, simulate, virtual_node_id


class ScaleLabTests(unittest.TestCase):
    def test_690m_namespace_without_servers(self):
        report = simulate(samples=100, seed=1610)
        self.assertEqual(report["virtual_identity_namespace_size"], 690_000_000)
        self.assertEqual(report["sampled_virtual_identities"], 100)
        self.assertEqual(report["real_servers_provisioned"], 0)
        self.assertEqual(len(report["report_sha256"]), 64)

    def test_deterministic_evidence(self):
        self.assertEqual(simulate(1_000, 50, 0.2, 42), simulate(1_000, 50, 0.2, 42))

    def test_bounds_and_no_overallocation(self):
        self.assertEqual(simulate(4, samples=10)["sampled_virtual_identities"], 4)
        with self.assertRaises(ValueError):
            simulate(samples=100_001)
        with self.assertRaises(ValueError):
            simulate(logical_nodes=MAX_LOGICAL_NODES + 1)
        with self.assertRaises(ValueError):
            simulate(samples=True)
        with self.assertRaises(ValueError):
            simulate(failure_probability=float("nan"))

    def test_all_healthy_or_failed(self):
        self.assertEqual(simulate(100, 100, 0)["extrapolated_failed_identities"], 0)
        self.assertEqual(simulate(100, 100, 1)["extrapolated_failed_identities"], 100)

    def test_virtual_identifiers_only(self):
        self.assertEqual(virtual_node_id(0), "ava-01610-node-000000000")
        self.assertEqual(virtual_node_id(689_999_999), "ava-01610-node-689999999")
        with self.assertRaises(ValueError):
            virtual_node_id(690_000_000)


if __name__ == "__main__":
    unittest.main()
