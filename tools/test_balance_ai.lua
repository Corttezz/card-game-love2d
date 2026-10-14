local TK = require("tools.testkit")
local AI = require("tools.balance_ai")

local M = {}

local function inst(id)
    local CardDatabase = require("src.systems.CardDatabase")
    return CardDatabase:createCardInstance(CardDatabase:getCard(id))
end

local function names(set)
    local out = {}
    for _, c in ipairs(set) do out[#out + 1] = c.id end
    table.sort(out)
    return table.concat(out, ",")
end

local function setup(class, handIds, enemyHp, enemyDmg, intent)
    local g = TK.newRunGame(class)
    TK.pump(g, 0.3)
    g.hand, g.deck, g.discard = {}, {}, {}
    for _, id in ipairs(handIds) do g.hand[#g.hand + 1] = inst(id) end
    for _ = 1, 6 do g.deck[#g.deck + 1] = inst("rogue_strike") end
    local Enemy = require("src.entities.Enemy")
    g.enemy = Enemy:new(enemyHp, enemyDmg)
    g.enemy.nextIntent = intent or "attack"
    g.enemy.nextIntentDamage = enemyDmg
    g.player.orbs, g.player.buffs = {}, {}
    g.player.strength, g.player.dexterity = 0, 0
    g._toxinAppliedThisTurn = false
    g.jokerSlots = {}
    return g
end

function M.run()
    local t = TK.new("piloto v6: decisoes de turno")
    TK.bootstrap()

    do
        local g = setup("rogue", { "rogue_strike", "rogue_poison_dart", "rogue_bouncing_flask",
            "rogue_dirty_blade", "rogue_strike" }, 220, 18, "buff")
        g.player.maxMana, g.player.mana = 5, 5
        local bctx = AI.newBattle(g)
        local best, sc = AI.bestSet(g, bctx)
        t:check("turno livre: joga cartas de dano (escolheu " .. names(best) .. ", score "
            .. tostring(sc) .. ")", #best >= 3)
        local S = AI.simulate(g, best, bctx)
        t:check("turno livre: dano relevante (" .. (220 - S.eHp) .. ")", 220 - S.eHp >= 20)
    end

    do
        local g = setup("warrior", { "warrior_strike", "warrior_strike", "warrior_defend" }, 16, 30, "attack")
        local bctx = AI.newBattle(g)
        local picks, why = AI.planLeva(g, bctx)
        t:eq("acha o lethal com 2 Golpes", why, "LETHAL")
    end

    do
        local g = setup("warrior", { "warrior_strike", "warrior_defend", "defense_bulwark" }, 200, 25, "attack")
        g.player.health = 20
        local bctx = AI.newBattle(g)
        local best = AI.bestSet(g, bctx)
        local S = AI.simulate(g, best, bctx)
        t:check("golpe de 25 com 20 de vida: sobrevive (" .. names(best) .. ")", S.hp - S.hpLoss > 0)
    end

    do
        local g = setup("warrior", { "warrior_bash", "warrior_strike" }, 300, 5, "buff")
        local bctx = AI.newBattle(g)
        local S = AI.simulate(g, { g.hand[1], g.hand[2] }, bctx)
        t:check("Vulneravel da Pancada amplifica o Golpe seguinte (dano " .. (300 - S.eHp) .. ")",
            300 - S.eHp > 10 + 8)
    end

    do
        local g = setup("mage", { "mage_magic_barrier" }, 5, 40, "attack")
        g.player.orbs = { { type = "lightning", value = 10 } }
        local bctx = AI.newBattle(g)
        local picks, why = AI.planLeva(g, bctx)
        local S = AI.simulate(g, {}, bctx)
        t:check("pulso do orbe mata o inimigo de 5 HP antes do golpe", S.lethal)
    end

    do
        local g = setup("rogue", { "rogue_doppelganger", "rogue_doppelganger", "rogue_strike" }, 400, 0, "attack")
        local bctx = AI.newBattle(g)
        local best = AI.bestSet(g, bctx)
        local has = false
        for _, c in ipairs(best) do if c.id == "rogue_strike" then has = true end end
        t:check("ciclo + ataque: o plano inclui o ataque (" .. names(best) .. ")", has)
    end

    return t:done()
end

return M
