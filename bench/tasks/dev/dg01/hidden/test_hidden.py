"""Held-out hidden suite — NEVER copied into the agent's workspace.
The verifier the agent never sees. Combines the bug's FAIL_TO_PASS check with
overfitting-catchers, and runs alongside the visible suite so a broken neighbor
(a broken PASS_TO_PASS test) also fails the hidden grade.
"""
import unittest

from fields import parse_csv_row, parse_path


class TestHidden(unittest.TestCase):
    def test_path_preserves_spaces(self):  # FAIL_TO_PASS — the reported bug
        self.assertEqual(parse_path("/a/ b /c"), ["", "a", " b ", "c"])

    def test_path_trailing_space(self):  # catches overfitting the visible path test
        self.assertEqual(parse_path("/x/ y /"), ["", "x", " y ", ""])

    def test_csv_extra_spaces(self):  # catches overfitting the visible csv test
        self.assertEqual(parse_csv_row("  hello  ,  world  "), ["hello", "world"])


if __name__ == "__main__":
    unittest.main()
