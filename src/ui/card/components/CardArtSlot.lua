-- src/ui/card/components/CardArtSlot.lua
-- Art slot: ilustração central com opção de cover/contain.
-- Default: **cover fit** — o ícone preenche o slot todo (ambas dimensões);
-- overflow é cortado pelo scissor, dando o efeito "ilustração encosta
-- nos banners de nome e stats".
--
-- Overrides por carta (em `src/data/card_art.lua`):
--   artData.artScale  = número (1, 1.5, 2, etc.) — substitui o cover automático.
--     - nil   → cover-fit inteiro (padrão)
--     - 1     → ícone nativo sem zoom (64×64 centrado — tipo o visual antigo)
--     - outro → scale fixo (pode ser fracional pra PNG)
--   artData.artOffsetY = pixels pra deslocar o ícone verticalmente (útil pra
--     sprites cujo subject não tá no centro do 64×64).
--
-- opts:
--   skipIcon = true      → não desenha o ícone (usado pelo Joker, anima via overlay)
--   iconOverride = handle → substitui artData.icon (frames animados do CardFrame;
--                           mesmo contrato { size = {w,h}, draw(x, y, scale) })

local CardArtSlot = {}

-- Escala inteira que cobre o slot (pixel-perfect, sem blur). Usa ceil pra
-- garantir que o ícone preenche as duas dimensões.
local function computeCoverScale(iconW, iconH, slotW, slotH)
    if iconW <= 0 or iconH <= 0 then return 1 end
    local sW = math.ceil(slotW / iconW)
    local sH = math.ceil(slotH / iconH)
    return math.max(1, sW, sH)
end

-- Geometria compartilhada do ícone no slot (cover-fit ou artScale/artOffsetY).
-- Também usada pelo CardAnimationLayer pra desenhar frames animados EXATAMENTE
-- onde o ícone estático ficaria — manter as duas em sincronia é obrigatório.
-- ENQUADRAMENTO VERTICAL (Out/2026, dono: "o topo das cartas está cortado"
-- — o elmo do Defender, o punho da espada, a cabeça da Força Interior). O
-- cover-fit inteiro (64→128) passa ~25-31px da altura do slot e o corte era
-- dividido meio a meio: metade do excesso sumia em CIMA, justamente onde
-- ficam cabeças, punhos e chamas. VALIGN = fração do excesso cortada em
-- cima (0 = topo encostado, 0.5 = centro): 0.2 mostra o topo do sujeito e
-- tira o resto do pé/chão, que o rodapé de stats já emoldura. Carta cujo
-- sujeito importante fica EMBAIXO usa artOffsetY em src/data/card_art.lua.
CardArtSlot.VALIGN = 0.2

-- Primeira linha com conteúdo (alpha > ~5%) do PNG do ícone, em px do ícone.
-- Cache por caminho; ícone sem PNG (matriz) = 0.
local contentTopCache = {}
function CardArtSlot.contentTop(handle)
    local path = handle and handle.path
    if not path then return 0 end
    local c = contentTopCache[path]
    if c then return c end
    c = 0
    local ok, data = pcall(love.image.newImageData, path)
    if ok and data then
        local w, h = data:getWidth(), data:getHeight()
        c = h
        for yy = 0, h - 1 do
            local hit = false
            for xx = 0, w - 1 do
                local _, _, _, a = data:getPixel(xx, yy)
                if a > 0.05 then hit = true; break end
            end
            if hit then c = yy; break end
        end
    else
        print("[CardArtSlot] sem ImageData pro bbox de " .. tostring(path))
    end
    contentTopCache[path] = c
    return c
end

-- iconHandle: o ícone ESTÁTICO (artData.icon) — o bbox vale pros frames
-- animados também, que são desenhados exatamente no mesmo lugar.
function CardArtSlot.layout(iconW, iconH, x, y, w, h, artData, iconHandle)
    local scale = (artData and artData.artScale)
        or computeCoverScale(iconW, iconH, w, h)
    local drawnW = iconW * scale
    local drawnH = iconH * scale
    local iconX = x + math.floor((w - drawnW) / 2)
    local excess = h - drawnH   -- negativo quando o ícone passa do slot
    local iconY = y + math.floor(excess * (excess < 0 and CardArtSlot.VALIGN or 0.5))
    -- SUJEITO INTEIRO NO TOPO (dono: "onde começa a sombra do título ela
    -- corta"): se o conteúdo do ícone começaria acima do slot (atrás do
    -- banner), desce até a primeira linha de conteúdo ficar no slot — o
    -- corte vai todo pro pé. Nunca desce além do topo do ícone no slot.
    if excess < 0 and not (artData and artData.artOffsetY and artData.artOffsetY ~= 0) then
        local ct = CardArtSlot.contentTop(iconHandle or (artData and artData.icon))
        local want = y - ct * scale
        if want > iconY then iconY = math.min(y, want) end
    end
    iconY = iconY + ((artData and artData.artOffsetY) or 0)
    return iconX, iconY, scale
end

function CardArtSlot.draw(x, y, w, h, artData, theme, opts)
    opts = opts or {}

    local iconHandle = opts.iconOverride or artData.icon
    if not opts.skipIcon and iconHandle then
        local iconW = iconHandle.size.w
        local iconH = iconHandle.size.h

        local iconX, iconY, scale = CardArtSlot.layout(iconW, iconH, x, y, w, h, artData,
            artData and artData.icon)

        -- RECORTE: embaixo e dos lados, o slot; em CIMA, opts.clipTop (topo
        -- interno da moldura). Acima do slot a arte continua e some ATRÁS do
        -- banner do nome, que é desenhado depois — nunca é decepada por uma
        -- linha reta no pergaminho (dono: "onde começa a sombra do título
        -- ela corta").
        local top = math.min(y, opts.clipTop or y)
        local sx, sy, sw, sh = love.graphics.getScissor()
        love.graphics.setScissor(x, top, w, y + h - top)
        iconHandle.draw(iconX, iconY, scale)
        if sx then
            love.graphics.setScissor(sx, sy, sw, sh)
        else
            love.graphics.setScissor()
        end
    end
end

return CardArtSlot
