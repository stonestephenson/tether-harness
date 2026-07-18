"""Held-out hidden suite — NEVER copied into the agent's workspace.
The grader the agent never sees: the reported deep-merge bug (FAIL_TO_PASS), a
deeper-nesting generalization, and a no-mutation correctness guard. Runs alongside
the visible suite, so a broken visible neighbor also fails the hidden grade.
"""
import unittest

from config import merge


class TestHidden(unittest.TestCase):
    def test_deep_merge(self):  # FAIL_TO_PASS — the reported bug
        self.assertEqual(
            merge({"db": {"host": "x"}}, {"db": {"port": 5}}),
            {"db": {"host": "x", "port": 5}},
        )

    def test_deep_nesting(self):  # generalization — catches a one-level-only "fix"
        self.assertEqual(
            merge({"a": {"b": {"c": 1}}}, {"a": {"b": {"d": 2}}}),
            {"a": {"b": {"c": 1, "d": 2}}},
        )

    def test_no_mutation(self):  # correctness — a naive recursive fix may mutate base
        base = {"a": {"x": 1}}
        merge(base, {"a": {"y": 2}})
        self.assertEqual(base, {"a": {"x": 1}})


if __name__ == "__main__":
    unittest.main()
