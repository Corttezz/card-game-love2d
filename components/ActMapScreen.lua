local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local Ink         = require("src.ui.RunJournalInk")
local MapManager  = require("src.systems.MapManager")
local ActSystem   = require("src.systems.ActSystem")
local Sfx         = require("src.systems.Sfx")
local I18n        = require("src.i18n.I18n")

local ActMapScreen = {}
ActMapScreen.__index = ActMapScreen

ActMapScreen.TOP_GAP  = 58
ActMapScreen.MARGIN   = 12
ActMapScreen.HEAD_H   = 70
ActMapScreen.FLOOR_H  = 30
ActMapScreen.FOOT_H   = 122
ActMapScreen.PAD_L    = 96
ActMapScreen.PAD_R    = 74
ActMapScreen.NODE_R   = 17
ActMapScreen.HIT_R    = 26
ActMapScreen.LEGEND   = { "battle", "elite", "event", "shop", "rest", "mini_boss", "boss", "choice" }

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
    sfx("mapOpen", "menuOpen")
end

function ActMapScreen:hide()
    if not self.visible then return end
    self.visible = false
    self._hover = nil
    sfx("mapClose", "menuClose")
end

function ActMapScreen:toggle(game)
    if self.visible then self:hide() else self:show(game) end
end

function ActMapScreen:resize()
    self._hover = nil
    Ink.clearPaperCache()
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

function ActMapScreen.layout(map, sw, sh, seed)
    local S = ActMapScreen
    local x, y = S.MARGIN, S.TOP_GAP
    local w, h = sw - S.MARGIN * 2, sh - S.TOP_GAP - S.MARGIN
    local area = { x = x + S.PAD_L, y = y + S.HEAD_H + S.FLOOR_H + 14, w = w - S.PAD_L - S.PAD_R }
    area.h = h - S.HEAD_H - S.FLOOR_H - 14 - S.FOOT_H - 16
    local F = #map.floors
    local colW = area.w / math.max(1, F - 1)
    local L = { x = x, y = y, w = w, h = h, area = area, colW = colW, pts = {} }
    for f, row in ipairs(map.floors) do
        L.pts[f] = {}
        for i, n in ipairs(row) do
            local r, rows = ActMapScreen.rowOf(map, f, i, n)
            local slot = area.h / rows
            local px = area.x + (f - 1) * colW
            local py = area.y + (r - 0.5) * slot
            if #row > 1 then
                px = px + (hash(seed, f, i, 1) - 0.5) * colW * 0.22
                py = py + (hash(seed, f, i, 2) - 0.5) * slot * 0.45
            end
            L.pts[f][i] = { x = math.floor(px), y = math.floor(py) }
        end
    end
    L.start = { x = area.x - 62, y = math.floor(area.y + area.h / 2) }
    L.foot = { x = x + 24, y = y + h - S.FOOT_H, w = w - 48, h = S.FOOT_H - 12 }
    return L
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

local function segDist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) or 0
    local qx, qy = ax + dx * t - px, ay + dy * t - py
    return math.sqrt(qx * qx + qy * qy)
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
    if len < 30 then return end
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
    thick(x - 7 * s, y, x, y - 8 * s, INK, 0.42, seed, 2, { wobble = 0.5 })
    thick(x, y - 8 * s, x + 7 * s, y, INK, 0.42, seed + 1, 2, { wobble = 0.5 })
    Ink.line(x + 1, y - 7 * s, x + 4 * s, y - 2, INK, 0.3, seed + 2, { wobble = 0.3, dash = 1, gap = 1 })
    if hash(seed, 3) < 0.6 then
        Ink.line(x + 3 * s, y, x + 8 * s, y - 5 * s, INK, 0.4, seed + 4, { wobble = 0.4 })
        Ink.line(x + 8 * s, y - 5 * s, x + 12 * s, y, INK, 0.4, seed + 5, { wobble = 0.4 })
    end
end

local function tree(x, y, s, seed)
    thick(x, y, x, y - 5 * s, INK, 0.45, seed, 2, { wobble = 0.1 })
    Ink.ring(x, y - 9 * s, 4 * s, Palette.MOSS, 0.55, seed + 1, 2)
end

