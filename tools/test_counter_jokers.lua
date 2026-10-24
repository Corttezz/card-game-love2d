local TK = require("tools.testkit")
local Enemy = require("src.entities.Enemy")
local EnemyRoster = require("src.systems.EnemyRoster")
local BM = require("src.systems.BossMechanics")
local Counter = require("src.systems.CounterJokers")

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

M.IDS = {
    "joker_counter_lantern", "joker_counter_brazier", "joker_counter_antidote",
    "joker_counter_salamander", "joker_counter_weak", "joker_counter_frail",
    "joker_counter_vulnerable",
}

M.BY_DEBUFF = {
    poison = "joker_counter_antidote", burn = "joker_counter_salamander",
    weak = "joker_counter_weak", frail = "joker_counter_frail",
    vulnerable = "joker_counter_vulnerable",
}

local function equip(g, ids)
    g.jokerSlots = {}
    local db = g.deckManager.cardDatabase
    for _, id in ipairs(ids or {}) do
        g.jokerSlots[#g.jokerSlots + 1] = db:createCardInstance(db:getCard(id))
    end
    g._counterProcs = 0
end

local function battleWith(id, ids)
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.3)
    if id then
        g.enemy = EnemyRoster.spawn(Enemy, id, { health = 400, damage = 10 })
        g.enemy.spriteId = id
    end
    g._deathHandled, g._deathStaged = false, false
    g.player.health = g.player.maxHealth
    g.battleTurn = 1
    equip(g, ids)
    return g
end

local function runEnemyTurn(g)
    g.player.armor = 99
    g.turn = "enemy"
    g._enemyActing = false
    g:enemyTurn()
    TK.pump(g, 8)
end

local function testData(t)
    local db = TK.newRunGame("warrior").deckManager.cardDatabase
    local art = require("src.data.card_art")
    local I18n = require("src.i18n.I18n")
    local Unlock = require("src.systems.UnlockSystem")
    for _, id in ipairs(M.IDS) do
        local cd = db:getCard(id)
        t:truthy(id .. ": existe", cd)
        if cd then
            t:eq(id .. ": coringa", cd.type, "joker")
            t:eq(id .. ": incomum", cd.rarity, "uncommon")
            t:eq(id .. ": neutro", cd.class, "basic")
            t:truthy(id .. ": ameaça reconhecida", Counter.threatOfCard(cd))
            for _, loc in ipairs(LOCALES) do
                I18n.setLocale(loc, true)
                local label = I18n.effectDesc(cd.effects[1])
                t:truthy(id .. " [" .. loc .. "]: efeito com rótulo traduzido", label ~= cd.effects[1].type)
            end
            I18n.setLocale("pt_BR", true)
        end
        local a = art[id]
        t:truthy(id .. ": atlas", a and a.icon)
        if a and a.icon then
            t:truthy(id .. ": ícone", love.filesystem.getInfo("assets/sprites/icons/" .. a.icon .. ".png"))
            t:truthy(id .. ": ícone animado",
                love.filesystem.getInfo("assets/sprites/icons_anim/" .. a.icon .. "/frame_000.png"))
        end
        t:truthy(id .. ": assinatura sonora", love.filesystem.getInfo("audio/sfx/joker-sig/" .. id .. ".mp3"))
        t:truthy(id .. ": desbloqueado", Unlock.isCardUnlockedReal(id))
        for _, loc in ipairs(LOCALES) do
            local tbl = require("src.i18n.locales." .. loc)
            local e = tbl.cards and tbl.cards[id]
            t:truthy(id .. " [" .. loc .. "]: nome e descrição", e and e.name and e.desc)
            if e and e.desc then
                t:falsy(id .. " [" .. loc .. "]: sem travessão", e.desc:find("\226\128\148") or e.desc:find("\226\128\147"))
            end
        end
    end
    for _, loc in ipairs(LOCALES) do
        local tbl = require("src.i18n.locales." .. loc)
        for _, k in ipairs({ "immune", "frost", "thaw", "sight" }) do
            t:truthy("proc " .. k .. " [" .. loc .. "]", tbl.counter_jokers and tbl.counter_jokers.proc[k])
        end
        for _, kw in ipairs({ "immune", "fog", "frost", "frail", "burn" }) do
            t:truthy("glossário " .. kw .. " [" .. loc .. "]", tbl.keyword and tbl.keyword[kw] and tbl.keyword[kw].text)
        end
    end
    I18n.setLocale("pt_BR")
