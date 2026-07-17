"""Tiny field/path parsing helpers."""


def split_fields(line, sep=","):
    """Split ``line`` on ``sep``, trimming surrounding whitespace from each field."""
    return [f.strip() for f in line.split(sep)]


def parse_csv_row(line):
    """Parse a CSV row into trimmed fields."""
    return split_fields(line)


def parse_path(p):
    """Split a path on '/' into its components."""
    return split_fields(p, sep="/")
