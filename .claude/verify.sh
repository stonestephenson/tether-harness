#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
bash plugins/tether/tests/context-health.test.sh
bash plugins/tether/tests/verify-hooks.test.sh

# harden(2026-07-12): docs pointer-graph hygiene — a relative link to a .md file
# that doesn't exist is doc rot at commit time, not audit time. .md targets only
# (http/mailto/#anchor and non-md targets are skipped; references/papers/ is
# gitignored and its links are non-md anyway).
python3 - <<'PY'
import os, re, subprocess, sys
files = subprocess.run(["git", "ls-files", "*.md"], capture_output=True, text=True).stdout.split()
link = re.compile(r"\]\(([^)\s]+)\)")
broken = []
for f in files:
    try:
        text = open(f, encoding="utf-8").read()
    except OSError:
        continue
    for target in link.findall(text):
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        path = target.split("#", 1)[0]
        if not path.endswith(".md"):
            continue
        if not os.path.isfile(os.path.join(os.path.dirname(f), path)):
            broken.append(f"{f}: ({target})")
if broken:
    print("broken .md links:\n  " + "\n  ".join(broken), file=sys.stderr)
    sys.exit(1)
print(f"doc links OK ({len(files)} files)")
PY
