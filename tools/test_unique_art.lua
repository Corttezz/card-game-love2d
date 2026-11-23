local TK = require("tools.testkit")

local M = {}

local ICON_DIR = "assets/sprites/icons/"

local function digest(name)
    local raw = love.filesystem.read(ICON_DIR .. name .. ".png")
    if not raw then return nil end
    return love.data.encode("string", "hex", love.data.hash("md5", raw))
end

local function body(t)
    TK.bootstrap()
    local atlas = require("src.data.card_art")
    local CardDatabase = require("src.systems.CardDatabase")
    local Resistances = require("src.systems.Resistances")
    local StatusPill = require("src.ui.StatusPill")
    local all = CardDatabase:new():getAllCards()

    local ids = {}
    for id in pairs(all) do ids[#ids + 1] = id end
    table.sort(ids)

    local byIcon, byHash, cardIcon = {}, {}, {}
    local missing, sharedIcon, sharedPng = {}, {}, {}
    for _, id in ipairs(ids) do
        local entry = atlas[id]
        local icon = entry and entry.icon
        local h = icon and digest(icon)
        if not h then
            missing[#missing + 1] = id
        else
            cardIcon[icon] = id
            if byIcon[icon] then sharedIcon[#sharedIcon + 1] = byIcon[icon] .. " = " .. id end
            byIcon[icon] = byIcon[icon] or id
            if byHash[h] and byHash[h] ~= id then sharedPng[#sharedPng + 1] = byHash[h] .. " = " .. id end
            byHash[h] = byHash[h] or id
        end
    end
    t:check(("%d cartas, coringas e itens com PNG próprio no atlas"):format(#ids), #ids > 100 and #missing == 0)
    for _, id in ipairs(missing) do print("    sem PNG: " .. id) end
    t:eq("nenhum ícone de atlas usado por 2 ids", #sharedIcon, 0)
    for _, s in ipairs(sharedIcon) do print("    " .. s) end
    t:eq("nenhum PNG idêntico entre 2 ids", #sharedPng, 0)
    for _, s in ipairs(sharedPng) do print("    " .. s) end

    t:eq("Espelho de Forja tem arte própria", atlas.effect_mystery_card.icon, "effect_mystery_card")

    local uiUses = {}
    for kind, icon in pairs(Resistances.ICON) do uiUses[#uiUses + 1] = { "resistência " .. kind, icon } end
    for name, icon in pairs(StatusPill.ICONS) do uiUses[#uiUses + 1] = { "status " .. name, icon } end
    local borrowed = {}
    for _, u in ipairs(uiUses) do
        local h = digest(u[2])
        local owner = cardIcon[u[2]] or (h and byHash[h])
        if owner then borrowed[#borrowed + 1] = u[1] .. " usa a arte de " .. owner end
    end
    t:eq("interface (resistências e status) não usa arte de carta", #borrowed, 0)
    for _, s in ipairs(borrowed) do print("    " .. s) end
end

function M.run()
    local t = TK.new("arte única por id (#533)")
    local ok, err = pcall(body, t)
    if not ok then t:check("sem erro: " .. tostring(err), false) end
    return t:done()
end

return M
