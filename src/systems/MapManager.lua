local MapManager = {}

local Rng = require("src.systems.Rng")

MapManager.NODE_TYPES = {
    BATTLE    = "battle",
    ELITE     = "elite",
    MINI_BOSS = "mini_boss",
    BOSS      = "boss",
    SHOP      = "shop",
    REST      = "rest",
    EVENT     = "event",
}

MapManager.FLOORS_PER_ACT = 12

MapManager.NODE_META = {
    [MapManager.NODE_TYPES.BATTLE] = {
        label = "Batalha",
        icon = "sword_short",
        sprite = nil,
        desc = "Combate padrao. Recompensa: 1 carta + ouro.",
    },
    [MapManager.NODE_TYPES.ELITE] = {
        label = "Elite",
        icon = "skull",
        sprite = nil,
        desc = "Inimigo forte. Recompensa: carta garantida uncommon+.",
    },
    [MapManager.NODE_TYPES.MINI_BOSS] = {
        label = "Mini-Boss",
        icon = "skull_horned",
        sprite = nil,
        desc = "Meio do ato. Recompensa rara.",
    },
    [MapManager.NODE_TYPES.BOSS] = {
        label = "BOSS",
        icon = "skull_crowned",
        sprite = nil,
        desc = "Fim do ato. Recompensa lendaria + reliquia.",
    },
    [MapManager.NODE_TYPES.SHOP] = {
        label = "Loja",
        icon = "coin",
        sprite = "shop_tent",
        desc = "Compre cartas e upgrades.",
    },
    [MapManager.NODE_TYPES.REST] = {
        label = "Descanso",
        icon = "heart",
        sprite = "campfire",
        desc = "Cure 30% HP ou forje uma carta.",
    },
    [MapManager.NODE_TYPES.EVENT] = {
        label = "Evento",
        icon = "scroll",
        sprite = "altar",
        desc = "Encontro misterioso. Arrisque.",
    },
}

function MapManager.labelFor(nodeType)
    local meta = MapManager.NODE_META[nodeType] or {}
    return require("src.i18n.I18n").t(
        "node_type." .. tostring(nodeType) .. ".label",
        nil, meta.label or tostring(nodeType))
end

function MapManager.descFor(nodeType)
    local meta = MapManager.NODE_META[nodeType] or {}
    return require("src.i18n.I18n").t(
        "node_type." .. tostring(nodeType) .. ".desc",
        nil, meta.desc or "")
end

