-- tools/screenshot_turnbanner.lua
-- Valida o TurnBanner v2 (placa grimório):  love . screenshot_turnbanner
-- Renderiza a batalha da estrada (bioma 1) e captura o banner nos dois
-- estados, no meio do hold: turnbanner_player.png / turnbanner_enemy.png.

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
    game.enemy.spriteId = "cursed_scarecrow"

    local WorldRoad = require("src.ui.WorldRoad")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local TurnBanner = require("src.ui.TurnBanner")
    local width, height = love.graphics.getDimensions()
    local topBarH = 80

    WorldRoad.clearCache()
    WorldRoad.setBiome(1)
    WorldRoad._camZ = 6
    for _ = 1, 30 do
        WorldRoad.update(1 / 30)
        EnemyRenderer.update(1 / 30)
    end

    local shots = {
        { kind = "player", t = 0.15, tag = "player_in" },   -- meio da queima
        { kind = "player", t = 0.50, tag = "player" },      -- hold cheio
        { kind = "enemy",  t = 0.50, tag = "enemy" },
        { kind = "enemy",  t = 0.90, tag = "enemy_out" },   -- dissolvendo
    }
    for _, sp in ipairs(shots) do
        local kind = sp.kind
        TurnBanner.show(kind)
        TurnBanner.update(sp.t)

        love.graphics.clear(0, 0, 0, 1)
        local cx, cy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,
            0, topBarH, width, height - topBarH)
        WorldRoad.setBattleEnemyDraw(function()
            EnemyRenderer.draw(game, cx, cy)
        end, cy)
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
        TurnBanner.draw()

        local tag = sp.tag
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", "turnbanner_" .. tag .. ".png")
            print("[screenshot] turnbanner_" .. tag .. ".png salvo")
        end)
        love.graphics.present()
    end
    love.event.quit()
end

return M
