-- tools/screenshot_holo.lua
-- Prancha do reflexo das cartas raras/lendárias, sem janela: desenha pelo
-- caminho AO VIVO (Card:draw) uma rara "glow", uma rara "holo", uma lendária
-- e uma comum com edition "holo" — em REPOUSO (tem que ser a carta crua, ou
-- quase) e no HOVER em três instantes da varredura. Canvas 1920x1080.
--
--   love . test_one screenshot_holo
--
-- Saída: holo_rest_hover_1920x1080.png no save dir.

local M = {}

function M.run()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    local HoloShader = require("src.ui.HoloShader")
    if not HoloShader.load() then print("[screenshot_holo] AVISO: load falhou") end
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()

    local W, H = 1920, 1080
    local SCALE = 1.4
    local COLS = {
        { id = "warrior_juggernaut", label = "rara, atlas glow (0 -> 0.25)" },
        { id = "warrior_bastion",    label = "rara, atlas holo (0.08 -> 0.5)" },
        { id = "joker_001",          label = "lendaria (0.08 -> 0.5)" },
        { id = "attack_001",         label = "comum + edition holo", edition = "holo" },
    }
    local function make(col, hover)
        local inst = db:createCardInstance(db:getCard(col.id))
        inst.isHovered, inst.hoverStrength, inst.liftOffset = hover, hover and 1 or 0, 0
        if hover then inst.tiltX, inst.tiltY = 0.03, -0.02 end
        inst.baseScale, inst.currentScale, inst.targetScale = SCALE, SCALE, SCALE
        inst.deferTooltip = true          -- sem tooltip por cima da prancha
        if col.edition then inst.edition = col.edition end
        return inst
    end

    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.11, 0.09, 0.08, 1)
    local font = FontManager.getFont(14)
    love.graphics.setFont(font)
    local realGetTime = love.timer.getTime
    local cardW, cardH = 96 * SCALE, 144 * SCALE
    local colW = math.floor(W / 4)
    -- Instantes escolhidos pela posicao da faixa (34 px/s, ciclo ~6.7 s):
    -- t=1.5 canto superior esquerdo, t=2.9 meio da carta, t=4.2 canto inferior.
    local ROWS = { { label = "REPOUSO (estatica)", time = 1.0, hover = false },
                   { label = "HOVER t=1.5 (faixa no topo)", time = 1.5, hover = true },
                   { label = "HOVER t=2.9 (faixa no meio)", time = 2.9, hover = true },
                   { label = "HOVER t=4.2 (faixa embaixo)", time = 4.2, hover = true } }
    local rowH = math.floor(H / 4)
    for r, row in ipairs(ROWS) do
        love.timer.getTime = function() return row.time end
        local y = (r - 1) * rowH
        love.graphics.setColor(0.9, 0.85, 0.7, 1)
        love.graphics.print(row.label, 16, y + 8)
        for c, col in ipairs(COLS) do
            local inst = make(col, row.hover)
            -- Card:draw recebe o canto SUPERIOR ESQUERDO (nao o centro).
            local cx = colW * (c - 1) + colW / 2
            local left, top = math.floor(cx - cardW / 2), y + 58
            love.graphics.setColor(1, 1, 1, 1)
            inst:draw(left, top, false, false)
            love.graphics.setColor(0.9, 0.85, 0.7, 1)
            love.graphics.print(col.label, left, y + 26)
        end
    end
    love.timer.getTime = realGetTime
    love.graphics.pop()
    local name = "holo_rest_hover_1920x1080.png"
    canvas:newImageData():encode("png", name)
    print("[screenshot_holo] " .. name .. " em " .. love.filesystem.getSaveDirectory())
    return true
end

return M
