local TK = require("tools.testkit")
local Player = require("src.entities.Player")
local Enemy = require("src.entities.Enemy")

local M = {}

function M.run()
    local t = TK.new("entities: Player + Enemy")

    local p = Player:new()
    t:eq("Player.new health = maxHealth (60)", p.health, 60)
    t:eq("Player.new mana = maxMana (3)", p.mana, 3)
    t:eq("Player.new armor = 0", p.armor, 0)
    t:eq("Player.new strength = 0", p.strength, 0)

    p = Player:new(); p.armor = 5
    p:takeDamage(8)
    t:eq("takeDamage(8) com armor 5 -> HP -3", p.health, 57)
    t:eq("takeDamage(8) com armor 5 -> armor 0", p.armor, 0)

    p = Player:new(); p.armor = 20
    p:takeDamage(8)
    t:eq("takeDamage(8) com armor 20 -> HP intacto", p.health, 60)
    t:eq("takeDamage(8) com armor 20 -> armor 12", p.armor, 12)

    p = Player:new(); p.armor = 30
    p:loseHealth(5)
    t:eq("loseHealth(5) ignora armor -> HP 55", p.health, 55)
    t:eq("loseHealth nao mexe em armor", p.armor, 30)

    p = Player:new(); p.health = 50
    p:heal(20)
    t:eq("heal cap em maxHealth", p.health, 60)

    p = Player:new()
    p:addArmor(25); p:addArmor(25)
    t:eq("addArmor cap em maxArmor (30)", p.armor, 30)

    p = Player:new()
    t:truthy("spendMana(3) ok", p:spendMana(3))
    t:eq("mana zerada", p.mana, 0)
    t:falsy("spendMana(1) sem mana falha", p:spendMana(1))
    t:eq("mana nao ficou negativa", p.mana, 0)
    p:restoreMana()
    t:eq("restoreMana volta ao maxMana", p.mana, 3)

    p = Player:new()
    p:gainStrength(3); p:gainStrength(2)
    t:eq("gainStrength acumula", p.strength, 5)
    p:gainDexterity(4)
    t:eq("gainDexterity acumula", p.dexterity, 4)

    p = Player:new(); p.armor = 15
    p:onTurnStart()
    t:eq("onTurnStart zera armor", p.armor, 0)

    p = Player:new(); p.armor = 15; p.retainArmor = true
    p:onTurnStart()
    t:eq("onTurnStart com retainArmor preserva", p.armor, 15)

    p = Player:new()
    p:addBuff("focus", 2, 1)
    t:eq("addBuff cria com stacks", p:getBuffStacks("focus"), 1)
    p:onTurnStart()
    t:eq("buff sobrevive turno 1", p:getBuffStacks("focus"), 1)
    p:onTurnStart()
    t:eq("buff expira em duration 0", p:getBuffStacks("focus"), 0)

    p = Player:new()
    p:addBuff("focus", 2, 1); p:addBuff("focus", 1, 2)
    t:eq("addBuff acumula stacks", p:getBuffStacks("focus"), 3)

    p = Player:new()
    t:eq("orbSlots padrao 3", p.orbSlots, 3)
    local of1 = p:addOrb({ type = "lightning", value = 3 })
    t:falsy("addOrb sem overflow", of1)
    p:addOrb({ type = "ice", value = 2 })
    p:addOrb({ type = "dark", value = 4 })
    local overflow = p:addOrb({ type = "fire", value = 5 })
    t:truthy("4o orb estoura (overflow retornado)", overflow ~= nil)
    t:eq("overflow e o mais antigo (lightning)", overflow and overflow.type, "lightning")
    t:eq("orbs mantem cap 3", #p.orbs, 3)

    p = Player:new()
    p:gainStrength(5); p:gainDexterity(3); p:addArmor(10); p:addBuff("x", 3, 1)
    p:addOrb({ type = "ice", value = 1 })
    p:resetTransientStats()
    t:eq("reset zera strength", p.strength, 0)
    t:eq("reset zera dexterity", p.dexterity, 0)
    t:eq("reset zera armor", p.armor, 0)
    t:eq("reset zera orbs", #p.orbs, 0)
    t:eq("reset zera buffs", #p.buffs, 0)

    local e = Enemy:new(50, 8)
    t:eq("Enemy.new health", e.health, 50)
    t:eq("Enemy.new damage", e.damage, 8)
    t:eq("Enemy.new armor 0", e.armor, 0)

    e = Enemy:new(100, 8); e.armor = 5
    e:takeDamage(12)
    t:eq("enemy takeDamage(12) armor 5 -> HP -7", e.health, 93)
    t:eq("enemy armor consumida", e.armor, 0)

    e = Enemy:new(100, 8)
    e:addStatusEffect({ name = "vulnerable", duration = 2 })
    e:takeDamage(10)
    t:eq("vulnerable: 10 -> 15 de dano", e.health, 85)

    e = Enemy:new(100, 8); e.armor = 5
    e:addStatusEffect({ name = "vulnerable", duration = 2 })
    e:takeDamage(10)
    t:eq("vulnerable+armor: HP -10", e.health, 90)

    e = Enemy:new(100, 10)
    e:takeDamage(75)
    t:eq("fúria aumenta damage p/ baseDamage*1.5", e.damage, 15)
    t:eq("fúria muda attackPattern", e.attackPattern, "aggressive")

    e = Enemy:new(100, 10)
    e:addStatusEffect({ name = "weak", duration = 2 })
    e.attackCooldown = 0
    t:eq("weak: performAttack 10 -> 7", e:performAttack(), 7)

    e = Enemy:new(100, 25)
    t:eq("getDefendAmount clamp em maxArmor 20", e:getDefendAmount(), 20)
    e = Enemy:new(100, 3)
    t:eq("getDefendAmount minimo 6", e:getDefendAmount(), 6)

    e = Enemy:new(100, 8)
    e:addArmor(15); e:addArmor(15)
    t:eq("enemy addArmor cap 20", e.armor, 20)

    e = Enemy:new(100, 8)
    e:addStatusEffect({ name = "poison", stacks = 3, duration = 2 })
    local d1 = e:onTurnEnd()
    t:eq("poison tick 1 = 3 dano", d1, 3)
    t:eq("poison tick 1 HP", e.health, 97)
    t:truthy("poison ainda ativo (duration 1)", e:hasStatus("poison"))
    local d2 = e:onTurnEnd()
    t:eq("poison tick 2 = 3 dano (stacks persistem)", d2, 3)
    t:eq("poison tick 2 HP", e.health, 94)
    t:falsy("poison expira apos duration 0", e:hasStatus("poison"))
    t:eq("onTurnEnd sem poison = 0", e:onTurnEnd(), 0)

    e = Enemy:new(100, 8); e.armor = 2
    e:addStatusEffect({ name = "poison", stacks = 3, duration = 1 })
    e:onTurnEnd()
    t:eq("poison ignora armor -> HP -3", e.health, 97)
    t:eq("poison nao consome armor", e.armor, 2)

    e = Enemy:new(100, 8)
    e:addStatusEffect({ name = "poison", stacks = 2, duration = 2 })
    e:addStatusEffect({ name = "poison", stacks = 1, duration = 1 })
    t:eq("poison acumula stacks", e:getStatusStacks("poison"), 3)

    e = Enemy:new(100, 8)
    local valid = { attack = true, strong = true, defend = true, buff = true }
    local allValid = true
    for _ = 1, 40 do
        e:rollIntent()
        if not valid[e.nextIntent] then allValid = false end
    end
    t:truthy("rollIntent sempre em {attack,strong,defend,buff}", allValid)

    return t:done()
end

return M
