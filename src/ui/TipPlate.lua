-- src/ui/TipPlate.lua
-- PLACA DE DICA ancorada num objeto (tutorial, Out/2026).
--
-- Uma placa de pergaminho pequena com seta apontando pro objeto que ela
-- explica — o padrão do StS/Balatro. NUNCA uma faixa de rodapé (CLAUDE.md:
-- "sem faixa de dica no rodapé"): a informação mora ANCORADA no objeto.
--
-- Duas metades, como o resto da UI do projeto:
--   TipPlate.layout(...)   PURA — onde a placa cabe sem cobrir o objeto, a
--                          TopBar nem sair da tela. Testável sem desenhar.
--   TipPlate.validate(L)   as regras de zona, pra teste e tools.
--   TipPlate.draw(L, ...)  desenha a placa já calculada.
--
-- Coordenadas: PIXELS REAIS da janela. Tamanhos de fonte/margem são
-- multiplicados por `k` (UiScale.k() — a escala da interface).

local Palette = require("src.ui.Palette")
local FontManager = require("src.ui.FontManager")

local TipPlate = {}

TipPlate.MAX_W = 300      -- largura máxima da placa (×k): cabe ao LADO de um painel central
TipPlate.PAD = 12         -- respiro interno (×k)
TipPlate.GAP = 14         -- distância placa ↔ objeto (×k): onde a seta mora
TipPlate.MARGIN = 10      -- distância mínima da borda da tela (×k)
TipPlate.TITLE_PX = 13
TipPlate.BODY_PX = 10
TipPlate.HINT_PX = 8

local function fonts(k)
    return FontManager.getFont(math.floor(TipPlate.TITLE_PX * k + 0.5)),
        FontManager.getFont(math.floor(TipPlate.BODY_PX * k + 0.5)),
        FontManager.getFont(math.floor(TipPlate.HINT_PX * k + 0.5))
end

local function overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
TipPlate.overlaps = overlaps

-- Mede a placa pros textos dados (lista de linhas já quebradas).
function TipPlate.measure(title, body, hint, k, screenW)
    local fT, fB, fH = fonts(k)
    local maxW = math.min(math.floor(TipPlate.MAX_W * k), math.floor(screenW * 0.42))
    local pad = math.floor(TipPlate.PAD * k)
    local inner = maxW - pad * 2
    local _, tLines = fT:getWrap(title or "", inner)
    local _, bLines = fB:getWrap(body or "", inner)
    local w = 0
    for _, l in ipairs(tLines) do w = math.max(w, fT:getWidth(l)) end
    for _, l in ipairs(bLines) do w = math.max(w, fB:getWidth(l)) end
    w = math.max(w, fH:getWidth(hint or ""))
    local h = #tLines * fT:getHeight() + math.floor(6 * k)
        + #bLines * fB:getHeight() * 1.15 + math.floor(8 * k) + fH:getHeight()
    return {
        w = math.min(maxW, w + pad * 2), h = math.floor(h + pad * 2),
        tLines = tLines, bLines = bLines, pad = pad,
    }
end

