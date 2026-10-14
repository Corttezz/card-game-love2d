local RunJournalLayout = {}

local R = RunJournalLayout
R.HEADER_H     = 60
R.BOTTOM_PAD   = 10
R.SHEET_MAX_W  = 840
R.SHEET_GAP    = 10
R.CLOSED_H     = 34
R.TITLE_H      = 28
R.PAD_X        = 14
R.PAD_T        = 6
R.PAD_B        = 8
R.FLOOR_COL_W  = 24
R.COL_GAP      = 8
R.MAP_FRACTION = 0.44
R.ROW_MIN      = 28
R.ROW_MAX      = 56
R.ROW_DIV      = 15
R.GLYPH        = 9
R.CASTLE_W     = 21
R.CASTLE_H     = 13
R.LEGEND_H     = 15
R.TIP_GAP      = 8
R.TOP_SLACK    = 6

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local bit = require("bit")
local bxor, lshift, rshift, band, tobit = bit.bxor, bit.lshift, bit.rshift, bit.band, bit.tobit
local function hash(...)
    local h = 0x1234567
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        v = math.floor(tonumber(v) or 0) % 2147483647
        h = tobit(h + v * 2654435 + 12345)
        h = tobit(bxor(h, lshift(h, 13)))
        h = tobit(bxor(h, rshift(h, 17)))
        h = tobit(bxor(h, lshift(h, 5)))
        h = tobit(h * 1664525 + 1013904223)
    end
    return (band(h, 0x7fffffff) % 10007) / 10007
end
R.hash = hash

local function noteSizeFor(w)
    if w >= 240 then return 9 end
    return 8
end

