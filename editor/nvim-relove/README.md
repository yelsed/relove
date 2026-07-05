# nvim-relove

A minimal Neovim adapter for `relove`. It watches `.relove/status.json` and turns
`relove` errors into Neovim diagnostics, mirroring the VS Code adapter. It reads
the editor-agnostic contract documented in [`../PROTOCOL.md`](../PROTOCOL.md).

The adapter is optional — hot reload works without it.

## Install

Copy `lua/relove.lua` onto your `runtimepath`, or point a plugin manager at
`editor/nvim-relove`.

lazy.nvim:

```lua
{
  dir = "/path/to/relove/editor/nvim-relove",
  config = function()
    require("relove").setup()
  end,
}
```

## Usage

```lua
require("relove").setup()                      -- watches the current working directory
require("relove").setup({ root = "/path/to/game" })
```

When `relove` reports an `error` or `restart_required`, the adapter places a
diagnostic on the offending `file:line`. Other statuses clear diagnostics. The
current status is also exposed as `vim.g.relove_status` for status lines.

## Requirements

Neovim 0.10+ (uses `vim.uv`, `vim.json`, and `vim.diagnostic`).
