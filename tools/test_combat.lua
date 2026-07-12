-- tools/test_combat.lua
-- Integração de combate (Game.lua): seleção/mana, remoção da mão, pipeline de
-- dano/defesa, ciclo de turno, vitória/derrota, slots de joker.
-- Usa pump() pro combate diferido (apex), como smoke_turn_order.
--   love . test_combat

local TK = require("tools.testkit")

local M = {}

local function findInHand(game, cardType)
    for _, c in ipairs(game.hand) do
        if c.type == cardType then return c end
    end
    return nil
end

function M.run()
    local t = TK.new("combate: Game (integração)")

    -- ===== Seleção e mana =====
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.5)
    t:truthy("mão inicial > 0", #g.hand > 0)
    t:eq("mana inicial 3", g.player.mana, 3)

    local card = g.hand[1]
    local cost = card.cost
    g:selectCard(card)
    t:truthy("selectCard marca a carta", g:isCardSelected(card))
    t:eq("selectCard debita mana", g.player.mana, 3 - cost)
    g:selectCard(card)  -- toggle -> deseleciona
    t:falsy("segundo selectCard desseleciona", g:isCardSelected(card))
    t:eq("deselect devolve mana", g.player.mana, 3)

    -- mana insuficiente: canPlayCard false e não seleciona
    g.player.mana = 0
    t:falsy("canPlayCard false sem mana", g:canPlayCard(card))
    g:selectCard(card)
    t:falsy("selectCard não seleciona sem mana", g:isCardSelected(card))

    -- ===== playSelectedCards remove da mão imediatamente =====
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    local handBefore = #g.hand
    local first = g.hand[1]
    g:selectCard(first)
    g:playSelectedCards()
    t:eq("carta jogada sai da mão na hora", #g.hand, handBefore - 1)

    -- ===== Pipeline de ATAQUE: dano exato (starter, sem combo/força) =====
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    local atk = findInHand(g, "attack")
    if atk then
        local enemyHp = g.enemy.health
        local expected = atk.attack  -- força 0, sem combo (1 carta), sem edition
        g:selectCard(atk)
        g:playSelectedCards()
        TK.pump(g, 2.0)
        t:eq("ataque causa dano base no inimigo", g.enemy.health, enemyHp - expected)
        t:eq("selectedCards limpo após combate", #g.selectedCards, 0)
    else
        t:truthy("mão tinha carta de ataque", false)
    end

    -- ===== Pipeline de DEFESA: armadura exata =====
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    local def = findInHand(g, "defense")
    if def then
        g:selectCard(def)
        g:playSelectedCards()
        TK.pump(g, 2.0)
        t:eq("defesa vira armadura (dex 0)", g.player.armor, def.defense)
    else
        t:truthy("mão tinha carta de defesa", false)
    end

    -- ===== Força soma no dano =====
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    local atk2 = findInHand(g, "attack")
    if atk2 then
        g.player:gainStrength(3)
        local enemyHp = g.enemy.health
        g:selectCard(atk2)
        g:playSelectedCards()
        TK.pump(g, 2.0)
        t:eq("dano = ataque + força", g.enemy.health, enemyHp - (atk2.attack + 3))
    end

    -- ===== Ciclo de turno: endTurn descarta e passa a vez =====
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    t:eq("turno começa no jogador", g.turn, "player")
    g:endTurn()
    t:eq("endTurn -> vez do inimigo", g.turn, "enemy")

    -- ===== Vitória / Derrota =====
    -- isPhaseCleared
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    t:falsy("fase não limpa com inimigo vivo", g:isPhaseCleared())
    g.enemy.health = 0
    t:truthy("isPhaseCleared com inimigo morto", g:isPhaseCleared())

    -- checkVictory: precisa ato 3, andar 8, boss, inimigo morto
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    local run = g.runManager.currentRun
    run.actNumber = 3; run.floorInAct = 8; run.endlessMode = false
    run.currentNode = { type = "boss" }
    g.enemy.health = 0
    t:truthy("checkVictory no boss final", g:checkVictory())
    t:eq("gameState vira victory", g.gameState, "victory")

    -- checkGameOver: HP <= 0 (save vai pra sandbox *.tool.lua)
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    t:falsy("game over false com HP > 0", g:checkGameOver())
    g.player.health = 0
    t:truthy("checkGameOver com HP 0", g:checkGameOver())
    t:eq("gameState vira gameOver", g.gameState, "gameOver")

    -- ===== Slots de joker (máx 3) =====
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    t:truthy("canAcceptJoker inicial", g:canAcceptJoker())
    t:truthy("add joker_001", g:addJokerToRun("joker_001"))
    t:truthy("add joker_002", g:addJokerToRun("joker_002"))
    t:truthy("add joker_003", g:addJokerToRun("joker_003"))
    t:falsy("slots cheios -> canAcceptJoker false", g:canAcceptJoker())
    t:falsy("4o joker rejeitado", g:addJokerToRun("joker_004"))
    t:eq("exatamente 3 jokers", #g.jokerSlots, 3)

    return t:done()
end

return M
