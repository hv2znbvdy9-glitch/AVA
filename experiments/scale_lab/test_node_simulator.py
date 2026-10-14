import unittest

from node_simulator import MAX_TARGET, estimate_scale


class ScaleEstimateTests(unittest.TestCase):
    def test_default_target_is_aggregate_only(self):
        result = estimate_scale()
        self.assertEqual(result.target_logical_nodes, 690_000_000)
        self.assertEqual(result.simulated_sample_nodes, 1000)
        self.assertEqual(result.estimated_total_memory_bytes, 690_000_000 * 256)
        self.assertEqual(result.mode, "aggregate_estimate_not_real_infrastructure")

    def test_small_target(self):
        result = estimate_scale(target=10, sample_nodes=5, bytes_per_node=100)
        self.assertEqual(result.sample_memory_bytes, 500)
        self.assertEqual(result.estimated_total_memory_bytes, 1000)

    def test_rejects_out_of_bounds_target(self):
        for target in (0, MAX_TARGET + 1, -1):
            with self.subTest(target=target), self.assertRaises(ValueError):
                estimate_scale(target=target)

    def test_rejects_unbounded_sample(self):
        with self.assertRaises(ValueError):
            estimate_scale(target=10, sample_nodes=11)
        with self.assertRaises(ValueError):
            estimate_scale(sample_nodes=1_000_001)


if __name__ == "__main__":
    unittest.main()
