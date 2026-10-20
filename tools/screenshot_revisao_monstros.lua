local M = {}

local VW, VH = 1920, 1080
local DT = 1 / 60

local function parseArg(arg)
    arg = arg or "1"
    local act, only = arg:match("^(%d+):?([%w_,]*)$")
    act = tonumber(act) or 1
    local set = nil
    if only and only ~= "" then
        set = {}
        for id in only:gmatch("[^,]+") do set[id] = true end
    end
    return act, set
end

local function rosterOf(act)
    local R = require("src.data.enemies").ROSTER[act]
    local list = {}
    for _, kind in ipairs({ "battle", "elite", "mini_boss", "boss" }) do
        for _, id in ipairs(R[kind] or {}) do list[#list + 1] = { id = id, node = kind } end
    end
    return list
end

function M.runLuz(act, tag)
    local vcanvas = love.graphics.newCanvas(VW, VH)
    local realW, realH = love.graphics.getWidth, love.graphics.getHeight
    local realDim = love.graphics.getDimensions
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    local realMouse = love.mouse.getPosition
    love.mouse.getPosition = function() return -500, -500 end
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local Enemy = require("src.entities.Enemy")
    local FontManager = require("src.ui.FontManager")
    local font = FontManager.getFont(16)
    local tods = { 0.65, 0.85, 1.0 }
    local list = {}
    for _, e in ipairs(rosterOf(act)) do
        if e.node ~= "boss" then list[#list + 1] = e end
    end
    local cw, ch = 420, 470
    local sheet = love.graphics.newCanvas(#tods * (cw + 6), #list * (ch + 6))
    love.graphics.setCanvas(sheet)
    love.graphics.clear(0.12, 0.12, 0.12, 1)
    love.graphics.setCanvas()
    for row, entry in ipairs(list) do
        _G.EventManager.clear()
        EnemyRenderer.clearCache()
        EnemyRenderer.resetRun()
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        local run = game.runManager.currentRun
        run.actNumber = act
        run.floorInAct = 5
        run.currentNode = { type = entry.node }
        game.enemy = EnemyRoster.spawn(Enemy, entry.id,
            ActSystem.getEnemyStats(act, 5, entry.node))
        game.messageSystem = nil
        _G.game = game
        local topBar = TopBar:new()
        topBar:setGame(game)
        GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
            playButton = Button:new(VW * 0.8, VH * 0.8, 150, 46, "Jogar") })
        WorldRoad.setBiome(act)
        for col, tod in ipairs(tods) do
            WorldRoad.setTimeOfDay(tod, true)
            for _ = 1, 40 do
                WorldRoad.update(1 / 60)
                EnemyRenderer.update(1 / 60)
                WorldRoad.setTimeOfDay(tod, true)
            end
            love.graphics.setCanvas(vcanvas)
            love.graphics.clear(0, 0, 0, 1)
            GameplayScene.draw()
            love.graphics.setCanvas()
            local f = EnemyRenderer.getLastFoot()
            local bx = f and f.bodyX or VW / 2
            local gy = f and f.groundY or VH * 0.7
            local x0 = math.max(0, math.min(VW - cw, math.floor(bx - cw / 2)))
            local y0 = math.max(0, math.min(VH - ch, math.floor(gy - ch + 90)))
            local q = love.graphics.newQuad(x0, y0, cw, ch, VW, VH)
            love.graphics.setCanvas(sheet)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(vcanvas, q, (col - 1) * (cw + 6), (row - 1) * (ch + 6))
            love.graphics.setFont(font)
            local LE = require("engine.LightEngine")
            local ar, ag, ab = LE.ambientColor()
            love.graphics.print(string.format("%.2f a%.2f r%.2f %s", tod,
                0.299 * ar + 0.587 * ag + 0.114 * ab, EnemyRenderer.rimStrength(), entry.id),
                (col - 1) * (cw + 6) + 4, (row - 1) * (ch + 6) + 2)
            love.graphics.setCanvas()
            q:release()
        end
    end
    love.filesystem.createDirectory("revisao_monstros")
    local out = "revisao_monstros/luz_ato" .. act .. "_" .. (tag or "x") .. ".png"
    local d = sheet:newImageData()
    d:encode("png", out)
    d:release(); sheet:release(); vcanvas:release()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    love.graphics.getDimensions = realDim
    love.mouse.getPosition = realMouse
    print("[revisao_monstros] " .. love.filesystem.getSaveDirectory() .. "/" .. out)
    return true
end

function M.run(arg)
    local la, lt = (arg or ""):match("^luz:(%d+):?(%w*)$")
    if la then return M.runLuz(tonumber(la), lt) end
    local act, only = parseArg(arg)
    local vcanvas = love.graphics.newCanvas(VW, VH)
    local realW, realH = love.graphics.getWidth, love.graphics.getHeight
    local realDim = love.graphics.getDimensions
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    local realMouse = love.mouse.getPosition
    local mouseX, mouseY = -500, -500
    love.mouse.getPosition = function() return mouseX, mouseY end
    love.mouse.getX = function() return mouseX end
    love.mouse.getY = function() return mouseY end

    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false

    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local Enemy = require("src.entities.Enemy")
    local BossCinematic = require("src.ui.BossCinematic")
    local InteriorFX = require("src.ui.InteriorFX")
    local EnemyHud = require("src.ui.EnemyHud")
    local StatusTooltip = require("src.ui.StatusTooltip")
    local FontManager = require("src.ui.FontManager")
    local CombatBeats = require("src.systems.CombatBeats")
    local ShadowEngine = require("engine.ShadowEngine")
    local InteriorDepth = require("src.ui.InteriorDepth")

    local origBossAlpha = BossCinematic.bossAlpha
    if os.getenv("REVMON_ANTES") == "1" then BossCinematic.bossAlpha = function() return 1 end end
    local lastBbox
    local origDraw = EnemyRenderer.draw
    EnemyRenderer.draw = function(...)
        local b = origDraw(...)
        if b then lastBbox = b end
        return b
    end
    local lastL
    local origLayout = EnemyHud.layout
    EnemyHud.layout = function(...)
        local L = origLayout(...)
        lastL = L
        return L
    end

    local outDir = "revisao_monstros/ato" .. act
    love.filesystem.createDirectory(outDir)
    local font = FontManager.getFont(16)
    local report = {}

    for _, entry in ipairs(rosterOf(act)) do
        local id, node = entry.id, entry.node
        if not only or only[id] then
            local isBoss = node == "boss"
            _G.EventManager.clear()
            CombatBeats.clear()
            EnemyRenderer.clearCache()
            EnemyRenderer.resetRun()
            if BossCinematic.reset then BossCinematic.reset() end
            local game = Game:new()
            game:startNewRun("warrior")
            game:startGame()
            local run = game.runManager.currentRun
            run.actNumber = act
            run.floorInAct = isBoss and 8 or 5
            run.currentNode = { type = node }
            local stats = ActSystem.getEnemyStats(act, run.floorInAct, node)
            game.enemy = EnemyRoster.spawn(Enemy, id, stats)
            game.enemy.isBoss = isBoss
            game.messageSystem = nil
            _G.game = game
            local topBar = TopBar:new()
            topBar:setGame(game)
            GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
                playButton = Button:new(VW * 0.80, VH * 0.80, 150, 46, "Jogar") })
            if isBoss then
                GameplayScene._debugForceBossEntered()
                love.timer.sleep(0.15)
            end
            WorldRoad.setBiome(act)

            local tod = 0.85
            local function step(secs, deathCine)
                local n = math.max(1, math.floor(secs / DT + 0.5))
                for _ = 1, n do
                    _G.EventManager.update(DT)
                    if not isBoss then WorldRoad.update(DT) end
                    EnemyRenderer.update(DT)
                    if isBoss then
                        InteriorFX.update(DT, InteriorFX.hallFor(act))
                        if deathCine then BossCinematic.update(DT, game, { inHall = true }) end
                    end
                    WorldRoad.setTimeOfDay(tod, true)
                end
            end

            local frames = {}
            local crop
            local function render()
                love.graphics.setCanvas(vcanvas)
                love.graphics.clear(0, 0, 0, 1)
                GameplayScene.draw()
                love.graphics.setCanvas()
            end
            local function shot(label, extra)
                local realTime = love.timer.getTime
                local frozen = realTime()
                love.timer.getTime = function() return frozen end
                local seed = love.math.getRandomSeed and { love.math.getRandomSeed() }
                render()
                if extra then
                    love.graphics.setCanvas(vcanvas)
                    extra()
                    love.graphics.setCanvas()
                end
                local foot = EnemyRenderer.getLastFoot()
                local data = vcanvas:newImageData()
                local S, C, ID = ShadowEngine.silhouette, EnemyRenderer.drawFootContact, InteriorDepth.drawContact
                ShadowEngine.silhouette = function() return true end
                EnemyRenderer.drawFootContact = function() end
                InteriorDepth.drawContact = function() end
                if seed then love.math.setRandomSeed(seed[1], seed[2]) end
                render()
                ShadowEngine.silhouette, EnemyRenderer.drawFootContact, InteriorDepth.drawContact = S, C, ID
                love.timer.getTime = realTime
                local bare = vcanvas:newImageData()
                frames[#frames + 1] = { label = label, data = data, bare = bare,
                    foot = foot and { bodyX = foot.bodyX, groundY = foot.groundY } or nil }
            end

            WorldRoad.setTimeOfDay(tod, true)
            step(1.0)

            if not isBoss then
                WorldRoad.travel({
                    encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
                    onComplete = function() EnemyRenderer.triggerArrival() end,
                })
                local tr = WorldRoad._travel
                local guard = 0
                local encPos
                WorldRoad._traceEnemy = function(x, y) encPos = { x = x, y = y } end
                while tr and WorldRoad._travel and tr.t + DT < tr.duration and guard < 2000 do
                    step(DT)
                    if tr.duration - tr.t < 0.6 then render() end
                    guard = guard + 1
                end
                shot("chegada (fim)")
                local ePos = encPos
                WorldRoad._traceEnemy = nil
                step(DT)
                shot("batalha (1o quadro)")
                local lf = EnemyRenderer.getLastFoot()
                if ePos and lf then
                    print(string.format("[revisao_monstros] %s handoff dx=%.1f dy=%.1f",
                        id, lf.drawX - ePos.x, lf.drawY - EnemyRenderer.getArrivalOffset() - ePos.y))
                end
                step(0.7)
            else
                step(0.5)
            end
            shot("parado tod .85")
            if lastBbox then
                local w = math.max(820, math.floor(lastBbox.width * 1.7))
                local h = math.floor(lastBbox.bottomY - lastBbox.topY) + 440
                w, h = math.min(w, 900), math.min(h, 1060)
                local cx = lastBbox.cx
                local x0 = math.max(0, math.min(VW - w, math.floor(cx - w / 2)))
                local y0 = math.max(0, math.min(VH - h, math.floor(lastBbox.topY - 180)))
                crop = { x = x0, y = y0, w = w, h = h }
            end
            local idleFoot = EnemyRenderer.getLastFoot()
            local anchorX = idleFoot and idleFoot.bodyX or VW / 2
            local anchorY = idleFoot and idleFoot.groundY or VH * 0.7

            if act == 1 or isBoss or node == "battle" then
                tod = 0.5
                step(0.1)
                shot("parado tod .50")
                tod = 0.85
                step(0.1)
            end

            EnemyRenderer.triggerAttack("attack", function() end)
            local tAcc = 0
            for _, tt in ipairs({ 0.06, 0.14, 0.22, 0.30, 0.45, 0.65 }) do
                step(tt - tAcc); tAcc = tt
                shot(string.format("ataque %.2fs", tt))
            end
            step(0.6)
            EnemyRenderer.triggerAttack("strong", function() end)
            tAcc = 0
            for _, tt in ipairs({ 0.15, 0.30, 0.42, 0.50, 0.70 }) do
                step(tt - tAcc); tAcc = tt
                shot(string.format("forte %.2fs", tt))
            end
            step(0.8)

            local e = game.enemy
            e:addStatusEffect({ name = "poison", stacks = 4, duration = 4 })
            e:addStatusEffect({ name = "weak", stacks = 1, duration = 2 })
            e:addStatusEffect({ name = "vulnerable", stacks = 1, duration = 2 })
            e:addStatusEffect({ name = "burn", stacks = 3, duration = 3 })
            e:addStatusEffect({ name = "strength", stacks = 2, duration = 99 })
            EnemyRenderer.triggerHurt()
            step(0.06)
            shot("golpe + estados")
            step(0.5)
            e.health = math.max(1, math.floor(e.maxHealth * 0.5))
            e:takeDamage(math.floor(e.maxHealth * 0.3))
            game:announceEnrageIfPending(nil)
            step(0.18)
            shot("enfurecido (beat)")
            step(1.0)
            render()
            local L = lastL
            if L and L.iw and L.iw > 0 then
                local uk = require("src.ui.UiScale").k()
                local function tip(label, vx)
                    mouseX = math.floor(vx * uk)
                    mouseY = math.floor((L.rowY + L.rowH / 2) * uk)
                    local rt = love.timer.getTime
                    local base, ft = rt(), 0
                    love.timer.getTime = function() return base + ft end
                    for _ = 1, 14 do ft = ft + 0.05; render() end
                    shot(label)
                    love.timer.getTime = rt
                end
                local x0 = L.cx - L.totalW / 2
                tip("tooltip intencao", x0 + L.iw / 2)
                tip("tooltip estado", x0 + L.iw + L.gap + (L.pillSize or 34) / 2)
                mouseX, mouseY = -500, -500
            end
            e.intentVisibility = "type_only"
            e.intentVeilCause = "fog"
            shot("nevoa: tipo so")
            e.intentVisibility = nil

            e.health = 0
            game:_onEnemyDeath()
            tAcc = 0
            local deathT = isBoss and { 0.1, 0.4, 0.8, 1.3, 2.0, 3.0, 4.5, 6.5 }
                or { 0.05, 0.2, 0.35, 0.5, 0.7, 0.95, 1.4, 2.5 }
            if os.getenv("REVMON_DEATH_T") then
                deathT = {}
                for v in os.getenv("REVMON_DEATH_T"):gmatch("[%d%.]+") do deathT[#deathT + 1] = tonumber(v) end
            end
            for _, tt in ipairs(deathT) do
                step(tt - tAcc, true); tAcc = tt
                shot(string.format("morte %.2fs", tt))
            end

            crop = crop or { x = 560, y = 200, w = 800, h = 800 }
            local cols = 4
            local rows = math.ceil(#frames / cols)
            local labH = 22
            local sheet = love.graphics.newCanvas(cols * (crop.w + 6), rows * (crop.h + labH + 6))
            local feetW, feetH = 440, 150
            local feetSheet = love.graphics.newCanvas(cols * (feetW * 2 + 6), rows * (feetH * 2 + labH + 6))
            love.graphics.setCanvas(sheet)
            love.graphics.clear(0.12, 0.12, 0.12, 1)
            love.graphics.setCanvas(feetSheet)
            love.graphics.clear(0.12, 0.12, 0.12, 1)
            love.graphics.setCanvas()
            for i, f in ipairs(frames) do
                local img = love.graphics.newImage(f.data)
                img:setFilter("nearest", "nearest")
                local c = (i - 1) % cols
                local r = math.floor((i - 1) / cols)
                love.graphics.setCanvas(sheet)
                love.graphics.setColor(1, 1, 1, 1)
                local q = love.graphics.newQuad(crop.x, crop.y, crop.w, crop.h, VW, VH)
                love.graphics.draw(img, q, c * (crop.w + 6), r * (crop.h + labH + 6) + labH)
                love.graphics.setFont(font)
                love.graphics.print(id .. "  " .. f.label, c * (crop.w + 6) + 4, r * (crop.h + labH + 6) + 2)
                love.graphics.setCanvas(feetSheet)
                local fx, fy = anchorX, anchorY
                local qx = math.max(0, math.min(VW - feetW, math.floor(fx - feetW / 2)))
                local qy = math.max(0, math.min(VH - feetH, math.floor(fy - feetH * 0.6)))
                local q2 = love.graphics.newQuad(qx, qy, feetW, feetH, VW, VH)
                love.graphics.draw(img, q2, c * (feetW * 2 + 6), r * (feetH * 2 + labH + 6) + labH, 0, 2, 2)
                love.graphics.print(f.label, c * (feetW * 2 + 6) + 4, r * (feetH * 2 + labH + 6) + 2)
                love.graphics.setCanvas()
                img:release()
                q:release(); q2:release()
            end
            local mw, mh = crop.w, crop.h
            local maskSheet = love.image.newImageData(cols * (mw + 6), rows * (mh + 6))
            local cell = love.image.newImageData(mw, mh)
            for i, f in ipairs(frames) do
                local n, sx0, sx1, sy1, sumX, peak = 0, 1e9, -1e9, -1e9, 0, 0
                for y = 0, mh - 1 do
                    for x = 0, mw - 1 do
                        local r1, g1, b1 = f.data:getPixel(crop.x + x, crop.y + y)
                        local r2, g2, b2 = f.bare:getPixel(crop.x + x, crop.y + y)
                        local l1 = 0.3 * r1 + 0.59 * g1 + 0.11 * b1
                        local l2 = 0.3 * r2 + 0.59 * g2 + 0.11 * b2
                        local d = l2 - l1
                        local gr = l1 * 0.55
                        if d > 0.012 then
                            n = n + 1
                            local ax = crop.x + x
                            if ax < sx0 then sx0 = ax end
                            if ax > sx1 then sx1 = ax end
                            if crop.y + y > sy1 then sy1 = crop.y + y end
                            sumX = sumX + ax
                            if d > peak then peak = d end
                            cell:setPixel(x, y, math.min(1, gr + d * 6), gr, gr, 1)
                        elseif d < -0.012 then
                            cell:setPixel(x, y, gr, gr, math.min(1, gr - d * 6), 1)
                        else
                            cell:setPixel(x, y, gr, gr, gr, 1)
                        end
                    end
                end
                local c = (i - 1) % cols
                local r = math.floor((i - 1) / cols)
                maskSheet:paste(cell, c * (mw + 6), r * (mh + 6), 0, 0, mw, mh)
                f.stats = { n = n, cx = n > 0 and (sumX / n - anchorX) or 0,
                    x0 = sx0 - anchorX, x1 = sx1 - anchorX, ybot = sy1 - anchorY, peak = peak }
                print(string.format("[revisao_monstros] %s | %-20s sombra px=%6d  centro=%+6.1f  x=[%+.0f,%+.0f] fundo=%+.0f pico=%.3f",
                    id, f.label, n, f.stats.cx, f.stats.x0, f.stats.x1, f.stats.ybot, peak))
                f.bare:release()
            end
            cell:release()
            maskSheet:encode("png", outDir .. "/" .. id .. "_sombra.png")
            maskSheet:release()
            local p1 = outDir .. "/" .. id .. ".png"
            local p2 = outDir .. "/" .. id .. "_pes.png"
            local sd = sheet:newImageData()
            sd:encode("png", p1)
            sd:release()
            local fd = feetSheet:newImageData()
            fd:encode("png", p2)
            fd:release()
            sheet:release(); feetSheet:release()
            for _, f in ipairs(frames) do f.data:release() end
            report[#report + 1] = id
            print("[revisao_monstros] " .. love.filesystem.getSaveDirectory() .. "/" .. p1)
        end
    end

    EnemyRenderer.draw = origDraw
    EnemyHud.layout = origLayout
    BossCinematic.bossAlpha = origBossAlpha
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    love.graphics.getDimensions = realDim
    love.mouse.getPosition = realMouse
    print("[revisao_monstros] ato " .. act .. ": " .. #report .. " inimigos")
    return true
end

return M
