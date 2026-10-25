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
