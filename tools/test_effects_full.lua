-- tools/test_effects_full.lua
-- Cobertura ampla do EffectSystem além do smoke_effects: appliers contínuos de
-- joker (multiplicadores/bônus com gating), applyCardEffects (multi_hit,
-- damage_bonus_self), todos os processEffectCard, orbs por tipo (lightning/ice/
-- dark/fire/holy + overflow), triggers (attack/defend/turn_start), heal_multiplier.
-- Conferido em src/systems/EffectSystem.lua.
--   love . test_effects_full

local TK = require("tools.testkit")
local EffectSystem = require("src.systems.EffectSystem")

local M = {}

function M.run()
    TK.bootstrap()
    TK.seedRng(555)
    local t = TK.new("efeitos: EffectSystem (completo)")
    local es = EffectSystem:new()

    -- ===== processEffect: appliers contínuos de joker (com gating) =====
    local atkCard, defCard = { type = "attack" }, { type = "defense" }
    local v = es:processEffect({ type = "damage_multiplier", target = "attack", value = 2 }, atkCard, 10, {})
    t:eq("damage_multiplier x2 em attack", v, 20)
    v = es:processEffect({ type = "damage_multiplier", target = "attack", value = 2 }, defCard, 10, {})
    t:eq("damage_multiplier NÃO afeta defense", v, 10)
    v = es:processEffect({ type = "defense_multiplier", target = "defense", value = 2 }, defCard, 10, {})
    t:eq("defense_multiplier x2 em defense", v, 20)
    v = es:processEffect({ type = "damage_bonus", value = 5 }, atkCard, 10, {})
    t:eq("damage_bonus +5 em attack", v, 15)
    v = es:processEffect({ type = "defense_bonus", value = 3 }, defCard, 10, {})
    t:eq("defense_bonus +3 em defense", v, 13)

    -- ===== applyCardEffects: só multi_hit e damage_bonus_self =====
    local g0 = TK.mockGame()
    local mh = { type = "attack", effects = { { type = "multi_hit", value = 3 } } }
    t:eq("multi_hit x3", es:applyCardEffects(g0, mh, 5), 15)
    local dbs = { type = "attack", effects = { { type = "damage_bonus_self", value = 4 } } }
    t:eq("damage_bonus_self +4", es:applyCardEffects(g0, dbs, 10), 14)
    -- strength_scaling é flag-only aqui (não altera valor)
    local ss = { type = "attack", effects = { { type = "strength_scaling" } } }
    t:eq("strength_scaling é flag-only (não altera)", es:applyCardEffects(g0, ss, 10), 10)

    -- ===== processEffectCard: cada tipo =====
    local function fresh() return TK.mockGame({ enemyHp = 100 }) end

    local g = fresh(); g.player.health = 40
    es:processEffectCard(g, { type = "instant_heal", value = 10 })
    t:eq("instant_heal +10", g.player.health, 50)

    g = fresh()
    es:processEffectCard(g, { type = "self_damage", value = 5 })
    t:eq("self_damage -5 (ignora armor)", g.player.health, 55)

    g = fresh(); g.player:spendMana(3)
    es:processEffectCard(g, { type = "restore_mana", value = 2 })
    t:eq("restore_mana +2", g.player.mana, 2)

    g = fresh()
    es:processEffectCard(g, { type = "increase_max_mana", value = 2 })
    t:eq("increase_max_mana sobe maxMana", g.player.maxMana, 5)

    g = fresh()
    es:processEffectCard(g, { type = "add_armor", value = 8 })
    t:eq("add_armor +8", g.player.armor, 8)

    g = fresh()
    es:processEffectCard(g, { type = "magic_damage", value = 8 })
    t:eq("magic_damage no inimigo", g.enemy.health, 92)
    t:eq("magic_damage soma score", g.score, 8)

    g = fresh()
    es:processEffectCard(g, { type = "aoe_magic_damage", value = 6 })
    t:eq("aoe_magic_damage no inimigo", g.enemy.health, 94)

    g = fresh()
    es:processEffectCard(g, { type = "draw_cards", value = 3 })
    t:eq("draw_cards puxa 3", #g.hand, 3)

    g = fresh()
    g.hand = { { id = "a" }, { id = "b" }, { id = "c" } }
    g.discard = {}
    es:processEffectCard(g, { type = "discard_cards", value = 2 })
    t:eq("discard_cards remove 2 da mão", #g.hand, 1)
    -- REGRESSÃO (Jul/2026): a carta descartada TEM que ir pro discard, não
    -- sumir. Antes table.remove só arrancava da mão → o deck de batalha
    -- degenerava (Sobrevivente comia 1 carta/turno até sobrar só as 3 jogadas).
    t:eq("discard_cards move as 2 pro discard (não deleta)", #g.discard, 2)

    g = fresh()
    es:processEffectCard(g, { type = "apply_debuff", value = "poison", stacks = 3, duration = 2 })
    t:eq("apply_debuff poison stacks", g.enemy:getStatusStacks("poison"), 3)
    t:truthy("apply_debuff poison ativo", g.enemy:hasStatus("poison"))

    g = fresh()
    es:processEffectCard(g, { type = "gain_strength", value = 2 })
    t:eq("gain_strength +2", g.player.strength, 2)
    es:processEffectCard(g, { type = "gain_dexterity", value = 3 })
    t:eq("gain_dexterity +3", g.player.dexterity, 3)

    g = fresh()
    es:processEffectCard(g, { type = "apply_buff", value = "focus", stacks = 2, duration = 3 })
    t:eq("apply_buff focus stacks", g.player:getBuffStacks("focus"), 2)

    -- retorno de fallback: efeito desconhecido -> handled=false
    g = fresh()
    t:falsy("efeito desconhecido -> handled false", es:processEffectCard(g, { type = "xyz_nao_existe", value = 1 }))

    -- ===== Orbs: channel/evoke por tipo =====
    g = fresh()
    es:processEffectCard(g, { type = "channel_orb", orbType = "lightning", value = 7 })
    t:eq("channel_orb empilha 1", #g.player.orbs, 1)
    t:eq("orb é do tipo canalizado", g.player.orbs[1].type, "lightning")
    es:processEffectCard(g, { type = "evoke_orb" })
    t:eq("evoke lightning = dano direto", g.enemy.health, 93)
    t:eq("evoke esvazia orb", #g.player.orbs, 0)

    -- ice -> armor
    g = fresh()
    es:processEffectCard(g, { type = "channel_orb", orbType = "ice", value = 5 })
    es:processEffectCard(g, { type = "evoke_orb" })
    t:eq("evoke ice = +armor", g.player.armor, 5)

    -- dark -> dano dobrado
    g = fresh()
    es:processEffectCard(g, { type = "channel_orb", orbType = "dark", value = 5 })
    es:processEffectCard(g, { type = "evoke_orb" })
    t:eq("evoke dark = 2x dano", g.enemy.health, 90)

    -- fire -> dano + poison
    g = fresh()
    es:processEffectCard(g, { type = "channel_orb", orbType = "fire", value = 6 })
    es:processEffectCard(g, { type = "evoke_orb" })
    t:eq("evoke fire = dano", g.enemy.health, 94)
    t:truthy("evoke fire aplica poison", g.enemy:hasStatus("poison"))

    -- holy -> cura
    g = fresh(); g.player.health = 40
    es:processEffectCard(g, { type = "channel_orb", orbType = "holy", value = 8 })
    es:processEffectCard(g, { type = "evoke_orb" })
    t:eq("evoke holy = cura", g.player.health, 48)

    -- overflow: 4o orb evoca o mais antigo automaticamente
    g = fresh()
    for _ = 1, 4 do es:processEffectCard(g, { type = "channel_orb", orbType = "lightning", value = 5 }) end
    t:eq("orbs mantêm cap 3", #g.player.orbs, 3)
    t:eq("overflow auto-evocou o mais antigo (-5)", g.enemy.health, 95)

    -- evoke_all_orbs
    g = fresh()
    es:processEffectCard(g, { type = "channel_orb", orbType = "ice", value = 3 })
    es:processEffectCard(g, { type = "channel_orb", orbType = "lightning", value = 4 })
    es:processEffectCard(g, { type = "evoke_all_orbs" })
    t:eq("evoke_all: ice deu armor", g.player.armor, 3)
    t:eq("evoke_all: lightning deu dano", g.enemy.health, 96)
    t:eq("evoke_all esvazia orbs", #g.player.orbs, 0)

    -- mystery: sempre resolvido (handled), sem crash
    g = fresh()
    t:truthy("mystery é handled", es:processEffectCard(g, { type = "mystery" }))

    -- ===== applyHealMultiplier (joker heal_multiplier) =====
    g = fresh()
    g.jokerSlots = { { effects = { { type = "heal_multiplier", value = 2 } } } }
    t:eq("heal_multiplier dobra cura", es:applyHealMultiplier(g, 10), 20)

    -- ===== Triggers =====
    -- on_attack_heal (lifesteal) via joker
    g = fresh(); g.player.health = 50
    g.jokerSlots = { { effects = { { type = "on_attack_heal", value = 3 } } } }
    es:applyTriggerEffects(g, "attack", { target = g.enemy })
    t:eq("on_attack_heal cura no ataque", g.player.health, 53)

    -- on_defend_damage (reflete) via joker
    g = fresh()
    g.jokerSlots = { { effects = { { type = "on_defend_damage", value = 4 } } } }
    es:applyTriggerEffects(g, "defend", { target = g.enemy })
    t:eq("on_defend_damage reflete no alvo", g.enemy.health, 96)

    -- regen_per_turn / damage_per_turn no turn_start
    g = fresh(); g.player.health = 50
    g.jokerSlots = { { effects = { { type = "regen_per_turn", value = 5 } } } }
    es:applyTriggerEffects(g, "turn_start", {})
    t:eq("regen_per_turn cura no início do turno", g.player.health, 55)

    g = fresh(); g.player.health = 50
    g.jokerSlots = { { effects = { { type = "damage_per_turn", value = 3 } } } }
    es:applyTriggerEffects(g, "turn_start", {})
    t:eq("damage_per_turn fere no início do turno", g.player.health, 47)

    -- trigger via sourceCard (carta non-joker) — on_defend_damage numa defense card
    g = fresh()
    local reflectCard = { type = "defense", effects = { { type = "on_defend_damage", value = 6 } } }
    es:applyTriggerEffects(g, "defend", { target = g.enemy, sourceCard = reflectCard })
    t:eq("trigger de sourceCard também dispara", g.enemy.health, 94)

    -- ===== P0.9 (rebalance v2): LARGEST-MULTIPLIER-WINS entre jokers =====
    -- 2 jokers x1.5 NAO compõem (x2.25) — só o maior multiplicador conta;
    -- bônus flat continuam somando todos. Regressão exigida pela crítica A1.
    g = fresh()
    g.jokerSlots = {
        { effects = { { type = "damage_multiplier", target = "attack", value = 1.5 } } },
        { effects = { { type = "damage_multiplier", target = "attack", value = 1.5 } } },
    }
    local atkCard = { type = "attack" }
    t:eq("2 jokers x1.5: só o maior conta (15, não 22)",
        es:applyJokerEffects(g, atkCard, 10), 15)
    g.jokerSlots[2].effects[1].value = 2.0
    t:eq("maior multiplicador vence (x2.0)",
        es:applyJokerEffects(g, atkCard, 10), 20)
    table.insert(g.jokerSlots, { effects = { { type = "damage_bonus", value = 3 } } })
    table.insert(g.jokerSlots, { effects = { { type = "damage_bonus", value = 2 } } })
    t:eq("bônus flat somam TODOS por cima do maior x",
        es:applyJokerEffects(g, atkCard, 10), 25)

    -- ===== Game feel v1: applyJokerEffects retorna PROCS (ticks Balatro) =====
    -- Cada joker que MUDOU o valor gera um proc {slotIndex, joker, label, kind}
    -- pro tick sequencial no slot. Previsão (predictJokerProcs) deve bater.
    do
        local finalV, procs = es:applyJokerEffects(g, atkCard, 10)
        t:eq("procs: valor inalterado (25)", finalV, 25)
        t:eq("procs: 3 contribuições (1 mult largest-wins + 2 flat)", #procs, 3)
        t:eq("procs: rótulo do multiplicador", procs[1].label, "×2")
        t:eq("procs: slotIndex aponta o joker do MAIOR mult", procs[1].slotIndex, 2)
        t:eq("procs: rótulo do flat", procs[2].label, "+3")
        t:eq("predictJokerProcs bate com o real", es:predictJokerProcs(g, atkCard), 3)
        t:eq("predictJokerProcs: carta de efeito não proca", es:predictJokerProcs(g, { type = "effect" }), 0)
    end

    -- ===== P2.3 (rebalance v2): thorn de JOKER dispara 1x/turno =====
    -- Duas defesas na mesma rodada: joker reflete só na primeira; thorn de
    -- CARTA (sourceCard) segue disparando por carta jogada.
    g = fresh()
    g.jokerSlots = { { effects = { { type = "on_defend_damage", value = 4 } } } }
    es:applyTriggerEffects(g, "defend", { target = g.enemy })
    es:applyTriggerEffects(g, "defend", { target = g.enemy })
    t:eq("thorn de joker: 2 defesas refletem 1x (-4)", g.enemy.health, 96)
    local thornCard2 = { type = "defense", effects = { { type = "on_defend_damage", value = 6 } } }
    es:applyTriggerEffects(g, "defend", { target = g.enemy, sourceCard = thornCard2 })
    es:applyTriggerEffects(g, "defend", { target = g.enemy, sourceCard = thornCard2 })
    t:eq("thorn de carta segue por carta (-12)", g.enemy.health, 84)

    return t:done()
end

return M
