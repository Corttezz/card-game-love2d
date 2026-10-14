local Debug = require("src.core.Debug")

local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local I18n = require("src.i18n.I18n")
local utf8 = require("utf8")

local StatusTooltip = {}

local active = nil
local shownKey = nil
local shownAt = 0
local lastShowTime = 0

local MAX_INNER = 264
local MIN_INNER = 132
local PAD = 12
local LETTER_SPACING = 1
local LINE_HEIGHT = 1.4
local POP_DURATION = 0.14

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end

local function measureSpaced(font, text)
    local w, n = 0, 0
    for _, code in utf8.codes(text) do
        w = w + font:getWidth(utf8.char(code))
        n = n + 1
    end
    if n > 1 then w = w + LETTER_SPACING * (n - 1) end
    return w
end

local function printSpaced(font, text, x, y)
    local cx = x
    for _, code in utf8.codes(text) do
        local ch = utf8.char(code)
        love.graphics.print(ch, math.floor(cx), math.floor(y))
        cx = cx + font:getWidth(ch) + LETTER_SPACING
    end
end

local function breakLongWord(font, word, maxW, lines)
    local piece = ""
    for _, code in utf8.codes(word) do
        local ch = utf8.char(code)
        if piece ~= "" and measureSpaced(font, piece .. ch) > maxW then
            table.insert(lines, piece)
            piece = ch
        else
            piece = piece .. ch
        end
    end
    return piece
end

local function wrapSpaced(font, text, maxW)
    local lines = {}
    local line = ""
    for word in tostring(text):gmatch("%S+") do
        if measureSpaced(font, word) > maxW then
            if line ~= "" then table.insert(lines, line); line = "" end
            line = breakLongWord(font, word, maxW, lines)
        else
            local test = line == "" and word or (line .. " " .. word)
            if measureSpaced(font, test) > maxW then
                table.insert(lines, line)
                line = word
            else
                line = test
            end
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

function StatusTooltip.show(statusName, mouseX, mouseY, ctx)
    if not statusName then return end
    active = {
        name = statusName,
        x = mouseX or 0,
        y = mouseY or 0,
        ctx = ctx or {},
        k = require("src.ui.UiScale").activeK(),
    }
    local now = love.timer.getTime()
    if statusName ~= shownKey or (now - lastShowTime) > 0.25 then
        shownKey = statusName
        shownAt = now
    end
    lastShowTime = now
end

function StatusTooltip.hide()
    active = nil
    shownKey = nil
end

function StatusTooltip.isActive()
    return active ~= nil
end

local function capitalize(s)
    if not s or s == "" then return s end
    return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

local warnedVariant = {}
local function resolveTexts(statusName, ctx)
    if ctx and ctx.title then return ctx.title, ctx.body or "" end
    local ns = "status."
    if I18n.t("status." .. statusName .. ".name", nil, "") == ""
        and I18n.t("enemy_kit.status." .. statusName .. ".name", nil, "") ~= "" then
        ns = "enemy_kit.status."
    end
    if ns == "status." and I18n.t("status." .. statusName .. ".name", nil, "") == ""
        and I18n.t("tutorial.status." .. statusName .. ".name", nil, "") ~= "" then
        ns = "tutorial.status."
    end
    local nameKey = ns .. statusName .. ".name"
    local descKey = ns .. statusName .. ".desc"
    local name = I18n.t(nameKey, nil, capitalize(statusName))
    local desc = ""
    local variant = ctx and ctx.variant
    if variant then
        desc = I18n.t(descKey .. "_" .. variant, ctx, "")
        if desc == "" and not warnedVariant[statusName .. "/" .. variant] then
            warnedVariant[statusName .. "/" .. variant] = true
            Debug.warn("[StatusTooltip] sem chave " .. descKey .. "_" .. variant
                .. " — usando a desc padrao")
        end
    end
    if desc == "" then
        desc = I18n.t(descKey, ctx, "")
    end
    return name, desc
end

function StatusTooltip.draw()
    if not active then return end
    local UiScale = require("src.ui.UiScale")
    if (active.k or 1) ~= 1 and not UiScale.isActive() then
        UiScale.begin(active.k)
        local ok, err = pcall(StatusTooltip._draw)
        UiScale.finish()
        if not ok then error(err, 0) end
        return
    end
    return StatusTooltip._draw()
end

