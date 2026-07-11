-- src/ui/UiPanel.lua
-- Painel canônico do design system (Jul/2026): o idioma ESCURO-DOURADO da
-- loja, extraído pra fonte única. Antes, CardRewardScreen._drawPanel,
-- PauseMenu.drawDarkPanel e RoundEvalScreen redesenhavam a mesma gramática
-- com valores hardcoded levemente diferentes — agora todos leem daqui e dos
-- tokens Palette.PANEL_*.
--
-- Gramática (ver memory/ui_design_system.md):
--   sombra INK (offset 4,4 α0.45)
--   → miolo PANEL_FILL (via Panel9 "panel_inner" quando o asset existe)
--   → outline AGED_GOLD (lw3) + inner-outline AGED_GOLD_DARK (lw1)
--   → bevel-highlight no topo
--   → 4 cantos ornamentais AGED_GOLD_LIGHT (só depth "main")
--
-- Uso:
--   UiPanel.draw(x, y, w, h)                      -- painel principal
--   UiPanel.draw(x, y, w, h, { depth = "inner" }) -- subpainel (sem ornamento)

local Palette     = require("src.ui.Palette")
local Panel9      = require("src.ui.Panel9")

local UiPanel = {}

-- Fill canônico do miolo (PANEL_FILL com alpha de modal).
UiPanel.FILL_MAIN  = { 0.10, 0.07, 0.05, 0.95 }
UiPanel.FILL_INNER = { 0.05, 0.04, 0.03, 0.88 }

function UiPanel.draw(x, y, w, h, opts)
    opts = opts or {}
    local depth = opts.depth or "main"
    x, y = math.floor(x), math.floor(y)
    w, h = math.floor(w), math.floor(h)

    if depth == "inner" then
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", x + 4, y + 4, w, h, 6, 6)
        love.graphics.setColor(opts.fill or UiPanel.FILL_INNER)
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        Palette.set(Palette.AGED_GOLD_DARK)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
        return
    end

    -- ===== depth "main" =====
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", x + 4, y + 4, w, h, 6, 6)

    if Panel9.has and Panel9.has("panel_inner") then
        Panel9.draw("panel_inner", x, y, w, h,
            { fill = opts.fill or UiPanel.FILL_MAIN })
    else
        love.graphics.setColor(opts.fill or UiPanel.FILL_MAIN)
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        -- Bevel-highlight topo
        love.graphics.setColor(1, 0.88, 0.55, 0.18)
        love.graphics.setLineWidth(1)
        love.graphics.line(x + 6, y + 2, x + w - 6, y + 2)
        Palette.set(Palette.PANEL_OUTLINE or Palette.AGED_GOLD)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
        Palette.set(Palette.PANEL_OUTLINE_INNER or Palette.AGED_GOLD_DARK)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x + 3, y + 3, w - 6, h - 6, 4, 4)
    end

    -- Cantos ornamentais (assinatura do idioma)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT or { 1, 0.92, 0.55, 1 })
    love.graphics.setLineWidth(2)
    local c = 10
    love.graphics.line(x + 2, y + c, x + 2, y + 2, x + c, y + 2)
    love.graphics.line(x + w - c, y + 2, x + w - 2, y + 2, x + w - 2, y + c)
    love.graphics.line(x + 2, y + h - c, x + 2, y + h - 2, x + c, y + h - 2)
    love.graphics.line(x + w - c, y + h - 2, x + w - 2, y + h - 2, x + w - 2, y + h - c)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return UiPanel
