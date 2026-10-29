#!/usr/bin/env bash
# Codex CLI "notify" program -> MyNotch. Codex passes one JSON argument when a turn ends.
# In ~/.codex/config.toml:   notify = ["/path/to/integrations/codex/notify.sh"]
# NOT TESTED: written from Codex's documented notify format, check it on your version.
here="$(cd "$(dirname "$0")/.." && pwd)"
payload="${1:-}"
cwd="$(printf '%s' "$payload" | sed -nE 's/.*"cwd"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -n1)"
msg="$(printf '%s' "$payload" | sed -nE 's/.*"last-assistant-message"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n1)"
cd "${cwd:-$PWD}" 2>/dev/null || true
"$here/mynotch-notify" --name "Codex" --state done --message "${msg:-Finished}"
exit 0
