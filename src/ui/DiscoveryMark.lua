local Debug = require("src.core.Debug")

local Palette = require("src.ui.Palette")
local PixelFont = require("src.ui.PixelFont")
local CardMesh = require("src.ui.CardMesh")

local DiscoveryMark = {}

DiscoveryMark.SWEEP_DUR = 0.75
DiscoveryMark.SWEEP_DELAY = 0.12
DiscoveryMark.RESWEEP_EVERY = 5.5
DiscoveryMark.RESWEEP_STRENGTH = 0.45
DiscoveryMark.STAMP_DUR = 0.22
DiscoveryMark.CHIME_GAP = 0.3

local revealedAt = {}
local lastChimeAt, chimeRun = -math.huge, 0

DiscoveryMark.clock = love.timer.getTime
local function now() return DiscoveryMark.clock() end

local function reduced()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) == true
end

function DiscoveryMark.chime()
    local t = now()
    if t - lastChimeAt < DiscoveryMark.CHIME_GAP then return end
    chimeRun = (t - lastChimeAt < 1.5) and math.min(chimeRun + 1, 4) or 0
    lastChimeAt = t
    local Sfx = require("src.systems.Sfx")
    if not Sfx.has("cardDiscovered") then
        if _G.audioSystem and _G.audioSystem.sources and not DiscoveryMark._warned then
            DiscoveryMark._warned = true
            Debug.warn("[DiscoveryMark] som cardDiscovered não registrado")
        end
        return
    end
    Sfx.play("cardDiscovered", { pitch = 1 + chimeRun * 0.06 })
end

function DiscoveryMark.reveal(key, silent)
    local t0 = revealedAt[key]
    if not t0 then
        t0 = now()
        revealedAt[key] = t0
        if not silent then DiscoveryMark.chime() end
    end
    return now() - t0
end

function DiscoveryMark.reset()
    revealedAt = {}
    lastChimeAt, chimeRun = -math.huge, 0
end

local shader, shaderTried
local function getShader()
    if shaderTried then return shader end
    shaderTried = true
    local ok, s = pcall(love.graphics.newShader, "shaders/discovery_sweep.glsl")
    if ok then shader = s else Debug.warn("[DiscoveryMark] shader falhou: " .. tostring(s)) end
    return shader
end

local TINT = { Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3] }

function DiscoveryMark.sweepAt(t, w, h, once)
    local dur = DiscoveryMark.SWEEP_DUR
    local span = w + h * 0.5 + 24
    local tt = t - DiscoveryMark.SWEEP_DELAY
    if tt < 0 then return 0, 0 end
    local strength = 1
    if tt >= dur then
        if once then return 0, 0 end
        tt = (tt - dur) % DiscoveryMark.RESWEEP_EVERY - (DiscoveryMark.RESWEEP_EVERY - dur)
        if tt < 0 then return 0, 0 end
        strength = DiscoveryMark.RESWEEP_STRENGTH
    end
    local p = tt / dur
    p = p * p * (3 - 2 * p)
    return strength, math.floor(-12 + p * span)
end

function DiscoveryMark.drawSweep(image, x, y, sx, t, alpha, once, warp)
    if reduced() then return end
    local w, h = image:getWidth(), image:getHeight()
    local strength, pos = DiscoveryMark.sweepAt(t, w, h, once)
    if strength <= 0 then return end
    local sh = getShader()
    if not sh then return end
    local mesh = CardMesh.getMesh(w, h)
    mesh:setTexture(image)
    local mode, amode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    love.graphics.setShader(sh)
    sh:send("mouse", warp and warp[1] or { 0, 0 })
    sh:send("hover", warp and warp[2] or 0)
    sh:send("time", warp and warp[3] or 0)
    sh:send("cardSize", { w, h })
    sh:send("sweep", pos)
    sh:send("strength", strength * 0.85)
    sh:send("tint", TINT)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(mesh, x, y, 0, sx or 1, sx or 1)
    love.graphics.setShader()
    love.graphics.setBlendMode(mode, amode)
    love.graphics.setColor(1, 1, 1, 1)
end

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a) end

