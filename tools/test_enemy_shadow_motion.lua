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

    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    local origSil = ShadowEngine.silhouette
    local sil
    ShadowEngine.silhouette = function(x, y, o, fn)
        sil = { x = x, y = y }
        return true
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
        EnemyRenderer._flap.n = 0
        sil = nil
        love.graphics.setCanvas(canvas)
        EnemyRenderer.draw(game, cx, cy)
        love.graphics.setCanvas()
        return EnemyRenderer.getLastFoot()
    end

    local lungeFail, knockFail, deathFail = {}, {}, {}
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
        frame(game)
        if not sil then
            deathFail[#deathFail + 1] = id .. "(sem sombra no cadaver)"
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
            love.graphics.setCanvas(canvas)
            EnemyRenderer.draw(g, cx, cy, { alpha = a })
            love.graphics.setCanvas()
        end
        t:truthy(string.format("corpo esmaecendo leva a sombra junto (%.2f/%.2f/%.2f)", alphas[1], alphas[2], alphas[3]),
            math.abs(alphas[2] - alphas[1] * 0.5) < 1e-6 and alphas[3] == 0)
    end
    ShadowEngine.silhouette = origSil
    IconLoader.get = origGet
    love.timer.getTime = realTime
    _G.gameSettings = savedSettings
    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()

    t:truthy("roster inteiro testado (" .. n .. " inimigos)", n >= 42)
    t:eq("no bote/golpe forte a sombra anda junto com o corpo: " .. table.concat(lungeFail, " "), #lungeFail, 0)
    t:eq("no recuo do golpe a sombra anda junto com o corpo: " .. table.concat(knockFail, " "), #knockFail, 0)
    t:eq("cadaver com sombra projetada: " .. table.concat(deathFail, " "), #deathFail, 0)
    t:eq("icone de forca do buff nasce no corpo, nunca acima do canvas (zona do HUD): " .. table.concat(buffFail, " "), #buffFail, 0)
    t:falsy("sem sombrinha redonda sob o pe (dono, 24/Out): drawFootContact saiu", EnemyRenderer.drawFootContact ~= nil)
    t:falsy("sem contactK (so a silhueta projetada)", EnemyRenderer.contactK ~= nil)
    t:falsy("salao sem poca de contato (InteriorDepth saiu)", love.filesystem.getInfo("src/ui/InteriorDepth.lua") ~= nil)
    do
        local src = love.filesystem.read("src/ui/EnemyRenderer.lua") or ""
        t:falsy("EnemyRenderer nao desenha elipse de sombra", src:find("graphics.ellipse", 1, true) ~= nil)
        local wr = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        t:falsy("billboard da estrada sem contato de pe", wr:find("drawFootContact", 1, true) ~= nil)
    end
    do
        local EL = require("src.ui.EnemyLife")
        local big = love.graphics.newCanvas(W, H)
        local realEl = love.graphics.ellipse
        local nEl = 0
        love.graphics.ellipse = function(...) nEl = nEl + 1 return realEl(...) end
        local fxWas = EL.fxEnabled
        EL.fxEnabled = false
        ShadowEngine.silhouette = function() return true end
        local underFail = {}
        for _, id in ipairs({ "frost_troll", "pit_brute", "plague_rats", "winter_monarch", "dusk_bat", "rot_colossus" }) do
            EnemyRenderer.clearCache()
            EnemyRenderer.resetRun()
            local g = { enemy = { spriteId = id, isBoss = false, health = 10 } }
            love.graphics.setCanvas(big)
            love.graphics.clear(0, 0, 0, 0)
            ShadowEngine.setFrame(cx - 600, W, 0.85, 0.8)
            EnemyRenderer.draw(g, cx, cy)
            EnemyRenderer.update(1 / 60)
            love.graphics.clear(0, 0, 0, 0)
            local SA = require("src.ui.SpriteAnimation")
            local realDraw = SA.draw
            SA.draw = function() end
            EnemyRenderer.draw(g, cx, cy)
            SA.draw = realDraw
            love.graphics.setCanvas()
            local d = big:newImageData()
            local n = 0
            for y = cy - 24, cy + 16 do
                for x = cx - 260, cx + 260 do
                    local _, _, _, a = d:getPixel(x, y)
                    if a > 0.01 then n = n + 1 end
                end
            end
            if n > 0 then underFail[#underFail + 1] = id .. "(" .. n .. ")" end
        end
        EL.fxEnabled = fxWas
        love.graphics.ellipse = realEl
        ShadowEngine.silhouette = origSil
        t:eq("sem o corpo e sem a silhueta, nada sobra no chao junto ao pe: " .. table.concat(underFail, " "), #underFail, 0)
        t:eq("nenhuma elipse no desenho do inimigo", nEl, 0)
    end
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
        t:eq("sem contorno de luz no escuro (dono: borda estranha)", noite, 0)
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
    do
        local GS = require("src.scenes.GameplayScene")
        love.timer.getTime = function() return clock + 50 end
        t:falsy("salao sem frame de sombra fica sem sombra", ShadowEngine.isActive())
        GS.hallShadowFrame({ lightXr = 0.5 }, 1920)
        t:truthy("salao do chefe liga a sombra de silhueta (luz atras do chefe)", ShadowEngine.isActive())
        t:eq("luz do salao no centro: sombra cai reto pra frente", ShadowEngine.tipShiftAt(960), 0)
        love.timer.getTime = realTime
    end
    return t:done()
end

return M