local function grass(x, y, s, seed)
    for k = 0, 2 do
        Ink.line(x + k * 4, y, x + k * 4 + (k - 1) * 2, y - 5, Palette.MOSS, 0.45, seed + k, { wobble = 0.2 })
    end
end

local function waves(x, y, s, seed)
    for k = 0, 1 do
        local yy = y + k * 5
        for i = 0, 16 do
            Ink.px(x + i, yy + math.floor(math.sin(i * 0.7 + k) * 1.5 + 0.5), INK, 0.32, 1, 2)
        end
    end
end

local DOODLES = { mountain, mountain, mountain, tree, tree, tree, grass, waves }

function ActMapScreen:_doodles(L, map, seed)
    local A = L.area
    local placed = 0
    for k = 1, 220 do
        if placed >= 46 then break end
        local x = A.x - 40 + hash(seed, k, 71) * (A.w + 70)
        local y = A.y - 6 + hash(seed, k, 72) * (A.h + 12)
        local ok = math.abs(x - L.start.x) > 40 or math.abs(y - L.start.y) > 40
        for f = 1, #map.floors do
            if not ok then break end
            for i, n in ipairs(map.floors[f]) do
                local p = L.pts[f][i]
                if math.abs(p.x - x) < 38 and math.abs(p.y - y) < 38 then ok = false break end
                local nxt = (f < #map.floors) and (n.mapNext or {}) or {}
                for _, j in ipairs(nxt) do
                    local q = L.pts[f + 1][j]
                    if q and segDist(x, y, p.x, p.y, q.x, q.y) < 20 then ok = false break end
                end
                if not ok then break end
            end
        end
        if ok then
            for _, p in ipairs(map.floors[1] and L.pts[1] or {}) do
                if segDist(x, y, L.start.x, L.start.y, p.x, p.y) < 20 then ok = false end
            end
        end
        if ok then
            local fn = DOODLES[1 + math.floor(hash(seed, k, 73) * #DOODLES)]
            local s = (fn == mountain) and (2 + math.floor(hash(seed, k, 74) * 2)) or 1
            fn(math.floor(x), math.floor(y), s, seed + k * 13)
            placed = placed + 1
        end
    end
end

function ActMapScreen:_compass(cx, cy, seed)
    local r = 20
    Ink.ring(cx, cy, r - 8, INK, 0.6, seed, 2)
    thick(cx - r - 6, cy, cx + r + 10, cy, INK, 0.75, seed + 1, 2, { wobble = 0.2 })
    thick(cx, cy - r, cx, cy + r, INK, 0.55, seed + 2, 2, { wobble = 0.2 })
    arrow(cx - r - 6, cy, cx + r + 12, cy, RED, 0.95, seed + 3, 1, 9)
end

local function medallion(p, r, ty, alpha, fill)
    if fill then
        setAlpha(Ink.PAPER_LIGHT, alpha)
        love.graphics.circle("fill", p.x, p.y, r, 28)
    end
end

function ActMapScreen:_hitNode(L, map, mx, my)
    local best, bd
    for f = 1, #map.floors do
        for i in ipairs(map.floors[f]) do
            local p = L.pts[f][i]
            local hr = ActMapScreen.HIT_R * (f == #map.floors and 1.6 or 1)
            local d = (p.x - mx) ^ 2 + (p.y - my) ^ 2
            if d <= hr ^ 2 and (not bd or d < bd) then best, bd = { f = f, i = i }, d end
        end
    end
    return best
end

function ActMapScreen:_closeRect(L)
    return L.x + L.w - 46, L.y + 16, 30, 30
end

function ActMapScreen:_journalRect(L)
    local label = I18n.t("act_map.journal_button", nil, "Roteiro [L]")
    local w = font("text", 20):getWidth(label) + 24
    return L.x + 20, L.y + 18, w, 30, label
end

local function nodeState(map, run, f, i, reach, floorNow, start, path)
    local st = {}
    st.pending = f == floorNow and start[i] and run.pendingNodes ~= nil
    st.cur = path[f] == i and run.currentNode and run.currentNode.mapFloor == f
    st.visited = path[f] == i
    st.past = f < floorNow and not st.visited
    st.live = reach[f] and reach[f][i]
    return st
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
    local L = ActMapScreen.layout(map, sw, sh, seed)
    self._L = L
    local paper = Ink.paper(L.w, L.h, seed)
    Ink.drawSheet(paper, L.x, L.y)

    local reach, floorNow, start = ActMapScreen.reach(map, run)
    local path = pathSet(map, run)
    local mx, my = love.mouse.getPosition()
    local hov = self:_hitNode(L, map, mx, my)
    if hov and (not self._hover or self._hover.f ~= hov.f or self._hover.i ~= hov.i) then
        sfx("mapHover")
    end
    self._hover = hov
    local t = love.timer.getTime()
    local A = L.area
    local F = #map.floors
    local R = ActMapScreen.NODE_R

    Ink.begin()
    thick(L.x + 14, L.y + ActMapScreen.HEAD_H, L.x + L.w - 14, L.y + ActMapScreen.HEAD_H, INK, 0.55, seed + 4, 2)
    Ink.line(L.x + 16, L.y + ActMapScreen.HEAD_H + 4, L.x + L.w - 16, L.y + ActMapScreen.HEAD_H + 4, INK, 0.3,
        seed + 5, { dash = 4, gap = 3 })
    thick(L.foot.x - 8, L.foot.y - 8, L.foot.x + L.foot.w + 8, L.foot.y - 8, INK, 0.5, seed + 3, 2)
    self:_doodles(L, map, seed)
    self:_compass(L.x + L.w - 120, L.y + 36, seed + 9)

    local onStart = run.pendingNodes ~= nil and floorNow == 1 and not path[1]
    for i, b in ipairs(L.pts[1]) do
        local x1, y1, x2, y2 = trimmed(L.start, b, 10, R + 3)
        local s = seed + 7 * i
        if path[1] == i then
            thick(x1, y1, x2, y2, RED, 0.95, s, 3)
        elseif onStart and start[i] then
            thick(x1, y1, x2, y2, INK, 0.9, s, 3)
            arrow(x1, y1, x2, y2, INK, 0.9, s + 5, 0.62)
        else
            thick(x1, y1, x2, y2, INK, 0.3, s, 2, { dash = 3, gap = 4 })
        end
    end

    for f = 1, F - 1 do
        for i, n in ipairs(map.floors[f]) do
            local a = L.pts[f][i]
            for _, j in ipairs(n.mapNext or {}) do
                local b = L.pts[f + 1][j]
                if a and b then
                    local rb = (f + 1 == F) and 30 or R + 3
                    local x1, y1, x2, y2 = trimmed(a, b, R + 3, rb)
                    local walked = path[f] == i and path[f + 1] == j
                    local live = reach[f] and reach[f][i] and reach[f + 1] and reach[f + 1][j]
                    local entering = f + 1 == floorNow and path[f] == i and start[j]
                    local s = seed + f * 97 + i * 13 + j
                    if walked then
                        thick(x1, y1, x2, y2, RED, 0.95, s, 3)
                    elseif entering then
                        thick(x1, y1, x2, y2, INK, 0.95, s, 3)
                        arrow(x1, y1, x2, y2, INK, 0.95, s + 5, 0.62)
                    elseif live then
                        thick(x1, y1, x2, y2, INK, 0.78, s, 2)
                        arrow(x1, y1, x2, y2, INK, 0.7, s + 5, 0.6, 6)
                    elseif f + 1 < floorNow then
                        thick(x1, y1, x2, y2, INK, 0.2, s, 2, { dash = 2, gap = 4 })
                    else
                        thick(x1, y1, x2, y2, INK, 0.4, s, 2, { dash = 4, gap = 4 })
                    end
                end
            end
        end
    end
    Ink.flush()

    for f, row in ipairs(map.floors) do
        for i, n in ipairs(row) do
            if n.type ~= "boss" then
                local st = nodeState(map, run, f, i, reach, floorNow, start, path)
                local p = L.pts[f][i]
                local r = (n.type == "mini_boss") and R + 6 or R
                medallion(p, r, n.type, st.past and 0.55 or 0.96, true)
            end
        end
    end

    Ink.begin()
    local sx, sy = L.start.x, L.start.y
    thick(sx - 7, sy - 7, sx + 7, sy + 7, RED, 1, seed + 41, 3, { wobble = 0.2 })
    thick(sx - 7, sy + 7, sx + 7, sy - 7, RED, 1, seed + 42, 3, { wobble = 0.2 })

    local anchors = { choices = {}, nodes = {} }
    for f, row in ipairs(map.floors) do
        for i, n in ipairs(row) do
            local p = L.pts[f][i]
            local s = seed + f * 31 + i * 7
            local st = nodeState(map, run, f, i, reach, floorNow, start, path)
            local isHover = hov and hov.f == f and hov.i == i
            local color = colorOf(n.type)
            local alpha = st.past and 0.38 or ((st.live or st.visited) and 1 or 0.62)
            if n.type == "boss" then
                local cw, ch = Ink.castleSize()
                Ink.castle(p.x - math.floor(cw * 3 / 2), p.y - math.floor(ch * 3 / 2), 3, RED, alpha, s, st.past)
                anchors.boss = { x = p.x - cw * 1.5 - 6, y = p.y - ch * 1.5 - 6, w = cw * 3 + 12, h = ch * 3 + 40 }
            else
                local big = n.type == "mini_boss"
                local r = big and R + 6 or R
                Ink.glyph(Ink.hasGlyph(n.type) and n.type or "unknown", p.x, p.y, big and 3 or 2, color, alpha, s,
                    st.past)
                Ink.ring(p.x, p.y, r, st.past and INK or color, st.past and 0.3 or 0.85, s + 1, 2)
                if big then
                    anchors.mini = { x = p.x - r - 4, y = p.y - r - 4, w = r * 2 + 8, h = r * 2 + 34 }
                end
            end
            if st.visited and not st.cur then Ink.ring(p.x, p.y, R + 5, RED, 0.8, s + 2, 1) end
            if st.cur then
                Ink.ring(p.x, p.y, R + 5, RED, 1, s + 2, 2)
                Ink.ring(p.x, p.y, R + 8, RED, 0.7, s + 3, 1)
            end
            if st.pending then
                local pr = R + 6 + math.sin(t * 4 + i) * 1.5
                Ink.ring(p.x, p.y, pr, GOLD, 1, s + 3, 2)
                Ink.ring(p.x, p.y, pr + 3, GOLD, 0.75, s + 5, 2)
                anchors.choices[#anchors.choices + 1] = { x = p.x - pr - 6, y = p.y - pr - 6,
                    w = (pr + 6) * 2, h = (pr + 6) * 2 }
            end
            if isHover then Ink.ring(p.x, p.y, R + 11, INK, 0.65, s + 4, 2) end
        end
    end

    local legend = {}
    local how = { x = L.foot.x, y = L.foot.y, w = math.floor(L.foot.w * 0.5) }
    local lg = { x = how.x + how.w + 30, y = L.foot.y + 6, w = L.foot.w - how.w - 30 }
    local slotW = lg.w / 4
    for k, ty in ipairs(ActMapScreen.LEGEND) do
        local col, rowk = (k - 1) % 4, math.floor((k - 1) / 4)
        local gx = math.floor(lg.x + col * slotW + 16)
        local gy = math.floor(lg.y + 22 + rowk * 46)
        local gp = { x = gx, y = gy }
        if ty == "choice" then
            Ink.ring(gx, gy, 12, GOLD, 1, seed + 300, 2)
            Ink.ring(gx, gy, 15, GOLD, 0.75, seed + 301, 2)
        elseif ty == "boss" then
            local cw, ch = Ink.castleSize()
            Ink.castle(gx - cw, gy - ch, 2, RED, 0.95, seed + k)
        else
            Ink.glyph(ty, gx, gy, 2, colorOf(ty), 0.95, seed + k)
            Ink.ring(gx, gy, 14, colorOf(ty), 0.8, seed + k + 50, 2)
        end
        legend[k] = { x = gx + 26, y = gy - 13, w = slotW - 46, ty = ty, p = gp }
    end
    Ink.flush()

    for _, e in ipairs(legend) do
        setAlpha(e.ty == "choice" and GOLD_DARK or INK, 1)
        local label = e.ty == "choice" and I18n.t("act_map.legend_choice", nil, "Sua escolha agora")
            or MapManager.labelFor(e.ty)
        text(label, e.x, e.y, "text", 21, { maxW = e.w, minSize = 14 })
    end

    setAlpha(INK, 1)
    text(I18n.t("act_map.how_title", nil, "Como ler o mapa"), how.x, how.y - 2, "title", 24, { maxW = how.w })
    local howLines = {
        I18n.t("act_map.how_1", nil, "Siga da esquerda para a direita, um andar por vez."),
        I18n.t("act_map.how_2", nil, "De cada parada saem 2 ou 3 trilhas: escolha uma."),
        I18n.t("act_map.how_3", nil, "Ouro: suas opções agora. Vermelho: o caminho feito."),
    }
    for k, s in ipairs(howLines) do
        setAlpha(k == 3 and RED or INK, 0.95)
        text(s, how.x + 10, how.y + 24 + (k - 1) * 24, "text", 20, { maxW = how.w - 10, minSize = 13 })
    end

    local actName = ActSystem.getActName and ActSystem.getActName(map.act) or ""
    local title = I18n.t("act_map.title", { act = ROMAN[map.act] or map.act }, "Mapa do Ato")
        .. (actName ~= "" and ("  ·  " .. actName) or "")
    setAlpha(INK, 1)
    text(title, L.x + 200, L.y + 6, "title", 36, { maxW = L.w - 400, align = "center", minSize = 24 })
    local boss = map.floors[F][1]
    local bossName = boss and boss.enemyId and I18n.t("end_screen.enemy." .. boss.enemyId, nil, boss.enemyId)
    local sub = I18n.t("act_map.floor_of", { x = math.min(F, run.floorInAct or 1), total = F },
        "Andar " .. (run.floorInAct or 1))
    if bossName then sub = sub .. "   ·   " .. I18n.t("act_map.boss_line", { name = bossName }, bossName) end
    setAlpha(RED, 1)
    text(sub, L.x + 200, L.y + 40, "text", 21, { maxW = L.w - 400, align = "center", minSize = 14 })

    local fy = A.y - ActMapScreen.FLOOR_H - 10
    setAlpha(INK, 0.7)
    text(I18n.t("act_map.floor_word", nil, "Andar"), L.x + 18, fy, "text", 19, { maxW = ActMapScreen.PAD_L - 30 })
    for f = 1, F do
        local px = A.x + (f - 1) * L.colW
        local here = f == floorNow
        setAlpha(here and RED or INK, here and 1 or (f < floorNow and 0.4 or 0.75))
        text(tostring(f), px - 20, fy, "title", here and 28 or 24, { maxW = 40, align = "center" })
    end

    for f, row in ipairs(map.floors) do
        for i, n in ipairs(row) do
            local st = nodeState(map, run, f, i, reach, floorNow, start, path)
            local p = L.pts[f][i]
            if n.type == "mini_boss" or n.type == "boss" then
                setAlpha(RED, st.past and 0.4 or 1)
                local lbl = MapManager.labelFor(n.type)
                if n.type == "boss" and bossName then lbl = bossName end
                local dy = n.type == "boss" and 30 or R + 10
                text(lbl, p.x - 70, p.y + dy, "text", 19, { maxW = 140, align = "center", minSize = 12 })
            elseif st.pending then
                local lbl = MapManager.labelFor(n.type)
                local f2 = font("text", 18)
                local w = f2:getWidth(lbl) + 14
                local bx, by = math.floor(p.x - w / 2), math.floor(p.y - R - 36)
                setAlpha(Ink.PAPER_LIGHT, 0.95)
                love.graphics.rectangle("fill", bx, by, w, 24)
                setAlpha(GOLD_DARK, 1)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", bx + 1, by + 1, w - 2, 22)
                love.graphics.setLineWidth(1)
                setAlpha(INK, 1)
                text(lbl, bx + 7, by + 1, "text", 18)
            end
        end
    end

    local here
    if run.currentNode and path[run.currentNode.mapFloor or -1] then
        here = L.pts[run.currentNode.mapFloor][path[run.currentNode.mapFloor]]
    elseif onStart then
        here = L.start
    end
    if here then
        local lbl = I18n.t("act_map.you_are_here", nil, "Você está aqui")
        local f2 = font("text", 19)
        local w = f2:getWidth(lbl) + 16
        local bx, by = math.floor(here.x - w / 2), math.floor(here.y + R + 14)
        if here == L.start then bx = math.max(L.x + 8, bx) end
        setAlpha(RED, 0.95)
        love.graphics.rectangle("fill", bx, by, w, 26)
        setAlpha(Ink.PAPER_LIGHT, 1)
        text(lbl, bx + 8, by + 1, "text", 19)
        anchors.here = { x = math.min(bx, here.x - R - 8), y = here.y - R - 8,
            w = math.max(w, R * 2 + 16), h = by + 26 - (here.y - R - 8) }
    end

    setAlpha(INK, 0.6)
    text(I18n.t("act_map.hint", nil, "M ou ESC fecha  ·  clique numa marca dourada para seguir"),
        L.x + 20, L.y + L.h - 24, "text", 16, { maxW = L.w - 40, align = "center", minSize = 12 })

    local cx, cy, cw, chh = self:_closeRect(L)
    local hotX = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + chh
    require("src.ui.NavCursor").target("close", cx, cy, cw, chh)
    setAlpha(hotX and RED or INK, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(cx + 6, cy + 6, cx + cw - 6, cy + chh - 6)
    love.graphics.line(cx + cw - 6, cy + 6, cx + 6, cy + chh - 6)
    love.graphics.setLineWidth(1)

    local jx, jy, jw, jh, jl = self:_journalRect(L)
    local hotJ = mx >= jx and mx <= jx + jw and my >= jy and my <= jy + jh
    require("src.ui.NavCursor").target("journal", jx, jy, jw, jh)
    setAlpha(INK, hotJ and 0.95 or 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", jx + 1, jy + 1, jw - 2, jh - 2)
    love.graphics.setLineWidth(1)
    text(jl, jx + 12, jy + 2, "text", 20, { maxW = jw - 16 })

    self:_anchors(L, anchors, how, lg)
    if hov then self:_tooltip(L, map, run, hov, reach, floorNow, start, path) end
    love.graphics.setColor(1, 1, 1, 1)
end

function ActMapScreen:_anchors(L, anchors, how, lg)
    local ok, Tutorial = pcall(require, "src.systems.Tutorial")
    if not ok then return end
    self._anchorRects = anchors
    Tutorial.anchor("map_sheet", L.x, L.y, L.w, L.h)
    Tutorial.anchor("map_nodes", L.area.x - 80, L.area.y - 50, L.area.w + 130, L.area.h + 70)
    Tutorial.anchor("map_how", how.x - 6, how.y - 6, how.w + 6, L.foot.h + 4)
    Tutorial.anchor("map_legend", lg.x - 6, lg.y - 6, lg.w + 6, L.foot.h)
    if anchors.here then
        local a = anchors.here
        Tutorial.anchor("map_here", a.x, a.y, a.w, a.h)
    end
    if #anchors.choices > 0 then Tutorial.anchorList("map_choices", anchors.choices) end
    local bx = anchors.mini or anchors.boss
    if anchors.mini and anchors.boss then
        local a, b = anchors.mini, anchors.boss
        local x1, y1 = math.min(a.x, b.x), math.min(a.y, b.y)
        local x2, y2 = math.max(a.x + a.w, b.x + b.w), math.max(a.y + a.h, b.y + b.h)
        bx = { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
    end
    if bx then Tutorial.anchor("map_boss", bx.x, bx.y, bx.w, bx.h) end
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
    local f1, f2 = font("title", 24), font("text", 19)
    local w = 60
    for k, s in ipairs(lines) do w = math.max(w, (k == 1 and f1 or f2):getWidth(s) + 24) end
    w = math.min(w, 360)
    local h = 30 + (#lines - 1) * 23 + 12
    local x = p.x + 30
    if x + w > L.x + L.w - 8 then x = p.x - 30 - w end
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
            text(s, x + 12, y + 4, "title", 24, { maxW = w - 24, minSize = 16 })
        else
            setAlpha(k == #lines and RED or INK, 1)
            text(s, x + 12, y + 30 + (k - 2) * 23, "text", 19, { maxW = w - 24, minSize = 12 })
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

function ActMapScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" or key == "m" then
        self:hide()
    elseif key == "l" then
        self:hide()
        if _G.toggleRunJournal then _G.toggleRunJournal() end
    end
    return true
end

function ActMapScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    return true
end

function ActMapScreen:wheelmoved() return self.visible end

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
