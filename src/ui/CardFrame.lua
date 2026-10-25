local Debug = require("src.core.Debug")

local PixelCanvas      = require("src.ui.PixelCanvas")
local Palette          = require("src.ui.Palette")
local CardArt          = require("src.ui.CardArt")
local I18n             = require("src.i18n.I18n")
local IconFramesLoader = require("src.ui.IconFramesLoader")

local CardBorder      = require("src.ui.card.components.CardBorder")
local CardHeader      = require("src.ui.card.components.CardHeader")
local CardCostBadge   = require("src.ui.card.components.CardCostBadge")
local CardRaritySeal  = require("src.ui.card.components.CardRaritySeal")
local CardArtSlot     = require("src.ui.card.components.CardArtSlot")
local CardDecoration  = require("src.ui.card.components.CardDecoration")
local CardStatsFooter = require("src.ui.card.components.CardStatsFooter")

local JokerBorder = require("src.ui.card.components.joker.JokerBorder")
local JokerHeader = require("src.ui.card.components.joker.JokerHeader")
local JokerSeal   = require("src.ui.card.components.joker.JokerSeal")
local JokerMoon   = require("src.ui.card.components.joker.JokerMoon")
local JokerFooter = require("src.ui.card.components.joker.JokerFooter")

local CardFrame = {}

CardFrame.WIDTH  = 96
CardFrame.HEIGHT = 144

function CardFrame.showsManaCost(card)
    return card ~= nil and card.type ~= "joker"
end

function CardFrame.liveEnabled()
    local s = _G.gameSettings
    return not (s and s.reducedMotion)
end

function CardFrame.displayImage(card)
    if not card then return nil end
    if CardFrame.liveEnabled() then
        local live = CardFrame.liveImage(card)
        if live then return live end
    end
    return card.image
end

local cache = {}
local animCache = {}
local layerCache = {}

local _parchmentTex
local _parchmentLoaded = false
local function getParchmentTex()
    if _parchmentLoaded then return _parchmentTex end
    _parchmentLoaded = true
    local path = "assets/sprites/ui/parchment_texture.png"
    if love.filesystem.getInfo(path) then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            _parchmentTex = img
        end
    end
    return _parchmentTex
end

CardFrame.TOP_INSET = 3

local function artSlotBounds(card)
    local w, h = CardFrame.WIDTH, CardFrame.HEIGHT
    local headerH, footerH
    if card.type == "joker" then
        headerH = JokerHeader.HEIGHT
        footerH = JokerFooter.HEIGHT
    else
        headerH = CardHeader.computeHeight(card, w)
        footerH = CardStatsFooter.HEIGHT
    end
    local top    = headerH + CardFrame.TOP_INSET
    local bottom = h - footerH
    return 5, top, w - 10, bottom - top
end

function CardFrame.artSlotBounds(card)
    return artSlotBounds(card)
end

local BANNER_SHADOW_INSET = {
    common    = 3,
    uncommon  = 3,
    rare      = 0,
    legendary = 3,
}

local function drawRecessShadow(ax, ay, aw, ah, bannerX, bannerW, rarity)
    local inset = BANNER_SHADOW_INSET[rarity or "common"] or 0
    local tx = bannerX + inset
    local tw = bannerW - inset * 2
    Palette.set(Palette.INK, 0.38)
    love.graphics.rectangle("fill", tx, ay,     tw, 1)
    Palette.set(Palette.INK, 0.20)
    love.graphics.rectangle("fill", tx, ay + 1, tw, 1)

    Palette.set(Palette.INK, 0.32)
    love.graphics.rectangle("fill", ax, ay + ah - 1, aw, 1)
    Palette.set(Palette.INK, 0.16)
    love.graphics.rectangle("fill", ax, ay + ah - 2, aw, 1)

    Palette.set(Palette.INK, 0.26)
    love.graphics.rectangle("fill", ax,          ay + 2, 1, ah - 4)
    love.graphics.rectangle("fill", ax + aw - 1, ay + 2, 1, ah - 4)
    Palette.set(Palette.INK, 0.12)
    love.graphics.rectangle("fill", ax + 1,      ay + 2, 1, ah - 4)
    love.graphics.rectangle("fill", ax + aw - 2, ay + 2, 1, ah - 4)

    love.graphics.setColor(1, 1, 1, 1)
end

