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
--   }

local CardDetailPanel = {}

local FontManager        = require("src.ui.FontManager")
local Palette            = require("src.ui.Palette")
local CardMesh           = require("src.ui.CardMesh")
local CardArt            = require("src.ui.CardArt")
local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")
local ImageCache         = require("src.ui.ImageCache")
local UpgradeTile        = require("src.ui.UpgradeTile")
local I18n               = require("src.i18n.I18n")

local PAD = 14

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

local function divider(x, y, w, alpha)
    setC(Palette.AGED_GOLD, 0.55 * alpha)
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
        if ly > limit then return ly end
        love.graphics.printf(l, x, ly, w, align or "left")
    end
    return y + #lines * lh
end

local function typeLabelFor(payload)
    local offer = payload.offer
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
        setC(Palette.PARCHMENT, 0.55 * alpha)
        for i, l in ipairs(lines) do
            love.graphics.printf(l, textX, blockY + (i - 1) * lh, textW, "center")
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local offer = payload.offer
    local inst = payload.instance

    -- Descrição resolvida ANTES da arte: quanto texto existe decide quanto
    -- espaço sobra pra ilustração (ver artFrac abaixo).
    local desc = payload.kind == "card"
        and I18n.cardDesc({ id = offer.id, description = offer.description })
        or offer.description
    if not desc or desc == "" then
        desc = I18n.t("card_info.no_desc", nil, "")
    end

    -- ===== Arte (topo) =====
    -- Fração ADAPTATIVA: com pouco texto a carta cresce e ocupa o painel; com
    -- muito (descrição longa + lista de efeitos) ela cede espaço. Fração fixa
    -- deixava um vão morto no pé do painel nas cartas de descrição curta —
    -- exatamente o "espaço morto" reportado.
    local descLineCount = #wrapLines(desc, FontManager.getFont(F.desc), textW)
    if payload.kind == "card" and inst and inst.effects then
        descLineCount = descLineCount + math.min(4, #inst.effects) + 1
    elseif payload.kind == "voucher" then
        -- Relíquia agora traz chip de efeito + linha de grimório abaixo da
        -- descrição: a arte tem que ceder a mesma altura que eles ocupam,
        -- senão o texto encosta no rodapé dos botões de compra.
        local flavor = UpgradeTile.flavor(offer)
        if UpgradeTile.effectLabel(offer) then descLineCount = descLineCount + 2 end
        if flavor then
            descLineCount = descLineCount
                + #wrapLines(flavor, FontManager.getFont(F.tiny), textW)
        end
    end
    local artFrac = 0.44
    if descLineCount <= 3 then artFrac = 0.60
    elseif descLineCount <= 6 then artFrac = 0.52 end
    local artH = math.floor((h - footerH) * artFrac)
    local artY = y + PAD
    local artW = textW
    if payload.kind == "card" then
        drawCardArt(inst, textX, artY, artW, artH, alpha)
    elseif payload.kind == "pack" then
        drawPackArt(offer, textX, artY, artW, artH, alpha)
    else
        drawVoucherArt(offer, textX, artY, artW, artH, alpha)
    end

    -- Respiro real entre a arte e a legenda: colados, os dois liam como duas
    -- faixas empilhadas em vez de uma composição só.
    local cy = artY + artH + 18

    -- ===== Nome =====
    local displayName = payload.kind == "card"
        and I18n.cardName({ id = offer.id, name = offer.name })
        or offer.name or "?"
    cy = line(displayName, FontManager.getFont(F.name), Palette.AGED_GOLD_LIGHT,
              textX, cy, textW, bottom, alpha, "center")

    divider(textX, cy + 2, textW, alpha)
    cy = cy + 8

    -- ===== Linha meta: TIPO · RARIDADE · PREÇO =====
    -- Raridade vive AQUI e no badge do slot: o jogador vê o que está
    -- comprando sem depender de decorar cores de borda.
    do
        local typeLabel = typeLabelFor(payload)
        local rarityLabel = offer.rarity
            and I18n.t("rarity." .. offer.rarity, nil, offer.rarity) or nil
        local priceLabel = (offer.cost or 0) > 0 and ("$" .. tostring(offer.cost))
            or I18n.t("reward.detail_free", nil, "Grátis")

        -- Cor do tipo CLAREADA: as cores canônicas (STEEL #4a5260, BLOOD
        -- #8b1e1e) foram desenhadas pra acentuar molduras claras de carta —
        -- cruas sobre o miolo INK do painel ficam quase ilegíveis (defeito
        -- visto na captura: "DEFESA" sumindo no fundo).
        local typeColor = inst and Palette.lighten(Palette.forCardType(inst.type), 0.45)
            or Palette.PARCHMENT
        local segs = { { typeLabel, typeColor } }
        if rarityLabel then
            table.insert(segs, { rarityLabel, Palette.forRarity(offer.rarity) })
        end
        -- O PREÇO entra na legenda em vez de ocupar uma linha centrada só
        -- dele: eram três faixas empilhadas (nome / meta / preço) onde cabia
        -- uma legenda só. Cor segue a regra de sempre — dourado se dá pra
        -- pagar, sangue se não.
        table.insert(segs, { priceLabel,
            opts.canAfford == false and Palette.BLOOD or Palette.AGED_GOLD_LIGHT })

        -- Segmentos coloridos centrados, separados por "·". A fonte encolhe
        -- se a linha inteira (tipo + separador + raridade) não couber.
        local sep = "  ·  "
        local joined = segs[1][1]
        for i = 2, #segs do joined = joined .. sep .. segs[i][1] end
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
                setC(Palette.PARCHMENT_DARK, alpha)
                love.graphics.print(sep, sx, cy)
                sx = sx + metaFont:getWidth(sep)
            end
        end
        cy = cy + metaFont:getHeight() + 10
    end

    -- ===== Stats (custo de mana / dano / armadura / forja) =====
    if payload.kind == "card" and inst then
        local parts = {}
        table.insert(parts, {
            I18n.t("card_info.cost", nil, "Custo: ") .. tostring(inst.cost or 0),
            Palette.MANA_LIGHT or Palette.PARCHMENT_LIGHT })
        if inst.type == "attack" and (inst.attack or 0) > 0 then
            table.insert(parts, {
                I18n.t("card_info.damage", nil, "Dano: ") .. tostring(inst.attack),
                Palette.BLOOD })
        elseif inst.type == "defense" and (inst.defense or 0) > 0 then
            table.insert(parts, {
                I18n.t("card_info.defense", nil, "Defesa: ") .. tostring(inst.defense),
                Palette.STEEL_LIGHT })
        end
        -- Lado a lado SÓ se os dois rótulos couberem de fato na metade da
        -- coluna; senão a fonte encolhe e, em último caso, empilha. Sem isso
        -- o printf quebrava "Verteid.: 10" e o "10" caía sobre a descrição.
        local texts = {}
        for _, p in ipairs(parts) do texts[#texts + 1] = p[1] end
        local half = math.floor(textW / math.max(1, #parts)) - 8
        local statFont, statSize, fits = fitFont(texts, half, F.stat, math.max(6, F.stat - 4))
        love.graphics.setFont(statFont)
        local lineH = statFont:getHeight() + 4

        if fits or #parts == 1 then
            local gap = math.floor(textW / math.max(1, #parts))
            for i, p in ipairs(parts) do
                setC(p[2], alpha)
                love.graphics.printf(p[1], textX + (i - 1) * gap, cy, gap,
                    #parts == 1 and "center" or (i == 1 and "left" or "right"))
            end
            cy = cy + lineH + 4
        else
            statFont = fitFont(texts, textW, F.stat, math.max(6, F.stat - 4))
            love.graphics.setFont(statFont)
            lineH = statFont:getHeight() + 4
            for _, p in ipairs(parts) do
                setC(p[2], alpha)
                love.graphics.printf(p[1], textX, cy, textW, "center")
                cy = cy + lineH
            end
            cy = cy + 4
        end
    end

    -- ===== Chip do EFEITO (relíquia) =====
    -- O painel da relíquia era nome + "Relíquia · $5" + uma linha de texto, e
    -- depois meio painel de vazio — enquanto o da carta tem custo, dano e
    -- lista de efeitos. Aqui o NÚMERO ganha o mesmo peso que tem no tile:
    -- uma placa com a cor do efeito, para o jogador comparar de longe.
    if payload.kind == "voucher" then
        local chipTxt = UpgradeTile.effectLabel(offer)
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
    end

    divider(textX, cy, textW, alpha * 0.8)
    cy = cy + 8

    -- ===== Descrição =====
    cy = line(desc, FontManager.getFont(F.desc), Palette.PARCHMENT_LIGHT,
              textX, cy, textW, bottom, alpha)

    -- ===== Linha de grimório (relíquia) =====
    -- Ocupa o vão que sobrava sob a descrição curta com a coisa certa: voz,
    -- não enchimento. Cai fora sozinha se não houver espaço.
    if payload.kind == "voucher" then
        local flavor = UpgradeTile.flavor(offer)
        if flavor and cy < bottom - 10 then
            cy = cy + 6
            line('"' .. flavor .. '"', FontManager.getFont(F.tiny),
                 Palette.PARCHMENT, textX, cy, textW, bottom, alpha * 0.8, "center")
        end
    end

    -- ===== Efeitos (até 4, como na inspeção) =====
    if payload.kind == "card" and inst and inst.effects and #inst.effects > 0 then
        cy = cy + 4
        cy = line(I18n.t("card_info.effects", nil, "Efeitos"),
                  FontManager.getFont(F.tiny), Palette.AGED_GOLD,
                  textX, cy, textW, bottom, alpha)
        local effFont = FontManager.getFont(F.tiny)
        for i, e in ipairs(inst.effects) do
            if i > 4 or cy > bottom then break end
            cy = line("- " .. I18n.effectDesc(e), effFont, Palette.PARCHMENT,
                      textX + 6, cy, textW - 6, bottom, alpha)
        end
    end

    -- ===== Afinidade: POR QUE esta oferta apareceu =====
    if offer.affinity and offer.affinityTags and cy < bottom then
        cy = cy + 4
        line(I18n.t("reward.affinity_line", { tags = table.concat(offer.affinityTags, ", ") },
                    "Afinidade com seu deck: " .. table.concat(offer.affinityTags, ", ")),
             FontManager.getFont(F.tiny), Palette.AGED_GOLD_LIGHT,
             textX, cy, textW, bottom, alpha)
    end

    -- Rodapé discreto de contexto (pré-foco / última observada). Ancorado no
    -- pé do painel: o bloco INTEIRO é medido antes (pode quebrar em 2 linhas
    -- num painel estreito) — com printf multi-linha ele saía pela borda de
    -- baixo com as linhas coladas.
    if opts.stale and opts.staleHint then
        local f = FontManager.getFont(F.tiny)
        local lines = wrapLines(opts.staleHint, f, textW)
        local lh = f:getHeight() + LINE_GAP
        local topY = y + h - footerH - 8 - #lines * lh
        love.graphics.setFont(f)
        setC(Palette.PARCHMENT, 0.45 * alpha)
        for i, l in ipairs(lines) do
            love.graphics.printf(l, textX, topY + (i - 1) * lh, textW, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return CardDetailPanel
