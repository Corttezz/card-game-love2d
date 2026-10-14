local M = {}

function M.run()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load()
    CRTShader.setPower(1)

    local realW, realH, realD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    local FontManager = require("src.ui.FontManager")
    local Menu = require("components.Menu")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = true

    local crops = {}
    for _, sz in ipairs({ { 1920, 1080 }, { 2560, 1440 } }) do
        local W, H = sz[1], sz[2]
        love.graphics.getWidth = function() return W end
        love.graphics.getHeight = function() return H end
        love.graphics.getDimensions = function() return W, H end
        FontManager.clearCache()
        local menu = Menu:new()
        menu:enterWithIntro()
        for _ = 1, 60 * 5 do _G.EventManager.update(1 / 60); menu:update(1 / 60) end
        for _, lv in ipairs(CRTShader.LEVELS) do
            CRTShader.setLevel(lv)
            local target = love.graphics.newCanvas(W, H)
            love.graphics.push("all")
            if lv == "off" then
                love.graphics.setCanvas(target)
                love.graphics.clear(0, 0, 0, 1)
                menu:draw()
            else
                CRTShader.beginScene()
                love.graphics.clear(0, 0, 0, 1)
                menu:draw()
                CRTShader.endScene(target)
            end
            love.graphics.pop()
            local data = target:newImageData()
            local name = ("crt_%s_%dx%d.png"):format(lv, W, H)
            data:encode("png", name)
            print("[crt_levels] " .. name)
            crops[#crops + 1] = { data = data, W = W, H = H, lv = lv,
                title = { x = math.floor(W / 2 - 330), y = math.floor(H * 0.22 - 70), w = 660, h = 140 },
                btn = { x = math.floor(W / 2 - 330), y = math.floor(H * 0.5 - 12), w = 660, h = 90 } }
            target:release()
        end
    end
    CRTShader.setLevel("normal")
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = realW, realH, realD
    FontManager.clearCache()

    local colW, rowH = 660, 150
    local sheet = love.graphics.newCanvas(colW * #crops, rowH * 2 + 20)
    love.graphics.push("all")
    love.graphics.setCanvas(sheet)
    love.graphics.clear(0.05, 0.04, 0.03, 1)
    local font = FontManager.getFont(10)
    love.graphics.setFont(font)
    for i, c in ipairs(crops) do
        local img = love.graphics.newImage(c.data)
        local x0 = (i - 1) * colW
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, love.graphics.newQuad(c.title.x, c.title.y, c.title.w, c.title.h, c.W, c.H), x0, 20)
        love.graphics.draw(img, love.graphics.newQuad(c.btn.x, c.btn.y, c.btn.w, c.btn.h, c.W, c.H), x0, 20 + rowH)
        love.graphics.setColor(1, 0.9, 0.6, 1)
        love.graphics.print(("%s %dx%d"):format(c.lv, c.W, c.H), x0 + 6, 4)
        img:release()
    end
    love.graphics.pop()
    sheet:newImageData():encode("png", "crt_levels_sheet.png")
    print("[crt_levels] crt_levels_sheet.png em " .. love.filesystem.getSaveDirectory())
    return true
end

return M
