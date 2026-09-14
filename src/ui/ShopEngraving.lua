-- src/ui/ShopEngraving.lua
-- A gramatica UNICA de "quanto custa" e "o que faz" na prateleira da loja.
--
-- POR QUE ESTE MODULO EXISTE
-- O dono olhou a loja e disse que o preco e o efeito estavam "com cara de IA"
-- (Set/2026). Olhando as capturas, o diagnostico e concreto e tem tres partes:
--
--   1) DIALETO ERRADO. A carta ja mostrava o preco como MOEDA cunhada no canto
--      superior direito -- disco de ouro com aro escuro, encostado na moldura.
--      O pacote e o voucher, na MESMA fileira da MESMA tela, mostravam o preco
--      como retangulo de 1px flutuando embaixo do objeto. Duas gramaticas pra
--      mesma informacao a 40px de distancia: a segunda so podia ler como
--      componente de template que caiu ali.
--   2) FORMA SUAVE EM TELA DE PIXEL. Os retangulos usavam cantos arredondados
--      do love.graphics (vetor anti-aliasado) e o disco da carta usava
--      love.graphics.circle -- tambem AA. Borda macia no meio de arte de borda
--      dura e o tell mais rapido de "isso nao foi desenhado, foi gerado".
--   3) SUPERFICIE MORTA. Fundo chapado (ou degrade continuo), moldura de 1px
--      perfeitamente simetrica, texto mecanicamente centrado. O resto do jogo
--      -- ver src/ui/card/components/CardStatsFooter.lua -- da MATERIA a cada
--      placa: bevel direcional (luz em cima/esquerda, sombra embaixo/direita),
--      cunhas de canto, grao por hash e desgaste concentrado nas bordas.
--
-- A correcao nao foi inventar forma nova: foi falar o dialeto que o jogo ja
-- tem. `priceSeal` e a moeda da carta, agora desenhada em pixel (degraus) e em
-- cores da Palette; `effectStrip` e a placa gravada do rodape da carta,
-- parametrizada. Carta, pacote e reliquia passam pelas MESMAS duas funcoes.
--
-- CACHE: a placa de efeito tem grao e desgaste por pixel -- caro demais por
-- frame. Ela e rasterizada num canvas com chave (w|h|texto|accent|seed). A
-- chave inclui as dimensoes, entao um resize nunca reaproveita bitmap velho;
-- ainda assim `clearCache()` existe e e chamado no resize da loja, pra nao
-- acumular canvas de tamanhos mortos (ui_layout_invariants, secao 2).

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local FontManager = require("src.ui.FontManager")
local TextFit     = require("src.ui.TextFit")

local ShopEngraving = {}

local function withA(c, a)
    return { c[1], c[2], c[3], (c[4] or 1) * (a or 1) }
end

-- Hash estavel string -> inteiro. Usado pra que CADA item envelheca com o
-- proprio padrao de desgaste, e sempre o mesmo entre re-renders (nada de
-- random no draw -- captura de tela tem que ser reproduzivel).
local function seedOf(s)
    local h = 0
    for i = 1, #tostring(s or "") do
        h = (h + tostring(s):byte(i) * i * 31) % 9973
    end
    return h
end
ShopEngraving.seedOf = seedOf

-- ============================================================================
-- MOEDA DE PRECO
-- ============================================================================
-- Raio proporcional ao objeto (um disco de tamanho fixo come a ilustracao no
-- tile compacto e some no tile grande) E ao TAMANHO DO NUMERO.
--
-- A segunda parte custou uma rodada: com raio fixo, "$25" so cabia encolhendo
-- a fonte pro minimo, e o numero virava dois pontinhos ilegiveis no disco --
-- o preco, que e a razao de a moeda existir, era a unica coisa que nao dava
-- pra ler. Moeda de valor maior e MAIOR; e assim que moeda funciona.
-- `cost` nil = reserva o pior caso (3 digitos), pra quem so precisa do espaco.
function ShopEngraving.sealRadius(objW, cost)
    local r = math.max(8, math.min(14, math.floor((objW or 0) * 0.13)))
    local digits = cost and #tostring(math.max(0, math.floor(cost))) or 3
    if digits >= 2 then r = r + math.min(4, (digits - 1) * 2) end
    return r
