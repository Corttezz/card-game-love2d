local TK = require("tools.testkit")

local M = {}

local function body(t)
    TK.bootstrap()
    local EffectSystem = require("src.systems.EffectSystem")
    local CardDatabase = require("src.systems.CardDatabase")
    local TagSystem = require("src.systems.TagSystem")
    local db = CardDatabase:new()
    local es = EffectSystem:new()

    local function card(id)
        local data = db:getCard(id)
        t:truthy("carta existe: " .. id, data)
        return data and db:createCardInstance(data)
    end
    local function joker(id) return card(id) end
    local function fresh()
        local g = TK.mockGame({ enemyHp = 999 })
        function g:spawnBattleCopy(c) return { id = c.id, type = c.type, cost = c.cost } end
        return g
    end

    local deus = joker("joker_001")
    local bufao = joker("joker_005")
    local eclipse = joker("joker_boss_eclipse")
    local metal = card("defense_001")
    t:truthy("defense_001 é Metálica", metal and TagSystem.cardHasTag(metal, "metal"))

    local g = fresh()
    g.jokerSlots = { deus }
    local atk = { type = "attack", cost = 1 }
    for _ = 1, 5 do g.hand[#g.hand + 1] = card("defense_001") end
    t:near("Deus do Abismo: ×1,5 por Metálica na mão (5 → ×7,59)",
        (es:applyJokerEffects(g, atk, 10)), 10 * 1.5 ^ 5)

    g.selectedCards = { g.hand[1], g.hand[2] }
    t:near("Metálicas jogadas não contam (3 na mão → ×3,375)",
        (es:applyJokerEffects(g, atk, 10)), 10 * 1.5 ^ 3)
    g.selectedCards = nil

    g.hand = {}
    t:eq("sem Metálica na mão o Deus não mexe", (es:applyJokerEffects(g, atk, 10)), 10)

    g = fresh()
    g.jokerSlots = { bufao }
    local ctx = { activeCombos = { {}, {} } }
    t:near("Chapéu do Bufão: ×1,25 por combo ativo (2 → ×1,5625)",
        (es:applyJokerEffects(g, atk, 10, ctx)), 10 * 1.25 ^ 2)

    g = fresh()
    g.jokerSlots = { eclipse }
    local def = { type = "defense", cost = 1 }
    t:eq("Halo do Eclipse: primeira carta do turno ecoa (defesa também)",
        (es:applyJokerEffects(g, def, 10)), 20)
    t:eq("Halo do Eclipse: a segunda sai limpa", (es:applyJokerEffects(g, atk, 10)), 10)

    g = fresh()
    g.jokerSlots = { deus, bufao, eclipse }
    for _ = 1, 5 do g.hand[#g.hand + 1] = card("defense_001") end
    local snow = es:applyJokerEffects(g, atk, 10, ctx)
    t:near("BOLA DE NEVE: Deus + Bufão + Eclipse compõem (≈237)",
        snow, 10 * 1.5 ^ 5 * 1.25 ^ 2 * 2)
    t:check("bola de neve passa de 20× o golpe base", snow > 200)

    g = fresh()
    local strike = card("attack_001") or { id = "attack_001", type = "attack" }
    local mirror = card("effect_mystery_card")
    g._currentTurnContext = { allSelectedCards = { strike, mirror } }
    es:processEffectCard(g, mirror.effects[1], mirror)
    t:eq("Espelho de Forja copia a carta ANTERIOR para o descarte",
        g.discard[1] and g.discard[1].id, strike.id)
    g = fresh()
    g._currentTurnContext = { allSelectedCards = { mirror } }
    es:processEffectCard(g, mirror.effects[1], mirror)
    t:eq("Espelho de Forja sozinho avisa e não copia", #g.discard, 0)

    g = fresh()
    local leech = card("rogue_leech_blade")
    for _, e in ipairs(leech.effects) do
        if e.type == "copy_to_discard" then es:processEffectCard(g, e, leech) end
    end
    t:eq("Lâmina Sanguessuga se multiplica no descarte", g.discard[1] and g.discard[1].id,
        "rogue_leech_blade")

    g = fresh()
    g.jokerSlots = { joker("rogue_toxin_master") }
    g.enemy:addStatusEffect({ name = "poison", stacks = 6, duration = 6 })
    es:holdPoison(g)
    g.enemy:onTurnEnd()
    t:eq("Mestre das Toxinas: veneno NÃO decai", g.enemy:getStatusStacks("poison"), 6)
    g = fresh()
    g.enemy:addStatusEffect({ name = "poison", stacks = 6, duration = 6 })
    es:holdPoison(g)
    g.enemy:onTurnEnd()
    t:eq("sem o coringa o veneno decai normal", g.enemy:getStatusStacks("poison"), 5)

    g = fresh()
    g.jokerSlots = { joker("warrior_dark_embrace") }
    for _ = 1, 4 do es:applyTriggerEffects(g, "exhaust", {}) end
    t:eq("Abraço Sombrio: cada exaustão compra 1", #g.hand, 4)
    t:eq("Abraço Sombrio: cinzas acumulam +1 por exaustão", EffectSystem.ashBonus(g), 4)
    t:eq("cinzas somam no ataque (10 → 14)", (es:applyJokerEffects(g, atk, 10)), 14)

    g = fresh()
    g.jokerSlots = { joker("joker_004") }
    local drawn = 0
    for i = 1, 8 do
        g._cardsPlayedTurn = i
        es:applyTriggerEffects(g, "card_played", {})
    end
    drawn = #g.hand
    t:eq("Bobo da Corte: +1 carta a cada 4 jogadas (8 → 2)", drawn, 2)

    g = fresh()
    g.jokerSlots = { joker("mage_electrodynamics") }
    g.player.orbs = g.player.orbs or {}
    local before = #g.player.orbs
    es:applyTriggerEffects(g, "evoke", { orb = { type = "lightning", value = 3 } })
    t:eq("Eletrodinâmica: evocar Raio recanaliza um Raio", #g.player.orbs, before + 1)

    g = fresh()
    g.jokerSlots = { joker("mage_rune_of_power") }
    t:eq("Runa do Poder: +3 de foco para Raio",
        (EffectSystem.orbFocusBonus(g, { type = "lightning" })), 3)
    t:eq("Runa do Poder: nada para Gelo", (EffectSystem.orbFocusBonus(g, { type = "ice" })), 0)

    local dop = db:getCard("rogue_doppelganger")
    local drawN, mana = 0, 0
    for _, e in ipairs(dop.effects) do
        if e.type == "draw_cards" then drawN = e.value end
        if e.type == "restore_mana" then mana = e.value end
    end
    t:check("Sósia é motor de loop: devolve a mana que custa e compra mais de 1",
        mana >= (dop.cost or 0) and drawN >= 2)
end

function M.run()
    local t = TK.new("combos #509: coringas em bola de neve e motores")
    local ok, err = pcall(body, t)
    if not ok then t:check("sem erro: " .. tostring(err), false) end
    return t:done()
end

return M
