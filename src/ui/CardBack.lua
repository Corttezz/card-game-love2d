local Palette  = require("src.ui.Palette")
local CardMesh = require("src.ui.CardMesh")

local BACK_PATH = "assets/cards/back.png"

local CardBack = {}

local _img
local _triedLoad = false

local CORNER_RADIUS = 5

local function roundCorners(imgData, r)
    local w, h = imgData:getWidth(), imgData:getHeight()
    local cx = { r, w - 1 - r, r,         w - 1 - r }
    local cy = { r, r,         h - 1 - r, h - 1 - r }
    local boxX = { 0, w - r, 0,     w - r }
    local boxY = { 0, 0,     h - r, h - r }
    local r2 = r * r
    for i = 1, 4 do
        for x = boxX[i], boxX[i] + r - 1 do
            for y = boxY[i], boxY[i] + r - 1 do
                local dx = x - cx[i]
                local dy = y - cy[i]
                if dx * dx + dy * dy > r2 then
                    imgData:setPixel(x, y, 0, 0, 0, 0)
                end
            end
        end
    end
end

local function loadBackImage()
    if _triedLoad then return _img end
    _triedLoad = true
    if not love.filesystem.getInfo(BACK_PATH) then return nil end

    local okData, imgData = pcall(love.image.newImageData, BACK_PATH)
    if not okData or not imgData then
        local ok, img = pcall(love.graphics.newImage, BACK_PATH)
        if ok and img then img:setFilter("nearest", "nearest"); _img = img end
        return _img
    end

    roundCorners(imgData, CORNER_RADIUS)

    local ok, img = pcall(love.graphics.newImage, imgData)
    if ok and img then
        img:setFilter("nearest", "nearest")
        _img = img
    end
    return _img
end

function CardBack.getImage()
    return loadBackImage()
end

function CardBack.reload()
    _img = nil
    _triedLoad = false
end

local TILT_RANGE              = 0.15
local SHADOW_BASE_OFFSET_Y    = 6
local SHADOW_MAX_HORIZ_OFFSET = 20
local SHADOW_PRESS_SHIFT      = 14
local SHADOW_ALPHA            = 0.50
local BASE_LIFT               = 3

function CardBack.draw(x, y, w, h, opts)
    opts = opts or {}
    local alpha    = opts.alpha or 1
    local scale    = opts.scale or 1
    local rot      = opts.rot or 0
    local dissolve = opts.dissolve or 0

    local tiltX               = opts.tiltX or 0
    local tiltY               = opts.tiltY or 0
    local hoverStrength       = opts.hoverStrength or 0
    local liftOffset          = opts.liftOffset or 0
    local perspectiveRotation = opts.perspectiveRotation or 0

    if alpha <= 0 then return end
    local a = alpha * (1 - dissolve)
    if a <= 0 then return end

    local img = loadBackImage()
    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local sx = (w / iw) * scale
        local sy = (h / ih) * scale

        local mouseUV = {
            math.max(-1, math.min(1, tiltX / TILT_RANGE)),
            math.max(-1, math.min(1, tiltY / TILT_RANGE)),
        }

        local totalLift = liftOffset - BASE_LIFT

        local screenW = love.graphics.getWidth()
        local cardCxAbs = x
        local dirX = math.max(-1, math.min(1, (cardCxAbs - screenW / 2) / (screenW / 2)))
        local shadowOffsetX = -dirX * SHADOW_MAX_HORIZ_OFFSET
                            - mouseUV[1] * SHADOW_PRESS_SHIFT * hoverStrength
        local liftMag = math.abs(liftOffset) + BASE_LIFT
        local shadowOffsetY = SHADOW_BASE_OFFSET_Y + liftMag * 0.5
                            - mouseUV[2] * SHADOW_PRESS_SHIFT * hoverStrength * 0.7
        local shadowAlpha = (SHADOW_ALPHA + liftMag * 0.003) * a
        if shadowAlpha > 0.85 then shadowAlpha = 0.85 end

        love.graphics.push()
        love.graphics.translate(x, y + totalLift)
        love.graphics.rotate(rot + perspectiveRotation)
        love.graphics.scale(sx, sy)

        local drawX = -iw / 2
        local drawY = -ih / 2

        local shader = CardMesh.getShader()
        local timeNow = love.timer.getTime()

        if shader then
            local mesh = CardMesh.getMesh(iw, ih)
            mesh:setTexture(img)
            love.graphics.setShader(shader)
            CardMesh.setUniforms(shader, mouseUV, hoverStrength, timeNow, img)
            love.graphics.setColor(0, 0, 0, shadowAlpha)
            love.graphics.draw(mesh, drawX + shadowOffsetX / sx, drawY + shadowOffsetY / sy)

            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(mesh, drawX, drawY)
            love.graphics.setShader()
        else
            love.graphics.setColor(0, 0, 0, shadowAlpha)
            love.graphics.draw(img, drawX + shadowOffsetX / sx, drawY + shadowOffsetY / sy)
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(img, drawX, drawY)
        end

        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rot)
    love.graphics.scale(scale, scale)

    local hw, hh = w / 2, h / 2

    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.rectangle("fill", -hw + 4, -hh + 4, w, h)

    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], a)
    love.graphics.rectangle("fill", -hw, -hh, w, h)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], a)
    love.graphics.rectangle("line", -hw, -hh, w, h)

    love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2], Palette.PARCHMENT_DARK[3], a)
    local cs = math.min(w, h) * 0.22
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", 0, -cs, cs, 0, 0, cs, -cs, 0)

    love.graphics.setLineWidth(1)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return CardBack