local function renderStandard(card, w, h, iconOverride, skipIcon)
    local rarity = card.rarity or "common"
    local art    = CardArt.resolve(card)
    local name   = I18n.cardName(card)

    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, "parchment",
        { iconOverride = iconOverride, clipTop = CardFrame.TOP_INSET, skipIcon = skipIcon })

    CardDecoration.draw(ax, ay, aw, ah, art.decoration, art.accent)
    local autoDec = CardDecoration.autoForBackground(art.bgPattern)
    if autoDec and autoDec ~= art.decoration then
        CardDecoration.draw(ax, ay, aw, ah, autoDec, art.accent)
    end

    drawRecessShadow(ax, ay, aw, ah, 15, w - 30, rarity)

    CardBorder.draw(w, h, card.type, rarity, card.id)
    CardHeader.draw(w, name, rarity)
    CardCostBadge.draw(card.cost or 0)
    CardRaritySeal.draw(w, rarity)
    CardStatsFooter.draw(w, h, card)
end

local function renderJoker(card, w, h, iconOverride, skipIcon)
    local rarity = card.rarity or "common"
    local art    = CardArt.resolve(card)
    local name   = I18n.cardName(card)

    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, "tarot",
        { iconOverride = iconOverride, clipTop = CardFrame.TOP_INSET, skipIcon = skipIcon })
    CardDecoration.draw(ax, ay, aw, ah, art.decoration or "flash", art.accent)
    local autoDec = CardDecoration.autoForBackground(art.bgPattern)
    if autoDec and autoDec ~= (art.decoration or "flash") then
        CardDecoration.draw(ax, ay, aw, ah, autoDec, art.accent)
    end

    drawRecessShadow(ax, ay, aw, ah, 13, w - 26, rarity)

    JokerBorder.draw(w, h, rarity)
    JokerHeader.draw(w, name, rarity)
    JokerMoon.draw()
    JokerSeal.draw(w, rarity)
    JokerFooter.draw(w, h)
end

local keyMemo = setmetatable({}, { __mode = "k" })
local function cacheKey(card)
    local up = card.upgrades or 0
    local m = keyMemo[card]
    if m and m.up == up then return m.key end
    local key = (card.id or (tostring(card.name) .. "_" .. tostring(card.type)))
        .. "+" .. tostring(up)
    keyMemo[card] = { key = key, up = up }
    return key
end

local function frameHandle(img)
    return {
        size = { w = img:getWidth(), h = img:getHeight() },
        draw = function(x, y, scale)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, x, y, 0, scale, scale)
        end,
    }
end

local function drawBase(card, w, h)
    local baseColor = (card.type == "joker") and (Palette.TAROT_CREAM or Palette.PARCHMENT_LIGHT)
                                              or Palette.PARCHMENT_LIGHT
    PixelCanvas.rect(0, 0, w, h, baseColor)

    local tex = getParchmentTex()
    if tex and card.type ~= "joker" then
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.draw(tex, 0, 0, 0, w / tex:getWidth(), h / tex:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end

end

local function drawChrome(card, w, h, iconOverride, skipIcon)
    if card.type == "joker" then
        renderJoker(card, w, h, iconOverride, skipIcon)
    else
        renderStandard(card, w, h, iconOverride, skipIcon)
    end

    if (card.upgrades or 0) > 0 then
        local lvl = card.upgrades
        local gems = math.min(lvl, 5)
        local gy = h - CardStatsFooter.HEIGHT - 7
        local gx = 7
        local GEM_HI  = { 0.62, 0.95, 0.55, 1 }
        local GEM_MID = { 0.30, 0.68, 0.30, 1 }
        local GEM_LO  = { 0.10, 0.32, 0.12, 1 }
        for i = 1, gems do
            local cxp = gx + (i - 1) * 6
            PixelCanvas.pixel(cxp,     gy - 1, GEM_HI)
            PixelCanvas.pixel(cxp - 1, gy,     GEM_MID)
            PixelCanvas.pixel(cxp,     gy,     GEM_HI)
            PixelCanvas.pixel(cxp + 1, gy,     GEM_LO)
            PixelCanvas.pixel(cxp,     gy + 1, GEM_LO)
        end
        if lvl > 5 then
            local FontManager = require("src.ui.FontManager")
            local f = FontManager.getFont(8)
            love.graphics.setFont(f)
            local tag = "x" .. tostring(lvl)
            love.graphics.setColor(0, 0, 0, 0.9)
            love.graphics.print(tag, gx + gems * 6 + 2, gy - 4)
            love.graphics.setColor(GEM_HI)
            love.graphics.print(tag, gx + gems * 6 + 1, gy - 5)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

end

local function cutCorners(w, h)
    local CORNER_CUT = 3
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(0, 0, 0, 0)
    for i = 0, CORNER_CUT - 1 do
        local rowLen = CORNER_CUT - i
        love.graphics.rectangle("fill", 0, i, rowLen, 1)
        love.graphics.rectangle("fill", w - rowLen, i, rowLen, 1)
        love.graphics.rectangle("fill", 0, h - 1 - i, rowLen, 1)
        love.graphics.rectangle("fill", w - rowLen, h - 1 - i, rowLen, 1)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)

end

