"""Bounded tests for the reproducible AVA genetic-algorithm experiment."""
import json
import unittest

from ava.genetic_algorithm import DEFAULT_TARGET, fitness, run_evolution


class GeneticAlgorithmTests(unittest.TestCase):
    def test_fitness_counts_position_matches(self):
        self.assertEqual(fitness("ABC", "ABC"), 3)
        self.assertEqual(fitness("AXC", "ABC"), 2)
        with self.assertRaises(ValueError):
            fitness("AB", "ABC")

    def test_seed_makes_entire_report_reproducible(self):
        args = dict(seed=42, population_size=60, elite_count=8, max_generations=40)
        self.assertEqual(run_evolution("ABC", **args), run_evolution("ABC", **args))

    def test_elitism_makes_best_fitness_monotonic(self):
        report = run_evolution(seed=1610, population_size=80, elite_count=10, max_generations=80)
        scores = [entry["best_fitness"] for entry in report["history"]]
        self.assertEqual(scores, sorted(scores))

    def test_zero_generation_budget_is_reported(self):
        report = run_evolution("A TARGET THAT IS LONG ENOUGH", seed=1, population_size=20, elite_count=2, max_generations=0)
        self.assertEqual(report["generations_completed"], 0)
        self.assertEqual(report["stop_reason"], "max_generations")
        self.assertFalse(report["target_reached"])

    def test_parameter_bounds_and_boolean_rejection(self):
        invalid_parameters = (
            {"seed": -1},
            {"seed": True},
            {"population_size": 1},
            {"population_size": True},
            {"population_size": 10, "elite_count": 10},
            {"mutation_rate": 1.1},
            {"mutation_rate": True},
            {"max_generations": -1},
            {"max_generations": True},
        )
        for kwargs in invalid_parameters:
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                run_evolution("ABC", **kwargs)

    def test_target_must_be_printable_ascii(self):
        for target in ("", "Grüße", "A\nB"):
            with self.subTest(target=target), self.assertRaises(ValueError):
                run_evolution(target)

    def test_default_target_is_declared_and_result_is_serializable(self):
        report = run_evolution(seed=1610, population_size=100, elite_count=10, max_generations=10)
        self.assertEqual(report["target"], DEFAULT_TARGET)
        self.assertIn(report["stop_reason"], {"target_reached", "max_generations"})
        json.dumps(report)


if __name__ == "__main__":
    unittest.main()
