-- Opt-in main.lua reload (M4 R2) over the real reloader.lua.
-- Run: luajit test/main_reload.lua
local TEST_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = TEST_DIR .. "../?.lua;" .. package.path

local vfiles = {}
_G.love = {
  filesystem = {
    getSource = function() return "." end,
    read = function(p) local c = vfiles[p]; if not c then return nil end; return c, #c end,
  },
}

local Reloader = require("dev.relove.reloader")
local last
local reporter = {
  write = function(s) last = s end,
  restartRequired = function(f, m) last = { status = "restart_required", file = f, message = m } end,
  error = function(f, m) last = { status = "error", file = f, message = m } end,
  info = function() end,
  ok = function() end,
}

local PASS, FAIL = 0, 0
local function check(name, cond) if cond then PASS = PASS + 1; print("  ok   : " .. name) else FAIL = FAIL + 1; print("  FAIL : " .. name .. "  [" .. tostring(last and last.status) .. "]") end end

local r = Reloader.new({}, reporter, nil, { reloadMain = true })
vfiles["main.lua"] = "MAIN_RAN = (MAIN_RAN or 0) + 1\nfunction love.load() LOAD_CALLED = (LOAD_CALLED or 0) + 1 end\nfunction love.update() end"
r:reloadPath("main.lua", "main")
check("main chunk ran once (MAIN_RAN=1)", MAIN_RAN == 1)
check("status ok on main reload", last.status == "ok")
check("love.update was re-bound", type(love.update) == "function")
check("love.load NOT auto-called (LOAD_CALLED nil)", LOAD_CALLED == nil)

r:reloadPath("main.lua", "main")
check("re-run increments (boot re-ran, opt-in caveat)", MAIN_RAN == 2)

vfiles["main.lua"] = "this is not valid lua ((("
r:reloadPath("main.lua", "main")
check("syntax error -> error status", last.status == "error")
check("bad chunk did not run (MAIN_RAN still 2)", MAIN_RAN == 2)

local r2 = Reloader.new({}, reporter, nil, {})
vfiles["main.lua"] = "MAIN_RAN = (MAIN_RAN or 0) + 1"
local before = MAIN_RAN
r2:reloadPath("main.lua", "main")
check("default -> restart_required", last.status == "restart_required")
check("default -> chunk NOT run", MAIN_RAN == before)

print(string.format("\n=== main_reload: %d passed, %d failed ===", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
