-- Textos de interface do jogo usados na tela de título do site (5 idiomas), direto dos locales do jogo.
-- uso: lua tools/extract_ui.lua > src/data/ui_game.json
package.path = "E:/dev/projects/card-game-love2d/?.lua;" .. package.path
local KEYS = { "menu.play", "menu.collection", "menu.achievements", "menu.settings", "menu.quit", "menu.subtitle",
  "settings.title", "settings.music", "settings.sfx", "settings.crt_shader", "settings.reduced_motion", "settings.language", "settings.back",
  "collection.title", "achievements.toast_label", "achievements.title" }
local function get(t, path)
  for k in path:gmatch("[^%.]+") do
    if type(t) ~= "table" then return nil end
    t = t[k]
  end
  return t
end
local function q(s)
  s = tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("%c", function(c) return string.format("\\u%04x", c:byte()) end)
  return '"' .. s .. '"'
end
local out = {}
for _, l in ipairs({ "en", "pt_BR", "es", "fr", "de" }) do
  local m = require("src.i18n.locales." .. l)
  local parts = {}
  for _, k in ipairs(KEYS) do
    local v = get(m, k)
    if type(v) == "string" then parts[#parts + 1] = q(k) .. ":" .. q(v) end
  end
  out[#out + 1] = q(l) .. ":{" .. table.concat(parts, ",") .. "}"
end
io.write("{" .. table.concat(out, ",") .. "}\n")
