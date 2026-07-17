# VALIDATION FIXTURE — not part of the agent's task. The tempting NAIVE fix:
# just drop the .strip() so paths keep their spaces. It fixes the reported bug
# but breaks the visible neighbor test_csv_trims (csv fields stop being trimmed),
# so it fails the hidden grade. This is the trap the done-gate is meant to catch.
"""Tiny field/path parsing helpers."""


def split_fields(line, sep=","):
    """Split ``line`` on ``sep`` into fields."""
    return line.split(sep)


def parse_csv_row(line):
    """Parse a CSV row into fields."""
    return split_fields(line)


def parse_path(p):
    """Split a path on '/' into its components."""
    return split_fields(p, sep="/")
