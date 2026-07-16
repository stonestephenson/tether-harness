# probes/ — de-risking the DESIGN.md verification list

Small, sandboxed experiments that answer the six unknowns in
[`../../paper/DESIGN.md`](../../paper/DESIGN.md) (its "Phase-2 verification list")
before the full runner is built. Results land in [`../FINDINGS.md`](../FINDINGS.md).

Each probe provisions a throwaway `CLAUDE_CONFIG_DIR` under `$TMPDIR` and never
touches the live `~/.claude`. Probes that invoke the model are **user-fired** (your
subscription auth); each ships a model-free `selftest` that validates the plumbing
first so no quota is spent on a broken harness.

## `stop_hook/` — verification items #1, #2, #4

The load-bearing one: what does headless `claude -p` do when a Stop hook blocks?

0. **One-time auth** (sandboxes don't inherit the keychain login — see FINDINGS
   item 1b). Generate a subscription token and export it in the shell you'll fire
   from — zero API cost, never commit it:
   ```
   claude setup-token
   export CLAUDE_CODE_OAUTH_TOKEN='<paste the token it prints>'
   ```
1. **Validate the harness (no model calls, safe to run now):**
   ```
   bash bench/probes/stop_hook/selftest.sh
   ```
2. **P1-real — the real done-gate on a perpetually-red verifier** (the important
   run; ~1 short session):
   ```
   bash bench/probes/stop_hook/run_p1_real.sh
   ```
   Reports done-gate invocation + block counts and the result-JSON field presence.
   *1 block* ⇒ the gate gives a single forced repair-nudge (H1's mechanism wording
   in DESIGN.md must change from "blocks until green"); *>1 block* ⇒ repeated
   enforcement.
3. **P1-raw — the CLI's own ceiling under an unconditional block** (optional; the
   hook self-caps at 6 blocks so quota is bounded):
   ```
   bash bench/probes/stop_hook/run_p1_raw.sh
   ```
   *blocks == cap* ⇒ the CLI loops as long as the hook blocks (our run-time cap is
   load-bearing); *< cap* ⇒ the CLI enforces its own turn ceiling.

**If either firing prints `EMPTY result` / an auth error:** a fresh
`CLAUDE_CONFIG_DIR` doesn't inherit your login — that is itself a finding for the
runner's auth design (record it in FINDINGS.md item #1/#2). Complete the login it
prompts for, or note how the sandbox must be authenticated, then re-fire.

Paste the console output back and it gets recorded in FINDINGS.md.
