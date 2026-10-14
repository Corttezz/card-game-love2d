local Debug = require("src.core.Debug")

local EnemyKits = require("src.data.enemies")
local Rng = require("src.systems.Rng")

local EnemyRoster = {}

local COMBAT = { battle = true, elite = true, mini_boss = true, boss = true }

function EnemyRoster.isCombat(nodeType)
    return COMBAT[nodeType] == true
end

function EnemyRoster.biomeAct(run)
    if not run then return 1 end
    local a = run.actNumber or 1
    if run.endlessMode then
        a = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
    end
    return (((a or 1) - 1) % 6) + 1
end

function EnemyRoster.poolFor(act, nodeType)
    local byAct = EnemyKits.ROSTER[act] or EnemyKits.ROSTER[1]
    return byAct[nodeType or "battle"] or byAct.battle
end

function EnemyRoster.pick(act, nodeType, recent)
    local pool = EnemyRoster.poolFor(act, nodeType)
    if #pool == 1 then return pool[1] end
    recent = recent or {}
    local last = recent[#recent]
    local prev = recent[#recent - 1]
    local function filter(excl)
        local out = {}
        for _, id in ipairs(pool) do
            if not excl[id] then out[#out + 1] = id end
        end
        return out
    end
    local cand = filter({ [last or ""] = true, [prev or ""] = true })
    if #cand == 0 then cand = filter({ [last or ""] = true }) end
    if #cand == 0 then cand = pool end
    return Rng.get():pick("enemy", cand)
end

function EnemyRoster.assignNodes(run, nodes)
    if not nodes then return end
    local act = EnemyRoster.biomeAct(run)
    local recent = {}
    for _, id in ipairs((run and run.recentEnemies) or {}) do recent[#recent + 1] = id end
    for _, node in ipairs(nodes) do
        if COMBAT[node.type] and not node.enemyId then
            node.enemyId = EnemyRoster.pick(act, node.type, recent)
            recent[#recent + 1] = node.enemyId
        end
    end
end

function EnemyRoster.resolveNode(run, node, nodeType)
    nodeType = nodeType or (node and node.type) or "battle"
    if node and node.enemyId then return node.enemyId end
    local id = EnemyRoster.pick(EnemyRoster.biomeAct(run), nodeType,
        run and run.recentEnemies)
    if node then node.enemyId = id end
    return id
end

function EnemyRoster.remember(run, id)
    if not run or not id then return end
    run.recentEnemies = run.recentEnemies or {}
    local r = run.recentEnemies
    r[#r + 1] = id
    while #r > 4 do table.remove(r, 1) end
end

function EnemyRoster.spawn(Enemy, id, stats, act)
    local kit = EnemyKits.KITS[id]
    if not kit then
        Debug.warn("[EnemyRoster] sem kit para '" .. tostring(id) .. "' — inimigo genérico")
    end
    local scales = EnemyKits.DAMAGE_SCALE_BY_ACT or {}
    local actScale = 1
    if act then actScale = scales[math.min(math.max(1, act), #scales)] or 1 end
    local hp = math.max(1, math.floor((stats.health or 20) * ((kit and kit.hpMul) or 1)))
    if stats.kind == "boss" then actScale = actScale * (EnemyKits.BOSS_DAMAGE_SCALE or 1) end
    local dmg = math.max(1, math.floor((stats.damage or 5)
        * ((kit and kit.dmgMul) or 1) * actScale))
    local enemy = Enemy:new(hp, dmg, kit and id or "generic")
    enemy.spriteId = id
    return enemy
end

return EnemyRoster
