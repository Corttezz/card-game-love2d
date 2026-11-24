local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local Ink         = require("src.ui.RunJournalInk")
local Parchment   = require("src.ui.MapParchment")
local MapManager  = require("src.systems.MapManager")
local ActSystem   = require("src.systems.ActSystem")
local Sfx         = require("src.systems.Sfx")
local I18n        = require("src.i18n.I18n")

local ActMapScreen = {}
ActMapScreen.__index = ActMapScreen

ActMapScreen.TOP_GAP     = 58
ActMapScreen.MARGIN      = 12
ActMapScreen.HEAD_H      = 56
ActMapScreen.BOSS_H      = 92
ActMapScreen.FOOT_H      = 30
ActMapScreen.LEG_W       = 250
ActMapScreen.GUTTER      = 70
ActMapScreen.MAP_W       = 600
ActMapScreen.TOP_PAD     = 46
ActMapScreen.NODE_R      = 19
ActMapScreen.HIT_R       = 26
ActMapScreen.ROWS_SHOWN  = 7
ActMapScreen.FOCUS       = 0.74
ActMapScreen.SCROLL_STEP = 62
ActMapScreen.SCROLL_EASE = 14
ActMapScreen.LEGEND      = { "battle", "elite", "event", "shop", "rest", "mini_boss", "boss" }

local INK, RED = Ink.INK, Ink.RED
local GOLD = Palette.AGED_GOLD
local GOLD_DARK = Palette.AGED_GOLD_DARK
local hash = Ink.hash

local TYPE_COLOR = {
    battle    = INK,
    elite     = RED,
    mini_boss = RED,
    boss      = RED,
    event     = Palette.PURPLE_DEEP,
    shop      = GOLD_DARK,
    rest      = Palette.MOSS,
}

local FADED = 0.22

local function colorOf(ty) return TYPE_COLOR[ty] or INK end

local function sfx(name, fallback)
    if Sfx.has(name) then Sfx.play(name) elseif fallback then Sfx.play(fallback) end
end

