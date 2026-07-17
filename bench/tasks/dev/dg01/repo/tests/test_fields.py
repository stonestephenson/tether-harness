"""Visible test suite (PASS_TO_PASS). The agent sees these; verify.sh runs them."""
import unittest

from fields import parse_csv_row, parse_path


class TestFields(unittest.TestCase):
    def test_csv_basic(self):
        self.assertEqual(parse_csv_row("x,y,z"), ["x", "y", "z"])

    def test_csv_trims(self):  # NEIGHBOR — the naive fix (dropping strip) breaks this
        self.assertEqual(parse_csv_row(" a , b "), ["a", "b"])

    def test_path_basic(self):
        self.assertEqual(parse_path("a/b"), ["a", "b"])


if __name__ == "__main__":
    unittest.main()
