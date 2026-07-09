-- tools/screenshot_menuanim.lua
-- Valida a ANIMAÇÃO DE VELA do menu (ciclo de crossfade entre frames).
--   love . screenshot_menuanim
-- Monkeypatcha love.timer.getTime pra amostrar o ciclo inteiro em pontos
-- controlados, renderiza o Menu REAL em cada ponto e monta um grid pra ver
-- a sequência (7 "holds") + um crossfade intermediário numa imagem só.
-- Salva menuanim_grid.png no save dir.

local M = {}

function M.run()
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local Menu = require("components.Menu")
    local menu = Menu:new()
    for _ = 1, math.floor(2.4 * 30) do menu:update(1 / 30) end  -- passa a intro

    -- mesma matemática do Menu (BG_SEG = FADE+HOLD, 7 estados)
    local FADE, HOLD = 0.65, 0.55
    local SEG = FADE + HOLD
    local N = 7
    local labels = { "menu", "menu_normal", "menu", "menu_1", "menu_2", "menu_normal", "menu" }

    -- pontos de amostragem: o "hold" (alvo cheio) de cada um dos 7 estados,
    -- + 2 crossfades no meio (menu→normal e menu_1→menu_2) pra ver o blend.
    local samples = {}
    for i = 0, N - 1 do
        samples[#samples + 1] = {
            t = i * SEG + FADE + HOLD * 0.5,        -- meio do hold do "to"
            tag = "hold: " .. labels[(i % N) + 1] .. "->" .. labels[((i + 1) % N) + 1],
        }
    end
    samples[#samples + 1] = { t = 0 * SEG + FADE * 0.5, tag = "XFADE menu->normal" }
    samples[#samples + 1] = { t = 3 * SEG + FADE * 0.5, tag = "XFADE menu_1->menu_2" }

    local W, H = love.graphics.getDimensions()
    local cols = 3
    local rows = math.ceil(#samples / cols)
    local cw, ch = math.floor(W / cols), math.floor(H / rows)

    local realGetTime = love.timer.getTime
    local font = love.graphics.newFont(12)

    love.graphics.clear(0, 0, 0, 1)
    for i, sp in ipairs(samples) do
        -- render do menu REAL num canvas full-size, no tempo amostrado
        local canvas = love.graphics.newCanvas(W, H)
        love.timer.getTime = function() return sp.t end
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        menu:draw()
        love.graphics.setCanvas()
        love.timer.getTime = realGetTime

        -- desenha reduzido na célula do grid
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x, y = col * cw, row * ch
        local s = math.min(cw / W, ch / H)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, x, y, 0, s, s)
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", x, y, cw, 18)
        love.graphics.setColor(1, 0.85, 0.4, 1)
        love.graphics.setFont(font)
        love.graphics.print(string.format("%d) %s  t=%.2f", i, sp.tag, sp.t), x + 3, y + 3)
    end

    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "menuanim_grid.png")
        print("[screenshot] menuanim_grid.png salvo")
        love.event.quit()
    end)
    love.graphics.present()
end

return M