local function setAlpha(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local function font(kind, size)
    return FontManager.getFontAt(kind == "title" and FontManager.MAP_TITLE or FontManager.MAP_TEXT, size)
end

local function text(s, x, y, kind, size, opts)
    opts = opts or {}
    local min = opts.minSize or math.max(10, size - 8)
    local f = font(kind, size)
    while opts.maxW and f:getWidth(s) > opts.maxW and size > min do
        size = size - 1
        f = font(kind, size)
    end
    local dx = x
    if opts.maxW and opts.align == "center" then
        dx = x + math.floor((opts.maxW - f:getWidth(s)) / 2)
    elseif opts.maxW and opts.align == "right" then
        dx = x + opts.maxW - f:getWidth(s)
    end
    love.graphics.setFont(f)
    love.graphics.print(s, math.floor(dx), math.floor(y))
    return f:getWidth(s), f:getHeight()
end
ActMapScreen.text = text

local function para(s, x, y, w, size)
    local f = font("text", size)
    love.graphics.setFont(f)
    local _, lines = f:getWrap(s, w)
    love.graphics.printf(s, math.floor(x), math.floor(y), w, "left")
    return #lines * f:getHeight()
end

local function runOf(game)
    local rm = game and game.runManager
    return rm and rm.currentRun or nil
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

function ActMapScreen:new()
    local o = setmetatable({}, ActMapScreen)
    o.visible = false
    o.game = nil
    o._openedAt = 0
    o._hover = nil
    o._scroll = 0
    o._scrollTo = 0
    o._snap = true
    return o
end

function ActMapScreen:isVisible() return self.visible end

function ActMapScreen:show(game)
    self.game = game or self.game
    local run = runOf(self.game)
    if run and self.game.runManager.ensureActMap and not run.endlessMode then
        self.game.runManager:ensureActMap()
    end
    self.visible = true
    self._openedAt = love.timer.getTime()
    self._hover = nil
    self._forceHover = nil
    self._snap = true
    sfx("mapOpen", "menuOpen")
end

function ActMapScreen:hide()
    if not self.visible then return end
    self.visible = false
    self._hover = nil
    self._forceHover = nil
    sfx("mapClose", "menuClose")
end

function ActMapScreen:toggle(game)
    if self.visible then self:hide() else self:show(game) end
end

function ActMapScreen:resize()
    self._hover = nil
    self._snap = true
    Ink.clearPaperCache()
    Parchment.clear()
end

function ActMapScreen:update(dt) end

function ActMapScreen:map()
    local run = runOf(self.game)
    local map = run and run.actMap
    if not map or map.act ~= run.actNumber or run.endlessMode then return nil, run end
    return map, run
end

function ActMapScreen.rowOf(map, f, i, n)
    local row = map.floors[f]
    local cols = map.cols or MapManager.MAP_COLS
    if n.mapCol then return n.mapCol, cols end
    if #row == 1 then return (cols + 1) / 2, cols end
    return (i - 0.5) / #row * cols + 0.5, cols
end

function ActMapScreen.layout(map, sw, sh, seed, scroll)
    local S = ActMapScreen
    local x, y = S.MARGIN, S.TOP_GAP
    local w, h = sw - S.MARGIN * 2, sh - S.TOP_GAP - S.MARGIN
    local F = #map.floors
    local L = { x = x, y = y, w = w, h = h, pts = {} }
    L.legend = { x = x + w - S.LEG_W - 12, y = y + S.HEAD_H + 6, w = S.LEG_W }
    L.legend.h = y + h - S.FOOT_H - 6 - L.legend.y
    local left, right = x + 12, L.legend.x - 14
    local ax = left + S.GUTTER
    local aw = right - ax
    local mw = math.min(S.MAP_W, aw - 70)
    L.area = { x = math.floor(ax + (aw - mw) / 2), w = mw }
    L.gutter = { x = left, w = S.GUTTER }
    L.boss = { x = left, y = y + S.HEAD_H + 2, w = right - left, h = S.BOSS_H }
    L.view = { x = left, y = L.boss.y + L.boss.h + 2, w = right - left }
    L.view.h = y + h - S.FOOT_H - L.view.y
    L.rowH = math.floor(math.max(54, math.min(84, (L.view.h - S.TOP_PAD) / S.ROWS_SHOWN)))
    L.content = S.TOP_PAD + (F - 2) * L.rowH + math.floor(L.rowH * 0.9) + 34
    L.maxScroll = math.max(0, L.content - L.view.h)
    L.scroll = math.max(0, math.min(L.maxScroll, scroll or 0))
    local cols = map.cols or MapManager.MAP_COLS
    L.colW = L.area.w / math.max(1, cols - 1)
    L.rowY = {}
    for f = 1, F - 1 do
        L.rowY[f] = math.floor(L.view.y + S.TOP_PAD + (F - 1 - f) * L.rowH - L.scroll)
    end
    for f, row in ipairs(map.floors) do
        L.pts[f] = {}
        for i, n in ipairs(row) do
            local px, py
            if f == F then
                px, py = L.area.x + L.area.w / 2, L.boss.y + 34
            else
                local c = ActMapScreen.rowOf(map, f, i, n)
                px, py = L.area.x + (c - 1) * L.colW, L.rowY[f]
                if #row > 1 then
                    px = px + (hash(seed, f, i, 1) - 0.5) * L.colW * 0.36
                    py = py + (hash(seed, f, i, 2) - 0.5) * L.rowH * 0.24
                end
            end
            L.pts[f][i] = { x = math.floor(px), y = math.floor(py) }
        end
    end
    L.start = { x = math.floor(L.area.x + L.area.w / 2), y = math.floor(L.rowY[1] + L.rowH * 0.9) }
    return L
end

function ActMapScreen.focusScroll(L, floorNow, F)
    local f = math.max(1, math.min(F - 1, floorNow))
    local y = L.rowY[f] + L.scroll - L.view.y
    return math.max(0, math.min(L.maxScroll, y - L.view.h * ActMapScreen.FOCUS))
end

function ActMapScreen.inView(L, p, pad)
    pad = pad or 0
    return p.y >= L.view.y - pad and p.y <= L.view.y + L.view.h + pad
end

function ActMapScreen.reach(map, run)
    local out = {}
    local floorNow = run.floorInAct or 1
    local start = {}
    for _, n in ipairs(run.pendingNodes or {}) do
        if n.mapFloor == floorNow and n.mapLane then start[n.mapLane] = true end
    end
    local cur = run.currentNode
    if next(start) == nil and cur and cur.mapFloor and map.floors[cur.mapFloor] then
        for _, j in ipairs(cur.mapNext or {}) do start[j] = true end
        floorNow = cur.mapFloor + 1
    end
    if next(start) == nil then return out, floorNow, start end
    out[floorNow] = start
    for f = floorNow, #map.floors - 1 do
        local nxt = {}
        for lane in pairs(out[f] or {}) do
            local n = map.floors[f][lane]
            for _, j in ipairs((n and n.mapNext) or {}) do nxt[j] = true end
        end
        out[f + 1] = nxt
    end
    return out, floorNow, start
end

local function pathSet(map, run)
    local p = {}
    for f, lane in pairs(map.path or {}) do p[f] = lane end
    local cur = run.currentNode
    if cur and cur.mapFloor and cur.mapLane and map.floors[cur.mapFloor] then p[cur.mapFloor] = cur.mapLane end
    return p
end

local function trimmed(a, b, r1, r2)
    local dx, dy = b.x - a.x, b.y - a.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < r1 + r2 + 2 then return a.x, a.y, b.x, b.y end
    local ux, uy = dx / len, dy / len
    return a.x + ux * r1, a.y + uy * r1, b.x - ux * r2, b.y - uy * r2
end

local function thick(x1, y1, x2, y2, color, alpha, seed, width, opts)
    opts = opts or {}
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local nx, ny = -dy / len, dx / len
    for k = 0, width - 1 do
        local o = (k - (width - 1) / 2) * 0.9
        Ink.line(x1 + nx * o, y1 + ny * o, x2 + nx * o, y2 + ny * o, color, alpha, seed,
            { wobble = opts.wobble or 0.9, dash = opts.dash, gap = opts.gap })
    end
end
ActMapScreen.thick = thick

local function arrow(x1, y1, x2, y2, color, alpha, seed, at, size)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 24 then return end
    local ux, uy = dx / len, dy / len
    local tx, ty = x1 + dx * at, y1 + dy * at
    size = size or 7
    for s = -1, 1, 2 do
        local c, sn = math.cos(2.55 * s), math.sin(2.55 * s)
        local bx = tx + (ux * c - uy * sn) * size
        local by = ty + (ux * sn + uy * c) * size
        thick(tx, ty, bx, by, color, alpha, seed + s, 2, { wobble = 0.1 })
    end
end

local function mountain(x, y, s, seed)
    thick(x - 7 * s, y, x, y - 8 * s, INK, 0.3, seed, 2, { wobble = 0.5 })
    thick(x, y - 8 * s, x + 7 * s, y, INK, 0.3, seed + 1, 2, { wobble = 0.5 })
    Ink.line(x + 1, y - 7 * s, x + 4 * s, y - 2, INK, 0.2, seed + 2, { wobble = 0.3, dash = 1, gap = 1 })
end

local function tree(x, y, s, seed)
    thick(x, y, x, y - 5 * s, INK, 0.3, seed, 2, { wobble = 0.1 })
    Ink.ring(x, y - 9 * s, 4 * s, Palette.MOSS, 0.38, seed + 1, 2)
end

local function grass(x, y, s, seed)
    for k = 0, 2 do
        Ink.line(x + k * 4, y, x + k * 4 + (k - 1) * 2, y - 5, Palette.MOSS, 0.32, seed + k, { wobble = 0.2 })
    end
end

local DOODLES = { mountain, mountain, tree, tree, tree, grass }

function ActMapScreen:_doodles(L, seed)
    local sideW = L.area.x - 24 - (L.gutter.x + L.gutter.w)
    if sideW < 30 then return end
    for k = 1, 22 do
        local right = k % 2 == 0
        local x = right and (L.area.x + L.area.w + 34 + hash(seed, k, 71) * (sideW - 30))
            or (L.gutter.x + L.gutter.w + 10 + hash(seed, k, 71) * (sideW - 30))
        local y = L.view.y + hash(seed, k, 72) * L.content - L.scroll
        if y > L.view.y + 12 and y < L.view.y + L.view.h - 4 then
            local fn = DOODLES[1 + math.floor(hash(seed, k, 73) * #DOODLES)]
            local s = (fn == mountain) and (2 + math.floor(hash(seed, k, 74) * 2)) or 1
            fn(math.floor(x), math.floor(y), s, seed + k * 13)
        end
    end
end

function ActMapScreen:_hitNode(L, map, mx, my)
    local best, bd
    local F = #map.floors
    for f = 1, F do
        for i in ipairs(map.floors[f]) do
            local p = L.pts[f][i]
            local hr = ActMapScreen.HIT_R * ((f == F and 1.8) or (map.floors[f][i].type == "mini_boss" and 1.3) or 1)
            local d = (p.x - mx) ^ 2 + (p.y - my) ^ 2
            local visible = f == F or (my >= L.view.y and my <= L.view.y + L.view.h)
            if visible and d <= hr ^ 2 and (not bd or d < bd) then best, bd = { f = f, i = i }, d end
        end
    end
    return best
end

function ActMapScreen:_closeRect(L)
    return L.x + L.w - 46, L.y + 14, 30, 30
end

function ActMapScreen:_journalRect(L)
    local label = I18n.t("act_map.journal_button", nil, "Roteiro [L]")
    local w = font("text", 20):getWidth(label) + 24
    return L.x + 20, L.y + 14, w, 30, label
end

local function nodeState(map, run, f, i, reach, floorNow, start, path)
    local st = {}
    st.next = f == floorNow and start[i]
    st.pending = st.next and run.pendingNodes ~= nil
    st.cur = path[f] == i and run.currentNode and run.currentNode.mapFloor == f
    st.visited = path[f] == i
    st.past = f < floorNow and not st.visited
    st.live = reach[f] and reach[f][i]
    return st
end

local function tag(lbl, x, y, size, fg, bg, border, side)
    local f = font("text", size)
    local w, h = f:getWidth(lbl) + 14, f:getHeight() + 2
    local bx = side == "left" and math.floor(x - w) or math.floor(x)
    local by = math.floor(y - h / 2)
    setAlpha(bg, 0.96)
    love.graphics.rectangle("fill", bx, by, w, h)
    if border then
        setAlpha(border, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx + 1, by + 1, w - 2, h - 2)
        love.graphics.setLineWidth(1)
    end
    setAlpha(fg, 1)
    text(lbl, bx + 7, by + 1, "text", size)
    return bx, by, w, h
end

function ActMapScreen:hoverDemo()
    local map, run = self:map()
    if not map or not run then return end
    local reach, floorNow, start = ActMapScreen.reach(map, run)
    local lane
    for i in pairs(start) do if not lane or i < lane then lane = i end end
    if lane then self._forceHover = { f = floorNow, i = lane } end
end

function ActMapScreen:_scrollBy(d)
    local L = self._L
    local maxS = L and L.maxScroll or 0
    self._scrollTo = math.max(0, math.min(maxS, (self._scrollTo or 0) + d))
end

function ActMapScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(Ink.BACKDROP[1], Ink.BACKDROP[2], Ink.BACKDROP[3], 0.82)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local map, run = self:map()
    if not map then
        setAlpha(Palette.PARCHMENT_LIGHT, 1)
        text(I18n.t("act_map.none", nil, "Sem mapa nesta parte da jornada"), 0, sh / 2 - 14, "text", 26,
            { maxW = sw, align = "center" })
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local seed = (tonumber(run.runSeed) or 0) % 100000 + map.act * 977 + (map.baseFloor or 1) * 31
    local reach, floorNow, start = ActMapScreen.reach(map, run)
    local path = pathSet(map, run)
    local F = #map.floors

    local L0 = ActMapScreen.layout(map, sw, sh, seed, 0)
    if self._snap then
        self._scrollTo = ActMapScreen.focusScroll(L0, floorNow, F)
        self._scroll = self._scrollTo
        self._snap = false
    end
    self._scrollTo = math.max(0, math.min(L0.maxScroll, self._scrollTo or 0))
    local dt = math.min(0.05, love.timer.getDelta() or 0)
    self._scroll = (self._scroll or 0) + (self._scrollTo - (self._scroll or 0))
        * (1 - math.exp(-ActMapScreen.SCROLL_EASE * dt))
    if math.abs(self._scroll - self._scrollTo) < 0.5 then self._scroll = self._scrollTo end
    local L = ActMapScreen.layout(map, sw, sh, seed, self._scroll)
    self._L = L

    local sheet = Parchment.sheet(L.w, L.h, seed)
    if sheet then
        Parchment.drawSheet(sheet, L.x, L.y)
    else
        Ink.drawSheet(Ink.paper(L.w, L.h, seed), L.x, L.y)
    end
    local layered = sheet ~= nil and Parchment.beginInk()

    local mx, my = love.mouse.getPosition()
    local hov = self._forceHover or self:_hitNode(L, map, mx, my)
    if hov and (not self._hover or self._hover.f ~= hov.f or self._hover.i ~= hov.i) then
        sfx("mapHover")
    end
    self._hover = hov
    local t = love.timer.getTime()
    local V = L.view
    local R = ActMapScreen.NODE_R
    local onStart = run.pendingNodes ~= nil and floorNow == 1 and not path[1]
    local anchors = { choices = {}, nodes = {} }
    local pulse = 0.5 + 0.5 * math.sin(t * 4.2)

    Ink.begin()
    thick(L.x + 14, L.y + ActMapScreen.HEAD_H, L.x + L.w - 14, L.y + ActMapScreen.HEAD_H, INK, 0.55, seed + 4, 2)
    Ink.line(L.boss.x + 8, L.boss.y + L.boss.h, L.boss.x + L.boss.w - 8, L.boss.y + L.boss.h, INK, 0.35,
        seed + 5, { dash = 4, gap = 3 })
    Ink.flush()

    love.graphics.setScissor(V.x, V.y, V.w, V.h)
    if floorNow < F and L.rowY[floorNow] then
        local by = L.rowY[floorNow]
        setAlpha(GOLD, 0.1 + 0.05 * pulse)
        love.graphics.rectangle("fill", V.x, by - L.rowH * 0.42, V.w, L.rowH * 0.84)
    end

    Ink.begin()
    self:_doodles(L, seed)
    for i, b in ipairs(L.pts[1]) do
        local x1, y1, x2, y2 = trimmed(L.start, b, 10, R + 3)
        local s = seed + 7 * i
        if path[1] == i then
            thick(x1, y1, x2, y2, RED, 0.95, s, 4)
        elseif onStart and start[i] then
            thick(x1, y1, x2, y2, INK, 0.95, s, 3)
            arrow(x1, y1, x2, y2, INK, 0.95, s + 5, 0.6)
        else
            thick(x1, y1, x2, y2, INK, 0.16, s, 1, { dash = 2, gap = 4 })
        end
    end
    for f = 1, F - 2 do
        for i, n in ipairs(map.floors[f]) do
            local a = L.pts[f][i]
            for _, j in ipairs(n.mapNext or {}) do
                local b = L.pts[f + 1][j]
                if a and b then
                    local rb = (map.floors[f + 1][j].type == "mini_boss") and R + 9 or R + 3
                    local x1, y1, x2, y2 = trimmed(a, b, R + 3, rb)
                    local walked = path[f] == i and path[f + 1] == j
                    local live = reach[f] and reach[f][i] and reach[f + 1] and reach[f + 1][j]
                    local entering = f + 1 == floorNow and path[f] == i and start[j]
                    local s = seed + f * 97 + i * 13 + j
                    if walked then
                        thick(x1, y1, x2, y2, RED, 0.95, s, 4)
                    elseif entering then
                        thick(x1, y1, x2, y2, INK, 0.95, s, 3)
                        arrow(x1, y1, x2, y2, INK, 0.95, s + 5, 0.6)
                    elseif live then
                        thick(x1, y1, x2, y2, INK, 0.72, s, 2)
                    else
                        thick(x1, y1, x2, y2, INK, 0.16, s, 1, { dash = 2, gap = 4 })
                    end
                end
            end
        end
    end
    Ink.flush()

    for f = 1, F - 1 do
        for i, n in ipairs(map.floors[f]) do
            local p = L.pts[f][i]
            if ActMapScreen.inView(L, p, 40) then
                local st = nodeState(map, run, f, i, reach, floorNow, start, path)
                local r = (n.type == "mini_boss") and R + 7 or R
                if st.next then
                    setAlpha(GOLD, 0.22 + 0.18 * pulse)
                    love.graphics.circle("fill", p.x, p.y, r + 9 + pulse * 3, 32)
                end
                setAlpha(Ink.PAPER_LIGHT, (st.live or st.visited) and 1 or 0.75)
                love.graphics.circle("fill", p.x, p.y, r, 28)
            end
        end
    end
    local sx, sy = L.start.x, L.start.y
    setAlpha(Ink.PAPER_LIGHT, 1)
    love.graphics.circle("fill", sx, sy, 11, 20)

    Ink.begin()
    thick(sx - 7, sy - 7, sx + 7, sy + 7, RED, 1, seed + 41, 3, { wobble = 0.2 })
    thick(sx - 7, sy + 7, sx + 7, sy - 7, RED, 1, seed + 42, 3, { wobble = 0.2 })
    for f = 1, F - 1 do
        for i, n in ipairs(map.floors[f]) do
            local p = L.pts[f][i]
            if ActMapScreen.inView(L, p, 40) then
                local s = seed + f * 31 + i * 7
                local st = nodeState(map, run, f, i, reach, floorNow, start, path)
                local big = n.type == "mini_boss"
                local r = big and R + 7 or R
                local lit = st.live or st.visited
                local alpha = lit and 1 or (st.past and FADED * 0.8 or FADED)
                local color = colorOf(n.type)
                Ink.mapGlyph(n.type, p.x, p.y, big and 3 or 2, color, alpha)
                if lit then Ink.ring(p.x, p.y, r, color, 0.85, s + 1, 2) end
                if st.visited and not st.cur then Ink.ring(p.x, p.y, r + 4, RED, 0.9, s + 2, 2) end
                if st.cur then
                    Ink.ring(p.x, p.y, r + 4, RED, 1, s + 2, 2)
                    Ink.ring(p.x, p.y, r + 8, RED, 0.75, s + 3, 2)
                end
                if st.next then
                    local pr = r + 5 + pulse * 2
                    Ink.ring(p.x, p.y, pr, GOLD, 1, s + 3, 2)
                    Ink.ring(p.x, p.y, pr + 3, GOLD_DARK, 0.8, s + 5, 2)
                    anchors.choices[#anchors.choices + 1] = { x = p.x - pr - 6, y = p.y - pr - 6,
                        w = (pr + 6) * 2, h = (pr + 6) * 2 }
                end
                if hov and hov.f == f and hov.i == i then Ink.ring(p.x, p.y, r + 12, INK, 0.7, s + 4, 2) end
                if big then anchors.mini = { x = p.x - r - 4, y = p.y - r - 4, w = r * 2 + 8, h = r * 2 + 8 } end
            end
        end
    end
    Ink.flush()

    for f = 1, F - 1 do
        for i, n in ipairs(map.floors[f]) do
            local p = L.pts[f][i]
            if ActMapScreen.inView(L, p, 10) then
                local st = nodeState(map, run, f, i, reach, floorNow, start, path)
                local r = (n.type == "mini_boss") and R + 7 or R
                if st.next then
                    tag(MapManager.labelFor(n.type), p.x + r + 12, p.y, 18, INK, Ink.PAPER_LIGHT, GOLD_DARK)
                elseif n.type == "mini_boss" then
                    tag(MapManager.labelFor(n.type), p.x + r + 12, p.y, 18, RED, Ink.PAPER_LIGHT,
                        st.live and RED or nil)
                end
            end
        end
    end

    local here
    if run.currentNode and path[run.currentNode.mapFloor or -1] and run.currentNode.mapFloor < F then
        here = L.pts[run.currentNode.mapFloor][path[run.currentNode.mapFloor]]
    elseif onStart or (floorNow == 1 and not path[1]) then
        here = L.start
    end
    if here and ActMapScreen.inView(L, here, 0) then
        local lbl = I18n.t("act_map.you_are_here", nil, "Você está aqui")
        local bx, by, bw, bh = tag(lbl, here.x - R - 14, here.y, 19, Ink.PAPER_LIGHT, RED, nil, "left")
        anchors.here = { x = bx, y = math.min(by, here.y - R - 8), w = here.x + R + 8 - bx,
            h = math.max(bh, R * 2 + 16) }
    end
    if not path[1] then
        setAlpha(INK, 0.7)
        text(I18n.t("act_map.start", nil, "Início"), sx + 16, sy - 11, "text", 18)
    end

    local gx, gw = L.gutter.x, L.gutter.w
    for f = 1, F - 1 do
        local y = L.rowY[f]
        if y > V.y - 20 and y < V.y + V.h + 20 then
            local isNow = f == floorNow
            setAlpha(isNow and RED or INK, isNow and 1 or (f < floorNow and 0.3 or 0.55))
            text(tostring(f), gx + 6, y - (isNow and 17 or 13), "title", isNow and 32 or 24,
                { maxW = gw - 26, align = "right" })
            if isNow then
                local tx = gx + gw - 14
                love.graphics.polygon("fill", tx, y - 8, tx + 11, y, tx, y + 8)
            end
        end
    end
    love.graphics.setScissor()

    local bandTop, bandBot = 22, 22
    if layered then
        Parchment.fade(V.x, V.y, V.w, bandTop, true)
        Parchment.fade(V.x, V.y + V.h - bandBot, V.w, bandBot, false)
    else
        for k = 0, bandTop - 1 do
            setAlpha(Ink.PAPER, 0.9 * (1 - k / bandTop))
            love.graphics.rectangle("fill", V.x, V.y + k, V.w, 1)
        end
        for k = 0, bandBot - 1 do
            setAlpha(Ink.PAPER, 0.9 * (1 - k / bandBot))
            love.graphics.rectangle("fill", V.x, V.y + V.h - 1 - k, V.w, 1)
        end
    end
    if L.maxScroll > 0 then
        local tx, th = V.x + V.w - 6, V.h - 24
        local frac = L.scroll / L.maxScroll
        local hh = math.max(30, th * V.h / L.content)
        setAlpha(INK, 0.18)
        love.graphics.rectangle("fill", tx, V.y + 12, 3, th)
        setAlpha(INK, 0.6)
        love.graphics.rectangle("fill", tx - 1, V.y + 12 + (th - hh) * (1 - frac), 5, hh)
    end

    local boss = map.floors[F][1]
    local bp = L.pts[F][1]
    local mini = L.pts[F - 1] and L.pts[F - 1][1]
    local bossNext = floorNow == F and start[1]
    local cw, ch = Ink.castleSize()
    local bossName = boss and boss.enemyId and I18n.t("end_screen.enemy." .. boss.enemyId, nil, boss.enemyId)
    if bossNext then
        setAlpha(GOLD, 0.12 + 0.06 * pulse)
        love.graphics.rectangle("fill", L.boss.x, L.boss.y + 2, L.boss.w, L.boss.h - 4)
    end
    Ink.begin()
    if mini then
        local y1 = math.max(V.y + 4, math.min(V.y + V.h - 4, mini.y - R - 9))
        local y2 = bp.y + math.floor(ch * 1.5) + 2
        local walked = path[F - 1] and path[F] == 1
        local live = reach[F] and reach[F][1]
        if walked then
            thick(mini.x, y1, bp.x, y2, RED, 0.95, seed + 51, 4)
        elseif bossNext then
            thick(mini.x, y1, bp.x, y2, INK, 0.95, seed + 51, 3)
            arrow(mini.x, y1, bp.x, y2, INK, 0.95, seed + 52, 0.7)
        else
            thick(mini.x, y1, bp.x, y2, INK, live and 0.72 or 0.35, seed + 51, 2, live and nil or { dash = 3, gap = 4 })
        end
    end
    Ink.castleHand(bp.x - math.floor(cw * 3 / 2), bp.y - math.floor(ch * 3 / 2), 3, RED, 1, seed + 61)
    if bossNext then
        Ink.ring(bp.x, bp.y, 40 + pulse * 2, GOLD, 1, seed + 62, 2)
        anchors.choices[#anchors.choices + 1] = { x = bp.x - 46, y = bp.y - 46, w = 92, h = 92 }
    end
    if hov and hov.f == F then Ink.ring(bp.x, bp.y, 46, INK, 0.7, seed + 63, 2) end
    Ink.flush()
    anchors.boss = { x = L.boss.x, y = L.boss.y, w = L.boss.w, h = L.boss.h }
    if bossName then
        local nm = I18n.t("act_map.boss_line", { name = bossName }, bossName)
        setAlpha(RED, 1)
        text(nm, bp.x + cw * 1.5 + 16, bp.y - 15, "title", 28,
            { maxW = L.boss.x + L.boss.w - (bp.x + cw * 1.5 + 16) - 10, minSize = 18 })
    end
    setAlpha(RED, 1)
    text(tostring(F), gx + 6, bp.y - 17, "title", floorNow == F and 32 or 28, { maxW = gw - 26, align = "right" })
    setAlpha(INK, 0.6)
    text(I18n.t("act_map.floor_word", nil, "Andar"), gx, L.boss.y + L.boss.h - 26, "text", 17,
        { maxW = gw - 12, align = "right", minSize = 12 })

    local actName = ActSystem.getActName and ActSystem.getActName(map.act) or ""
    local title = I18n.t("act_map.title", { act = ROMAN[map.act] or map.act }, "Mapa do Ato")
        .. (actName ~= "" and ("  ·  " .. actName) or "")
    setAlpha(INK, 1)
    text(title, L.x + 200, L.y + 2, "title", 32, { maxW = L.w - 400, align = "center", minSize = 22 })
    local sub = I18n.t("act_map.floor_of", { x = math.min(F, floorNow), total = F }, "Andar " .. floorNow)
    setAlpha(RED, 1)
    text(sub, L.x + 200, L.y + 31, "text", 20, { maxW = L.w - 400, align = "center", minSize = 14 })

    local how, lg = self:_legend(L, seed, pulse)

    local cx, cy, cw2, chh = self:_closeRect(L)
    local hotX = mx >= cx and mx <= cx + cw2 and my >= cy and my <= cy + chh
    require("src.ui.NavCursor").target("close", cx, cy, cw2, chh)
    setAlpha(hotX and RED or INK, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(cx + 6, cy + 6, cx + cw2 - 6, cy + chh - 6)
    love.graphics.line(cx + cw2 - 6, cy + 6, cx + 6, cy + chh - 6)
    love.graphics.setLineWidth(1)

    local jx, jy, jw, jh, jl = self:_journalRect(L)
    local hotJ = mx >= jx and mx <= jx + jw and my >= jy and my <= jy + jh
    require("src.ui.NavCursor").target("journal", jx, jy, jw, jh)
    setAlpha(INK, hotJ and 0.95 or 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", jx + 1, jy + 1, jw - 2, jh - 2)
    love.graphics.setLineWidth(1)
    text(jl, jx + 12, jy + 2, "text", 20, { maxW = jw - 16 })

    if layered then Parchment.endInk(sheet, L.x, L.y) end
    self:_anchors(L, anchors, how, lg)
    if hov then self:_tooltip(L, map, run, hov, reach, floorNow, start, path) end
    love.graphics.setColor(1, 1, 1, 1)
end

function ActMapScreen:_legend(L, seed, pulse)
    local P = L.legend
    setAlpha(Ink.PAPER_DARK, 0.35)
    love.graphics.rectangle("fill", P.x, P.y, P.w, P.h)
    Ink.begin()
    thick(P.x, P.y, P.x, P.y + P.h, INK, 0.5, seed + 201, 2, { wobble = 0.4 })
    Ink.flush()

    local x, w = P.x + 16, P.w - 28
    local y = P.y + 8
    setAlpha(INK, 1)
    text(I18n.t("act_map.legend_title", nil, "Legenda"), x, y, "title", 28, { maxW = w })
    y = y + 34
    setAlpha(INK, 0.9)
    y = y + para(I18n.t("act_map.how_1", nil, "Suba de baixo até o castelo do chefe, um andar por vez."), x, y, w, 18)
    local how = { x = P.x + 4, y = P.y + 4, w = P.w - 8, h = y - P.y + 4 }

    y = y + 10
    local rows = {
        { kind = "now",    label = I18n.t("act_map.legend_now", nil, "Pode ir agora") },
        { kind = "done",   label = I18n.t("act_map.legend_done", nil, "Caminho feito") },
        { kind = "closed", label = I18n.t("act_map.legend_closed", nil, "Fora do seu caminho") },
    }
    local iconX = x + 18
    Ink.begin()
    for k, r in ipairs(rows) do
        local cy = y + 15 + (k - 1) * 32
        if r.kind == "now" then
            Ink.ring(iconX, cy, 11 + pulse * 1.5, GOLD, 1, seed + 210, 2)
            Ink.ring(iconX, cy, 14 + pulse * 1.5, GOLD_DARK, 0.8, seed + 211, 2)
        elseif r.kind == "done" then
            thick(iconX - 15, cy + 6, iconX + 15, cy - 6, RED, 0.95, seed + 212, 4, { wobble = 0.3 })
        else
            Ink.mapGlyph("battle", iconX, cy, 1, INK, FADED + 0.08)
            thick(iconX - 16, cy + 9, iconX + 16, cy + 9, INK, 0.25, seed + 213, 1, { dash = 2, gap = 4 })
        end
    end
    Ink.flush()
    for k, r in ipairs(rows) do
        local cy = y + 15 + (k - 1) * 32
        setAlpha(r.kind == "now" and GOLD_DARK or (r.kind == "done" and RED or INK), r.kind == "closed" and 0.65 or 1)
        text(r.label, x + 46, cy - 12, "text", 19, { maxW = w - 46, minSize = 13 })
    end
    y = y + #rows * 32 + 6
    how.h = y - how.y

    Ink.begin()
    Ink.line(x, y, x + w, y, INK, 0.35, seed + 220, { dash = 4, gap = 3 })
    Ink.flush()
    y = y + 8
    local lg = { x = P.x + 4, y = y - 4, w = P.w - 8 }
    local rowH = math.max(28, math.min(38, math.floor((P.y + P.h - y - 6) / #ActMapScreen.LEGEND)))
    for k, ty in ipairs(ActMapScreen.LEGEND) do
        local cy = y + math.floor(rowH / 2) + (k - 1) * rowH
        setAlpha(Ink.PAPER_LIGHT, 1)
        love.graphics.circle("fill", iconX, cy, 16, 24)
    end
    Ink.begin()
    for k, ty in ipairs(ActMapScreen.LEGEND) do
        local cy = y + math.floor(rowH / 2) + (k - 1) * rowH
        if ty == "boss" then
            local cw, ch = Ink.castleSize()
            Ink.castleHand(iconX - cw, cy - ch, 2, RED, 1, seed + 230)
        else
            Ink.mapGlyph(ty, iconX, cy, 2, colorOf(ty), 1)
        end
    end
    Ink.flush()
    for k, ty in ipairs(ActMapScreen.LEGEND) do
        local cy = y + math.floor(rowH / 2) + (k - 1) * rowH
        local label = ty == "boss" and I18n.t("act_map.legend_boss", nil, "Chefe") or MapManager.labelFor(ty)
        setAlpha(colorOf(ty), 1)
        text(label, x + 46, cy - 12, "text", 20, { maxW = w - 46, minSize = 13 })
    end
    lg.h = #ActMapScreen.LEGEND * rowH + 8
    return how, lg
end

function ActMapScreen:_anchors(L, anchors, how, lg)
    local ok, Tutorial = pcall(require, "src.systems.Tutorial")
    if not ok then return end
    self._anchorRects = anchors
    Tutorial.anchor("map_sheet", L.x, L.y, L.w, L.h)
    Tutorial.anchor("map_nodes", L.view.x, L.view.y, L.view.w, L.view.h)
    Tutorial.anchor("map_how", how.x, how.y, how.w, how.h)
    Tutorial.anchor("map_legend", lg.x, lg.y, lg.w, lg.h)
    if anchors.here then
        local a = anchors.here
        Tutorial.anchor("map_here", a.x, a.y, a.w, a.h)
    end
    if #anchors.choices > 0 then Tutorial.anchorList("map_choices", anchors.choices) end
    if anchors.boss then
        local b = anchors.boss
        Tutorial.anchor("map_boss", b.x, b.y, b.w, b.h)
    end
end

function ActMapScreen:_tooltip(L, map, run, hov, reach, floorNow, start, path)
    local n = map.floors[hov.f][hov.i]
    local p = L.pts[hov.f][hov.i]
    local lines = { MapManager.labelFor(n.type), MapManager.descFor(n.type) }
    if n.type == "boss" and n.enemyId then
        lines[1] = lines[1] .. ": " .. I18n.t("end_screen.enemy." .. n.enemyId, nil, n.enemyId)
    end
    local nk = #(n.mapNext or {})
    if hov.f < #map.floors - 2 and nk > 0 then
        lines[#lines + 1] = I18n.t(nk == 1 and "act_map.exits_one" or "act_map.exits_many", { n = nk },
            nk == 1 and "Daqui sai 1 trilha" or ("Daqui saem " .. nk .. " trilhas"))
    end
    local state
    if path[hov.f] == hov.i and hov.f < floorNow then
        state = I18n.t("act_map.state_done", nil, "Já percorrido")
    elseif hov.f == floorNow and start[hov.i] and run.pendingNodes then
        state = I18n.t("act_map.state_choice", nil, "Escolha disponível agora")
    elseif reach[hov.f] and reach[hov.f][hov.i] then
        state = I18n.t("act_map.state_reach", nil, "Alcançável por este caminho")
    else
        state = I18n.t("act_map.state_closed", nil, "Fora do seu caminho")
    end
    lines[#lines + 1] = state
    local f1, f2 = font("title", 26), font("text", 19)
    local w = 60
    for k, s in ipairs(lines) do w = math.max(w, (k == 1 and f1 or f2):getWidth(s) + 24) end
    w = math.min(w, 360)
    local h = 32 + (#lines - 1) * 23 + 12
    local x = p.x + 36
    if x + w > L.legend.x - 6 then x = p.x - 36 - w end
    x = math.max(L.x + 8, x)
    local y = math.max(L.y + 8, math.min(p.y - h / 2, L.y + L.h - h - 8))
    setAlpha(Ink.PAPER_LIGHT, 0.98)
    love.graphics.rectangle("fill", x, y, w, h)
    setAlpha(INK, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)
    love.graphics.setLineWidth(1)
    for k, s in ipairs(lines) do
        if k == 1 then
            setAlpha(colorOf(n.type), 1)
            text(s, x + 12, y + 4, "title", 26, { maxW = w - 24, minSize = 16 })
        else
            setAlpha(k == #lines and RED or INK, 1)
            text(s, x + 12, y + 32 + (k - 2) * 23, "text", 19, { maxW = w - 24, minSize = 12 })
        end
    end
end

function ActMapScreen:_chooseFromMap(map, run, hov)
    local n = map.floors[hov.f] and map.floors[hov.f][hov.i]
    if not n or not run.pendingNodes then return false end
    local WorldRoad = require("src.ui.WorldRoad")
    if not WorldRoad.forkChoose then return false end
    local fork = WorldRoad._fork
    if not fork or fork.converge then return false end
    for idx, pn in ipairs(fork.nodes or {}) do
        if pn.mapFloor == hov.f and pn.mapLane == hov.i and idx <= (fork.n or 3) then
            self:hide()
            return WorldRoad.forkChoose(idx)
        end
    end
    return false
end

local SCROLL_KEYS = { up = -1, w = -1, down = 1, s = 1 }

function ActMapScreen:keypressed(key)
    if not self.visible then return false end
    local V = self._L and self._L.view
    if key == "escape" or key == "m" then
        self:hide()
    elseif key == "l" then
        self:hide()
        if _G.toggleRunJournal then _G.toggleRunJournal() end
    elseif SCROLL_KEYS[key] then
        self:_scrollBy(SCROLL_KEYS[key] * ActMapScreen.SCROLL_STEP)
    elseif key == "pageup" or key == "pagedown" then
        self:_scrollBy((key == "pageup" and -1 or 1) * (V and V.h * 0.8 or 300))
    elseif key == "home" then
        self._scrollTo = 0
    elseif key == "end" then
        self:_scrollBy(1e6)
    end
    return true
end

function ActMapScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    return true
end

function ActMapScreen:wheelmoved(dx, dy)
    if not self.visible then return false end
    self._forceHover = nil
    self:_scrollBy(-(dy or 0) * ActMapScreen.SCROLL_STEP)
    return true
end

function ActMapScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if love.timer.getTime() - (self._openedAt or 0) < 0.2 then return true end
    if button ~= 1 then return true end
    local L = self._L
    local map, run = self:map()
    if not L or not map then self:hide() return true end
    local cx, cy, cw, ch = self:_closeRect(L)
    if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then self:hide() return true end
    local jx, jy, jw, jh = self:_journalRect(L)
    if x >= jx and x <= jx + jw and y >= jy and y <= jy + jh then
        self:hide()
        if _G.toggleRunJournal then _G.toggleRunJournal() end
        return true
    end
    if x < L.x or x > L.x + L.w or y < L.y or y > L.y + L.h then self:hide() return true end
    local hov = self:_hitNode(L, map, x, y)
    if hov then self:_chooseFromMap(map, run, hov) end
    return true
end

return ActMapScreen
