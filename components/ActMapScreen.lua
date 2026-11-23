local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local TextFit     = require("src.ui.TextFit")
local Ink         = require("src.ui.RunJournalInk")
local MapManager  = require("src.systems.MapManager")
local ActSystem   = require("src.systems.ActSystem")
local Sfx         = require("src.systems.Sfx")
local I18n        = require("src.i18n.I18n")
local TextCase    = require("src.i18n.TextCase")

local ActMapScreen = {}
ActMapScreen.__index = ActMapScreen

ActMapScreen.SHEET_MAX_W = 760
ActMapScreen.TOP_GAP     = 64
ActMapScreen.MARGIN      = 14
ActMapScreen.HEAD_H      = 58
ActMapScreen.LEGEND_H    = 34
ActMapScreen.PAD_X       = 46
ActMapScreen.NODE_R      = 15
ActMapScreen.HIT_R       = 20
ActMapScreen.LEGEND      = { "battle", "elite", "event", "shop", "rest", "mini_boss", "boss" }

local INK, RED = Ink.INK, Ink.RED
local GOLD = Palette.AGED_GOLD
local hash = Ink.hash

local function setAlpha(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local function runOf(game)
    local rm = game and game.runManager
    return rm and rm.currentRun or nil
end

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
    Sfx.play("menuOpen")
end

function ActMapScreen:hide()
    if not self.visible then return end
    self.visible = false
    self._hover = nil
    Sfx.play("menuClose")
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

function ActMapScreen.colOf(map, f, i, n)
    local row = map.floors[f]
    local cols = map.cols or MapManager.MAP_COLS
    if n.mapCol then return n.mapCol, cols end
    if #row == 1 then return (cols + 1) / 2, cols end
    return (i - 0.5) / #row * cols + 0.5, cols
end

function ActMapScreen.layout(map, sw, sh, seed)
    local S = ActMapScreen
    local w = math.min(sw - S.MARGIN * 2, S.SHEET_MAX_W)
    local h = sh - S.TOP_GAP - S.MARGIN
    local x = math.floor((sw - w) / 2)
    local y = S.TOP_GAP
    local area = { x = x + S.PAD_X, y = y + S.HEAD_H + 26, w = w - S.PAD_X * 2 }
    area.h = h - S.HEAD_H - S.LEGEND_H - 26 - 30
    local F = #map.floors
    local rowH = area.h / math.max(1, F - 1)
    local L = { x = x, y = y, w = w, h = h, area = area, rowH = rowH, pts = {} }
    for f, row in ipairs(map.floors) do
        L.pts[f] = {}
        for i, n in ipairs(row) do
            local col, cols = ActMapScreen.colOf(map, f, i, n)
            local colW = area.w / cols
            local px = area.x + (col - 0.5) * colW
            local py = area.y + area.h - (f - 1) * rowH
            if #row > 1 then
                px = px + (hash(seed, f, i, 1) - 0.5) * colW * 0.55
                py = py + (hash(seed, f, i, 2) - 0.5) * rowH * 0.38
            end
            L.pts[f][i] = { x = math.floor(px), y = math.floor(py) }
        end
    end
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

local function trimmed(a, b, r)
    local dx, dy = b.x - a.x, b.y - a.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < r * 2 + 2 then return a.x, a.y, b.x, b.y end
    local ux, uy = dx / len, dy / len
    return a.x + ux * r, a.y + uy * r, b.x - ux * r, b.y - uy * r
end

local function segDist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) or 0
    local qx, qy = ax + dx * t - px, ay + dy * t - py
    return math.sqrt(qx * qx + qy * qy)
end

local function mountain(x, y, s, seed)
    Ink.line(x - 7 * s, y, x, y - 8 * s, INK, 0.5, seed, { wobble = 0.5 })
    Ink.line(x, y - 8 * s, x + 7 * s, y, INK, 0.5, seed + 1, { wobble = 0.5 })
    Ink.line(x + 1, y - 7 * s, x + 4 * s, y - 2, INK, 0.3, seed + 2, { wobble = 0.3, dash = 1, gap = 1 })
    if hash(seed, 3) < 0.6 then
        Ink.line(x + 3 * s, y, x + 8 * s, y - 5 * s, INK, 0.45, seed + 4, { wobble = 0.4 })
        Ink.line(x + 8 * s, y - 5 * s, x + 12 * s, y, INK, 0.45, seed + 5, { wobble = 0.4 })
    end
