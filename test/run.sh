#!/usr/bin/env bash
# Runs the relove test suite. luajit is required (it is LÖVE's interpreter and
# runs the runtime + CLI tests). node and nvim are optional (editor adapters).
# Usage: test/run.sh
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=0
have() { command -v "$1" >/dev/null 2>&1; }
run() {
  local label="$1"; shift
  echo "### $label"
  if "$@"; then echo "PASS: $label"; else echo "FAIL: $label"; FAILED=1; fi
  echo
}

if have luajit; then
  run "reload_veto (M2)"   luajit "$DIR/reload_veto.lua"
  run "config_ignore (M3)" luajit "$DIR/config_ignore.lua"
  run "asset_reload (M4)"  luajit "$DIR/asset_reload.lua"
  run "main_reload (M4)"   luajit "$DIR/main_reload.lua"
  run "cli (M1)"           bash "$DIR/cli.sh"
else
  echo "SKIP+FAIL: luajit not found (required for runtime + CLI tests)"; FAILED=1
fi

if have node; then run "vscode_extension (M3)" node "$DIR/vscode_extension.js"
else echo "SKIP: node not found (VS Code adapter test)"; echo; fi

if have nvim; then run "nvim_adapter (M3)" nvim --headless -l "$DIR/nvim_adapter.lua"
else echo "SKIP: nvim not found (Neovim adapter test)"; echo; fi

echo "======================================"
if [ "$FAILED" = 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi
exit $FAILED
