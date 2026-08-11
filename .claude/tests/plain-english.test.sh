#!/usr/bin/env bash
# Regression test for .claude/hooks/plain-english.py (personal maintainer tooling).
# Run:  bash .claude/tests/plain-english.test.sh   (from the repo root)
# Hermetic: a stub HTTP server stands in for Ollama, so no model is required and
# nothing touches ~/.claude. Exits non-zero if any assertion fails.
# Panels are keyed on the session's cwd, so run() passes cwd=/p/<session>
# and the expected panel file is out/-p-<session>.md.

HOOK="$(cd "$(dirname "$0")/../hooks" && pwd)/plain-english.py"
T="$(mktemp -d "${TMPDIR:-/tmp}/tether-plain.XXXXXX")"
STATE_DIR="$(python3 -c 'import os,tempfile;print(os.path.join(tempfile.gettempdir(),"claude-plain-english-state"))')"
pass=0
fail=0

STUBS=()
cleanup() { for pid in "${STUBS[@]:-}"; do [[ -n "$pid" ]] && kill "$pid" 2>/dev/null; done; rm -rf "$T"; rm -f "$STATE_DIR"/pe_*; }
trap cleanup EXIT
rm -f "$STATE_DIR"/pe_*

export PLAIN_DIR="$T/out"
export PLAIN_MIN_CHARS=1200
unset PLAIN_DISABLE

# --- stub Ollama: echoes a fixed panel, and reports a prompt_eval_count we control ---
cat > "$T/stub.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
PE = int(sys.argv[2]) if len(sys.argv) > 2 else 500
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        user = body["messages"][-1]["content"]
        open(sys.argv[3], "w").write(str(len(user)))          # record what we received
        out = "<think>ignore me</think>BOTTOM LINE\nstub ok\n\nNEEDS YOU\nNothing — FYI only."
        self.send_response(200); self.send_header("Content-Type","application/json"); self.end_headers()
        self.wfile.write(json.dumps({"message":{"content":out},"prompt_eval_count":PE}).encode())
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY

PORT=11533
python3 "$T/stub.py" "$PORT" 500 "$T/received.txt" >/dev/null 2>&1 & STUB_PID=$!; STUBS+=("$STUB_PID")
disown %% 2>/dev/null || true
export PLAIN_OLLAMA_URL="http://127.0.0.1:$PORT/api/chat"
for _ in $(seq 1 40); do
  python3 -c "import socket,sys; s=socket.socket(); sys.exit(0 if s.connect_ex(('127.0.0.1',$PORT))==0 else 1)" && break
  sleep 0.1
done

# --- fixtures ---
long_text() { python3 -c "print('The gate is green and I committed on main. ' * 40)"; }
mk() { # file  text  [extra-json-per-line]
  python3 - "$1" "$2" "${3:-}" <<'PY'
import json, sys
path, text, extra = sys.argv[1], sys.argv[2], sys.argv[3]
rec = {"type":"assistant","uuid":"u-"+str(abs(hash(text))%10**8),
       "message":{"content":[{"type":"text","text":text}]}}
if extra: rec.update(json.loads(extra))
open(path,"w").write(json.dumps(rec)+"\n")
PY
}

run() { # transcript  session  [extra json fields]
  local tr="$1" sess="$2" extra="${3:-}"
  python3 - "$tr" "$sess" "$extra" <<'PY' | python3 "$HOOK"
import json, sys
d = {"session_id": sys.argv[2], "hook_event_name": "Stop", "transcript_path": sys.argv[1],
     "cwd": "/p/" + sys.argv[2]}
if sys.argv[3]: d.update(json.loads(sys.argv[3]))
print(json.dumps(d))
PY
}

wait_file() { for _ in $(seq 1 60); do [[ -s "$1" ]] && return 0; sleep 0.1; done; return 1; }

