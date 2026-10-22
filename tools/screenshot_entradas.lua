local M = {}

M.VW, M.VH = 1920, 1080
M.CELL_W, M.CELL_H = 480, 270
M.COLS, M.ROWS = 6, 2
M.FRACS = { 0.02, 0.30, 0.55, 0.70, 0.80, 0.88, 0.94, 0.985 }
M.AFTER = { 0.3, 0.9 }
M.CROP_W, M.CROP_H = 720, 640
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

local function cropInto(dst, src, cx, cy, dx)
    local W, H = M.CROP_W, M.CROP_H
    local x0 = math.floor(math.max(0, math.min(src:getWidth() - W, cx - W / 2)))
    local y0 = math.floor(math.max(0, math.min(src:getHeight() - H, cy - H * 0.82)))
    dst:paste(src, dx, 0, x0, y0, W, H)
end

function M.capture(entry, cv, small, font)
    local Entradas = require("tools.entradas")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local EE = require("src.ui.EnemyEntrance")
    local ER = require("src.ui.EnemyRenderer")
    local Shake = require("src.systems.ScreenShake")
    local CardParticles = require("src.systems.CardParticles")
    local UiScale = require("src.ui.UiScale")

    local ctx = Entradas.mount(entry, { dt = DT })
    local function draw()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        Shake.push()
        GameplayScene.draw()
        Shake.pop()
        UiScale.begin()
        CardParticles.draw()
        UiScale.finish()
        love.graphics.setCanvas()
    end
    draw()
    Entradas.startEntrance(ctx, DT)
    local info = EE.info()
    local total = info and info.total or WorldRoad.TRAVEL_DURATION
    local strip = love.image.newImageData(M.CELL_W * M.COLS, M.CELL_H * M.ROWS)
    local hand = love.image.newImageData(M.CROP_W * 3, M.CROP_H)
    local midDone = false
    local n = 0
    local function snap(label)
        if n >= M.COLS * M.ROWS then return end
        love.graphics.setCanvas(small)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        local r = WorldRoad._lastRect
        if M.CREST and r then
            local g = WorldRoad.domeGeom(r.x, r.y, r.w, r.h)
            love.graphics.draw(cv, -math.floor(g.cx - M.CELL_W / 2), -math.floor(g.crestApexY + (M.CROP_DY or 0) - M.CELL_H * 0.45))
        else
            love.graphics.draw(cv, 0, 0, 0, M.CELL_W / M.VW, M.CELL_H / M.VH)
        end
        love.graphics.setFont(font)
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, font:getWidth(label) + 10, font:getHeight() + 6)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(label, 5, 3)
        love.graphics.setCanvas()
        local sd = small:newImageData()
        strip:paste(sd, (n % M.COLS) * M.CELL_W, math.floor(n / M.COLS) * M.CELL_H, 0, 0, M.CELL_W, M.CELL_H)
        sd:release()
        n = n + 1
    end
    local elapsed = 0
    local fi = 1
    local firstBattleAt = nil
    local afterI = 1
    local lastFoot = nil
    local guard = 0
    while n < M.COLS * M.ROWS and guard < 900 do
        guard = guard + 1
        local wasTraveling = WorldRoad.isTraveling()
        GameplayScene.update(DT)
        if _G.EventManager and _G.EventManager.update then _G.EventManager.update(DT) end
        Shake.update(DT)
        CardParticles.update(DT)
        elapsed = elapsed + DT
        draw()
        local tr = WorldRoad._travel
        local S = EE.state()
        if S and S.footX then lastFoot = { x = S.footX, y = S.footY } end
        local lastEnc = tr ~= nil and (tr.t + DT >= tr.duration + (tr.settle or 0) - 1e-6)
        local firstBattle = wasTraveling and not WorldRoad.isTraveling()
        local ph = Entradas.phase()
        if not midDone and elapsed >= 0.80 * total then
            midDone = true
            local full = cv:newImageData()
            local f = lastFoot or { x = M.VW / 2, y = M.VH * 0.6 }
            cropInto(hand, full, f.x, f.y, 0)
            full:release()
        end
        if lastEnc and fi <= #M.FRACS + 1 then
            fi = #M.FRACS + 2
            snap(string.format("%.2fs fim da viagem (ultimo quadro do encontro)", elapsed))
            local full = cv:newImageData()
            local f = lastFoot or { x = M.VW / 2, y = M.VH * 0.6 }
            cropInto(hand, full, f.x, f.y, M.CROP_W)
            full:release()
        elseif firstBattle then
            firstBattleAt = elapsed
            local lf = ER.getLastFoot()
            snap(string.format("%.2fs 1o quadro da batalha (idle %d)", elapsed, lf and lf.frame or 0))
            local full = cv:newImageData()
            local f = lastFoot or { x = M.VW / 2, y = M.VH * 0.6 }
            cropInto(hand, full, f.x, f.y, M.CROP_W * 2)
            full:release()
        elseif firstBattleAt and afterI <= #M.AFTER and elapsed >= firstBattleAt + M.AFTER[afterI] then
            afterI = afterI + 1
            snap(string.format("%.2fs %s", elapsed, ph))
        elseif not firstBattleAt and fi <= #M.FRACS and elapsed >= M.FRACS[fi] * total then
            fi = fi + 1
            snap(string.format("%.2fs %s", elapsed, ph))
        end
        if firstBattleAt and elapsed > firstBattleAt + 3 then break end
    end
    local anchorCrop = nil
    local ap = info and info.anchor
    if ap then
        for _, he in ipairs(WorldRoad._hitScene or {}) do
            if he.ref == ap then
                local bw, bh = he.x2 - he.x1, he.y2 - he.y1
                local x0 = math.floor(math.max(0, he.x1 - bw * 0.9))
                local y0 = math.floor(math.max(0, he.y1 - bh * 0.4))
                local x1 = math.floor(math.min(M.VW, he.x2 + bw * 0.9))
                local y1 = math.floor(math.min(M.VH, he.y2 + bh * 0.9))
                if x1 > x0 and y1 > y0 then
                    local full = cv:newImageData()
                    anchorCrop = love.image.newImageData(x1 - x0, y1 - y0)
                    anchorCrop:paste(full, 0, 0, x0, y0, x1 - x0, y1 - y0)
                    full:release()
                end
            end
        end
    end
    return strip, hand, info, anchorCrop
