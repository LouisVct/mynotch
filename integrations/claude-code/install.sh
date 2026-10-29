#!/usr/bin/env bash
# Adds the MyNotch hooks to ~/.claude/settings.json (keeps all other settings and hooks).
# Safe to run several times: older MyNotch hooks are replaced, never duplicated.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-mynotch"

python3 - "$SETTINGS" "$DIR" <<'PY'
import json, sys

settings_path, directory = sys.argv[1], sys.argv[2]
settings = json.load(open(settings_path))
wanted = json.loads(open(f"{directory}/hooks.json").read().replace("__MYNOTCH_DIR__", directory))["hooks"]

def is_mynotch(entry):
    return any("mynotch://agent" in h.get("command", "") or "claude-code/notify.sh" in h.get("command", "")
               for h in entry.get("hooks", []))

hooks = settings.setdefault("hooks", {})
# Drop previous MyNotch entries (including the first, link-only version), then add the current ones
for event in list(hooks):
    hooks[event] = [e for e in hooks[event] if not is_mynotch(e)]
    if not hooks[event]:
        del hooks[event]
for event, entries in wanted.items():
    hooks.setdefault(event, []).extend(entries)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"MyNotch hooks installed in {settings_path} (backup: {settings_path}.bak-mynotch)")
PY
