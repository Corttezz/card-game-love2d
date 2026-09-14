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

    -- fire -> dano + QUEIMADURA (status proprio; NAO veneno)
    -- Set/2026: o dono, jogando de MAGO, viu veneno empilhando no inimigo e
    -- estranhou com razao -- veneno e o eixo do LADINO e nenhuma carta de mago
    -- aplica. O ramo `fire` de _evokeOrbEffect usava "poison" como atalho
    -- ("via poison por ora; refinar"), e o "por ora" ficou. Este par de
    -- asserções e o que impede o atalho de voltar.
    g = fresh()
    es:processEffectCard(g, { type = "channel_orb", orbType = "fire", value = 6 })
    es:processEffectCard(g, { type = "evoke_orb" })
    t:eq("evoke fire = dano", g.enemy.health, 94)
    t:truthy("evoke fire aplica QUEIMADURA", g.enemy:hasStatus("burn"))
    t:falsy("evoke fire NAO aplica veneno (veneno e identidade do ladino)",
        g.enemy:hasStatus("poison"))

    -- ===== QUEIMADURA: o DoT proprio do fogo =====
    -- Mecanica IGUAL a do veneno (stacks de dano por turno, pela duracao,
    -- absorvido pela armadura) com status SEPARADO -- o pedido nao era
    -- rebalancear, era parar de mentir. Estas asserções travam as duas metades:
    -- que a queimadura queima de verdade, e que ela nao e veneno.
    do
        local Enemy = require("src.entities.Enemy")
        local e = Enemy:new(50, 5)
        e:addStatusEffect({ name = "burn", duration = 2, stacks = 3 })
        t:truthy("queimadura entra como status proprio", e:hasStatus("burn"))
        t:falsy("queimadura NAO e veneno", e:hasStatus("poison"))

        -- Tica no MESMO lugar que o veneno (Enemy:onTurnEnd), com a mesma
        -- cadencia: o dano sai ANTES do decremento de duration.
        local _, b1 = e:onTurnEnd()
        t:eq("1a queimadura tica os stacks", b1, 3)
        local _, b2 = e:onTurnEnd()
        t:eq("2a queimadura tica os stacks", b2, 3)
        local _, b3 = e:onTurnEnd()
        t:eq("queimadura expira depois da duracao", b3, 0)
        t:eq("total queimado = stacks x duracao (igual ao veneno)",
            50 - e.health, 6)

        -- O 1o retorno continua sendo o VENENO (chamadas antigas nao mudam) e
        -- os dois DoTs sao numeros SEPARADOS, nunca somados num so.
        local e4 = Enemy:new(50, 5)
        e4:addStatusEffect({ name = "poison", duration = 1, stacks = 2 })
        e4:addStatusEffect({ name = "burn", duration = 1, stacks = 3 })
        local pv, bv = e4:onTurnEnd()
        t:eq("veneno e queimadura sao contados SEPARADOS (veneno)", pv, 2)
        t:eq("veneno e queimadura sao contados SEPARADOS (queimadura)", bv, 3)
        t:eq("e os dois doem", 50 - e4.health, 5)

        local e2 = Enemy:new(50, 5)
        e2.armor = 2
        e2:addStatusEffect({ name = "burn", duration = 1, stacks = 5 })
        e2:onTurnEnd()
        t:eq("armadura absorve queimadura, como no veneno", e2.health, 47)
        t:eq("e a armadura e consumida", e2.armor, 0)

        local e3 = Enemy:new(3, 5)
        e3:addStatusEffect({ name = "burn", duration = 1, stacks = 9 })
        e3:onTurnEnd()
        t:eq("queimadura mata", e3.health, 0)
        t:truthy("morrer QUEIMADO marca a morte (senao a animacao nao roda)",
            e3._pendingDeath == true)
    end

    -- ===== VENENO E IDENTIDADE DO LADINO =====
    -- Varredura do catalogo inteiro. Foi ESTA fronteira que o atalho do fogo
    -- furava: o mago via a pill de Veneno e ia procurar no proprio deck uma
    -- carta que nao existe -- alem de disparar a conquista de 15+ veneno e o
    -- combo `poison_stack`, que sao do ladino.
    do
        local CardDatabase = require("src.systems.CardDatabase")
        local offenders, sources = {}, 0
        for id, cd in pairs(CardDatabase:getAllCards()) do
            local applies = false
            for _, ef in ipairs(cd.effects or {}) do
                if (ef.type == "apply_debuff" and ef.value == "poison")
                    or ef.debuffName == "poison" then
                    applies = true
                end
            end
            if applies then
                sources = sources + 1
                if cd.class ~= "rogue" then
                    offenders[#offenders + 1] = id .. "(" .. tostring(cd.class) .. ")"
                end
            end
        end
        table.sort(offenders)
        t:truthy("o catalogo TEM fontes de veneno (" .. sources .. ")", sources >= 5)
        t:eq("VENENO so vem do ladino (" .. table.concat(offenders, ", ") .. ")",
            #offenders, 0)
    end

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

    -- on_defend_damage ARMA ESPINHOS (Set/2026) — nao causa dano na hora.
    -- Contrato novo: a carta/joker vira o buff "thorn"; quem dispara o dano
    -- e o GOLPE do inimigo (Game:enemyTurn -> fireThornReflect). Ver test_beats.
    g = fresh()
    g.jokerSlots = { { effects = { { type = "on_defend_damage", value = 4 } } } }
    es:applyTriggerEffects(g, "defend", { target = g.enemy })
    t:eq("on_defend_damage NAO fere ao jogar a carta", g.enemy.health, 100)
    t:eq("on_defend_damage arma 4 de espinhos", g.player:getBuffStacks("thorn"), 4)
    t:eq("espinhos duram 1 turno (expiram no proximo upkeep)",
        g.player.buffs[1].duration, 1)
    es:fireThornReflect(g)
    t:eq("fireThornReflect cobra os 4 no inimigo", g.enemy.health, 96)

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
    t:eq("trigger de sourceCard também dispara (arma espinhos)",
        g.player:getBuffStacks("thorn"), 6)
    t:eq("sourceCard: inimigo intacto ate ele atacar", g.enemy.health, 100)

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

    -- ===== P2.3 (rebalance v2): thorn de JOKER ARMA 1x/turno =====
    -- A intencao de balanceamento sobreviveu a migracao pro modelo de ESTADO
    -- (Set/2026): o TETO por turno e o mesmo de antes — joker contribui uma
    -- vez, carta contribui por carta jogada. O que mudou e QUANDO o dano sai.
    g = fresh()
    g.jokerSlots = { { effects = { { type = "on_defend_damage", value = 4 } } } }
    es:applyTriggerEffects(g, "defend", { target = g.enemy })
    es:applyTriggerEffects(g, "defend", { target = g.enemy })
    t:eq("thorn de joker: 2 defesas armam 1x (4)", g.player:getBuffStacks("thorn"), 4)
    local thornCard2 = { type = "defense", effects = { { type = "on_defend_damage", value = 6 } } }
    es:applyTriggerEffects(g, "defend", { target = g.enemy, sourceCard = thornCard2 })
    es:applyTriggerEffects(g, "defend", { target = g.enemy, sourceCard = thornCard2 })
    t:eq("thorn de carta acumula por carta (4 + 6 + 6 = 16)",
        g.player:getBuffStacks("thorn"), 16)
    t:eq("espinhos empilhados nao esticam a duracao (1 turno)",
        g.player.buffs[1].duration, 1)
    es:fireThornReflect(g)
    t:eq("o golpe do inimigo cobra o total de uma vez (-16)", g.enemy.health, 84)

    return t:done()
end

return M
