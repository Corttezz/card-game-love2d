local Palette = require("src.ui.Palette")

local CursorManager = {}

local images = {}
local want = "arrow"
local loaded = false

local COLORS = {
    I = Palette.INK,
    B = Palette.PARCHMENT_LIGHT,
    L = { 1.0, 0.957, 0.839 },
    D = { 0.659, 0.541, 0.306 },
    G = Palette.AGED_GOLD,
}

local ARROW = {
    "........................",
    "..I.....................",
    ".ILI....................",
    ".ILLI...................",
    ".ILBLI..................",
    ".ILBBLI.................",
    ".ILBBBLI................",
    ".ILBBBBLI...............",
    ".ILBBBBBLI..............",
    ".ILBBBBBBLI.............",
    ".ILBBBBBBBLI............",
    ".ILBBBBBBBBLI...........",
    ".ILBBBBBBBBBLI..........",
    ".ILBBBBBBBBBBLI.........",
    ".ILBBBBBBBDDDDLI........",
    ".ILBBBDBBDIIIII.........",
    ".ILBBDILBBLI............",
    ".ILBDI.ILBDI............",
    ".ILDI..ILBDI............",
    ".ILI...ILBBLI...........",
    "..I.....ILBDI...........",
    "........ILBDLI..........",
    ".........ILII...........",
    "..........I.............",
    "........................",
    "........................",
}

local HAND = {
    "........II..............",
    ".......ILBI.............",
    ".......ILBDI............",
    ".......ILBDI............",
    ".......ILBDI............",
    ".......ILBDI............",
    ".......ILBDI............",
    ".......ILBDIIIIIIIII....",
    ".......ILBIBBDIIBBDI....",
    "......ILBBBBBBBBBBBBDI..",
    ".....ILBBBBBBBBBBBBBBDI.",
    ".....ILBDBBBBBBBBBBBBDI.",
    ".....ILBBDBBBBBBBBBBBDI.",
    ".....ILBBBDBBBBBBBBBBDI.",
    "......ILBBBBBBBBBBBBDI..",
    "......ILBBBBBBBBBBBBDI..",
    ".....IIIIIIIIIIIIIIIIII.",
    "....ILGGGGGGGGGGGGGGGGDI",
    "....ILGLGGGGLGGGGLGGGGDI",
    "....ILDDDDDDDDDDDDDDDDDI",
    ".....IIIIIIIIIIIIIIIIII.",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
}

local function buildImage(matrix)
    local h = #matrix
    local wdt = #matrix[1]
    local data = love.image.newImageData(wdt, h)
    for y = 1, h do
        local row = matrix[y]
        for x = 1, wdt do
            local ch = row:sub(x, x)
            local c = COLORS[ch]
            if c then
                data:setPixel(x - 1, y - 1, c[1], c[2], c[3], 1)
            end
        end
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img
end

local function loadPng(path)
    if not love.filesystem.getInfo(path) then return nil end
    local ok, data = pcall(love.image.newImageData, path)
    if not ok or not data then return nil end
    local w, h = data:getWidth(), data:getHeight()
    local hx, hy = math.floor(w / 2), 0
    for y = 0, h - 1 do
        local minX, maxX = nil, nil
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.5 then
                minX = minX or x
                maxX = x
            end
        end
        if minX then
            hx, hy = math.floor((minX + maxX) / 2), y
            break
        end
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return { img = img, hx = hx, hy = hy }
end

function CursorManager.load()
    if loaded then return end
    images.arrow = { img = buildImage(ARROW), hx = 2, hy = 1 }
    love.mouse.setVisible(false)
    loaded = true
end

function CursorManager.request(name)
    if images[name] then want = name end
end

function CursorManager.draw()
    if not loaded then return end
    if require("src.ui.NavCursor").isActive() then return end
    if love.window and love.window.hasMouseFocus
       and not love.window.hasMouseFocus() then
        want = "arrow"
        return
    end
    local mx, my = love.mouse.getPosition()
    local spec = images[want] or images.arrow
    want = "arrow"
    local s = math.max(1, math.floor(love.graphics.getHeight() / 256 + 0.5) / 2)
    local pressed = love.mouse.isDown(1)
    local off = pressed and s or 0
    local k = pressed and 0.86 or 1
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.draw(spec.img, math.floor(mx - spec.hx * s + s + off),
        math.floor(my - spec.hy * s + s + off), 0, s, s)
    love.graphics.setColor(k, k, k, 1)
    love.graphics.draw(spec.img, math.floor(mx - spec.hx * s + off),
        math.floor(my - spec.hy * s + off), 0, s, s)
    love.graphics.setColor(1, 1, 1, 1)
end

return CursorManager
