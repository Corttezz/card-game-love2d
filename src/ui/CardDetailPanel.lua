-- src/ui/CardDetailPanel.lua
-- Painel de DETALHE FIXO de uma oferta (carta / voucher / booster pack).
--
-- Nasceu do redesign split-view da LOJA DE RELÍQUIAS (Jul/2026, pedido do
-- dono: "não está muito boa a visualização das cartas"). O problema antigo era
-- que a informação real da oferta só existia em painéis FLUTUANTES que
-- saltavam de posição (CardRewardScreen._drawHoverInfoPanels) — o jogador
-- tinha que varrer o mouse pra entender o que estava comprando.
--
-- Aqui a leitura é ESTÁVEL: uma âncora que nunca muda de lugar, só de
-- conteúdo. Grid compacto à esquerda decide, este painel à direita explica.
--
-- Gramática visual: a MESMA do CardInspectModal (carta grande com warp 3D do
-- CardMesh + coluna de meta/stats/descrição/efeitos). A duplicação com o
-- CardInspectModal é consciente: aquele arquivo é o modal FULLSCREEN da
-- Coleção/Deck Viewer (geometria própria, setas de navegação, backdrop) e
-- estava sendo editado por outra frente — extrair de lá seria mexer em
-- território alheio. Se um dia os dois convergirem, o modal deve passar a
-- chamar CardDetailPanel.draw() com o retângulo dele.
--
-- Uso:
--   local rect = { x = ..., y = ..., w = ..., h = ... }
--   CardDetailPanel.draw(rect, payload, opts)
--
--   payload = nil                                   -- estado neutro
--           | { kind = "card",    offer = o, instance = inst }
--           | { kind = "voucher", offer = o }
--           | { kind = "pack",    offer = o }
--
--   opts = {
--     alpha     = 0..1,    -- fade do conteúdo (default 1)
--     stale     = bool,    -- é a ÚLTIMA carta olhada (nada em hover agora)
--     footerH   = number,  -- altura reservada no rodapé (botões do caller)
--     emptyHint = string,  -- texto do estado neutro
--     staleHint = string,  -- rodapé discreto quando stale
--     chrome    = bool,    -- desenha o painel de fundo (default true)
--     parchment = bool,    -- tinta sobre papel (pergaminho da Loja v3)
--     artMaxH   = number,  -- teto da altura da arte (pergaminho curto)
--     priceOnButton = bool, -- o preço está no botão de compra: some da legenda
--     objectArt = fn(payload, x, y, w, h, alpha) -> bool  -- desenha a arte de
--                 relíquia/pacote no lugar da composição padrão (Loja v3c: o
--                 pergaminho mostra o MESMO sprite da mesa); false = padrão
--   }

local CardDetailPanel = {}

local FontManager        = require("src.ui.FontManager")
local Palette            = require("src.ui.Palette")
local CardMesh           = require("src.ui.CardMesh")
local CardArt            = require("src.ui.CardArt")
local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")
local UpgradeTile        = require("src.ui.UpgradeTile")
local I18n               = require("src.i18n.I18n")

local PAD = 14

-- PALETAS. O painel nasceu como coluna escura (texto claro). Na Loja v3 ele
-- vira o PERGAMINHO de inspeção pendurado no prego: tinta sobre papel. Em vez
-- de duplicar o desenho, as cores saem de uma tabela escolhida por
-- opts.parchment (ver ShopScene._drawScroll).
local DARK_PAL = {
    name = Palette.AGED_GOLD_LIGHT, body = Palette.PARCHMENT_LIGHT, dim = Palette.PARCHMENT,
    sep = Palette.PARCHMENT_DARK, divider = Palette.AGED_GOLD, head = Palette.AGED_GOLD,
    price = Palette.AGED_GOLD_LIGHT, mana = Palette.MANA_LIGHT or Palette.PARCHMENT_LIGHT,
    defense = Palette.STEEL_LIGHT, affinity = Palette.AGED_GOLD_LIGHT,
    typeColor = function(c) return Palette.lighten(c, 0.45) end,
    rarity = function(r) return Palette.forRarity(r) end,
}
-- Contraste mínimo no papel (v5: "Comum" e "Relíquia" saíam cinza claro).
local function lumC(c)
    local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