function DiscoveryMark.drawBadge(x, y, w, t, alpha)
    alpha = alpha or 1
    if alpha <= 0.01 then return end
    local I18n = require("src.i18n.I18n")
    local label = I18n.t("unlocks.new_badge", nil, "NEW")
    local font = PixelFont.get(8)
    local tw = font:getWidth(label)
    local th = font:getHeight()
    local bw = tw + 14
    bw = bw + (bw % 2)
    local bh = th + 3
    local bx = x + math.floor((w - bw) / 2)
    local by = y - bh + 1
    local drop = 0
    if not reduced() and t < DiscoveryMark.STAMP_DUR then
        local p = t / DiscoveryMark.STAMP_DUR
        drop = math.floor((1 - p) * (1 - p) * 5 + 0.5)
        alpha = alpha * p
    end
    by = by - drop

    love.graphics.push("all")
    setc(Palette.INK, 0.55 * alpha)
    love.graphics.rectangle("fill", bx + 1, by + 1, bw, bh)
    setc(Palette.INK, alpha)
    love.graphics.rectangle("fill", bx, by, bw, bh)
    setc(Palette.BLOOD, alpha)
    love.graphics.rectangle("fill", bx + 1, by + 1, bw - 2, bh - 2)
    setc(Palette.AGED_GOLD_LIGHT, alpha)
    love.graphics.rectangle("fill", bx + 1, by + 1, bw - 2, 1)
    setc(Palette.INK, alpha * 0.45)
    love.graphics.rectangle("fill", bx + 1, by + bh - 2, bw - 2, 1)
    local py = by + math.floor(bh / 2) - 1
    setc(Palette.AGED_GOLD_LIGHT, alpha)
    love.graphics.rectangle("fill", bx + 3, py, 2, 2)
    love.graphics.rectangle("fill", bx + bw - 5, py, 2, 2)
    love.graphics.setFont(font)
    setc(Palette.PARCHMENT_LIGHT, alpha)
    love.graphics.print(label, bx + 7, by + 2)
    love.graphics.pop()
end

function DiscoveryMark.drawOnCard(card, image, drawX, drawY, mouseUV, hover, timeNow)
    local alpha = 1
    if card.dissolve and card.dissolve > 0.001 then
        if card.dissolve >= 0.2 then return end
        alpha = 1 - card.dissolve / 0.2
    end
    local t = DiscoveryMark.reveal(card.id)
    DiscoveryMark.drawSweep(image, drawX, drawY, 1, t, alpha, false,
        { mouseUV, hover, timeNow })
    DiscoveryMark.drawBadge(drawX, drawY, image:getWidth(), t, alpha)
end

function DiscoveryMark.drawAlert(cx, cy, size)
    local r = size or 9
    local x, y = math.floor(cx - r), math.floor(cy - r)
    local d = r * 2
    love.graphics.push("all")
    setc(Palette.INK, 0.6)
    love.graphics.rectangle("fill", x + 1, y + 2, d, d)
    setc(Palette.INK, 1)
    love.graphics.rectangle("fill", x, y + 2, d, d - 4)
    love.graphics.rectangle("fill", x + 2, y, d - 4, d)
    setc(Palette.BLOOD, 1)
    love.graphics.rectangle("fill", x + 1, y + 3, d - 2, d - 6)
    love.graphics.rectangle("fill", x + 3, y + 1, d - 6, d - 2)
    setc(Palette.AGED_GOLD_LIGHT, 1)
    love.graphics.rectangle("fill", x + 3, y + 1, d - 6, 1)
    local font = PixelFont.get(8)
    love.graphics.setFont(font)
    setc(Palette.PARCHMENT_LIGHT, 1)
    love.graphics.print("!", math.floor(cx - font:getWidth("!") / 2), math.floor(cy - font:getHeight() / 2) + 1)
    love.graphics.pop()
end

DiscoveryMark.PULSE_DUR = 1.1
function DiscoveryMark.drawCollectionPulse(key, image, x, y, s)
    local t = DiscoveryMark.reveal("collection:" .. key, true)
    if t > DiscoveryMark.PULSE_DUR + DiscoveryMark.SWEEP_DELAY then return false end
    DiscoveryMark.drawSweep(image, x, y, s, t, 1, true)
    local p = math.min(1, t / DiscoveryMark.PULSE_DUR)
    local a = math.sin(p * math.pi) * 0.9
    if a > 0.01 then
        local w, h = image:getWidth() * s, image:getHeight() * s
        local px = math.max(1, math.floor(s + 0.5))
        love.graphics.push("all")
        setc(Palette.AGED_GOLD_LIGHT, a)
        local g = px * 2
        love.graphics.rectangle("fill", x - g, y - g, w + g * 2, px)
        love.graphics.rectangle("fill", x - g, y + h + g - px, w + g * 2, px)
        love.graphics.rectangle("fill", x - g, y - g, px, h + g * 2)
        love.graphics.rectangle("fill", x + w + g - px, y - g, px, h + g * 2)
        love.graphics.pop()
    end
    return true
end

return DiscoveryMark
