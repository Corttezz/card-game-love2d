local Palette     = require("src.ui.Palette")
local TextFit     = require("src.ui.TextFit")
local Ink         = require("src.ui.RunJournalInk")
local I18n        = require("src.i18n.I18n")

local ActMapPanel = {}

ActMapPanel.W = 132
ActMapPanel.ROW_H = 38
ActMapPanel.PAD = 10
ActMapPanel.HEAD_H = 34

local INK = Ink.INK
local RED = Ink.RED
local GOLD = Palette.AGED_GOLD

local function run(game)
    local rm = game and game.runManager
    return rm and rm.currentRun or nil
end

function ActMapPanel.layout(map, screenW, screenH)
    local floors = map and map.floors
    if not floors or #floors == 0 then return nil end
    local P = ActMapPanel
    local h = P.HEAD_H + P.PAD * 2 + (#floors - 1) * P.ROW_H
    local maxH = screenH - 140
    local rowH = P.ROW_H
    if h > maxH then
        rowH = math.max(22, math.floor((maxH - P.HEAD_H - P.PAD * 2) / math.max(1, #floors - 1)))
        h = P.HEAD_H + P.PAD * 2 + (#floors - 1) * rowH
    end
    local x = 16
    local y = math.floor((screenH - h) / 2) + 20
    local L = { x = x, y = y, w = P.W, h = h, rowH = rowH, pts = {} }
    local laneW = (P.W - P.PAD * 2) / 3
    for f, row in ipairs(floors) do
        L.pts[f] = {}
        local cy = y + h - P.PAD - (f - 1) * rowH
        for i, n in ipairs(row) do
            local lane = (#row == 1) and 2 or (n.mapLane or i)
            L.pts[f][i] = { x = math.floor(x + P.PAD + laneW * (lane - 0.5)), y = math.floor(cy) }
        end
    end
    return L
end

local function reachable(map, cur)
    local out = {}
    if not cur or not cur.mapFloor then return out end
    out[cur.mapFloor] = { [cur.mapLane or 1] = true }
    for f = cur.mapFloor, #map.floors - 1 do
        local nxt = {}
        for lane in pairs(out[f] or {}) do
            local n = map.floors[f][lane]
            for _, j in ipairs((n and n.mapNext) or {}) do nxt[j] = true end
        end
        out[f + 1] = nxt
    end
    return out
end

function ActMapPanel.draw(game, screenW, screenH)
    local r = run(game)
    local map = r and r.actMap
    if not map or map.act ~= r.actNumber then return false end
    screenW = screenW or love.graphics.getWidth()
    screenH = screenH or love.graphics.getHeight()
    local L = ActMapPanel.layout(map, screenW, screenH)
    if not L then return false end
    local floorNow = r.floorInAct or 1
    local cur = r.currentNode
    if cur and cur.mapFloor ~= floorNow - 1 then cur = nil end
    local reach = reachable(map, cur)
    local pending = {}
    for _, n in ipairs(r.pendingNodes or {}) do
        if n.mapFloor == floorNow then pending[n.mapLane or 0] = true end
    end

    love.graphics.setColor(Ink.BACKDROP[1], Ink.BACKDROP[2], Ink.BACKDROP[3], 0.55)
    love.graphics.rectangle("fill", L.x + 3, L.y + 4, L.w, L.h, 6, 6)
    love.graphics.setColor(Ink.PAPER[1], Ink.PAPER[2], Ink.PAPER[3], 0.94)
    love.graphics.rectangle("fill", L.x, L.y, L.w, L.h, 6, 6)
    love.graphics.setColor(Ink.PAPER_RIM[1], Ink.PAPER_RIM[2], Ink.PAPER_RIM[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", L.x, L.y, L.w, L.h, 6, 6)
    love.graphics.setLineWidth(1)

    local seed = (map.baseFloor or 1) * 131 + (map.act or 1)
    Ink.begin()
    for f = 1, #map.floors - 1 do
        for i, n in ipairs(map.floors[f]) do
            local a = L.pts[f][i]
            for _, j in ipairs(n.mapNext or {}) do
                local b = L.pts[f + 1][j]
                if a and b then
                    local live = f >= floorNow - 1 and reach[f] and reach[f][i]
                        and reach[f + 1] and reach[f + 1][j]
                    local past = f < floorNow - 1
                    Ink.line(a.x, a.y - 7, b.x, b.y + 7, INK, live and 0.85 or (past and 0.18 or 0.35),
                        seed + f * 7 + i * 3 + j, { dash = (not live) and 2 or nil, gap = 3 })
                end
            end
        end
    end
    for f, row in ipairs(map.floors) do
        for i, n in ipairs(row) do
            local p = L.pts[f][i]
            local isPending = f == floorNow and pending[n.mapLane or i]
            local isCur = cur and f == cur.mapFloor and (cur.mapLane or 1) == (n.mapLane or i)
            local past = f < floorNow
            local color = (n.type == "boss") and RED or INK
            local alpha = past and 0.3 or 0.9
            if isPending then
                Ink.ring(p.x, p.y, 9, GOLD, 1, seed + f * 17 + i, 2)
                alpha = 1
            end
            if isCur then Ink.ring(p.x, p.y, 9, RED, 0.9, seed + f * 19 + i, 2) end
            local glyph = Ink.hasGlyph(n.type) and n.type or "unknown"
            Ink.glyph(glyph, p.x, p.y, (n.type == "boss") and 2 or 1, color, alpha, seed + f * 5 + i, past)
        end
    end
    Ink.flush()

    local boss = map.floors[#map.floors][1]
    local bossName = boss and boss.enemyId
        and I18n.t("end_screen.enemy." .. boss.enemyId, nil, boss.enemyId) or nil
    love.graphics.setColor(INK[1], INK[2], INK[3], 0.95)
    TextFit.print(I18n.t("act_map.title", { act = map.act }, "Mapa do Ato"),
        L.x + ActMapPanel.PAD, L.y + 6,
        { size = 11, maxW = L.w - ActMapPanel.PAD * 2, minSize = 8 })
    if bossName then
        love.graphics.setColor(RED[1], RED[2], RED[3], 1)
        TextFit.print(bossName, L.x + ActMapPanel.PAD, L.y + 19,
            { size = 9, maxW = L.w - ActMapPanel.PAD * 2, minSize = 7 })
    end
    love.graphics.setColor(1, 1, 1, 1)
    ActMapPanel._last = L
    return true
end

return ActMapPanel
