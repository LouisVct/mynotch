#!/usr/bin/env bash
# Claude Code hook -> MyNotch. Usage: notify.sh <working|input|done|end>
# Reads the hook JSON on stdin and opens a mynotch://agent link.
# Plain bash on purpose: it also runs after every tool call, so it has to be fast.
# Never fails the hook.
state="${1:-input}"
input="$(cat 2>/dev/null || true)"

field() {
  printf '%s' "$input" | sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n1
}

urlenc() {
  local LC_ALL=C s="$1" i c out=""
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) out+="$(printf '%%%02X' "'$c")" ;;
    esac
  done
  printf '%s' "$out"
}

# "Claude is waiting for your input" comes 60 s after Stop: the "done" banner already covered it
[ "$(field notification_type)" = "idle_prompt" ] && exit 0

session="$(field session_id)"
cwd="$(field cwd)"
project="${cwd##*/}"
message="$(field message)"
message="${message//\\\"/\"}"

# App hosting this session (terminal, editor, Claude app...), so the notch can jump back to it
terminal="${__CFBundleIdentifier:-}"
if [ -z "$terminal" ]; then
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal) terminal="com.apple.Terminal" ;;
    iTerm.app) terminal="com.googlecode.iterm2" ;;
    vscode) terminal="com.microsoft.VSCode" ;;
    ghostty) terminal="com.mitchellh.ghostty" ;;
    WarpTerminal) terminal="dev.warp.Warp-Stable" ;;
  esac
fi

query="name=Claude%20Code&state=$(urlenc "$state")"
[ -n "$session" ] && query+="&session=$(urlenc "$session")"
[ -n "$project" ] && query+="&project=$(urlenc "$project")"
[ -n "$terminal" ] && query+="&terminal=$(urlenc "$terminal")"
case "$state" in
  input) query+="&message=$(urlenc "${message:-Needs your attention}")" ;;
  done) query+="&message=Finished" ;;
esac

open -g "mynotch://agent?$query" >/dev/null 2>&1 || true
exit 0
