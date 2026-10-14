local M = {}

function M.run()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()

    local W = tonumber(os.getenv("BOOT_W")) or 960
    local H = tonumber(os.getenv("BOOT_H")) or 540
    local canvas = love.graphics.newCanvas(W, H)
    local realW, realH, realD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end

    local BootScene = require("src.scenes.BootScene")
    local done = false
    BootScene.init({ onComplete = function() done = true end })

    love.filesystem.createDirectory("boot_entry")
    local dt = 1 / 60
    local t = 0
    local frameEvery = 4
    local step = 0
    local nFrames = 0
    local maxInFlight = 0
    local sheet = {}
    local sheetAt = { 2.0, 2.3, 2.6, 2.9, 3.2, 3.5, 3.8, 4.1, 4.4, 4.8, 5.4, 6.2 }
    local sheetIdx = 1

    local function drawFrame()
        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        BootScene.draw()
        love.graphics.pop()
    end

    while not done and t < 16 do
        _G.EventManager.update(dt)
        BootScene.update(dt)
        t = t + dt
        step = step + 1
        maxInFlight = math.max(maxInFlight, BootScene.cardsInFlight())
        local st = BootScene.splashTime()
        local inWindow = BootScene.phase() == "splash" and st >= 1.6
        if inWindow and step % frameEvery == 0 then
            drawFrame()
            nFrames = nFrames + 1
            canvas:newImageData():encode("png", ("boot_entry/frame_%03d.png"):format(nFrames))
        end
        if sheetIdx <= #sheetAt and st >= sheetAt[sheetIdx] then
            drawFrame()
            sheet[#sheet + 1] = { t = st, img = canvas:newImageData() }
            sheetIdx = sheetIdx + 1
        end
    end

    if #sheet > 0 then
        local tw, th = math.floor(W / 2), math.floor(H / 2)
        local cols = 4
        local rows = math.ceil(#sheet / cols)
        local out = love.graphics.newCanvas(tw * cols, th * rows)
        love.graphics.push("all")
        love.graphics.setCanvas(out)
        love.graphics.clear(0.05, 0.04, 0.03, 1)
        local font = require("src.ui.FontManager").getFont(12)
        love.graphics.setFont(font)
        for i, sh in ipairs(sheet) do
            local img = love.graphics.newImage(sh.img)
            local cx = ((i - 1) % cols) * tw
            local cy = math.floor((i - 1) / cols) * th
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, cx, cy, 0, 0.5, 0.5)
            love.graphics.setColor(1, 0.9, 0.6, 1)
            love.graphics.print(("t=%.1f"):format(sh.t), cx + 6, cy + 6)
        end
        love.graphics.pop()
        out:newImageData():encode("png", "boot_entry_sheet.png")
    end
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = realW, realH, realD
    print(("[boot_entry] semente %s · %d quadros · pico de %d cartas no ar · fim em %.2fs · %s"):format(
        tostring(BootScene.seed()), nFrames, maxInFlight, t, love.filesystem.getSaveDirectory()))
    return done
end

return M
