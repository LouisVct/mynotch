#!/usr/bin/env bash
# Records what macOS sends to MyNotch about the current track, to debug wrong covers.
#   tools/capture-nowplaying.sh [seconds]      (default 60)
# Change track a few times while it runs. Output: /tmp/mynotch-capture/log.txt (+ the covers as images).
# Uses the same adapter and the same "diff" stream as the app. Read only: it controls nothing.
secs="${1:-60}"
APP="${MYNOTCH_APP:-/Applications/MyNotch.app}"
out=/tmp/mynotch-capture
rm -rf "$out"; mkdir -p "$out"
echo "Capturing for ${secs}s... change track now (Ctrl-C to stop early)"

( perl "$APP/Contents/Resources/mediaremote-adapter.pl" "$APP/Contents/Frameworks/MediaRemoteAdapter.framework" stream & echo $! > "$out/pid"; wait ) 2>&1 |
python3 -u -c '
import sys, json, hashlib, base64, time
out = "/tmp/mynotch-capture"
log = open(out + "/log.txt", "w")
t0 = time.time()
n = 0
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try: d = json.loads(line)
    except ValueError: continue
    p = d.get("payload", d)
    n += 1
    art = p.get("artworkData")
    h = "-"
    if art:
        b = base64.b64decode(art.strip())
        h = hashlib.sha1(b).hexdigest()[:8]
        open(f"{out}/{h}.jpg", "wb").write(b)
    row = "%6.2fs #%-3d diff=%-5s art=%-8s title=%r album=%r playing=%s keys=%s" % (
        time.time() - t0, n, d.get("diff"), h, p.get("title"), p.get("album"), p.get("playing"),
        ",".join(k for k in p if k not in ("artworkData","elapsedTime","timestamp")))
    print(row); log.write(row + "\n"); log.flush()
' &
reader=$!
sleep "$secs"
kill "$(cat "$out/pid" 2>/dev/null)" 2>/dev/null; kill $reader 2>/dev/null
echo "Done. Log: $out/log.txt"
