# relove — implementation plan

Turns `IDEAS.md` into a sequenced, buildable roadmap that fits the current
runtime. Derived from reading the whole runtime (`dev/relove/*.lua`),
`tools/relove.lua`, the `relove` wrapper, `editor/vscode-relove/extension.js`,
and `README.md`.

Decisions locked with the owner before writing this plan:

- **Windows must work soon** → the portability pass leads the roadmap, and it
  covers the *install path* and *wrapper*, not just the hot path.
- **Config is `.relove.lua`** (a Lua file that returns a table), not TOML — no
  parser to write or bundle.
- **Full asset reload** (images + shaders + audio) is in scope, but lands last
  and stays **opt-in**, because it's the one idea that fights the project's
  "not a framework, no required asset pipeline" rule.

---

## How the runtime works today (the constraints the plan must respect)

1. **The reload trick only works because Lua modules are tables.**
   `reloader.lua:shallowPatchTable` mutates the *old* exported table in place, so
   every live `local X = require("...")` reference keeps working. Anything that
   is **userdata** (LÖVE `Image`, `Shader`, `Source`) cannot be patched this way —
   that's the whole difficulty of asset reload.

2. **`.relove/` status files must be written to the game's *source* directory,**
   not LÖVE's save directory. `reporter.lua` writes with `io.open` against an
   absolute path from `love.filesystem.getSource()` precisely because
   `love.filesystem.write` targets the save dir, where the editor isn't looking.

3. **Shell usage already has pure-Lua / `love.filesystem` fallbacks** — except
   one primitive:
   - `reloader.readFile` → `io.popen("cat")` then `io.open` then
     `love.filesystem.read` (pure-Lua path already present).
   - `watcher.checksum` → `io.popen("cksum")` then a pure-Lua rolling hash
     (already present).
   - `reporter.ensureProjectStateDir` → `os.execute("mkdir -p")`. **This is the
     only genuinely un-portable primitive** — pure Lua cannot create a directory,
     and `love.filesystem.createDirectory` would create it in the *save* dir, not
     the source dir. Everything else can drop the shell today.

4. **`tools/relove.lua` runs under plain `lua`, not LÖVE** — so it has **no
   `love.filesystem`** available. Its `cp -R` / `cp` / `chmod` / `cd && love .`
   are the biggest POSIX dependency in the project, and IDEAS.md's two
   portability bullets don't squarely name them. Real Windows support has to
   replace these too.

5. **Baseline is already LÖVE 11.x.** `watcher.lua` uses
   `love.filesystem.getInfo(path).modtime`, which is 11.0+. **Nothing in this
   roadmap needs LÖVE 12** — image reference-swap, shader recompile, and Lua
   config all work on 11.x. No version bump anywhere.

---

## Per-idea assessment

Effort: **S** ≤ half a day, **M** ~1–2 days, **L** multi-day.

