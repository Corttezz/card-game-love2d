-- src/ui/PackChoiceLayout.lua
-- PLANO DE ZONAS da tela de escolha do booster pack.
--
-- POR QUE ESTE MÓDULO EXISTE
-- A tela foi crescendo por acumulação: a etiqueta de raridade foi colocada
-- "embaixo da carta", os botões de confirmar/cancelar também ancoraram
-- "embaixo da carta", e a faixa de info foi parar no topo da tela. Cada
-- elemento foi posicionado sozinho, sem um plano de onde cada coisa mora — e
-- por isso colidiram: etiqueta e botões nasciam no MESMO Y (`ry + imgH + 8`),
-- com o botão tapando a raridade sempre que uma carta era selecionada.
--
-- A correção não é empurrar o botão alguns pixels. É dar a cada elemento uma
-- ZONA própria, reservada, e nenhuma zona encostar na outra em nenhum estado:
--
--   ┌──────────────────────────────────────────────┐
--   │ C — CONTEXTO DO PACOTE                       │ nome do pacote, "Escolha N", Pular
--   ├──────────────────────────────────────────────┤
--   │ A — CARTAS (a protagonista)                  │ a fileira
--   │ A' — etiquetas de raridade                   │ metadado colado na carta
--   ├──────────────────────────────────────────────┤
--   │ B — DETALHE DA CARTA EM FOCO                 │ tudo que se sabe da carta
--   ├──────────────────────────────────────────────┤
--   │ D — AÇÃO                                     │ Escolher / Cancelar / instrução
--   └──────────────────────────────────────────────┘
--
-- Como as alturas são ALOCADAS (e não chutadas), a ausência de sobreposição é
-- garantida por construção, não por inspeção visual: as bandas são fatiadas em
-- sequência a partir da altura da janela, e a escala da carta é o que cede
-- quando o espaço aperta.
--
-- As zonas B e D têm altura FIXA e existem sempre, mesmo vazias. Isso é
-- deliberado: se elas aparecessem só quando há hover/seleção, o resto da tela
-- pularia a cada movimento do mouse. Zona vazia mostra instrução.

local PackChoiceLayout = {}

-- Alturas fixas das bandas (px lógicos).
PackChoiceLayout.HEADER_H = 60   -- C: nome do pacote + contador + Pular
PackChoiceLayout.TAG_H    = 24   -- A': faixa da etiqueta de raridade
PackChoiceLayout.DETAIL_H = 116  -- B: detalhe da carta em foco
PackChoiceLayout.ACTION_H = 52   -- D: botões / instrução
PackChoiceLayout.MARGIN   = 14
PackChoiceLayout.GAP_MIN  = 10
PackChoiceLayout.GAP_MAX  = 34

-- Escala da carta.
-- Teto da escala a 768px de altura. Em telas MAIORES ele sobe proporcional:
-- travado em 1.90, um monitor 1080p deixava as cartas do mesmo tamanho de uma
-- janela 768 e sobravam ~250px mortos em cima E embaixo. A carta e a
-- recompensa; se ha tela, ela ocupa.
PackChoiceLayout.CARD_SCALE_BASE = 1.90   -- ~1.43x a escala da mão
PackChoiceLayout.CARD_SCALE_CAP  = 2.80   -- alem disso a arte pixel borra
PackChoiceLayout.CARD_SCALE_MIN = 0.80   -- abaixo disso a arte fica ilegível
PackChoiceLayout.CARD_SPACING   = 0.34   -- fração da largura da carta

-- Altura que TODAS as bandas fixas consomem junta, com os 4 respiros mínimos.
local function fixedHeight()
    local L = PackChoiceLayout
    return L.HEADER_H + L.TAG_H + L.DETAIL_H + L.ACTION_H
end

-- Escala da carta: o maior valor que respeita AS DUAS restrições.
--   • largura — a fileira inteira cabe (pacotes de 5 cartas existem);
--   • altura  — sobra espaço para todas as outras bandas.
-- A altura é a que costuma ser esquecida. Sem ela, em janela baixa a fileira
-- crescia até não sobrar espaço e as bandas se atropelavam.
function PackChoiceLayout.cardScale(n, imgW, imgH, sw, sh)
    local L = PackChoiceLayout
    sw = sw or love.graphics.getWidth()
    sh = sh or love.graphics.getHeight()

    local fitW = (sw * 0.88) / (imgW * (n + (n - 1) * L.CARD_SPACING))
    local budget = sh - 2 * L.MARGIN - fixedHeight() - 4 * L.GAP_MIN
    local fitH = budget / imgH
    local ceiling = math.min(L.CARD_SCALE_CAP, L.CARD_SCALE_BASE * math.max(1, sh / 768))

    return math.max(L.CARD_SCALE_MIN, math.min(ceiling, fitW, fitH))
