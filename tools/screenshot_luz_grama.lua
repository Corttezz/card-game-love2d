local M = {}

local DT = 1 / 30

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

local function outDir(sub)
    local d = love.filesystem.getSource() .. "/tools/preview_out/luz_grama/" .. sub .. "/"
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

local function writePng(imageData, path)
    local fd = imageData:encode("png")
    local f = assert(io.open(path, "wb"))
    f:write(fd:getString())
    f:close()
    fd:release()
end

local function crop(cv, x, y, w, h, k, path)
    local W, H = cv:getDimensions()
    x = math.max(0, math.min(W - w, math.floor(x)))
    y = math.max(0, math.min(H - h, math.floor(y)))
    local out = love.graphics.newCanvas(w * k, h * k)
    out:setFilter("nearest", "nearest")
    local q = love.graphics.newQuad(x, y, w, h, W, H)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(out)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cv, q, 0, 0, 0, k, k)
    love.graphics.pop()
    local d = out:newImageData()
    writePng(d, path)
    d:release()
    out:release()
    q:release()
end

local function pools(VW, VH)
    local LE = require("engine.LightEngine")
    local list = {}
    for i = 1, LE.queued() do
        local e = LE._entryAt(i)
        if e and (e.sy or 1) < 0.6 and e.r > 20 and e.x > 0 and e.x < VW and e.y > 0 and e.y < VH * 0.97 then
            list[#list + 1] = { x = e.x, y = e.y, r = e.r, sy = e.sy }
        end
    end
    table.sort(list, function(a, b) return a.r > b.r end)
    return list
end

local function luma(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

local function measure(on, off, nog, p, VW, VH)
    local acc = {}
    local function bin(k)
        local t = acc[k]
        if not t then t = { n = 0, on = 0, off = 0, r = 0, g = 0, b = 0, ro = 0, go = 0, bo = 0 }; acc[k] = t end
        return t
    end
    local ry = p.r * p.sy
    local x0, x1 = math.max(0, math.floor(p.x - p.r * 1.6)), math.min(VW - 1, math.floor(p.x + p.r * 1.6))
    local y0, y1 = math.max(0, math.floor(p.y - ry * 1.6)), math.min(VH - 1, math.floor(p.y + ry * 1.6))
    for py = y0, y1 do
        for px = x0, x1 do
            local dx, dy = (px - p.x) / p.r, (py - p.y) / ry
            local d = math.sqrt(dx * dx + dy * dy)
            local ring = (d < 0.45 and "centro") or (d < 0.85 and "meio") or ((d > 1.15 and d < 1.6) and "fora") or nil
            if ring then
                local r1, g1, b1 = on:getPixel(px, py)
                local r0, g0, b0 = off:getPixel(px, py)
                local rn, gn, bn = nog:getPixel(px, py)
                local grass = math.abs(r1 - rn) + math.abs(g1 - gn) + math.abs(b1 - bn) > 6 / 255
                local t = bin((grass and "grama_" or "chao_") .. ring)
                t.n = t.n + 1
                t.on = t.on + luma(r1, g1, b1)
                t.off = t.off + luma(r0, g0, b0)
                t.r, t.g, t.b = t.r + r1, t.g + g1, t.b + b1
                t.ro, t.go, t.bo = t.ro + r0, t.go + g0, t.bo + b0
            end
        end
    end
    local lines = {}
    for _, k in ipairs({ "grama_centro", "grama_meio", "grama_fora", "chao_centro", "chao_meio", "chao_fora" }) do
        local t = acc[k]
        if t and t.n > 0 then
            local n = t.n
            lines[#lines + 1] = string.format(
                "%-13s n=%6d luz=%6.1f sem=%6.1f ganho=%+5.1f razao=%.2f rgb=(%3.0f,%3.0f,%3.0f) sem=(%3.0f,%3.0f,%3.0f)",
                k, n, t.on / n * 255, t.off / n * 255, (t.on - t.off) / n * 255, t.on / math.max(1e-6, t.off),
                t.r / n * 255, t.g / n * 255, t.b / n * 255, t.ro / n * 255, t.go / n * 255, t.bo / n * 255)
        end
    end
    return lines, acc
end

local function setupGame(act, VW, VH, seed, tod)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    require("src.ui.PixelCanvas").enableNearest()
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
    local floor = 7
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = floor
    run.currentNode = { type = "battle" }
    local sid = EnemyRenderer.resolveSpriteId(act, "battle")
    game.enemy = EnemyRoster.spawn(Enemy, sid, ActSystem.getEnemyStats(act, floor, "battle"))
    game.enemy.isBoss = false
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(VW * 0.8, VH * 0.8, 150, 46, "Jogar") })
    if game.messageSystem then game.messageSystem.messages = {} end
    WorldRoad._lastRect = nil
    WorldRoad.restoreProgress(act, floor)
    WorldRoad._rng:setSeed(seed)
    WorldRoad._props = {}
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    love.math.setRandomSeed(seed)
    WorldRoad.planStop(WorldRoad._camZ + WorldRoad.TRAVEL_DISTANCE, true)
    WorldRoad.setTimeOfDay(tod, true)
    return game, GameplayScene, EnemyRenderer, WorldRoad
