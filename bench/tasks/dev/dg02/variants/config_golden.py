# VALIDATION FIXTURE — not part of the agent's task. The correct fix: recurse ONLY
# when both sides are dicts, so a scalar override still replaces a dict.
"""Config dictionary helpers."""


def merge(base, override):
    """Deep-merge ``override`` into ``base``; override wins on non-dict conflicts."""
    result = dict(base)
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result
