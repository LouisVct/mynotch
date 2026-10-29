#!/usr/bin/env bash
# Claude Code hook -> MyNotch. Usage: notify.sh <working|input|done|end>
# Reads the hook JSON on stdin, then opens a mynotch://agent link. Never fails the hook.
state="${1:-input}"

HOOK_INPUT="$(cat 2>/dev/null || true)" python3 - "$state" <<'PY' 2>/dev/null || true
import json, os, subprocess, sys
from urllib.parse import urlencode

state = sys.argv[1]
try:
    data = json.loads(os.environ.get("HOOK_INPUT") or "{}")
except ValueError:
    data = {}

# App that hosts this session (terminal, editor, Claude app...) so the notch can jump back to it
terminal = os.environ.get("__CFBundleIdentifier", "")
if not terminal:
    terminal = {
        "Apple_Terminal": "com.apple.Terminal",
        "iTerm.app": "com.googlecode.iterm2",
        "vscode": "com.microsoft.VSCode",
        "ghostty": "com.mitchellh.ghostty",
        "WarpTerminal": "dev.warp.Warp-Stable",
    }.get(os.environ.get("TERM_PROGRAM", ""), "")

params = {
    "name": "Claude Code",
    "state": state,
    "session": data.get("session_id", ""),
    "project": os.path.basename((data.get("cwd") or "").rstrip("/")),
    "terminal": terminal,
}
if state == "input":
    params["message"] = data.get("message") or "Needs your attention"
elif state == "done":
    params["message"] = "Finished"

params = {k: v for k, v in params.items() if v}
subprocess.run(["open", "-g", "mynotch://agent?" + urlencode(params)], check=False)
PY
exit 0