check() { # desc  actual  mode  expected
  local desc="$1" actual="$2" mode="$3" expected="$4" ok=0
  case "$mode" in
    contains) [[ "$actual" == *"$expected"* ]] && ok=1 ;;
    absent)   [[ "$actual" != *"$expected"* ]] && ok=1 ;;
    empty)    [[ -z "$actual" ]] && ok=1 ;;
    eq)       [[ "$actual" == "$expected" ]] && ok=1 ;;
  esac
  if [[ $ok -eq 1 ]]; then printf 'PASS  %s\n' "$desc"; pass=$((pass+1))
  else printf 'FAIL  %s\n      got: %s\n' "$desc" "${actual:-<empty>}"; fail=$((fail+1)); fi
}

LONG="$(long_text)"
mk "$T/long.jsonl" "$LONG"
mk "$T/short.jsonl" "too short to bother"
mk "$T/side.jsonl" "$LONG" '{"isSidechain":true}'
python3 - "$T/tooluse.jsonl" <<'PY'
import json
rec={"type":"assistant","uuid":"u-tool","message":{"content":[
  {"type":"text","text":"x"*1500},{"type":"tool_use","id":"t1","name":"Bash","input":{}}]}}
open("/dev/stdin".replace("/dev/stdin","")or None,"w") if False else open(__import__("sys").argv[1],"w").write(json.dumps(rec)+"\n")
PY

# --- the three load-bearing properties ---

# T1 the hook is silent on stdout, always. Anything here would reach the agent.
o=$(run "$T/long.jsonl" pe_a)
check "long response: hook stdout is empty"      "$o" empty ""
check "long response: no additionalContext"      "$o" absent "additionalContext"

# T2 it returns immediately — the turn must not wait on inference
start=$(python3 -c 'import time;print(time.time())')
run "$T/long.jsonl" pe_speed >/dev/null
elapsed=$(python3 -c "import time;print(int((time.time()-$start)*1000))")
check "hook returns in <1500ms (detached)"       "$( ((elapsed<1500)) && echo ok )" eq "ok"

# T3 the panel actually lands
check "panel file written"                       "$(wait_file "$T/out/-p-pe_a.md" && echo ok)" eq "ok"
panel="$(cat "$T/out/-p-pe_a.md")"
check "panel contains the summary"               "$panel" contains "BOTTOM LINE"
check "panel strips <think> blocks"              "$panel" absent "ignore me"
check "panel records model + timing"             "$panel" contains "qwen3:8b"
check "worker received the FULL message"         "$(cat "$T/received.txt")" eq "${#LONG}"

# --- gating ---
check "short response is skipped"                "$(run "$T/short.jsonl" pe_b; ls "$T/out/-p-pe_b.md" 2>&1)" contains "No such file"
check "sidechain turn is skipped"                "$(run "$T/side.jsonl" pe_c; ls "$T/out/-p-pe_c.md" 2>&1)" contains "No such file"
check "turn ending in tool_use is skipped"       "$(run "$T/tooluse.jsonl" pe_d; ls "$T/out/-p-pe_d.md" 2>&1)" contains "No such file"
check "stop_hook_active is skipped"              "$(run "$T/long.jsonl" pe_e '{"stop_hook_active":true}'; ls "$T/out/-p-pe_e.md" 2>&1)" contains "No such file"
check "PLAIN_DISABLE is honored"                 "$(PLAIN_DISABLE=1 run "$T/long.jsonl" pe_f; ls "$T/out/-p-pe_f.md" 2>&1)" contains "No such file"

# --- dedupe: Stop fires repeatedly for one message ---
run "$T/long.jsonl" pe_g >/dev/null; wait_file "$T/out/-p-pe_g.md"
run "$T/long.jsonl" pe_g >/dev/null; sleep 0.6
check "same message rendered only once"          "$(grep -c 'BOTTOM LINE' "$T/out/-p-pe_g.md")" eq "1"

# --- fail open ---
o=$(run "/no/such/transcript.jsonl" pe_h); check "missing transcript is silent" "$o" empty ""
o=$(printf 'not json' | python3 "$HOOK"); rc=$?
check "garbage stdin is silent"                  "$o" empty ""
check "garbage stdin exits 0"                    "$rc" eq "0"
o=$(printf '[]' | python3 "$HOOK"); rc=$?
check "non-dict stdin exits 0"                   "$rc" eq "0"

