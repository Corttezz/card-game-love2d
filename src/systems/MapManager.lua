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

MapManager.FLOORS_PER_ACT = 8

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

    if floorInAct <= 2 then
        base[1].weight = 70
        base[2].weight = 4
        base[4].weight = 8
    elseif floorInAct >= 5 then
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

MapManager.LANES = 3
MapManager.LINK_CHANCE = 0.45

local function sortedLanes(set)
    local out = {}
    for lane in pairs(set) do out[#out + 1] = lane end
    table.sort(out)
    return out
end

function MapManager.buildActMap(actNumber, opts)
    local F = MapManager.FLOORS_PER_ACT
    local floors = {}
    for f = 1, F do
        local row = MapManager.generate(f, actNumber, MapManager.LANES, opts)
        for i, n in ipairs(row) do
            n.mapFloor, n.mapLane = f, i
        end
        floors[f] = row
    end
    local crossed = false
    for f = 1, F - 1 do
        local cur, nxt = floors[f], floors[f + 1]
        local links = {}
        for i = 1, #cur do links[i] = {} end
        if #nxt == 1 or #cur == 1 then
            for i = 1, #cur do
                for j = 1, #nxt do links[i][j] = true end
            end
        else
            for i = 1, #cur do
                links[i][math.min(i, #nxt)] = true
                if Rng.get():random("map") < MapManager.LINK_CHANCE then
                    local side = (Rng.get():random("map") < 0.5) and -1 or 1
                    local j = i + side
                    if j < 1 or j > #nxt then j = i - side end
                    if j >= 1 and j <= #nxt then links[i][j] = true end
                end
            end
            for i = 1, #cur - 1 do
                if links[i][i + 1] and links[i + 1][i] then crossed = true end
            end
        end
        for i, n in ipairs(cur) do n.mapNext = sortedLanes(links[i]) end
    end
    if not crossed then
        for f = 1, F - 1 do
            local cur, nxt = floors[f], floors[f + 1]
            if #cur >= 2 and #nxt >= 2 then
                local i = 1 + math.floor(Rng.get():random("map") * (math.min(#cur, #nxt) - 1))
                local a, b = {}, {}
                for _, j in ipairs(cur[i].mapNext) do a[j] = true end
                for _, j in ipairs(cur[i + 1].mapNext) do b[j] = true end
                a[i + 1], b[i] = true, true
                cur[i].mapNext, cur[i + 1].mapNext = sortedLanes(a), sortedLanes(b)
                break
            end
        end
    end
    floors[F][1].mapNext = {}
    return { act = actNumber, floors = floors }
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
        for _, n in ipairs(row) do out[#out + 1] = MapManager.copyNode(n) end
    end
    return out
end

function MapManager.hasCrossing(map)
    for f = 1, #map.floors - 1 do
        local cur = map.floors[f]
        for i = 1, #cur - 1 do
            local a, b = {}, {}
            for _, j in ipairs(cur[i].mapNext or {}) do a[j] = true end
            for _, j in ipairs(cur[i + 1].mapNext or {}) do b[j] = true end
            for ja in pairs(a) do
                for jb in pairs(b) do
                    if ja > jb then return true end
                end
            end
        end
    end
    return false
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
