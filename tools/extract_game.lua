-- Lê o jogo (só leitura): locales dos 5 idiomas e as tabelas de cartas. Imprime JSON.
-- uso: lua tools/extract_game.lua > tools/out/game_raw.json
local GAME = "E:/dev/projects/card-game-love2d/"
package.path = GAME .. "?.lua;" .. GAME .. "?/init.lua;" .. package.path

local function enc(v, ind)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return tostring(v) end
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if math.type and math.type(v) == "integer" then return tostring(v) end
    return string.format("%.6g", v)
  end
  if t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c)
      local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
      return m[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
  end
  if t == "table" then
    local n = #v
    local isArr = n > 0
    if isArr then for k in pairs(v) do if type(k) ~= "number" then isArr = false break end end end
    local parts = {}
    if isArr then
      for i = 1, n do parts[#parts + 1] = enc(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local val = v[k]
      if type(val) ~= "function" and type(val) ~= "userdata" then parts[#parts + 1] = enc(tostring(k)) .. ":" .. enc(val) end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

local LOCALES = { "en", "pt_BR", "es", "fr", "de" }
local out = { locales = {}, cards = {} }
for _, l in ipairs(LOCALES) do
  local ok, m = pcall(require, "src.i18n.locales." .. l)
  if not ok then io.stderr:write("locale " .. l .. ": " .. tostring(m) .. "\n") os.exit(1) end
  local pick = {}
  for _, k in ipairs({ "menu", "acts", "classes", "combos", "seals", "seal_ui", "endless_curses", "endless", "bestiary",
                       "boss_cinematics", "cards", "keyword", "play_button", "battle", "end_screen", "status", "enemy_kit", "card_info", "pack", "tutorial" }) do
    pick[k] = m[k]
  end
  out.locales[l] = pick
end
for _, f in ipairs({ "basic", "warrior", "mage", "rogue", "boss" }) do
  local ok, t = pcall(require, "src.data.cards." .. f)
  if not ok then io.stderr:write("cards " .. f .. ": " .. tostring(t) .. "\n") os.exit(1) end
  for id, c in pairs(t) do
    -- mesmas variáveis que I18n.cardVars (src/i18n/I18n.lua) usa para preencher a descrição
    local vars = { atk = c.attack, def = c.defense, cost = c.cost }
    if type(c.effects) == "table" then
      local suffix = { "", "2", "3", "4" }
      for i = 1, 4 do
        local e = c.effects[i]
        if e then
          local s = suffix[i]
          vars["value" .. s] = e.value; vars["stacks" .. s] = e.stacks; vars["duration" .. s] = e.duration
          if type(e.value) == "number" and type(e.type) == "string" and e.type:find("_multiplier$") then
            vars["pct" .. s] = math.floor((e.value - 1) * 100 + 0.5)
          end
        end
      end
    end
    out.cards[id] = { id = c.id or id, type = c.type, cost = c.cost, attack = c.attack, defense = c.defense, rarity = c.rarity,
                      class = c.class, tags = c.tags, file = f, hits = c.hits, vars = vars }
  end
end
local okArt, art = pcall(require, "src.data.card_art")
if okArt and type(art) == "table" then
  local map = {}
  for k, v in pairs(art) do if type(v) == "string" then map[k] = v elseif type(v) == "table" then map[k] = v.icon or v[1] end end
  out.card_art = map
end
io.write(enc(out))