end

-- Onde a moeda encosta, dado o retangulo do objeto: canto superior-direito,
-- mordendo a moldura -- exatamente como na carta. Devolve cx, cy, r.
function ShopEngraving.sealAnchor(rect, cost)
    local r = ShopEngraving.sealRadius(rect.w, cost)
    return math.floor(rect.x + rect.w - r), math.floor(rect.y + r), r
end

-- Retangulo do CORPO da moeda (pro layout reservar espaco e pro validate).
-- Deliberadamente NAO inclui a sombra projetada: a moeda descansa na quina e
-- a sombra dela cai 2px pra fora do objeto, como na carta. O que nao pode
-- vazar e o disco.
-- Sem `cost`, devolve a reserva do pior caso -- e o que o layout quer: a
-- coluna do nome nao pode depender de quanto o item custa hoje.
function ShopEngraving.sealRect(rect, cost)
    local cx, cy, r = ShopEngraving.sealAnchor(rect, cost)
    return { x = cx - r, y = cy - r, w = r * 2 + 1, h = r * 2 + 1 }
end

-- Moeda cunhada. opts = { afford = bool, alpha = 0..1, glow = 0..1 }
--
-- Cinco camadas, todas em degraus: sombra projetada, aro de tinta, corpo com
-- luz direcional (lerp POR LINHA, nunca shader), serrilha da borda e o numero
-- gravado -- tinta escura com realce claro embaixo, que e como um relevo
-- batido se le de verdade.
function ShopEngraving.priceSeal(cx, cy, r, cost, opts)
    opts = opts or {}
    local alpha  = opts.alpha or 1
    local afford = opts.afford ~= false
    if alpha <= 0.01 or r < 4 then return end
    cx, cy, r = math.floor(cx), math.floor(cy), math.floor(r)

    local body = afford and Palette.AGED_GOLD or Palette.BLOOD
    local rim  = afford and Palette.INK       or Palette.BLOOD_DARK

    -- Halo: so no hover/destaque. Em repouso a moeda nao brilha -- metal velho
    -- nao emite luz, e o halo permanente era mais uma camada sobre a arte.
    local glow = opts.glow or 0
    if glow > 0.01 then
        PixelCanvas.disc(cx, cy, r + 2,
            withA(Palette.lighten(body, 0.45), alpha * 0.30 * glow))
    end

    PixelCanvas.disc(cx + 2, cy + 2, r, withA(Palette.INK, alpha * 0.55))
    -- Aro de 2px em tinta: e o que separa a moeda do fundo claro do pergaminho
    -- E do fundo escuro da placa. Com 1px ela sumia nos dois.
    PixelCanvas.disc(cx, cy, r, withA(rim, alpha))
    -- Corpo: ouro de verdade (nao creme). A primeira versao clareava 50% no
    -- topo e a moeda lia como disco bege sem material nenhum.
    PixelCanvas.discShaded(cx, cy, r - 2,
        withA(Palette.lighten(body, 0.28), alpha),
        withA(Palette.darken(body, 0.50), alpha))

    -- Serrilha: 8 tiques no aro. E o detalhe que transforma "circulo dourado"
    -- em "moeda" -- e nao existe em nenhum componente de template.
    local milled = withA(Palette.lighten(body, 0.55), alpha * 0.8)
    for i = 0, 7 do
        local a = i * math.pi / 4 + math.pi / 8
        PixelCanvas.pixel(cx + math.floor(math.cos(a) * (r - 1) + 0.5),
                          cy + math.floor(math.sin(a) * (r - 1) + 0.5), milled)
    end
    -- Numero GRAVADO: glifo em tinta com realce claro 1px abaixo-direita.
    --
    -- O numero e a razao de a moeda existir: ele manda na moeda, nao o
    -- contrario. Passar por TextFit com a largura util do disco fazia "$25"
    -- desabar pro minimo de 8px e virar dois pontinhos ilegiveis (visto na
    -- captura, Set/2026). Aqui a fonte so desce um degrau, e o glifo pode
    -- invadir 1-2px do aro -- numero grande cunhado de borda a borda e
    -- exatamente como moeda antiga se le.
    local txt = "$" .. tostring(cost or 0)
    -- Fonte 11/9: no tamanho 10 o glifo "6" da fonte pixel rasteriza "G".
    local size = (r >= 12) and 11 or 9
    local font = FontManager.getFont(size)
    -- Folga de 6px: o glifo pode morder o aro, mas nao pode ser COMIDO por
    -- ele. "$25" em 11 media 29px num disco de 28 e as pontas sumiam.
    if size > 9 and font:getWidth(txt) > r * 2 - 6 then
        size = 9
        font = FontManager.getFont(size)
    end
    local fitted = txt
    love.graphics.setFont(font)
    local tx = cx - math.floor(font:getWidth(fitted) / 2)
    local ty = cy - math.floor(font:getHeight() / 2)
    local hi = afford and Palette.lighten(body, 0.75) or Palette.lighten(body, 0.55)
    love.graphics.setColor(hi[1], hi[2], hi[3], alpha * 0.8)
    love.graphics.print(fitted, tx + 1, ty + 1)
    local ink = afford and Palette.INK or Palette.PARCHMENT_LIGHT
    love.graphics.setColor(ink[1], ink[2], ink[3], alpha)
    love.graphics.print(fitted, tx, ty)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Atalho: carimba a moeda no canto do retangulo do objeto.
