-- Deterministic module reload + __accept veto test (M2), over the real
-- registry/reloader/watcher modules. Run: luajit test/reload_veto.lua
local TEST_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = TEST_DIR .. "../?.lua;" .. package.path

local vfiles = {}
local clock = 100
_G.love = {
  filesystem = {
    getSource = function() return "/tmp/relove-sim" end,
    getInfo = function(p) local f = vfiles[p]; if not f then return nil end; return { type = "file", size = #f.content, modtime = f.modtime } end,
    read = function(p) local f = vfiles[p]; if not f then return nil end; return f.content, #f.content end,
    write = function() return true end,
    createDirectory = function() return true end,
  },
  timer = { getTime = function() return clock end },
}

local Registry = require("dev.relove.module_registry")
local Reporter = require("dev.relove.reporter")
local Overlay  = require("dev.relove.overlay")
local Reloader = require("dev.relove.reloader")
local Watcher  = require("dev.relove.watcher")

local statuses = {}
Reporter.write = function(payload) statuses[#statuses + 1] = payload end

local function setfile(p, content)
  local existing = vfiles[p]
  vfiles[p] = { content = content, modtime = existing and existing.modtime or clock }
end
local function touch(p) clock = clock + 5; vfiles[p].modtime = clock end
local function last() return statuses[#statuses] or {} end

local liveTable = { v = 1 }
setfile("m.lua", "local M = {}\nM.v = 1\nreturn M\n")
Registry.modules["m"] = { name = "m", path = "m.lua", exported = liveTable, modtime = clock, size = #vfiles["m.lua"].content, lastKnownGood = vfiles["m.lua"].content }
Registry.pathToName["m.lua"] = "m"
package.loaded["m"] = liveTable

local reloader = Reloader.new(Registry, Reporter, Overlay)
local watcher = Watcher.new(Registry, reloader, { interval = 0 })

local PASS, FAIL = 0, 0
local function check(name, cond) if cond then PASS = PASS + 1; print("  ok   : " .. name) else FAIL = FAIL + 1; print("  FAIL : " .. name .. "  [status=" .. tostring(last().status) .. "]") end end

watcher:scan()

setfile("m.lua", "local M = {}\nM.v = 2\nreturn M\n"); touch("m.lua")
watcher:scan()
check("plain edit reloads (liveTable patched to v=2)", liveTable.v == 2)
check("reload status ok", last().status == "ok")

setfile("m.lua", "local M = {}\nM.v = 3\nfunction M.__accept() if VETO then return false, 'busy' end end\nreturn M\n"); touch("m.lua")
watcher:scan()
check("adding __accept reloads (v=3, hook live)", liveTable.v == 3 and type(liveTable.__accept) == "function")

_G.VETO = true
setfile("m.lua", "local M = {}\nM.v = 4\nfunction M.__accept() if VETO then return false, 'busy' end end\nreturn M\n"); touch("m.lua")
watcher:scan()
check("veto keeps liveTable at v=3", liveTable.v == 3)
check("veto reports status vetoed", last().status == "vetoed")

_G.VETO = false
touch("m.lua")
watcher:scan()
check("identical re-save re-attempts + applies v=4", liveTable.v == 4)
check("resume status ok", last().status == "ok")

print(string.format("\n=== reload_veto: %d passed, %d failed ===", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
