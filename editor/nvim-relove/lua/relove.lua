-- relove Neovim adapter: watches .relove/status.json and turns relove errors
-- into Neovim diagnostics. Consumes the same schemaVersion:1 contract as the
-- VS Code adapter (see editor/PROTOCOL.md).
--
-- Usage (e.g. in init.lua):
--   require("relove").setup()                 -- watches the cwd
--   require("relove").setup({ root = "/path/to/game" })

local M = {}

local uv = vim.uv or vim.loop
local namespace = vim.api.nvim_create_namespace("relove")

local function severityFor(status)
  if status.status == "error" then
    return vim.diagnostic.severity.ERROR
  end
  if status.status == "restart_required" then
    return vim.diagnostic.severity.WARN
  end
  return nil
end

local function readStatus(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    return decoded
  end
  return nil
end

local function apply(root, status)
  vim.g.relove_status = status.status
  vim.diagnostic.reset(namespace)

  local severity = severityFor(status)
  if not severity then
    return
  end

  local file = status.file or "main.lua"
  -- A runtime error's `file` can be a callback label ("love.update") rather than
  -- a path; only attach a diagnostic when it resolves to a readable file.
  local absolute = file:sub(1, 1) == "/" and file or (root .. "/" .. file)
  if vim.fn.filereadable(absolute) == 0 then
    return
  end

  local bufnr = vim.fn.bufadd(absolute)
  vim.fn.bufload(bufnr)

  local line = math.max(0, (tonumber(status.line) or 1) - 1)
  vim.diagnostic.set(namespace, bufnr, {
    {
      lnum = line,
      col = 0,
      message = status.message or status.status,
      severity = severity,
      source = "relove",
    },
  })
end

-- Stop any running watcher/timer so a repeated setup() doesn't leak handles.
function M.stop()
  if M._watcher then
    pcall(function() M._watcher:stop() end)
    pcall(function() M._watcher:close() end)
    M._watcher = nil
  end
  if M._timer then
    pcall(function() M._timer:stop() end)
    pcall(function() M._timer:close() end)
    M._timer = nil
  end
end

function M.setup(opts)
  M.stop()
  opts = opts or {}
  local root = opts.root or vim.fn.getcwd()
  local stateDir = root .. "/.relove"
  local statusPath = stateDir .. "/status.json"

  local function refresh()
    local status = readStatus(statusPath)
    if status then
      vim.schedule(function()
        apply(root, status)
      end)
    end
  end

  refresh()

  -- Watch the directory, not the single file: editors save atomically (write a
  -- temp file then rename), which breaks a watch bound to one inode.
  if vim.fn.isdirectory(stateDir) == 1 then
    local watcher = uv.new_fs_event()
    if watcher then
      watcher:start(stateDir, {}, function(err, filename)
        if not err and (filename == nil or filename:match("status%.json")) then
          vim.schedule(refresh)
        end
      end)
      M._watcher = watcher
    end
  else
    -- .relove doesn't exist yet: poll once a second until it appears.
    local timer = uv.new_timer()
    timer:start(1000, 1000, function()
      vim.schedule(refresh)
    end)
    M._timer = timer
  end

  return M
end

return M