function ShopEngraving.stampPrice(rect, cost, opts)
    if (cost or 0) <= 0 then return end
    local cx, cy, r = ShopEngraving.sealAnchor(rect, cost)
    ShopEngraving.priceSeal(cx, cy, r, cost, opts)
end

-- ============================================================================
-- PLACA GRAVADA DO EFEITO
-- ============================================================================
-- Mesmo vocabulario do rodape da carta (CardStatsFooter): bevel direcional,
-- cunhas de canto, grao do material, desgaste nas bordas e um filete da cor do
-- efeito que ATRAVESSA a placa e termina em ponta de lanca de cada lado,
-- "apresentando" o texto. Nada de moldura de 1px simetrica.

-- Cunha de canto 4-2-1 (versao curta da do CardStatsFooter -- a placa do tile
-- tem ~14px de altura, a da carta tem 20).
local WEDGE = { 4, 2, 1 }
local function drawCornerWedge(x, y, dx, dy)
    for row = 0, #WEDGE - 1 do
        for col = 0, WEDGE[row + 1] - 1 do
            local c = (row + col >= WEDGE[1] - 1) and Palette.AGED_GOLD_DARK
                                                   or Palette.AGED_GOLD
            PixelCanvas.pixel(x + dx * col, y + dy * row, c)
        end
    end
    PixelCanvas.pixel(x, y, Palette.AGED_GOLD_LIGHT)
end