end

local function testDebuffs(t)
    for name, id in pairs(M.BY_DEBUFF) do
        local g = battleWith(nil, { id })
        g.enemy:forceIntent("attack", g.player)
        g.enemy.intent.debuffs = { { name = name, duration = 2, stacks = 3 } }
        runEnemyTurn(g)
        t:falsy(id .. ": " .. name .. " não entra", g.player:hasDebuff(name))
        t:truthy(id .. ": tique do coringa", (g._counterProcs or 0) >= 1)

        local g2 = battleWith(nil, {})
        g2.enemy:forceIntent("attack", g2.player)
        g2.enemy.intent.debuffs = { { name = name, duration = 2, stacks = 3 } }
        runEnemyTurn(g2)
        t:truthy("sem coringa: " .. name .. " entra", g2.player:hasDebuff(name))

        local g3 = battleWith(nil, { id })
        local other = name == "weak" and "frail" or "weak"
        g3.enemy:forceIntent("attack", g3.player)
        g3.enemy.intent.debuffs = { { name = other, duration = 2, stacks = 1 } }
        runEnemyTurn(g3)
        t:truthy(id .. ": não protege de " .. other, g3.player:hasDebuff(other))
        t:eq(id .. ": sem tique quando a ameaça não vem", g3._counterProcs or 0, 0)
    end
end

local function frozenCount(g)
    local n = 0
    for _, c in ipairs(g.hand) do if c.frozen then n = n + 1 end end
    return n
end

local function testFrost(t)
    local g = battleWith("winter_monarch", { "joker_counter_brazier" })
    g.enemy.isBoss = true
    g.player.frost = 0
    g.enemy:forceIntent("royal_blizzard", g.player)
    t:eq("braseiro: anúncio continua congelado (+2 no intent)", g.enemy:getIntent().frost, 2)
    runEnemyTurn(g)
    t:eq("braseiro: Geada não acumula", g.player.frost or 0, 0)
    t:truthy("braseiro: tique ao barrar a Geada", (g._counterProcs or 0) >= 1)
    g.player.frost = 4
    local res = BM.onPlayerDraw(g)
    t:falsy("braseiro: nada congela mesmo com Geada no limiar", res)
    t:eq("braseiro: mão sem carta congelada", frozenCount(g), 0)

    local g2 = battleWith("winter_monarch", {})
    g2.enemy.isBoss = true
    g2.player.frost = 0
    g2.enemy:forceIntent("royal_blizzard", g2.player)
    runEnemyTurn(g2)
    t:eq("sem braseiro: Geada acumula 2", g2.player.frost, 2)
    g2.player.frost = 4
    BM.onPlayerDraw(g2)
    t:truthy("sem braseiro: cartas congelam", frozenCount(g2) >= 1)

    local g3 = battleWith("carrion_king", { "joker_counter_brazier" })
    g3.enemy.isBoss = true
    g3.enemy:forceIntent(g3.enemy:getIntent().id, g3.player)
    runEnemyTurn(g3)
    t:eq("braseiro fora do Monarca: nenhum tique", g3._counterProcs or 0, 0)
end

