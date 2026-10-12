-- src/ui/ClassSelectLayout.lua
-- PLANO DE ZONAS da seleção de classe (Out/2026 — emblemas no lugar dos
-- heróis). Mesmo princípio do PackChoiceLayout: cada elemento mora numa
-- BANDA alocada em sequência, nenhuma banda encosta na outra, e quem cede
-- quando falta espaço é a ESCALA (emblema e cartas), não a posição.
--
--   ┌──────────────────────────────────────────────┐
--   │ T — título                                   │
--   ├──────────┬──────────┬──────────┬─────────────┤
--   │ painel 1 │ painel 2 │ painel 3 │  cada painel:
--   │          │          │          │   emblem  (flex — protagonista)
--   │          │          │          │   name
--   │          │          │          │   status  (maestria | requisito+barra)
--   │          │          │          │   desc
--   │          │          │          │   stats   (vida · baralho)
--   │          │          │          │   passive (mecânica-chave)
--   │          │          │          │   cards   (flex — cartas iniciais)
--   ├──────────┴──────────┴──────────┴─────────────┤
--   │ S — Selo do Grimório  [<]  Selo 3 · regra  [>]│
--   │ B — voltar                                   │
--   │ H — hint bar                                 │
--   └──────────────────────────────────────────────┘
--
-- compute() é PURO (só aritmética sobre sw/sh) — testável sem janela.
-- validate() checa a geometria e é rodado pelo test_class_select em vários
-- tamanhos de janela.

local L = {}

L.MARGIN     = 14
L.GAP        = 12
L.TITLE_H    = 48
L.BACK_H     = 44
L.SEAL_H     = 42      -- banda do seletor de Selo (×ts)
L.HINT_H     = 42
L.PAD        = 12      -- respiro interno do painel
L.INNER_GAP  = 6
-- alturas base (×ts) das bandas fixas do painel
L.NAME_H     = 24
L.STATUS_H   = 36
L.DESC_H     = 30
L.STATS_H    = 22
L.PASSIVE_H  = 64
L.CARD_LABEL_H = 14
L.CARD_W, L.CARD_H = 96, 144
L.CARD_SCALE_MIN, L.CARD_SCALE_MAX = 0.45, 1.0
L.EMBLEM_MIN = 72
L.PANEL_H_MAX = 720

-- Escala do TEXTO (e das bandas fixas): cresce com a janela pra o painel
-- não virar um selo minúsculo em 1080p; nunca encolhe abaixo de 1.
function L.textScale(sw, sh)
    return math.max(1, math.min(1.5, math.min(sh / 768, sw / 1024)))
end

local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

