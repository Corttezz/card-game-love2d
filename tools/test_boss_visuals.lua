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
