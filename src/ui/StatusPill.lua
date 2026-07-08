-- src/ui/StatusPill.lua
-- Componente visual único pra "pill" de status effect / buff / debuff.
-- Usado tanto por EnemyHud (debuffs do inimigo) quanto PlayerBuffPills (buffs do jogador).
--
-- Formato: círculo com halo colorido + fundo escuro + outlines + ícone central + contador.
-- Comportamento: hover → StatusTooltip.show.
--
-- Config única (STATUS_COLORS + STATUS_ICONS) vive aqui como source of truth.
-- Callers passam opts pra ajustar tamanho, animação e regras de exibição de stacks.

local Palette = require("src.ui.Palette")
local FontManager = require("src.ui.FontManager")
local IconLoader = require("src.ui.IconLoader")
local StatusTooltip = require("src.ui.StatusTooltip")

local StatusPill = {}

-- ===== Tabelas canônicas (fonte única de verdade) =====
StatusPill.COLORS = {
    poison     = { 0.45, 0.75, 0.30 },
    weak       = { 0.50, 0.45, 0.70 },
    vulnerable = { 0.85, 0.55, 0.25 },
    burn       = { 0.90, 0.40, 0.20 },
    strength   = { 0.85, 0.30, 0.30 },
    fury       = { 0.95, 0.35, 0.15 },
    dexterity  = { 0.35, 0.75, 0.90 },
    focus      = { 0.80, 0.70, 0.30 },
}
StatusPill.ICONS = {
    poison     = "status_poison",
    weak       = "status_weak",
    vulnerable = "status_vulnerable",
    burn       = "flame",
    strength   = "status_strength",
    fury       = "flame",
    dexterity  = "status_dexterity",
    focus      = "rune",
}

local iconCache = {}
local function getIcon(name)
    if iconCache[name] ~= nil then return iconCache[name] or nil end
    local iconName = StatusPill.ICONS[name]
    if not iconName then
        iconCache[name] = false
        return nil
    end
    local icon = IconLoader.get(iconName)
    iconCache[name] = icon or false
    return icon
end

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

-- Dimensões da row horizontal (layout externo).
function StatusPill.getRowDims(count, size, spacing)
    size = size or 32
    spacing = spacing or 8
    if count == 0 then return 0, 0 end
    return count * (size + spacing) - spacing, size
end

-- Desenha UMA pill. Não gerencia posicionamento da row — cal ler passa (x, y) top-left.
-- opts:
--   size: diâmetro em px (default 32)
--   stacks: número (default 1); contador só aparece se > 1 OU showStacksAlways
--   duration: turnos restantes (passado pro tooltip, não renderizado)
--   showStacksAlways: bool — buffs do player mostram sempre
--   animTime: segundos acumulados (pra halo pulsante)
--   pulseHalo: bool — buffs tem halo mais forte (pulsando)
--   iconTarget: tamanho alvo do ícone em px (default = size * 0.76)
function StatusPill.render(name, x, y, opts)
    opts = opts or {}
    local size = opts.size or 32
    local stacks = opts.stacks or 1
    local animTime = opts.animTime or 0
    local pulseHalo = opts.pulseHalo
    local color = StatusPill.COLORS[name] or { 0.6, 0.6, 0.6 }
    local iconTarget = opts.iconTarget or math.floor(size * 0.76)

    local cx = x + size / 2
    local cy = y + size / 2
    local r = size / 2

    -- Halo colorido (pulsa em buffs, estático em debuffs)
    local haloAlpha = 0.30
    if pulseHalo then
        haloAlpha = 0.30 * (0.75 + math.sin(animTime * 3) * 0.25)
    end
    love.graphics.setColor(color[1], color[2], color[3], haloAlpha)
    love.graphics.circle("fill", cx, cy, r + 2)

    -- Fundo escuro
    love.graphics.setColor(0.10, 0.07, 0.05, 0.95)
    love.graphics.circle("fill", cx, cy, r)

    -- Outlines (tinta preta externa + cor interna)
    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.circle("line", cx, cy, r - 1)

    -- Ícone centralizado (fallback: inicial maiúscula)
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

    -- Contador (stacks) no canto inf-dir
    if stacks > 1 or opts.showStacksAlways then
        local font = FontManager.getResponsiveFont(0.02, 12)
        love.graphics.setFont(font)
        local txt = tostring(stacks)
        local tw = font:getWidth(txt)
        local fh = font:getHeight()
        local stackCx = x + size - 6
        local stackCy = y + size - 6
        love.graphics.setColor(0, 0, 0, 0.92)
        love.graphics.circle("fill", stackCx, stackCy, 10)
        setColor(Palette.INK, 1)
        love.graphics.circle("line", stackCx, stackCy, 10)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(txt, stackCx - tw / 2, stackCy - fh / 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Desenha uma row horizontal de pills. Trata hover → tooltip sozinho.
-- effects: array { {name, stacks, duration}, ... }
-- startX, startY: top-left da row
-- opts: mesmas opts de render + spacing
function StatusPill.drawRow(effects, startX, startY, opts)
    if not effects or #effects == 0 then return end
    opts = opts or {}
    local size = opts.size or 32
    local spacing = opts.spacing or 8

    local mx, my = love.mouse.getPosition()

    for i, eff in ipairs(effects) do
        local x = startX + (i - 1) * (size + spacing)
        local pillOpts = {
            size = size,
            stacks = eff.stacks or 1,
            animTime = opts.animTime,
            pulseHalo = opts.pulseHalo,
            iconTarget = opts.iconTarget,
            showStacksAlways = opts.showStacksAlways,
        }
        StatusPill.render(eff.name, x, startY, pillOpts)

        -- Hover → tooltip
        if mx >= x and mx <= x + size and my >= startY and my <= startY + size then
            StatusTooltip.show(eff.name, mx, my, {
                stacks = eff.stacks or 1,
                duration = eff.duration or 1,
            })
        end
    end
end

return StatusPill
