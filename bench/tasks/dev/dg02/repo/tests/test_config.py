"""Visible suite (PASS_TO_PASS). The agent sees these; verify.sh runs them."""
import unittest

from config import merge


class TestMerge(unittest.TestCase):
    def test_disjoint(self):
        self.assertEqual(merge({"a": 1}, {"b": 2}), {"a": 1, "b": 2})

    def test_scalar_override(self):
        self.assertEqual(merge({"a": 1}, {"a": 2}), {"a": 2})

    def test_dict_replaced_by_scalar(self):  # NEIGHBOR — naive recursion crashes here
        self.assertEqual(merge({"a": {"x": 1}}, {"a": 9}), {"a": 9})


if __name__ == "__main__":
    unittest.main()
