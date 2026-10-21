local FontManager = require("src.ui.FontManager")

local L = {}

L.MARGIN = 16
L.REF_W, L.REF_H = 126, 132
L.NAME_H = 22
L.CHIP_H = 28
L.CHIP_Y = 70
L.BOOK_MAX_W = 1200
L.BOOK_PAD = 24
L.BOOK_HEADER_H = 74
L.SLOT_TOP = 16
L.SLOT_GAP = 14
L.PAGE_GAP = 22
L.FOOTER_H = 18
L.SMALL_FIT = 1.34
L.BOSS_FIT = 2.0

L.PAGE_MAX_W, L.PAGE_MAX_H = 1040, 660
L.PAGE_PAD = 26
L.HABITAT_MIN = 70
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

function L.smallScale(k)
    k = k or 1
    local p = math.max(1, math.floor(k * L.SMALL_FIT + 1e-6))
    return p / k, p
end

function L.bossScale(k)
    k = k or 1
    local p = math.max(1, math.floor(k * L.BOSS_FIT + 1e-6))
    return p / k, p
end

function L.grid(sw, sh, top, bottom, k, entries)
    local pageW = math.min(sw - 2 * L.MARGIN, L.BOOK_MAX_W)
    local px = math.floor((sw - pageW) / 2)
    local pad = L.BOOK_PAD
    local innerW = pageW - 2 * pad
    local s, p = L.smallScale(k)
    local bs, bp = L.bossScale(k)
    local spriteH = math.ceil(L.REF_H * s) + 8
    local slotH = L.SLOT_TOP + spriteH + L.NAME_H + 8
    local bossW = math.max(math.ceil(L.REF_W * bs) + 40, math.floor(innerW * 0.29))
    local leftW = innerW - bossW - L.SLOT_GAP
    local cols = 3
    local slotW = math.floor((leftW - (cols - 1) * L.SLOT_GAP) / cols)
    local G = {
        x = px, w = pageW, top = top, bottom = bottom, viewH = bottom - top,
        spriteS = s, spriteP = p, bossS = bs, bossP = bp, spriteH = spriteH, slotH = slotH,
        cells = {}, acts = {}, pages = {}, cols = cols,
    }
    local byAct, order = {}, {}
    for i, e in ipairs(entries or {}) do
        if not byAct[e.act] then byAct[e.act] = {}; order[#order + 1] = e.act end
        byAct[e.act][#byAct[e.act] + 1] = i
    end
    table.sort(order)
    local y = 0
    for _, a in ipairs(order) do
        local list = byAct[a]
        local page = { act = a, x = px, y = y, w = pageW }
        local hy = y + pad
        page.header = { x = px + pad, y = hy, w = innerW, h = L.BOOK_HEADER_H }
        page.vignette = { x = px + pad + math.floor(innerW * 0.46), y = hy - 6,
            w = math.floor(innerW * 0.54), h = L.BOOK_HEADER_H }
        local sy = hy + L.BOOK_HEADER_H + 14
        local left, bosses = {}, {}
        for _, i in ipairs(list) do
            if entries[i].tier == "boss" then bosses[#bosses + 1] = i else left[#left + 1] = i end
        end
        local rows = math.max(2, math.ceil(#left / cols))
        local areaH = rows * slotH + (rows - 1) * L.SLOT_GAP
        local bossH = math.max(areaH, math.ceil(L.REF_H * bs) + L.SLOT_TOP + L.NAME_H + 40)
        if #bosses > 1 then
            bossH = math.max(bossH, #bosses * (math.ceil(L.REF_H * bs) + L.SLOT_TOP + L.NAME_H + 40))
        end
        areaH = math.max(areaH, bossH)
        for n, i in ipairs(left) do
            local c = (n - 1) % cols
            local r = math.floor((n - 1) / cols)
            G.cells[i] = { act = a, tier = entries[i].tier, x = px + pad + c * (slotW + L.SLOT_GAP),
                y = sy + r * (slotH + L.SLOT_GAP), w = slotW, h = slotH, s = s }
        end
        local each = math.floor((areaH - (#bosses - 1) * L.SLOT_GAP) / math.max(1, #bosses))
        for n, i in ipairs(bosses) do
            G.cells[i] = { act = a, tier = "boss", x = px + pad + leftW + L.SLOT_GAP,
                y = sy + (n - 1) * (each + L.SLOT_GAP), w = bossW, h = each, s = bs }
        end
        for _, i in ipairs(list) do
            local c = G.cells[i]
            local big = c.tier == "boss"
            c.nameY = c.y + c.h - L.NAME_H - (big and 30 or 4)
            c.groundY = c.nameY - 8
            c.spriteBox = { x = c.x + 4, y = c.y + L.SLOT_TOP - 4, w = c.w - 8, h = c.groundY - c.y - L.SLOT_TOP + 8 }
            c.seal = { x = c.x + c.w - 20, y = c.y + 20, r = big and 16 or 12 }
        end
        page.footer = { x = px + pad, y = sy + areaH + 10, w = innerW, h = L.FOOTER_H }
        page.h = page.footer.y + L.FOOTER_H + pad - y
        G.pages[#G.pages + 1] = page
        G.acts[a] = { act = a, header = { x = px, y = y, w = pageW, h = page.h }, page = page }
        y = y + page.h + L.PAGE_GAP
    end
    G.contentH = y
    G.maxScroll = math.max(0, G.contentH - G.viewH)
    local n = #order
    local chipGap = 6
    local chipW = math.floor((pageW - (n - 1) * chipGap) / math.max(1, n))
    G.chips = {}
    for idx, a in ipairs(order) do
        G.chips[a] = { x = px + (idx - 1) * (chipW + chipGap), y = L.CHIP_Y, w = chipW, h = L.CHIP_H }
    end
    return G
end

local function rectIn(r, o)
    return r.x >= o.x - 0.5 and r.y >= o.y - 0.5 and r.x + r.w <= o.x + o.w + 0.5 and r.y + r.h <= o.y + o.h + 0.5
end

function L.validateGrid(G, sw, sh)
    local problems = {}
    local list = {}
    for i, c in pairs(G.cells) do list[#list + 1] = { i = i, c = c } end
    for _, page in ipairs(G.pages) do
        if page.x < 0 or page.x + page.w > sw then
            problems[#problems + 1] = ("pagina do ato %d fora da largura"):format(page.act)
        end
    end
    for n, it in ipairs(list) do
        local c = it.c
        local page = G.acts[c.act].page
        if not rectIn(c, page) then problems[#problems + 1] = ("vaga %d fora da pagina"):format(it.i) end
        local need = math.ceil(L.REF_W * c.s)
        if need > c.spriteBox.w then
            problems[#problems + 1] = ("sprite %.2fx nao cabe na vaga %d (%d > %d)"):format(c.s, it.i, need, c.spriteBox.w)
        end
        if math.ceil(L.REF_H * c.s) > c.groundY - c.y - 6 then
            problems[#problems + 1] = ("sprite alto demais na vaga %d"):format(it.i)
        end
        for m = n + 1, #list do
            local d = list[m].c
            if c.x < d.x + d.w and d.x < c.x + c.w and c.y < d.y + d.h and d.y < c.y + c.h then
                problems[#problems + 1] = ("vagas %d e %d sobrepostas"):format(it.i, list[m].i)
            end
        end
    end
    for a, ch in pairs(G.chips) do
        if ch.x < 0 or ch.x + ch.w > sw or ch.y + ch.h > G.top then
            problems[#problems + 1] = ("marcador do ato %d fora da faixa"):format(a)
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

    local btn = 26
    C.close = { x = px + pw - pad - btn + 6, y = py + pad - 8, w = btn, h = btn }
    C.next = { x = C.close.x - 8 - btn, y = C.close.y, w = btn, h = btn }
    C.counter = { x = C.next.x - 62, y = C.close.y, w = 58, h = btn }
    C.prev = { x = C.counter.x - 4 - btn, y = C.close.y, w = btn, h = btn }

    local innerX, innerW = px + pad, pw - 2 * pad
    local sealW = texts.tier ~= "common" and 40 or 0
    local titleW = C.prev.x - 16 - innerX - sealW
    local nameSize = texts.tier == "boss" and 24 or 16
    while nameSize > L.FONT_MIN.name
        and FontManager.getFont(nameSize):getWidth(texts.name or "") > titleW do
        nameSize = nameSize - 1
    end
    C.fonts.name = nameSize
    local y = py + pad - 6
    C.name = { x = innerX, y = y, w = titleW, h = fh(nameSize) }
    if sealW > 0 then
        local nw = math.min(titleW, FontManager.getFont(nameSize):getWidth(texts.name or ""))
        C.seal = { x = innerX + nw + 26, y = y + math.floor(fh(nameSize) / 2), r = 13 }
    end
    y = y + C.name.h + 8
    local epSize, epH = fitWrap(texts.epithet, L.FONT.epithet, L.FONT_MIN.epithet, innerW, fh(L.FONT.epithet) * 2 + 4)
    C.fonts.epithet = epSize
    C.epithet = { x = innerX, y = y, w = innerW, h = math.max(fh(epSize), epH) }
    y = y + C.epithet.h + 6
    C.meta = { x = innerX, y = y, w = innerW, h = fh(L.FONT.meta) }
    y = y + C.meta.h + 8
    C.rule = { x = innerX, y = y, w = innerW, h = 4 }
    y = y + 4 + 12

    local bodyTop = y
    local bodyBottom = py + ph - pad
    local leftW = math.floor(innerW * 0.40)
    local gutter = 28
    local rowH = math.max(fh(8), 12) + 8
    local ledgerH = 3 * rowH + 4
    C.figure = { x = innerX, y = bodyTop, w = leftW, h = bodyBottom - bodyTop - ledgerH - 14 }
    C.ledger = { x = innerX, y = C.figure.y + C.figure.h + 14, w = leftW, h = ledgerH, rowH = rowH }
    C.spriteS, C.spriteP = L.spriteScale(C.figure.w - 24, C.figure.h - 30, k, L.REF_W, L.REF_H)

    local rx = innerX + leftW + gutter
    local rw = innerX + innerW - rx
    C.right = { x = rx, y = bodyTop, w = rw, h = bodyBottom - bodyTop }
    local headH = fh(L.FONT.head) + 10
    local avail = C.right.h
    local nMoves = math.max(1, texts.moveCount or 4)
    local moveCols = 2
    local moveRows = math.ceil(nMoves / moveCols)
    local bodySize = 10
    local lineH = fh(bodySize) + 7
    local hintH = texts.movesHint and (wrapH(texts.movesHint, 8, rw) + 8) or 0
    local movesH = headH + moveRows * lineH + hintH
    local sigText = texts.signature
    local sigH, sigSize = 0, 10
    if sigText and sigText ~= "" then
        local h
        sigSize, h = fitWrap(sigText, 10, L.FONT_MIN.body, rw - 22, math.floor(avail * 0.3))
        sigH = h + fh(8) + 14 + 16
    end
    local loreMax = avail - movesH - sigH - 18 - L.HABITAT_MIN
    local loreSize, loreH = fitWrap(texts.lore, 12, L.FONT_MIN.body, rw, math.max(fh(8), loreMax - headH))
    C.fonts.lore, C.fonts.signature, C.fonts.body = loreSize, sigSize, bodySize
    local ry = bodyTop
    C.loreHead = { x = rx, y = ry, w = rw, h = headH }
    ry = ry + headH
    C.lore = { x = rx, y = ry, w = rw, h = loreH }
    ry = ry + loreH + 16
    if sigH > 0 then
        C.sigBox = { x = rx, y = ry, w = rw, h = sigH - 16 }
        C.sigHead = { x = rx + 18, y = ry + 2, w = rw - 22, h = fh(8) + 6 }
        C.signature = { x = rx + 18, y = ry + 2 + fh(8) + 8, w = rw - 22, h = sigH - 16 - fh(8) - 10 }
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
        C.movesHint = { x = rx, y = ry + moveRows * lineH + 4, w = rw, h = hintH - 8 }
    end
    ry = C.moves.y + C.moves.h + 12
    local habH = bodyBottom - ry
    if habH >= L.HABITAT_MIN then
        C.habitat = { x = rx, y = ry, w = rw, h = habH }
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
    local zones = { "close", "next", "prev", "counter", "name", "epithet", "meta", "figure", "ledger",
        "loreHead", "lore", "sigBox", "movesHead", "moves", "movesHint", "habitat" }
    for _, z in ipairs(zones) do
        local r = C[z]
        if r and not inside(r, C.page) then problems[#problems + 1] = "zona " .. z .. " fora da pagina" end
    end
    local stack = { "loreHead", "lore", "sigBox", "movesHead", "moves", "habitat" }
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
    if C.movesHint and C.movesHint.y + C.movesHint.h > C.page.y + C.page.h - C.pad + 0.5 then
        problems[#problems + 1] = "dica dos golpes passa da pagina"
    end
    if overlap(C.figure, C.right) or overlap(C.ledger, C.right) then
        problems[#problems + 1] = "coluna da criatura invade a coluna de texto"
    end
    if overlap(C.name, C.prev) then problems[#problems + 1] = "nome invade a navegacao" end
    if C.seal and (C.seal.x + C.seal.r > C.prev.x) then problems[#problems + 1] = "selo invade a navegacao" end
    if FontManager.getFont(C.fonts.name):getWidth(texts.name or "") > C.name.w then
        problems[#problems + 1] = "nome nao cabe"
    end
    local loreH = wrapH(texts.lore, C.fonts.lore, C.lore.w)
    if loreH > C.lore.h + 0.5 then problems[#problems + 1] = "lore nao cabe" end
    if texts.signature and texts.signature ~= "" and C.signature then
        local sh2 = wrapH(texts.signature, C.fonts.signature, C.signature.w)
        if sh2 > C.signature.h + 0.5 then problems[#problems + 1] = "assinatura nao cabe" end
    end
    if texts.movesHint and C.movesHint then
        local hh = wrapH(texts.movesHint, 8, C.movesHint.w)
        if hh > C.movesHint.h + 0.5 then problems[#problems + 1] = "dica dos golpes nao cabe" end
    end
    local bottom = C.page.y + C.page.h - C.pad + 0.5
    local last = C.movesHint or C.moves
    if last and last.y + last.h > bottom then problems[#problems + 1] = "golpes passam da pagina" end
    if C.spriteS * L.REF_W > C.figure.w or C.spriteS * L.REF_H > C.figure.h then
        problems[#problems + 1] = "sprite nao cabe na figura"
    end
    local f = FontManager.getFont(8)
    for _, label in ipairs(texts.statLabels or {}) do
        if f:getWidth(label) > C.ledger.w * 0.5 then
            problems[#problems + 1] = "rotulo do livro-caixa largo demais: " .. label
        end
    end
    return problems
end

return L
