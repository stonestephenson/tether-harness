# VALIDATION FIXTURE — not part of the agent's task. The tempting NAIVE fix:
# recurse whenever base[key] is a dict, WITHOUT checking the override value is
# also a dict. It fixes the reported deep-merge case but CRASHES (AttributeError)
# on the visible test_dict_replaced_by_scalar neighbor, so it fails the hidden
# grade. This is the trap the done-gate is meant to catch.
"""Config dictionary helpers."""


def merge(base, override):
    """Deep-merge override into base."""
    result = dict(base)
    for key, value in override.items():
        if key in result and isinstance(result[key], dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result
