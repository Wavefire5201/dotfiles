#!/usr/bin/env bash
# Deterministic test run for the jisho plugin: unit tests, then the headless QML harnesses.
# No network (fixture server), no clipboard or browser (fake wl-copy/wl-paste/xdg-open).
set -euo pipefail

tests=$(cd "$(dirname "$0")" && pwd)
plugin=$(dirname "$tests")
work=$(mktemp -d)
server_pid=""
qs_pid=""
cleanup() {
  [[ -n $qs_pid ]] && kill "$qs_pid" 2>/dev/null || true
  [[ -n $server_pid ]] && kill "$server_pid" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

fail() {
  echo "FAIL $*"
  [[ -n ${current_log:-} && -f $current_log ]] && { echo "-- log tail ($current_log):"; tail -30 "$current_log"; }
  exit 1
}

echo "== unit tests"
node --test "$tests"/*.test.mjs

echo "== fixture server"
python3 "$tests/fixture_server.py" > "$work/port" &
server_pid=$!
for _ in $(seq 50); do [[ -s $work/port ]] && break; sleep 0.1; done
port=$(head -1 "$work/port")
[[ -n $port ]] || fail "fixture server did not start"

mkdir -p "$work/bin"
export JISHO_CALLS_LOG=$work/calls.log JISHO_SELECTION=$work/selection
: > "$JISHO_CALLS_LOG"
cat > "$work/bin/xdg-open" <<'EOF'
#!/bin/sh
echo "xdg-open $*" >> "$JISHO_CALLS_LOG"
EOF
cat > "$work/bin/wl-copy" <<'EOF'
#!/bin/sh
echo "wl-copy $*" >> "$JISHO_CALLS_LOG"
EOF
cat > "$work/bin/wl-paste" <<'EOF'
#!/bin/sh
echo "wl-paste $*" >> "$JISHO_CALLS_LOG"
if [ -s "$JISHO_SELECTION" ]; then cat "$JISHO_SELECTION"; else echo "No selection" >&2; exit 1; fi
EOF
chmod +x "$work/bin"/*

echo "== logic harness"
harness=$tests/harness
ipc() { qs -p "$harness" ipc call "$@" 2>/dev/null; }
wait_for() { # wait_for <expected> <ipc args...>
  local want=$1; shift
  for _ in $(seq 100); do [[ $(ipc "$@") == "$want" ]] && return 0; sleep 0.1; done
  fail "timed out waiting for '$*' == $want (got '$(ipc "$@")')"
}

current_log=$work/harness.log
PATH=$work/bin:$PATH QT_QPA_PLATFORM=offscreen JISHO_PLUGIN_DIR=$plugin \
  JISHO_SERVER=http://127.0.0.1:$port qs -p "$harness" > "$work/harness.log" 2>&1 &
qs_pid=$!
wait_for ipc harness phase

printf '\n  猫舌 \nsecond line' > "$JISHO_SELECTION"
ipc plugin:jisho lookupSelection
wait_for 1 harness openCount
ipc plugin:jisho lookup "  食べる  "
wait_for 2 harness openCount
: > "$JISHO_SELECTION"
ipc plugin:jisho lookupSelection
wait_for 3 harness openCount
ipc plugin:jisho toggle
ipc harness finish > /dev/null
wait "$qs_pid" || true
qs_pid=""

rg --no-filename -o '(PASS|FAIL) .*' "$work/harness.log" || true
selection_reads=$(rg -c -F 'wl-paste --primary --no-newline --type text' "$JISHO_CALLS_LOG" || echo 0)
[[ $selection_reads == 2 ]] || fail "expected 2 primary-selection reads, saw $selection_reads"
echo "PASS lookupSelection reads the primary selection as text"

problems=$(rg -n 'TypeError|ReferenceError|Error:|WARN.*jisho|jisho/.*\.qml:\d+' "$work/harness.log" | rg -v 'PASS|FAIL|not placed in the graphics scene' || true)
[[ -z $problems ]] || { echo "$problems"; fail "QML errors or warnings from the plugin"; }
echo "PASS no QML warnings from plugin files"

result=$(rg -o 'HARNESS RESULT .*' "$work/harness.log" | tail -1)
echo "$result"
[[ $result == *"failures=0"* ]] || fail "logic harness"

echo "== render harness"
noctalia=/etc/xdg/quickshell/noctalia-shell
root=$work/render-root
export JISHO_RENDER_OUT=${JISHO_RENDER_OUT:-$work/render}
mkdir -p "$root/Services/UI" "$work/config" "$work/cache" "$JISHO_RENDER_OUT"
for e in "$noctalia"/*; do case ${e##*/} in shell.qml | Services) ;; *) ln -s "$e" "$root/" ;; esac; done
for e in "$noctalia"/Services/*; do [[ ${e##*/} == UI ]] || ln -s "$e" "$root/Services/"; done
for e in "$noctalia"/Services/UI/*; do [[ ${e##*/} == ImageCacheService.qml ]] || ln -s "$e" "$root/Services/UI/"; done
cp "$tests/render/ImageCacheService.qml" "$tests/render/shell.qml" "$root/"
mv "$root/ImageCacheService.qml" "$root/Services/UI/"
# The live theme, copied so noctalia's Settings cannot write back to it
for f in settings.json colors.json; do
  [[ -f $HOME/.config/noctalia/$f ]] && cp "$HOME/.config/noctalia/$f" "$work/config/"
done

current_log=$work/render.log
NOCTALIA_CONFIG_DIR=$work/config/ NOCTALIA_CACHE_DIR=$work/cache/ QT_QPA_PLATFORM=offscreen \
  JISHO_PLUGIN_DIR=$plugin JISHO_SERVER=http://127.0.0.1:$port timeout 60 qs -p "$root" > "$current_log" 2>&1 || true
rg --no-filename -o '(PASS|FAIL) .*' "$current_log" || true

problems=$(rg -n 'jisho/(Preview|LauncherProvider|Main)\.qml|jisho/jisho\.js' "$current_log" | rg -v 'PASS|FAIL|not placed in the graphics scene' || true)
[[ -z $problems ]] || { echo "$problems"; fail "QML errors or warnings from the preview"; }
echo "PASS no QML warnings from plugin files"

result=$(rg -o 'RENDER RESULT .*' "$current_log" | tail -1)
echo "$result (screenshots in $JISHO_RENDER_OUT)"
[[ $result == *"failures=0"* ]] || fail "render harness"
