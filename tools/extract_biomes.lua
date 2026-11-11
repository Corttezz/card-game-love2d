-- Lê src/data/biomes.lua do jogo (só leitura) e imprime as cores em JSON para o site.
package.path = "E:/dev/projects/card-game-love2d/?.lua;" .. package.path
local ok, B = pcall(require, "src.data.biomes")
if not ok then io.stderr:write(tostring(B)) os.exit(1) end
local function hex(c) if not c then return nil end
  return string.format("#%02x%02x%02x", math.floor(c[1]*255+0.5), math.floor(c[2]*255+0.5), math.floor(c[3]*255+0.5)) end
local keys = {"skyTop","skyHorizon","cloud","hillsFar","hillsNear","grassA","grassB","roadA","fog","accent","lightNight","rock","canopy"}
local list = B.list or B
local out = {}
for _, b in ipairs(list) do
  local parts = {}
  table.insert(parts, string.format('"id":"%s","name_pt":"%s"', b.id, b.name or ""))
  for _, k in ipairs(keys) do if b[k] then table.insert(parts, string.format('"%s":"%s"', k, hex(b[k]))) end end
  if b.celestial then table.insert(parts, string.format('"celestial":{"kind":"%s","x":%s,"y":%s,"r":%s,"color":"%s"}', b.celestial.kind, b.celestial.xr, b.celestial.yr, b.celestial.r, hex(b.celestial.color))) end
  if b.ambient then table.insert(parts, string.format('"ambient":{"style":"%s","rate":%s,"color":"%s"}', b.ambient.style, b.ambient.rate, hex(b.ambient.color))) end
  table.insert(out, "{" .. table.concat(parts, ",") .. "}")
end
print("[" .. table.concat(out, ",\n") .. "]")