end

function M.capture(act, VW, VH, dir, tag, tod, seed, travelSeq)
    local LE, Lum, GF = require("engine.LightEngine"), require("engine.LuminaireEngine"), require("engine.GrassField")
    local restore = patchDims(VW, VH)
    local realTime = love.timer.getTime
    local fakeT = 100
    love.timer.getTime = function() return fakeT end
    local cv = love.graphics.newCanvas(VW, VH)
    local game, GameplayScene, EnemyRenderer, WorldRoad = setupGame(act, VW, VH, seed, tod)
    local function render()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
        love.graphics.present()
    end
    local seq = {}
    local function step(n, cond)
        local i = 0
        while (n and i < n) or (cond and cond()) do
            i = i + 1
            fakeT = fakeT + DT
            WorldRoad.setTimeOfDay(tod, true)
            WorldRoad.update(DT)
            EnemyRenderer.update(DT)
            if i % 4 == 0 or travelSeq then render() end
            if travelSeq and cond and #seq < travelSeq.max and i % travelSeq.every == 0 then
                local pl = pools(VW, VH)[1]
                if pl then
                    local d = cv:newImageData()
                    seq[#seq + 1] = { img = love.graphics.newImage(d), p = pl }
                    d:release()
                end
            end
            if i % 30 == 0 then collectgarbage() end
            if i > 2000 then break end
        end
    end
    local result = {}
    local ok, err = pcall(function()
        step(20)
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
            onComplete = function() EnemyRenderer.triggerArrival() end,
        })
        step(nil, function() return WorldRoad.isTraveling() end)
        step(75)
        fakeT = 500
        render()
        local base = dir .. tag
        local onD = cv:newImageData()
        local list = pools(VW, VH)
        writePng(onD, base .. ".png")
        LE.debugNoLights, Lum.EMIT.on = true, false
        render()
        LE.debugNoLights, Lum.EMIT.on = false, true
        local offD = cv:newImageData()
        GF.disabled = true
        render()
        GF.disabled = false
        local nogD = cv:newImageData()
        fakeT = 500
        render()
        local k = VH / 1080
        for pi = 1, math.min(2, #list) do
            local p = list[pi]
            local lines = measure(onD, offD, nogD, p, VW, VH)
            result[#result + 1] = string.format("%s poca%d x=%.0f y=%.0f r=%.0f sy=%.2f", tag, pi, p.x, p.y, p.r, p.sy)
            for _, l in ipairs(lines) do result[#result + 1] = "  " .. l end
            local w3, h3 = math.floor(math.min(VW * 0.3, p.r * 2.2)), math.floor(math.max(120 * k, p.r * p.sy * 3.2 + 160 * k))
            crop(cv, p.x - w3 / 2, p.y - h3 + p.r * p.sy * 1.4, w3, h3, 3, string.format("%s_poste%d_3x.png", base, pi))
            local offImg = love.graphics.newImage(offD)
            crop(offImg, p.x - w3 / 2, p.y - h3 + p.r * p.sy * 1.4, w3, h3, 3, string.format("%s_poste%d_3x_semluz.png", base, pi))
            offImg:release()
        end
        if #list == 0 then result[#result + 1] = tag .. " sem poca no quadro" end
        onD:release(); offD:release(); nogD:release()
    end)
    if ok and travelSeq then
        local ok2, err2 = pcall(function()
            local nn = 0
            local function travelOnce()
                WorldRoad.travel({ onComplete = function() end })
                step(nil, function() return WorldRoad.isTraveling() end)
            end
            for _ = 1, 3 do
                if #seq >= travelSeq.max then break end
                travelOnce()
                nn = nn + 1
            end
            local k = VH / 1080
            local cw, ch = math.floor(260 * k), math.floor(200 * k)
            local cols = 4
            local rows = math.ceil(#seq / cols)
            if #seq > 0 then
                local sheet = love.graphics.newCanvas(cw * 2 * cols, ch * 2 * rows)
                love.graphics.push("all")
                love.graphics.setCanvas(sheet)
                love.graphics.clear(0, 0, 0, 1)
                love.graphics.setBlendMode("replace")
                for i, s in ipairs(seq) do
                    local cx = math.max(0, math.min(VW - cw, s.p.x - cw / 2))
                    local cy = math.max(0, math.min(VH - ch, s.p.y - ch * 0.7))
                    local q = love.graphics.newQuad(cx, cy, cw, ch, VW, VH)
                    s.img:setFilter("nearest", "nearest")
                    love.graphics.draw(s.img, q, ((i - 1) % cols) * cw * 2, math.floor((i - 1) / cols) * ch * 2, 0, 2, 2)
                    q:release()
                end
                love.graphics.pop()
                local d = sheet:newImageData()
                writePng(d, dir .. tag .. "_viagem_seq.png")
                d:release()
                sheet:release()
            end
            result[#result + 1] = string.format("%s viagem: %d quadros com poca", tag, #seq)
        end)
        if not ok2 then ok, err = false, err2 end
    end
    for _, s in ipairs(seq) do s.img:release() end
    love.timer.getTime = realTime
    restore()
    cv:release()
    collectgarbage()
    if not ok then error(err) end
    return result
end

function M.run(arg)
    io.stdout:setvbuf("line")
    local label, acts = (arg or ""):match("^([%w_]*):?([%d,]*)$")
    label = (label and label ~= "") and label or "depois"
    local actList = {}
    for a in (acts or ""):gmatch("%d") do actList[#actList + 1] = tonumber(a) end
    if #actList == 0 then actList = { 1, 2, 3, 4, 5, 6 } end
    local tod = tonumber(os.getenv("LUZ_TOD") or "") or 0.9
    local seeds = { 0xC0FFEE, 0xBEEF01, 0x51DE, 0x7A11, 0x3E3E }
    local travel = os.getenv("LUZ_VIAGEM") == "1"
    require("engine.LightSpill").on = os.getenv("LUZ_SPILL") ~= "0"
    local dir = outDir(label)
    local all = {}
    for _, act in ipairs(actList) do
        local got
        for si, seed in ipairs(seeds) do
            local res = M.capture(act, 1920, 1080, dir, "ato" .. act, tod, seed,
                travel and { max = 16, every = 6 } or nil)
            if not (res[1] or ""):find("sem poca") then got = res; break end
            got = res
        end
        for _, l in ipairs(got) do all[#all + 1] = l; print("[ok] " .. l) end
    end
    local f = io.open(dir .. "medidas.txt", "w")
    if f then f:write(table.concat(all, "\n"), "\n"); f:close() end
    print("[ok] " .. dir .. "medidas.txt")
    return true
end

return M