function L.compute(sw, sh, n)
    n = n or 3
    local ts = L.textScale(sw, sh)
    local out = { sw = sw, sh = sh, ts = ts, panels = {} }

    local titleH = math.floor(L.TITLE_H * ts)
    out.title = rect(0, L.MARGIN, sw, titleH)

    -- Faixa de dica desligada no jogo (HintBar.ENABLED = false, Out/2026):
    -- a banda vira só margem e o espaço volta pros painéis e pro Selo.
    local hintOn = require("src.ui.HintBar").ENABLED
    local hintH = hintOn and math.floor(L.HINT_H * ts) or L.MARGIN
    out.hint = rect(0, sh - hintH, sw, hintH)
    local backH = L.BACK_H
    local backW = math.min(260, math.max(180, sw * 0.22))

    local sealH = math.floor(L.SEAL_H * ts)
    local top = L.MARGIN + titleH + L.GAP
    local bottom = sh - hintH - backH - sealH - L.GAP * 3
    local availH = bottom - top
    local ph = math.min(availH, math.floor(L.PANEL_H_MAX * ts))
    local py = top + math.floor((availH - ph) / 2)

    local colGap = math.max(16, math.min(40, math.floor(sw * 0.025)))
    local pw = math.min(math.floor(340 * ts), math.floor((sw - 2 * 16 - (n - 1) * colGap) / n))
    local rowW = n * pw + (n - 1) * colGap
    local px0 = math.floor((sw - rowW) / 2)

    local sealW = math.min(rowW, math.floor(620 * ts), sw - 32)
    out.seal = rect((sw - sealW) / 2, py + ph + L.GAP, sealW, sealH)
    local arrowW = math.floor(sealH * 0.9)
    out.sealPrev = rect(out.seal.x, out.seal.y, arrowW, sealH)
    out.sealNext = rect(out.seal.x + out.seal.w - arrowW, out.seal.y, arrowW, sealH)
    out.back = rect((sw - backW) / 2, out.seal.y + sealH + L.GAP, backW, backH)

    -- bandas internas (iguais pros 3 painéis)
    local pad = L.PAD
    local ig = L.INNER_GAP
    local fixed = {
        name    = math.floor(L.NAME_H * ts),
        status  = math.floor(L.STATUS_H * ts),
        desc    = math.floor(L.DESC_H * ts),
        stats   = math.floor(L.STATS_H * ts),
        passive = math.floor(L.PASSIVE_H * ts),
    }
    local fixedSum = fixed.name + fixed.status + fixed.desc + fixed.stats + fixed.passive
    local flex = ph - 2 * pad - fixedSum - 6 * ig
    local labelH = math.floor(L.CARD_LABEL_H * ts)

    -- cartas: até 38% do flex, limitadas pela largura (2 cartas lado a lado)
    local innerW = pw - 2 * pad
    local fitW = (innerW - 12) / (2 * L.CARD_W)
    local fitH = (flex * 0.38 - labelH) / L.CARD_H
    local cardScale = math.max(L.CARD_SCALE_MIN, math.min(L.CARD_SCALE_MAX * ts, fitW, fitH))
    local cardsH = labelH + math.ceil(L.CARD_H * cardScale)
    local emblemH = flex - cardsH
    out.cardScale = cardScale
    out.emblemH = emblemH

    for i = 1, n do
        local x = px0 + (i - 1) * (pw + colGap)
        local p = rect(x, py, pw, ph)
        local ix = x + pad
        local y = py + pad
        p.emblem = rect(ix, y, innerW, emblemH);           y = y + emblemH + ig
        p.name = rect(ix, y, innerW, fixed.name);           y = y + fixed.name + ig
        p.status = rect(ix, y, innerW, fixed.status);       y = y + fixed.status + ig
        p.desc = rect(ix, y, innerW, fixed.desc);           y = y + fixed.desc + ig
        p.stats = rect(ix, y, innerW, fixed.stats);         y = y + fixed.stats + ig
        p.passive = rect(ix, y, innerW, fixed.passive);     y = y + fixed.passive + ig
        p.cards = rect(ix, y, innerW, cardsH)
        out.panels[i] = p
    end
    return out
end

-- ===== Validação geométrica =====
local BAND_ORDER = { "emblem", "name", "status", "desc", "stats", "passive", "cards" }

local function inside(a, b)   -- a dentro de b
    return a.x >= b.x and a.y >= b.y and a.x + a.w <= b.x + b.w and a.y + a.h <= b.y + b.h
end

local function overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Retorna ok, { erros... }
function L.validate(lay)
    local errs = {}
    local screen = { x = 0, y = 0, w = lay.sw, h = lay.sh }
    local function err(msg) errs[#errs + 1] = msg end

    for _, key in ipairs({ "title", "seal", "back", "hint" }) do
        if not inside(lay[key], screen) then err(key .. " fora da tela") end
    end
    if lay.emblemH < L.EMBLEM_MIN then
        err(("emblema pequeno demais: %d < %d"):format(lay.emblemH, L.EMBLEM_MIN))
    end
    for i, p in ipairs(lay.panels) do
        if not inside(p, screen) then err("painel " .. i .. " fora da tela") end
        if overlaps(p, lay.title) then err("painel " .. i .. " invade o titulo") end
        if overlaps(p, lay.back) then err("painel " .. i .. " invade o voltar") end
        if overlaps(p, lay.seal) then err("painel " .. i .. " invade o selo") end
        if overlaps(p, lay.hint) then err("painel " .. i .. " invade a hint") end
        for j = i + 1, #lay.panels do
            if overlaps(p, lay.panels[j]) then err(("paineis %d e %d se sobrepoem"):format(i, j)) end
        end
        local prev
        for _, b in ipairs(BAND_ORDER) do
            local r = p[b]
            if r.h <= 0 then err(("painel %d banda %s com altura %d"):format(i, b, r.h)) end
            if not inside(r, p) then err(("painel %d banda %s vaza do painel"):format(i, b)) end
            if prev and overlaps(prev, r) then
                err(("painel %d banda %s encosta na anterior"):format(i, b))
            end
            prev = r
        end
        local cw = 2 * L.CARD_W * lay.cardScale + 12
        if cw > p.cards.w then err(("painel %d: cartas (%d) mais largas que a banda (%d)"):format(i, cw, p.cards.w)) end
    end
    if overlaps(lay.back, lay.hint) then err("voltar invade a hint") end
    if overlaps(lay.seal, lay.back) then err("selo invade o voltar") end
    if overlaps(lay.sealPrev, lay.sealNext) then err("setas do selo se sobrepoem") end
    return #errs == 0, errs
end

return L
