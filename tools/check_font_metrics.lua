-- tools/check_font_metrics.lua
-- Mede a fonte do projeto: altura REPORTADA vs altura DESENHADA.
--
-- Existe porque a entrelinha do corpo de texto do evento sobrepunha as linhas
-- em alemão e o palpite "multiplica por 1.1" não resolveu. Fonte pixel via TTF
-- costuma reportar `getHeight()` menor que a caixa real dos glifos (acentos e
-- descendentes ficam fora da métrica), e aí `printf` empilha linhas curtas
-- demais. Medir a MANCHA DE PIXELS é o único jeito honesto de achar o fator.
--
-- Roda: love . check_font_metrics [tamanhos separados por virgula]

local M = {}

-- Desenha `txt` num canvas e devolve a primeira e a última linha de pixel
-- efetivamente pintada.
local function inkBounds(font, txt, w)
    local h = font:getHeight() * 4 + 40
    local c = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print(txt, 4, 10)
    love.graphics.setCanvas()

    local d = c:newImageData()
    local top, bot
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r = d:getPixel(x, y)
            if r > 0.25 then
                if not top then top = y end
                bot = y
                break
            end
        end
    end
    return top, bot
end

function M.run(sizes)
    require("src.ui.PixelCanvas").enableNearest()
    require("src.i18n.I18n").init()
    local FontManager = require("src.ui.FontManager")

    local list = {}
    for s in tostring(sizes or "10,12,14,20"):gmatch("[^,]+") do
        list[#list + 1] = tonumber(s)
    end

    -- Amostra com ascendente, descendente e acento: é o pior caso real.
    local SAMPLE = "Agjq ÁÇÃõ Klares"

    print("")
    print(string.format("%-6s %-10s %-10s %-10s %s",
        "size", "getHeight", "tinta(px)", "fator", "veredito"))
    for _, sz in ipairs(list) do
        local f = FontManager.getFont(sz)
        local top, bot = inkBounds(f, SAMPLE, 420)
        local ink = (top and bot) and (bot - top + 1) or 0
        local reported = f:getHeight()
        local factor = reported > 0 and (ink / reported) or 0
        local verdict = (ink > reported) and "SOBREPOE (tinta > metrica)" or "ok"
        print(string.format("%-6d %-10d %-10d %-10.2f %s",
            sz, reported, ink, factor, verdict))
    end
    print("")
    print("fator = quanto a tinta real excede getHeight(). A entrelinha segura")
    print("e o MAIOR fator entre os tamanhos usados, com uma folga pequena.")
    return true
end

return M
