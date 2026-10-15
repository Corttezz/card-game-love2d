local TK = require("tools.testkit")
local Enemy = require("src.entities.Enemy")
local EnemyRoster = require("src.systems.EnemyRoster")
local BM = require("src.systems.BossMechanics")
local BossTokens = require("src.ui.BossTokens")
local CombatBeats = require("src.systems.CombatBeats")

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

local function battleWith(id, hp, dmg)
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.3)
    g.enemy = EnemyRoster.spawn(Enemy, id, { health = hp or 400, damage = dmg or 20 })
    g.enemy.isBoss = true
    g.enemy.spriteId = id
    g._deathHandled, g._deathStaged = false, false
    g.player.health = g.player.maxHealth
    g.player.armor = 0
    g.battleTurn = 1
    return g
end

local function runEnemyTurn(g, secs)
    g.turn = "enemy"
    g._enemyActing = false
    g:enemyTurn()
    TK.pump(g, secs or 8)
end

local function ownIcon(t, label, iconName)
    local StatusPill = require("src.ui.StatusPill")
    local path = "assets/sprites/icons/" .. tostring(iconName) .. ".png"
    t:truthy(label .. ": ícone existe (" .. tostring(iconName) .. ")", love.filesystem.getInfo(path))
    local cardIcons = {}
    for _, art in pairs(require("src.data.card_art")) do
        if type(art) == "table" and art.icon then cardIcons[art.icon] = true end
    end
    t:falsy(label .. ": ícone não é nome de arte de carta", cardIcons[iconName])
    local bytes = love.filesystem.read(path)
    local same = nil
    for name in pairs(cardIcons) do
        local p = "assets/sprites/icons/" .. name .. ".png"
        if love.filesystem.getInfo(p) and love.filesystem.read(p) == bytes then same = name end
    end
    t:falsy(label .. ": ícone não copia bytes de carta", same)
    local okImg, img = pcall(love.graphics.newImage, path)
    t:truthy(label .. ": ícone 64x64", okImg and img:getWidth() == 64 and img:getHeight() == 64)
    return StatusPill
end

local function localesHave(t, label, keys)
    local I18n = require("src.i18n.I18n")
    local saved = I18n.getLocale and I18n.getLocale()
    for _, loc in ipairs(LOCALES) do
        I18n.setLocale(loc)
        for _, k in ipairs(keys) do
            local v = I18n.t(k, { stacks = 2, value = 9, max = 4, dealt = 3, hits = 2 }, "")
            t:truthy(label .. " [" .. loc .. "] " .. k, v ~= "" and not v:find("—", 1, true))
        end
    end
    if saved then I18n.setLocale(saved) end
end

local function settleTokens(id, enemy, secs)
    BossTokens.sync(id, enemy)
    for _ = 1, math.floor((secs or 2) * 30) do
        BossTokens.sync(id, enemy)
        BossTokens.update(1 / 30, id, false)
    end
end