end
local function onPaper(c)
    local bg = Palette.PARCHMENT_LIGHT
    for _ = 1, 30 do
        local a, b = lumC(c), lumC(bg)
        if (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05) >= 4.5 then break end
        c = Palette.darken(c, 0.88)
    end
    return c
end
CardDetailPanel.onPaper = onPaper
local PARCHMENT_PAL = {
    name = Palette.BLOOD_DARK, body = Palette.INK, dim = onPaper(Palette.PARCHMENT_DARK),
    sep = Palette.PARCHMENT_DARK, divider = Palette.AGED_GOLD_DARK, head = Palette.RUST,
    price = Palette.AGED_GOLD_DARK, mana = Palette.MANA_DEEP or Palette.INK,
    defense = Palette.STEEL, affinity = Palette.RUST,
    typeColor = function(c) return onPaper(Palette.darken(c, 0.75)) end,
    -- comum é PARCHMENT_LIGHT: some no papel. Tudo escurece até >= 4,5:1.
    rarity = function(r) return onPaper(Palette.darken(Palette.forRarity(r), 0.55)) end,
}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

-- Escalonamento de fonte por largura do painel: o mesmo módulo serve uma
-- coluna de 240px (janela pequena) e uma de 380px (fullscreen).
local function fontTier(w)
    if w >= 330 then
        return { name = 15, meta = 10, stat = 12, desc = 10, tiny = 8 }
    elseif w >= 270 then
        return { name = 13, meta = 9, stat = 11, desc = 9, tiny = 8 }
    end
    return { name = 11, meta = 8, stat = 9, desc = 8, tiny = 7 }
end

-- Maior tamanho de fonte (descendo de `from` até `to`) em que TODAS as strings
-- cabem em maxW. Existe porque os rótulos vêm do i18n: "Dano: 12" cabe, o
-- "Verteid.: 10" do alemão não — e um printf que não cabe QUEBRA A LINHA,
-- jogando o número por cima do texto de baixo (defeito visto em de_DE).
local function fitFont(strings, maxW, from, to)
    for size = from, to, -1 do
        local f = FontManager.getFont(size)
        local ok = true
        for _, t in ipairs(strings) do
            if f:getWidth(t) > maxW then ok = false; break end
        end
        if ok then return f, size, true end
    end
    return FontManager.getFont(to), to, false
end

local function setC(color, a)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (a or 1))
end

local function divider(x, y, w, alpha, color)
    setC(color or Palette.AGED_GOLD, 0.55 * alpha)
    love.graphics.rectangle("fill", x, y, w, 1)
end

-- ============================================================================
-- ARTE (topo do painel)
-- ============================================================================

