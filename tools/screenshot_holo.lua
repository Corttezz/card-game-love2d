-- tools/screenshot_holo.lua
-- ANTES/DEPOIS do holo das cartas raras/lendárias, sem janela: desenha pelo
-- caminho AO VIVO (Card:draw, hover) uma rara, uma lendária e uma comum com
-- edition "holo" — primeiro com o HoloShader descarregado (o estado em que o
-- jogo ficou de Abr a Out/2026), depois carregado, em três instantes da
-- varredura. Canvas 1920x1080 (escala de carta do 1080p).
--
--   love . test_one screenshot_holo
--
-- Saída: holo_before_after_1920x1080.png no save dir.

local M = {}

function M.run()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    local HoloShader = require("src.ui.HoloShader")
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()

    local W, H = 1920, 1080
    local SCALE = 1.7
    local COLS = {
        { id = "warrior_juggernaut", label = "rara, atlas glow (0.35)" },
        { id = "warrior_bastion",    label = "rara, atlas holo (0.75)" },
        { id = "joker_001",          label = "lendaria (holo 0.75)" },
        { id = "attack_001",         label = "comum + edition holo", edition = "holo" },
    }
    local function make(col)
        local inst = db:createCardInstance(db:getCard(col.id))
        inst.isHovered, inst.hoverStrength, inst.liftOffset = true, 1, 0
        inst.tiltX, inst.tiltY = 0.03, -0.02
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
    -- linha 0: ANTES (sem load); linhas 1-3: DEPOIS em t = 0.3 / 0.9 / 1.5
    local ROWS = { { label = "ANTES: HoloShader sem load()", time = 1.0, loaded = false },
                   { label = "DEPOIS t=0.3", time = 0.3, loaded = true },
                   { label = "DEPOIS t=0.9", time = 0.9, loaded = true },
                   { label = "DEPOIS t=1.5", time = 1.5, loaded = true } }
    local rowH = math.floor(H / 4)
    for r, row in ipairs(ROWS) do
        if row.loaded and not HoloShader.isAvailable() then
            if not HoloShader.load() then print("[screenshot_holo] AVISO: load falhou") end
        end
        love.timer.getTime = function() return row.time end
        local y = (r - 1) * rowH
        love.graphics.setColor(0.9, 0.85, 0.7, 1)
        love.graphics.print(row.label, 16, y + 8)
        for c, col in ipairs(COLS) do
            local inst = make(col)
            -- Card:draw recebe o CENTRO da carta
            local cx = colW * (c - 1) + colW / 2
            local cy = y + rowH / 2 + 10
            love.graphics.setColor(1, 1, 1, 1)
            inst:draw(cx, cy, false, false)
            love.graphics.setColor(0.9, 0.85, 0.7, 1)
            love.graphics.print(col.label, math.floor(cx - cardW / 2), y + 26)
        end
    end
    love.timer.getTime = realGetTime
    love.graphics.pop()
    local name = "holo_before_after_1920x1080.png"
    canvas:newImageData():encode("png", name)
    print("[screenshot_holo] " .. name .. " em " .. love.filesystem.getSaveDirectory())
    return true
end

return M