-- Calcula a posição. anchor = {x,y,w,h} (pixels reais), size = measure(...),
-- avoid = lista de retângulos que a placa não pode cobrir (TopBar...).
-- Tenta acima, abaixo, à esquerda e à direita do objeto, nessa ordem, e fica
-- com a primeira que cabe na tela sem cobrir o objeto nem nada de `avoid`.
-- Se nenhuma cabe (objeto enorme), fica a que menos invade.
-- `prefer` (opcional): ordem dos lados, ex. { "right", "left", ... } — o
-- intent do inimigo prefere o LADO (embaixo dele mora a barra de vida).
function TipPlate.layout(anchor, size, W, H, k, avoid, prefer)
    avoid = avoid or {}
    local gap = math.floor(TipPlate.GAP * k)
    local m = math.floor(TipPlate.MARGIN * k)
    local acx, acy = anchor.x + anchor.w / 2, anchor.y + anchor.h / 2
    local function clampX(x) return math.max(m, math.min(W - m - size.w, x)) end
    local function clampY(y) return math.max(m, math.min(H - m - size.h, y)) end
    local cands = {
        { side = "above", x = clampX(acx - size.w / 2), y = anchor.y - gap - size.h },
        { side = "below", x = clampX(acx - size.w / 2), y = anchor.y + anchor.h + gap },
        { side = "left",  x = anchor.x - gap - size.w, y = clampY(acy - size.h / 2) },
        { side = "right", x = anchor.x + anchor.w + gap, y = clampY(acy - size.h / 2) },
    }
    if prefer then
        local bySide = {}
        for _, c in ipairs(cands) do bySide[c.side] = c end
        local ordered = {}
        for _, side in ipairs(prefer) do
            if bySide[side] then ordered[#ordered + 1] = bySide[side]; bySide[side] = nil end
        end
        for _, c in ipairs(cands) do if bySide[c.side] then ordered[#ordered + 1] = c end end
        cands = ordered
    end
    local best, bestScore
    for _, c in ipairs(cands) do
        local r = { x = math.floor(c.x), y = math.floor(c.y), w = size.w, h = size.h }
        local inside = r.x >= m - 0.5 and r.y >= m - 0.5
            and r.x + r.w <= W - m + 0.5 and r.y + r.h <= H - m + 0.5
        local score = 0
        if not inside then score = score + 100 end
        if overlaps(r, anchor) then score = score + 50 end
        for _, a in ipairs(avoid) do
            if overlaps(r, a) then score = score + 10 end
        end
        if not bestScore or score < bestScore then
            best, bestScore = { rect = r, side = c.side }, score
        end
        if score == 0 then break end
    end
    -- Fora da tela nunca: o pior caso é encostar no objeto, nunca sumir.
    local r = best.rect
    r.x = math.max(m, math.min(W - m - r.w, r.x))
    r.y = math.max(m, math.min(H - m - r.h, r.y))
    -- Ponta da seta: na borda do objeto voltada pra placa; base na placa.
    local tip, base
    if best.side == "above" then
        tip = { x = math.max(anchor.x, math.min(anchor.x + anchor.w, acx)), y = anchor.y }
        base = { x = math.max(r.x + 14 * k, math.min(r.x + r.w - 14 * k, tip.x)), y = r.y + r.h }
    elseif best.side == "below" then
        tip = { x = math.max(anchor.x, math.min(anchor.x + anchor.w, acx)), y = anchor.y + anchor.h }
        base = { x = math.max(r.x + 14 * k, math.min(r.x + r.w - 14 * k, tip.x)), y = r.y }
    elseif best.side == "left" then
        tip = { x = anchor.x, y = math.max(anchor.y, math.min(anchor.y + anchor.h, acy)) }
        base = { x = r.x + r.w, y = math.max(r.y + 14 * k, math.min(r.y + r.h - 14 * k, tip.y)) }
    else
        tip = { x = anchor.x + anchor.w, y = math.max(anchor.y, math.min(anchor.y + anchor.h, acy)) }
        base = { x = r.x, y = math.max(r.y + 14 * k, math.min(r.y + r.h - 14 * k, tip.y)) }
    end
    return { rect = r, side = best.side, anchor = anchor, tip = tip, base = base,
        size = size, k = k, W = W, H = H, avoid = avoid }
end

-- Regras de zona. Devolve (ok, lista de violações).
function TipPlate.validate(L)
    local errs = {}
    local r, m = L.rect, math.floor(TipPlate.MARGIN * L.k)
    if r.x < m - 1 or r.y < m - 1 or r.x + r.w > L.W - m + 1 or r.y + r.h > L.H - m + 1 then
        errs[#errs + 1] = "placa sai da tela"
    end
    if overlaps(r, L.anchor) then errs[#errs + 1] = "placa cobre o objeto que explica" end
    for i, a in ipairs(L.avoid or {}) do
        if overlaps(r, a) then errs[#errs + 1] = "placa cobre zona proibida #" .. i end
    end
    return #errs == 0, errs
end

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (a or 1) * (c[4] or 1))
end

-- Desenha a placa. texts = { title, hint, step = "2/5"? }; alpha 0..1.
function TipPlate.draw(L, title, hint, alpha)
    alpha = alpha or 1
    local k, r, s = L.k, L.rect, L.size
    local fT, fB, fH = fonts(k)
    local now = love.timer.getTime()

    -- Aro pulsante no OBJETO explicado (o olho acha a coisa, não a placa).
    local pulse = 0.5 + 0.5 * math.sin(now * 4)
    local a = L.anchor
    setColor(Palette.AGED_GOLD_LIGHT or { 1, 0.9, 0.5, 1 }, (0.55 + 0.35 * pulse) * alpha)
    love.graphics.setLineWidth(math.max(2, math.floor(2 * k)))
    love.graphics.rectangle("line", a.x - 4 * k, a.y - 4 * k, a.w + 8 * k, a.h + 8 * k, 6 * k, 6 * k)

    -- Seta (triângulo da base na placa até a borda do objeto).
    local bx, by, tx, ty = L.base.x, L.base.y, L.tip.x, L.tip.y
    local dx, dy = tx - bx, ty - by
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    local nx, ny = -dy / len, dx / len
    local half = 7 * k
    love.graphics.setColor(0, 0, 0, 0.5 * alpha)
    love.graphics.polygon("fill", bx + nx * half + 2, by + ny * half + 3,
        bx - nx * half + 2, by - ny * half + 3, tx + 2, ty + 3)
    setColor(Palette.PARCHMENT_LIGHT or { 0.95, 0.9, 0.78, 1 }, alpha)
    love.graphics.polygon("fill", bx + nx * half, by + ny * half, bx - nx * half, by - ny * half, tx, ty)
    setColor(Palette.INK or { 0.1, 0.08, 0.06, 1 }, alpha)
    love.graphics.setLineWidth(math.max(1, math.floor(k)))
    love.graphics.line(bx + nx * half, by + ny * half, tx, ty, bx - nx * half, by - ny * half)

    -- Placa: sombra, pergaminho, borda de tinta dupla.
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle("fill", r.x + 3 * k, r.y + 4 * k, r.w, r.h, 5 * k, 5 * k)
    setColor(Palette.PARCHMENT_LIGHT or { 0.95, 0.9, 0.78, 1 }, alpha)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5 * k, 5 * k)
    setColor(Palette.INK or { 0.1, 0.08, 0.06, 1 }, alpha)
    love.graphics.setLineWidth(math.max(1, math.floor(2 * k)))
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5 * k, 5 * k)
    setColor(Palette.AGED_GOLD or { 0.75, 0.6, 0.3, 1 }, 0.8 * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x + 3 * k, r.y + 3 * k, r.w - 6 * k, r.h - 6 * k, 3 * k, 3 * k)

    -- Texto
    local x, y = r.x + s.pad, r.y + s.pad
    love.graphics.setFont(fT)
    setColor(Palette.BLOOD or { 0.55, 0.12, 0.1, 1 }, alpha)
    for _, l in ipairs(s.tLines) do
        love.graphics.print(l, math.floor(x), math.floor(y)); y = y + fT:getHeight()
    end
    y = y + math.floor(6 * k)
    love.graphics.setFont(fB)
    setColor(Palette.INK or { 0.1, 0.08, 0.06, 1 }, alpha)
    for _, l in ipairs(s.bLines) do
        love.graphics.print(l, math.floor(x), math.floor(y)); y = y + fB:getHeight() * 1.15
    end
    y = y + math.floor(8 * k)
    love.graphics.setFont(fH)
    setColor(Palette.AGED_GOLD or { 0.6, 0.45, 0.2, 1 }, (0.7 + 0.3 * pulse) * alpha)
    love.graphics.print(hint or "", math.floor(r.x + r.w - s.pad - fH:getWidth(hint or "")), math.floor(y))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return TipPlate
