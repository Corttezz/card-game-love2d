-- tools/preview_battle_hud.lua
-- Renderiza um frame simulado de batalha pra validar o novo HUD visual.
-- Usar: love . preview_battle_hud → saída em ~/.local/share/love/card-game/preview_battle_hud.png

local M = {}

function M.run()
    require("src.ui.PixelCanvas").enableNearest()
    local I18n = require("src.i18n.I18n")
    I18n.init()

    local Game = require("src.core.Game")
    local HudManager = require("src.ui.HudManager")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local EnemyHud = require("src.ui.EnemyHud")

    -- Setup fake game state
    local game = Game:new()
    game.selectedClass = "mage"  -- chip da passiva + OrbRow (fileira de orbes)
    game.player.health = 48
    game.player.maxHealth = 80
    game.player.mana = 2
    game.player.maxMana = 3
    game.player.armor = 7
    game.player.strength = 3
    game.player.dexterity = 2
    game.player.buffs = {
        { name = "focus", stacks = 2, duration = 3 },
    }
    -- OrbRow (Jul/2026): 2 orbes + 1 slot vazio — valida numero com Foco,
    -- marcador FIFO e o aro apagado do cap.
    game.player.orbs = {
        { type = "lightning", value = 4 },
        { type = "dark", value = 5 },
    }
    game.enemy.health = 34
    game.enemy.maxHealth = 55
    game.enemy.damage = 12
    game.enemy.statusEffects = {
        { name = "poison",     stacks = 3, duration = 2 },
        { name = "weak",       stacks = 1, duration = 2 },
        { name = "vulnerable", stacks = 1, duration = 1 },
    }

    local w, h = 1024, 768
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.08, 0.05, 0.04, 1)

    -- Fundo tipo arena (retângulos simples pra simular cenário)
    love.graphics.setColor(0.14, 0.10, 0.06, 1)
    love.graphics.rectangle("fill", 0, 0, w, h * 0.55)
    love.graphics.setColor(0.06, 0.04, 0.03, 1)
    love.graphics.rectangle("fill", 0, h * 0.55, w, h * 0.45)

    -- Inimigo (sprite pode não existir; bbox cai no fallback)
    local enemyCx = math.floor(w / 2)
    local enemyCy = math.floor(h * 0.55)
    local bbox = EnemyRenderer.draw(game, enemyCx, enemyCy)
    -- Se bbox veio false (sem sprite), desenha um placeholder quadrado pra visualizar
    if type(bbox) ~= "table" then
        love.graphics.setColor(0.30, 0.15, 0.20, 0.85)
        love.graphics.rectangle("fill", enemyCx - 60, enemyCy - 160, 120, 160)
        love.graphics.setColor(0.1, 0.05, 0.05, 1)
        love.graphics.rectangle("line", enemyCx - 60, enemyCy - 160, 120, 160)
        bbox = { cx = enemyCx, topY = enemyCy - 160, bottomY = enemyCy, width = 120, height = 160 }
    end
    EnemyHud.draw(game, bbox, enemyCx, enemyCy)

    -- HUD player panel + mana orb
    local hud = HudManager:new()
    hud:update(0.016)
    hud:draw(game)

    love.graphics.setCanvas()

    -- Salva PNG
    local img = canvas:newImageData()
    local out = "preview_battle_hud.png"
    img:encode("png", out)
    print("[preview] salvou", love.filesystem.getSaveDirectory() .. "/" .. out)
end

return M
