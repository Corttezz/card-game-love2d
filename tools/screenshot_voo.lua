local M = {}

M.ANTES = "tools/preview_out/voo_tries/_antes_"
M.FPS = 12
M.FRAMES = 36

local function idlePath(id)
    return "assets/sprites/characters/enemies/" .. id .. "/animations/idle/south"
end

local function overlayAntes(id)
    local src = M.ANTES .. id
    if not love.filesystem.getInfo(src) then return nil end
    local dst = idlePath(id)
    love.filesystem.createDirectory(dst)
    local written = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(src)) do
        if f:match("^%d+%.png$") then
            local p = dst .. "/" .. f
            love.image.newImageData(src .. "/" .. f):encode("png", p)
            written[#written + 1] = p
        end
    end
    return written
end

local function removeOverlay(written)
    for _, p in ipairs(written or {}) do love.filesystem.remove(p) end
end

local function withoutDraft(data)
    if not data then return nil end
    local out = {}
    for k, v in pairs(data) do out[k] = v end
    if data.fx then
        out.fx = {}
        for _, e in ipairs(data.fx) do
            if e.kind ~= "downdraft" then out.fx[#out.fx + 1] = e end
        end
    end
    return out
end

function M.run()
    local vw, vh = (os.getenv("VOO_VIRTUAL") or "1920x1080"):match("^(%d+)x(%d+)$")
    vw, vh = tonumber(vw), tonumber(vh)
    local vcanvas = love.graphics.newCanvas(vw, vh)
    vcanvas:setFilter("nearest", "nearest")
    love.graphics.getWidth = function() return vw end
    love.graphics.getHeight = function() return vh end
    love.graphics.getDimensions = function() return vw, vh end
    local simT = 1000
    love.timer.getTime = function() return simT end

    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = os.getenv("VOO_REDUCED") == "1"

    local Vida = require("tools.vida")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyLife = require("src.ui.EnemyLife")
    local ER = require("src.ui.EnemyRenderer")
    local SpriteAnimation = require("src.ui.SpriteAnimation")
    local list = Vida.roster()
    local modes = {}
    for m in (os.getenv("VOO_MODES") or "antes,depois"):gmatch("[%a]+") do modes[#modes + 1] = m end
    local outDir = "voo"
    love.filesystem.createDirectory(outDir)

    local function step(dt, entry)
        simT = simT + dt
        Vida.step(dt, entry)
    end
    local function draw()
        love.graphics.setCanvas(vcanvas)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
    end

    for id in (os.getenv("VOO_IDS") or "carrion_king"):gmatch("[%w_]+") do
        local entry = list[Vida.indexOf(list, id) or 1]
        local box = nil
        for _, mode in ipairs(modes) do
            local written = nil
            if mode == "antes" then written = overlayAntes(id) end
            SpriteAnimation.clearCache()
            ER.clearCache()
            EnemyLife.clearCache()
            simT = 1000
            love.math.setRandomSeed(Vida.SEED)
            EnemyLife._rng:setSeed(0x51DE)
            Vida.mount(entry)
            local data = EnemyLife.load(id)
            if mode == "antes" then
                EnemyLife._setData(id, withoutDraft(data))
            end
            EnemyLife.enabled = false
            EnemyLife.prewarmNow(id)
            for _ = 1, 120 do step(1 / 60, entry); draw() end
            if not box then
                local foot = ER.getLastFoot()
                local ux, uy = foot.ux or 1, foot.uy or 1
                local sx = (foot.tx or 0) + foot.drawX * ux
                local sy = (foot.ty or 0) + foot.drawY * uy
                local bw, bh = foot.iw * foot.scale * ux, foot.ih * foot.scale * uy
                local gy = (foot.ty or 0) + (foot.groundY or (sy + bh)) * uy
                local m = 70
                local x0 = math.max(0, math.floor(sx - m))
                local y0 = math.max(0, math.floor(sy - 40))
                local x1 = math.min(vw, math.floor(sx + bw + m))
                local y1 = math.min(vh, math.floor(math.max(sy + bh, gy) + 40))
                box = { x0, y0, x1 - x0, y1 - y0 }
            end
            local per = math.max(1, math.floor(60 / M.FPS + 0.5))
            local hits = {}
            local yMin, yMax = math.huge, -math.huge
            for f = 0, M.FRAMES - 1 do
                local s0 = EnemyLife.strokeCount()
                for _ = 1, per do step(1 / 60, entry); draw() end
                if EnemyLife.strokeCount() > s0 then hits[#hits + 1] = tostring(f) end
                local dy = ER.getLastFoot().drawY
                if dy < yMin then yMin = dy end
                if dy > yMax then yMax = dy end
                local img = vcanvas:newImageData()
                if f == 0 then img:encode("png", outDir .. "/" .. id .. "_" .. mode .. "_full.png") end
                local crop = love.image.newImageData(box[3], box[4])
                crop:paste(img, 0, 0, box[1], box[2], box[3], box[4])
                crop:encode("png", string.format("%s/%s_%s_%02d.png", outDir, id, mode, f))
            end
            love.filesystem.write(string.format("%s/%s_%s_sopros.txt", outDir, id, mode), table.concat(hits, ","))
            print(string.format("[voo] %s %s %d quadros, caixa %d,%d %dx%d, drawY %.1f..%.1f, sopros %d -> %s/%s/",
                id, mode, M.FRAMES, box[1], box[2], box[3], box[4], yMin, yMax, #hits,
                love.filesystem.getSaveDirectory(), outDir))
            EnemyLife.enabled = true
            EnemyLife._setData(id, nil)
            removeOverlay(written)
        end
    end
    love.event.quit()
    return true
end

return M
