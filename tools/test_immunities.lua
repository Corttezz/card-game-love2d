local TK = require("tools.testkit")

local M = {}

local LEVELS = { immune = true, resist = true, weak = true }

local function spawn(id, hp, dmg, act)
    local Enemy = require("src.entities.Enemy")
    local EnemyRoster = require("src.systems.EnemyRoster")
    return EnemyRoster.spawn(Enemy, id, { health = hp or 200, damage = dmg or 6, kind = "battle" },
        act or 1)
end

local function card(db, id)
    return db:createCardInstance(db:getCard(id))
end

local function settle(g)
    TK.pump(g, 2.0)
    local guard = 0
    while (g.combatAnimationSystem:isBlocking() or
        require("src.systems.CombatBeats").isBusy()) and guard < 600 do
        TK.pump(g, 0.1); guard = guard + 1
    end
end

local function checkData(t)
    local Enemies = require("src.data.enemies")
    local R = require("src.systems.Resistances")
    local valid = {}
    for _, ty in ipairs(R.TYPES) do valid[ty] = true end
    local missing, bad = {}, {}
    for act, row in ipairs(Enemies.ROSTER) do
        for kind, ids in pairs(row) do
            for _, id in ipairs(ids) do
                local tb = Enemies.RESIST[id]
                if not tb then missing[#missing + 1] = id end
                for ty, lvl in pairs(tb or {}) do
                    if not valid[ty] or not LEVELS[lvl] then
                        bad[#bad + 1] = id .. ":" .. tostring(ty) .. "=" .. tostring(lvl)
                    end
                    if act <= 2 and kind == "battle" and ty == "poison" and lvl == "immune" then
                        bad[#bad + 1] = id .. ": comum do ato " .. act .. " imune a veneno"
                    end
                end
                if kind == "boss" then
                    t:truthy(id .. ": chefe tem ao menos uma regra", next(tb or {}) ~= nil)
                end
            end
        end
    end
    t:eq("toda criatura do roster tem linha na tabela", table.concat(missing, ","), "")
    t:eq("tipos e niveis validos, nenhum comum dos atos 1-2 imune a veneno",
        table.concat(bad, ","), "")
    local q = Enemies.RESIST.eclipse_queen
    local reduced, weak = 0, 0
    for _, lvl in pairs(q) do
        if lvl == "weak" then weak = weak + 1 else reduced = reduced + 1 end
    end
    t:truthy("rainha: reduz a maioria dos tipos (" .. reduced .. ")", reduced >= 4)
    t:truthy("rainha: duas fraquezas claras (" .. weak .. ")", weak >= 2)
    t:eq("rainha: fisico nao e resistido (guerreiro vence)", q.physical, nil)
    local physResist = 0
    for _, tb in pairs(Enemies.RESIST) do
        if tb.physical == "resist" or tb.physical == "immune" then physResist = physResist + 1 end
    end
    t:truthy("fisico resistido por no maximo 1 criatura (" .. physResist .. ")", physResist <= 1)
end

local function checkMath(t)
    local R = require("src.systems.Resistances")
    t:eq("imune zera", R.scale("immune", 10), 0)
    t:eq("resiste corta a metade", R.scale("resist", 10), 5)
    t:eq("resiste arredonda para baixo", R.scale("resist", 7), 3)
    t:eq("resiste nunca zera um golpe", R.scale("resist", 1), 1)
    t:eq("fraco +50%", R.scale("weak", 10), 15)
    t:eq("fraco arredonda para baixo", R.scale("weak", 7), 10)
    t:eq("sem nivel nao muda", R.scale(nil, 9), 9)
    local fire = { tags = { "fire", "magic" }, type = "attack", attack = 5 }
    local arcane = { tags = { "magic" }, type = "attack", attack = 5 }
    local blade = { tags = { "poison" }, type = "attack", attack = 5 }
    t:eq("carta de fogo causa fogo", R.ofCard(fire), "fire")
    t:eq("so magia = arcano", R.ofCard(arcane), "arcane")
    t:eq("lamina envenenada golpeia fisico", R.ofCard(blade), "physical")
    t:eq("magia sem elemento = arcano", R.ofSpell(blade), "arcane")
    t:eq("magia de gelo = gelo", R.ofSpell({ tags = { "magic", "ice" } }), "ice")

    local lich = spawn("tower_lich")
    local hp = lich.health
    local landed, lvl = lich:takeDamage(20, "ice")
    t:eq("lich imune a gelo: vida intacta", lich.health, hp)
    t:eq("lich imune a gelo: nivel", lvl, "immune")
    t:eq("lich imune a gelo: golpe vira 0", landed, 0)
    lich:takeDamage(10, "fire")
    t:eq("lich fraco a fogo: 10 vira 15", hp - lich.health, 15)

    local rats = spawn("plague_rats")
    rats.armor = 0
    rats:addStatusEffect({ name = "vulnerable", stacks = 1, duration = 2 })
    hp = rats.health
    rats:takeDamage(10, "fire")
    t:eq("fraco antes de Vulneravel: 10 -> 15 -> 22", hp - rats.health, 22)

    local before = rats.health
    rats:takeDamage(8)
    t:eq("sem tipo (cheat/legado) nao aplica resistencia", before - rats.health, 12)

    R.ENABLED = false
    local off = spawn("tower_lich")
    hp = off.health
    off:takeDamage(10, "ice")
    t:eq("knob desligado: sem imunidade", hp - off.health, 10)
    t:eq("knob desligado: HUD sem icones", #R.entries(off), 0)
    R.ENABLED = true
end

local function checkTicks(t)
    local thrall = spawn("grave_thrall", 200, 6, 6)
    thrall:addStatusEffect({ name = "poison", stacks = 5, duration = 5 })
    local hp = thrall.health
    local p, b = thrall:onTurnEnd()
    t:eq("imune a veneno: tique nao tira vida", thrall.health, hp)
    t:eq("imune a veneno: tique reportado 0", p, 0)
    t:eq("imune a veneno: tique cru guardado", thrall.lastDot.poison.raw, 5)
    t:eq("imune a veneno: nivel do tique", thrall.lastDot.poison.level, "immune")
    t:eq("o veneno continua no corpo e decai (fica verde)", thrall:getStatusStacks("poison"), 4)

    local rats = spawn("plague_rats")
    rats:addStatusEffect({ name = "poison", stacks = 6, duration = 6 })
    hp = rats.health
    rats:onTurnEnd()
    t:eq("resiste a veneno: 6 vira 3", hp - rats.health, 3)

    local imp = spawn("ember_imp", 200, 6, 3)
    imp:addStatusEffect({ name = "burn", stacks = 4, duration = 2 })
    hp = imp.health
    imp:onTurnEnd()
    t:eq("imune a fogo: queimadura nao tira vida", imp.health, hp)

    local king = spawn("carrion_king")
    king:addStatusEffect({ name = "burn", stacks = 4, duration = 2 })
    hp = king.health
    king:onTurnEnd()
    t:eq("fraco a fogo: queimadura 4 vira 6", hp - king.health, 6)
end

local function checkCombat(t, db)
    local ResistFx = require("src.ui.ResistFx")
    TK.seedRng(7001)
    local g = TK.newRunGame("mage")
    TK.pump(g, 0.6)
    g.enemy = spawn("ember_imp", 300, 5, 3)
    g.enemy.spriteId = "ember_imp"
    g.player.mana, g.player.maxMana = 99, 99
    local c = card(db, "mage_fireball")
    g.hand = { c }
    g:selectCard(c)
    local hp = g.enemy.health
    local n0 = #ResistFx.log
    g:playSelectedCards()
    settle(g)
    t:eq("Bola de Fogo no diabrete: vida intacta", g.enemy.health, hp)
    local sawImmune = false
    for i = n0 + 1, #ResistFx.log do
        if ResistFx.log[i].level == "immune" and ResistFx.log[i].type == "fire" then sawImmune = true end
    end
    t:truthy("golpe imune solta o retorno IMUNE", sawImmune)

    TK.seedRng(7002)
    local gr = TK.newRunGame("rogue")
    TK.pump(gr, 0.6)
    gr.enemy = spawn("grave_thrall", 300, 4, 6)
    gr.enemy.spriteId = "grave_thrall"
    gr.enemy:addStatusEffect({ name = "poison", stacks = 6, duration = 6 })
    local n1 = #ResistFx.log
    local hp1 = gr.enemy.health
    gr.turn = "enemy"
    gr:enemyTurn()
    settle(gr)
    local dotImmune = false
    for i = n1 + 1, #ResistFx.log do
        local e = ResistFx.log[i]
        if e.level == "immune" and e.dot == "poison" then dotImmune = true end
    end
    t:truthy("tique de veneno no esqueleto mostra IMUNE no lugar do numero", dotImmune)
    t:eq("tique de veneno no esqueleto: vida intacta", gr.enemy.health, hp1)
    t:eq("o esqueleto continua envenenado", gr.enemy:getStatusStacks("poison"), 5)
end

local function checkPreview(t, db)
    local DamagePreview = require("src.systems.DamagePreview")
    local R = require("src.systems.Resistances")
    TK.seedRng(7003)
    local g = TK.newRunGame("mage")
    TK.pump(g, 0.6)
    g.enemy = spawn("ember_imp", 10, 5, 3)
    g.enemy.armor = 0
    g.player.mana = 99
    local c = card(db, "mage_fireball")
    local Rp = DamagePreview.simulate(g, { c })
    local e = Rp.cards[1]
    t:eq("previa: carta imune marcada", e.resist, "immune")
    t:eq("previa: carta imune vale 0", e.value, 0)
    t:eq("previa: dano total 0", Rp.damage, 0)
    t:falsy("previa: golpe imune nao e LETAL", Rp.lethal)
    local hasStep = false
    for _, s in ipairs(e.steps) do if s.kind == "resist" then hasStep = true end end
    t:truthy("previa: passo de resistencia na conta da carta", hasStep)

    g.enemy = spawn("tower_lich", 12, 5, 2)
    g.enemy.armor = 0
    local Rw = DamagePreview.simulate(g, { c })
    t:truthy("previa: fraco a fogo vira LETAL (12 de vida)", Rw.lethal)

    t:eq("dica na mao: Bola de Fogo contra o diabrete",
        (R.cardHint(spawn("ember_imp"), c) or {}).level, "immune")
    t:eq("dica na mao: dardo envenenado contra esqueleto",
        (R.cardHint(spawn("grave_thrall"), card(db, "rogue_poison_dart")) or {}).type, "poison")
    t:eq("dica na mao: golpe comum no espantalho sem dica",
        R.cardHint(spawn("cursed_scarecrow"), card(db, "warrior_strike")), nil)

    local AI = require("tools.balance_ai")
    g.player.orbs = {}
    local bctx = AI.newBattle(g)
    g.enemy = spawn("ember_imp", 50, 5, 3)
    g.enemy.armor = 0
    local S = AI.simulate(g, { c }, bctx, { noEndTurn = true })
    t:eq("piloto le a imunidade pela mesma API", S.eHp, g.enemy.health)
    g.enemy = spawn("tower_lich", 50, 5, 2)
    g.enemy.armor = 0
    S = AI.simulate(g, { c }, bctx, { noEndTurn = true })
    t:truthy("piloto le a fraqueza (" .. tostring(S.eHp) .. ")", S.eHp < g.enemy.health - c.attack)
end

local function checkHud(t)
    local EnemyHud = require("src.ui.EnemyHud")
    local ResistBadges = require("src.ui.ResistBadges")
    TK.seedRng(7004)
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.6)
    g.enemy = spawn("eclipse_queen", 300, 8, 6)
    g.enemy.spriteId = "eclipse_queen"
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    EnemyHud.draw(g, { cx = 640, bottomY = 520, topY = 300, width = 200 })
    love.graphics.setCanvas()
    love.graphics.present()
    t:eq("HUD: um icone por regra da rainha", #ResistBadges.lastRects, 6)
    local L = EnemyHud.layout(g, { cx = 640, bottomY = 520, topY = 300, width = 200 })
    local bar = EnemyHud.hpBarRect(L)
    local first = ResistBadges.lastRects[1]
    local last = ResistBadges.lastRects[#ResistBadges.lastRects]
    t:truthy("HUD: icones a esquerda da barra de vida", last and last.x + last.w <= bar.x)
    t:truthy("HUD: icones dentro do retangulo do HUD", first and first.x >= L.rect.x - 0.5)
    t:eq("HUD: imunes primeiro", first and first.entry.level, "immune")
    canvas:release()

    local pills = EnemyHud.collectPills((function()
        local e = spawn("grave_thrall")
        e:addStatusEffect({ name = "poison", stacks = 3, duration = 3 })
        return e
    end)())
    local variant
    for _, p in ipairs(pills) do if p.name == "poison" then variant = p.variant end end
    t:eq("pilula de veneno ganha variante imune", variant, "immune")
end

local function checkLocales(t)
    local I18n = require("src.i18n.I18n")
    local R = require("src.systems.Resistances")
    local problems = {}
    local function need(loc, key, v)
        if type(v) ~= "string" or v == "" then
            problems[#problems + 1] = loc .. ":" .. key
        elseif v:find("—") or v:find("–") or v:find(" %- ") then
            problems[#problems + 1] = loc .. ":" .. key .. " (travessao)"
        end
    end
    for _, loc in ipairs(I18n.available) do
        local tb = require("src.i18n.locales." .. loc)
        local rs = tb.resist or {}
        for _, ty in ipairs(R.TYPES) do need(loc, "resist.type." .. ty, (rs.type or {})[ty]) end
        for lvl in pairs(LEVELS) do
            need(loc, "resist.title." .. lvl, (rs.title or {})[lvl])
            need(loc, "resist.desc." .. lvl, (rs.desc or {})[lvl])
            need(loc, "resist.float." .. lvl, (rs.float or {})[lvl])
            for _, st in ipairs({ "poison", "burn" }) do
                need(loc, "status." .. st .. ".desc_" .. lvl,
                    ((tb.status or {})[st] or {})["desc_" .. lvl])
            end
            for _, ty in ipairs({ "poison", "fire" }) do
                need(loc, "resist.status_note." .. ty .. "_" .. lvl,
                    (rs.status_note or {})[ty .. "_" .. lvl])
            end
        end
    end
    t:eq("textos de resistencia nos 5 idiomas, sem travessao", table.concat(problems, ","), "")
    local title, body = require("src.ui.ResistBadges").tooltip({ type = "poison", level = "immune" })
    t:truthy("tooltip monta titulo com o tipo (" .. title .. ")", title:find("{") == nil and #title > 3)
    t:truthy("tooltip monta corpo (" .. body .. ")", body:find("{") == nil and #body > 10)
end

function M.run()
    local t = TK.new("imunidades e resistencias por criatura")
    TK.bootstrap()
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    checkData(t)
    checkMath(t)
    checkTicks(t)
    checkCombat(t, db)
    checkPreview(t, db)
    checkHud(t)
    checkLocales(t)
    return t:done()
end

return M
