-- Opt-in asset hot reload (M4 R1) over the real assets.lua module.
-- Run: luajit test/asset_reload.lua
local TEST_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)")) or "./"
package.path = TEST_DIR .. "../?.lua;" .. package.path

local vfiles = {}
local clock = 100
local breakImage = false
local breakImageData = false

local FakeImage = {}
FakeImage.__index = FakeImage
local function newFakeImage(w, h, pixels) return setmetatable({ w = w, h = h, pixels = pixels, replaced = 0 }, FakeImage) end
function FakeImage:replacePixels(data)
  if data.w ~= self.w or data.h ~= self.h then error("replacePixels: dimensions mismatch") end
  self.replaced = self.replaced + 1
  self.pixels = data.pixels
end

_G.love = {
  filesystem = {
    getSource = function() return "/tmp/relove-sim" end,
    getInfo = function(p) local f = vfiles[p]; if not f then return nil end; return { type = "file", size = #f.content, modtime = f.modtime } end,
  },
  graphics = {
    newImage = function(arg)
      if type(arg) == "table" then return newFakeImage(arg.w, arg.h, arg.pixels) end
      if breakImage then error("broken image") end
      local f = vfiles[arg]; return newFakeImage(f.w, f.h, f.content)
    end,
    newShader = function(p) return { shader = vfiles[p].content, release = function() end } end,
  },
  audio = { newSource = function(p, t) return { audio = vfiles[p].content, sourceType = t, stop = function() end, release = function() end } end },
  image = { newImageData = function(p) if breakImageData then error("broken imagedata") end local f = vfiles[p]; return { w = f.w, h = f.h, pixels = f.content } end },
  timer = { getTime = function() return clock end },
}

local Assets = require("dev.relove.assets")
local lastStatus
local reporter = { write = function(s) lastStatus = s end }
local A = Assets.new(reporter, nil, { interval = 0 })

local PASS, FAIL = 0, 0
local function check(name, cond) if cond then PASS = PASS + 1; print("  ok   : " .. name) else FAIL = FAIL + 1; print("  FAIL : " .. name .. "  [" .. tostring(lastStatus and lastStatus.message) .. "]") end end

local function setFile(p, content, w, h) local e = vfiles[p]; vfiles[p] = { content = content, modtime = e and e.modtime or clock, w = w, h = h } end
local function edit(p, content, w, h) clock = clock + 5; vfiles[p] = { content = content, modtime = clock, w = w, h = h } end

setFile("hero.png", "px1", 16, 16)
local hero = A:image("hero.png")
check("intern returns an image", hero ~= nil)
check("second intern returns the same cached object", A:image("hero.png") == hero)

edit("hero.png", "px2", 16, 16)
A:scan()
check("same-size reload uses replacePixels (in place)", hero.replaced == 1)
check("cached handle identity preserved after in-place", A:image("hero.png") == hero)
check("in-place status ok + 'in place'", lastStatus.status == "ok" and lastStatus.message:find("in place", 1, true) ~= nil)

edit("hero.png", "px3", 32, 32)
A:scan()
check("size change -> swapped to a new object", A:image("hero.png") ~= hero)
check("swap status mentions re-fetch", lastStatus.message:find("re-fetch", 1, true) ~= nil)

setFile("fx.glsl", "v1")
local sh = A:shader("fx.glsl")
edit("fx.glsl", "v2")
A:scan()
check("shader swapped to new object", A:shader("fx.glsl") ~= sh)
check("shader reload status ok", lastStatus.status == "ok")

setFile("boom.wav", "a1")
local src = A:audio("boom.wav", "static")
check("audio intern carries sourceType", src.sourceType == "static")
edit("boom.wav", "a2")
A:scan()
check("audio swapped", A:audio("boom.wav") ~= src)

setFile("logo.png", "good", 8, 8)
local logo = A:image("logo.png")
breakImageData = true
edit("logo.png", "bad", 8, 8)
A:scan()
check("broken reload keeps old object (last-good)", A:image("logo.png") == logo)
check("broken reload error status", lastStatus.status == "error" and lastStatus.usingLastGood == true)
breakImageData = false

local stopped, released = false, false
vfiles["loop.ogg"] = { content = "l1", modtime = clock }
love.audio.newSource = function(p, t) return { audio = vfiles[p].content, sourceType = t, stop = function() stopped = true end, release = function() released = true end } end
local loop = A:audio("loop.ogg", "stream")
edit("loop.ogg", "l2")
A:scan()
check("audio swap stopped the old source", stopped)
check("audio swap released the old source", released)

vfiles["shared.dat"] = { content = "d", modtime = clock, w = 4, h = 4 }
local asImg = A:image("shared.dat")
local asShader = A:shader("shared.dat")
check("same path, different kind -> distinct objects", asImg ~= asShader)

local before = hero.replaced
A:scan()
check("no spurious reload when nothing changed", hero.replaced == before)

print(string.format("\n=== asset_reload: %d passed, %d failed ===", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
