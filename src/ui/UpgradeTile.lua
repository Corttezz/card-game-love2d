-- src/ui/UpgradeTile.lua
-- Vitrine de UPGRADE (voucher) da loja: forja, vida maxima, mana maxima.
--
-- POR QUE ESTE MODULO EXISTE
-- O upgrade era desenhado como "o else" do slot de oferta: um retangulo
-- PANEL_FILL (a MESMA cor do fundo da grade), o sprite flutuando no vazio,
-- o nome miudo, uma tarja verde de 3px no topo e o preco como texto solto.
-- No tile compacto do split-view a descricao era DESCARTADA, entao o item nao
-- dizia o que fazia: o jogador via "Forja $5" e precisava passar o mouse pra
-- descobrir o resto.
--
-- Aqui ele vira um OBJETO na prateleira: placa iluminada (mais clara que o
-- fundo, entao existe), relicario com halo na cor do efeito, PLACA GRAVADA com
-- o efeito e MOEDA cunhada com o preco.
--
-- REVISAO Set/2026 ("cara de IA"): a versao anterior mostrava o efeito e o
-- preco como dois retangulos empilhados de cantos arredondados anti-aliasados,
-- moldura de 1px simetrica e texto centrado -- vocabulario de formulario web,
-- nao de grimorio, e diferente do que a CARTA ao lado ja fazia (moeda no canto
-- superior direito). As duas placas foram substituidas pela gramatica unica de
-- src/ui/ShopEngraving.lua, que carta, pacote e reliquia agora compartilham.
-- Repare que o tile PERDEU uma banda: o preco nao ocupa mais linha nenhuma, e
-- a sobra foi pra arte.
--
-- LAYOUT POR ZONAS (memory/ui_layout_invariants.md, secao 1)
-- layout() e uma funcao PURA que fatia o retangulo do slot em bandas
-- empilhadas -- nome / arte / efeito -- mais o rect da MOEDA, que e overlay
-- carimbado na moldura (como o custo de mana na carta) e por isso tem regra
-- propria: nunca invade a coluna do nome. Nenhum elemento e ancorado no
-- vizinho: quando falta altura, quem cede e a ESCALA do conteudo, e as bandas
-- opcionais CAEM em ordem de prioridade declarada. validate() prova isso
-- geometricamente e roda nos testes.
--
-- RESIZE: este modulo nao guarda estado geometrico -- as bandas sao derivadas
-- do retangulo a cada frame. O unico cache e o de bitmaps da placa gravada,
-- que vive no ShopEngraving e e limpo por ShopEngraving.clearCache() no
-- resize da loja (secao 2).

local Palette       = require("src.ui.Palette")
local PixelCanvas   = require("src.ui.PixelCanvas")
local FontManager   = require("src.ui.FontManager")
local TextFit       = require("src.ui.TextFit")
local ImageCache    = require("src.ui.ImageCache")
local I18n          = require("src.i18n.I18n")
local Moveable      = require("engine.Moveable")
local ShopEngraving = require("src.ui.ShopEngraving")
local FramesLoader  = require("src.ui.IconFramesLoader")

local UpgradeTile = {}

