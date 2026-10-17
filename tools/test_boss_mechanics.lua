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
    t:eq("lich: nasce sem runa", BM.stacks(e, "runes"), 0)
    t:eq("lich: limiar = 12% da vida (48)", BM.runeThreshold(e), 48)

    for _ = 1, 4 do
        for _, step in ipairs(BM.turnEndSteps(e)) do BM.applyStep(e, step) end
    end
    t:eq("lich: +1 runa por turno até 4", BM.stacks(e, "runes"), 4)
    t:falsy("lich: teto 4", BM.applyStep(e, BM.turnEndSteps(e)[1]))
    e:rollIntent(g.player)
    local it = e:getIntent()
    t:eq("lich: 4 runas = Cataclismo anunciado", it.id, "rune_cataclysm")
    t:eq("lich: 1 golpe por runa", it.hits, 4)
    t:eq("lich: 0,45 x dano por golpe", it.perHit, 9)

    e:takeDamage(47)
    t:falsy("lich: 47 de dano não quebra", BM.hasPending(e))
    e:takeDamage(1)
    t:truthy("lich: 48 no turno quebra uma runa", BM.hasPending(e))
    local res = BM.applyEvent(e, BM.popEvent(e))
    t:eq("lich: runa quebrada", res and res.kind, "rune_break")
    t:eq("lich: sobram 3", BM.stacks(e, "runes"), 3)
    t:eq("lich: Cataclismo anunciado perde um golpe", e:getIntent().hits, 3)
    t:eq("lich: número do golpe não muda", e:getIntent().perHit, 9)
    e:takeDamage(130)
    local n = 0
    while BM.hasPending(e) do
        local r = BM.applyEvent(e, BM.popEvent(e))
        n = n + (r and r.n or 0)
    end
    t:eq("lich: 178 acumulados no turno = 3 quebras (mais 2)", n, 2)
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
    t:eq("lich (luta): 4 golpes de 9", lost, 36)
    t:eq("lich (luta): golpes consomem as runas e o turno acende 1", BM.stacks(e2, "runes"), 1)
    local trace = CombatBeats.traceString()
    CombatBeats.stopTrace()
    t:truthy("lich (luta): beat de runa acesa no fim do turno", trace:find("boss.rune_gain", 1, true))
    t:falsy("lich (luta): runas cheias de novo não repetem logo o Cataclismo",
        e2:getIntent().id == "rune_cataclysm")

    local g3 = battleWith(ID, 400, 20)
    t:eq("Continuar: luta nova nasce sem runa", BM.stacks(g3.enemy, "runes"), 0)

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