local function rollWeighted(weights)
    local total = 0
    for _, e in ipairs(weights) do total = total + (e.weight or 1) end
    local r = Rng.get():random("map") * total
    local acc = 0
    for _, e in ipairs(weights) do
        acc = acc + (e.weight or 1)
        if r <= acc then return e.type end
    end
    return weights[#weights].type
end

function MapManager.weightsFor(floorInAct, actNumber)
    if floorInAct == MapManager.FLOORS_PER_ACT then
        return { { type = MapManager.NODE_TYPES.BOSS, weight = 1 } }
    end
    if floorInAct == MapManager.FLOORS_PER_ACT - 1 then
        return { { type = MapManager.NODE_TYPES.MINI_BOSS, weight = 1 } }
    end

    local base = {
        { type = MapManager.NODE_TYPES.BATTLE, weight = 55 },
        { type = MapManager.NODE_TYPES.ELITE,  weight = 10 },
        { type = MapManager.NODE_TYPES.SHOP,   weight = 12 },
        { type = MapManager.NODE_TYPES.REST,   weight = 10 },
        { type = MapManager.NODE_TYPES.EVENT,  weight = 13 },
    }

    if floorInAct <= MapManager.earlyUntil() then
        base[1].weight = 70
        base[2].weight = 4
        base[4].weight = 8
    elseif floorInAct >= MapManager.lateFrom() then
        base[2].weight = 18
        base[3].weight = 14
    end

    return base
end

function MapManager.generate(floorInAct, actNumber, numNodes, opts)
    numNodes = numNodes or 3
    opts = opts or {}
    local weights = MapManager.weightsFor(floorInAct, actNumber)
    if opts.eliteMul and opts.eliteMul ~= 1 then
        for _, w in ipairs(weights) do
            if w.type == MapManager.NODE_TYPES.ELITE then w.weight = w.weight * opts.eliteMul end
        end
    end

    if floorInAct == MapManager.FLOORS_PER_ACT or floorInAct == MapManager.FLOORS_PER_ACT - 1 then
        local t = weights[1].type
        return {
            MapManager._makeNode(t, floorInAct, actNumber),
        }
    end

    local nodes = {}
    local usedTypes = {}
    local attempts = 0
    while #nodes < numNodes and attempts < 20 do
        attempts = attempts + 1
        local t = rollWeighted(weights)
        if not usedTypes[t] then
            usedTypes[t] = true
            table.insert(nodes, MapManager._makeNode(t, floorInAct, actNumber))
        end
    end
    while #nodes < numNodes do
        local rest = {}
        for _, e in ipairs(weights) do
            if not usedTypes[e.type] and (e.weight or 1) > 0 then rest[#rest + 1] = e end
        end
        if #rest == 0 then break end
        local t = rollWeighted(rest)
        usedTypes[t] = true
        table.insert(nodes, MapManager._makeNode(t, floorInAct, actNumber))
    end
    return nodes
end

MapManager.MAP_MIN_W = 2
MapManager.MAP_MAX_W = 4
MapManager.MAP_START_W = 3
MapManager.MAP_COLS = MapManager.MAP_MAX_W * 2 - 1
MapManager.MAP_TRIES = 24

local function rnd() return Rng.get():random("map") end
local function rint(a, b) return a + math.floor(rnd() * (b - a + 1)) end

local function totalActs() return require("src.core.Config").TotalActs or 3 end

function MapManager.endlessStart()
    return totalActs() * MapManager.FLOORS_PER_ACT + 1
end

function MapManager.endlessBiome(run)
    local start = MapManager.endlessStart()
    return totalActs() + 1 + math.floor(math.max(0, (run.currentFloor or start) - start) / MapManager.FLOORS_PER_ACT)
end

function MapManager.earlyUntil(F)
    return math.floor((F or MapManager.FLOORS_PER_ACT) / 4)
end

function MapManager.lateFrom(F)
    return math.ceil((F or MapManager.FLOORS_PER_ACT) * 0.6)
end

function MapManager.legacyFloor(floorInAct, F)
    F = F or MapManager.FLOORS_PER_ACT
    local f = math.max(1, math.min(F, floorInAct or 1))
    if F <= 1 then return 1 end
    return 1 + (f - 1) * 7 / (F - 1)
end

local function rowWidths(rows)
    local w = { MapManager.MAP_START_W }
    for r = 2, rows do
        local prev, roll = w[r - 1], rnd()
        local d
        if prev <= MapManager.MAP_MIN_W then d = roll < 0.7 and 1 or 0
        elseif prev >= MapManager.MAP_MAX_W then d = roll < 0.55 and 0 or -1
        else d = roll < 0.2 and -1 or (roll < 0.6 and 0 or 1) end
        w[r] = math.max(MapManager.MAP_MIN_W, math.min(MapManager.MAP_MAX_W, prev + d))
    end
    return w
end

local function ladder(nA, nB)
    local span, gap = {}, {}
    for i = 1, nA do span[i], gap[i] = 1, 0 end
    local sum, want = nA, nB - 1
    local guard = 0
    while sum > want and guard < 400 do
        guard = guard + 1
        local i = rint(1, nA)
        if span[i] > 0 then span[i] = span[i] - 1; sum = sum - 1 end
    end
    while sum < want and guard < 800 do
        guard = guard + 1
        if nA > 1 and rnd() < 0.25 then
            local i = rint(1, nA - 1)
            if gap[i] == 0 then gap[i] = 1; sum = sum + 1 end
        else
            local i = rint(1, nA)
            if span[i] < 2 then span[i] = span[i] + 1; sum = sum + 1 end
        end
    end
    for _ = 1, nA do
        if rnd() < 0.12 then
            local i, j = rint(1, nA), rint(1, nA)
            if i ~= j and span[i] == 1 and span[j] == 1 then span[i], span[j] = 2, 0 end
        end
    end
    local kids, lo = {}, 1
    for i = 1, nA do
        local hi = lo + span[i]
        kids[i] = {}
        for j = lo, hi do kids[i][#kids[i] + 1] = j end
        lo = hi + (i < nA and gap[i] or 0)
    end
    return kids
end

local function hasMerge(kids, rows)
    for r = 1, rows - 1 do
        local seen = {}
        for _, ks in ipairs(kids[r]) do
            for _, j in ipairs(ks) do
                if seen[j] then return true end
                seen[j] = true
            end
        end
    end
    return false
end

local CALM = { rest = true, shop = true, elite = true, event = true }

local function assignTypes(widths, kids, rows, actNumber, opts)
    local typeAt = {}
    for r = 1, rows do typeAt[r] = {} end
    for r = 1, rows do
        local weights = MapManager.weightsFor(r, actNumber)
        if opts.eliteMul and opts.eliteMul ~= 1 then
            for _, w in ipairs(weights) do
                if w.type == MapManager.NODE_TYPES.ELITE then w.weight = w.weight * opts.eliteMul end
            end
        end
        for c = 1, widths[r] do
            local banned, parentTypes = {}, {}
            if r == 1 then
                for o, t in pairs(typeAt[1]) do if o ~= c then banned[t] = true end end
            else
                for p, ks in ipairs(kids[r - 1]) do
                    local mine = false
                    for _, k in ipairs(ks) do mine = mine or k == c end
                    if mine then
                        parentTypes[typeAt[r - 1][p]] = true
                        for _, k in ipairs(ks) do
                            if k ~= c and typeAt[r][k] then banned[typeAt[r][k]] = true end
                        end
                    end
                end
            end
            local pool = {}
            for _, w in ipairs(weights) do
                local t = w.type
                if not banned[t] and not (CALM[t] and parentTypes[t]) and (w.weight or 1) > 0 then
                    pool[#pool + 1] = w
                end
            end
            if #pool == 0 then
                for _, w in ipairs(weights) do
                    if not banned[w.type] then pool[#pool + 1] = { type = w.type, weight = 1 } end
                end
            end
            typeAt[r][c] = rollWeighted(pool)
        end
    end
    return typeAt
end

function MapManager.buildActMap(actNumber, opts)
    opts = opts or {}
    local F = MapManager.FLOORS_PER_ACT
    local rows = F - 2
    local cols = MapManager.MAP_COLS
    local mid = math.floor((cols + 1) / 2)
    local widths, kids
    for _ = 1, MapManager.MAP_TRIES do
        widths, kids = rowWidths(rows), {}
        for r = 1, rows - 1 do kids[r] = ladder(widths[r], widths[r + 1]) end
        if hasMerge(kids, rows) then break end
    end
    local typeAt = assignTypes(widths, kids, rows, actNumber, opts)

    local floors = {}
    for r = 1, rows do
        floors[r] = {}
        local w = widths[r]
        for i = 1, w do
            local n = MapManager._makeNode(typeAt[r][i], r, actNumber)
            n.mapFloor, n.mapLane = r, i
            n.mapCol = mid + math.floor((i - (w + 1) / 2) * 2 + 0.5)
            n.mapNext = (r < rows) and kids[r][i] or { 1 }
            floors[r][i] = n
        end
    end
    for f = rows + 1, F do
        local n = MapManager.generate(f, actNumber, 1, opts)[1]
        n.mapFloor, n.mapLane, n.mapCol = f, 1, mid
        floors[f] = { n }
    end
    floors[F - 1][1].mapNext = { 1 }
    floors[F][1].mapNext = {}
    return { act = actNumber, floors = floors, cols = cols }
end

function MapManager.copyNode(node)
    local c = {}
    for k, v in pairs(node) do c[k] = v end
    if node.mapNext then
        c.mapNext = {}
        for i, j in ipairs(node.mapNext) do c.mapNext[i] = j end
    end
    return c
end

function MapManager.choicesFrom(map, floorInAct, prev)
    local row = map and map.floors and map.floors[floorInAct]
    if not row then return nil end
    local lanes
    if prev and prev.mapFloor == floorInAct - 1 and type(prev.mapNext) == "table"
        and #prev.mapNext > 0 then
        lanes = prev.mapNext
    end
    local out = {}
    if lanes then
        for _, j in ipairs(lanes) do
            if row[j] then out[#out + 1] = MapManager.copyNode(row[j]) end
        end
    end
    if #out == 0 then
        local c0 = (prev and prev.mapCol) or math.floor(((map.cols or 3) + 1) / 2)
        local idx = {}
        for i = 1, #row do idx[i] = i end
        if #idx > 3 then
            table.sort(idx, function(a, b)
                local da = math.abs((row[a].mapCol or a) - c0)
                local db = math.abs((row[b].mapCol or b) - c0)
                if da ~= db then return da < db end
                return a < b
            end)
            idx = { idx[1], idx[2], idx[3] }
            table.sort(idx)
        end
        for _, i in ipairs(idx) do out[#out + 1] = MapManager.copyNode(row[i]) end
        if MapManager.dedupeNodes then out = MapManager.dedupeNodes(out) end
    end
    return out
end

function MapManager.hasCrossing(map)
    for f = 2, #map.floors do
        local row = map.floors[f]
        if #row > 1 then
            local parents = {}
            for _, p in ipairs(map.floors[f - 1]) do
                for _, j in ipairs(p.mapNext or {}) do parents[j] = (parents[j] or 0) + 1 end
            end
            for _, n in pairs(parents) do
                if n >= 2 then return true end
            end
        end
    end
    return false
end

function MapManager.tangledEdges(map)
    local n = 0
    for f = 1, #map.floors - 1 do
        local row = map.floors[f]
        for i = 1, #row do
            for _, j in ipairs(row[i].mapNext or {}) do
                for k = i + 1, #row do
                    for _, jb in ipairs(row[k].mapNext or {}) do
                        if jb < j then n = n + 1 end
                    end
                end
            end
        end
    end
    return n
end

function MapManager.dedupeNodes(nodes)
    if type(nodes) ~= "table" then return nodes, 0 end
    local seen, out, removed = {}, {}, 0
    for _, n in ipairs(nodes) do
        local t = type(n) == "table" and n.type or nil
        if t and not seen[t] then
            seen[t] = true
            out[#out + 1] = n
        else
            removed = removed + 1
        end
    end
    return out, removed
end

function MapManager._makeNode(nodeType, floorInAct, actNumber)
    local meta = MapManager.NODE_META[nodeType] or {}
    return {
        type = nodeType,
        label = MapManager.labelFor(nodeType),
        icon = meta.icon,
        sprite = meta.sprite,
        desc = MapManager.descFor(nodeType),
        floorInAct = floorInAct,
        actNumber = actNumber,
    }
end

function MapManager.floorToAct(globalFloor)
    local act = math.floor((globalFloor - 1) / MapManager.FLOORS_PER_ACT) + 1
    local inAct = ((globalFloor - 1) % MapManager.FLOORS_PER_ACT) + 1
    return act, inAct
end

return MapManager
