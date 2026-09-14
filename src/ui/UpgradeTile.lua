-- src/ui/UpgradeTile.lua
-- Vitrine de UPGRADE (voucher) da loja: forja, vida maxima, mana maxima.
--
-- POR QUE ESTE MODULO EXISTE
-- O upgrade era desenhado como "o else" do slot de oferta: um retangulo
-- PANEL_FILL (a MESMA cor do fundo da grade), o sprite flutuando no vazio,
-- o nome miudo, uma tarja verde de 3px no topo e o preco como texto solto.
-- No tile compacto do split-view a descricao era DESCARTADA, entao o item nao
-- dizia o que fazia: o jogador via "Forja $5" e precisava passar o mouse pra
-- descobrir o resto. Ao lado, os booster packs tinham sleeve ilustrada e placa
-- de preco emoldurada -- o upgrade parecia o slot inacabado da loja.
--
-- Aqui ele vira um OBJETO na prateleira: placa iluminada (mais clara que o
-- fundo, entao existe), relicario com pedestal e halo na cor do efeito, chip
-- com o NUMERO do efeito (a informacao que faltava) e placa de preco com a
-- mesma gramatica da dos pacotes.
--
-- LAYOUT POR ZONAS (memory/ui_layout_invariants.md, secao 1)
-- layout() e uma funcao PURA que fatia o retangulo do slot em bandas
-- empilhadas -- nome / arte / chip / preco. Nenhum elemento e ancorado no
-- vizinho: quando falta altura, quem cede e a ESCALA do conteudo, e as bandas
-- opcionais CAEM em ordem de prioridade declarada (o chip cai, o preco nunca).
-- validate() prova isso geometricamente e roda nos testes.
--
-- RESIZE: este modulo nao guarda estado geometrico nenhum -- as bandas sao
-- derivadas do retangulo a cada frame. Nao ha cache pra invalidar (secao 2).

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local FontManager = require("src.ui.FontManager")
local TextFit     = require("src.ui.TextFit")
local ImageCache  = require("src.ui.ImageCache")
local I18n        = require("src.i18n.I18n")
local Moveable    = require("engine.Moveable")

local UpgradeTile = {}

