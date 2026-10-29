#!/usr/bin/env bash
# Adds the MyNotch alert hooks to ~/.claude/settings.json (keeps existing settings and hooks).
# Safe to run several times: hooks already containing "mynotch://agent" are not added twice.
set -euo pipefail

SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
HOOKS="$(cd "$(dirname "$0")" && pwd)/hooks.json"

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-mynotch"

python3 - "$SETTINGS" "$HOOKS" <<'PY'
import json, sys

settings_path, hooks_path = sys.argv[1], sys.argv[2]
settings = json.load(open(settings_path))
wanted = json.load(open(hooks_path))["hooks"]

existing = settings.setdefault("hooks", {})
for event, entries in wanted.items():
    current = existing.setdefault(event, [])
    already = any("mynotch://agent" in h.get("command", "")
                  for e in current for h in e.get("hooks", []))
    if not already:
        current.extend(entries)

json.dump(settings, open(settings_path, "w"), indent=2, ensure_ascii=False)
open(settings_path, "a").write("\n")
print(f"MyNotch hooks installed in {settings_path} (backup: {settings_path}.bak-mynotch)")
PY