-- Acessibilidade: reducedMotion remove MOVIMENTO, nunca INFORMACAO
-- (ui_layout_invariants, secao 3). Halo, placa e destaque de hover continuam.
local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function setC(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
end

-- ============================================================================
-- SPRITE: estatico por padrao, animado na INTERACAO
-- ============================================================================
-- Mesmo contrato dos icones de carta (memory/card_icon_animation.md):
--   assets/sprites/vouchers_anim/<offer_id>/frame_NNN.png (+ meta.lua {fps})
-- Pasta ausente = o tile usa o PNG estatico de assets/sprites/vouchers/. Os
-- dois estados sao normais e nenhum quebra -- a faixa de animacao e um upgrade
-- opcional do asset, nao um requisito do codigo.
local VOUCHER_STATIC = "assets/sprites/vouchers/"
local VOUCHER_ANIM   = "assets/sprites/vouchers_anim"

UpgradeTile.ANIM_ROOT = VOUCHER_ANIM

local animWarned = {}

-- Handle de animacao do voucher, ou nil. AVISA uma vez se a pasta existe mas
-- nao rendeu frame nenhum -- fallback silencioso e proibido (secao 3): uma
-- pasta com PNG de nome errado degradaria pra estatico sem rastro nenhum.
function UpgradeTile.animationFor(offerId)
    if not offerId then return nil end
    local handle = FramesLoader.getFrom(VOUCHER_ANIM, offerId)
    if handle then return handle end
    if not animWarned[offerId]
        and love.filesystem.getInfo(VOUCHER_ANIM .. "/" .. tostring(offerId), "directory") then
        animWarned[offerId] = true
        print(("[UpgradeTile] %s/%s existe mas nao tem frame_NNN.png legivel -- "
            .. "caindo no PNG estatico"):format(VOUCHER_ANIM, tostring(offerId)))
    end
    return nil
end

function UpgradeTile.staticSprite(offerId)
    if not offerId then return nil end
    -- tryGet: miss = nil (o get() devolvia o placeholder theRock e o voucher
    -- sem arte mostrava uma carta no lugar).
    return ImageCache.tryGet(VOUCHER_STATIC .. tostring(offerId) .. ".png")
end

-- A imagem a desenhar neste frame. `animate` vem da INTERACAO (hover ou item
-- em foco no painel de detalhe) -- idle e estatico, regra do projeto: o que
-- se move na prateleira e o que o jogador esta olhando.
function UpgradeTile.spriteFor(offerId, animate, t)
    if animate then
        local anim = UpgradeTile.animationFor(offerId)
        if anim then
            local frame = anim:frameAt(t or 0)
            if frame then return frame, true end
        end
    end
    -- Frame 0 do set animado tambem serve de estatico (se a pasta existe mas
    -- o PNG solto nao). Ordem: estatico -> frame 0 -> nil.
    local img = UpgradeTile.staticSprite(offerId)
    if img then return img, false end
    return FramesLoader.firstFrom(VOUCHER_ANIM, offerId), false
end

-- ============================================================================
-- TEMA POR EFEITO (data-driven: chaveado pelo `effect`, nunca pelo nome --
-- convencao do projeto contra condicional por card.name)
-- ============================================================================
local THEMES = {
    forge_card          = { accent = Palette.RUST },
    increase_max_health = { accent = Palette.BLOOD },
    increase_base_mana  = { accent = Palette.MANA_LIGHT },
}
local DEFAULT_THEME = { accent = Palette.AGED_GOLD }

-- accent = cromo (filete da placa gravada, halo); text = cor do efeito quando
-- ele aparece FORA da placa (popup de compra, etiqueta de categoria).
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
-- shop_items.<id>.effect; sem chave, devolve nil e a banda da placa nao e
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
-- Bandas empilhadas, de cima pra baixo:
--   name   (obrigatoria)  nome da reliquia -- largura DESCONTADA da moeda
--   art    (obrigatoria)  halo + sombra de contato + sprite
--   effect (opcional)     placa gravada com o efeito
-- Overlay:
--   seal   (quando ha preco)  moeda cunhada no canto superior direito
local ART_MIN = 44   -- piso da arte antes de derrubar banda opcional

-- `cost` e opcional: a moeda cresce com o numero de digitos, entao quem sabe o
-- preco reserva o espaco EXATO e o nome fica com o resto. Sem ele, reserva-se
-- o pior caso (3 digitos) -- a coluna do nome nunca pode ficar devendo.
function UpgradeTile.layout(x, y, w, h, cost)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    local pad = clamp(math.floor(w * 0.05), 4, 9)
    local ix, iw = x + pad, w - pad * 2
    local iy, ih = y + pad, h - pad * 2

    local nameH   = clamp(math.floor(h * 0.095), 12, 20)
    local effectH = clamp(math.floor(h * 0.105), 13, 20)
    local gap     = (ih >= 150) and 5 or 3

    -- Altura da arte = sobra. A banda opcional cai enquanto a arte nao alcanca
    -- o piso -- nunca por "ajuste fino" no call site.
    local function artOf(useEffect)
        local bands = nameH + (useEffect and effectH or 0)
        local gaps  = gap * (useEffect and 2 or 1)
        return ih - bands - gaps
    end
    local useEffect = artOf(true) >= ART_MIN
    local artH = math.max(10, artOf(useEffect))

    local frame = { x = x, y = y, w = w, h = h }
    local seal = ShopEngraving.sealRect(frame, cost)

    local cy = iy
    local bands = {
        pad = pad,
        frame = frame,
        inner = { x = ix, y = iy, w = iw, h = ih },
        seal = seal,
    }

    -- A moeda tem prioridade na coluna da direita: o nome cede largura. Sem
    -- isso, um nome longo passaria POR BAIXO do disco (o defeito classico de
    -- dois elementos ancorados no mesmo canto sem saber um do outro).
    local nameW = math.max(12, seal.x - 2 - ix)
    bands.name = { x = ix, y = cy, w = nameW, h = nameH }
    cy = cy + nameH + gap
    bands.art = { x = ix, y = cy, w = iw, h = artH }
    cy = cy + artH + gap
    if useEffect then
        bands.effect = { x = ix, y = cy, w = iw, h = effectH }
    end
    return bands
end

-- Violacoes geometricas (lista vazia = OK). Mesmo contrato do
-- PackChoiceLayout.validate: o teste que layout por acumulacao nunca tem.
function UpgradeTile.validate(x, y, w, h, cost)
    local b = UpgradeTile.layout(x, y, w, h, cost)
    local bad = {}
    local prev
    for _, key in ipairs({ "name", "art", "effect" }) do
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
    -- A moeda e overlay, mas nao pode sair do tile nem morder o nome.
    local s = b.seal
    if s.x + s.w > b.frame.x + b.frame.w + 1 or s.y < b.frame.y - 1 then
        bad[#bad + 1] = ("moeda (%d,%d %dx%d) escapa do tile"):format(s.x, s.y, s.w, s.h)
    end
    if b.name.x + b.name.w > s.x then
        bad[#bad + 1] = ("nome (fim x=%d) passa por baixo da moeda (x=%d)")
            :format(b.name.x + b.name.w, s.x)
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
--   opts.alpha, opts.glow (0..1), opts.bob (px), opts.theme,
--   opts.animate (bool), opts.time
function UpgradeTile.drawArt(offer, rect, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    local th = opts.theme or UpgradeTile.theme(offer)
    local glowK = opts.glow or 0

    local cx = math.floor(rect.x + rect.w / 2)
    local restY = rect.y + rect.h - 3   -- linha de chao (base da banda)
    local availH = rect.h - 6

    local sprite = UpgradeTile.spriteFor(offer and offer.id,
        opts.animate and not reducedMotion(), opts.time or 0)

    local dw, dh = 0, 0
    local scale = 0
    if sprite and availH > 8 then
        local sw, sh = sprite:getWidth(), sprite:getHeight()
        local raw = math.min((rect.w - 10) / sw, availH / sh)
        -- Escala em passos de 1/4. Inteiro puro era luxo caro aqui: com
        -- sprite de 64px e banda de ~120, floor() joga tudo pra 1x e a peca
        -- encolhia pra metade da banda. Um quarto de passo mantem a malha
        -- previsivel e ainda preenche -- o jogo ja desenha carta em 1.333.
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
        PixelCanvas.disc(cx, restY - r, r,
            { Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],
              Palette.PARCHMENT_DARK[3], 0.85 * alpha })
        PixelCanvas.discOutline(cx, restY - r, r,
            { th.accent[1], th.accent[2], th.accent[3], alpha })
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Brasas subindo do chao no hover. Deterministicas (senoide por indice):
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
    local b = UpgradeTile.layout(rect.x, rect.y, rect.w, rect.h, offer and offer.cost)
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

    -- Impagavel = tile ESCURECIDO, alem do preco vermelho. Mesma regra das
    -- cartas (Card.saleDim): nunca comunicar so pela cor do numero.
    local shade = afford and 1 or 0.55
    local dim = afford and 1 or 0.45

    -- ===== Placa =====
    -- Sombra projetada: o tile e um OBJETO na prateleira, nao um recorte no
    -- fundo (o retangulo PANEL_FILL antigo tinha a cor do proprio fundo).
    local R = 3   -- canto CORTADO (degraus), nao arredondado por vetor: a
                  -- versao AA do love.graphics era um dos tells de "cara de IA"
    PixelCanvas.rectRounded(f.x + 3, f.y + 4, f.w, f.h, R,
        { Palette.INK[1], Palette.INK[2], Palette.INK[3],
          alpha * (0.45 + 0.2 * hover) })

    local fillTop = Palette.darken(
        Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.30 + 0.16 * hover), shade)
    local fillBot = Palette.darken(
        Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.12 + 0.10 * hover), shade)
    PixelCanvas.rectRounded(f.x, f.y, f.w, f.h, R,
        { fillTop[1], fillTop[2], fillTop[3], alpha })
    -- Luz de cima pra baixo em LINHAS INTEIRAS de pixel (inset 2px, pra base
    -- arredondada seguir aparecendo na borda). O degrade de 8 faixas da versao
    -- anterior deixava emendas horizontais visiveis no meio da placa.
    local gx, gy = f.x + 2, f.y + 2
    local gw, gh = f.w - 4, f.h - 4
    for row = 0, gh - 1 do
        local c = Palette.lerp(fillTop, fillBot, row / math.max(1, gh - 1))
        PixelCanvas.hline(gx, gy + row, gw, { c[1], c[2], c[3], alpha })
    end

    -- Moldura: bevel direcional (luz no topo, sombra na base) + cunhas de
    -- canto -- o mesmo vocabulario do rodape da carta. A moldura dupla
    -- perfeitamente simetrica com quatro rebites 2x2 identicos saiu: simetria
    -- de maquina e exatamente o que le como gerado.
    PixelCanvas.rectRoundedOutline(f.x, f.y, f.w, f.h, R,
        { Palette.INK[1], Palette.INK[2], Palette.INK[3], alpha })
    local hi = Palette.lerp(borderColor, Palette.PARCHMENT_LIGHT, 0.35)
    local lo = Palette.darken(borderColor, 0.5)
    local ba = alpha * (0.75 + 0.25 * hover)
    PixelCanvas.hline(f.x + 3, f.y + 1, f.w - 6, { hi[1], hi[2], hi[3], ba })
    PixelCanvas.vline(f.x + 1, f.y + 3, f.h - 6, { borderColor[1], borderColor[2], borderColor[3], ba })
    PixelCanvas.hline(f.x + 3, f.y + f.h - 2, f.w - 6, { lo[1], lo[2], lo[3], ba })
    PixelCanvas.vline(f.x + f.w - 2, f.y + 3, f.h - 6, { lo[1], lo[2], lo[3], ba })

    -- ===== Banda NOME =====
    do
        local name = (offer and offer.name) or "?"
        local size = clamp(math.floor(b.name.h * 0.62), 8, 13)
        -- -12: margem real dos dois lados (com -4 um nome longo era reduzido
        -- ate encostar na moldura).
        local font, txt = TextFit.fit(name, size, b.name.w - 12)
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
        alpha = alpha * dim, theme = th, bob = bob, time = t,
        glow = 0.35 + 0.65 * hover,
        -- Idle estatico, animado na INTERACAO (mesma regra dos icones de
        -- carta). Sem pasta de animacao, o sprite estatico entra igual.
        animate = hover > 0.02 or state.animate == true,
    })
    if not reducedMotion() then
        drawEmbers(b.art, th, t, hover, alpha)
    end

    -- ===== Banda EFEITO: placa gravada =====
    local label = UpgradeTile.effectLabel(offer)
    if b.effect and label then
        ShopEngraving.effectStrip(b.effect.x, b.effect.y, b.effect.w, b.effect.h,
            label, {
                accent = th.accent,
                alpha  = alpha,
                dim    = dim,
                seed   = ShopEngraving.seedOf(offer and offer.id),
            })
    end

    -- ===== PRECO: moeda cunhada na moldura =====
    -- Nao ocupa banda nenhuma: e carimbo sobre o objeto, como na carta ao
    -- lado. Foi a troca que fez a fileira inteira falar a mesma lingua.
    ShopEngraving.stampPrice(f, offer and offer.cost, {
        afford = afford, alpha = alpha, glow = hover,
    })

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