local function testTyrant(t)
    local ID = "abyss_tyrant"
    local g = battleWith(ID, 400, 20)
    local e = g.enemy
    t:eq("tirano: mecânica correntes", BM.spec(e).kind, "chains")
    t:eq("tirano: 3 correntes", BM.stacks(e, "chains"), 3)
    local marks = BM.hpMarks(e)
    t:eq("tirano: 3 marcas na barra", #marks, 3)
    t:eq("tirano: 1ª marca em 75%", marks[1], 0.75)
    e:forceIntent("hellfire", g.player)
    local before = e:getIntent().perHit
    t:eq("tirano: Fogo Infernal 1,7x", before, 34)
    e:takeDamage(99)
    t:falsy("tirano: acima de 75% nada rompe", BM.hasPending(e))
    e:takeDamage(2)
    t:truthy("tirano: cruzar 75% rompe", BM.hasPending(e))
    local res = BM.applyEvent(e, BM.popEvent(e))
    t:eq("tirano: corrente rompida", res and res.kind, "chain_break")
    t:eq("tirano: sobram 2", BM.stacks(e, "chains"), 2)
    t:eq("tirano: golpe anunciado pela metade", e:getIntent().perHit, 17)
    t:truthy("tirano: intent marcado como cambaleio", e:getIntent().staggered)
    t:eq("tirano: +8% do dano base como Força (mínimo 1)", res.strength, 1)
    t:eq("tirano: Força entra no dano", e.damage, 21)
    t:eq("tirano: marcas restantes", #BM.hpMarks(e), 2)
    e:takeDamage(100)
    BM.applyEvent(e, BM.popEvent(e))
    t:eq("tirano: 2ª corrente no mesmo turno", BM.stacks(e, "chains"), 1)
    t:eq("tirano: cambaleia só uma vez por turno", e:getIntent().perHit, 17)
    BM.onPlayerTurnStart(g)
    e:_applyDot(120)
    t:truthy("tirano: queimadura também rompe", BM.hasPending(e))
    BM.applyEvent(e, BM.popEvent(e))
    t:eq("tirano: sem correntes", BM.stacks(e, "chains"), 0)
    t:eq("tirano: sem marcas", #BM.hpMarks(e), 0)

    local g2 = battleWith(ID, 400, 20)
    local e2 = g2.enemy
    e2:forceIntent("abyssal_claws", g2.player)
    local per = e2:getIntent().perHit
    e2:takeDamage(101)
    g2:settleEnemyDamage(nil)
    TK.pump(g2, 1.0)
    t:eq("tirano (luta): beat aplica a ruptura", BM.stacks(e2, "chains"), 2)
    local hp0 = g2.player.health
    g2.player.armor = 0
    runEnemyTurn(g2, 8)
    t:eq("tirano (luta): golpe sai pela metade", hp0 - g2.player.health, math.floor(per / 2))
    local g3 = battleWith(ID, 400, 20)
    t:eq("Continuar: tirano nasce com 3 correntes", BM.stacks(g3.enemy, "chains"), 3)

    local savedGS = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    BossTokens.reset()
    local n = 3
    local fake = { getStatusStacks = function(_, nm) return nm == "chains" and n or 0 end }
    settleTokens(ID, fake, 0.1)
    local st = BossTokens._debug(ID)
    st.iw, st.ih, st.groundArt, st.tgtX, st.tgtY = 123, 126, 126, -200, 300
    t:eq("tirano visual: 3 correntes inteiras", BossTokens.chainState(ID).intact, 3)
    n = 2
    settleTokens(ID, fake, 0.1)
    t:eq("tirano visual: uma estala", BossTokens.chainState(ID).breaking, 1)
    t:eq("tirano visual: sobram 2", BossTokens.chainState(ID).intact, 2)
    settleTokens(ID, fake, 1.2)
    t:eq("tirano visual: a rompida cai e some", BossTokens.chainState(ID).breaking, 0)
    t:truthy("tirano visual: Fogo Infernal lança bola de fogo", BossTokens.strike(ID, "fireball", 0.34, 0.42))
    t:eq("tirano visual: projétil no ar", #st.bolts, 1)
    for _ = 1, 30 do BossTokens.update(1 / 30, ID, false) end
    t:eq("tirano visual: projétil some depois do recuo", #st.bolts, 0)
    _G.gameSettings = { reducedMotion = true }
    BossTokens.reset()
    n = 1
    settleTokens(ID, fake, 0.1)
    t:eq("tirano reducedMotion: correntes no lugar", BossTokens.chainState(ID).intact, 1)
    t:falsy("tirano reducedMotion: sem projétil", BossTokens.strike(ID, "fireball", 0.34, 0.42))
    _G.gameSettings = savedGS
    BossTokens.reset()

    local SP = ownIcon(t, "tirano", require("src.ui.StatusPill").ICONS.chains)
    t:eq("tirano: pill usa status_chains", SP.ICONS.chains, "status_chains")
    local spec = BossTokens.spec(ID)
    t:truthy("tirano: elo da corrente é sprite", BossTokens.image(spec.link))
    t:truthy("tirano: bola de fogo é sprite", BossTokens.image(spec.strikes.fireball.sprite))
    t:truthy("tirano: estalo baixo (<= 0.45)", spec.sounds.lose.volume <= 0.45)
    t:truthy("tirano: impacto baixo (<= 0.30)", spec.strikes.fireball.sound.volume <= 0.30)
    localesHave(t, "tirano", { "enemy_kit.intent.staggered", "enemy_kit.status.chains.name",
        "enemy_kit.status.chains.desc", "enemy_kit.msg.chain_break", "enemy_kit.msg.staggered" })
end

local function luaFiles(dir, out)
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = dir .. "/" .. f
        local info = love.filesystem.getInfo(path)
        if info and info.type == "directory" then
            luaFiles(path, out)
        elseif f:match("%.lua$") then
            out[#out + 1] = path
        end
    end
    return out
end

local function testTyrantChains(t)
    local ID = "abyss_tyrant"
    local SB = require("src.ui.SceneBackground")
    local spec = BossTokens.spec(ID)
    t:eq("correntes: 3 correntes no dado da mecânica", #spec.chains, 3)
    local hw, hh = SB.getSize("castle_hall_" .. spec.hall)
    t:truthy("correntes: salão do tirano existe", hw ~= nil)
    for _, clip in ipairs({ "idle", "stride", "hurt", "roar", "attack", "attack_strong", "death" }) do
        local dir = "assets/sprites/characters/enemies/" .. ID .. "/animations/" .. clip .. "/south"
        local n = 0
        for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
            if f:match("%.png$") then n = n + 1 end
        end
        local frames = spec.grips[clip]
        t:eq("correntes: pegada medida em todo quadro de " .. clip, frames and #frames or 0, n)
        local bad = 0
        for i = 1, n do
            local data = love.image.newImageData(dir .. "/" .. (i - 1) .. ".png")
            for _, ch in ipairs(spec.chains) do
                local gx, gy = BossTokens.gripPoint(spec, ch, clip, i)
                local px, py = math.floor(gx), math.floor(gy)
                local inside = px >= 0 and py >= 0 and px < data:getWidth() and py < data:getHeight()
                local _, _, _, a = 0, 0, 0, 0
                if inside then _, _, _, a = data:getPixel(px, py) end
                if not inside or a <= 0 then bad = bad + 1 end
            end
        end
        t:eq("correntes: toda pegada cai no CORPO (pixel opaco) em " .. clip, bad, 0)
    end
    local savedGS = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    for _, res in ipairs({ { 1600, 900 }, { 1920, 1080 }, { 1280, 720 }, { 1024, 768 } }) do
        local W, H = res[1], res[2]
        local tag = W .. "x" .. H
        local tr = SB.getCoverTransform("castle_hall_" .. spec.hall, W, H)
        local vx0, vx1 = math.max(0, -tr.ox / tr.scale), math.min(hw, (W - tr.ox) / tr.scale)
        local vy0, vy1 = math.max(0, -tr.oy / tr.scale), math.min(hh, (H - tr.oy) / tr.scale)
        for _, ch in ipairs(spec.chains) do
            local ax, ay = ch.from[1], ch.from[2]
            t:truthy(("correntes %s: âncora de %s visível na arte do salão"):format(tag, ch.grip),
                ax >= vx0 + 4 and ax <= vx1 - 4 and ay >= vy0 + 4 and ay <= vy1 - 4)
        end
        local sc = 330 / 121
        local gy = H * 0.78
        local r = { x = W / 2 - 123 * sc / 2, y = gy - 124 * sc, scale = sc, iw = 123, ih = 126,
                    groundY = gy, clip = "idle", frame = 1, hallTr = tr }
        local canvas = love.graphics.newCanvas(W, H)
        local n = 3
        local fake = { health = 100, getStatusStacks = function(_, nm) return nm == "chains" and n or 0 end }
        BossTokens.reset()
        for _, want in ipairs({ 3, 2, 1, 0 }) do
            n = want
            settleTokens(ID, fake, 1.2)
            love.graphics.setCanvas(canvas)
            BossTokens.drawBack(ID, r)
            BossTokens.drawFront(ID, r)
            love.graphics.setCanvas()
            t:eq(("correntes %s: %d na mecânica = %d desenhadas"):format(tag, want, want),
                BossTokens.drawnChains(ID), want)
            t:eq(("correntes %s: %d inteiras"):format(tag, want), BossTokens.chainState(ID).intact, want)
        end
        n = 3
        BossTokens.reset()
        settleTokens(ID, fake, 0.1)
        local nohall = {}
        for k, v in pairs(r) do nohall[k] = v end
        nohall.hallTr = nil
        love.graphics.setCanvas(canvas)
        BossTokens.drawBack(ID, nohall)
        BossTokens.drawFront(ID, nohall)
        love.graphics.setCanvas()
        t:eq("correntes " .. tag .. ": sem salão não inventa âncora", BossTokens.drawnChains(ID), 0)
        canvas:release()
    end
    BossTokens.reset()
    _G.gameSettings = savedGS
    local owners = {}
    for _, f in ipairs(luaFiles("src", {})) do
        local src = love.filesystem.read(f) or ""
        if src:find("chain_link", 1, true) or src:find("drawChainLinks", 1, true)
            or src:find("chainAnchors", 1, true) or src:find("CHAIN_DARK", 1, true) then
            owners[#owners + 1] = f
        end
    end
    t:eq("correntes: um módulo só conhece o elo (" .. table.concat(owners, ", ") .. ")", #owners, 1)
    t:eq("correntes: o dono é o dado da mecânica", owners[1], "src/data/boss_tokens.lua")
    local cine = love.filesystem.read("src/ui/BossCinematic.lua") or ""
    t:falsy("correntes: cinemática não desenha elo próprio", cine:find("love.graphics.rectangle(\"fill\", bx, by, 2 * P, 3 * P)", 1, true) ~= nil)
    t:truthy("correntes: cinemática delega ao BossTokens", cine:find("drawChainsAt", 1, true) ~= nil)
    t:falsy("correntes: cinemática não rompe por vida", cine:find("chainShouldBreak", 1, true) ~= nil)
end

local function testMonarch(t)
    local ID = "winter_monarch"
    local g = battleWith(ID, 400, 20)
    local e = g.enemy
    t:eq("monarca: mecânica geada", BM.spec(e).kind, "frost")
    e:forceIntent("royal_blizzard", g.player)
    t:eq("monarca: Nevasca Real anuncia +2 Geada", e:getIntent().frost, 2)
    e:forceIntent("winter_blade", g.player)
    t:eq("monarca: Lâmina do Inverno +1", e:getIntent().frost, 1)
    e.intentVisibility = "type_only"
    t:eq("monarca: névoa esconde o número mas não a Geada", e:getKnownIntent(g.player).frost, 1)
    e.intentVisibility = "full"

    g.player.frost = 0
    e:forceIntent("royal_blizzard", g.player)
    g.player.armor = 99
    runEnemyTurn(g, 8)
    t:eq("monarca (luta): Geada no jogador", g.player.frost, 2)
    local frozen = 0
    for _, c in ipairs(g.hand) do if c.frozen then frozen = frozen + 1 end end
    t:eq("monarca (luta): abaixo de 4 nada congela", frozen, 0)

    g:endTurn()
    TK.pump(g, 1)
    g.player.frost = 3
    e:forceIntent("royal_blizzard", g.player)
    g.player.armor = 99
    runEnemyTurn(g, 8)
    frozen = 0
    local maxCostFrozen, maxCostFree = -1, -1
    for _, c in ipairs(g.hand) do
        if c.frozen then
            frozen = frozen + 1
            maxCostFrozen = math.max(maxCostFrozen, c.cost or 0)
        else
            maxCostFree = math.max(maxCostFree, c.cost or 0)
        end
    end
    t:eq("monarca (luta): 5 de Geada congela 2 cartas na compra", frozen, math.min(2, #g.hand))
    t:truthy("monarca (luta): congela as mais caras", maxCostFrozen >= maxCostFree)
    t:eq("monarca (luta): Geada perde 4", g.player.frost, 1)
    local fc = nil
    for _, c in ipairs(g.hand) do if c.frozen then fc = c break end end
    if fc then
        t:falsy("monarca: carta congelada não pode ser jogada", g:canPlayCard(fc))
        local mana = g.player.mana
        g:selectCard(fc)
        t:falsy("monarca: selecionar congelada não seleciona", g:isCardSelected(fc))
        t:eq("monarca: e não gasta mana", g.player.mana, mana)
        local AI = require("tools.balance_ai")
        local bctx = AI.newBattle(g)
        local set = AI.bestSet(g, bctx)
        local uses = false
        for _, c in ipairs(set) do if c.frozen then uses = true end end
        t:falsy("monarca: piloto nunca escolhe carta congelada", uses)
    end
    g:endTurn()
    local still = 0
    for _, c in ipairs(g.hand) do if c.frozen then still = still + 1 end end
    t:eq("monarca: gelo derrete no fim do turno", still, 0)

    g.player.frost = 3
    local res = BM.onPlayerAttack(g, { type = "attack", tags = {} })
    t:eq("monarca: ataque derrete 1", g.player.frost, 2)
    BM.onPlayerAttack(g, { type = "attack", tags = { "fire" } })
    t:eq("monarca: fogo derrete 2", g.player.frost, 0)
    t:eq("monarca: evento de derretimento", res and res.kind, "frost_melt")
    g.player.frost = 3
    g:applyClassBattleStartPassive()
    t:eq("Continuar/luta nova: Geada zera", g.player.frost, 0)
    local g2 = battleWith("tower_lich", 400, 20)
    g2.player.frost = 9
    t:falsy("monarca: fora do Monarca a Geada não congela", BM.onPlayerDraw(g2))

    local picks = BM.freezePicks({ { cost = 1 }, { cost = 3 }, { cost = 2 }, { cost = 3 } }, 2)
    t:truthy("monarca: empate de custo congela a mais à esquerda",
        picks[1].cost == 3 and picks[2].cost == 3)

    local savedGS = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    local BT = BossTokens
    BT.reset()
    local fakeGame = { enemy = e, player = { frost = 4 } }
    BT.drawScreen(fakeGame)
    t:truthy("monarca visual: gelo nas bordas cresce com a Geada", BT.screenLevel() > 0)
    _G.gameSettings = { reducedMotion = true }
    BT.drawScreen(fakeGame)
    t:eq("monarca reducedMotion: gelo já no tamanho (informação fica)", BT.screenLevel(), 1)
    fakeGame.player.frost = 0
    BT.drawScreen(fakeGame)
    t:eq("monarca visual: sem Geada, sem gelo", BT.screenLevel(), 0)
    _G.gameSettings = { reducedMotion = false }
    local fake = { getStatusStacks = function() return 0 end }
    settleTokens(ID, fake, 0.1)
    local st = BT._debug(ID)
    st.iw, st.ih, st.tgtX, st.tgtY = 122, 129, -200, 300
    t:truthy("monarca visual: Nevasca dispara estilhaço", BT.strike(ID, "shard", 0.34, 0.42))
    _G.gameSettings = { reducedMotion = true }
    t:falsy("monarca reducedMotion: sem estilhaço", BT.strike(ID, "shard", 0.34, 0.42))
    _G.gameSettings = savedGS
    BT.reset()

    local SP = ownIcon(t, "monarca", require("src.ui.StatusPill").ICONS.frost)
    t:eq("monarca: pill usa status_frost", SP.ICONS.frost, "status_frost")
    local spec = BT.spec(ID)
    t:truthy("monarca: canto de gelo é sprite", BT.image(spec.corner))
    t:truthy("monarca: bloco de gelo da carta é sprite", BT.image(spec.iceBlock))
    t:truthy("monarca: estilhaço é sprite", BT.image(spec.strikes.shard.sprite))
    for _, snd in pairs(spec.sounds) do
        t:truthy("monarca: som " .. snd.code .. " sem estourar (<= 1)", snd.volume <= 1)
    end
    local pills = require("src.ui.PlayerBuffPills").collect({ frost = 3, debuffs = {}, buffs = {} },
        { enemy = e })
    local has = false
    for _, pl in ipairs(pills) do if pl.name == "frost" and pl.stacks == 3 and pl.value == 4 then has = true end end
    t:truthy("monarca: pill de Geada no jogador com o limiar", has)
    localesHave(t, "monarca", { "enemy_kit.intent.frost", "enemy_kit.status.frost.name",
        "enemy_kit.status.frost.desc", "enemy_kit.msg.frost_gain", "enemy_kit.msg.freeze",
        "enemy_kit.msg.frost_melt", "enemy_kit.msg.card_frozen" })
end

local function testColossus(t)
    local ID = "rot_colossus"
    local g = battleWith(ID, 1000, 20)
    local e = g.enemy
    t:eq("colosso: mecânica raízes", BM.spec(e).kind, "roots")
    t:eq("colosso: nasce com 2 raízes", BM.stacks(e, "roots"), 2)
    t:falsy("colosso: sem a regeneração fixa antiga", e:hasStatus("regen"))
    t:eq("colosso: 0,65% por raiz", BM.rootRegen(e), 6)
    t:eq("colosso: corte com 4% num golpe", BM.rootCutThreshold(e), 40)
    e.health = 600
    t:eq("colosso: cura 2 raízes", e:tickRegen(), 12)
    for _ = 1, 4 do BM.applyStep(e, BM.turnEndSteps(e)[1]) end
    t:eq("colosso: +1 raiz a cada 2 turnos", BM.stacks(e, "roots"), 3)
    for _ = 1, 4 do BM.applyStep(e, BM.turnEndSteps(e)[1]) end
    t:eq("colosso: teto 3", BM.stacks(e, "roots"), 3)
    e:takeDamage(39)
    t:falsy("colosso: 39 não corta", BM.hasPending(e))
    e:takeDamage(30)
    e:takeDamage(30)
    t:falsy("colosso: dano miúdo somado não corta", BM.hasPending(e))
    e:takeDamage(40)
    t:truthy("colosso: um golpe de 40 corta", BM.hasPending(e))
    local res = BM.applyEvent(e, BM.popEvent(e))
    t:eq("colosso: raiz cortada", res and res.kind, "root_cut")
    t:eq("colosso: sobram 2", BM.stacks(e, "roots"), 2)
    e:_applyDot(80)
    t:falsy("colosso: veneno não corta", BM.hasPending(e))
    e.armor = 30
    e:takeDamage(65)
    t:falsy("colosso: Bloqueio que segura o golpe não deixa cortar", BM.hasPending(e))
    BM.setStacks(e, "roots", 0)
    e.health = 600
    t:eq("colosso: sem raízes não regenera", e:tickRegen(), 0)

    local g2 = battleWith(ID, 1000, 20)
    g2.enemy.health = 500
    g2.player.armor = 99
    CombatBeats.startTrace()
    runEnemyTurn(g2, 8)
    local trace = CombatBeats.traceString()
    CombatBeats.stopTrace()
    t:eq("colosso (luta): regenera 12 no fim do turno", g2.enemy.health, 512)
    t:truthy("colosso (luta): beat de regeneração", trace:find("enemy.regen", 1, true))
    runEnemyTurn(g2, 8)
    t:eq("colosso (luta): 2º turno brota a 3ª raiz", BM.stacks(g2.enemy, "roots"), 3)
    local g3 = battleWith(ID, 1000, 20)
    t:eq("Continuar: colosso nasce com 2 raízes", BM.stacks(g3.enemy, "roots"), 2)

    local savedGS = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    BossTokens.reset()
    local n = 2
    local fake = { getStatusStacks = function(_, nm) return nm == "roots" and n or 0 end }
    settleTokens(ID, fake, 0.1)
    t:eq("colosso visual: 1ª leitura já no chão", BossTokens.phases(ID).idle, 2)
    n = 3
    settleTokens(ID, fake, 0.1)
    t:eq("colosso visual: raiz nova brota", BossTokens.phases(ID).enter, 1)
    settleTokens(ID, fake, 1)
    t:eq("colosso visual: 3 raízes", BossTokens.count(ID), 3)
    local slots = {}
    for _, c in ipairs(BossTokens._debug(ID).tokens) do slots[c.slot] = (slots[c.slot] or 0) + 1 end
    t:truthy("colosso visual: cada raiz no seu lugar", (slots[1] or 0) <= 1 and (slots[2] or 0) <= 1
        and (slots[3] or 0) <= 1)
    n = 2
    settleTokens(ID, fake, 0.1)
    t:eq("colosso visual: raiz cortada murcha", BossTokens.phases(ID).leave, 1)
    settleTokens(ID, fake, 1)
    t:eq("colosso visual: sobram 2", BossTokens.count(ID), 2)
    local st = BossTokens._debug(ID)
    st.iw, st.ih, st.groundArt, st.tgtX, st.tgtY = 141, 131, 125, -200, 300
    t:truthy("colosso visual: Pancada faz raiz brotar sob o herói", BossTokens.strike(ID, "root", 0.34, 0.42))
    _G.gameSettings = { reducedMotion = true }
    t:falsy("colosso reducedMotion: sem raiz no golpe", BossTokens.strike(ID, "root", 0.34, 0.42))
    _G.gameSettings = savedGS
    BossTokens.reset()

    local SP = ownIcon(t, "colosso", require("src.ui.StatusPill").ICONS.roots)
    t:eq("colosso: pill usa status_roots", SP.ICONS.roots, "status_roots")
    local spec = BossTokens.spec(ID)
    for i, p in ipairs(spec.sprites) do
        t:truthy("colosso: raiz " .. i .. " é sprite", BossTokens.image(p))
    end
    for _, snd in pairs(spec.sounds) do
        t:truthy("colosso: som " .. snd.code .. " (<= 0.9)", snd.volume <= 0.9)
    end
    localesHave(t, "colosso", { "enemy_kit.status.roots.name", "enemy_kit.status.roots.desc",
        "enemy_kit.msg.root_grow", "enemy_kit.msg.root_cut" })
end

local function testQueen(t)
    local ID = "eclipse_queen"
    local g = battleWith(ID, 1000, 20)
    local e = g.enemy
    t:eq("rainha: mecânica lua", BM.spec(e).kind, "moon")
    t:eq("rainha: abre na Crescente", BM.stacks(e, "moon"), 1)
    t:falsy("rainha: Crescente sem Vulnerável", e:hasStatus("vulnerable"))
    e._forcedNext = "lunar_blades"
    e:rollIntent(g.player)
    local it = e:getIntent()
    t:eq("rainha: 2º anúncio = Lua Cheia", BM.stacks(e, "moon"), 2)
    t:truthy("rainha: intent marcado Cheia", it.fullMoon)
    t:eq("rainha: Cheia = golpe x1,5 já no anúncio", it.perHit, math.floor(math.floor(20 * 0.4) * 1.5))
    local ev = BM.afterRoll(e)
    t:truthy("rainha: virada da Cheia avisa", ev and ev.full)
    e._forcedNext = "lunar_blades"
    e:rollIntent(g.player)
    t:eq("rainha: Minguante", BM.stacks(e, "moon"), 3)
    t:eq("rainha: Minguante sem bônus", e:getIntent().perHit, math.floor(20 * 0.4))
    t:falsy("rainha: Minguante não avisa", BM.afterRoll(e))
    e:rollIntent(g.player)
    t:eq("rainha: Lua Nova", BM.stacks(e, "moon"), 4)
    t:truthy("rainha: Lua Nova = Vulnerável", e:hasStatus("vulnerable"))
    t:truthy("rainha: intent marcado Nova", e:getIntent().newMoon)
    local hp = e.health
    e:takeDamage(10)
    t:eq("rainha: Vulnerável na Nova = +50%", hp - e.health, 15)
    e:onTurnEnd()
    t:falsy("rainha: Vulnerável some no turno dela", e:hasStatus("vulnerable"))
    e:rollIntent(g.player)
    t:eq("rainha: ciclo volta à Crescente", BM.stacks(e, "moon"), 1)

    local g2 = battleWith(ID, 1000, 20)
    local e2 = g2.enemy
    e2:rollIntent(g2.player)
    g2.player.armor = 0
    local expected = e2:getIncomingDamage(g2.player)
    local hp0 = g2.player.health
    CombatBeats.startTrace()
    runEnemyTurn(g2, 8)
    local trace = CombatBeats.traceString()
    CombatBeats.stopTrace()
    t:eq("rainha (luta): golpe da Cheia sai exatamente como anunciado", hp0 - g2.player.health, expected)
    t:eq("rainha (luta): virou Minguante no fim do turno", BM.stacks(e2, "moon"), 3)
    t:truthy("rainha (luta): sem beat extra na Minguante", not trace:find("boss.moon", 1, true))
    local g3 = battleWith(ID, 1000, 20)
    t:eq("Continuar: rainha começa na Crescente", BM.stacks(g3.enemy, "moon"), 1)
    t:truthy("rainha: marca de 50% (eclipse) na barra", #BM.hpMarks(g3.enemy) == 1
        and BM.hpMarks(g3.enemy)[1] == 0.5)

    local pills = require("src.ui.EnemyHud").collectPills(e2)
    local moonPill = nil
    for _, pl in ipairs(pills) do if pl.name == "moon" then moonPill = pl end end
    t:truthy("rainha: pill da lua sem número e com a fase no texto",
        moonPill and moonPill.variant == "p3" and moonPill.showStacks == false)

    local savedGS = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    BossTokens.reset()
    local n = 1
    local fake = { getStatusStacks = function(_, nm) return nm == "moon" and n or 0 end }
    settleTokens(ID, fake, 0.1)
    local st = BossTokens._debug(ID)
    t:eq("rainha visual: lua na fase do status", st.phase, 1)
    n = 2
    settleTokens(ID, fake, 0.1)
    t:eq("rainha visual: lua vira Cheia", st.phase, 2)
    t:eq("rainha visual: com transição", st.prevPhase, 1)
    local spec = BossTokens.spec(ID)
    local imgs = {}
    for p = 1, 4 do imgs[p] = BossTokens.moonImage(spec, p) end
    t:truthy("rainha visual: 4 fases desenhadas do sprite", imgs[1] and imgs[2] and imgs[3] and imgs[4])
    local function litCount(p)
        local out = 0
        local img = BossTokens.moonImage(spec, p)
        local cv = love.graphics.newCanvas(img:getWidth(), img:getHeight())
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, 0, 0)
        love.graphics.setCanvas()
        local data = cv:newImageData()
        for y = 0, data:getHeight() - 1 do
            for x = 0, data:getWidth() - 1 do
                local r0, _, _, a0 = data:getPixel(x, y)
                if a0 > 0 and r0 > 0.5 then out = out + 1 end
            end
        end
        return out
    end
    local full, cres, newm = litCount(2), litCount(1), litCount(4)
    t:truthy(string.format("rainha visual: Cheia > Crescente > Nova (%d > %d > %d)", full, cres, newm),
        full > cres and cres > newm)
    st.iw, st.ih, st.tgtX, st.tgtY = 140, 135, -200, 300
    t:truthy("rainha visual: Lâminas Lunares lançam crescente", BossTokens.strike(ID, "crescent", 0.34, 0.42))
    _G.gameSettings = { reducedMotion = true }
    BossTokens.reset()
    n = 4
    settleTokens(ID, fake, 0.1)
    t:eq("rainha reducedMotion: fase sem transição", BossTokens._debug(ID).prevPhase, nil)
    t:falsy("rainha reducedMotion: sem crescente", BossTokens.strike(ID, "crescent", 0.34, 0.42))
    _G.gameSettings = savedGS
    BossTokens.reset()

    local SP = ownIcon(t, "rainha", require("src.ui.StatusPill").ICONS.moon)
    t:eq("rainha: pill usa status_moon", SP.ICONS.moon, "status_moon")
    t:truthy("rainha: crescente é sprite", BossTokens.image(spec.strikes.crescent.sprite))
    for _, snd in pairs(spec.sounds) do
        t:truthy("rainha: som " .. snd.code .. " baixo", snd.volume <= 0.75)
    end
    localesHave(t, "rainha", { "enemy_kit.intent.full_moon", "enemy_kit.intent.new_moon",
        "enemy_kit.status.moon.name", "enemy_kit.status.moon.desc_p1", "enemy_kit.status.moon.desc_p2",
        "enemy_kit.status.moon.desc_p3", "enemy_kit.status.moon.desc_p4",
        "enemy_kit.msg.moon_full", "enemy_kit.msg.moon_new" })
end

local function testOwnIcons(t)
    local SP = require("src.ui.StatusPill")
    ownIcon(t, "foco", SP.ICONS.focus)
    ownIcon(t, "eclipse", SP.ICONS.eclipse)
    t:eq("foco tem ícone de status próprio", SP.ICONS.focus, "status_focus")
    t:eq("eclipse tem ícone de status próprio", SP.ICONS.eclipse, "status_eclipse")
    local function iconsAsked(path)
        local src = love.filesystem.read(path) or ""
        local names = {}
        for n in src:gmatch('IconLoader%.get%("([%w_]+)"%)') do names[#names + 1] = n end
        return names
    end
    local top = iconsAsked("components/TopBar.lua")
    local menu = iconsAsked("components/Menu.lua")
    local function has(list, name)
        for _, n in ipairs(list) do if n == name then return true end end
        return false
    end
    t:truthy("TopBar: pontuação com a estrela própria", has(top, "ui_score_star"))
    t:truthy("TopBar: ato com o pergaminho próprio", has(top, "ui_act_scroll"))
    t:falsy("TopBar: não pede mais a estrela de carta", has(top, "star"))
    t:falsy("TopBar: não pede mais o pergaminho de carta", has(top, "scroll"))
    t:truthy("Menu: perfil com a estrela própria", has(menu, "ui_score_star"))
    t:falsy("Menu: não pede mais a estrela de carta", has(menu, "star"))
    for _, name in ipairs(top) do ownIcon(t, "TopBar " .. name, name) end
    for _, name in ipairs(menu) do ownIcon(t, "Menu " .. name, name) end
end

function M.run()
    local t = TK.new("chefes: mecânica-assinatura, contador, visual, golpe")
    TK.bootstrap()
    TK.seedRng(9090)
    testLich(t)
    testTyrant(t)
    testTyrantChains(t)
    testMonarch(t)
    testColossus(t)
    testQueen(t)
    testOwnIcons(t)
    return t:done()
end

return M
