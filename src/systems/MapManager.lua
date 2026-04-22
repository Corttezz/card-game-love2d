-- src/systems/MapManager.lua
-- Gera escolhas de nos entre batalhas (MVP sem mapa visual global).
-- Cada escolha e uma lista de 2-3 NodeType distintos.
--
-- A probabilidade de cada tipo de no e funcao do floorInAct (posicao dentro
-- do ato). Fase 5 refinara pesos por ato; por ora, floorsPerAct fixo=8.
--
-- Contrato:
--   MapManager.generate(floorInAct, actNumber, numNodes, opts) -> { node1, node2, ... }
--   Cada node = { type, label, icon, rewardHint, payload }

local MapManager = {}

MapManager.NODE_TYPES = {
    BATTLE    = "battle",
    ELITE     = "elite",
    MINI_BOSS = "mini_boss",
    BOSS      = "boss",
    SHOP      = "shop",
    REST      = "rest",
    EVENT     = "event",
}

-- Floors por ato. Fase 5 mudara para tabela por ato em Config.Acts.
MapManager.FLOORS_PER_ACT = 8

-- Metadata humana para cada tipo.
-- `icon`: fallback 64×64 de assets/sprites/icons/ (IconLoader)
-- `sprite`: sprite 96×96 ilustrado de assets/sprites/map_nodes/ (preferencial)
MapManager.NODE_META = {
    [MapManager.NODE_TYPES.BATTLE] = {
        label = "Batalha",
        icon = "sword_short",
        sprite = nil, -- backlog: gerar sprite de "arena" pra battle node
        desc = "Combate padrao. Recompensa: 1 carta + ouro.",
    },
    [MapManager.NODE_TYPES.ELITE] = {
        label = "Elite",
        icon = "skull",
        sprite = nil, -- backlog
        desc = "Inimigo forte. Recompensa: carta garantida uncommon+.",
    },
    [MapManager.NODE_TYPES.MINI_BOSS] = {
        label = "Mini-Boss",
        icon = "skull_crowned",
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
        sprite = "altar", -- mais tematico que chest
        desc = "Encontro misterioso. Arrisque.",
    },
}

-- Helper: pesca um tipo dado um vetor { {type=, weight=}, ... }
local function rollWeighted(weights)
    local total = 0
    for _, e in ipairs(weights) do total = total + (e.weight or 1) end
    local r = love.math.random() * total
    local acc = 0
    for _, e in ipairs(weights) do
        acc = acc + (e.weight or 1)
        if r <= acc then return e.type end
    end
    return weights[#weights].type
end

-- Pesos base para um floorInAct dentro de um ato padrao.
-- Fase 5 vai permitir override por ato via Config.Acts[N].nodeWeights.
function MapManager.weightsFor(floorInAct, actNumber)
    -- Pisos finais do ato: mini-boss no penultimo, boss no ultimo
    if floorInAct == MapManager.FLOORS_PER_ACT then
        return { { type = MapManager.NODE_TYPES.BOSS, weight = 1 } }
    end
    if floorInAct == MapManager.FLOORS_PER_ACT - 1 then
        return { { type = MapManager.NODE_TYPES.MINI_BOSS, weight = 1 } }
    end

    -- Pesos progressivos: atos mais avancados tem mais elites/shops.
    local base = {
        { type = MapManager.NODE_TYPES.BATTLE, weight = 55 },
        { type = MapManager.NODE_TYPES.ELITE,  weight = 10 },
        { type = MapManager.NODE_TYPES.SHOP,   weight = 12 },
        { type = MapManager.NODE_TYPES.REST,   weight = 10 },
        { type = MapManager.NODE_TYPES.EVENT,  weight = 13 },
    }

    -- Ajustes por posicao no ato
    if floorInAct <= 2 then
        -- Inicio do ato: mais batalhas normais, menos elites
        base[1].weight = 70
        base[2].weight = 4
        base[4].weight = 8
    elseif floorInAct >= 5 then
        -- Final do ato: mais elites
        base[2].weight = 18
        base[3].weight = 14
    end

    return base
end

-- Gera N nos distintos (sem repeticao) para a proxima escolha.
-- Boss/mini-boss unicos nunca tem alternativas.
function MapManager.generate(floorInAct, actNumber, numNodes, opts)
    numNodes = numNodes or 3
    opts = opts or {}
    local weights = MapManager.weightsFor(floorInAct, actNumber)

    -- Floor boss/mini-boss: um unico no, nao ha escolha
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
    -- Se ainda faltam (pool unicos < numNodes), repete permitindo duplicatas
    while #nodes < numNodes do
        local t = rollWeighted(weights)
        table.insert(nodes, MapManager._makeNode(t, floorInAct, actNumber))
    end
    return nodes
end

-- Cria um node com payload minimo. Campos extras populados no handler do tipo.
function MapManager._makeNode(nodeType, floorInAct, actNumber)
    local meta = MapManager.NODE_META[nodeType] or {}
    return {
        type = nodeType,
        label = meta.label or nodeType,
        icon = meta.icon,
        sprite = meta.sprite, -- nil se não gerado ainda
        desc = meta.desc,
        floorInAct = floorInAct,
        actNumber = actNumber,
    }
end

-- Dado um floor global (1, 2, ...), converte para (actNumber, floorInAct).
-- Usado pelo Game quando so temos o contador global.
function MapManager.floorToAct(globalFloor)
    local act = math.floor((globalFloor - 1) / MapManager.FLOORS_PER_ACT) + 1
    local inAct = ((globalFloor - 1) % MapManager.FLOORS_PER_ACT) + 1
    return act, inAct
end

return MapManager
