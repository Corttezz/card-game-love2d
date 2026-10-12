-- src/ui/ClassSelectLayout.lua
-- PLANO DE ZONAS da seleção de classe v4 (Out/2026, "página do grimório").
-- O dono achou a v3 poluída (três painéis iguais, muito rótulo, tudo de uma
-- vez — "cara de IA"). A v4 é ASSIMÉTRICA e mostra UMA classe por vez:
--
--   ┌───────────────────────────────────────────────┐
--   │ ‹ menu      [<] selo [>]    ┌───────────────┐ │
--   │                             │  (cabeçalho)  │ │
--   │         HERÓI               │  NOME         │ │
--   │   (emblema grande,      [▸] │  identidade   │ │
--   │    efeito da classe)  marca │  passiva      │ │
--   │                             │  ♥ ◆ ▤        │ │
--   │   ◇  ◇  ◇                   │   [COMEÇAR]   │ │
--   └─────────────────────────────┴───────────────┘─┘
--      escolha                        página
--
-- Cada elemento mora numa BANDA; quando falta espaço cede a escala do
-- emblema e o tamanho da fonte, não a posição. compute() é PURO (só
-- aritmética sobre sw/sh, no espaço VIRTUAL do UiScale) e validate() é
-- rodado pelo test_class_select e pelo test_endless_seals.

local L = {}

L.BACK_H = 28
L.CHOOSER_H = 108          -- faixa das três classes (emblemas pequenos)
L.SEAL_MIN_W = 210
L.TAB_W, L.TAB_H = 30, 120  -- marcador "detalhes" (fita vertical na borda da página)
L.CTA_H = 40
L.EMBLEM_MIN = 120
L.CARD_W_SRC, L.CARD_H_SRC = 96, 144   -- canvas da carta (cartas iniciais nos detalhes)

local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

-- Tamanhos de fonte da tela: SÓ DOIS (grande = nome, corpo = o resto).
function L.fonts(sw, sh)
    local small = sw < 900 or sh < 620
    return small and 20 or 24, small and 10 or 12
end

function L.compute(sw, sh, n)
    n = n or 3
    local out = { sw = sw, sh = sh, n = n }
    local M = (sw < 900) and 16 or 24
    out.margin = M
    out.bigFont, out.bodyFont = L.fonts(sw, sh)

    -- PÁGINA (direita): 40% da largura, altura quase toda; o pé deixa folga
    -- pra fita do COMEÇAR, que pende 10 px pra fora do papel.
    local pw = math.floor(math.min(560, math.max(300, sw * 0.40)))
    local ph = sh - 2 * M - 12
    out.page = rect(sw - M - pw, M, pw, ph)
    local pad = math.floor(pw * 0.09)
    out.pageInner = rect(out.page.x + pad, out.page.y + pad, pw - 2 * pad, ph - 2 * pad - L.CTA_H)
    local ctaW = math.floor(pw * 0.72)
    out.start = rect(out.page.x + (pw - ctaW) / 2, out.page.y + ph - L.CTA_H + 2, ctaW, L.CTA_H)
    -- marcador de DETALHES: fita vertical presa na borda esquerda da página
    out.details = rect(out.page.x - L.TAB_W + 6, out.page.y + math.floor(ph * 0.16), L.TAB_W, L.TAB_H)

    -- ZONA ESQUERDA: voltar no alto, herói no meio, escolha + selo no pé
    local zx, zr = M, out.details.x - 16
    out.back = rect(M, M, (sw < 900) and 170 or 200, L.BACK_H)
    local chooserY = sh - M - L.CHOOSER_H
    local heroTop = M + L.BACK_H + 16
    out.hero = rect(zx, heroTop, zr - zx, chooserY - 12 - heroTop)

    local md = math.floor(math.max(64, math.min(104, (zr - zx) * 0.17)))
    local gap = math.floor(md * 0.30)
    out.medallions = {}
    for i = 1, n do
        out.medallions[i] = rect(zx + (i - 1) * (md + gap), chooserY + (L.CHOOSER_H - md) / 2, md, md)
    end
    local chooserW = n * md + (n - 1) * gap
    out.chooser = rect(zx, chooserY, chooserW, L.CHOOSER_H)

    -- SELO: no alto da zona esquerda, alinhado à direita (o voltar fica na
    -- ponta oposta). Só existe com selo liberado — a tela decide; a banda é
    -- reservada sempre.
    local sealH = 40
    local sealW = math.min(400, zr - (M + ((sw < 900) and 190 or 220)))
    out.seal = rect(zr - sealW, M - 6, sealW, sealH)
    local aw = 30
    out.sealPrev = rect(out.seal.x, out.seal.y, aw, sealH)
    out.sealNext = rect(out.seal.x + out.seal.w - aw, out.seal.y, aw, sealH)
    return out
end

local function inside(a, b)
    return a.x >= b.x and a.y >= b.y and a.x + a.w <= b.x + b.w and a.y + a.h <= b.y + b.h
end

local function overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Retorna ok, { erros... }
function L.validate(lay)
    local errs = {}
    local function err(msg) errs[#errs + 1] = msg end
    local screen = { x = 0, y = 0, w = lay.sw, h = lay.sh }
    for _, key in ipairs({ "page", "start", "details", "back", "hero", "chooser", "seal" }) do
        if not inside(lay[key], screen) then err(key .. " fora da tela") end
    end
    if lay.hero.h < L.EMBLEM_MIN then err(("heroi baixo demais: %d"):format(lay.hero.h)) end
    if lay.seal.w < L.SEAL_MIN_W then err(("selo estreito: %d"):format(lay.seal.w)) end
    if lay.pageInner.h < 260 then err(("pagina baixa demais: %d"):format(lay.pageInner.h)) end
    for _, key in ipairs({ "hero", "chooser", "seal", "back" }) do
        if overlaps(lay[key], lay.page) then err(key .. " invade a pagina") end
        if overlaps(lay[key], lay.details) then err(key .. " invade o marcador") end
    end
    if overlaps(lay.hero, lay.chooser) then err("heroi invade a escolha") end
    if overlaps(lay.hero, lay.seal) then err("heroi invade o selo") end
    if overlaps(lay.chooser, lay.seal) then err("escolha invade o selo") end
    if overlaps(lay.back, lay.seal) then err("voltar invade o selo") end
    if overlaps(lay.back, lay.hero) then err("voltar invade o heroi") end
    if overlaps(lay.sealPrev, lay.sealNext) then err("setas do selo se sobrepoem") end
    for i, m in ipairs(lay.medallions) do
        if not inside(m, lay.chooser) then err("emblema " .. i .. " fora da faixa") end
    end
    if not inside(lay.pageInner, lay.page) then err("texto vaza da pagina") end
    if overlaps(lay.pageInner, lay.start) then err("texto encosta no COMECAR") end
    return #errs == 0, errs
end

return L