local function renderOne(card, iconOverride)
    local w, h = CardFrame.WIDTH, CardFrame.HEIGHT
    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)
    drawBase(card, w, h)
    drawChrome(card, w, h, iconOverride, false)
    cutCorners(w, h)
    PixelCanvas.endDraw()
    return canvas
end

local function renderLayers(card)
    local w, h = CardFrame.WIDTH, CardFrame.HEIGHT
    local over = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(over, true)
    drawChrome(card, w, h, nil, true)
    PixelCanvas.endDraw()
    return { over = over }
end

local function composeFrame(card, layers, iconOverride)
    local w, h = CardFrame.WIDTH, CardFrame.HEIGHT
    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)
    drawBase(card, w, h)
    local art = CardArt.resolve(card)
    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, (card.type == "joker") and "tarot" or "parchment",
        { iconOverride = iconOverride, clipTop = CardFrame.TOP_INSET })
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(layers.over, 0, 0)
    love.graphics.setBlendMode("alpha")
    cutCorners(w, h)
    PixelCanvas.endDraw()
    return canvas
end

function CardFrame.render(card)
    local key = cacheKey(card)
    if cache[key] then return cache[key] end

    local art = CardArt.resolve(card)
    local first = art.iconName and IconFramesLoader.first(art.iconName)
    if first then
        local layers = renderLayers(card)
        layers.t = love.timer.getTime()
        layerCache[key] = layers
        cache[key] = composeFrame(card, layers, frameHandle(first))
        return cache[key]
    end

    cache[key] = renderOne(card)
    return cache[key]
end

local warned = {}

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    Debug.warn("[CardFrame] " .. msg .. " (" .. tostring(key) .. ")")
end

local function validSet(canvases)
    local n = #canvases
    if n == 0 then return false end
    for i = 1, n do
        if canvases[i] == nil then return false end
    end
    return true
end

local BUILD_PER_FRAME = 8
local BUILD_BUDGET_MS = 2.5
local STALE_SECS = 0.35
local MAX_LIVE = 64
local LAYER_TTL = 3.0
CardFrame.MAX_LIVE, CardFrame.STALE_SECS = MAX_LIVE, STALE_SECS
CardFrame.BUILD_PER_FRAME, CardFrame.BUILD_BUDGET_MS = BUILD_PER_FRAME, BUILD_BUDGET_MS
local building = {}

local BUDGET_WINDOW = 1 / 30
local budget = { left = BUILD_PER_FRAME, spentMs = 0, t0 = -math.huge }

local function budgetReset(now)
    budget.left = BUILD_PER_FRAME
    budget.spentMs = 0
    budget.t0 = now
end

local function budgetTick(now)
    if now < budget.t0 or now - budget.t0 >= BUDGET_WINDOW then budgetReset(now) end
end

local function budgetOk()
    return budget.left > 0 and budget.spentMs < BUILD_BUDGET_MS
end

local function budgetSpend(t0)
    budget.left = budget.left - 1
    budget.spentMs = budget.spentMs + (love.timer.getTime() - t0) * 1000
end

local function frameIndex(anim, t)
    local n = #anim.canvases
    if n <= 0 then return 1 end
    local x = t * anim.fps
    if x ~= x or x == math.huge or x == -math.huge then return 1 end
    return math.floor(x) % n + 1
end

function CardFrame.frameAt(anim, t)
    return anim and anim.canvases[frameIndex(anim, t)] or nil
end

function CardFrame.getAnimation(card)
    local key = cacheKey(card)
    if animCache[key] then return animCache[key] end
    local art = CardArt.resolve(card)
    local frames = art.iconName and IconFramesLoader.get(art.iconName)
    if not frames then return nil end
    local canvases = {}
    local layers = layerCache[key] or renderLayers(card)
    for i, img in ipairs(frames.frames) do
        if i == 1 and cache[key] then
            canvases[1] = cache[key]
        else
            canvases[i] = composeFrame(card, layers, frameHandle(img))
        end
    end
    cache[key] = cache[key] or canvases[1]
    layerCache[key] = nil
    if not validSet(canvases) then
        warnOnce(key, "getAnimation: set de frames incompleto")
        return nil
    end
    building[key] = nil
    animCache[key] = { canvases = canvases, fps = frames.fps,
                       lastReq = love.timer.getTime() }
    return animCache[key]
end

local function evictLRU(now)
    local n = 0
    for _ in pairs(animCache) do n = n + 1 end
    while n > MAX_LIVE do
        local oldestKey, oldestT = nil, math.huge
        for k, a in pairs(animCache) do
            local t = a.lastReq or 0
            if t < oldestT then oldestT, oldestKey = t, k end
        end
        if not oldestKey or (now - oldestT) <= STALE_SECS then return end
        animCache[oldestKey] = nil
        n = n - 1
    end
end