-- Carta grande com warp 3D seguindo o mouse (mesma linguagem da inspeção).
-- Com reducedMotion o warp e a sombra dinâmica ficam em repouso.
local function drawCardArt(inst, ax, ay, aw, ah, alpha)
    local img = inst and inst.image
    if not img then return end

    -- Ícone animado (icons_anim/): a inspeção CONTA como interação — regra do
    -- dono "a animação só aparece na interação" (ver memory/card_icon_animation.md).
    local okCF, CardFrame = pcall(require, "src.ui.CardFrame")
    if okCF and CardFrame and CardFrame.liveImage then
        local live = CardFrame.liveImage(inst)
        if live then img = live end
    end

    local iw, ih = img:getWidth(), img:getHeight()
    -- Margem própria: a carta NUNCA encosta nas bordas da coluna nem no bloco
    -- de texto. Encostada ela parecia espremida ("apertada contra o limite").
    local scale = math.min((aw - 28) / iw, (ah - 16) / ih)
    local dw, dh = iw * scale, ih * scale
    local x = math.floor(ax + (aw - dw) / 2)
    local y = math.floor(ay + (ah - dh) / 2)

    -- VINHETA + CHÃO: a carta grande vira um objeto EM EXPOSIÇÃO em vez de um
    -- sprite colado no fundo. Halo quente que decai (nada de moldura — ela já
    -- tem borda). NÃO desenhamos sombra de contato aqui: o próprio Card:draw
    -- já projeta a sombra da carta (shDx/shDy abaixo), e a elipse somava uma
    -- SEGUNDA sombra — pedido do dono Set/2026: "tire a sombra circular, o
    -- componente da carta já tem sombra automaticamente".
    -- 20 passos (não 9): com poucos degraus o halo mostrava ANÉIS visíveis a
    -- 2×. Expoente 1.5 na queda pra a luz morrer suave e não virar um rim
    -- dourado colado na borda da carta (que já é dourada — isso reintroduziria
    -- a sensação de moldura dupla).
    local steps = 20
    for i = steps, 1, -1 do
        local t = i / steps
        local pad = 3 + t * 34
        setC(Palette.AGED_GOLD, 0.05 * ((1 - t) ^ 1.5) * alpha)
        love.graphics.rectangle("fill", x - pad, y - pad, dw + pad * 2, dh + pad * 2, 16, 16)
    end

    local uvx, uvy, hover = 0, 0, 0
    if not reducedMotion() then
        local mx, my = love.mouse.getPosition()
        local cx, cy = x + dw / 2, y + dh / 2
        uvx = math.max(-1, math.min(1, (mx - cx) / (dw / 2)))
        uvy = math.max(-1, math.min(1, (my - cy) / (dh / 2)))
        hover = 0.55 * alpha   -- warp permanente suave (a carta está "na mão")
    end

    -- Sombra projetada mais curta que antes: com a vinheta, um deslocamento
    -- grande virava uma "segunda carta" fantasma.
    local shDx = -uvx * 9
    local shDy = 8 - uvy * 6

    local shader = CardMesh.getShader()
    if shader then
        local mesh = CardMesh.getMesh(iw, ih)
        mesh:setTexture(img)
        love.graphics.setShader(shader)
        CardMesh.setUniforms(shader, { uvx, uvy }, hover, love.timer.getTime(), img)
        love.graphics.setColor(0, 0, 0, 0.38 * alpha)
        love.graphics.draw(mesh, x + shDx, y + shDy, 0, scale, scale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(mesh, x, y, 0, scale, scale)
        love.graphics.setShader()
    else
        love.graphics.setColor(0, 0, 0, 0.38 * alpha)
        love.graphics.draw(img, x + shDx, y + shDy, 0, scale, scale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, x, y, 0, scale, scale)
    end

    -- Camada de FX por arte (brasas, glifos arcanos...) já usada na Coleção.
    if not inst._cachedArt then
        local ok, a = pcall(CardArt.resolve, inst)
        inst._cachedArt = ok and a or { bgPattern = nil }
    end
    pcall(CardAnimationLayer.draw, inst, inst._cachedArt, x, y, scale, scale)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Sleeve do booster pack (API do PackSleeve — require lazy, arquivo de outra frente).
local function drawPackArt(offer, ax, ay, aw, ah, alpha)
    local ok, PackSleeve = pcall(require, "src.ui.PackSleeve")
    if not ok or not PackSleeve then return end
    local sw, sh = PackSleeve.getDimensions()
    if not sw or sw <= 0 then return end
    local scale = math.min(aw / sw, ah / sh)
    PackSleeve.drawAt(offer.id, offer.kind,
        math.floor(ax + aw / 2), math.floor(ay + ah / 2), scale, alpha)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Relíquia: MESMA composição do tile da vitrine (pedestal + halo na cor do
-- efeito + sprite apoiado). Antes era só o PNG centrado no vazio — a peça
-- flutuava no escuro e a coluna parecia inacabada ao lado da carta grande,
-- que tem moldura e sombra. Uma composição só, dois lugares.
local function drawVoucherArt(offer, ax, ay, aw, ah, alpha)
    local t = love.timer.getTime()
    UpgradeTile.drawArt(offer, { x = ax, y = ay, w = aw, h = ah }, {
        alpha = alpha,
        glow = 0.8,
        bob = reducedMotion() and 0 or (math.sin(t * 1.4) * 2),
        -- O PREVIEW TAMBEM ANIMA. Este painel e o lugar onde o jogador PARA
        -- pra decidir se compra — a peca maior e parada, ao lado do tile
        -- pequeno que se mexia, lia como se a grande tivesse travado.
        -- Pedido do dono (Set/2026). `time` compartilha o relogio com o tile,
        -- entao os dois ficam no MESMO frame da animacao: duas copias da
        -- mesma peca fora de fase na mesma tela seriam pior que nenhuma.
        animate = true,
        time = t,
    })
end

-- ============================================================================
-- TEXTO
-- ============================================================================

-- Quebra o texto em linhas reais: respeita "\n" explícito E o wrap por largura.
-- Efeitos que a DESCRIÇÃO ainda não diz. Desde a auditoria carta a carta
-- (descrição = efeito real nos 5 idiomas) a lista "Efeitos:" repetia, palavra
-- por palavra, a frase logo acima ("Ganha 5 de Bloqueio" duas vezes) — ruído
-- puro no painel da loja. Só sobra o que acrescenta informação.
local function normalized(text)
    return (require("src.i18n.TextCase").lower(tostring(text or "")):gsub("[%p%s]+", " "))
end

local function extraEffects(inst, desc)
    local out = {}
    if not (inst and inst.effects) then return out end
    local hay = normalized(desc)
    for _, e in ipairs(inst.effects) do
        local txt = I18n.effectDesc(e)
        if txt and txt ~= "" and not hay:find(normalized(txt), 1, true) then
            out[#out + 1] = txt
        end
    end
    return out
end

local function wrapLines(text, font, w)
    local out = {}
    for seg in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
        local _, wrapped = font:getWrap(seg, w)
        if #wrapped == 0 then out[#out + 1] = "" end
        for _, l in ipairs(wrapped) do out[#out + 1] = l end
    end
    return out
end

-- Escreve e devolve o novo cursor Y; para de desenhar ao passar do limite.
--
-- ⚠️ NÃO usa printf multi-linha: o printf da LÖVE avança exatamente
-- font:getHeight() por linha, ou seja ZERO entrelinha. Com a fonte pixel
-- (Press Start 2P) isso encosta uma linha na outra e o texto parece
-- sobreposto (defeito reportado no estado neutro do painel). Aqui cada linha
-- é impressa individualmente com entrelinha explícita.
local LINE_GAP = 6

local function line(text, font, color, x, y, w, limit, alpha, align)
    if y > limit then return y end
    love.graphics.setFont(font)
    setC(color, alpha)
    local lines = wrapLines(text, font, w)
    local lh = font:getHeight() + LINE_GAP
    for i, l in ipairs(lines) do
        local ly = y + (i - 1) * lh
        -- v5: a linha inteira tem que caber (antes só o topo era conferido e a
        -- última linha podia invadir o botão)
        if ly + font:getHeight() > limit then return ly end
        love.graphics.printf(l, x, ly, w, align or "left")
    end
    return y + #lines * lh
end

local function typeLabelFor(payload)
    if payload.kind == "pack" then
        return I18n.t("reward.detail_type_pack", nil, "Pacote")
    elseif payload.kind == "voucher" then
        return I18n.t("reward.detail_type_voucher", nil, "Relíquia")
    end
    local inst = payload.instance
    local t = (inst and inst.type) or "unknown"
    return I18n.t("card_type." .. t, nil, I18n.t("card_type.unknown", nil, "CARTA"))
end

-- ============================================================================
-- DRAW
-- ============================================================================

function CardDetailPanel.draw(rect, payload, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    if alpha <= 0.01 then return end

    local x, y = math.floor(rect.x), math.floor(rect.y)
    local w, h = math.floor(rect.w), math.floor(rect.h)
    if w < 60 or h < 80 then return end

    -- FUNDO, NÃO MOLDURA (correção Jul/2026 — "a carta expandida ficou muito
    -- feia, muito estranha"): o painel usava a moldura dourada canônica do
    -- UiPanel. Como a carta JÁ é um retângulo dourado ornamentado, os dois
    -- viravam um duplo enquadramento concêntrico, e o rodapé da carta
    -- ("DEFESA 5") encostava na borda externa parecendo erro.
    -- Agora: fundo escurecido + um único filete vertical separando da grade.
    -- A carta fica sozinha em campo, destacada pela sombra projetada dela.
    if opts.chrome ~= false then
        love.graphics.setColor(0, 0, 0, 0.30)
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        setC(Palette.AGED_GOLD_DARK, 0.55)
        love.graphics.setLineWidth(1)
        love.graphics.line(x, y + 10, x, y + h - 10)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local F = fontTier(w)
    local PAL = opts.parchment and PARCHMENT_PAL or DARK_PAL
    local textX = x + PAD
    local textW = w - PAD * 2
    local footerH = opts.footerH or 0
    local bottom = y + h - footerH - PAD

    -- ===== Estado neutro: rede de segurança =====
    -- Na prática a loja PRÉ-FOCA a primeira oferta ao abrir (ver
    -- CardRewardScreen:_prefocusDetail), então este estado só aparece em caso
    -- de borda — por exemplo tudo comprado. Mesmo assim ele fala, não fica um
    -- buraco preto: o texto é centralizado no eixo vertical do painel.
    if not payload or not payload.offer then
        local msg = opts.emptyHint
            or I18n.t("reward.detail_empty", nil,
                      "Passe o mouse sobre uma oferta para ver os detalhes aqui")
        local font = FontManager.getFont(F.desc)
        local lines = wrapLines(msg, font, textW)
        local lh = font:getHeight() + LINE_GAP
        local blockY = y + math.floor((h - #lines * lh) / 2)
        love.graphics.setFont(font)
        setC(PAL.dim, 0.75 * alpha)
        for i, l in ipairs(lines) do
            love.graphics.printf(l, textX, blockY + (i - 1) * lh, textW, "center")
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local offer = payload.offer
    local inst = payload.instance

    -- ===== CONTEÚDO (resolvido ANTES de medir/desenhar) =====
    local desc = payload.kind == "card"
        and I18n.cardDesc({ id = offer.id, description = offer.description })
        or offer.description
    if not desc or desc == "" then
        desc = I18n.t("card_info.no_desc", nil, "")
    end
    local displayName = payload.kind == "card"
        and I18n.cardName({ id = offer.id, name = offer.name })
        or offer.name or "?"
    local extras = (payload.kind == "card") and extraEffects(inst, desc) or {}
    local chipTxt = (payload.kind == "voucher") and UpgradeTile.effectLabel(offer) or nil
    local flavor = (payload.kind == "voucher") and UpgradeTile.flavor(offer) or nil
    -- Linha meta: TIPO · RARIDADE (· PREÇO). Loja v5: o preço já está no
    -- botão COMPRAR · $N logo abaixo e na plaquinha do objeto; repetir na
    -- legenda era a terceira cópia (opts.priceOnButton tira daqui).
    local typeLabel = typeLabelFor(payload)
    local rarityLabel = offer.rarity and I18n.t("rarity." .. offer.rarity, nil, offer.rarity) or nil
    local priceLabel = (offer.cost or 0) > 0 and ("$" .. tostring(offer.cost))
        or I18n.t("reward.detail_free", nil, "Grátis")
    local typeColor = inst and PAL.typeColor(Palette.forCardType(inst.type)) or PAL.dim
    local segs = { { typeLabel, typeColor } }
    if rarityLabel then segs[#segs + 1] = { rarityLabel, PAL.rarity(offer.rarity) } end
    if not opts.priceOnButton then
        segs[#segs + 1] = { priceLabel, opts.canAfford == false and Palette.BLOOD or PAL.price }
    end
    local sep = "  ·  "
    local joined = segs[1][1]
    for i = 2, #segs do joined = joined .. sep .. segs[i][1] end
    local statParts = {}
    if payload.kind == "card" and inst then
        statParts[#statParts + 1] = { I18n.t("card_info.cost", nil, "Custo: ") .. tostring(inst.cost or 0), PAL.mana }
        if inst.type == "attack" and (inst.attack or 0) > 0 then
            statParts[#statParts + 1] = { I18n.t("card_info.damage", nil, "Dano: ") .. tostring(inst.attack), Palette.BLOOD }
        elseif inst.type == "defense" and (inst.defense or 0) > 0 then
            statParts[#statParts + 1] = { I18n.t("card_info.defense", nil, "Defesa: ") .. tostring(inst.defense), PAL.defense }
        end
    end
    local affinityTxt = (offer.affinity and offer.affinityTags)
        and I18n.t("reward.affinity_line", { tags = table.concat(offer.affinityTags, ", ") },
            "Afinidade com seu deck: " .. table.concat(offer.affinityTags, ", ")) or nil

    -- ===== MEDIDA (Loja v5, briefing item 8: "o conteúdo não pode colidir
    -- com o botão, sair do painel ou exigir uma fonte minúscula"). Mede o
    -- bloco de texto com as MESMAS regras do desenho; quem cede primeiro é
    -- a ARTE (até 45% do teto), depois um degrau de fonte (nunca abaixo de
    -- 8 na descrição). O texto nunca é cortado no meio sem aviso.
    local function linesH(text, font, w)
        return #wrapLines(text, font, w) * (font:getHeight() + LINE_GAP)
    end
    local function statsLayout(Fx)
        if #statParts == 0 then return 0, nil, false end
        local texts = {}
        for _, p in ipairs(statParts) do texts[#texts + 1] = p[1] end
        local half = math.floor(textW / math.max(1, #statParts)) - 8
        local f, _, fits = fitFont(texts, half, Fx.stat, math.max(6, Fx.stat - 4))
        if fits or #statParts == 1 then return f:getHeight() + 8, f, true end
        f = fitFont(texts, textW, Fx.stat, math.max(6, Fx.stat - 4))
        return (f:getHeight() + 4) * #statParts + 4, f, false
    end
    local function textBlockH(Fx)
        local hgt = linesH(displayName, FontManager.getFont(Fx.name), textW) + 8
        local mf = fitFont({ joined }, textW, Fx.meta, math.max(6, Fx.meta - 3))
        hgt = hgt + mf:getHeight() + 10
        hgt = hgt + (statsLayout(Fx))
        if chipTxt then hgt = hgt + FontManager.getFont(Fx.stat):getHeight() + 16 end
        hgt = hgt + 8 + linesH(desc, FontManager.getFont(Fx.desc), textW)
        if flavor then hgt = hgt + 6 + linesH('"' .. flavor .. '"', FontManager.getFont(Fx.tiny), textW) end
        if #extras > 0 then
            local ft = FontManager.getFont(Fx.tiny)
            hgt = hgt + 4 + ft:getHeight() + LINE_GAP
            for i, txt in ipairs(extras) do
                if i <= 4 then hgt = hgt + linesH("- " .. txt, ft, textW - 6) end
            end
        end
        if affinityTxt then hgt = hgt + 4 + linesH(affinityTxt, FontManager.getFont(Fx.tiny), textW) end
        return hgt
    end
    local avail = h - footerH - PAD * 2 - 18
    -- Fração ADAPTATIVA da arte (com pouco texto a arte cresce), teto do
    -- pergaminho (opts.artMaxH) e piso de 45% do teto.
    local artCap = math.floor((h - footerH) * 0.60)
    if opts.artMaxH then artCap = math.min(artCap, math.floor(opts.artMaxH)) end
    local artMin = math.floor(artCap * 0.45)
    local tiers = { F }
    for _, tf in ipairs({ { name = 13, meta = 9, stat = 11, desc = 9, tiny = 8 },
                          { name = 11, meta = 8, stat = 9, desc = 8, tiny = 7 } }) do
        if tf.desc < tiers[#tiers].desc or tf.name < tiers[#tiers].name then tiers[#tiers + 1] = tf end
    end
    local artH, textH, fits
    for _, tf in ipairs(tiers) do
        F = tf
        textH = textBlockH(F)
        artH = math.min(artCap, avail - textH)
        fits = artH >= artMin
        if fits then break end
    end
    if not fits then artH = artMin end
    artH = math.max(0, math.floor(artH))
    local artY = y + PAD
    local artW = textW
    if payload.kind == "card" then
        drawCardArt(inst, textX, artY, artW, artH, alpha)
    elseif opts.objectArt and opts.objectArt(payload, textX, artY, artW, artH, alpha) then
        -- a loja desenha o MESMO sprite da mesa (mesma arte, mesmo espelho)
    elseif payload.kind == "pack" then
        drawPackArt(offer, textX, artY, artW, artH, alpha)
    else
        drawVoucherArt(offer, textX, artY, artW, artH, alpha)
    end

    -- Respiro real entre a arte e a legenda.
    local cy = artY + artH + 18
    local textTop = cy

    -- ===== Nome (o título: maior peso) =====
    cy = line(displayName, FontManager.getFont(F.name), PAL.name,
              textX, cy, textW, bottom, alpha, "center")
    divider(textX, cy + 2, textW, alpha, PAL.divider)
    cy = cy + 8

    -- ===== Meta: TIPO · RARIDADE (peso menor, centrado) =====
    do
        local metaFont = fitFont({ joined }, textW, F.meta, math.max(6, F.meta - 3))
        love.graphics.setFont(metaFont)
        local total = 0
        for i, sg in ipairs(segs) do
            total = total + metaFont:getWidth(sg[1])
            if i < #segs then total = total + metaFont:getWidth(sep) end
        end
        local sx = textX + math.floor((textW - total) / 2)
        for i, sg in ipairs(segs) do
            setC(sg[2], alpha)
            love.graphics.print(sg[1], sx, cy)
            sx = sx + metaFont:getWidth(sg[1])
            if i < #segs then
                setC(PAL.sep, alpha)
                love.graphics.print(sep, sx, cy)
                sx = sx + metaFont:getWidth(sep)
            end
        end
        cy = cy + metaFont:getHeight() + 10
    end

    -- ===== Stats (custo de mana / dano / armadura) =====
    if #statParts > 0 then
        local hgt, statFont, side = statsLayout(F)
        love.graphics.setFont(statFont)
        if side then
            local gap = math.floor(textW / math.max(1, #statParts))
            for i, p in ipairs(statParts) do
                setC(p[2], alpha)
                love.graphics.printf(p[1], textX + (i - 1) * gap, cy, gap,
                    #statParts == 1 and "center" or (i == 1 and "left" or "right"))
            end
        else
            local yy = cy
            for _, p in ipairs(statParts) do
                setC(p[2], alpha)
                love.graphics.printf(p[1], textX, yy, textW, "center")
                yy = yy + statFont:getHeight() + 4
            end
        end
        cy = cy + hgt
    end

    -- ===== Chip do EFEITO (relíquia) =====
    if chipTxt then
        local th = UpgradeTile.theme(offer)
        local f = FontManager.getFont(F.stat)
        local chipH = f:getHeight() + 10
        local chipW = math.min(textW, f:getWidth(chipTxt) + 28)
        local chipX = textX + math.floor((textW - chipW) / 2)
        setC(Palette.darken(Palette.INK, 0.2), alpha * 0.85)
        love.graphics.rectangle("fill", chipX, cy, chipW, chipH, 3, 3)
        setC(th.accent, alpha * 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", chipX + 0.5, cy + 0.5, chipW - 1, chipH - 1, 3, 3)
        love.graphics.setFont(f)
        setC(th.text, alpha)
        love.graphics.printf(chipTxt, chipX, cy + 5, chipW, "center")
        cy = cy + chipH + 6
    end

    divider(textX, cy, textW, alpha * 0.8, PAL.divider)
    cy = cy + 8

    -- ===== Descrição (o corpo: as regras) =====
    cy = line(desc, FontManager.getFont(F.desc), PAL.body, textX, cy, textW, bottom, alpha)

    -- ===== Linha de grimório (relíquia): voz, peso mínimo =====
    if flavor then
        cy = cy + 6
        cy = line('"' .. flavor .. '"', FontManager.getFont(F.tiny),
                  PAL.dim, textX, cy, textW, bottom, alpha * 0.9, "center")
    end

    -- ===== Efeitos que a descrição AINDA não diz (até 4) =====
    if #extras > 0 then
        cy = cy + 4
        cy = line(I18n.t("card_info.effects", nil, "Efeitos"),
                  FontManager.getFont(F.tiny), PAL.head, textX, cy, textW, bottom, alpha)
        local effFont = FontManager.getFont(F.tiny)
        for i, txt in ipairs(extras) do
            if i > 4 then break end
            cy = line("- " .. txt, effFont, PAL.body, textX + 6, cy, textW - 6, bottom, alpha)
        end
    end

    -- ===== Afinidade: POR QUE esta oferta apareceu =====
    if affinityTxt then
        cy = cy + 4
        cy = line(affinityTxt, FontManager.getFont(F.tiny), PAL.affinity, textX, cy, textW, bottom, alpha)
    end

    -- Rodapé discreto de contexto (pré-foco / última observada), ancorado no
    -- pé do painel; só se couber sem encostar no texto.
    if opts.stale and opts.staleHint then
        local f = FontManager.getFont(F.tiny)
        local lines = wrapLines(opts.staleHint, f, textW)
        local lh = f:getHeight() + LINE_GAP
        local topY = y + h - footerH - 8 - #lines * lh
        if topY >= cy + 4 then
            love.graphics.setFont(f)
            setC(PAL.dim, (opts.parchment and 0.8 or 0.45) * alpha)
            for i, l in ipairs(lines) do
                love.graphics.printf(l, textX, topY + (i - 1) * lh, textW, "center")
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    -- devolve a medida (test_shop_scene confere que nada sai do painel)
    return { fits = fits and cy <= bottom + 1, contentBottom = cy, bottom = bottom, artH = artH,
             textTop = textTop, font = F }
end

return CardDetailPanel
