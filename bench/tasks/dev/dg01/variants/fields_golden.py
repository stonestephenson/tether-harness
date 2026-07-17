# VALIDATION FIXTURE — not part of the agent's task. The correct fix: give
# parse_path a non-trimming path, leaving parse_csv_row's trimming intact.
"""Tiny field/path parsing helpers."""


def split_fields(line, sep=",", trim=True):
    """Split ``line`` on ``sep``; trim surrounding whitespace from each field iff ``trim``."""
    parts = line.split(sep)
    return [p.strip() for p in parts] if trim else parts


def parse_csv_row(line):
    """Parse a CSV row into trimmed fields."""
    return split_fields(line)


def parse_path(p):
    """Split a path on '/' into its components, preserving surrounding spaces."""
    return split_fields(p, sep="/", trim=False)
