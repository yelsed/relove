#!/usr/bin/env bash
# CLI behavioral test (M1): init copies the manifest, patches main.lua idempotently,
# doctor reports correctly, remove works, copies are byte-identical.
# Run under luajit (LÖVE's interpreter). Usage: test/cli.sh
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$REPO/tools/relove.lua"
GAME="$(mktemp -d)/game"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok   : $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL : $1"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

echo "=== syntax-load every runtime module (LuaJIT) ==="
for f in dev/relove/*.lua tools/relove.lua; do
  if luajit -e "assert(loadfile('$REPO/$f'))" 2>/tmp/relove-syn.err; then ok "loads: $f"
  else bad "loads: $f -> $(cat /tmp/relove-syn.err)"; fi
done

echo "=== no shell deps survive in the hot path ==="
check "no io.popen in runtime" "! grep -rl 'io.popen' $REPO/dev/relove"
check "no cksum shell call in runtime" "! grep -rn 'popen(\"cksum\|execute(\"cksum' $REPO/dev/relove"

echo "=== scaffold + init ==="
mkdir -p "$GAME/src"
printf 'function love.load() end\nfunction love.update(dt) end\nfunction love.draw() end\n' > "$GAME/main.lua"
printf 'function love.conf(t) t.window.title="test" end\n' > "$GAME/conf.lua"
printf 'local P={}\nfunction P.update(p,dt) p.x=p.x+1 end\nreturn P\n' > "$GAME/src/player.lua"
luajit "$CLI" init "$GAME" >/dev/null 2>&1 || bad "init exited nonzero"
for f in dev/relove/init.lua dev/relove/module_registry.lua dev/relove/watcher.lua \
         dev/relove/reloader.lua dev/relove/reporter.lua dev/relove/overlay.lua \
         dev/relove/assets.lua dev/relove.lua tools/relove.lua relove relove.bat; do
  check "copied: $f" "[ -f '$GAME/$f' ]"
done
check ".relove created" "[ -d '$GAME/.relove' ]"
check "main.lua patched" "grep -q 'relove dev hot reload start' '$GAME/main.lua'"
check "backup written" "[ -f '$GAME/main.lua.relove-backup' ]"
check "reloader.lua byte-identical" "cmp -s '$REPO/dev/relove/reloader.lua' '$GAME/dev/relove/reloader.lua'"

echo "=== idempotent init ==="
luajit "$CLI" init "$GAME" >/dev/null 2>&1
check "marker appears once" "[ \"$(grep -c 'relove dev hot reload start' "$GAME/main.lua")\" = '1' ]"

echo "=== doctor ==="
luajit "$CLI" doctor "$GAME" >/tmp/relove-doc.out 2>&1
check "doctor: runtime present ok" "grep -q '\[ok\].*runtime present' /tmp/relove-doc.out"
check "doctor: main.lua patched ok" "grep -q '\[ok\].*main.lua contains' /tmp/relove-doc.out"
check "doctor: .relove writable ok"  "grep -q '\[ok\].*.relove writable' /tmp/relove-doc.out"

echo "=== remove ==="
luajit "$CLI" remove "$GAME" >/dev/null 2>&1
check "marker removed" "! grep -q 'relove dev hot reload start' '$GAME/main.lua'"
check "user code survives" "grep -q 'function love.load' '$GAME/main.lua'"

rm -rf "$GAME"
echo ""
echo "=== cli: $PASS passed, $FAIL failed ==="
[ "$FAIL" = "0" ]
