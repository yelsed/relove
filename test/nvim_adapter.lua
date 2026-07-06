-- Neovim adapter (M3) headless test. Run: nvim --headless -l test/nvim_adapter.lua
local TEST_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = TEST_DIR .. "../editor/nvim-relove/lua/?.lua;" .. package.path

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp .. "/.relove", "p")
vim.fn.mkdir(tmp .. "/src", "p")
vim.fn.writefile({ "local P = {}", "return P" }, tmp .. "/src/player.lua")

local function writeStatus(obj)
  vim.fn.writefile({ vim.json.encode(obj) }, tmp .. "/.relove/status.json")
end

writeStatus({ schemaVersion = 1, status = "error", file = "src/player.lua", line = 1, message = "boom", usingLastGood = true })

local relove = require("relove")
relove.setup({ root = tmp })

local PASS, FAIL = 0, 0
local function check(name, cond) if cond then PASS = PASS + 1; print("  ok   : " .. name) else FAIL = FAIL + 1; print("  FAIL : " .. name) end end

vim.wait(1500, function() return vim.g.relove_status == "error" end)
check("initial status = error", vim.g.relove_status == "error")
local diags = vim.diagnostic.get()
check("diagnostic published", #diags >= 1)
check("diagnostic on lnum 0 (1-based line 1)", diags[1] ~= nil and diags[1].lnum == 0)
check("severity ERROR", diags[1] ~= nil and diags[1].severity == vim.diagnostic.severity.ERROR)

writeStatus({ schemaVersion = 1, status = "error", file = "love.update", message = "nil idx", usingLastGood = true })
vim.wait(2000, function() return #vim.diagnostic.get() == 0 and vim.g.relove_status == "error" end)
check("label-only error attaches no diagnostic", #vim.diagnostic.get() == 0)

writeStatus({ schemaVersion = 1, status = "ok", file = "src/player.lua", message = "reloaded", usingLastGood = false })
vim.wait(2000, function() return vim.g.relove_status == "ok" end)
check("watcher picked up change -> ok", vim.g.relove_status == "ok")
check("diagnostics cleared on ok", #vim.diagnostic.get() == 0)

check("M.stop is a function", type(relove.stop) == "function")
check("second setup() does not error", pcall(function() relove.setup({ root = tmp }) end))
vim.wait(500, function() return false end)
check("still functional after re-setup", vim.g.relove_status ~= nil)

print(string.format("\n=== nvim_adapter: %d passed, %d failed ===", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
