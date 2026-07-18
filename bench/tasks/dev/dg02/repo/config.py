"""Config dictionary helpers."""


def merge(base, override):
    """Merge ``override`` into ``base`` (override wins). Returns a new dict."""
    result = dict(base)
    result.update(override)
    return result