function RunJournalLayout.compute(sw, sh, acts, scroll, seed)
    seed = seed or 0
    local margin   = clamp(math.floor(sw * 0.035), 12, 48)
    local sheetW   = math.min(sw - margin * 2, R.SHEET_MAX_W)
    local sheetX   = math.floor((sw - sheetW) / 2)
    local rowH     = clamp(math.floor(sheetW / R.ROW_DIV), R.ROW_MIN, R.ROW_MAX)
    local gs       = (rowH >= 40) and 2 or 1
    local glyph    = R.GLYPH * gs
    local innerX   = sheetX + R.PAD_X
    local innerW   = sheetW - R.PAD_X * 2
    local mapW     = math.floor((innerW - R.FLOOR_COL_W - R.COL_GAP * 2) * R.MAP_FRACTION)
    local noteW    = innerW - R.FLOOR_COL_W - R.COL_GAP * 2 - mapW
    local slotGap  = clamp(math.floor(mapW / 4), glyph + 14, 72)

    local zone = {
        x = 0, y = R.HEADER_H, w = sw,
        h = math.max(40, sh - R.HEADER_H - R.BOTTOM_PAD),
    }

    local L = {
        sw = sw, sh = sh,
        header = { x = 0, y = 0, w = sw, h = R.HEADER_H },
        zone = zone,
        sheetX = sheetX, sheetW = sheetW,
        rowH = rowH, glyphScale = gs, glyph = glyph, slotGap = slotGap,
        noteSize = noteSizeFor(noteW),
        sheets = {},
    }

    local contentH = 0
    for i, a in ipairs(acts) do
        local S = { open = a.open and true or false, isEndless = a.isEndless and true or false }
        if S.open then
            local rows
            if a.isEndless then
                rows = 0
                for _, nd in ipairs(a.nodes or {}) do rows = math.max(rows, nd.row or 0) end
                if a.pending then rows = math.max(rows, a.pending.row or 0) end
                rows = math.max(1, rows)
            else
                rows = R.FLOORS or 8
            end
            local nLegend = a.legend or 0
            local legendRows = 0
            local legendCols = 0
            if nLegend > 0 then
                legendRows = (sheetW < 620 and nLegend > 4) and 2 or 1
                legendCols = math.ceil(nLegend / legendRows)
            end
            S.rows = rows
            S.legendRows, S.legendCols = legendRows, legendCols
            S.h = R.TITLE_H + R.PAD_T + rows * rowH + legendRows * R.LEGEND_H
                + (legendRows > 0 and 4 or 0) + R.PAD_B
        else
            S.rows = 0
            S.h = R.CLOSED_H
        end
        L.sheets[i] = S
        contentH = contentH + S.h + R.SHEET_GAP
    end
    contentH = math.max(0, contentH - R.SHEET_GAP)
    L.contentH = contentH
    L.maxScroll = math.max(0, contentH - zone.h + R.TOP_SLACK)
    L.scroll = clamp(scroll or 0, 0, L.maxScroll)

    local y = zone.y + R.TOP_SLACK - L.scroll
    for i, S in ipairs(L.sheets) do
        local a = acts[i]
        S.x, S.y, S.w = sheetX, y, sheetW
        S.title = { x = innerX, y = y + (S.open and 0 or 0), w = innerW, h = S.open and R.TITLE_H or R.CLOSED_H }
        if S.open then
            local mapTop = y + R.TITLE_H + R.PAD_T
            local mapH = S.rows * rowH
            S.floorCol = { x = innerX, y = mapTop, w = R.FLOOR_COL_W, h = mapH }
            S.map = { x = innerX + R.FLOOR_COL_W + R.COL_GAP, y = mapTop, w = mapW, h = mapH }
            S.noteCol = { x = S.map.x + mapW + R.COL_GAP, y = mapTop, w = noteW, h = mapH }
            if S.legendRows > 0 then
                S.legend = { x = innerX, y = mapTop + mapH + 4, w = innerW,
                    h = S.legendRows * R.LEGEND_H, cols = S.legendCols, rows = S.legendRows,
                    itemW = math.floor(innerW / S.legendCols) }
            end

            S.rowY = {}
            for r = 1, S.rows do
                S.rowY[r] = S.map.y + mapH - math.floor((r - 0.5) * rowH)
            end

            local half = glyph / 2
            local minX = S.map.x + half + 4
            local maxX = S.map.x + mapW - half - 4
            local function slotsFor(row, n, fromX, idx)
                local span = (n - 1) * slotGap
                local cxc = clamp(fromX, minX + span / 2, maxX - span / 2)
                local slots = {}
                for k = 1, n do
                    local jx = math.floor((hash(seed, i, row, k, idx or 0) - 0.5) * 7)
                    local jy = math.floor((hash(seed, i, row, k, 99 + (idx or 0)) - 0.5) * 5)
                    local x = clamp(math.floor(cxc + (k - (n + 1) / 2) * slotGap + jx), minX, maxX)
                    slots[k] = { x = x, y = S.rowY[row] + jy, k = k }
                end
                return slots
            end

            S.nodes, S.stubs, S.segments = {}, {}, {}
            local fromX = S.map.x + math.floor(mapW / 2)
            local prev = nil
            S.start = { x = fromX, y = S.map.y + mapH - 1 }
            for ni, nd in ipairs(a.nodes or {}) do
                local n = math.max(1, nd.n or 1)
                local pick = clamp(nd.pick or 1, 1, n)
                local row = clamp(nd.row or ni, 1, S.rows)
                local slots = slotsFor(row, n, fromX, ni)
                local chosen = slots[pick]
                S.nodes[ni] = { x = chosen.x, y = chosen.y, row = row, slot = pick, n = n }
                if ni == 1 then S.start.x = chosen.x end
                for k, sl in ipairs(slots) do
                    if k ~= pick then
                        S.stubs[#S.stubs + 1] = {
                            x = sl.x, y = sl.y, row = row, node = ni, slot = k,
                            fromX = prev and prev.x or S.start.x,
                            fromY = prev and prev.y or S.start.y,
                        }
                    end
                end
                if prev then
                    S.segments[#S.segments + 1] = { x1 = prev.x, y1 = prev.y, x2 = chosen.x, y2 = chosen.y, node = ni }
                end
                prev = S.nodes[ni]
                fromX = chosen.x
            end
            if a.pending and prev then
                local n = math.max(1, a.pending.n or 1)
                local row = clamp(a.pending.row or (prev.row + 1), 1, S.rows)
                S.pending = {}
                for k, sl in ipairs(slotsFor(row, n, prev.x, 500)) do
                    S.pending[k] = { x = sl.x, y = sl.y, row = row, slot = k, fromX = prev.x, fromY = prev.y }
                end
            end
            if not a.isEndless then
                local cw, ch = R.CASTLE_W * gs, R.CASTLE_H * gs
                local top = S.nodes[#S.nodes]
                local reached = top and top.row == S.rows
                local cx = reached and top.x or (S.map.x + math.floor(mapW / 2))
                local cy = reached and top.y or S.rowY[S.rows]
                S.castle = { x = clamp(cx - math.floor(cw / 2), S.map.x, S.map.x + mapW - cw),
                             y = cy - math.floor(ch / 2), w = cw, h = ch, reached = reached and true or false }
            end
        end
        y = y + S.h + R.SHEET_GAP
    end
    return L
end

R.FLOORS = 8

function RunJournalLayout.glyphRect(L, p)
    local g = L.glyph
    return { x = p.x - math.floor(g / 2) - 3, y = p.y - math.floor(g / 2) - 3, w = g + 6, h = g + 6 }
end

function RunJournalLayout.tipRect(L, S, p, w, h)
    local gr = RunJournalLayout.glyphRect(L, p)
    local right = gr.x + gr.w + R.TIP_GAP
    local x
    if right + w <= L.sw - 6 then
        x = right
    elseif gr.x - R.TIP_GAP - w >= 6 then
        x = gr.x - R.TIP_GAP - w
    else
        x = clamp(right, 6, math.max(6, L.sw - 6 - w))
    end
    local top = math.max(S.y, L.zone.y)
    local bot = math.min(S.y + S.h, L.zone.y + L.zone.h)
    local y = clamp(gr.y - 4, top, math.max(top, bot - h))
    return { x = x, y = y, w = w, h = h }
end

function RunJournalLayout.maxTipH(L, S)
    local top = math.max(S.y, L.zone.y)
    local bot = math.min(S.y + S.h, L.zone.y + L.zone.h)
    return math.max(0, bot - top)
end

function RunJournalLayout.tipRoom(L, S, p)
    local gr = RunJournalLayout.glyphRect(L, p)
    local right = L.sw - 6 - (gr.x + gr.w + R.TIP_GAP)
    local left = gr.x - R.TIP_GAP - 6
    return math.max(right, left)
end

local function inside(a, b)
    return a.x >= b.x - 0.5 and a.y >= b.y - 0.5
        and a.x + a.w <= b.x + b.w + 0.5 and a.y + a.h <= b.y + b.h + 0.5
end
local function overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function RunJournalLayout.validate(L, tip)
    local problems = {}
    local function bad(msg) problems[#problems + 1] = msg end

    if L.zone.y < L.header.y + L.header.h then bad("folhas sobem no cabecalho") end
    if L.sheetX < 0 or L.sheetX + L.sheetW > L.sw then bad("folha estoura a largura da janela") end
    if L.scroll < 0 or L.scroll > L.maxScroll + 0.001 then bad("scroll fora do conteudo") end

    for si, S in ipairs(L.sheets) do
        local tag = "folha " .. si
        if not inside(S.title, S) then bad(tag .. ": titulo fora da folha") end
        local nb = L.sheets[si + 1]
        if nb and S.y + S.h > nb.y then bad(tag .. " encosta na seguinte") end
        if L.maxScroll == 0 then
            if S.y < L.zone.y - 1 or S.y + S.h > L.zone.y + L.zone.h + 1 then
                bad(tag .. " fora da zona sem scroll")
            end
        end
        if S.open then
            for _, name in ipairs({ "floorCol", "map", "noteCol" }) do
                if not inside(S[name], S) then bad(tag .. ": " .. name .. " fora da folha") end
                if S[name].y < S.title.y + S.title.h then bad(tag .. ": " .. name .. " invade o titulo") end
            end
            if overlaps(S.floorCol, S.map) then bad(tag .. ": numerais invadem o mapa") end
            if overlaps(S.map, S.noteCol) then bad(tag .. ": mapa invade a margem") end
            if S.noteCol.w < 40 then bad(tag .. ": margem estreita demais") end
            if S.legend then
                if not inside(S.legend, S) then bad(tag .. ": legenda fora da folha") end
                if S.legend.y < S.map.y + S.map.h then bad(tag .. ": legenda invade o mapa") end
            end
            for ni, p in ipairs(S.nodes) do
                local gr = RunJournalLayout.glyphRect(L, p)
                if not inside(gr, S.map) then bad(("%s: parada %d fora do mapa"):format(tag, ni)) end
                if ni > 1 then
                    local seg = S.segments[ni - 1]
                    local q = S.nodes[ni - 1]
                    if not seg or seg.x1 ~= q.x or seg.y1 ~= q.y or seg.x2 ~= p.x or seg.y2 ~= p.y then
                        bad(("%s: caminho interrompido entre %d e %d"):format(tag, ni - 1, ni))
                    end
                end
                for _, st in ipairs(S.stubs) do
                    if st.node == ni and overlaps(gr, RunJournalLayout.glyphRect(L, st)) then
                        bad(("%s: ramo encosta na parada %d"):format(tag, ni))
                    end
                end
            end
            for k, st in ipairs(S.stubs) do
                if not inside(RunJournalLayout.glyphRect(L, st), S.map) then
                    bad(("%s: ramo %d fora do mapa"):format(tag, k))
                end
            end
            for k, pd in ipairs(S.pending or {}) do
                if not inside(RunJournalLayout.glyphRect(L, pd), S.map) then
                    bad(("%s: ramo pendente %d fora do mapa"):format(tag, k))
                end
            end
            if S.castle and not inside(S.castle, S.map) then bad(tag .. ": castelo fora do mapa") end
        end
    end

    if tip then
        local r, S = tip.rect, L.sheets[tip.sheet]
        if r.x < 0 or r.y < 0 or r.x + r.w > L.sw or r.y + r.h > L.sh then
            bad("detalhe sai da janela")
        end
        if r.y < L.zone.y - 0.5 or r.y + r.h > L.zone.y + L.zone.h + 0.5 then
            bad("detalhe sai da zona das folhas")
        end
        if S and (r.y < S.y - 0.5 or r.y + r.h > S.y + S.h + 0.5) then
            bad("detalhe invade outra folha")
        end
        if tip.node then
            local gr = RunJournalLayout.glyphRect(L, tip.node)
            if overlaps(r, gr) then bad("detalhe tapa a propria parada") end
        end
    end
    return problems
end

return RunJournalLayout
