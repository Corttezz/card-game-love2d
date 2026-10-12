-- tools/sheet_card_art.lua
-- Folha de contato de TODAS as cartas (canvas estático do CardFrame) em 2x,
-- pra revisar o enquadramento da ilustração no slot (topo × base cortados).
--
--   love . test_one sheet_card_art [tag]   → card_art_sheet_<tag>_<n>.png
--
-- 10 colunas × 5 linhas por folha (50 cartas), ordem por id.

local M = {}

function M.run(tag)
    tag = tag or "x"
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init(); I18n.setLocale("pt_BR")
    require("src.ui.PixelCanvas").enableNearest()
    local db = require("src.systems.CardDatabase"):new()
    db:loadData()
    local ids = {}
    for id in pairs(db:getAllCards()) do ids[#ids + 1] = id end
    table.sort(ids)
    local S, COLS, ROWS, PAD = 2, 10, 5, 6
    local cw, ch = 96 * S, 144 * S
    local per = COLS * ROWS
    local sheet = 0
    for start = 1, #ids, per do
        sheet = sheet + 1
        local cv = love.graphics.newCanvas(COLS * (cw + PAD) + PAD, ROWS * (ch + PAD + 12) + PAD)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0.12, 0.10, 0.08, 1)
        local font = love.graphics.newFont(10)
        love.graphics.setFont(font)
        for k = start, math.min(#ids, start + per - 1) do
            local i = k - start
            local x = PAD + (i % COLS) * (cw + PAD)
            local y = PAD + math.floor(i / COLS) * (ch + PAD + 12)
            local inst = db:createCardInstance(db:getCard(ids[k]))
            love.graphics.setColor(1, 1, 1, 1)
            if inst and inst.image then love.graphics.draw(inst.image, x, y, 0, S, S) end
            love.graphics.setColor(0.9, 0.85, 0.7, 1)
            love.graphics.print(ids[k], x, y + ch + 1)
        end
        love.graphics.setCanvas()
        local name = ("card_art_sheet_%s_%d.png"):format(tag, sheet)
        cv:newImageData():encode("png", name)
        print("[sheet] " .. name)
    end
    return true
end

return M
