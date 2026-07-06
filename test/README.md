# relove tests

Runnable checks over the real runtime modules. No test framework — each file is a
plain script that exits non-zero on failure.

```bash
test/run.sh
```

`luajit` is required (it is the interpreter LÖVE embeds, so it runs the runtime
and CLI without a full LÖVE/GUI session — the tests stub `love.*`). `node` and
`nvim` are optional and only gate the editor-adapter tests.

| File | Covers | Runner |
|------|--------|--------|
| `reload_veto.lua` | module reload + `__accept` veto + re-save re-attempt (M2) | `luajit` |
| `config_ignore.lua` | `.relove.lua` merge, ignore globs, malformed-config crash-proofing (M3) | `luajit` |
| `asset_reload.lua` | `relove.image/shader/audio` intern + in-place/swap reload (M4) | `luajit` |
| `main_reload.lua` | opt-in `main.lua` re-run vs restart-required (M4) | `luajit` |
| `cli.sh` | `init`/`doctor`/`remove`, manifest copy, idempotency (M1) | `luajit` |
| `vscode_extension.js` | `parseStackFrames` traceback → related-info (M3) | `node` |
| `nvim_adapter.lua` | Neovim adapter diagnostics + fs-watch (M3) | `nvim --headless -l` |

## What these do not cover

These are logic tests with `love.*` stubbed. The on-screen path (overlay
rendering, real physfs freshness, a texture visually swapping) is verified by
running a real LÖVE game — see the project notes. Run a game with
`love <project>` and edit a module to watch it live.
