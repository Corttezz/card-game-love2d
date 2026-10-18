local TK = require("tools.testkit")
local M = {}

local ART = "assets/sprites/characters/enemies"

local function frames(id, clip)
    local dir = ART .. "/" .. id .. "/animations/" .. clip .. "/south"
    local out = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local n = tonumber(f:match("^(%d+)%.png$"))
        if n then out[#out + 1] = { n = n, path = dir .. "/" .. f } end
    end
    table.sort(out, function(a, b) return a.n < b.n end)
    return out
end

local function diffFrac(a, b)
    if a:getWidth() ~= b:getWidth() or a:getHeight() ~= b:getHeight() then
        return 1
    end
    local w, h, n = a:getWidth(), a:getHeight(), 0
    for y = 0, h - 1, 2 do
        for x = 0, w - 1, 2 do
            local r1, g1, b1, a1 = a:getPixel(x, y)
            local r2, g2, b2, a2 = b:getPixel(x, y)
            if math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2)
                + math.abs(a1 - a2) > 0.12 then
                n = n + 1
            end
        end
    end
    return n / (math.ceil(w / 2) * math.ceil(h / 2))
end

function M.run()
    local t = TK.new("Visual dos chefes")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local EnemyPoses = require("src.data.enemy_poses")
    local BossAura = require("src.ui.BossAura")
    local AURAS = require("src.data.boss_auras")

    local bosses = {}
    for act = 1, 6 do
        bosses[#bosses + 1] = EnemyRenderer.resolveSpriteId(act, "boss")
    end
    t:eq("seis chefes no roster", #bosses, 6)

    for _, id in ipairs(bosses) do
        local idle = frames(id, "idle")
        t:truthy(id .. ": idle com >= 8 quadros (" .. #idle .. ")", #idle >= 8)
        local spec = (EnemyPoses.BY_ID[id] or {}).idle
        t:truthy(id .. ": pose declara idle em loop (cycle)", spec and spec.cycle)
        local fps, opts = EnemyRenderer._idleSpec(id)
        t:truthy(id .. ": renderer toca o idle sem ping-pong",
            opts.loop and not opts.pingpong and fps > 0)

        local datas = {}
        for i, f in ipairs(idle) do datas[i] = love.image.newImageData(f.path) end
        local sameSize = true
        for i = 2, #datas do
            if datas[i]:getWidth() ~= datas[1]:getWidth()
                or datas[i]:getHeight() ~= datas[1]:getHeight() then
                sameSize = false
            end
        end
        t:truthy(id .. ": todos os quadros no mesmo canvas", sameSize)
        local maxD, maxStep = 0, 0
        for i = 2, #datas do
            maxD = math.max(maxD, diffFrac(datas[1], datas[i]))
            maxStep = math.max(maxStep, diffFrac(datas[i - 1], datas[i]))
        end
        t:truthy(string.format("%s: idle MEXE (pico %.1f%%)", id, maxD * 100),
            maxD > 0.015)
        t:truthy(string.format("%s: ...sem chuvisco de regeração (passo %.1f%%)",
            id, maxStep * 100), maxStep < 0.30)

        for _, clip in ipairs({ "hurt", "death" }) do
            local c = frames(id, clip)
            if c[1] and datas[1] then
                local d = diffFrac(datas[1], love.image.newImageData(c[1].path))
                t:truthy(string.format("%s: quadro 0 do %s ≈ idle (%.1f%%)",
                    id, clip, d * 100), d < 0.10)
            end
        end

        local a = AURAS[id]
        t:truthy(id .. ": tem aura declarada", a ~= nil)
        if a then
            t:falsy(id .. ": aura sem contorno colorido", a.rim)
            t:truthy(id .. ": aura tem brilho", a.glows and #a.glows > 0)
            local maxR = 0
            for _, g in ipairs(a.glows or {}) do maxR = math.max(maxR, g.r or 0) end
            t:truthy(id .. ": brilho pequeno (raio " .. maxR .. " <= 8)", maxR <= 8)
        end
    end

    local savedGS = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    local savedState = love.math.getRandomState()
    love.math.setRandomSeed(20261011)
    BossAura.reset()
    for _ = 1, 60 do BossAura.update(1 / 30, "tower_lich", false) end
    local n = BossAura._debugCount("tower_lich")
    t:truthy("aura do lich emite partículas em 2s (" .. n .. ")", n > 3)
    for _ = 1, 30 do BossAura.update(1 / 30, "tower_lich", true) end
    local _, fade = BossAura._debugCount("tower_lich")
    t:eq("morte esvai a aura", fade, 0)

    local KING = "carrion_king"
    local o = AURAS[KING].orbit
    t:eq("rei-carniça: corvos contados pelo status swarm", o.countBy, "swarm")
    local function fakeEnemy(n)
        return { getStatusStacks = function(_, name) return name == "swarm" and n or 0 end }
    end
    local function settle(n, secs)
        BossAura.setCountFrom(KING, fakeEnemy(n))
        for _ = 1, math.floor((secs or 3) * 30) do BossAura.update(1 / 30, KING, false) end
    end
    BossAura.reset()
    settle(0, 1)
    t:eq("0 corvos invocados = 0 voando", BossAura.flockCount(KING), 0)
    settle(3)
    t:eq("3 corvos invocados = 3 voando", BossAura.flockCount(KING), 3)
    t:eq("...os 3 já em órbita depois do rasante", BossAura.flockPhases(KING).orbit, 3)
    BossAura.setCountFrom(KING, fakeEnemy(5))
    BossAura.update(1 / 30, KING, false)
    t:eq("novos corvos entram com rasante", BossAura.flockPhases(KING).enter, 2)
    settle(6)
    t:eq("6 corvos invocados = 6 voando", BossAura.flockCount(KING), 6)
    settle(o.max + 7)
    t:eq("teto visual de " .. o.max, BossAura.flockCount(KING), o.max)
    settle(2, 0.1)
    t:eq("contagem cai = sobram 2", BossAura.flockCount(KING), 2)
    t:truthy("...os outros saem voando", (BossAura.flockPhases(KING).leave or 0) > 0)
    settle(2, 2)
    t:falsy("...e somem", BossAura.flockPhases(KING).leave)
    t:truthy("ataque da revoada: um corvo mergulha", BossAura.dive(KING, 0.34, 0.42))
    t:eq("...em mergulho", BossAura.flockPhases(KING).dive, 1)
    for _ = 1, 30 do BossAura.update(1 / 30, KING, false) end
    t:falsy("...e volta pra órbita no fim do beat", BossAura.flockPhases(KING).dive)
    t:eq("...sem mudar a contagem", BossAura.flockCount(KING), 2)
    BossAura.reset()
    settle(0, 0.1)
    t:falsy("sem corvo invocado o rei não manda ninguém", BossAura.dive(KING, 0.34, 0.42))

    _G.gameSettings = { reducedMotion = true }
    BossAura.reset()
    settle(0, 0.1)
    BossAura.setCountFrom(KING, fakeEnemy(4))
    BossAura.update(1 / 30, KING, false)
    t:eq("reducedMotion: 4 corvos aparecem já em órbita", BossAura.flockPhases(KING).orbit, 4)
    t:falsy("reducedMotion: nenhum mergulho", BossAura.dive(KING, 0.34, 0.42))

    local crowImgs = BossAura.crowFrames(o.sprite)
    t:truthy("corvo do bando é sprite animado (>= 4 quadros)", crowImgs and #crowImgs >= 4)
    if crowImgs then
        local cw, chh = crowImgs[1]:getDimensions()
        t:truthy(string.format("corvo pequeno (%dx%d <= 32)", cw, chh), cw <= 32 and chh <= 32)
    end
    t:eq("órbita em escala inteira", BossAura.crowScale(2.3) % 1, 0)
    t:eq("escala do mergulho é inteira", BossAura.FLOCK.big % 1, 0)
    _G.gameSettings = { reducedMotion = false }
    BossAura.reset()
    settle(0, 0.1)
    settle(3)
    BossAura.dive(KING, 0.34, 0.42)
    for _ = 1, 9 do BossAura.update(1 / 30, KING, false) end
    local sAll = { iw = 148, ih = 129, t = 0, rot = 0, tgtX = -200, tgtY = 300 }
    for _, c in ipairs({ { phase = "orbit", off = 0, h1 = 0.5, h2 = 0.5, seed = 1 },
                         { phase = "dive", t = 0.3, apex = 0.34, back = 0.42,
                           off = 0, h1 = 0.5, h2 = 0.5, seed = 1 },
                         { phase = "enter", t = 0.1, side = 1, off = 0, h1 = 0.5, h2 = 0.5, seed = 1 } }) do
        local _, _, big = BossAura._crowPose(o, sAll, c, false)
        t:eq("corvo " .. c.phase .. " em escala inteira", (big or 1) % 1, 0)
    end

    local StatusPill = require("src.ui.StatusPill")
    local iconName = StatusPill.ICONS.swarm
    t:eq("pill da revoada tem ícone próprio", iconName, "status_crows")
    local iconPath = "assets/sprites/icons/" .. tostring(iconName) .. ".png"
    t:truthy("ícone dos corvos existe", love.filesystem.getInfo(iconPath))
    local cardIcons = {}
    for _, art in pairs(require("src.data.card_art")) do
        if type(art) == "table" and art.icon then cardIcons[art.icon] = true end
    end
    t:falsy("ícone dos corvos não é ícone de carta", cardIcons[iconName])
    local bytes = love.filesystem.read(iconPath)
    local same = nil
    for name in pairs(cardIcons) do
        local p = "assets/sprites/icons/" .. name .. ".png"
        if love.filesystem.getInfo(p) and love.filesystem.read(p) == bytes then same = name end
    end
    t:falsy("ícone dos corvos não copia bytes de carta", same)
    local okImg, img = pcall(love.graphics.newImage, iconPath)
    t:truthy("ícone dos corvos carrega 64x64", okImg and img:getWidth() == 64)

    local SOUNDS = require("src.ui.BossCinematic").SOUNDS
    t:truthy("sting do cartão mais baixo (<= 0.50)", SOUNDS.bossRevealSting[2] <= 0.50)
    for code, spec in pairs(require("src.systems.CrowSfx").MOMENTS) do
        t:truthy("corvo " .. code .. " no volume dos sons de chefe (<= 0.60)", spec.volume <= 0.60)
    end

    _G.gameSettings = { reducedMotion = true }
    BossAura.reset()
    for _ = 1, 60 do BossAura.update(1 / 30, "abyss_tyrant", false) end
    t:eq("reducedMotion: emissor parado", (BossAura._debugCount("abyss_tyrant")), 0)
    _G.gameSettings = savedGS
    love.math.setRandomState(savedState)
    BossAura.reset()

    local wm = EnemyPoses.BY_ID.winter_monarch
    local m = EnemyRenderer.debugClipMetrics("winter_monarch", "idle")
    t:truthy("winter_monarch declara axisX", wm and wm.axisX)
    if wm and wm.axisX and m.w > 0 then
        local bboxCenter = m.w / 2 + m.off
        t:truthy(string.format("eixo (%d) à esquerda do centro do bbox (%.1f)",
            wm.axisX, bboxCenter), wm.axisX < bboxCenter - 3)
    end

    return t:done()
end

return M