function StatusTooltip._draw()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    local headerFont = FontManager.getResponsiveFont(0.024, 15)
    local bodyFont = FontManager.getResponsiveFont(0.02, 12)

    local name, desc = resolveTexts(active.name, active.ctx)

    local headerLines = wrapSpaced(headerFont, name, MAX_INNER)
    local bodyLines = (desc ~= "") and wrapSpaced(bodyFont, desc, MAX_INNER) or {}

    local innerW = MIN_INNER
    for _, l in ipairs(headerLines) do
        innerW = math.max(innerW, measureSpaced(headerFont, l))
    end
    for _, l in ipairs(bodyLines) do
        innerW = math.max(innerW, measureSpaced(bodyFont, l))
    end
    innerW = math.min(innerW, MAX_INNER)

    local headerLH = math.floor(headerFont:getHeight() * LINE_HEIGHT)
    local bodyLH = math.floor(bodyFont:getHeight() * LINE_HEIGHT)
    local headerH = #headerLines * headerLH
    local dividerH = (#bodyLines > 0) and 9 or 0
    local bodyH = #bodyLines * bodyLH

    local boxW = innerW + PAD * 2
    local boxH = PAD + headerH + dividerH + bodyH + PAD

    local x = active.x + 14
    local y = active.y + 14
    if x + boxW > sw - 4 then
        x = active.x - boxW - 14
    end
    if x < 4 then x = 4 end
    if y + boxH > sh - 4 then
        y = active.y - boxH - 8
    end
    if y < 4 then y = 4 end
    x, y = math.floor(x), math.floor(y)

    local rm = _G.gameSettings and _G.gameSettings.reducedMotion
    local k = 1
    if not rm then
        k = math.min(1, (love.timer.getTime() - shownAt) / POP_DURATION)
        k = 1 - (1 - k) * (1 - k) * (1 - k)
    end
    local alpha = k
    local scale = 0.94 + 0.06 * k

    love.graphics.push()
    local ox = (x > active.x) and x or (x + boxW)
    local oy = (y > active.y) and y or (y + boxH)
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-ox, -oy)

    love.graphics.setColor(0, 0, 0, 0.55 * alpha)
    love.graphics.rectangle("fill", x + 3, y + 4, boxW, boxH, 5, 5)

    setColor(Palette.PARCHMENT_DARK, 0.98 * alpha)
    love.graphics.rectangle("fill", x, y, boxW, boxH, 5, 5)

    setColor(Palette.INK, alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, boxW, boxH, 5, 5)

    setColor(Palette.AGED_GOLD_DARK, 0.85 * alpha)
    love.graphics.rectangle("line", x + 3, y + 3, boxW - 6, boxH - 6, 3, 3)

    setColor(Palette.AGED_GOLD_LIGHT, 0.9 * alpha)
    love.graphics.setLineWidth(1)
    local tick = 6
    love.graphics.line(x + 3, y + 3 + tick, x + 3, y + 3, x + 3 + tick, y + 3)
    love.graphics.line(x + boxW - 3 - tick, y + 3, x + boxW - 3, y + 3, x + boxW - 3, y + 3 + tick)
    love.graphics.line(x + 3, y + boxH - 3 - tick, x + 3, y + boxH - 3, x + 3 + tick, y + boxH - 3)
    love.graphics.line(x + boxW - 3 - tick, y + boxH - 3, x + boxW - 3, y + boxH - 3, x + boxW - 3, y + boxH - 3 - tick)

    love.graphics.setFont(headerFont)
    local hy = y + PAD
    for _, line in ipairs(headerLines) do
        love.graphics.setColor(0, 0, 0, 0.9 * alpha)
        printSpaced(headerFont, line, x + PAD + 1, hy + 1)
        setColor(Palette.AGED_GOLD_LIGHT, alpha)
        printSpaced(headerFont, line, x + PAD, hy)
        hy = hy + headerLH
    end

    if #bodyLines > 0 then
        setColor(Palette.AGED_GOLD_DARK, 0.9 * alpha)
        love.graphics.line(x + PAD, hy + 3, x + boxW - PAD, hy + 3)
    end

    love.graphics.setFont(bodyFont)
    setColor(Palette.PARCHMENT_LIGHT, alpha)
    local by = hy + dividerH
    for _, line in ipairs(bodyLines) do
        printSpaced(bodyFont, line, x + PAD, by)
        by = by + bodyLH
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)

    active = nil
end

return StatusTooltip
