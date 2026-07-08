-- src/ui/HintBar.lua
-- Barra de dicas PADRONIZADA (F1 do UI Overhaul — docs/plan/ui-ux-overhaul-v1.md §3.6).
-- Regra: a dica SEMPRE cabe na tela — encolhe a fonte em degraus e, se ainda
-- não couber, trunca com reticências. Mata a classe de bug "hint estourando
-- dos dois lados" (loja). Pill centralizado, cores da paleta grimoire.
--
-- Uso:  HintBar.draw("CLIQUE pra inspecionar · ESC volta")            -- rodapé
--       HintBar.draw(texto, { y = 500, sizes = {14, 12, 10} })

local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")

local HintBar = {}

-- Encaixa o texto na largura: tenta cada tamanho de fonte; no menor,
-- trunca com "…" se preciso. Retorna font, texto final.
local function fit(text, maxW, sizes)
    local font
    for _, size in ipairs(sizes) do
        font = FontManager.getFont(size)
        if font:getWidth(text) <= maxW then
            return font, text
        end
    end
    -- menor fonte e ainda largo: trunca
    local out = text
    while #out > 4 and font:getWidth(out .. "…") > maxW do
        -- remove byte a byte respeitando UTF-8 (continuation bytes 0x80-0xBF)
        repeat
            out = out:sub(1, -2)
        until #out == 0 or out:byte(-1) < 0x80 or out:byte(-1) > 0xBF
    end
    return font, out .. "…"
end

function HintBar.draw(text, opts)
    if not text or text == "" then return end
    opts = opts or {}
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local padX = opts.padX or 12
    local maxW = W - 32 - padX * 2
    local sizes = opts.sizes or { 14, 12, 10 }

    local font, shown = fit(text, maxW, sizes)
    local tw = font:getWidth(shown)
    local th = font:getHeight()
    local x = math.floor((W - tw) / 2)
    local y = opts.y or (H - th - 14)

    -- pill de fundo (ink translúcido — véu pequeno de rodapé, padrão aceito)
    love.graphics.setColor(0.08, 0.06, 0.05, 0.72)
    love.graphics.rectangle("fill", x - padX, y - 5, tw + padX * 2, th + 10, 6, 6)
    Palette.set(Palette.PARCHMENT)
    love.graphics.setFont(font)
    love.graphics.print(shown, x, y)
    love.graphics.setColor(1, 1, 1, 1)
end

return HintBar
