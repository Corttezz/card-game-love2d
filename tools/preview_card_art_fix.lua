-- tools/preview_card_art_fix.lua
-- Contact sheet de validacao do fix de arte repetida (2026-09).
-- Renderiza as 12 cartas que estavam ORFAS no atlas `src/data/card_art.lua`
-- lado a lado com as 4 cartas com que elas colidiam no fallback por tipo
-- (potion_red / skull / dagger / shield_kite). Se alguma dupla ainda parecer
-- a mesma foto, aparece no mesmo contact sheet.
--
-- Roda: love . preview_card_art_fix
-- Saida: <saveDir>/cardartfix_sheet.png

local M = {}

-- {id, legenda} — as 4 ultimas sao as "vitimas" da colisao antiga.
local IDS = {
    { "warrior_adrenaline_rush", "ORFA" },
    { "warrior_battle_orders",   "ORFA" },
    { "warrior_eternal_bulwark", "ORFA" },
    { "warrior_taunt",           "ORFA" },
    { "mage_dark_harvest",       "ORFA" },
    { "mage_primordial_storm",   "ORFA" },
    { "mage_radiant_prayer",     "ORFA" },
    { "mage_sacred_chalice",     "ORFA" },
    { "rogue_dirty_blade",       "ORFA" },
    { "rogue_leech_blade",       "ORFA" },
    { "rogue_poison_dart",       "ORFA" },
    { "rogue_toxin_master",      "ORFA" },
    { "effect_healing_potion",   "colidia (potion_red)" },
    { "rogue_death_mark",        "colidia (skull)" },
    { "rogue_stiletto",          "colidia (dagger)" },
    { "warrior_kite_guard",      "colidia (shield_kite)" },
}

local COLS, CARD_W, CARD_H, PAD = 4, 96, 144, 10

function M.run()
    require("src.ui.PixelCanvas").enableNearest()
    local CardDatabase = require("src.systems.CardDatabase")
    local CardFrame = require("src.ui.CardFrame")
    local db = CardDatabase:new()

    local rows = math.ceil(#IDS / COLS)
    local sheetW = COLS * (CARD_W + PAD) + PAD
    local sheetH = rows * (CARD_H + PAD) + PAD

    local canvas = love.graphics.newCanvas(sheetW, sheetH)
    canvas:setFilter("nearest", "nearest")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.08, 0.07, 0.06, 1)

    for i, job in ipairs(IDS) do
        local id = job[1]
        local cd = db:getCard(id)
        if not cd then
            print("[cardartfix] WARN: carta nao encontrada: " .. id)
        else
            local img = CardFrame.render(cd)
            local col = (i - 1) % COLS
            local row = math.floor((i - 1) / COLS)
            local x = PAD + col * (CARD_W + PAD)
            local y = PAD + row * (CARD_H + PAD)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, x, y)
            print(string.format("[cardartfix] %-26s %s", id, job[2]))
        end
    end

    love.graphics.setCanvas()
    local data = canvas:newImageData()
    data:encode("png", "cardartfix_sheet.png")
    print("[cardartfix] salvo cardartfix_sheet.png em " .. love.filesystem.getSaveDirectory())
end

return M
