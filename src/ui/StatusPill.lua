local Debug = require("src.core.Debug")

local Palette = require("src.ui.Palette")
local FontManager = require("src.ui.FontManager")
local IconLoader = require("src.ui.IconLoader")
local PixelIcons = require("src.ui.PixelIcons")
local StatusTooltip = require("src.ui.StatusTooltip")

local StatusPill = {}

StatusPill.COLORS = {
    poison       = { 0.45, 0.75, 0.30 },
    weak         = { 0.50, 0.45, 0.70 },
    vulnerable   = { 0.85, 0.55, 0.25 },
    burn         = { 0.90, 0.40, 0.20 },
    strength     = { 0.85, 0.30, 0.30 },
    fury         = { 0.95, 0.35, 0.15 },
    dexterity    = { 0.35, 0.75, 0.90 },
    focus        = { 0.80, 0.70, 0.30 },
    thorn        = { 0.90, 0.50, 0.35 },
    lifesteal    = { 0.80, 0.25, 0.60 },
    regen        = { 0.40, 0.80, 0.55 },
    bleed        = { 0.60, 0.12, 0.18 },
    retain_armor = { 0.60, 0.72, 0.85 },
    block        = { 0.55, 0.70, 0.88 },
    enraged      = { 0.95, 0.45, 0.20 },
    weak_self       = { 0.50, 0.45, 0.70 },
    vulnerable_self = { 0.85, 0.55, 0.25 },
    frail           = { 0.45, 0.62, 0.80 },
    poison_self     = { 0.45, 0.75, 0.30 },
    burn_self       = { 0.90, 0.40, 0.20 },
    swarm           = { 0.40, 0.35, 0.45 },
    runes           = { 0.30, 0.55, 0.70 },
    chains          = { 0.55, 0.30, 0.15 },
    frost           = { 0.45, 0.70, 0.90 },
    roots           = { 0.40, 0.55, 0.25 },
    eclipse         = { 0.55, 0.30, 0.75 },
}
StatusPill.ICONS = {
    poison       = "status_poison",
    weak         = "status_weak",
    vulnerable   = "status_vulnerable",
    burn         = "status_burn",
    strength     = "status_strength",
    fury         = "status_fury",
    dexterity    = "status_dexterity",
    focus        = "rune",
    thorn        = "status_thorn",
    lifesteal    = "status_lifesteal",
    regen        = "status_regen",
    bleed        = "status_bleed",
    retain_armor = "status_retain_armor",
    enraged      = "status_enraged",
    block        = "armor_shield",
    weak_self       = "status_weak_self",
    vulnerable_self = "status_vulnerable_self",
    frail           = "status_frail",
    poison_self     = "status_poison",
    burn_self       = "status_burn",
    swarm           = "status_crows",
    runes           = "status_runes",
    chains          = "status_chains",
    frost           = "status_frost",
    roots           = "status_roots",
    eclipse         = "moon",
}

local warned = {}
local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    Debug.warn("[StatusPill] " .. message)
end

local iconCache = {}
local function getIcon(name)
    if iconCache[name] ~= nil then return iconCache[name] or nil end
    local iconName = StatusPill.ICONS[name]
    if not iconName then
        warnOnce("icon:" .. tostring(name),
            "status '" .. tostring(name) .. "' sem entrada em ICONS — pill cai na inicial")
        iconCache[name] = false
        return nil
    end
    local icon = IconLoader.get(iconName)
    if icon and icon.kind == "matrix" and PixelIcons[iconName] == nil then
        warnOnce("asset:" .. iconName,
            "icone '" .. iconName .. "' (status '" .. tostring(name)
            .. "') nao existe nem como PNG nem como matriz — desenhando '?'")
    end
    iconCache[name] = icon or false
    return icon
end

function StatusPill.clearCache()
    iconCache = {}
    warned = {}
end

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

function StatusPill.getRowDims(count, size, spacing)
    size = size or 32
    spacing = spacing or 8
    if count == 0 then return 0, 0 end
    return count * (size + spacing) - spacing, size
end