-- Ponta de lanca que arremata o filete junto ao texto (dir = -1 aponta pra
-- esquerda, 1 pra direita).
local function drawStripeEnd(x, cy, accent, dir)
    PixelCanvas.pixel(x, cy - 2, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(x - dir, cy - 1, Palette.AGED_GOLD)
    PixelCanvas.pixel(x, cy - 1, Palette.lighten(accent, 0.35))
    PixelCanvas.pixel(x + dir, cy - 1, Palette.AGED_GOLD)
    PixelCanvas.pixel(x - dir * 2, cy, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x - dir, cy, accent)
    PixelCanvas.pixel(x, cy, Palette.PARCHMENT_LIGHT)
    PixelCanvas.pixel(x + dir, cy, accent)
    PixelCanvas.pixel(x + dir * 2, cy, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x - dir, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x, cy + 1, Palette.darken(accent, 0.45))
    PixelCanvas.pixel(x + dir, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x, cy + 2, Palette.AGED_GOLD_DARK)
end

local RUST_TINT = { 0.55, 0.29, 0.12, 0.40 }

-- Desgaste: lascas de 2px deitadas concentradas nas bordas (onde a mao gasta
-- a placa) e ferrugem so grudada na moldura. Centro quase intocado -- pixel
-- solto no meio da chapa le como sujeira de render, nao como uso.
local function drawWear(w, h, seed)
    for y = 0, h - 1 do
        for x = 0, w - 2 do
            local edge = math.min(x, w - 1 - x, y, h - 1 - y)
            local r = (x * 7919 + y * 6271 + seed * 131) % 211
            local thresh = (edge <= 1) and 9 or ((edge <= 3) and 3 or 1)
            if r < thresh then
                PixelCanvas.pixel(x, y, { 0, 0, 0, 0.28 })
                PixelCanvas.pixel(x + 1, y, { 0, 0, 0, 0.16 })
            elseif r > 205 and edge == 0 then
                PixelCanvas.pixel(x, y, RUST_TINT)
            end
        end
    end
end

-- Rasteriza a placa (w x h) num canvas. Chamado so no miss do cache.
local function renderStrip(w, h, text, accent, seed)
    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas)

    -- Chapa: lerp POR LINHA (o degrade que o projeto aceita). O degrade de 8
    -- faixas da versao anterior deixava emendas horizontais visiveis.
    local top = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.22)
    for row = 0, h - 1 do
        PixelCanvas.hline(0, row, w, Palette.lerp(top, Palette.INK, row / math.max(1, h - 1)))
    end

    -- Grao do material: variacao densa e MUITO sutil por hash. E o que separa
    -- "superficie com materia" de "retangulo preenchido".
    for y = 1, h - 2 do
        for x = 1, w - 2 do
            local g = (x * 3557 + y * 2953 + seed * 41) % 17
            if g == 0 then
                PixelCanvas.pixel(x, y, { 1, 1, 1, 0.05 })
            elseif g == 1 then
                PixelCanvas.pixel(x, y, { 0, 0, 0, 0.11 })
            end
        end
    end

    local cy = math.floor(h / 2)

    -- Filete do efeito, 3 tons (luz de cima) -- a espinha da placa.
    PixelCanvas.hline(1, cy - 1, w - 2, Palette.lighten(accent, 0.25))
    PixelCanvas.hline(1, cy,     w - 2, accent)
    PixelCanvas.hline(1, cy + 1, w - 2, Palette.darken(accent, 0.55))

    -- Bevel direcional: luz em cima/esquerda, bronze embaixo/direita. Nunca
    -- moldura de tom unico -- e a diferenca entre "placa" e "borda de div".
    local bronze = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.45)
    PixelCanvas.hline(0, 0, w, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.vline(0, 0, h, Palette.AGED_GOLD)
    PixelCanvas.hline(0, h - 1, w, Palette.AGED_GOLD_DARK)
    PixelCanvas.vline(w - 1, 0, h, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(1, h - 2, w - 2, bronze)
    PixelCanvas.vline(w - 2, 1, h - 2, bronze)

    drawCornerWedge(1, 1,         1,  1)
    drawCornerWedge(w - 2, 1,    -1,  1)
    drawCornerWedge(1, h - 2,     1, -1)
    drawCornerWedge(w - 2, h - 2, -1, -1)

    drawWear(w, h, seed)

    -- Texto por cima, com contorno de tinta (le sobre filete e grao).
    local font, fitted = TextFit.fit(text, math.max(8, math.min(11, h - 5)), w - 26)
    love.graphics.setFont(font)
    local tw = font:getWidth(fitted)
    local tx = math.floor((w - tw) / 2)
    local ty = math.floor((h - font:getHeight()) / 2)

    -- As pontas de lanca "apresentam" a palavra; o filete some sob o texto.
    local pad = 4
    if tx - pad - 3 >= 3 then
        PixelCanvas.rect(tx - pad, cy - 1, tw + pad * 2, 3,
            Palette.lerp(top, Palette.INK, 0.5))
        drawStripeEnd(tx - pad - 3, cy, accent, -1)
        drawStripeEnd(tx + tw + pad + 3, cy, accent, 1)
    end

    FontManager.drawWithOutline(fitted, tx, ty,
        { Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2],
          Palette.PARCHMENT_LIGHT[3], 1 }, 1)

    PixelCanvas.endDraw()
    return canvas
end

-- ============================================================================
-- CARTUCHO DE VALOR (rotulo pequeno + numero grande)
-- ============================================================================
-- Mesma chapa da placa de efeito, em duas linhas. Substitui os "chips" de
-- CUSTO/DANO da tela de abertura de pacote, que eram retangulo preto a 45% com
-- contorno de 1px na cor do tipo -- o mesmo dialeto de formulario que o dono
-- reprovou na loja, na tela ao lado.
local function renderValuePlate(w, h, label, value, accent, seed)
    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas)

    local top = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.22)
    for row = 0, h - 1 do
        PixelCanvas.hline(0, row, w, Palette.lerp(top, Palette.INK, row / math.max(1, h - 1)))
    end
    for y = 1, h - 2 do
        for x = 1, w - 2 do
            local g = (x * 3557 + y * 2953 + seed * 41) % 17
            if g == 0 then
                PixelCanvas.pixel(x, y, { 1, 1, 1, 0.05 })
            elseif g == 1 then
                PixelCanvas.pixel(x, y, { 0, 0, 0, 0.11 })
            end
        end
    end

    local bronze = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.45)
    PixelCanvas.hline(0, 0, w, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.vline(0, 0, h, Palette.AGED_GOLD)
    PixelCanvas.hline(0, h - 1, w, Palette.AGED_GOLD_DARK)
    PixelCanvas.vline(w - 1, 0, h, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(1, h - 2, w - 2, bronze)
    PixelCanvas.vline(w - 2, 1, h - 2, bronze)
    drawCornerWedge(1, 1,         1,  1)
    drawCornerWedge(w - 2, 1,    -1,  1)
    drawCornerWedge(1, h - 2,     1, -1)
    drawCornerWedge(w - 2, h - 2, -1, -1)

    -- Rotulo pequeno em cima, filete do tipo embaixo dele, numero grande no
    -- resto. O filete separa sem precisar de uma segunda moldura.
    -- Texto GRAVADO na chapa: sombra de tinta 1px abaixo-direita, nunca
    -- contorno de 4 lados. Com o contorno, os vazios do "8" em 13px fechavam e
    -- o numero lia como "S" -- e o numero e a informacao inteira deste
    -- cartucho. Sobre chapa escura o contorno nem faz falta: o contraste ja
    -- esta la.
    local function engrave(text, font, x, y, color)
        love.graphics.setFont(font)
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.print(text, x + 1, y + 1)
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        love.graphics.print(text, x, y)
    end

    local fl = FontManager.getFont(8)
    engrave(label, fl, math.floor((w - fl:getWidth(label)) / 2), 4,
        { Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], 0.95 })
    local ruleY = 5 + fl:getHeight()
    PixelCanvas.hline(6, ruleY, w - 12, Palette.lighten(accent, 0.25))
    PixelCanvas.hline(6, ruleY + 1, w - 12, Palette.darken(accent, 0.55))

    local fv = FontManager.getFont(14)
    local vc = Palette.lighten(accent, 0.62)
    engrave(value, fv, math.floor((w - fv:getWidth(value)) / 2),
        ruleY + 3 + math.floor((h - ruleY - 3 - fv:getHeight()) / 2), vc)

    drawWear(w, h, seed + 7)
    PixelCanvas.endDraw()
    return canvas
end

-- ============================================================================
-- MARCADOR DE ETIQUETA (losango . TEXTO . losango)
-- ============================================================================
-- A loja ja etiquetava raridade e categoria assim ("* INCOMUM *"). A tela de
-- abertura de pacote desenhava a MESMA informacao numa caixinha preta com
-- contorno -- outra vez duas gramaticas pra mesma coisa. Aqui vira uma funcao
-- so, e o losango passou a ser desenhado em degraus (o polygon do love e
-- anti-aliasado; num rotulo de 5px isso vira um borrao).
local function pixelDiamond(cx, cy, r, color)
    Palette.set(color)
    for dy = -r, r do
        local hw = r - math.abs(dy)
        love.graphics.rectangle("fill", math.floor(cx - hw), math.floor(cy + dy),
            hw * 2 + 1, 1)
    end
end

function ShopEngraving.marker(cx, cy, text, color, fontSize, dia)
    local f = FontManager.getFont(fontSize or 8)
    love.graphics.setFont(f)
    local tw = f:getWidth(text)
    local fh = f:getHeight()
    dia = dia or 3
    local dx = math.floor(tw / 2) + 12
    for _, sx in ipairs({ -1, 1 }) do
        local px = cx + sx * dx
        pixelDiamond(px, cy + 1, dia, { 0, 0, 0, 0.8 })
        pixelDiamond(px, cy, dia, color)
    end
    local tx = cx - math.floor(tw / 2)
    local ty = cy - math.floor(fh / 2)
    love.graphics.setColor(0, 0, 0, 0.85)
    for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        love.graphics.print(text, tx + o[1], ty + o[2])
    end
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.print(text, tx, ty)
    love.graphics.setColor(1, 1, 1, 1)
end

local stripCache = {}
local stripCount = 0

local function colorKey(c)
    return ("%d.%d.%d"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

-- Placa de efeito. opts = { accent, alpha, dim (0..1), seed }
-- O conteudo NAO reage ao hover de proposito: metal gravado nao acende. O
-- destaque de foco mora na moldura do tile, no halo e no movimento da peca.
function ShopEngraving.effectStrip(x, y, w, h, text, opts)
    opts = opts or {}
    w, h = math.floor(w), math.floor(h)
    if w < 24 or h < 9 or not text or text == "" then return end
    local accent = opts.accent or Palette.AGED_GOLD
    local seed   = opts.seed or 0
    local key = ("%d|%d|%s|%s|%d"):format(w, h, text, colorKey(accent), seed)

    local canvas = stripCache[key]
    if not canvas then
        -- Teto de seguranca: se alguem chamar com texto variavel por frame,
        -- o cache zera em vez de comer VRAM em silencio.
        if stripCount > 96 then ShopEngraving.clearCache() end
        canvas = renderStrip(w, h, text, accent, seed)
        stripCache[key] = canvas
        stripCount = stripCount + 1
    end

    local a = opts.alpha or 1
    local d = opts.dim or 1
    -- Sombra de contato sob a placa (ela e um objeto parafusado, nao um
    -- recorte no fundo).
    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y) + h, w, 1)
    love.graphics.setColor(d, d, d, a)
    love.graphics.draw(canvas, math.floor(x), math.floor(y))
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cartucho de valor. opts = { accent, alpha, dim, seed }
function ShopEngraving.valuePlate(x, y, w, h, label, value, opts)
    opts = opts or {}
    w, h = math.floor(w), math.floor(h)
    if w < 24 or h < 20 then return end
    local accent = opts.accent or Palette.AGED_GOLD
    local seed = opts.seed or 0
    local key = ("V%d|%d|%s|%s|%s|%d"):format(w, h, label, value, colorKey(accent), seed)
    local canvas = stripCache[key]
    if not canvas then
        if stripCount > 96 then ShopEngraving.clearCache() end
        canvas = renderValuePlate(w, h, label, value, accent, seed)
        stripCache[key] = canvas
        stripCount = stripCount + 1
    end
    local a, d = opts.alpha or 1, opts.dim or 1
    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y) + h, w, 1)
    love.graphics.setColor(d, d, d, a)
    love.graphics.draw(canvas, math.floor(x), math.floor(y))
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopEngraving.clearCache()
    stripCache = {}
    stripCount = 0
end

return ShopEngraving
