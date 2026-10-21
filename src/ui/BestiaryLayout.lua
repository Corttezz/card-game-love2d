local FontManager = require("src.ui.FontManager")

local L = {}

L.COLS = 7
L.MARGIN = 16
L.GAP = 8
L.CELL_MAX = 176
L.REF_W, L.REF_H = 126, 132
L.HEADER_H = 30
L.ACT_GAP = 14
L.NAME_H = 22
L.CELL_PAD = 6
L.SPRITE_INSET = 4
L.CHIP_H = 26
L.CHIP_Y = 70

L.PAGE_MAX_W, L.PAGE_MAX_H = 1040, 660
L.PAGE_PAD = 26
L.FONT = { name = 16, epithet = 10, meta = 8, head = 10, body = 8, stat = 16, statLabel = 8, nav = 10 }
L.FONT_MIN = { name = 10, epithet = 8, body = 8, head = 8 }

function L.physScale()
    local x0 = love.graphics.transformPoint(0, 0)
    local x1 = love.graphics.transformPoint(1, 0)
    local s = math.abs(x1 - x0)
    if s <= 0 then return 1 end
    return s
end

function L.scissor(x, y, w, h)
    local k = require("src.ui.UiScale").activeK()
    local sx, sy = love.graphics.transformPoint(x, y)
    local ex, ey = love.graphics.transformPoint(x + w, y + h)
    love.graphics.setScissor(sx / k, sy / k, math.max(0, (ex - sx) / k), math.max(0, (ey - sy) / k))
end

function L.spriteScale(boxW, boxH, k, refW, refH)
    k = k or 1
    local fit = math.min(boxW / (refW or L.REF_W), boxH / (refH or L.REF_H))
    local p = math.max(1, math.floor(k * fit + 1e-6))
    return p / k, p
end