function StatusPill.fitSize(count, maxWidth, preferred, spacing)
    preferred = preferred or 32
    spacing = spacing or 8
    if count <= 0 or not maxWidth or maxWidth <= 0 then return preferred end
    local total = count * (preferred + spacing) - spacing
    if total <= maxWidth then return preferred end
    local fitted = math.floor((maxWidth - (count - 1) * spacing) / count)
    return math.max(16, math.min(preferred, fitted))
end

function StatusPill.render(name, x, y, opts)
    opts = opts or {}
    local size = opts.size or 32
    local stacks = opts.stacks or 1
    local animTime = opts.animTime or 0
    local pulseHalo = opts.pulseHalo
    local color = StatusPill.COLORS[name]
    if not color then
        warnOnce("color:" .. tostring(name),
            "status '" .. tostring(name) .. "' sem cor em COLORS — pill cinza")
        color = { 0.6, 0.6, 0.6 }
    end
    local iconTarget = opts.iconTarget or math.floor(size * 0.76)

    local cx = x + size / 2
    local cy = y + size / 2
    local r = size / 2

    local haloAlpha = 0.30
    if pulseHalo then
        haloAlpha = 0.30 * (0.75 + math.sin(animTime * 3) * 0.25)
    end
    love.graphics.setColor(color[1], color[2], color[3], haloAlpha)
    love.graphics.circle("fill", cx, cy, r + 2)

    love.graphics.setColor(0.10, 0.07, 0.05, 0.95)
    love.graphics.circle("fill", cx, cy, r)

    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.circle("line", cx, cy, r - 1)

    local icon = getIcon(name)
    if icon and icon.draw then
        local iconH = (icon.size and icon.size.h) or 16
        local iconW = (icon.size and icon.size.w) or 16
        local scale = IconLoader.computeScale(iconH, iconTarget)
        local ix = math.floor(cx - (iconW * scale) / 2)
        local iy = math.floor(cy - (iconH * scale) / 2)
        icon.draw(ix, iy, scale)
    else
        local font = FontManager.getResponsiveFont(0.02, 12)
        love.graphics.setFont(font)
        local letter = string.upper(string.sub(name or "?", 1, 1))
        local tw = font:getWidth(letter)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.print(letter, cx - tw / 2, cy - font:getHeight() / 2)
    end

    if stacks > 1 or opts.showStacksAlways then
        local font = FontManager.getResponsiveFont(0.02, 12)
        love.graphics.setFont(font)
        local txt = tostring(stacks)
        local tw = font:getWidth(txt)
        local fh = font:getHeight()
        local br = math.max(7, math.floor(size * 0.28))
        local stackCx = x + size - math.floor(br * 0.6)
        local stackCy = y + size - math.floor(br * 0.6)
        love.graphics.setColor(0, 0, 0, 0.92)
        love.graphics.circle("fill", stackCx, stackCy, br)
        setColor(Palette.INK, 1)
        love.graphics.circle("line", stackCx, stackCy, br)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(txt, stackCx - tw / 2, stackCy - fh / 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function StatusPill.drawRow(effects, startX, startY, opts)
    if not effects or #effects == 0 then return end
    opts = opts or {}
    local size = opts.size or 32
    local spacing = opts.spacing or 8

    local mx, my = love.mouse.getPosition()

    for i, eff in ipairs(effects) do
        local x = startX + (i - 1) * (size + spacing)
        local showStacks = opts.showStacksAlways
        if eff.showStacks ~= nil then showStacks = eff.showStacks end
        local pillOpts = {
            size = size,
            stacks = eff.stacks or 1,
            animTime = opts.animTime,
            pulseHalo = opts.pulseHalo,
            iconTarget = opts.iconTarget,
            showStacksAlways = showStacks,
        }
        StatusPill.render(eff.name, x, startY, pillOpts)
        require("src.ui.NavCursor").target("pill:" .. tostring(opts.navPrefix or "") .. eff.name, x, startY, size, size)

        if mx >= x and mx <= x + size and my >= startY and my <= startY + size then
            StatusTooltip.show(eff.name, mx, my, {
                stacks = eff.stacks or 1,
                duration = eff.duration or 1,
                variant = eff.variant,
                value = eff.value,
                max = eff.max,
                dealt = eff.dealt,
            })
        end
    end
end

return StatusPill