# ollama down: hook still silent+0, and the pane says why rather than staying blank
kill "$STUB_PID" 2>/dev/null; STUB_PID=""; sleep 0.3
o=$(run "$T/long.jsonl" pe_i); rc=$?
check "ollama down: hook still silent"           "$o" empty ""
check "ollama down: hook still exits 0"          "$rc" eq "0"
check "ollama down: failure is visible in pane"  "$(wait_file "$T/out/-p-pe_i.md" && cat "$T/out/-p-pe_i.md")" contains "summariser unavailable"

# --- truncation tripwire: the failure that otherwise looks like success ---
PORT2=11534
python3 "$T/stub.py" "$PORT2" 16380 "$T/received2.txt" >/dev/null 2>&1 & STUB_PID=$!; STUBS+=("$STUB_PID")
disown %% 2>/dev/null || true
for _ in $(seq 1 40); do
  python3 -c "import socket,sys; s=socket.socket(); sys.exit(0 if s.connect_ex(('127.0.0.1',$PORT2))==0 else 1)" && break
  sleep 0.1
done
PLAIN_OLLAMA_URL="http://127.0.0.1:$PORT2/api/chat" run "$T/long.jsonl" pe_j >/dev/null
check "near-num_ctx prompt raises a truncation warning" \
  "$(wait_file "$T/out/-p-pe_j.md" && cat "$T/out/-p-pe_j.md")" contains "may have been truncated"

# --- pane naming: this is what makes `plain` work with no arguments ---
# Restart the stub (the ollama-down test killed it).
PORT3=11535
python3 "$T/stub.py" "$PORT3" 500 "$T/received3.txt" >/dev/null 2>&1 & STUB_PID=$!; STUBS+=("$STUB_PID")
disown %% 2>/dev/null || true
for _ in $(seq 1 40); do
  python3 -c "import socket,sys; s=socket.socket(); sys.exit(0 if s.connect_ex(('127.0.0.1',$PORT3))==0 else 1)" && break
  sleep 0.1
done
export PLAIN_OLLAMA_URL="http://127.0.0.1:$PORT3/api/chat"

# two DIFFERENT sessions sharing one cwd must land in one pane, each tagged
sendcwd() { # transcript  session  cwd
  python3 - "$1" "$2" "$3" <<'PY' | python3 "$HOOK"
import json, sys
print(json.dumps({"session_id": sys.argv[2], "hook_event_name": "Stop",
                  "transcript_path": sys.argv[1], "cwd": sys.argv[3]}))
PY
}
mk "$T/t1.jsonl" "$LONG one"
mk "$T/t2.jsonl" "$LONG two"
sendcwd "$T/t1.jsonl" aaa111 /Users/x/repos/demo >/dev/null
wait_file "$T/out/-Users-x-repos-demo.md"
sendcwd "$T/t2.jsonl" bbb222 /Users/x/repos/demo >/dev/null
sleep 0.8
shared="$(cat "$T/out/-Users-x-repos-demo.md" 2>/dev/null)"
check "cwd (not session id) names the pane"    "$(ls "$T/out/" | grep -c 'demo')" eq "1"
check "two sessions in one cwd share the pane" "$(grep -c 'BOTTOM LINE' "$T/out/-Users-x-repos-demo.md")" eq "2"
check "each panel is tagged with its session"  "$shared" contains "[aaa111]"
check "second session tagged distinctly"       "$shared" contains "[bbb222]"

# missing cwd must still produce a pane rather than dropping the panel
python3 - "$T/t1.jsonl" <<'PY' | python3 "$HOOK"
import json, sys
print(json.dumps({"session_id":"nocwd9","hook_event_name":"Stop","transcript_path":sys.argv[1]}))
PY
check "no cwd falls back to session id"        "$(wait_file "$T/out/nocwd9.md" && echo ok)" eq "ok"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