function L.grid(sw, sh, top, bottom, k, actCounts)
    local cols = L.COLS
    local availW = sw - 2 * L.MARGIN
    local cellW = math.min(L.CELL_MAX, math.floor((availW - (cols - 1) * L.GAP) / cols))
    local s, p = L.spriteScale(cellW - 2 * L.SPRITE_INSET, 1e9, k)
    local spriteH = math.ceil(L.REF_H * s) + 4
    local cellH = L.CELL_PAD + spriteH + L.NAME_H
    local rowW = cols * cellW + (cols - 1) * L.GAP
    local x0 = math.floor((sw - rowW) / 2)
    local G = {
        x = x0, w = rowW, top = top, bottom = bottom, viewH = bottom - top,
        cellW = cellW, cellH = cellH, spriteH = spriteH, spriteS = s, spriteP = p,
        cols = cols, acts = {}, cells = {},
    }
    local y = 0
    for a = 1, #actCounts do
        local n = actCounts[a]
        local act = { act = a, header = { x = x0, y = y, w = rowW, h = L.HEADER_H } }
        y = y + L.HEADER_H
        local rows = math.max(1, math.ceil(n / cols))
        act.first = #G.cells + 1
        for i = 1, n do
            local c = (i - 1) % cols
            local r = math.floor((i - 1) / cols)
            G.cells[#G.cells + 1] = {
                act = a, x = x0 + c * (cellW + L.GAP), y = y + r * (cellH + L.GAP),
                w = cellW, h = cellH,
            }
        end
        act.y = act.header.y
        y = y + rows * cellH + (rows - 1) * L.GAP
        act.bottom = y
        G.acts[a] = act
        y = y + L.ACT_GAP
    end
    G.contentH = y
    G.maxScroll = math.max(0, G.contentH - G.viewH)
    local chipGap = 8
    local chipW = math.floor((rowW - (#actCounts - 1) * chipGap) / math.max(1, #actCounts))
    G.chips = {}
    for a = 1, #actCounts do
        G.chips[a] = { x = x0 + (a - 1) * (chipW + chipGap), y = L.CHIP_Y, w = chipW, h = L.CHIP_H }
    end
    return G
end

function L.validateGrid(G, sw, sh)
    local problems = {}
    for i, c in ipairs(G.cells) do
        if c.x < 0 or c.x + c.w > sw then
            problems[#problems + 1] = ("celula %d fora da largura (%d..%d em %d)"):format(i, c.x, c.x + c.w, sw)
        end
        for j = i + 1, #G.cells do
            local d = G.cells[j]
            if c.x < d.x + d.w and d.x < c.x + c.w and c.y < d.y + d.h and d.y < c.y + c.h then
                problems[#problems + 1] = ("celulas %d e %d sobrepostas"):format(i, j)
            end
        end
    end
    if G.spriteS * L.REF_W > G.cellW - 2 * L.SPRITE_INSET + 0.5 then
        problems[#problems + 1] = ("sprite %.2fx nao cabe na celula de %d"):format(G.spriteS, G.cellW)
    end
    for a, ch in ipairs(G.chips) do
        if ch.x < 0 or ch.x + ch.w > sw or ch.y + ch.h > G.top then
            problems[#problems + 1] = ("atalho do ato %d fora da faixa"):format(a)
        end
    end
    return problems
end

local function fh(size) return FontManager.getFont(size):getHeight() end

L.LINE = 1.5

local function wrapH(text, size, w)
    local f = FontManager.getFont(size)
    local _, lines = f:getWrap(text or "", w)
    local n = #lines
    if n == 0 then return 0, 0 end
    local lh = math.floor(f:getHeight() * L.LINE)
    return (n - 1) * lh + f:getHeight(), n
end
L.wrapH = wrapH

function L.printWrapped(text, x, y, w, size, align)
    local f = FontManager.getFont(size)
    local prev = f:getLineHeight()
    f:setLineHeight(math.floor(f:getHeight() * L.LINE) / f:getHeight())
    love.graphics.setFont(f)
    love.graphics.printf(text or "", x, y, w, align or "left")
    f:setLineHeight(prev)
end

local function fitWrap(text, size, minSize, w, maxH)
    local s = size
    while s > minSize do
        local h = wrapH(text, s, w)
        if h <= maxH then return s, h end
        s = s - 1
    end
    return minSize, wrapH(text, minSize, w)
end

function L.card(sw, sh, k, texts)
    texts = texts or {}
    local pw = math.min(sw - 2 * L.MARGIN, L.PAGE_MAX_W)
    local ph = math.min(sh - 2 * L.MARGIN, L.PAGE_MAX_H)
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    local pad = L.PAGE_PAD
    local C = { page = { x = px, y = py, w = pw, h = ph }, pad = pad, fonts = {} }

    local btn = 30
    C.close = { x = px + pw - pad - btn + 8, y = py + pad - 10, w = btn, h = btn }
    C.next = { x = C.close.x - 10 - btn, y = C.close.y, w = btn, h = btn }
    C.counter = { x = C.next.x - 70, y = C.close.y, w = 66, h = btn }
    C.prev = { x = C.counter.x - 4 - btn, y = C.close.y, w = btn, h = btn }

    local innerX, innerW = px + pad, pw - 2 * pad
    local titleW = C.prev.x - 12 - innerX
    local nameSize = L.FONT.name
    while nameSize > L.FONT_MIN.name
        and FontManager.getFont(nameSize):getWidth(texts.name or "") > titleW do
        nameSize = nameSize - 1
    end
    C.fonts.name = nameSize
    local y = py + pad - 6
    C.name = { x = innerX, y = y, w = titleW, h = fh(nameSize) }
    y = y + C.name.h + 8
    local epSize, epH = fitWrap(texts.epithet, L.FONT.epithet, L.FONT_MIN.epithet, innerW, fh(L.FONT.epithet) * 2)
    C.fonts.epithet = epSize
    C.epithet = { x = innerX, y = y, w = innerW, h = math.max(fh(epSize), epH) }
    y = y + C.epithet.h + 8
    C.meta = { x = innerX, y = y, w = innerW, h = fh(L.FONT.meta) }
    y = y + C.meta.h + 10
    C.rule = { x = innerX, y = y, w = innerW, h = 2 }
    y = y + 2 + 14

    local bodyTop = y
    local bodyBottom = py + ph - pad
    local leftW = math.floor(innerW * 0.40)
    local gutter = 26
    local statsH = fh(L.FONT.stat) + 8 + math.floor(fh(L.FONT.statLabel) * L.LINE) + fh(L.FONT.statLabel) + 18
    C.portrait = { x = innerX, y = bodyTop, w = leftW, h = bodyBottom - bodyTop - statsH - 12 }
    C.stats = { x = innerX, y = C.portrait.y + C.portrait.h + 12, w = leftW, h = statsH }
    C.statCells = {}
    local sgap = 8
    local scw = math.floor((leftW - 2 * sgap) / 3)
    for i = 1, 3 do
        C.statCells[i] = { x = innerX + (i - 1) * (scw + sgap), y = C.stats.y, w = scw, h = statsH }
    end
    local sp = math.max(8, C.portrait.h - 20)
    C.spriteS, C.spriteP = L.spriteScale(C.portrait.w - 24, sp, k, L.REF_W, L.REF_H)

    local rx = innerX + leftW + gutter
    local rw = innerX + innerW - rx
    C.right = { x = rx, y = bodyTop, w = rw, h = bodyBottom - bodyTop }
    local headH = fh(L.FONT.head) + 8
    local avail = C.right.h
    local nMoves = math.max(1, texts.moveCount or 4)
    local moveCols = 2
    local moveRows = math.ceil(nMoves / moveCols)
    local bodySize = 10
    local lineH = fh(bodySize) + 6
    local movesH = headH + moveRows * lineH + ((texts.movesHint and (wrapH(texts.movesHint, bodySize, rw) + 10)) or 0)
    local sigText = texts.signature
    local sigH = 0
    local sigSize = bodySize
    if sigText and sigText ~= "" then
        local h
        sigSize, h = fitWrap(sigText, 10, L.FONT_MIN.body, rw - 16, math.floor(avail * 0.34))
        sigH = headH + h + 16 + 14
    end
    local loreMax = avail - movesH - sigH - 18
    local loreSize, loreH = fitWrap(texts.lore, 12, L.FONT_MIN.body, rw, math.max(fh(8), loreMax - headH))
    C.fonts.lore, C.fonts.signature, C.fonts.body = loreSize, sigSize, bodySize
    local ry = bodyTop
    C.loreHead = { x = rx, y = ry, w = rw, h = headH }
    ry = ry + headH
    C.lore = { x = rx, y = ry, w = rw, h = loreH }
    ry = ry + loreH + 18
    if sigH > 0 then
        C.sigBox = { x = rx, y = ry, w = rw, h = sigH - 14 }
        C.sigHead = { x = rx + 8, y = ry + 8, w = rw - 16, h = headH }
        C.signature = { x = rx + 8, y = ry + 8 + headH, w = rw - 16, h = sigH - 14 - headH - 16 }
        ry = ry + sigH
    end
    C.movesHead = { x = rx, y = ry, w = rw, h = headH }
    ry = ry + headH
    C.moves = { x = rx, y = ry, w = rw, h = movesH - headH, cols = moveCols, lineH = lineH }
    C.moveCells = {}
    local mcw = math.floor((rw - 12) / moveCols)
    for i = 1, nMoves do
        local c = (i - 1) % moveCols
        local r = math.floor((i - 1) / moveCols)
        C.moveCells[i] = { x = rx + c * (mcw + 12), y = ry + r * lineH, w = mcw, h = lineH }
    end
    if texts.movesHint then
        C.movesHint = { x = rx, y = ry + moveRows * lineH + 6, w = rw, h = wrapH(texts.movesHint, bodySize, rw) }
    end
    return C
end

local function inside(r, o)
    return r.x >= o.x - 0.5 and r.y >= o.y - 0.5 and r.x + r.w <= o.x + o.w + 0.5 and r.y + r.h <= o.y + o.h + 0.5
end

local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function L.validateCard(C, sw, sh, texts)
    texts = texts or {}
    local problems = {}
    local screen = { x = 0, y = 0, w = sw, h = sh }
    if not inside(C.page, screen) then problems[#problems + 1] = "pagina fora da tela" end
    local zones = { "close", "next", "prev", "counter", "name", "epithet", "meta", "portrait", "stats",
        "loreHead", "lore", "sigBox", "movesHead", "moves", "movesHint" }
    for _, z in ipairs(zones) do
        local r = C[z]
        if r and not inside(r, C.page) then problems[#problems + 1] = "zona " .. z .. " fora da pagina" end
    end
    local stack = { "loreHead", "lore", "sigBox", "movesHead", "moves" }
    local prev
    for _, z in ipairs(stack) do
        local r = C[z]
        if r then
            if prev and r.y < prev.y + prev.h - 0.5 then
                problems[#problems + 1] = ("zona %s invade a anterior"):format(z)
            end
            prev = r
        end
    end
    if C.movesHint and C.moves and C.movesHint.y + C.movesHint.h > C.page.y + C.page.h - C.pad + 0.5 then
        problems[#problems + 1] = "dica dos golpes passa da pagina"
    end
    if overlap(C.portrait, C.right) then problems[#problems + 1] = "retrato invade a coluna de texto" end
    if overlap(C.name, C.prev) then problems[#problems + 1] = "nome invade a navegacao" end
    if FontManager.getFont(C.fonts.name):getWidth(texts.name or "") > C.name.w then
        problems[#problems + 1] = "nome nao cabe"
    end
    local loreH = wrapH(texts.lore, C.fonts.lore, C.lore.w)
    if loreH > C.lore.h + 0.5 then problems[#problems + 1] = "lore nao cabe" end
    if texts.signature and texts.signature ~= "" and C.signature then
        local sh2 = wrapH(texts.signature, C.fonts.signature, C.signature.w)
        if sh2 > C.signature.h + 0.5 then problems[#problems + 1] = "assinatura nao cabe" end
    end
    for i, label in ipairs(texts.statLabels or {}) do
        local r = C.statCells[i]
        local _, n = wrapH(label, L.FONT.statLabel, r.w - 8)
        if n > 2 then problems[#problems + 1] = "rotulo de estatistica em mais de 2 linhas: " .. label end
    end
    local bottom = C.page.y + C.page.h - C.pad + 0.5
    local last = C.movesHint or C.moves
    if last and last.y + last.h > bottom then problems[#problems + 1] = "golpes passam da pagina" end
    if C.spriteS * L.REF_W > C.portrait.w or C.spriteS * L.REF_H > C.portrait.h then
        problems[#problems + 1] = "sprite nao cabe no retrato"
    end
    return problems
end

return L
