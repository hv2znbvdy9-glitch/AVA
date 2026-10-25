import copy
import unittest

from ava_chemistry import load_knowledge, validate_knowledge


class ChemistryKnowledgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = load_knowledge()

    def test_all_13_s_block_entries_present(self):
        self.assertEqual(len(self.data["s_block"]), 13)

    def test_hydrogen_is_not_classified_as_alkali_metal(self):
        hydrogen = next(item for item in self.data["s_block"] if item["symbol"] == "H")
        self.assertIn("not an alkali metal", hydrogen["class"])

    def test_group_numbers_are_only_one_or_two(self):
        self.assertTrue(all(item["group"] in (1, 2) for item in self.data["s_block"]))

    def test_all_10_cation_reference_entries_present(self):
        self.assertEqual(len(self.data["cation_tests"]), 10)

    def test_all_cation_entries_require_confirmation(self):
        self.assertTrue(all(item["requires_confirmation"] for item in self.data["cation_tests"]))

    def test_cu2_record_uses_canonical_evidence_schema(self):
        cu = next(item for item in self.data["cation_tests"] if item["ion"] == "Cu2+")
        self.assertEqual(cu["category"], "qualitative_cation_analysis")
        self.assertEqual(cu["reaction"], "Cu2+ + 2 OH- -> Cu(OH)2(s)")
        self.assertEqual(cu["expected_observation"], "blue_precipitate")
        self.assertEqual(cu["confidence"], "reference_only")
        self.assertEqual(cu["evidence_status"], "reference_only")
        self.assertEqual(cu["experimental_status"], "not_confirmed")
        self.assertEqual(cu["safety_status"], "review_required")
        self.assertIs(cu["safety_review_required"], True)
        self.assertIs(cu["execution_claimed"], False)

    def test_validator_rejects_claimed_execution(self):
        bad = copy.deepcopy(self.data)
        cu = next(item for item in bad["cation_tests"] if item["ion"] == "Cu2+")
        cu["execution_claimed"] = True
        self.assertTrue(any("execution_claimed must be false" in error for error in validate_knowledge(bad)))

    def test_validator_detects_duplicate_symbols(self):
        bad = {
            "schema_version": "1.0",
            "s_block": [
                {"atomic_number": 1, "symbol": "X", "name": "X one", "group": 1, "class": "test"},
                {"atomic_number": 2, "symbol": "X", "name": "X two", "group": 2, "class": "test"},
            ],
            "cation_tests": [],
            "safety": {"no_experiment_claim": True},
        }
        self.assertTrue(any("duplicate symbol" in error for error in validate_knowledge(bad)))

    def test_validator_rejects_missing_confirmation_flag(self):
        bad = {
            "schema_version": "1.0", "s_block": [],
            "cation_tests": [{"ion": "X+", "reagent": "R", "observation": "O", "product": "P", "requires_confirmation": False}],
            "safety": {"no_experiment_claim": True},
        }
        self.assertTrue(any("must require confirmation" in error for error in validate_knowledge(bad)))

    def test_safety_disclaimer_prevents_experiment_claim(self):
        self.assertTrue(self.data["safety"]["no_experiment_claim"])


if __name__ == "__main__":
    unittest.main()