local function testSight(t)
    local Rng = require("src.systems.Rng")
    local function sample(ids, n)
        local g = battleWith("frost_wight", ids)
        g.enemy.fogContext = { biomeId = "frost", progress = 1, hall = true, density = 0.9 }
        TK.seedRng(4242)
        g._counterProcs = 0
        local levels = {}
        for i = 1, n do levels[i] = g.enemy:refreshIntentVisibility() end
        return levels, Rng.get():random("misc"), g
    end
    local plain, r1 = sample({}, 8)
    local lit, r2, g = sample({ "joker_counter_lantern" }, 8)
    local hidden = 0
    for i = 1, #plain do
        if plain[i] ~= "full" then hidden = hidden + 1 end
        t:eq("lanterna: intenção sempre visível (" .. i .. ")", lit[i], "full")
    end
    t:truthy("sem lanterna o véu do Espectro esconde", hidden > 0)
    t:eq("lanterna: stream misc intocado", r2, r1)
    t:truthy("lanterna: tique ao revelar", (g._counterProcs or 0) >= hidden)
    t:eq("lanterna: causa marcada", g.enemy.intentVeilCause, "lantern")
    t:truthy("lanterna: número conhecido", g.enemy:getKnownIncomingDamage(g.player) ~= nil)

    local g2 = battleWith(nil, { "joker_counter_lantern" })
    g2.enemy.fogContext = nil
    g2._counterProcs = 0
    t:eq("lanterna em céu limpo: full", g2.enemy:refreshIntentVisibility(), "full")
    t:eq("lanterna em céu limpo: sem tique", g2._counterProcs, 0)
end

local function testAllQuiet(t)
    local g = battleWith(nil, M.IDS)
    g.enemy:forceIntent("attack", g.player)
    g.enemy.intent.debuffs = nil
    local hp = g.player.health
    runEnemyTurn(g)
    t:eq("todos os 7 sem ameaça: nenhum tique", g._counterProcs or 0, 0)
    t:eq("todos os 7 sem ameaça: armadura absorveu igual", g.player.health, hp)
end

local function testOffersAndPilot(t)
    local db = TK.newRunGame("warrior").deckManager.cardDatabase
    local brazier = db:getCard("joker_counter_brazier")
    t:eq("oferta: braseiro fraco no ato 1", Counter.offerWeight(brazier, 1), Counter.IDLE_OFFER_WEIGHT)
    t:eq("oferta: braseiro cheio no ato 3 (prepara o 4)", Counter.offerWeight(brazier, 3), Counter.OFFER_WEIGHT)
    t:eq("oferta: braseiro cheio no ato 4", Counter.offerWeight(brazier, 4), Counter.OFFER_WEIGHT)
    t:eq("oferta: lanterna cheia no ato 6", Counter.offerWeight(db:getCard("joker_counter_lantern"), 6), Counter.OFFER_WEIGHT)
    t:eq("oferta: carta comum não muda", Counter.offerWeight(db:getCard("joker_combo_volley"), 1), 1)
    t:eq("piloto: braseiro vale 0 no ato 1", Counter.pilotScore(brazier.effects[1], 1), 0)
    t:truthy("piloto: braseiro vale no ato 4", Counter.pilotScore(brazier.effects[1], 4) > 0)
    t:truthy("piloto: antídoto vale no ato 5", Counter.pilotScore(db:getCard("joker_counter_antidote").effects[1], 5) > 0)
    t:eq("piloto: efeito comum não é contra", Counter.pilotScore({ type = "damage_bonus" }, 1), nil)

    local g = TK.newRunGame("warrior")
    local pool = {}
    for _, id in ipairs(g.cardRegistry and g.cardRegistry:_poolFor("warrior", "uncommon") or {}) do pool[id] = true end
    if g.cardRegistry then
        for _, id in ipairs(M.IDS) do
            t:truthy("pool incomum do guerreiro: " .. id, pool[id])
        end
    end
end

function M.run()
    local t = TK.new("coringas contra: névoa, Geada e debuffs no jogador")
    TK.bootstrap()
    TK.seedRng(5151)
    testData(t)
    testDebuffs(t)
    testFrost(t)
    testSight(t)
    testAllQuiet(t)
    testOffersAndPilot(t)
    return t:done()
end

return M