local function testLich(t)
    local ID = "tower_lich"
    local g = battleWith(ID, 400, 20)
    local e = g.enemy
    local m = BM.spec(e)
    t:eq("lich: mecânica runas", m and m.kind, "runes")
    t:eq("lich: nasce com 1 runa", BM.stacks(e, "runes"), 1)
    t:eq("lich: limiar = 15% da vida (60)", BM.runeThreshold(e), 60)

    for _ = 1, 3 do
        for _, step in ipairs(BM.turnEndSteps(e)) do BM.applyStep(e, step) end
    end
    t:eq("lich: +1 runa por turno até 4", BM.stacks(e, "runes"), 4)
    t:falsy("lich: teto 4", BM.applyStep(e, BM.turnEndSteps(e)[1]))
    e:rollIntent(g.player)
    local it = e:getIntent()
    t:eq("lich: 4 runas = Cataclismo anunciado", it.id, "rune_cataclysm")
    t:eq("lich: 1 golpe por runa", it.hits, 4)
    t:eq("lich: 0,5 x dano por golpe", it.perHit, 10)

    e:takeDamage(59)
    t:falsy("lich: 59 de dano não quebra", BM.hasPending(e))
    e:takeDamage(1)
    t:truthy("lich: 60 no turno quebra uma runa", BM.hasPending(e))
    local res = BM.applyEvent(e, BM.popEvent(e))
    t:eq("lich: runa quebrada", res and res.kind, "rune_break")
    t:eq("lich: sobram 3", BM.stacks(e, "runes"), 3)
    t:eq("lich: Cataclismo anunciado perde um golpe", e:getIntent().hits, 3)
    t:eq("lich: número do golpe não muda", e:getIntent().perHit, 10)
    e:takeDamage(130)
    local n = 0
    while BM.hasPending(e) do
        local r = BM.applyEvent(e, BM.popEvent(e))
        n = n + (r and r.n or 0)
    end
    t:eq("lich: 190 acumulados no turno = 3 quebras (mais 2)", n, 2)
    t:eq("lich: sobra 1 runa", BM.stacks(e, "runes"), 1)
    e:_applyDot(200)
    t:falsy("lich: veneno não quebra runa", BM.hasPending(e))
    BM.onPlayerTurnStart(g)
    t:eq("lich: contagem zera no turno novo", e._mech.turnDmg, 0)

    local g2 = battleWith(ID, 400, 20)
    local e2 = g2.enemy
    BM.setStacks(e2, "runes", 4)
    e2:rollIntent(g2.player)
    t:eq("lich (luta): Cataclismo anunciado", e2:getIntent().id, "rune_cataclysm")
    local hp0 = g2.player.health
    g2.player.armor = 0
    CombatBeats.startTrace()
    runEnemyTurn(g2, 10)
    local lost = hp0 - g2.player.health
    t:eq("lich (luta): 4 golpes de 10", lost, 40)
    t:eq("lich (luta): golpes consomem as runas e o turno acende 1", BM.stacks(e2, "runes"), 1)
    local trace = CombatBeats.traceString()
    CombatBeats.stopTrace()
    t:truthy("lich (luta): beat de runa acesa no fim do turno", trace:find("boss.rune_gain", 1, true))
    t:falsy("lich (luta): runas cheias de novo não repetem logo o Cataclismo",
        e2:getIntent().id == "rune_cataclysm")

    local g3 = battleWith(ID, 400, 20)
    t:eq("Continuar: luta nova nasce com 1 runa", BM.stacks(g3.enemy, "runes"), 1)

    local savedGS = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    BossTokens.reset()
    local fake = { getStatusStacks = function(_, nm) return nm == "runes" and 2 or 0 end }
    settleTokens(ID, fake, 0.1)
    t:eq("lich visual: 1ª leitura já em órbita", BossTokens.phases(ID).idle, 2)
    fake.getStatusStacks = function(_, nm) return nm == "runes" and 4 or 0 end
    BossTokens.sync(ID, fake)
    BossTokens.update(1 / 30, ID, false)
    t:eq("lich visual: runa nova entra animada", BossTokens.phases(ID).enter, 2)
    settleTokens(ID, fake, 2)
    t:eq("lich visual: 4 runas = 4 pedras", BossTokens.count(ID), 4)
    fake.getStatusStacks = function(_, nm) return nm == "runes" and 3 or 0 end
    BossTokens.sync(ID, fake)
    BossTokens.update(1 / 30, ID, false)
    t:eq("lich visual: runa quebrada estilhaça", BossTokens.phases(ID).leave, 1)
    settleTokens(ID, fake, 1)
    t:eq("lich visual: sobram 3", BossTokens.count(ID), 3)
    local st = BossTokens._debug(ID)
    st.iw, st.ih, st.tgtX, st.tgtY = 137, 131, -200, 300
    t:truthy("lich visual: Cataclismo manda runa", BossTokens.strike(ID, "rune", 0.34, 0.42))
    t:eq("lich visual: runa voando", BossTokens.phases(ID).strike, 1)
    for _ = 1, 6 do BossTokens.update(1 / 30, ID, false) end
    fake.getStatusStacks = function(_, nm) return nm == "runes" and 2 or 0 end
    settleTokens(ID, fake, 1)
    t:eq("lich visual: golpe consome a runa que voou (sem estilhaçar outra)", BossTokens.count(ID), 2)
    t:falsy("lich visual: nada sobrando em saída", BossTokens.phases(ID).leave)
    _G.gameSettings = { reducedMotion = true }
    BossTokens.reset()
    fake.getStatusStacks = function(_, nm) return nm == "runes" and 3 or 0 end
    settleTokens(ID, fake, 0.1)
    t:eq("lich reducedMotion: runas paradas no lugar", BossTokens.phases(ID).idle, 3)
    t:falsy("lich reducedMotion: sem projétil", BossTokens.strike(ID, "rune", 0.34, 0.42))
    _G.gameSettings = savedGS
    BossTokens.reset()

    local SP = ownIcon(t, "lich", require("src.ui.StatusPill").ICONS.runes)
    t:eq("lich: pill usa status_runes", SP.ICONS.runes, "status_runes")
    local spec = BossTokens.spec(ID)
    for i, p in ipairs(spec.sprites) do
        local img = BossTokens.image(p)
        t:truthy("lich: runa " .. i .. " é sprite <= 32px", img and img:getWidth() <= 32)
    end
    t:eq("lich: escala do token inteira", BossTokens.tokenScale(2.3) % 1, 0)
    for _, snd in pairs(spec.sounds) do
        t:truthy("lich: som " .. snd.code .. " baixo (<= 0.36)", snd.volume <= 0.36)
    end
    localesHave(t, "lich", { "enemy_kit.moves.rune_cataclysm.name", "enemy_kit.intent.runes",
        "enemy_kit.status.runes.name", "enemy_kit.status.runes.desc",
        "enemy_kit.msg.rune_gain", "enemy_kit.msg.rune_break" })
end

function M.run()
    local t = TK.new("chefes: mecânica-assinatura, contador, visual, golpe")
    TK.bootstrap()
    TK.seedRng(9090)
    testLich(t)
    return t:done()
end

return M