function CardFrame.liveImage(card)
    local key = cacheKey(card)
    local now = love.timer.getTime()
    local anim = animCache[key]
    if anim then
        anim.lastReq = now
        local cv = anim.canvases[frameIndex(anim, now)]
        if not cv then
            warnOnce(key, "animação com frame vazio descartada")
            animCache[key] = nil
            return nil
        end
        return cv
    end

    budgetTick(now)
    if not budgetOk() then return nil end

    local b = building[key]
    if not b then
        local okA, art = pcall(CardArt.resolve, card)
        if not okA or not art or not art.iconName then return nil end
        if not IconFramesLoader.has(art.iconName) then return nil end
        local t0 = love.timer.getTime()
        local frames = IconFramesLoader.getIncremental(art.iconName, 1)
        budgetSpend(t0)
        if not frames or #frames.frames == 0 then return nil end
        if not cache[key] then
            local okR, err = pcall(CardFrame.render, card)
            if not okR then
                Debug.warn("[CardFrame] liveImage: render falhou para " .. key .. ": " .. tostring(err))
                return nil
            end
        end
        if not cache[key] then
            warnOnce(key, "render não preencheu o cache; sem animação")
            return nil
        end
        b = { frames = frames.frames, fps = frames.fps,
              canvases = { cache[key] }, i = 1 }
        building[key] = b
    end

    if not b.layers then
        if layerCache[key] then
            b.layers = layerCache[key]
        else
            local t0 = love.timer.getTime()
            local okL, layers = pcall(renderLayers, card)
            budgetSpend(t0)
            if not okL then
                Debug.warn("[CardFrame] falha nas camadas de " .. key .. ": " .. tostring(layers))
                building[key] = nil
                return nil
            end
            b.layers = layers
        end
    end

    while b.i < #b.frames and budgetOk() do
        b.i = b.i + 1
        local t0 = love.timer.getTime()
        local ok, cv = pcall(composeFrame, card, b.layers, frameHandle(b.frames[b.i]))
        budgetSpend(t0)
        if not ok then
            Debug.warn("[CardFrame] falha compondo frame " .. b.i .. " de " .. key .. ": " .. tostring(cv))
            building[key] = nil
            return nil
        end
        b.canvases[b.i] = cv
    end
    if b.i < #b.frames then return nil end

    building[key] = nil
    layerCache[key] = nil
    if not validSet(b.canvases) then
        warnOnce(key, "set de frames incompleto; sem animação")
        return nil
    end
    anim = { canvases = b.canvases, fps = b.fps, lastReq = now }
    animCache[key] = anim
    evictLRU(now)
    return anim.canvases[frameIndex(anim, now)]
end

function CardFrame.update()
    local t = love.timer.getTime()
    budgetReset(t)
    local n = 0
    for _ in pairs(animCache) do n = n + 1 end
    if n > MAX_LIVE then evictLRU(t) end
    for k, L in pairs(layerCache) do
        if not building[k] and (t - (L.t or t)) > LAYER_TTL then layerCache[k] = nil end
    end
end

function CardFrame._liveCount()
    local n = 0
    for _ in pairs(animCache) do n = n + 1 end
    return n
end

function CardFrame._renderDirectForParity(card)
    local art = CardArt.resolve(card)
    local first = art.iconName and IconFramesLoader.first(art.iconName)
    if not first then return nil end
    return renderOne(card, frameHandle(first))
end

function CardFrame._layerCount()
    local n = 0
    for _ in pairs(layerCache) do n = n + 1 end
    return n
end

function CardFrame._buildingCount()
    local n = 0
    for _ in pairs(building) do n = n + 1 end
    return n
end

function CardFrame.invalidate(card)
    local prefix = (card.id or (card.name or "?")) .. "+"
    for k in pairs(cache) do
        if k:sub(1, #prefix) == prefix then cache[k] = nil end
    end
    for k in pairs(animCache) do
        if k:sub(1, #prefix) == prefix then animCache[k] = nil end
    end
    for k in pairs(building) do
        if k:sub(1, #prefix) == prefix then building[k] = nil end
    end
    for k in pairs(layerCache) do
        if k:sub(1, #prefix) == prefix then layerCache[k] = nil end
    end
end

function CardFrame.clearCache()
    cache = {}
    animCache = {}
    building = {}
    layerCache = {}
end

I18n.onLocaleChanged(function() CardFrame.clearCache() end)

CardFrame.components = {
    border = CardBorder,
    header = CardHeader,
    costBadge = CardCostBadge,
    raritySeal = CardRaritySeal,
    artSlot = CardArtSlot,
    decoration = CardDecoration,
    footer = CardStatsFooter,
    jokerBorder = JokerBorder,
    jokerHeader = JokerHeader,
    jokerSeal   = JokerSeal,
    jokerFooter = JokerFooter,
}

return CardFrame
