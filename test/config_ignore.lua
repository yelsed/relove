-- Ignore-glob matcher + scan-skip + config merge + crash-proofing (M3).
-- Run: luajit test/config_ignore.lua
local TEST_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = TEST_DIR .. "../?.lua;" .. package.path

local vfiles = {}
local clock = 100
_G.love = {
  filesystem = {
    getSource = function() return "/tmp/relove-sim" end,
    getInfo = function(p) local f = vfiles[p]; if not f then return nil end; return { type = "file", size = #f.content, modtime = f.modtime } end,
    read = function(p) local f = vfiles[p]; if not f then return nil end; return f.content, #f.content end,
  },
  timer = { getTime = function() return clock end },
}

local Watcher = require("dev.relove.watcher")
local PASS, FAIL = 0, 0
local function check(name, cond) if cond then PASS = PASS + 1; print("  ok   : " .. name) else FAIL = FAIL + 1; print("  FAIL : " .. name) end end

local w = Watcher.new({}, {}, { ignore = { "vendor/", "*.min.lua" } })
check("vendor/ prefix matches nested", w:isIgnored("vendor/foo/bar.lua"))
check("vendor/ does not match src", not w:isIgnored("src/foo.lua"))
check("*.min.lua matches basename", w:isIgnored("a.min.lua"))
check("*.min.lua matches nested basename", w:isIgnored("src/deep/b.min.lua"))
check("*.min.lua does not match plain .lua", not w:isIgnored("src/a.lua"))
check("no ignore list -> nothing ignored", not Watcher.new({}, {}, {}):isIgnored("anything.lua"))
check("literal dot not treated as wildcard", not Watcher.new({}, {}, { ignore = { "axmin.lua" } }):isIgnored("aXmin.lua"))

local function setfile(p, c) local e = vfiles[p]; vfiles[p] = { content = c, modtime = e and e.modtime or clock } end
local function touch(p) clock = clock + 5; vfiles[p].modtime = clock end
setfile("src/a.lua", "return {v=1}")
setfile("vendor/b.lua", "return {v=1}")
local registry = { listWatchedFiles = function() return { ["src/a.lua"] = { kind = "module" }, ["vendor/b.lua"] = { kind = "module" } } end }
local reloaded = {}
local reloader = { reloadPath = function(_, path) reloaded[#reloaded + 1] = path end }
local sw = Watcher.new(registry, reloader, { ignore = { "vendor/" } })
sw:scan()
touch("src/a.lua"); setfile("src/a.lua", "return {v=2}"); touch("src/a.lua")
setfile("vendor/b.lua", "return {v=2}"); touch("vendor/b.lua")
sw:scan()
local sawA, sawVendor = false, false
for _, p in ipairs(reloaded) do if p == "src/a.lua" then sawA = true elseif p == "vendor/b.lua" then sawVendor = true end end
check("ignored vendor/ module never reloaded", not sawVendor)
check("non-ignored src module reloaded", sawA)

local function merge(options, config)
  for k, v in pairs(config) do if options[k] == nil then options[k] = v end end
  return options
end
local merged = merge({ interval = 0.05 }, { interval = 0.5, overlayKey = "f9", ignore = { "x/" } })
check("inline interval overrides file", merged.interval == 0.05)
check("file overlayKey fills gap", merged.overlayKey == "f9")
check("file ignore fills gap", merged.ignore[1] == "x/")

local badInterval = Watcher.new({}, {}, { interval = "fast" })
check("string interval -> falls back to 0.15", badInterval.interval == 0.15)
badInterval.registry = { listWatchedFiles = function() return {} end }
check("update() does not throw with bad interval", pcall(function() badInterval:update(1) end))
local badIgnore = Watcher.new({}, {}, { ignore = "vendor/" })
check("string ignore -> falls back to nil", badIgnore.ignore == nil)
check("isIgnored does not throw with bad ignore", pcall(function() return badIgnore:isIgnored("x.lua") end))
check("bad ignore -> ignores nothing", badIgnore:isIgnored("vendor/x.lua") == false)

print(string.format("\n=== config_ignore: %d passed, %d failed ===", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
