-- src/ui/StatusTooltip.lua
-- Tooltip global (singleton) pra status effects. Qualquer componente chama
-- StatusTooltip.show(name, mx, my, ctx) e o main.lua desenha no fim do frame
-- (por cima de tudo) via StatusTooltip.draw().
--
-- Resolve i18n `status.<name>.name` e `status.<name>.desc` com interpolação
-- {stacks}/{duration}. Se a chave não existir, cai em fallback: nome literal
-- capitalizado + "Sem descrição disponível".

local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local I18n = require("src.i18n.I18n")

local StatusTooltip = {}

-- Estado interno (single tooltip por frame; última chamada vence)
local active = nil

local MAX_WIDTH = 240
local PAD = 10

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

-- Agenda um tooltip pra draw neste frame. Chamar ANTES do final do frame;
-- múltiplas chamadas no mesmo frame: só a última desenha (normal pra hover).
-- ctx: { stacks = N, duration = M } — valores usados na interpolação.
function StatusTooltip.show(statusName, mouseX, mouseY, ctx)
    if not statusName then return end
    active = {
        name = statusName,
        x = mouseX or 0,
        y = mouseY or 0,
        ctx = ctx or {},
    }
end

function StatusTooltip.hide()
    active = nil
end

function StatusTooltip.isActive()
    return active ~= nil
end

-- Capitaliza primeira letra (fallback quando falta tradução)
local function capitalize(s)
    if not s or s == "" then return s end
    return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

-- Resolve textos via I18n, com fallbacks sãos
local function resolveTexts(statusName, ctx)
    local nameKey = "status." .. statusName .. ".name"
    local descKey = "status." .. statusName .. ".desc"
    local name = I18n.t(nameKey, nil, capitalize(statusName))
    local desc = I18n.t(descKey, ctx, "")
    return name, desc
end

function StatusTooltip.draw()
    if not active then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    local headerFont = FontManager.getResponsiveFont(0.024, 15)
    local bodyFont = FontManager.getResponsiveFont(0.02, 12)

    local name, desc = resolveTexts(active.name, active.ctx)

    -- Mede texto (usa printf wrap pra descrição)
    love.graphics.setFont(headerFont)
    local nameW = headerFont:getWidth(name)
    local boxW = math.min(MAX_WIDTH, math.max(140, nameW + PAD * 2))

    love.graphics.setFont(bodyFont)
    local _, lines = bodyFont:getWrap(desc, boxW - PAD * 2)
    local descH = #lines * bodyFont:getHeight()

    local headerH = headerFont:getHeight()
    local dividerH = 6
    local boxH = PAD + headerH + dividerH + descH + PAD

    -- Smart positioning: à direita do mouse por default, espelha se sair da tela
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

    -- ===== RENDER =====
    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x + 3, y + 4, boxW, boxH, 5, 5)

    -- Fundo pergaminho escuro
    setColor(Palette.PARCHMENT_DARK, 0.98)
    love.graphics.rectangle("fill", x, y, boxW, boxH, 5, 5)

    -- Borda tinta externa
    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, boxW, boxH, 5, 5)

    -- Borda interna dourada
    setColor(Palette.AGED_GOLD_DARK, 0.85)
    love.graphics.rectangle("line", x + 3, y + 3, boxW - 6, boxH - 6, 3, 3)

    -- Header (nome)
    love.graphics.setFont(headerFont)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.print(name, x + PAD + 1, y + PAD + 1)
    setColor(Palette.AGED_GOLD_LIGHT, 1)
    love.graphics.print(name, x + PAD, y + PAD)

    -- Separador dourado
    setColor(Palette.AGED_GOLD_DARK, 0.9)
    love.graphics.line(
        x + PAD, y + PAD + headerH + 2,
        x + boxW - PAD, y + PAD + headerH + 2
    )

    -- Body (desc com wrap)
    love.graphics.setFont(bodyFont)
    setColor(Palette.PARCHMENT_LIGHT, 1)
    love.graphics.printf(
        desc,
        x + PAD,
        y + PAD + headerH + dividerH,
        boxW - PAD * 2,
        "left"
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)

    -- Auto-hide: tooltip é ephemeral por frame. Componentes têm que chamar
    -- show() a cada frame que o hover continua. Sem re-call, some no próximo
    -- frame automaticamente.
    active = nil
end

return StatusTooltip
