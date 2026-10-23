local M = {}

M.DEMO = {
    frost_wight = { fx = {
        { kind = "frost", xr = 0.45, yr = 0.10, rate = 1.0, spread = 0.5 },
        { kind = "mist", xr = 0.45, yr = 0.93, rate = 1.0, spread = 0.7 },
        { kind = "glint", xr = 0.50, yr = 0.35, rate = 1.0, spread = 0.3 },
    } },
}

M.FIXTURE_CLIP = "fidget_prova"

local function writeFixture(id)
    local base = "assets/sprites/characters/enemies/" .. id .. "/animations/"
    local dir = base .. "idle/south"
    local idle = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local n = tonumber(f:match("^(%d+)%.png$"))
        if n then idle[#idle + 1] = n end
    end
    table.sort(idle)
    local seq = {}
    for i = 1, #idle do seq[#seq + 1] = idle[i] end
    for i = #idle - 1, 1, -1 do seq[#seq + 1] = idle[i] end
    local out = base .. M.FIXTURE_CLIP .. "/south"
    love.filesystem.createDirectory(out)
    local written = {}
    for i, n in ipairs(seq) do
        local p = out .. "/" .. (i - 1) .. ".png"
        love.image.newImageData(dir .. "/" .. n .. ".png"):encode("png", p)
        written[#written + 1] = p
    end
    return written
end

local function removeFixture(id, written)
    for _, p in ipairs(written) do love.filesystem.remove(p) end
    local base = "assets/sprites/characters/enemies/" .. id .. "/animations/" .. M.FIXTURE_CLIP
    love.filesystem.remove(base .. "/south")
    love.filesystem.remove(base)
end

function M.run()
    local vw, vh = (os.getenv("VIDA_VIRTUAL") or "1920x1080"):match("^(%d+)x(%d+)$")
    vw, vh = tonumber(vw), tonumber(vh)
    local vcanvas = love.graphics.newCanvas(vw, vh)
    vcanvas:setFilter("nearest", "nearest")
    love.graphics.getWidth = function() return vw end
    love.graphics.getHeight = function() return vh end
    love.graphics.getDimensions = function() return vw, vh end

    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false

    local Vida = require("tools.vida")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyLife = require("src.ui.EnemyLife")
    local ER = require("src.ui.EnemyRenderer")
    local list = Vida.roster()
    local ids = {}
    for id in (os.getenv("VIDA_IDS") or "ember_imp,bog_ghoul,frost_wight"):gmatch("[%w_]+") do ids[#ids + 1] = id end
    local useFixture = os.getenv("VIDA_FIXTURE") == "1"
    local outDir = "vida_idle/runtime"
    love.filesystem.createDirectory(outDir)
    local tag = vw .. "x" .. vh
    local stTag = (os.getenv("VIDA_STATES") or ""):gsub("[^%a_]+", "-")
    if stTag ~= "" then tag = tag .. "_estado-" .. stTag end

    for _, id in ipairs(ids) do
        local entry = list[Vida.indexOf(list, id) or 1]
        local ldata = EnemyLife.load(id)
        local data = ldata or M.DEMO[id]
        local fixture = nil
        local fidgetName = data and data.fidgets and data.fidgets[1] and data.fidgets[1].clip
        if useFixture and not fidgetName then
            fixture = writeFixture(id)
            require("src.ui.SpriteAnimation").clearCache()
            local d = { fidgets = { { clip = M.FIXTURE_CLIP, fps = 8, weight = 1 } }, gap = { 60, 60 }, fx = data and data.fx }
            data = d
            fidgetName = M.FIXTURE_CLIP
        end
        local function draw()
            love.graphics.setCanvas(vcanvas)
            love.graphics.clear(0, 0, 0, 1)
            GameplayScene.draw()
            love.graphics.setCanvas()
        end
        Vida.mount(entry)
        if data then
            EnemyLife._setData(id, data)
            EnemyLife.prewarmNow(id)
        end
        local stEnv = os.getenv("VIDA_STATES")
        if stEnv and stEnv ~= "" then
            local list = {}
            for n in stEnv:gmatch("[%a_]+") do list[#list + 1] = n end
            EnemyLife.States.force(list)
        end
        for _ = 1, 120 do Vida.step(1 / 60, entry); draw() end
        local foot = ER.getLastFoot()
        local ux = foot.ux or 1
        local sx = (foot.tx or 0) + foot.drawX * ux
        local sy = (foot.ty or 0) + foot.drawY * (foot.uy or 1)
        local bw, bh = foot.iw * foot.scale * ux, foot.ih * foot.scale * (foot.uy or 1)
        local m = 50
        local cx0 = math.max(0, math.floor(sx - m))
        local cy0 = math.max(0, math.floor(sy - m))
        local cw = math.min(vw - cx0, math.floor(bw + 2 * m))
        local ch = math.min(vh - cy0, math.floor(bh + m + 30))
        local frames, labels = {}, {}
        local full = nil
        for f = 0, 59 do
            if f == 10 and fidgetName then EnemyLife.force(1) end
            for _ = 1, 6 do Vida.step(1 / 60, entry); draw() end
            local img = vcanvas:newImageData()
            if f == 0 then full = img end
            local crop = love.image.newImageData(cw, ch)
            crop:paste(img, 0, 0, cx0, cy0, cw, ch)
            frames[#frames + 1] = crop
            labels[#labels + 1] = ER.debugState().animName
        end
        full:encode("png", outDir .. "/" .. id .. "_" .. tag .. "_full.png")
        EnemyLife.fxEnabled = false
        draw()
        local off = vcanvas:newImageData()
        EnemyLife.fxEnabled = true
        draw()
        local on = vcanvas:newImageData()
        local diff = love.image.newImageData(cw * 3, ch * 3)
        local nd, lsum = 0, 0
        for y = 0, ch - 1 do
            for x = 0, cw - 1 do
                local r1, g1, b1 = on:getPixel(cx0 + x, cy0 + y)
                local r0, g0, b0 = off:getPixel(cx0 + x, cy0 + y)
                local d = math.abs(r1 - r0) + math.abs(g1 - g0) + math.abs(b1 - b0)
                local r, g, b = r0 * 0.25, g0 * 0.25, b0 * 0.25
                if d > 0.02 then
                    nd = nd + 1
                    lsum = lsum + 0.299 * r1 + 0.587 * g1 + 0.114 * b1
                    r, g, b = r1, g1, b1
                end
                for yy = 0, 2 do for xx = 0, 2 do diff:setPixel(x * 3 + xx, y * 3 + yy, r, g, b, 1) end end
            end
        end
        diff:encode("png", outDir .. "/" .. id .. "_" .. tag .. "_fx_3x.png")
        print(string.format("[vida] %s %s pixels de fx %d  luma media %.2f", id, tag, nd, nd > 0 and lsum / nd or 0))
        local cols = 10
        local rows = math.ceil(#frames / cols)
        local sheet = love.image.newImageData(cw * cols, ch * rows)
        for i, c in ipairs(frames) do
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            sheet:paste(c, col * cw, row * ch, 0, 0, cw, ch)
        end
        sheet:encode("png", outDir .. "/" .. id .. "_" .. tag .. "_seq_1x.png")
        local pick = {}
        for i = 1, #frames, 5 do pick[#pick + 1] = i end
        local c2 = 6
        local r2 = math.ceil(#pick / c2)
        local big = love.image.newImageData(cw * 2 * c2, ch * 2 * r2)
        for j, i in ipairs(pick) do
            local src = frames[i]
            local ox, oy = ((j - 1) % c2) * cw * 2, math.floor((j - 1) / c2) * ch * 2
            for y = 0, ch - 1 do
                for x = 0, cw - 1 do
                    local r, g, b, a = src:getPixel(x, y)
                    big:setPixel(ox + 2 * x, oy + 2 * y, r, g, b, a)
                    big:setPixel(ox + 2 * x + 1, oy + 2 * y, r, g, b, a)
                    big:setPixel(ox + 2 * x, oy + 2 * y + 1, r, g, b, a)
                    big:setPixel(ox + 2 * x + 1, oy + 2 * y + 1, r, g, b, a)
                end
            end
        end
        big:encode("png", outDir .. "/" .. id .. "_" .. tag .. "_seq_2x.png")
        local summary = {}
        for i, l in ipairs(labels) do
            if l ~= labels[i - 1] then summary[#summary + 1] = string.format("%.1fs:%s", (i - 1) * 0.1, tostring(l)) end
        end
        print(string.format("[vida] %s %s clips %s  fx vivas %d  -> %s/%s_%s_*.png", id, tag,
            table.concat(summary, " "), EnemyLife.liveCount(), outDir, id, tag))
        if fixture then removeFixture(id, fixture) end
        EnemyLife.States.force(nil)
        EnemyLife._setData(id, nil)
    end
    love.event.quit()
    return true
end

return M