-- Acessibilidade: reducedMotion remove MOVIMENTO, nunca INFORMACAO
-- (ui_layout_invariants, secao 3). Halo, chip e destaque de hover continuam.
local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function setC(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
end

-- ============================================================================
-- TEMA POR EFEITO (data-driven: chaveado pelo `effect`, nunca pelo nome --
-- convencao do projeto contra condicional por card.name)
-- ============================================================================
local THEMES = {
    forge_card          = { accent = Palette.RUST },
    increase_max_health = { accent = Palette.BLOOD },
    increase_base_mana  = { accent = Palette.BLUE },
}
local DEFAULT_THEME = { accent = Palette.AGED_GOLD }

-- accent = cromo (borda do chip, topo do pedestal); glow = halo atras da
-- reliquia; text = cor do numero do efeito (tem que passar no fundo escuro).
function UpgradeTile.theme(offer)
    local base = (offer and THEMES[offer.effect]) or DEFAULT_THEME
    local accent = base.accent
    return {
        accent = accent,
        glow   = Palette.lighten(accent, 0.35),
        text   = Palette.lighten(accent, 0.62),
    }
end

-- Texto curto do efeito ("+10 VIDA MAX"). Vive no i18n como
-- shop_items.<id>.effect; sem chave, devolve nil e a banda do chip nao e
-- desenhada (o painel de detalhe continua explicando o item por extenso).
function UpgradeTile.effectLabel(offer)
    if not offer or not offer.id then return nil end
    local key = "shop_items." .. tostring(offer.id) .. ".effect"
    local txt = I18n.t(key, { value = offer.value }, "")
    if not txt or txt == "" or txt == key then return nil end
    return txt
end

function UpgradeTile.flavor(offer)
    if not offer or not offer.id then return nil end
    local key = "shop_items." .. tostring(offer.id) .. ".flavor"
    local txt = I18n.t(key, nil, "")
    if not txt or txt == "" or txt == key then return nil end
    return txt
end

-- ============================================================================
-- LAYOUT (puro)
-- ============================================================================
-- Bandas, de cima pra baixo:
--   name  (obrigatoria)  nome da reliquia
--   art   (obrigatoria)  pedestal + halo + sprite
--   chip  (opcional)     numero do efeito
--   price (obrigatoria)  placa de preco
local ART_MIN = 44   -- piso da arte antes de derrubar banda opcional

function UpgradeTile.layout(x, y, w, h)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    local pad = clamp(math.floor(w * 0.05), 4, 9)
    local ix, iw = x + pad, w - pad * 2
    local iy, ih = y + pad, h - pad * 2

    local nameH  = clamp(math.floor(h * 0.095), 12, 20)
    local priceH = clamp(math.floor(h * 0.10), 15, 22)
    local chipH  = clamp(math.floor(h * 0.085), 13, 18)
    local gap    = (ih >= 150) and 5 or 3

    -- Altura da arte = sobra. As opcionais caem em ordem declarada enquanto a
    -- arte nao alcanca o piso -- nunca por "ajuste fino" no call site.
    local function artOf(useChip)
        local bands = nameH + priceH + (useChip and chipH or 0)
        local gaps  = gap * (useChip and 3 or 2)
        return ih - bands - gaps
    end
    local useChip = artOf(true) >= ART_MIN
    local artH = math.max(10, artOf(useChip))

    local cy = iy
    local bands = {
        pad = pad,
        frame = { x = x, y = y, w = w, h = h },
        inner = { x = ix, y = iy, w = iw, h = ih },
    }

    bands.name = { x = ix, y = cy, w = iw, h = nameH }
    cy = cy + nameH + gap
    bands.art = { x = ix, y = cy, w = iw, h = artH }
    cy = cy + artH + gap
    if useChip then
        bands.chip = { x = ix, y = cy, w = iw, h = chipH }
        cy = cy + chipH + gap
    end
    bands.price = { x = ix, y = cy, w = iw, h = priceH }
    return bands
end

-- Violacoes geometricas (lista vazia = OK). Mesmo contrato do
-- PackChoiceLayout.validate: o teste que layout por acumulacao nunca tem.
function UpgradeTile.validate(x, y, w, h)
    local b = UpgradeTile.layout(x, y, w, h)
    local bad = {}
    local prev
    for _, key in ipairs({ "name", "art", "chip", "price" }) do
        local r = b[key]
        if r then
            if r.x < b.frame.x or r.y < b.frame.y
                or r.x + r.w > b.frame.x + b.frame.w
                or r.y + r.h > b.frame.y + b.frame.h then
                bad[#bad + 1] = ("banda %s (%d,%d %dx%d) escapa do tile (%d,%d %dx%d)")
                    :format(key, r.x, r.y, r.w, r.h,
                            b.frame.x, b.frame.y, b.frame.w, b.frame.h)
            end
            if r.h <= 0 or r.w <= 0 then
                bad[#bad + 1] = ("banda %s degenerada (%dx%d)"):format(key, r.w, r.h)
            end
            if prev and r.y < prev.y + prev.h then
                bad[#bad + 1] = ("banda %s (y=%d) invade %s (fim y=%d)")
                    :format(key, r.y, prev.key, prev.y + prev.h)
            end
            prev = { key = key, y = r.y, h = r.h }
        end
    end
    return bad
end

-- ============================================================================
-- ARTE DA RELIQUIA (compartilhada com o painel de detalhe)
-- ============================================================================
-- Halo + sombra de contato + sprite, centrados no rect.
--
-- NAO desenha pedestal. A primeira versao punha uma laje sob a peca e foi
-- removida olhando os PNGs: o cristal de mana JA vem com base de pedra na
-- arte e a bigorna JA tem pe -- a laje virava um segundo pedestal empilhado
-- no primeiro (o anti-pattern "somar camada sobre arte que ja tem",
-- ui_layout_invariants secao 4). O que faltava era CHAO, nao mobilia: uma
-- sombra de contato e um halo quente resolvem, sem cobrir nada.
--   opts.alpha, opts.glow (0..1), opts.bob (px), opts.theme
function UpgradeTile.drawArt(offer, rect, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    local th = opts.theme or UpgradeTile.theme(offer)
    local glowK = opts.glow or 0

    local cx = math.floor(rect.x + rect.w / 2)
    local restY = rect.y + rect.h - 3   -- linha de chao (base da banda)
    local availH = rect.h - 6

    -- Sprite da reliquia. tryGet: miss = nil (o get() devolvia o placeholder
    -- theRock e o voucher sem arte mostrava uma carta no lugar).
    local sprite = offer and offer.id
        and ImageCache.tryGet("assets/sprites/vouchers/" .. tostring(offer.id) .. ".png")

    local dw, dh = 0, 0
    local scale = 0
    if sprite and availH > 8 then
        local sw, sh = sprite:getWidth(), sprite:getHeight()
        local raw = math.min((rect.w - 10) / sw, availH / sh)
        -- Escala em passos de 1/4. Inteiro puro era luxo caro aqui: com
        -- sprite de 64px e banda de ~120, floor() joga tudo pra 1x e a peca
        -- encolhia pra metade da banda (a versao antiga do tile mostrava a
        -- bigorna MAIOR). Um quarto de passo mantem a malha previsivel e
        -- ainda preenche -- o jogo ja desenha carta em 1.333.
        scale = (raw >= 1) and (math.floor(raw * 4) / 4) or raw
        dw, dh = sw * scale, sh * scale
    end

    -- Halo atras, centrado na PECA (tres aneis de alpha baixo -- sem shader).
    local haloR = math.floor(math.max(dw, dh, math.min(rect.w, rect.h) * 0.5) * 0.58)
    local haloY = math.floor(restY - (dh > 0 and dh or rect.h * 0.5) * 0.5)
    for i = 3, 1, -1 do
        local k = i / 3
        setC(th.glow, alpha * (0.05 + 0.16 * glowK) * (1.1 - k))
        love.graphics.circle("fill", cx, haloY, haloR * k)
    end

    if sprite and scale > 0 then
        local lift = math.max(0, opts.bob or 0)
        local dx = math.floor(cx - dw / 2)
        local dy = math.floor(restY - dh - lift)

        -- Sombra de contato: encolhe conforme a reliquia sobe (a sombra conta
        -- a altura -- sem ela o bob lia como o sprite "escorregando").
        setC(Palette.INK, alpha * 0.5 * (1 - math.min(0.7, lift / 12)))
        love.graphics.ellipse("fill", cx, restY,
            dw * 0.36 * (1 - math.min(0.25, lift / 40)), math.max(2, dh * 0.06))

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(sprite, dx, dy, 0, scale, scale)
    elseif not sprite then
        -- Sem PNG: selo ornamental (nunca um buraco).
        local r = math.floor(math.min(rect.w, math.max(8, availH)) * 0.28)
        setC(Palette.PARCHMENT_DARK, 0.85 * alpha)
        love.graphics.circle("fill", cx, restY - r, r)
        setC(th.accent, alpha)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", cx, restY - r, r)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Brasas subindo do pedestal no hover. Deterministicas (senoide por indice):
-- captura de tela vira reproduzivel e o RNG da run nao e gasto com cosmetico.
local function drawEmbers(rect, th, t, k, alpha)
    if k <= 0.02 then return end
    local cx = rect.x + rect.w / 2
    for i = 1, 6 do
        local phase = (t * 0.55 + i * 0.17) % 1
        local spread = math.sin(i * 2.4 + t * 1.3) * rect.w * 0.22
        local px = cx + spread * (0.4 + phase * 0.6)
        local py = rect.y + rect.h - 6 - phase * rect.h * 0.72
        setC(th.glow, alpha * k * (1 - phase) * 0.8)
        love.graphics.rectangle("fill", math.floor(px), math.floor(py), 2, 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- DRAW
-- ============================================================================
-- state = {
--   hover  = 0..1  (hover ja interpolado por quem e dono do tile)
--   afford = bool
--   time   = love.timer.getTime()
--   alpha  = 0..1
-- }
function UpgradeTile.draw(offer, rect, state)
    state = state or {}
    local alpha = state.alpha or 1
    if alpha <= 0.01 then return end
    local hover = clamp(state.hover or 0, 0, 1)
    local afford = state.afford ~= false
    local t = state.time or love.timer.getTime()
    local th = UpgradeTile.theme(offer)
    local b = UpgradeTile.layout(rect.x, rect.y, rect.w, rect.h)
    local f = b.frame

    -- Foco clareia a moldura, MAS dentro da propria cor de estado: um tile
    -- impagavel em hover clareando pra dourado apagava justamente o aviso de
    -- "voce nao tem ouro" no momento em que o jogador esta olhando pra ele.
    local borderColor = afford and Palette.AGED_GOLD or Palette.BLOOD
    if hover > 0 then
        borderColor = Palette.lerp(borderColor,
            afford and Palette.AGED_GOLD_LIGHT or Palette.lighten(Palette.BLOOD, 0.2),
            hover)
    end

    -- ===== Placa =====
    -- Sombra projetada: o tile e um OBJETO na prateleira, nao um recorte no
    -- fundo (o retangulo PANEL_FILL antigo tinha a cor do proprio fundo).
    setC(Palette.INK, alpha * (0.45 + 0.2 * hover))
    love.graphics.rectangle("fill", f.x + 3, f.y + 4, f.w, f.h, 4, 4)

    -- Fundo: um degrade CURTO (4 faixas) de topo iluminado pra base em
    -- sombra. A primeira versao usava uma faixa clara chapada no topo 16% e
    -- ela lia como um cabecalho colado, com emenda visivel no meio da placa.
    -- Impagavel escurece a PLACA inteira, nao so o numero: e o equivalente do
    -- saleDim das cartas. Comunicar so pela cor do preco falha exatamente em
    -- quem tem dificuldade com vermelho.
    local shade = afford and 1 or 0.55
    local fillTop = Palette.darken(
        Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.30 + 0.16 * hover), shade)
    local fillBot = Palette.darken(
        Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.12 + 0.10 * hover), shade)
    setC(Palette.lerp(fillTop, fillBot, 0.5), alpha)
    love.graphics.rectangle("fill", f.x, f.y, f.w, f.h, 4, 4)
    -- Faixas INSET 2px: o miolo recebe o degrade e a base arredondada segue
    -- aparecendo na borda (retangulo reto por cima comeria os cantos).
    local gx, gy = f.x + 2, f.y + 2
    local gw, gh = f.w - 4, f.h - 4
    local STEPS = 8   -- 4 faixas deixavam uma emenda visivel no meio da placa
    local bandH = math.max(1, math.floor(gh / STEPS))
    for i = 0, STEPS - 1 do
        local bh = (i == STEPS - 1) and (gh - bandH * (STEPS - 1)) or bandH
        setC(Palette.lerp(fillTop, fillBot, i / (STEPS - 1)), alpha)
        love.graphics.rectangle("fill", gx, gy + i * bandH, gw, math.max(1, bh))
    end

    -- Moldura dupla + rebites de canto (leitura de placa de metal).
    setC(Palette.INK, alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", f.x + 0.5, f.y + 0.5, f.w - 1, f.h - 1, 4, 4)
    setC(borderColor, alpha * (0.75 + 0.25 * hover))
    love.graphics.rectangle("line", f.x + 2.5, f.y + 2.5, f.w - 5, f.h - 5, 3, 3)
    for _, c in ipairs({ { f.x + 4, f.y + 4 }, { f.x + f.w - 6, f.y + 4 },
                         { f.x + 4, f.y + f.h - 6 }, { f.x + f.w - 6, f.y + f.h - 6 } }) do
        setC(borderColor, alpha * 0.9)
        love.graphics.rectangle("fill", c[1], c[2], 2, 2)
    end

    -- Impagavel = tile ESCURECIDO, alem do preco vermelho. Mesma regra das
    -- cartas (Card.saleDim): nunca comunicar so pela cor do numero.
    local dim = afford and 1 or 0.45

    -- ===== Banda NOME =====
    do
        local name = (offer and offer.name) or "?"
        local size = clamp(math.floor(b.name.h * 0.62), 8, 13)
        -- -16 (nao -4): com -4 um nome longo era reduzido ate encostar na
        -- moldura dos dois lados, sem margem nenhuma.
        local font, txt = TextFit.fit(name, size, b.name.w - 16)
        love.graphics.setFont(font)
        local tx = b.name.x + math.floor((b.name.w - font:getWidth(txt)) / 2)
        local ty = b.name.y + math.floor((b.name.h - font:getHeight()) / 2)
        local col = Palette.lerp(Palette.AGED_GOLD_LIGHT, Palette.PARCHMENT_LIGHT, hover * 0.5)
        FontManager.drawWithOutline(txt, tx, ty,
            { col[1], col[2], col[3], alpha * dim }, 0.85 * alpha)
    end

    -- ===== Banda ARTE =====
    local bob = 0
    if not reducedMotion() then
        -- Respiro lento em repouso; no hover a reliquia LEVANTA do chao.
        bob = math.sin(t * 1.6) * 1.5 + hover * 5
    end
    UpgradeTile.drawArt(offer, b.art, {
        alpha = alpha * dim, theme = th, bob = bob,
        glow = 0.35 + 0.65 * hover,
    })
    if not reducedMotion() then
        drawEmbers(b.art, th, t, hover, alpha)
    end

    -- ===== Banda CHIP (o numero do efeito) =====
    local label = UpgradeTile.effectLabel(offer)
    if b.chip and label then
        local c = b.chip
        setC(Palette.darken(Palette.INK, 0.2), alpha * 0.85)
        love.graphics.rectangle("fill", c.x, c.y, c.w, c.h, 3, 3)
        setC(th.accent, alpha * (0.7 + 0.3 * hover))
        love.graphics.rectangle("line", c.x + 0.5, c.y + 0.5, c.w - 1, c.h - 1, 3, 3)
        local size = clamp(math.floor(c.h * 0.60), 8, 11)
        local font, txt = TextFit.fit(label, size, c.w - 8)
        love.graphics.setFont(font)
        local tx = c.x + math.floor((c.w - font:getWidth(txt)) / 2)
        local ty = c.y + math.floor((c.h - font:getHeight()) / 2)
        FontManager.drawWithOutline(txt, tx, ty,
            { th.text[1], th.text[2], th.text[3], alpha }, 0.8 * alpha)
    end

    -- ===== Banda PRECO =====
    -- Mesma gramatica da placa dos booster packs ao lado (PANEL_FILL +
    -- contorno dourado/sangue): a fileira 2 passa a ler como uma prateleira
    -- so, nao como dois componentes de telas diferentes.
    do
        -- Placa mais estreita que o chip de efeito de proposito: empilhadas na
        -- mesma largura, as duas liam como duas barras iguais e a hierarquia
        -- (o que o item FAZ vs o que ele CUSTA) sumia.
        local inset = math.floor(b.price.w * 0.12)
        local p = { x = b.price.x + inset, y = b.price.y,
                    w = b.price.w - inset * 2, h = b.price.h }
        local priceColor = afford and Palette.AGED_GOLD or Palette.BLOOD
        PixelCanvas.rect(p.x, p.y, p.w, p.h, Palette.PANEL_FILL)
        PixelCanvas.rectOutline(p.x, p.y, p.w, p.h, priceColor)
        -- Fonte 11/9: no tamanho 10 o glifo "6" da fonte pixel rasteriza "G".
        local size = (p.h >= 20) and 11 or 9
        local font, txt = TextFit.fit("$" .. tostring((offer and offer.cost) or 0),
            size, p.w - 6)
        love.graphics.setFont(font)
        local col = afford and Palette.AGED_GOLD_LIGHT or Palette.BLOOD
        setC(col, alpha)
        love.graphics.print(txt,
            p.x + math.floor((p.w - font:getWidth(txt)) / 2),
            p.y + math.floor((p.h - font:getHeight()) / 2))
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Escala viva do tile (entrada + kick de compra), pra quem desenha aplicar em
-- torno do centro. Sem objeto de juice, devolve 1 / 0.
function UpgradeTile.scaleOf(fx)
    if not fx or not fx.juice then return 1 end
    return Moveable.scaleFactor(fx) * Moveable.swellFactor(fx)
end

function UpgradeTile.liftOf(fx)
    if not fx or not fx.juice then return 0 end
    return Moveable.hopOffset(fx)
end

return UpgradeTile