end

-- Retorna as zonas já resolvidas para a janela atual.
--   { header, cards, tags, detail, action }  -- cada um { x, y, w, h }
--   + cardScale, cardW, cardH, spacing, rowStartX
--
-- `n` é a quantidade de cartas do pacote; imgW/imgH são as dimensões do canvas
-- da carta (antes da escala).
function PackChoiceLayout.compute(n, imgW, imgH, sw, sh)
    local L = PackChoiceLayout
    sw = sw or love.graphics.getWidth()
    sh = sh or love.graphics.getHeight()

    local scale = L.cardScale(n, imgW, imgH, sw, sh)
    local cardW, cardH = imgW * scale, imgH * scale

    -- O que sobra depois das bandas fixas e das cartas vira respiro, dividido
    -- igualmente entre os 4 vãos; o excedente sobra como margem em cima/embaixo
    -- para a pilha ficar centrada em vez de grudada no topo.
    local leftover = sh - 2 * L.MARGIN - fixedHeight() - cardH
    local gap = math.max(L.GAP_MIN, math.min(L.GAP_MAX, leftover / 4))
    local topPad = L.MARGIN + math.max(0, (leftover - 4 * gap) * 0.5)

    local bandW = math.min(900, sw * 0.86)
    local bandX = math.floor((sw - bandW) * 0.5)

    -- Alocação em INTEIROS, acumulando o valor já arredondado. Fatiar em float
    -- e arredondar cada banda no fim deixa o resto do arredondamento entre uma
    -- banda e a seguinte, e a de cima invade a de baixo em 1px — invisível na
    -- tela, mas a validação geométrica (que é o ponto deste módulo) acusa. A
    -- altura da carta sobe com ceil pelo mesmo motivo.
    local gapI  = math.floor(gap)
    local cardHi = math.ceil(cardH)
    local y = math.floor(topPad)

    local header = { x = bandX, y = y, w = bandW, h = L.HEADER_H }
    y = y + L.HEADER_H + gapI

    local cards = { x = 0, y = y, w = sw, h = cardHi }
    y = y + cardHi

    local tags = { x = 0, y = y, w = sw, h = L.TAG_H }
    y = y + L.TAG_H + gapI

    local detail = { x = bandX, y = y, w = bandW, h = L.DETAIL_H }
    y = y + L.DETAIL_H + gapI

    local action = { x = bandX, y = y, w = bandW, h = L.ACTION_H }

    -- Posição horizontal da fileira.
    local spacing = cardW * L.CARD_SPACING
    local totalW = cardW * n + spacing * math.max(0, n - 1)

    return {
        header = header, cards = cards, tags = tags,
        detail = detail, action = action,
        cardScale = scale, cardW = cardW, cardH = cardH,
        spacing = spacing,
        rowStartX = (sw - totalW) * 0.5,
    }
end

-- Posição final (canto superior esquerdo) da i-ésima carta.
function PackChoiceLayout.cardPos(zones, i)
    return zones.rowStartX + (i - 1) * (zones.cardW + zones.spacing), zones.cards.y
end

-- Verificação de invariante: nenhuma banda encosta na seguinte, e nada sai da
-- tela. Usada pelo tool de captura de estados — é o que transforma "parece que
-- não bate" em prova. Retorna (ok, lista de problemas).
function PackChoiceLayout.validate(zones, sw, sh)
    sw = sw or love.graphics.getWidth()
    sh = sh or love.graphics.getHeight()
    local problems = {}
    local order = {
        { "header", zones.header }, { "cards", zones.cards },
        { "tags", zones.tags }, { "detail", zones.detail }, { "action", zones.action },
    }
    for i = 1, #order do
        local name, r = order[i][1], order[i][2]
        if r.y < 0 then
            problems[#problems + 1] = name .. " sai pelo topo (y=" .. math.floor(r.y) .. ")"
        end
        if r.y + r.h > sh then
            problems[#problems + 1] = name .. " sai por baixo (fim="
                .. math.floor(r.y + r.h) .. " > " .. sh .. ")"
        end
        if r.x < 0 or r.x + r.w > sw then
            problems[#problems + 1] = name .. " sai pelos lados"
        end
        if i < #order then
            local nxt = order[i + 1]
            if r.y + r.h > nxt[2].y + 0.5 then
                problems[#problems + 1] = string.format("%s invade %s em %.0fpx",
                    name, nxt[1], (r.y + r.h) - nxt[2].y)
            end
        end
    end
    -- A fileira de cartas também não pode sangrar pelos lados.
    if zones.rowStartX < 0 then
        problems[#problems + 1] = "fileira de cartas sangra pelos lados"
    end
    return #problems == 0, problems
end

return PackChoiceLayout
