local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("Queda dos flutuantes na morte")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local EnemyPoses = require("src.data.enemy_poses")
    local SceneAnchors = require("src.data.scene_anchors")
    local SpriteAnimation = require("src.ui.SpriteAnimation")

    local floors = {}
    local sizes = { { 1024, 768 }, { 1920, 1080 }, { 2560, 1440 } }
    for hall = 1, 6 do
        for _, sz in ipairs(sizes) do
            local scene = "castle_hall_" .. hall
            local x, y = SceneAnchors.groundAnchor(scene, sz[1], sz[2])
            local a = SceneAnchors.get(scene)
            local deathY = nil
            if a.deathYr then
                local _, dy = SceneAnchors.groundAnchor(scene, sz[1], sz[2], a.deathYr)
                deathY = math.max(y, dy)
            end
            floors[#floors + 1] = { name = scene .. "@" .. sz[1], x = x, y = y,
                                    deathY = deathY }
        end
    end
    for _, sz in ipairs(sizes) do
        floors[#floors + 1] = { name = "estrada@" .. sz[1],
            x = math.floor(sz[1] / 2), y = math.floor(sz[2] * 0.76) }
    end

    local canvas = love.graphics.newCanvas(64, 64)
    local SINK = EnemyRenderer.FOOT_SINK
    local floating = {}
    for id, p in pairs(EnemyPoses.BY_ID) do
        if p.pose == "floating" and SpriteAnimation.exists(id, "death", "south") then
            floating[#floating + 1] = id
        end
    end
    table.sort(floating)
    t:truthy("há flutuantes com death pra testar (" .. #floating .. ")", #floating >= 4)

    local function dieAt(id, fl, sizeK, reduced)
        local saved = _G.gameSettings
        _G.gameSettings = { reducedMotion = reduced or false }
        EnemyRenderer.clearCache()
        EnemyRenderer.resetRun()
        local game = { enemy = { spriteId = id, isBoss = false, health = 10 } }
        love.graphics.setCanvas(canvas)
        local opts = { sizeK = sizeK, deathCy = fl.deathY }
        EnemyRenderer.draw(game, fl.x, fl.y, opts)
        game.enemy.health = 0
        EnemyRenderer.triggerDeath(id)
        local samples = {}
        local tt = 0
        local dt = 1 / 60
        while tt < 4.5 do
            EnemyRenderer.update(dt)
            tt = tt + dt
            EnemyRenderer.draw(game, fl.x, fl.y, opts)
            local f = EnemyRenderer.getLastFoot()
            samples[#samples + 1] = { t = tt, gap = f.footBottom - (fl.deathY or fl.y) }
        end
        love.graphics.setCanvas()
        _G.gameSettings = saved
        return samples
    end

    local function at(samples, secs)
        local best = samples[1]
        for _, s in ipairs(samples) do
            if s.t <= secs then best = s end
        end
        return best.gap
    end

    local fails = 0
    local checked = 0
    for _, id in ipairs(floating) do
        for _, fl in ipairs(floors) do
            for _, sizeK in ipairs({ 0.85, 1.0, 1.3 }) do
                local s = dieAt(id, fl, sizeK, false)
                local mid = at(s, 0.08)
                local rest = at(s, 1.5)
                local late = at(s, 4.4)
                checked = checked + 1
                local ok = mid < rest - 4
                    and rest >= SINK - 1 and rest <= SINK + 1.5
                    and math.abs(late - rest) <= 1.5
                if not ok then
                    fails = fails + 1
                    if fails <= 12 then
                        print(string.format(
                            "  [queda] %s em %s k=%.2f: meio=%.1f repouso=%.1f 4s=%.1f (alvo %d)",
                            id, fl.name, sizeK, mid, rest, late, SINK))
                    end
                end
            end
        end
        local s = dieAt(id, floors[1], 1.0, true)
        local rest = at(s, 1.0)
        t:truthy(string.format("%s: reducedMotion repousa no chão (gap %.1f)", id, rest),
            rest >= SINK - 1 and rest <= SINK + 1.5)
    end
    t:truthy(string.format("flutuantes caem e repousam com o pé %dpx no chão em todo salão/estrada/escala (%d casos, %d falhas)",
        SINK, checked, fails), fails == 0)

    do
        local ROOT = "assets/sprites/characters/enemies"
        local grounded, badG = 0, 0
        for _, id in ipairs(love.filesystem.getDirectoryItems(ROOT)) do
            if not EnemyPoses.isFloating(id)
                and SpriteAnimation.exists(id, "death", "south") then
                grounded = grounded + 1
                local s = dieAt(id, floors[#floors], 1.0, false)
                local rest = at(s, 2.0)
                if not (rest >= SINK - 1 and rest <= SINK + 1.5) then
                    badG = badG + 1
                    print(string.format("  [cadaver] %s: gap final %.1f (alvo %d)", id, rest, SINK))
                end
            end
        end
        t:truthy(string.format("cadáver de todo apoiado repousa no chão (%d inimigos, %d falhas)",
            grounded, badG), badG == 0 and grounded >= 20)
    end

    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()
    return t:done()
end

return M
