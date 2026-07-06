# relove — ideas

Loose roadmap for the LÖVE hot-reload runtime. Nothing here is committed to a
version; it's a place to capture directions worth exploring.

## Portability

- **Windows-ready backend.** Replace the POSIX shell deps (`cat`, `cksum`,
  `cp -R`, `mkdir -p`, `chmod`) with portable implementations. Read files via
  `love.filesystem.read`; hash in pure Lua; drop `io.popen` from the hot path.
- **Shell-free wrapper.** Ship the CLI so it runs under `lua` directly on any OS
  instead of the `sh` wrapper.

## Reload engine

- **Asset hot reload.** Watch images, shaders, and audio; swap them in place the
  way modules are swapped now.
- **State-preserving reload for `main.lua`.** Currently restart-only. Explore
  re-running boot code while keeping live state, behind an opt-in flag.
- **Per-module hooks.** Document and expand `__dispose` / `__hotreload`; add an
  `__accept` predicate so a module can veto a reload it can't safely take.
- **Coroutine-safe reload.** Detect modules with suspended coroutines and defer
  the swap instead of tearing state.

## Feedback

- **Editor-agnostic protocol.** The `.relove/status.json` contract could feed a
  Neovim/Emacs adapter, not just VS Code.
- **In-overlay history.** Keep the last N reload events in the overlay, not just
  the current status.
- **Error deep-links.** Make overlay/editor stack lines clickable to the source.

## Tooling

- **`relove doctor`.** One command that checks LÖVE version, PATH utilities, and
  whether the game is patched correctly.
- **Config file.** Optional `.relove.toml` for interval, overlay key, and
  ignore globs, instead of only inline `start(options)`.
