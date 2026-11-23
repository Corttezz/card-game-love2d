local TK = require("tools.testkit")

local M = {}

local KIT_COUNTER = {
    carrion_king = "no_thorns",       tower_lich = "card_flood",
    abyss_tyrant = "strength_tax",    winter_monarch = "metal_freeze",
    rot_colossus = "drink_poison",    eclipse_queen = "eclipse_first",
    storm_griffin = "lightning_rod",  fallen_angel = "copy_exile",
    spore_mother = "exhaust_tax",     rune_golem = "magnet",
    spectral_knight = "pierce_all",   blood_duke = "blood_mirror",
}

local ARCHETYPES = { "metal", "lightning", "loop", "copies", "strength", "poison",
    "thorns", "block", "exhaust", "blood", "echo" }

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

local function body(t)
    TK.bootstrap()
    local Enemy = require("src.entities.Enemy")
    local EnemyKits = require("src.data.enemies")
    local AC = require("src.systems.ArchetypeCounters")
    local BM = require("src.systems.BossMechanics")
    local EffectSystem = require("src.systems.EffectSystem")
    local DamagePreview = require("src.systems.DamagePreview")
    local CardDatabase = require("src.systems.CardDatabase")
    local TagSystem = require("src.systems.TagSystem")
    local db = CardDatabase:new()

    local function card(id)
        local data = db:getCard(id)
        return data and db:createCardInstance(data)
    end
    local function fresh(kitId, hp)
        local g = TK.mockGame({ enemyHp = hp or 500 })
        g.enemy = Enemy:new(hp or 500, 10, kitId)
        g._cardsPlayedTurn = 0
        return g
    end
    local function fired(g, kind) return (g._counterFires or {})[kind] or 0 end

    local covered = {}
    for kitId, kind in pairs(KIT_COUNTER) do
        local kit = EnemyKits.KITS[kitId]
        t:truthy("kit existe: " .. kitId, kit)
        t:eq("contra do " .. kitId, kit and kit.counter and kit.counter.kind, kind)
        covered[AC.ARCHETYPE[kind] or "?"] = true
        local e = Enemy:new(300, 10, kitId)
        t:eq("pill de contra no " .. kitId, BM.stacks(e, AC.STATUS), 1)
        local vars = BM.pillVars(e, AC.STATUS)
        t:eq("pill vars variante " .. kitId, vars and vars.variant, kind)
        local d = AC.describe(e)
        t:check("aviso na tela tem texto: " .. kitId, d and d ~= "" and not d:find("{", 1, true))
    end
    for _, a in ipairs(ARCHETYPES) do
        t:truthy("arquétipo tem contra: " .. a, covered[a])
    end

    for _, loc in ipairs(LOCALES) do
        local L = require("src.i18n.locales.enemy_kit." .. loc)
        local st = L.status and L.status.counter
        t:truthy(loc .. ": status.counter", st and st.name)
        for _, kind in pairs(KIT_COUNTER) do
            t:truthy(loc .. ": desc_" .. kind, st and st["desc_" .. kind])
            if kind ~= "pierce_all" then
                t:truthy(loc .. ": msg.counter_" .. kind, L.msg and L.msg["counter_" .. kind])
            end
        end
        t:truthy(loc .. ": msg.counter_intro", L.msg and L.msg.counter_intro)
        t:truthy(loc .. ": msg.counter_card_flood_warn", L.msg and L.msg.counter_card_flood_warn)
    end

    local g = fresh("generic")
    AC.announce(g)
    t:eq("inimigo comum não anuncia contra", #g.messages, 0)
    g = fresh("winter_monarch")
    AC.announce(g)
    t:check("chefe anuncia o contra antes do golpe",
        g.messages[1] and g.messages[1].level == "warning")

    local metal = card("defense_001")
    t:check("defense_001 é Metálica", metal and TagSystem.cardHasTag(metal, "metal"))

    g = fresh("winter_monarch")
    local f0 = g.player.frost or 0
    AC.onCardPlayed(g, metal)
    t:eq("Monarca: Metálica jogada soma Geada", g.player.frost, f0 + 1)
    local hand = { { id = "a", type = "attack", cost = 3 }, card("defense_001"),
        { id = "b", type = "attack", cost = 2 } }
    local picks = BM.freezePicks(hand, 1, AC.freezeTag(g))
    t:eq("Monarca: congela a Metálica primeiro", picks[1], hand[2])
    g.hand = { card("defense_001"), card("defense_001") }
    g.hand[1].frozen = true
    t:eq("carta congelada não conta como segurada", EffectSystem.heldTagCount(g, "metal"), 1)

    g = fresh("rune_golem")
    local a0 = g.enemy.armor
    local mag = AC.spec(g.enemy).value
    AC.onCardPlayed(g, metal)
    t:eq("Golem: Metálica dá Bloqueio a ele", g.enemy.armor, a0 + mag)
    AC.onCardPlayed(g, { id = "x", type = "attack" })
    t:eq("Golem: carta comum não dá", g.enemy.armor, a0 + mag)

    g = fresh("rune_golem")
    local sim = DamagePreview.simulate(g, { metal })
    t:truthy("prévia roda com o Golem", sim)

    g = fresh("tower_lich")
    local m = BM.spec(g.enemy)
    local r0 = BM.stacks(g.enemy, m.status)
    local flood = AC.spec(g.enemy)
    for n = 1, flood.from - 1 do g._cardsPlayedTurn = n; AC.onCardPlayed(g, { id = "x", type = "skill" }) end
    t:eq("Lich: antes do limite nada acende", BM.stacks(g.enemy, m.status), r0)
    t:eq("Lich: avisa uma carta antes", fired(g, "card_flood_warn"), 1)
    g._cardsPlayedTurn = flood.from
    local arm0 = g.enemy.armor
    AC.onCardPlayed(g, { id = "x", type = "skill" })
    t:eq("Lich: carta do limite acende runa", BM.stacks(g.enemy, m.status), r0 + 1)
    t:eq("Lich: carta do limite dá Bloqueio", g.enemy.armor, math.min(g.enemy.maxArmor, arm0 + flood.value))

    g = fresh("fallen_angel")
    local dop = { id = "rogue_doppelganger", type = "skill" }
    t:falsy("Anjo: 1ª Sósia volta ao descarte", AC.exiles(g, dop))
    t:truthy("Anjo: 2ª Sósia no turno é banida", AC.exiles(g, dop))
    g._playedIdsTurn = {}
    t:falsy("Anjo: novo turno zera", AC.exiles(g, dop))
    local copy = require("src.core.Game").spawnBattleCopy({ deckManager = { cardDatabase = db } },
        card("warrior_strike"), false)
    t:truthy("cópia de luta vem marcada", copy and copy.battleCopy)
    t:truthy("Anjo: cópia criada na luta é banida já na 1ª", AC.exiles(g, copy))

    g = fresh("abyss_tyrant")
    g.player.strength = 3
    t:eq("Tirano: abaixo do limite não rouba", AC.onPlayerTurnEnd(g), 0)
    g.player.strength = 9
    local d0 = g.enemy.damage
    t:eq("Tirano: rouba metade (9 → 4)", AC.onPlayerTurnEnd(g), 4)
    t:eq("Tirano: Força fica 5", g.player.strength, 5)
    t:eq("Tirano: ele ganha o roubo", g.enemy.damage, d0 + 4)

    g = fresh("rot_colossus")
    g.enemy.health = 400
    g.enemy:addStatusEffect({ name = "poison", stacks = 20, duration = 20 })
    local roots = BM.stacks(g.enemy, BM.spec(g.enemy).status)
    local drank = AC.drinkPoison(g)
    local sip = AC.spec(g.enemy).value
    t:eq("Colosso: cada raiz bebe o valor do contra", drank, math.min(20, roots * sip))
    t:eq("Colosso: cura o que bebeu", g.enemy.health, 400 + math.min(20, roots * sip))

    g = fresh("carrion_king")
    t:truthy("Rei Carniça: Espinhos bloqueados", AC.blocksThorns(g))
    g = fresh("generic")
    t:falsy("inimigo comum: Espinhos refletem", AC.blocksThorns(g))

    t:truthy("Cavaleiro: todo golpe atravessa", AC.piercesAll(Enemy:new(100, 10, "spectral_knight")))
    t:falsy("comum não atravessa", AC.piercesAll(Enemy:new(100, 10, "generic")))

    g = fresh("storm_griffin")
    d0 = g.enemy.damage
    AC.onEvoke(g, { type = "lightning" })
    AC.onEvoke(g, { type = "ice" })
    t:eq("Grifo: só Raio fortalece", g.enemy.damage, d0 + AC.spec(g.enemy).value)

    g = fresh("spore_mother")
    d0 = g.enemy.damage
    AC.onExhaust(g)
    t:eq("Mãe-Esporo: Exaurir fortalece", g.enemy.damage, d0 + 1)

    g = fresh("blood_duke")
    g.enemy.health = 300
    AC.onSelfDamage(g, 6)
    t:eq("Duque: vida perdida por conta própria cura ele ×valor", g.enemy.health,
        math.min(g.enemy.maxHealth or 500, 300 + 6 * (AC.spec(g.enemy).value or 1)))

    g = fresh("eclipse_queen")
    g.effectSystem = EffectSystem:new()
    local strike = { id = "s", type = "attack", attack = 10, cost = 1 }
    local st = DamagePreview.liveState(g)
    local v1, steps = DamagePreview.cardValue(g, strike, nil, st)
    t:near("Rainha: 1ª carta vale o % do contra", v1, 10 * AC.spec(g.enemy).value / 100, 1)
    t:eq("Rainha: passo de contra na prévia", steps[#steps].kind == "counter"
        and steps[#steps].counter or (steps[#steps - 1] or {}).counter, "eclipse_first")
    local v2 = DamagePreview.cardValue(g, strike, nil, st)
    t:eq("Rainha: 2ª carta sai cheia", v2, 10)
    g = fresh("generic")
    t:eq("comum: sem eclipse", (DamagePreview.cardValue(g, strike, nil, DamagePreview.liveState(g))), 10)

    g = TK.mockGame({ enemyHp = 500 })
    g.battleTurn = 1
    local echo = { type = "echo_first_attack", value = 2, stacks = 2 }
    t:eq("Eco: turno 1 multiplica por 2", EffectSystem.echoFactor(g, echo), 2)
    g.battleTurn = 5
    t:eq("Eco: turno 5 multiplica por 4", EffectSystem.echoFactor(g, echo), 4)
    local bul = { type = "on_defend_damage", value = 8, stacks = 2 }
    g._defensesPlayedBattle = 1
    t:eq("Baluarte: 1ª defesa arma 8", EffectSystem.defendThornValue(g, bul), 8)
    g._defensesPlayedBattle = 6
    t:eq("Baluarte: 6 defesas na luta armam 11", EffectSystem.defendThornValue(g, bul), 11)
    t:eq("Baluarte: prévia conta a defesa que vai sair", EffectSystem.defendThornValue(g, bul, 1), 11)
    t:eq("Espinhos sem crescer ficam fixos", EffectSystem.defendThornValue(g, { value = 3 }), 3)

    local dead = fresh("rune_golem")
    dead.enemy.health = 0
    t:eq("inimigo morto não aplica contra", AC.magnetArmor(dead, metal), 0)
end

function M.run()
    local t = TK.new("contras #509: chefes e elites contra arquétipos")
    local ok, err = pcall(body, t)
    if not ok then t:check("sem erro: " .. tostring(err), false) end
    return t:done()
end

return M
