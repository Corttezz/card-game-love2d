-- src/ui/HelpBadge.lua
-- O "?" de ajuda no estilo do grimório: disco tinta + aro dourado + "?"
-- (o MESMO desenho do "?" de regras da loja). Uma peça só pra todo "?" que
-- abre explicação sob demanda — dados da loja, modal dos dados.

local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")

local HelpBadge = {}

-- Retângulo clicável (com folga de 3px) de um "?" de raio r em (cx, cy).
function HelpBadge.rect(cx, cy, r)
    return { x = cx - r - 3, y = cy - r - 3, w = r * 2 + 6, h = r * 2 + 6 }
end

function HelpBadge.draw(cx, cy, r, hot)
    love.graphics.setColor(0.10, 0.08, 0.05, 1)
    love.graphics.circle("fill", cx, cy, r)
    Palette.set(hot and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD)
    love.graphics.setLineWidth(hot and 2 or 1)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.setLineWidth(1)
    local f = FontManager.getFont(math.max(8, math.floor(r * 1.1)))
    love.graphics.setFont(f)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print("?", math.floor(cx - f:getWidth("?") / 2 + 1),
        math.floor(cy - f:getHeight() / 2))
    love.graphics.setColor(1, 1, 1, 1)
end

return HelpBadge
