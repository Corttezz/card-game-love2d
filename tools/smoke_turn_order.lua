-- tools/smoke_turn_order.lua
-- Regressão da ORDEM DO TURNO (nasceu do bug do escudo, Jul/2026):
-- o dano do inimigo é diferido pro apex da investida — TUDO que roda
-- depois do golpe (expiração do bloqueio, mana, compra) precisa esperar.
-- Este teste teria pego o bug que o dono encontrou jogando.
--   love . smoke_turn_order

local M = {}

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- smoke: ordem do turno (escudo vs apex) ----")

    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    require("src.i18n.I18n").init()
    local Game = require("src.core.Game")
    local EnemyRenderer = require("src.ui.EnemyRenderer")

    local function pump(game, secs)
        local dt = 1 / 30
        for _ = 1, math.floor(secs * 30) do
            _G.EventManager.update(dt)
            EnemyRenderer.update(dt)
            if game.enemy and game.enemy.update then game.enemy:update(dt) end
            if game.combatAnimationSystem then game.combatAnimationSystem:update(dt) end
        end
    end

    -- ===== 1. ESCUDO ABSORVE O GOLPE DIFERIDO (o bug do playtest) =====
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    pump(game, 0.5)

    game.enemy.nextIntent = "attack"
    game.enemy.damage = 8
    game.enemy.baseDamage = 8
    game.battleTurn = 1               -- longe da Fúria
    game.player.armor = 20
    local hpBefore = game.player.health

    game.turn = "enemy"
    game:enemyTurn()

    -- ANTES do apex (~0.34s): o golpe ainda não aterrissou — o escudo NÃO
    -- pode ter expirado e o HP não pode ter mudado.
    pump(game, 0.15)
    check("pré-apex: escudo ainda de pé (não expirou antes do golpe)",
        game.player.armor >= 20)
    check("pré-apex: HP intacto (dano não aplicado ainda)",
        game.player.health == hpBefore)

    -- DEPOIS do apex + continuação: golpe absorvido pelo escudo, HP intacto,
    -- e SÓ ENTÃO o escudo expira (início do turno do jogador).
    pump(game, 1.0)
    check("pós-golpe: HP intacto (20 de escudo absorveu 8 de dano)",
        game.player.health == hpBefore)
    check("pós-golpe: escudo expirou APÓS absorver (novo turno)",
        game.player.armor == 0)
    check("turno voltou pro jogador", game.turn == "player")

    -- ===== 2. GOLPE SEM ESCUDO FERE =====
    local game2 = Game:new()
    game2:startNewRun("warrior")
    game2:startGame()
    pump(game2, 0.5)
    game2.enemy.nextIntent = "attack"
    game2.enemy.damage = 8
    game2.enemy.baseDamage = 8
    game2.battleTurn = 1
    game2.player.armor = 0
    local hp2 = game2.player.health
    game2.turn = "enemy"
    game2:enemyTurn()
    pump(game2, 1.2)
    check("sem escudo: dano integral chegou no HP",
        game2.player.health == hp2 - 8)

    -- ===== 3. BASTIÃO: escudo NÃO expira =====
    local game3 = Game:new()
    game3:startNewRun("warrior")
    game3:startGame()
    pump(game3, 0.5)
    game3.player.retainArmor = true    -- flag do joker
    game3.enemy.nextIntent = "defend"  -- inimigo não ataca (escudo intocado)
    game3.battleTurn = 1
    game3.player.armor = 12
    game3.turn = "enemy"
    game3:enemyTurn()
    pump(game3, 1.0)
    check("Bastião: escudo sobrevive à virada do turno",
        game3.player.armor == 12)

    -- ===== 4. endTurn descarta e passa a vez =====
    local game4 = Game:new()
    game4:startNewRun("warrior")
    game4:startGame()
    pump(game4, 0.5)
    local handSize = #game4.hand
    check("mão inicial > 0", handSize > 0)
    game4:endTurn()
    check("endTurn: mão descartada", #game4.hand == 0)
    check("endTurn: vez do inimigo", game4.turn == "enemy")

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
