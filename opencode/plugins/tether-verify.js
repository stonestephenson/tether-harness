// tether — verification hooks for opencode.
//   tool.execute.after (edit/write) -> verify-on-edit.py; the diagnostics are appended to
//     the tool result so the AGENT sees and fixes them (this closes the verification loop).
//   session.idle -> done-gate.py; runs the project's fast check (.tether/verify.sh or
//     $VERIFY_CMD) and surfaces failures (incl. the verifier-integrity tamper report).
//   experimental.session.compacting -> pre-compact-guard.py; a dirty git tree gets its
//     state INJECTED into the compaction prompt (opencode cannot block a compaction —
//     inverse of Claude Code's PreCompact, which blocks but cannot inject).
// Reuses the shared Python hook scripts. Verified on opencode 1.17.15.
// (opencode delivers bus events through a single `event` hook you switch on by type;
//  the file path for an edit is in the edit tool's args.filePath.)
//
// The port's contract: opencode events are translated into the Claude-Code-shaped
// JSON the shared Python expects — verify-on-edit gets {tool_name:"Edit",
// tool_input:{file_path}}, done-gate gets {hook_event_name:"Stop", cwd, session_id}
// (session_id keys the tamper baseline; a stale cross-session baseline would
// false-flag), pre-compact-guard gets {cwd, session_id}. A hook signals "problem"
// with a non-zero exit + text on stderr; verify-on-edit's stderr is appended to the
// tool result (the agent sees it), done-gate's and pre-compact-guard's are surfaced
// via console.error; pre-compact-guard's STDOUT is appended to the compaction
// prompt. NOTE: done-gate fires on session.idle, which under headless
// `opencode run` may not complete before the process exits — it is reliable in an
// interactive session.
import { dirname } from "node:path";

export const TetherPlugin = async (factory) => {
  const $ = factory.$;
  const HOOKS = `${process.env.HOME}/.config/opencode/tether/hooks`;
  let projectDir = process.cwd();

  const runHook = async (script, payload) => {
    try {
      return await $`echo ${payload} | python3 ${HOOKS}/${script}`.quiet().nothrow();
    } catch (_) {
      return null; // a verification hook must never break the session
    }
  };

  return {
    "tool.execute.after": async (input, output) => {
      if (input?.tool !== "edit" && input?.tool !== "write") return;
      const path = input?.args?.filePath;
      if (!path) return;
      projectDir = dirname(path);
      const r = await runHook(
        "verify-on-edit.py",
        JSON.stringify({ tool_name: "Edit", tool_input: { file_path: path } }),
      );
      if (r && r.exitCode !== 0 && r.stderr?.length && output) {
        output.output = (output.output ?? "") + `\n\n${r.stderr.toString()}`; // feed the agent
      }
    },
    event: async (arg) => {
      const event = arg?.event ?? arg;
      if (event?.type !== "session.idle") return;
      const r = await runHook(
        "done-gate.py",
        JSON.stringify({
          hook_event_name: "Stop",
          cwd: projectDir,
          session_id: event?.properties?.sessionID ?? "default",
        }),
      );
      if (r && r.exitCode !== 0 && r.stderr?.length) console.error(r.stderr.toString());
    },
    "experimental.session.compacting": async (input, output) => {
      const r = await runHook(
        "pre-compact-guard.py",
        JSON.stringify({ cwd: projectDir, session_id: input?.sessionID ?? "default" }),
      );
      if (!r || r.exitCode === 0) return; // clean tree (or the guard failed open)
      const context = r.stdout?.toString().trim();
      if (context && output?.context) output.context.push(context); // prime the summary
      if (r.stderr?.length) console.error(r.stderr.toString()); // tell the user
    },
  };
};