end

local function tree(x, y, seed)
    Ink.line(x, y, x, y - 4, INK, 0.5, seed, { wobble = 0.1 })
    Ink.ring(x, y - 7, 3, INK, 0.5, seed + 1, 1)
end

local function grass(x, y, seed)
    for k = 0, 2 do
        Ink.line(x + k * 3, y, x + k * 3 + (k - 1), y - 3, INK, 0.35, seed + k, { wobble = 0.2 })
    end
end

local function waves(x, y, seed)
    for k = 0, 1 do
        local yy = y + k * 4
        for i = 0, 10 do
            Ink.px(x + i, yy + math.floor(math.sin(i * 0.9 + k) * 1.2 + 0.5), INK, 0.35)
        end
    end
end

local DOODLES = { mountain, mountain, tree, tree, tree, grass, waves }

function ActMapScreen:_doodles(L, map, seed)
    local A = L.area
    local placed = 0
    for k = 1, 90 do
        if placed >= 26 then break end
        local x = A.x - 30 + hash(seed, k, 71) * (A.w + 60)
        local y = A.y - 10 + hash(seed, k, 72) * (A.h + 20)
        local ok = true
        for f = 1, #map.floors do
            for i, n in ipairs(map.floors[f]) do
                local p = L.pts[f][i]
                if math.abs(p.x - x) < 30 and math.abs(p.y - y) < 30 then ok = false end
                if ok and f < #map.floors then
                    for _, j in ipairs(n.mapNext or {}) do
                        local q = L.pts[f + 1][j]
                        if q and segDist(x, y, p.x, p.y, q.x, q.y) < 16 then ok = false break end
                    end
                end
                if not ok then break end
            end
            if not ok then break end
        end
        if ok then
            local fn = DOODLES[1 + math.floor(hash(seed, k, 73) * #DOODLES)]
            fn(math.floor(x), math.floor(y), (fn == mountain) and (1 + math.floor(hash(seed, k, 74) * 2)) or 1, seed + k * 13)
            placed = placed + 1
        end
    end
end

function ActMapScreen:_compass(cx, cy, seed)
    local r = 16
    Ink.ring(cx, cy, r - 6, INK, 0.55, seed, 1)
    Ink.line(cx, cy - r, cx, cy + r, INK, 0.7, seed + 1, { wobble = 0.2 })
    Ink.line(cx - r, cy, cx + r, cy, INK, 0.7, seed + 2, { wobble = 0.2 })
    Ink.line(cx - 7, cy - 7, cx + 7, cy + 7, INK, 0.4, seed + 3, { wobble = 0.2 })
    Ink.line(cx - 7, cy + 7, cx + 7, cy - 7, INK, 0.4, seed + 4, { wobble = 0.2 })
    for d = 1, 4 do
        Ink.px(cx - 1, cy - r - 1 + d - 1, RED, 0.9, 3, 1)
    end
end

function ActMapScreen:_hitNode(L, map, mx, my)
    local best, bd
    for f = 1, #map.floors do
        for i in ipairs(map.floors[f]) do
            local p = L.pts[f][i]
            local d = (p.x - mx) ^ 2 + (p.y - my) ^ 2
            if d <= ActMapScreen.HIT_R ^ 2 and (not bd or d < bd) then best, bd = { f = f, i = i }, d end
        end
    end
    return best
end

function ActMapScreen:_closeRect(L)
    return L.x + L.w - 40, L.y + 12, 26, 26
end

function ActMapScreen:_journalRect(L)
    local f = FontManager.getFont(9)
    local label = I18n.t("act_map.journal_button", nil, "Roteiro [L]")
    local w = f:getWidth(label) + 18
    return L.x + 16, L.y + 14, w, 22, label
end

function ActMapScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(Ink.BACKDROP[1], Ink.BACKDROP[2], Ink.BACKDROP[3], 0.78)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local map, run = self:map()
    if not map then
        love.graphics.setColor(Palette.PARCHMENT_LIGHT)
        TextFit.print(I18n.t("act_map.none", nil, "Sem mapa nesta parte da jornada"), 0, sh / 2 - 8,
            { size = 14, maxW = sw, align = "center" })
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
    self._hover = hov
    local t = love.timer.getTime()
    local A = L.area

    Ink.begin()
    Ink.line(L.x + 10, L.y + L.h - ActMapScreen.LEGEND_H - 18, L.x + L.w - 10, L.y + L.h - ActMapScreen.LEGEND_H - 18, INK, 0.5, seed + 3)
    Ink.line(L.x + 10, L.y + ActMapScreen.HEAD_H, L.x + L.w - 10, L.y + ActMapScreen.HEAD_H, INK, 0.5, seed + 4)
    Ink.line(L.x + 12, L.y + ActMapScreen.HEAD_H + 3, L.x + L.w - 12, L.y + ActMapScreen.HEAD_H + 3, INK, 0.25,
        seed + 5, { dash = 3, gap = 2 })
    self:_doodles(L, map, seed)
    self:_compass(L.x + L.w - 40, L.y + L.h - ActMapScreen.LEGEND_H - 56, seed + 9)

    for f = 1, #map.floors - 1 do
        for i, n in ipairs(map.floors[f]) do
            local a = L.pts[f][i]
            for _, j in ipairs(n.mapNext or {}) do
                local b = L.pts[f + 1][j]
                if a and b then
                    local x1, y1, x2, y2 = trimmed(a, b, ActMapScreen.NODE_R)
                    local walked = path[f] == i and path[f + 1] == j
                    local live = reach[f] and reach[f][i] and reach[f + 1] and reach[f + 1][j]
                    local entering = f + 1 == floorNow and path[f] == i and start[j]
                    local s = seed + f * 97 + i * 13 + j
                    if walked then
                        Ink.line(x1, y1, x2, y2, RED, 0.9, s, { weight = 2 })
                    elseif live or entering then
                        Ink.line(x1, y1, x2, y2, INK, 0.85, s, { dash = 3, gap = 2, weight = 2 })
                    elseif f + 1 < floorNow then
                        Ink.line(x1, y1, x2, y2, INK, 0.24, s, { dash = 2, gap = 3 })
                    else
                        Ink.line(x1, y1, x2, y2, INK, 0.5, s, { dash = 2, gap = 3 })
                    end
                end
            end
        end
    end

    local F = #map.floors
    for f, row in ipairs(map.floors) do
        for i, n in ipairs(row) do
            local p = L.pts[f][i]
            local s = seed + f * 31 + i * 7
            local isPending = f == floorNow and start[i] and (run.pendingNodes ~= nil)
            local isCur = path[f] == i and run.currentNode and run.currentNode.mapFloor == f
            local visited = path[f] == i
            local past = f < floorNow and not visited
            local live = reach[f] and reach[f][i]
            local isHover = hov and hov.f == f and hov.i == i
            local color = (n.type == "boss" or n.type == "mini_boss") and RED or INK
            local alpha = past and 0.4 or (live and 1 or 0.72)
            if visited then alpha = 0.9 end
            if n.type == "boss" then
                local cw, ch = Ink.castleSize()
                Ink.castle(p.x - cw, p.y - ch * 2 + 6, 2, RED, alpha, s, past)
            else
                local scale = (n.type == "mini_boss") and 3 or 2
                Ink.glyph(Ink.hasGlyph(n.type) and n.type or "unknown", p.x, p.y, scale, color, alpha, s, past)
            end
            if visited then Ink.ring(p.x, p.y, ActMapScreen.NODE_R, INK, 0.75, s + 1, 1) end
            if isCur then Ink.ring(p.x, p.y, ActMapScreen.NODE_R + 3, RED, 0.95, s + 2, 2) end
            if isPending then
                local r = ActMapScreen.NODE_R + 2 + math.sin(t * 4 + i) * 1.5
                Ink.ring(p.x, p.y, r, GOLD, 1, s + 3, 2)
            end
            if isHover then Ink.ring(p.x, p.y, ActMapScreen.NODE_R + 6, INK, 0.6, s + 4, 1) end
        end
    end

    local lx = L.x + 24
    local ly = L.y + L.h - ActMapScreen.LEGEND_H
    local legend = {}
    local slotW = (L.w - 48) / #ActMapScreen.LEGEND
    for k, ty in ipairs(ActMapScreen.LEGEND) do
        local gx = lx + (k - 1) * slotW + 10
        Ink.glyph(ty, gx, ly + 8, 1, (ty == "boss" or ty == "mini_boss") and RED or INK, 0.9, seed + k)
        legend[k] = { x = gx + 9, w = slotW - 22, label = MapManager.labelFor(ty) }
    end
    Ink.flush()

    local headW = L.w - 140
    setAlpha(INK, 1)
    local actName = ActSystem.getActName and ActSystem.getActName(map.act) or ""
    TextFit.print(I18n.t("act_map.title", { act = map.act }, "Mapa do Ato") .. (actName ~= "" and ("  ·  " .. TextCase.upper(actName)) or ""),
        L.x + 70, L.y + 12, { size = 16, maxW = headW, minSize = 10, align = "center" })
    local boss = map.floors[F][1]
    local bossName = boss and boss.enemyId and I18n.t("end_screen.enemy." .. boss.enemyId, nil, boss.enemyId)
    local sub = I18n.t("act_map.floor_of", { x = run.floorInAct or 1, total = MapManager.FLOORS_PER_ACT },
        "Andar " .. (run.floorInAct or 1))
    if bossName then sub = sub .. "  ·  " .. I18n.t("act_map.boss_line", { name = bossName }, bossName) end
    setAlpha(RED, 1)
    TextFit.print(sub, L.x + 70, L.y + 34, { size = 9, maxW = headW, minSize = 7, align = "center" })

    for _, e in ipairs(legend) do
        setAlpha(INK, 0.95)
        TextFit.print(e.label, e.x, ly + 2, { size = 9, maxW = e.w, minSize = 7 })
    end
    setAlpha(INK, 0.7)
    TextFit.print(I18n.t("act_map.hint", nil, "M ou ESC fecha  ·  clique numa marca dourada para seguir"),
        L.x + 20, ly + 18, { size = 8, maxW = L.w - 40, minSize = 7, align = "center" })

    local cx, cy, cw, chh = self:_closeRect(L)
    local hotX = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + chh
    require("src.ui.NavCursor").target("close", cx, cy, cw, chh)
    setAlpha(hotX and RED or INK, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx + 6, cy + 6, cx + cw - 6, cy + chh - 6)
    love.graphics.line(cx + cw - 6, cy + 6, cx + 6, cy + chh - 6)
    love.graphics.setLineWidth(1)

    local jx, jy, jw, jh, jl = self:_journalRect(L)
    local hotJ = mx >= jx and mx <= jx + jw and my >= jy and my <= jy + jh
    require("src.ui.NavCursor").target("journal", jx, jy, jw, jh)
    setAlpha(INK, hotJ and 0.9 or 0.55)
    love.graphics.rectangle("line", jx + 0.5, jy + 0.5, jw - 1, jh - 1)
    TextFit.print(jl, jx + 9, jy + 5, { size = 9, maxW = jw - 12, minSize = 7 })

    if hov then self:_tooltip(L, map, run, hov, reach, floorNow, start, path) end
    love.graphics.setColor(1, 1, 1, 1)
end

function ActMapScreen:_tooltip(L, map, run, hov, reach, floorNow, start, path)
    local n = map.floors[hov.f][hov.i]
    local p = L.pts[hov.f][hov.i]
    local lines = { MapManager.labelFor(n.type), MapManager.descFor(n.type) }
    if n.type == "boss" and n.enemyId then
        lines[1] = lines[1] .. ": " .. I18n.t("end_screen.enemy." .. n.enemyId, nil, n.enemyId)
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
    local f = FontManager.getFont(9)
    local w = 40
    for _, s in ipairs(lines) do w = math.max(w, f:getWidth(s) + 16) end
    w = math.min(w, 280)
    local h = #lines * 13 + 10
    local x = math.min(L.x + L.w - w - 8, p.x + 20)
    if x < L.x + 8 then x = L.x + 8 end
    local y = math.max(L.y + 8, p.y - h - 14)
    setAlpha(Ink.PAPER_LIGHT, 0.97)
    love.graphics.rectangle("fill", x, y, w, h)
    setAlpha(INK, 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    for k, s in ipairs(lines) do
        setAlpha(k == #lines and RED or INK, 1)
        TextFit.print(s, x + 8, y + 5 + (k - 1) * 13, { size = 9, maxW = w - 16, minSize = 7 })
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
