-- tools/screenshot_cursor.lua
-- Valida o cursor pixel-art:  love . screenshot_cursor
-- Desenha o menu real de fundo + os 2 cursores em escala de jogo (2×) em
-- posições de contexto, e ampliados 8× num canto pra inspeção da arte.
-- Salva cursor_preview.png no save dir.

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
    for _ = 1, math.floor(2.4 * 30) do menu:update(1 / 30) end

    local CursorManager = require("src.ui.CursorManager")
    CursorManager.load()
    -- headless: sem foco de mouse o draw() sai cedo — força pro preview
    love.window.hasMouseFocus = function() return true end

    love.graphics.clear(0, 0, 0, 1)
    menu:draw()

    -- acessa as imagens internas via draw() com mouse fake: em vez disso,
    -- redesenha direto (inspeção): pega via package.loaded (upvalues não
    -- são expostos), então simplesmente chama draw() 2x com estados.
    -- Pra inspeção ampliada, reconstruímos as imagens aqui:
    local W, H = love.graphics.getDimensions()

    -- cursor em contexto: seta no meio, mão sobre o botão "Jogar" (fake pos)
    local rawGetPos = love.mouse.getPosition
    love.mouse.getPosition = function() return W * 0.35, H * 0.45 end
    CursorManager.draw()                       -- seta
    love.mouse.getPosition = function() return W * 0.62, H * 0.52 end
    CursorManager.request("hand")
    CursorManager.draw()                       -- mão
    love.mouse.getPosition = rawGetPos

    -- inspeção ampliada 8× no canto inferior esquerdo
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 8, H - 160, 300, 152, 8, 8)
    local rawH = love.graphics.getHeight
    love.graphics.getHeight = function() return 384 * 8 end   -- força escala 8
    love.mouse.getPosition = function() return 40, H - 140 end
    CursorManager.draw()
    love.mouse.getPosition = function() return 190, H - 140 end
    CursorManager.request("hand")
    CursorManager.draw()
    love.mouse.getPosition = rawGetPos
    love.graphics.getHeight = rawH

    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "cursor_preview.png")
        print("[screenshot] cursor_preview.png salvo")
        love.event.quit()
    end)
    love.graphics.present()
end

return M