end

function M.run(arg)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()
    M.CREST = os.getenv("ENTRADAS_CREST") == "1"
    M.CROP_DY = tonumber(os.getenv("ENTRADAS_CROP_DY") or "") or 0
    local fr = os.getenv("ENTRADAS_FRACS")
    if fr and fr ~= "" then
        local list = {}
        for v in fr:gmatch("[%d%.]+") do list[#list + 1] = tonumber(v) end
        if #list > 0 then M.FRACS = list end
    end
    local rw, rh = (os.getenv("ENTRADAS_RES") or ""):match("^(%d+)x(%d+)$")
    if rw then M.VW, M.VH = tonumber(rw), tonumber(rh) end
    local Entradas = require("tools.entradas")
    local forcedTod = tonumber(os.getenv("ENTRADAS_TOD") or "")
    local WR = require("src.ui.WorldRoad")
    local origTod = WR.setTimeOfDay
    if forcedTod then
        M.TOD_TAG = "_tod" .. tostring(forcedTod)
        WR.setTimeOfDay = function(_, instant) return origTod(forcedTod, instant) end
    end
    local list = Entradas.roster()
    local sel = {}
    local actOnly = arg and arg:match("^ato(%d)$")
    for _, r in ipairs(list) do
        if not arg or arg == "" or r.id == arg or (actOnly and r.act == tonumber(actOnly)) then sel[#sel + 1] = r end
    end
    if #sel == 0 then
        print("[FAIL] criatura desconhecida: " .. tostring(arg))
        return false
    end
    local restore = patchDims(M.VW, M.VH)
    local vsync = love.window.getVSync()
    love.window.setVSync(0)
    local cv = love.graphics.newCanvas(M.VW, M.VH)
    local small = love.graphics.newCanvas(M.CELL_W, M.CELL_H)
    small:setFilter("linear", "linear")
    local font = require("src.ui.FontManager").getFont(12)
    local sheets = {}
    local okAll = true
    for _, r in ipairs(sel) do
        local ok, strip, hand, info, anchorCrop = pcall(M.capture, r, cv, small, font)
        if not ok then
            okAll = false
            print("[FAIL] " .. r.id .. ": " .. tostring(strip))
        else
            local dir = "entradas/ato" .. r.act
            love.filesystem.createDirectory(dir)
            strip:encode("png", dir .. "/" .. r.id .. ".png")
            hand:encode("png", dir .. "/" .. r.id .. "_handoff.png")
            if anchorCrop then
                anchorCrop:encode("png", dir .. "/" .. r.id .. "_ancora" .. (M.TOD_TAG or "") .. ".png")
                anchorCrop:release()
            end
            hand:release()
            sheets[r.act] = sheets[r.act] or {}
            table.insert(sheets[r.act], strip)
            local used = {}
            for k in pairs(info and info.used or {}) do used[#used + 1] = k end
            table.sort(used)
            print(string.format("[ok] %s/%s.png  %s  total %.2fs  clipes usados: %s", dir, r.id,
                info and info.kind or "?", info and info.total or 0, #used > 0 and table.concat(used, ",") or "idle"))
        end
        collectgarbage()
    end
    for act, strips in pairs(sheets) do
        local sheet = love.image.newImageData(M.CELL_W * M.COLS, M.CELL_H * M.ROWS * #strips)
        for i, s in ipairs(strips) do
            sheet:paste(s, 0, (i - 1) * M.CELL_H * M.ROWS, 0, 0, s:getWidth(), s:getHeight())
            s:release()
        end
        sheet:encode("png", "entradas/ato" .. act .. "/folha.png")
        sheet:release()
        print(string.format("[ok] entradas/ato%d/folha.png (%d criaturas)", act, #strips))
    end
    cv:release()
    small:release()
    WR.setTimeOfDay = origTod
    restore()
    love.window.setVSync(vsync)
    print(string.format("TOTAL %d criaturas capturadas em %s", #sel, love.filesystem.getSaveDirectory() .. "/entradas"))
    return okAll
end

return M
