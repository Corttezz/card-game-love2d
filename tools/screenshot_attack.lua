-- tools/screenshot_attack.lua
-- Valida a INVESTIDA do inimigo (FX procedural Jul/2026): captura windup,
-- apex (impacto — dano aplicado aqui) e recoil, + um frame do tick de veneno.
--   love . screenshot_attack

local M = {}

local Game = require("src.core.Game")
local SceneLayer = require("src.ui.SceneLayer")
local EnemyRenderer = require("src.ui.EnemyRenderer")

function M.run()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local TopBar = require("components.TopBar")
    _G.topBar = TopBar:new()
    _G.topBar:setGame(game)

    SceneLayer._currentAct = 1
    for _ = 1, 30 do
        SceneLayer.update(1 / 30)
        EnemyRenderer.update(1 / 30)
    end

    local frameTime = 1 / 30
    local apexHit = false
    EnemyRenderer.triggerAttack("strong", function() apexHit = true end)

    -- momentos: fim do windup (0.16), apex (0.34), meio do recoil (0.55),
    -- e depois um frame de veneno (1.2)
    local moments = { 0.16, 0.335, 0.55, 1.2 }
    local outFiles = { "attack_windup.png", "attack_apex.png",
                       "attack_recoil.png", "attack_poison.png" }

    local totalElapsed = 0
    local function renderFrame()
        local width, height = love.graphics.getDimensions()
        love.graphics.clear(0, 0, 0, 1)
        SceneLayer.draw(0, 56, width, height - 56, 1)
        _G.topBar:draw()
        EnemyRenderer.draw(game, math.floor(width / 2), math.floor(height * 0.74))
    end

    for i, target in ipairs(moments) do
        while totalElapsed < target do
            EnemyRenderer.update(frameTime)
            SceneLayer.update(frameTime)
            totalElapsed = totalElapsed + frameTime
        end
        if i == 4 then EnemyRenderer.triggerPoison() end
        renderFrame()
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", outFiles[i])
            print("[attack] " .. outFiles[i] .. " salvo (t=" .. target .. ")")
        end)
        love.graphics.present()
    end
    print("[attack] apex disparou: " .. tostring(apexHit))
    love.event.quit()
end

return M
