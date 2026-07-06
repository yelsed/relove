#!/bin/sh
# relove installer — installs the relove CLI without Homebrew.
#
#   curl -fsSL https://raw.githubusercontent.com/yelsed/relove/master/install.sh | sh
#
# Environment overrides:
#   RELOVE_VERSION   git tag to install, e.g. v0.1.0 (default: master)
#   RELOVE_PREFIX    where the runtime is placed   (default: $HOME/.relove)
#   RELOVE_BIN       where the `relove` wrapper goes (default: $HOME/.local/bin)
set -eu

REPO="yelsed/relove"
PREFIX="${RELOVE_PREFIX:-$HOME/.relove}"
BIN="${RELOVE_BIN:-$HOME/.local/bin}"
VERSION="${RELOVE_VERSION:-master}"

have() { command -v "$1" >/dev/null 2>&1; }

# LÖVE ships luajit, so a game machine often has luajit but no standalone lua.
if have lua; then LUA=lua
elif have luajit; then LUA=luajit
else
  echo "relove: need lua or luajit on PATH (LÖVE ships luajit)." >&2
  exit 1
fi

case "$VERSION" in
  master) URL="https://github.com/$REPO/archive/refs/heads/master.tar.gz" ;;
  *)      URL="https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz" ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "relove: downloading $URL"
if have curl; then curl -fsSL "$URL" -o "$TMP/relove.tar.gz"
elif have wget; then wget -qO "$TMP/relove.tar.gz" "$URL"
else echo "relove: need curl or wget." >&2; exit 1
fi

tar -xzf "$TMP/relove.tar.gz" -C "$TMP"
SRC="$(find "$TMP" -maxdepth 1 -type d -name 'relove-*' | head -n 1)"
if [ -z "$SRC" ]; then
  echo "relove: unexpected archive layout." >&2
  exit 1
fi

mkdir -p "$PREFIX" "$BIN"
rm -rf "$PREFIX/dev" "$PREFIX/tools"
cp -R "$SRC/dev" "$SRC/tools" "$PREFIX/"

cat > "$BIN/relove" <<SH
#!/bin/sh
export RELOVE_RUNTIME="$PREFIX"
exec $LUA "$PREFIX/tools/relove.lua" "\$@"
SH
chmod +x "$BIN/relove"

echo "relove: installed $BIN/relove (runtime in $PREFIX, interpreter $LUA)"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "relove: add $BIN to your PATH, e.g.:"
     echo "  export PATH=\"$BIN:\$PATH\"" ;;
esac
