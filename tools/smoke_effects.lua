local Player = require("src.entities.Player")
local Enemy = require("src.entities.Enemy")
local EffectSystem = require("src.systems.EffectSystem")

local M = {}

local function makeMockGame()
    local game = {
        player = Player:new(),
        enemy = Enemy:new(100, 5),
        hand = {},
        jokerSlots = {},
        score = 0,
        messages = {},
    }
    function game:addMessage(text, level) table.insert(self.messages, { text = text, level = level }) end
    return game
end

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- Fase 2 effects smoke test ----")
    local ES = EffectSystem:new()

    local g = makeMockGame()
    ES:processEffectCard(g, { type = "gain_strength", value = 3 })
    check("gain_strength soma em player.strength", g.player.strength == 3)
    local attackCard = { type = "attack", attack = 10, effects = {} }
    local dmg = 10 + g.player.strength
    check("ataque base 10 + strength 3 = 13", dmg == 13)

    local g2 = makeMockGame()
    g2.player.strength = 5
    local scalingCard = { type = "attack", attack = 10, effects = { { type = "strength_scaling" } } }
    local base = 10
    base = ES:applyCardEffects(g2, scalingCard, base)
    check("strength_scaling é flag-only (não duplica strength)", base == 10)

    local g3 = makeMockGame()
    local multiCard = { type = "attack", attack = 5, effects = { { type = "multi_hit", value = 3 } } }
    local base3 = ES:applyCardEffects(g3, multiCard, 5)
    check("multi_hit x3 sobre base 5 = 15", base3 == 15)

    local g4 = makeMockGame()
    ES:processEffectCard(g4, { type = "channel_orb", orbType = "lightning", value = 4 })
    check("channel_orb empilha 1 orb", #g4.player.orbs == 1)
    ES:processEffectCard(g4, { type = "evoke_orb" })
    check("evoke_orb remove orb e causa dano", #g4.player.orbs == 0 and g4.enemy.health == 96)

    local g5 = makeMockGame()
    ES:processEffectCard(g5, { type = "channel_orb", orbType = "ice", value = 6 })
    ES:processEffectCard(g5, { type = "evoke_orb" })
    check("ice orb evoca armor", g5.player.armor == 6)

    local g6 = makeMockGame()
    g6.player.orbSlots = 3
    ES:processEffectCard(g6, { type = "channel_orb", orbType = "lightning", value = 2 })
    ES:processEffectCard(g6, { type = "channel_orb", orbType = "lightning", value = 2 })
    ES:processEffectCard(g6, { type = "channel_orb", orbType = "lightning", value = 2 })
    local hpBefore = g6.enemy.health
    ES:processEffectCard(g6, { type = "channel_orb", orbType = "lightning", value = 2 })
    check("overflow: auto-evoca o mais antigo (damage)", g6.enemy.health == hpBefore - 2)
    check("overflow: mantem orbSlots=3 cheios", #g6.player.orbs == 3)

    local g7 = makeMockGame()
    ES:processEffectCard(g7, { type = "channel_orb", orbType = "lightning", value = 3 })
    ES:processEffectCard(g7, { type = "channel_orb", orbType = "lightning", value = 3 })
    ES:processEffectCard(g7, { type = "evoke_all_orbs" })
    check("evoke_all zera orbs", #g7.player.orbs == 0)
    check("evoke_all causa dano total (2x3=6)", g7.enemy.health == 94)

    local g8 = makeMockGame()
    ES:processEffectCard(g8, { type = "apply_debuff", value = "poison", stacks = 3, duration = 2 })
    check("poison adicionado com 3 stacks", g8.enemy:getStatusStacks("poison") == 3)
    local dot = g8.enemy:onTurnEnd()
    check("onTurnEnd retorna dano de poison (3)", dot == 3)
    check("poison aplicou 3 de dano ao HP", g8.enemy.health == 97)
    local secondDot = g8.enemy:onTurnEnd()
    check("poison persiste 1 turno a mais", secondDot == 3 and g8.enemy.health == 94)
    local thirdDot = g8.enemy:onTurnEnd()
    check("poison expirou ao fim da duracao", thirdDot == 0 and not g8.enemy:hasStatus("poison"))

    local g9 = makeMockGame()
    ES:processEffectCard(g9, { type = "apply_debuff", value = "vulnerable", duration = 2 })
    local hpB = g9.enemy.health
    g9.enemy:takeDamage(10)
    check("vulnerable: dano 10 vira 15", hpB - g9.enemy.health == 15)

    local g10 = makeMockGame()
    ES:processEffectCard(g10, { type = "apply_debuff", value = "weak", duration = 2 })
    local atkDmg = g10.enemy:performAttack()
    check("weak: 5 de ataque vira 3 (floor(5*0.75))", atkDmg == 3)

    local g11 = makeMockGame()
    g11.player:gainStrength(5)
    g11.player:addOrb({ type = "lightning", value = 2 })
    g11.player:addBuff("focus", 3, 1)
    g11.player:resetTransientStats()
    check("resetTransientStats zera strength", g11.player.strength == 0)
    check("resetTransientStats zera orbs", #g11.player.orbs == 0)
    check("resetTransientStats zera buffs", #g11.player.buffs == 0)

    local g12 = makeMockGame()
    g12.player:addBuff("focus", 2, 1)
    check("buff focus adicionado", g12.player:getBuffStacks("focus") == 1)
    g12.player:onTurnStart()
    check("buff focus duration 2->1", #g12.player.buffs == 1)
    g12.player:onTurnStart()
    check("buff focus expirou", #g12.player.buffs == 0)

    local g13 = makeMockGame()
    ES:processEffectCard(g13, { type = "gain_dexterity", value = 4 })
    check("gain_dexterity soma em player.dexterity", g13.player.dexterity == 4)

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
