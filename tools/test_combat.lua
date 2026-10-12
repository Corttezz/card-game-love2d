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

    -- ===== COMBO v3 no combate real: a leva grande cresce LINEAR =====
    -- 3 golpes: Impeto (+1 Forca antes das cartas) -> x1.5 em cada golpe e o
    -- +10 do Triplo Golpe UMA vez (na 1a carta). Antes: x1.4 e +6 em CADA carta.
    do
        local CardDatabase = require("src.systems.CardDatabase")
        local db = CardDatabase:new()
        g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
        g.enemy.health, g.enemy.maxHealth, g.enemy.armor = 500, 500, 0
        g.player.mana = 10
        g.hand = {}
        local strikes = {}
        for i = 1, 3 do
            strikes[i] = db:createCardInstance(db:getCard("warrior_strike"))
            g.hand[i] = strikes[i]
        end
        for _, c in ipairs(strikes) do g:selectCard(c) end
        local a = strikes[1].attack
        local expected = math.floor((a + 1) * 1.5 + 10) + 2 * math.floor((a + 1) * 1.5)
        local preview = require("src.systems.DamagePreview").simulate(g, g.selectedCards)
        g:playSelectedCards()
        TK.pump(g, 6.0)
        t:eq("v3: 3 golpes = x1.5 em cada + 10 uma vez", 500 - g.enemy.health, expected)
        t:eq("v3: previa bate com o golpe real", preview.damage, expected)
    end

    -- ===== Passivas que CRESCEM na luta (balanceamento de classe, Out/2026) =====
    do
        local CardDatabase = require("src.systems.CardDatabase")
        local db = CardDatabase:new()
        local function playIds(gm, ids)
            gm.hand = {}
            gm.player.mana = 20
            for i, id in ipairs(ids) do gm.hand[i] = db:createCardInstance(db:getCard(id)) end
            for _, c in ipairs(gm.hand) do gm:selectCard(c) end
            gm:playSelectedCards()
            TK.pump(gm, 8.0)
        end
        -- Conduite: 2 cartas de orbe no turno = +1 Foco (uma vez por turno)
        local gm = TK.newRunGame("mage"); TK.pump(gm, 0.5)
        gm.enemy.health, gm.enemy.maxHealth = 999, 999
        local f0 = gm.player:getBuffStacks("focus")
        playIds(gm, { "mage_zap", "mage_lightning" })
        t:eq("Conduite: 2 cartas de orbe = +1 Foco", gm.player:getBuffStacks("focus"), f0 + 1)
        playIds(gm, { "mage_zap", "mage_lightning" })
        t:eq("Conduite: so 1x por turno", gm.player:getBuffStacks("focus"), f0 + 1)

        -- Toxinas: 2 ataques no turno = +1 no Veneno da passiva (na batalha)
        local gr = TK.newRunGame("rogue"); TK.pump(gr, 0.5)
        gr.enemy.health, gr.enemy.maxHealth = 999, 999
        gr.enemy.statusEffects = {}
        playIds(gr, { "rogue_strike", "rogue_strike" })
        local G = require("src.core.Game")
        t:eq("Toxinas: bonus +TOXIN_GROWTH na batalha", gr._toxinBonus, G.TOXIN_GROWTH)
        t:eq("Toxinas: 1o ataque aplica tier+bonus de Veneno",
            gr.enemy:getStatusStacks("poison"), gr:classPassiveTier() + G.TOXIN_GROWTH)

        -- Orbe pelo coringa: o maior damage_multiplier vale no evoke
        local go = TK.newRunGame("mage"); TK.pump(go, 0.5)
        go.enemy.health, go.enemy.maxHealth, go.enemy.armor = 999, 999, 0
        go.enemy.statusEffects = {}
        go.jokerSlots = { { id = "t_mult", effects = {
            { type = "damage_multiplier", target = "attack", value = 1.5 } } } }
        go.player.orbs = { { type = "lightning", value = 6 } }
        go.player.buffs = {}
        local hp0 = go.enemy.health
        go.effectSystem:_evokeOrbEffect(go, table.remove(go.player.orbs, 1))
        t:eq("evoke de raio 6 com coringa x1.5 = 9", hp0 - go.enemy.health, 9)
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

    -- checkVictory: precisa do ULTIMO ato, andar 8, boss, inimigo morto.
    -- Ancorado em Config.TotalActs — a campanha foi de 3 pra 6 atos em
    -- Set/2026 e um "3" cravado aqui passaria a testar o meio do jogo.
    g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    local run = g.runManager.currentRun
    run.actNumber = require("src.core.Config").TotalActs
    run.floorInAct = 8; run.endlessMode = false
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
    -- Coringas = COLEÇÃO + BANCADA (CLAUDE.md): joker NUNCA é rejeitado por
    -- slots cheios — o 4º entra na BANCADA (nunca se perde). jokerSlots =
    -- só os ATIVOS (até MAX_JOKER_SLOTS). Atualizado no merge Jul/2026 (o
    -- assert antigo encodava a rejeição pré-refactor).
    t:truthy("aceita joker mesmo com 3 ativos (bancada)", g:canAcceptJoker())
    t:truthy("4o joker aceito (vai pra bancada)", g:addJokerToRun("joker_004"))
    t:eq("jokerSlots = ativos (MAX 3)", #g.jokerSlots, 3)
    t:eq("coleção da run acumula os 4", #g.runManager.currentRun.jokers, 4)

    -- ===== Passivas que crescem com a run (Out/2026) =====
    -- Conduite (Foco) e Toxinas (Veneno) sobem 1 degrau a cada 2 atos.
    local function focusAt(act)
        local gm = TK.newRunGame("mage")
        gm.runManager.currentRun.actNumber = act
        gm.player.buffs = {}
        gm:applyClassBattleStartPassive()
        for _, b in ipairs(gm.player.buffs) do
            if b.name == "focus" then return b.stacks end
        end
        return 0
    end
    t:eq("Conduite: Foco 0 nos atos 1-2", focusAt(2), 0)
    t:eq("Conduite: Foco 1 nos atos 3-4", focusAt(3), 1)
    t:eq("Conduite: Foco 2 nos atos 5-6", focusAt(6), 2)
    local gr = TK.newRunGame("rogue")
    gr.runManager.currentRun.actNumber = 5
    t:eq("Toxinas: 3 de Veneno nos atos 5-6", gr:classPassiveTier(), 3)

    return t:done()
end

return M
