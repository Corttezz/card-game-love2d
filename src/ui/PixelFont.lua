-- src/ui/PixelFont.lua
-- Fonte pixel-friendly usada EXCLUSIVAMENTE pelos componentes da carta
-- (`src/ui/card/`) — CardHeader (título), CardStatsFooter (ATTACK/DEFESA/ACTION),
-- CardCostBadge, CardRaritySeal, JokerHeader.
--
-- Usa a fonte default do LÖVE com `setFilter("nearest", "nearest")`. A chrome
-- de UI (botões, menus, settings, topbar) usa `FontManager` com a Press Start 2P
-- em `assets/fonts/pixel.ttf` — proposital: as duas famílias têm proporções
-- diferentes e ficam melhores em contextos diferentes.
--
-- Se quiser mudar a fonte das cartas, edite aqui. NÃO delegue para FontManager.

local PixelFont = {}

local cache = {}

function PixelFont.get(size)
    size = math.floor(size or 10)
    if not cache[size] then
        local f = love.graphics.newFont(size)   -- default LÖVE font
        f:setFilter("nearest", "nearest")       -- crítico pro visual pixel
        cache[size] = f
    end
    return cache[size]
end

-- Tamanhos semânticos pré-definidos.
function PixelFont.tiny()     return PixelFont.get(8)  end
function PixelFont.small()    return PixelFont.get(10) end
function PixelFont.body()     return PixelFont.get(12) end
function PixelFont.header()   return PixelFont.get(14) end
function PixelFont.title()    return PixelFont.get(20) end
function PixelFont.heading()  return PixelFont.get(28) end

-- Texto com drop shadow de 1px.
function PixelFont.drawShadowed(text, x, y, size, color, shadowColor)
    local font = PixelFont.get(size)
    love.graphics.setFont(font)
    local sr, sg, sb, sa = love.graphics.getColor()

    if shadowColor then
        love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowColor[4] or 1)
    else
        love.graphics.setColor(0, 0, 0, 0.7)
    end
    love.graphics.print(text, math.floor(x + 1), math.floor(y + 1))

    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.print(text, math.floor(x), math.floor(y))

    love.graphics.setColor(sr, sg, sb, sa)
end

-- Cache próprio; não delega.
function PixelFont.clearCache()
    cache = {}
end

return PixelFont
