local TK = require("tools.testkit")
local M = {}

local function roster()
    local R = require("src.data.enemies").ROSTER
    local ids = {}
    for act = 1, 6 do
        for _, kind in ipairs({ "battle", "elite", "mini_boss", "boss" }) do
            for _, id in ipairs(R[act][kind] or {}) do ids[#ids + 1] = id end
        end
    end
    return ids
end

function M.run()
    local t = TK.new("sombra do inimigo acompanha o corpo (ataque, recuo, cadaver)")
    TK.bootstrap()
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local ShadowEngine = require("engine.ShadowEngine")
    local EnemyPoses = require("src.data.enemy_poses")

    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    local origSil = ShadowEngine.silhouette
    local origContact = EnemyRenderer.drawFootContact
    local sil, contact
    ShadowEngine.silhouette = function(x, y, o, fn)
        sil = { x = x, y = y }
        return true
    end
    EnemyRenderer.drawFootContact = function(cx, w, y, s, a)
        contact = { cx = cx, w = w, y = y, a = a }
    end
    local realTime = love.timer.getTime
    local clock = 100
    love.timer.getTime = function() return clock end

    local IconLoader = require("src.ui.IconLoader")
    local origGet = IconLoader.get
    local iconY
    local buffFail = {}
    IconLoader.get = function(name)
        local ic = origGet(name)
        if name == "status_strength" and ic then
            return { size = ic.size, draw = function(x, y, sc) iconY = y end }
        end
        return ic
    end
    local canvas = love.graphics.newCanvas(64, 64)
    local W, H = 1920, 1080
    local cx, cy = W / 2, math.floor(H * 0.7)

    local function frame(game)
        ShadowEngine.setFrame(cx - 600, W, 0.85, 0.8)
        sil, contact = nil, nil
        love.graphics.setCanvas(canvas)
        EnemyRenderer.draw(game, cx, cy)
        love.graphics.setCanvas()
        return EnemyRenderer.getLastFoot()
    end

    local lungeFail, knockFail, deathFail, floatFail, wideFail = {}, {}, {}, {}, {}
    local n = 0
    for _, id in ipairs(roster()) do
        n = n + 1
        EnemyRenderer.clearCache()
        EnemyRenderer.resetRun()
        local game = { enemy = { spriteId = id, isBoss = false, health = 10 } }
        frame(game)
        EnemyRenderer.update(0)
        local f0 = frame(game)
        local s0 = sil and { x = sil.x, y = sil.y }
        local c0 = contact and { cx = contact.cx }

        EnemyRenderer.triggerAttack("strong", function() end)
        local tt = 0
        local maxDev = 0
        while tt < 0.7 do
            EnemyRenderer.update(1 / 60)
            tt = tt + 1 / 60
            local f = frame(game)
            if f and f0 and sil and s0 then
                local bodyDX = (f.drawX + f.iw * f.scale / 2) - (f0.drawX + f0.iw * f0.scale / 2)
                local shDX = sil.x - s0.x
                local dev = math.abs(bodyDX - shDX)
                if dev > maxDev then maxDev = dev end
            end
        end
        if maxDev > 2.5 then lungeFail[#lungeFail + 1] = string.format("%s(%.1f)", id, maxDev) end

        EnemyRenderer.update(1.0)
        local f1 = frame(game)
        local s1 = sil and { x = sil.x }
        EnemyRenderer.triggerHurt()
        EnemyRenderer.update(1 / 60)
        local fk = frame(game)
        if fk and f1 and sil and s1 then
            local dev = math.abs((fk.drawX + fk.iw * fk.scale / 2) - (f1.drawX + f1.iw * f1.scale / 2) - (sil.x - s1.x))
            if dev > 2.5 then knockFail[#knockFail + 1] = string.format("%s(%.1f)", id, dev) end
        end

        EnemyRenderer.update(1.0)
        EnemyRenderer.triggerBuff()
        EnemyRenderer.update(0.1)
        iconY = nil
        local fb = frame(game)
        if not iconY then
            buffFail[#buffFail + 1] = id .. "(sem icone)"
        elseif fb and iconY < fb.drawY then
            buffFail[#buffFail + 1] = string.format("%s(%.0f acima do topo)", id, fb.drawY - iconY)
        end
        EnemyRenderer.update(1.0)
        game.enemy.health = 0
        EnemyRenderer.triggerDeath(id)
        for _ = 1, 240 do EnemyRenderer.update(1 / 60) end
        local fd = frame(game)
        local floating = EnemyPoses.isFloating(id)
        if not sil then
            deathFail[#deathFail + 1] = id .. "(sem sombra no cadaver)"
        end
        if not contact then
            if floating then floatFail[#floatFail + 1] = id else deathFail[#deathFail + 1] = id .. "(sem contato)" end
        else
            local m = EnemyRenderer.debugClipMetrics(id, "death")
            local ff = m.frameFeet and m.frameFeet[fd.frame]
            if ff then
                local expectW = (ff[2] - ff[1] + 1) * fd.scale
                if math.abs(contact.w - expectW) > 1 then
                    wideFail[#wideFail + 1] = string.format("%s(%.0f vs %.0f)", id, contact.w, expectW)
                end
            end
            if c0 and contact.a <= 0 then deathFail[#deathFail + 1] = id .. "(contato apagado)" end
        end
    end

    do
        EnemyRenderer.clearCache()
        EnemyRenderer.resetRun()
        local g = { enemy = { spriteId = "rot_colossus", isBoss = true, health = 10 } }
        local alphas = {}
        ShadowEngine.silhouette = function(x, y, o) alphas[#alphas + 1] = o.alphaK return true end
        for _, a in ipairs({ 1, 0.5, 0 }) do
            ShadowEngine.setFrame(cx - 600, W, 0.85, 0.8)
            contact = nil
            love.graphics.setCanvas(canvas)
            EnemyRenderer.draw(g, cx, cy, { alpha = a })
            love.graphics.setCanvas()
            alphas[#alphas + 1] = contact and contact.a or -1
        end
        t:truthy(string.format("corpo esmaecendo leva sombra e contato junto (%.2f/%.2f/%.2f)", alphas[1], alphas[3], alphas[5]),
            math.abs(alphas[3] - alphas[1] * 0.5) < 1e-6 and alphas[5] == 0 and math.abs(alphas[4] - alphas[2] * 0.5) < 1e-6)
    end
    ShadowEngine.silhouette = origSil
    EnemyRenderer.drawFootContact = origContact
    IconLoader.get = origGet
    love.timer.getTime = realTime
    _G.gameSettings = savedSettings
    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()

    t:truthy("roster inteiro testado (" .. n .. " inimigos)", n >= 42)
    t:eq("no bote/golpe forte a sombra anda junto com o corpo: " .. table.concat(lungeFail, " "), #lungeFail, 0)
    t:eq("no recuo do golpe a sombra anda junto com o corpo: " .. table.concat(knockFail, " "), #knockFail, 0)
    t:eq("cadaver com sombra e contato: " .. table.concat(deathFail, " "), #deathFail, 0)
    t:eq("flutuante caido ganha contato no chao: " .. table.concat(floatFail, " "), #floatFail, 0)
    t:eq("contato do cadaver mede o quadro deitado, nao o pe em pe: " .. table.concat(wideFail, " "), #wideFail, 0)
    t:eq("icone de forca do buff nasce no corpo, nunca acima do canvas (zona do HUD): " .. table.concat(buffFail, " "), #buffFail, 0)
    t:eq("flutuante no ar nao tem contato", EnemyRenderer.contactK(true, "idle", 0), 0)
    t:eq("flutuante no ataque nao tem contato", EnemyRenderer.contactK(true, "attack", 0), 0)
    t:eq("flutuante pousado tem contato cheio", EnemyRenderer.contactK(true, "death", 1), 1)
    t:truthy("flutuante caindo: contato cresce com a queda",
        EnemyRenderer.contactK(true, "death", 0.5) < EnemyRenderer.contactK(true, "death", 0.9))
    do
        local LE = require("engine.LightEngine")
        local SG = require("engine.SceneGrade")
        local origAmb, origAct = LE.ambientColor, SG.isActive
        SG.isActive = function() return true end
        LE.ambientColor = function() return 1, 1, 1 end
        local dia = EnemyRenderer.rimStrength()
        LE.ambientColor = function() return 0.62, 0.40, 0.36 end
        local noite = EnemyRenderer.rimStrength()
        LE.ambientColor, SG.isActive = origAmb, origAct
        t:eq("contorno de luz desligado com luz cheia", dia, 0)
        t:truthy(string.format("contorno de luz acende no escuro (%.2f)", noite), noite > 0.1 and noite <= EnemyRenderer.RIM.max)
    end
    do
        local nw, _, _, nt = EnemyRenderer.attackTiming("attack")
        local sw, _, _, st = EnemyRenderer.attackTiming("strong")
        t:truthy("golpe forte tem antecipacao mais longa que o comum", sw > nw + 0.1 and st > nt)
        local sq, dk = EnemyRenderer.strongPose(sw - 0.05)
        t:truthy(string.format("golpe forte agacha e escurece no preparo (squash %.2f, escuro %.2f)", sq, dk), sq > 0.05 and dk > 0.2)
        local sq2, dk2 = EnemyRenderer.strongPose(st)
        t:truthy("golpe forte volta ao normal no fim", sq2 == 0 and dk2 == 0)
    end
    t:eq("apoiado sempre tem contato", EnemyRenderer.contactK(false, "idle", 0), 1)
    return t:done()
end

return M