| ID | Idea (from IDEAS.md) | Effort | Risk | LÖVE bump | Depends on | Conflicts / notes |
|----|----------------------|:------:|:----:|:---------:|------------|-------------------|
| **P1** | Windows-ready backend (hot path) | M | Med | No | — | Fallbacks already exist; risk is `love.filesystem.read` freshness on editor saves (the reason `cat`/`cksum` are there). |
| **P2** | Shell-free wrapper **+ install path** | M/L | Low–Med | No | — | IDEAS under-specifies: the real work is `cp -R`/`chmod`/`cd&&love` in the CLI, which runs without `love.filesystem`. |
| **R3** | `__accept` predicate + document `__dispose`/`__hotreload` | S | Low | No | — | Purely additive in `reloader:reloadModule`. Hooks already half-exist. |
| **R4** | Coroutine-safe reload | L (auto) / free (convention) | Med | No | R3 | **No general mechanism** — Lua has no coroutine registry. Automatic detection is impractical; folds into R3 as an `__accept` convention (a module with a live coroutine returns `false`). |
| **F2** | In-overlay history (last N events) | S | Low | No | — | Self-contained in `overlay.lua`; data already flows through `setStatus`. |
| **F3** | Error deep-links | S–M | Low | No | stack present | **Overlay-clickable is impractical** (LÖVE can't open an editor). Realistic scope = VS Code `DiagnosticRelatedInformation` from the parsed `stack`. |
| **F1** | Editor-agnostic protocol → Neovim adapter | M | Low | No | schemaVersion | Contract is already JSON; work is a documented+versioned schema + a Neovim client. |
| **T1** | `relove doctor` | S | Low | No | — | New CLI subcommand. Doubles as the verification tool for the whole port. |
| **T2** | Config file | S | Low | No | — | Switched TOML→`.relove.lua` (zero parser). "ignore globs" adds a small matcher in the registry/watcher. |
| **R1** | Asset hot reload (full: image+shader+audio) | L | High | No | P1 | **Conflicts** with "no required asset pipeline"; userdata can't patch in place → needs an interned registry the game reads through. Keep **opt-in**. |
| **R2** | State-preserving `main.lua` reload | M–L | High | No | — | **Conflicts** with the explicit README section warning against exactly this. Keep behind an **opt-in flag**; adopt new callbacks without re-calling `love.load`. |

### Flagged conflicts with the current architecture

- **R1 (full assets)** and **R2 (main.lua reload)** are the only two ideas that
  fight documented design promises. Both are quarantined into the last milestone
  and made opt-in so a game that ignores them is byte-for-byte unaffected.
- **R4 (coroutine-safe)** as an *automatic* feature has no sound implementation;
  the plan delivers the *achievable* version (a veto convention) via R3 and says
  so rather than pretending to auto-detect.
- **F3 overlay deep-links** is partly impossible (no OS handoff from LÖVE); the
  plan scopes it to the editor side only.

---

## Sequenced roadmap (milestones, not a flat list)

**Start here — the two highest-value / lowest-risk wins:**

1. **`relove doctor` (T1)** — first task of Milestone 1. It's an S-effort,
   zero-dependency win *and* the environment check you'll lean on to confirm the
   Windows port actually works. Build the verifier before the thing it verifies.
2. **`__accept` hook (R3)** — a ~15-line correctness win in `reloader.lua` with no
   dependencies and no version bump; it also absorbs the coroutine-safety idea.

### Milestone 1 — Cross-platform core *(the opener; Windows-soon)*
Goal: `relove` installs and runs identically on Windows, Linux, macOS, with no
shell in the hot path and no `cp`/`chmod`/`cd` in the install path.
- **T1** `relove doctor` (do first)
- **P1** hot-path shell removal (`reloader.readFile`, `watcher.checksum`)
- reporter source-dir `mkdir` made OS-aware (the one hard primitive)
- **P2** install-path shell removal in `tools/relove.lua` + `relove.bat` wrapper

*Deep-dived below.*

### Milestone 2 — Reload correctness & feedback *(fast, low-risk)*
Goal: safer reloads and a more useful overlay, all additive.
- **R3** `__accept` predicate + document `__dispose`/`__hotreload` (folds in R4 as a convention)
- **F2** overlay history ring buffer (last N events)
- Add a `schemaVersion` field to `status.json` (XS) — unblocks every future adapter

### Milestone 3 — Config & editor reach
Goal: configurable without touching `main.lua`, and reachable beyond VS Code.
- **T2** `.relove.lua` config (interval, overlay key, ignore globs) — ignore-globs adds a matcher in `registry.listWatchedFiles`
- **F3** VS Code deep-links: parse `stack` into `DiagnosticRelatedInformation`
- **F1** documented + versioned JSON schema, then a Neovim adapter client

### Milestone 4 — Ambitious opt-in engine *(highest risk, last by dependency)*
Goal: the two framework-adjacent features, isolated and opt-in.
- **R1** full asset hot reload via an opt-in interned registry (shaders recompile+swap; images/audio reference-swap). Depends on P1's portable read backend and benefits from M2's hooks.
- **R2** state-preserving `main.lua` reload behind an opt-in flag.

> Note: R1 is the owner's explicitly requested feature but is sequenced **last by
> dependency**, not by preference — it needs the portable read backend (M1) and
> is the riskiest change in the project.

---

## Milestone 1 — deep dive

### Files to change

| File | Change |
|------|--------|
| `tools/relove.lua` | Add `doctor` subcommand. Replace `cp -R`/`cp`/`chmod`/`cd && love .` with a pure-Lua manifest copy + OS-aware bits. Add an `isWindows()`/`osQuote()` helper. `run` uses `love <dir>` (LÖVE accepts a path arg — no `cd`). Copy `relove.bat` too when present. |
| `dev/relove/reloader.lua` | `readFile`: make `love.filesystem.read` the primary path; drop `io.popen("cat")`. Keep `io.open` as a secondary. |
| `dev/relove/watcher.lua` | `checksum`: make the pure-Lua rolling hash primary; drop `io.popen("cksum")`. (The `getInfo` modtime+size gate already avoids hashing untouched files.) |
| `dev/relove/reporter.lua` | `ensureProjectStateDir`: OS-aware `mkdir` (`package.config:sub(1,1)` → `\` = Windows). Use double-quote quoting on Windows; only shell out when the probe write fails. |
| `relove.bat` *(new)* | Windows wrapper: `@lua "%~dp0tools\relove.lua" %*`. The POSIX `relove` sh wrapper stays. |
| `README.md` | Update "Platform notes" / prerequisites: mark Windows supported; drop `cat`/`cksum`/`cp` from the hard-requirement list. |

### Approach (the non-obvious parts)

**OS detection without a dependency.** `package.config:sub(1,1)` is `"/"` on
POSIX and `"\\"` on Windows — works in plain Lua *and* under LÖVE. One helper,
shared shape in both `tools/relove.lua` and `reporter.lua`.

**The `mkdir` crux (`reporter.lua`).** Pure Lua can't create a directory and
`love.filesystem.createDirectory` writes to the wrong (save) dir. But `relove
init` **already creates `.relove/`**, so at runtime the dir almost always exists.
New logic: try to open the status file for write; only if that fails, shell out
with the OS-correct command — POSIX `mkdir -p '<path>'`, Windows `mkdir "<path>"`
(cmd's `mkdir` creates intermediate dirs by default). This keeps `os.execute` off
the per-frame path entirely and off the common path too.
`// ponytail: shell mkdir only when the CLI-created dir is missing; lfs/native dir-create if that ever proves flaky.`

**Install copy without `love.filesystem` (`tools/relove.lua`).** The CLI runs
under plain `lua`, and plain Lua has no directory listing — so the current
`cp -R dev/relove` can't become a pure-Lua tree walk without `lfs`. It doesn't
need to: **relove ships its own runtime, so the file list is fixed and known.**
Copy from a hardcoded manifest with a binary-safe `io.open("rb")`→`io.open("wb")`
copy:
```
dev/relove/init.lua, module_registry.lua, watcher.lua,
reloader.lua, reporter.lua, overlay.lua        -- the runtime
dev/relove.lua                                  -- entrypoint
tools/relove.lua                                -- the CLI itself
relove, relove.bat                              -- wrappers (whichever exist)
```
`chmod +x` is meaningful only on POSIX → guard it behind `isWindows()` and skip
on Windows (`.bat`/`.lua` need no exec bit).
`// ponytail: manifest, not a tree walk — the runtime's own files are a fixed set.`

**`run` without `cd`.** `love` accepts the game directory as an argument, so
`love <dir>` replaces `cd <dir> && love .` and sidesteps shell-chaining
differences.

**Hot-path reads (`reloader.lua` / `watcher.lua`).** Reorder so the pure-Lua /
`love.filesystem` paths are primary and delete the `io.popen` primaries. The one
risk to verify empirically: `love.filesystem.read` must return **fresh** bytes
right after an editor saves (some editors save atomically via temp+rename). If a
stale/truncated read ever shows up, keep an OS-aware shell read behind
`isWindows()` as a documented fallback — but verify first before adding it back.

### End-to-end verification (a real LÖVE game, not syntax checks)

**A. Reload smoke test on this machine (proves no POSIX regression).**
1. Scaffold a throwaway game in the scratchpad: `main.lua`, `conf.lua`, and
   `src/player.lua` (a table-returning module with an `update`).
2. `lua tools/relove.lua init <game>` → assert: manifest files copied,
   `main.lua` contains the marker block, `.relove/` exists,
   `main.lua.relove-backup` written.
3. `love <game> &` (needs a display; on a headless box use a virtual framebuffer),
   wait ~1s for boot.
4. Read `<game>/.relove/status.json` → expect `status: info` "watching …".
5. Edit `src/player.lua` (change a number). Wait > `interval`.
6. Read `status.json` → expect `status: "ok"`, `message: "reloaded src.player"`;
   `events.log` has grown by a line.
7. Introduce a syntax error → expect `status: "error"`, `usingLastGood: true`,
   and the game **still running**.
8. `lua tools/relove.lua doctor <game>` → LÖVE found, `main.lua` patched,
   `.relove/` writable — all green.

**B. Portability logic self-check (proves the OS branches without a Windows box).**
The copy + OS-branch logic is the risky new code, so it leaves one runnable
check behind (ponytail rule): a small `assert`-based self-test that forces both
branches of `isWindows()`/`osQuote()`/manifest-copy against a temp dir and
asserts the emitted command strings and copied bytes. Runs under plain `lua`,
no framework.

**C. Honest gap.** This darwin machine can't execute the Windows path for real.
The plan validates the POSIX path end-to-end via **A**, and the Windows
*command construction* via **B**. True Windows validation is a manual/CI step on
a Windows runner (or Wine) — call it out in the PR, don't claim it's verified
from here.

---

## Dependency graph (what unlocks what)

```
T1 doctor ───────────────► (verification tool for everything after)
P1 hot-path reads ───────► R1 asset reload (needs portable read backend)
schemaVersion (M2) ──────► F1 Neovim adapter, F3 deep-links
R3 __accept ─────────────► R4 coroutine-safety (as a convention)
(no deps) F2, T2, R2
```

Everything in Milestones 1–3 is independent enough to ship in small PRs. Only
Milestone 4 has hard upstream dependencies (R1 → P1).

---

## Not doing (and why)

- **TOML config** — replaced by `.relove.lua`; a hand-rolled TOML parser is more
  code than the feature.
- **Automatic coroutine detection** — no sound mechanism in Lua; shipped as an
  `__accept` convention instead.
- **Clickable overlay stack lines** — LÖVE can't hand off to an editor; deep-links
  are editor-side only.
