import importlib.util
import pathlib
import unittest

MODULE_PATH = pathlib.Path(__file__).resolve().parents[1] / "node_simulator.py"
SPEC = importlib.util.spec_from_file_location("node_simulator", MODULE_PATH)
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class ScaleEstimatorTests(unittest.TestCase):
    def test_default_target_is_logical_only(self):
        report = module.estimate_scale()
        self.assertEqual(report.logical_nodes, 690_000_000)
        self.assertEqual(report.real_servers_created, 0)
        self.assertEqual(report.network_calls_made, 0)
        self.assertEqual(report.sample_size, 100_000)

    def test_payload_estimate(self):
        report = module.estimate_scale(10, 4, 256, 3)
        self.assertEqual(report.estimated_payload_bytes_total, 2560)
        self.assertEqual(report.workers, 4)

    def test_sample_limit_is_enforced(self):
        with self.assertRaises(ValueError):
            module.estimate_scale(sample_size=1_000_001)

    def test_negative_node_count_is_rejected(self):
        with self.assertRaises(ValueError):
            module.estimate_scale(logical_nodes=-1)

    def test_zero_nodes_needs_zero_workers(self):
        report = module.estimate_scale(logical_nodes=0, sample_size=0)
        self.assertEqual(report.workers, 0)


if __name__ == "__main__":
    unittest.main()
