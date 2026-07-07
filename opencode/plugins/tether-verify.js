// tether — verification hooks for opencode.
//   file.edited  -> per-edit checks (verify-on-edit.py): real-bug lint always;
//                   formatting/style only if the project ships a style config.
//   session.idle -> project verify gate (done-gate.py): runs .tether/.codex/.claude
//                   verify.sh (or $VERIFY_CMD) and surfaces failures.
// Reuses the shared Python hook scripts. A verification hook must never break the
// session, so every failure path is swallowed except the diagnostics we surface.
export const TetherPlugin = async ({ $ }) => {
  const HOOKS = `${process.env.HOME}/.config/opencode/tether/hooks`;

  const run = async (script, payload) => {
    try {
      const r = await $`echo ${payload} | python3 ${HOOKS}/${script}`.quiet().nothrow();
      if (r.exitCode !== 0 && r.stderr && r.stderr.length) {
        console.error(r.stderr.toString()); // surface diagnostics / failures
      }
    } catch (_) {
      /* never break the session because a hook errored */
    }
  };

  return {
    "file.edited": async (input) => {
      const path = input.filePath || input.file || input.path;
      if (!path) return;
      await run(
        "verify-on-edit.py",
        JSON.stringify({ tool_name: "Edit", tool_input: { file_path: path } }),
      );
    },
    "session.idle": async () => {
      await run(
        "done-gate.py",
        JSON.stringify({ hook_event_name: "Stop", cwd: process.cwd() }),
      );
    },
  };
};
