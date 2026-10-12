-- src/systems/EnemyRoster.lua
-- QUEM o jogador enfrenta em cada nó (Out/2026).
--
-- Auditoria de conteúdo: o roster era UM monstro comum por ato pra toda
-- batalha, e o sprite do elite servia de mini-chefe — uma run enfrentou o
-- Ceifador do ato 1 cinco vezes. Agora cada ato tem um POOL por tipo de nó
-- (src/data/enemies.lua, `ROSTER`), sorteado pelo stream "enemy" do Rng (a
-- seed reproduz o combate) e sem repetir o último inimigo enfrentado.
--
-- O inimigo é decidido quando o NÓ nasce (RunManager:generateNextNodes) e
-- gravado nele (`node.enemyId`): a prévia da encruzilhada, a batalha e o
-- Continuar leem o MESMO inimigo — o save não re-sorteia.

local EnemyKits = require("src.data.enemies")
local Rng = require("src.systems.Rng")

local EnemyRoster = {}

local COMBAT = { battle = true, elite = true, mini_boss = true, boss = true }

function EnemyRoster.isCombat(nodeType)
    return COMBAT[nodeType] == true
end

-- Ato do BIOMA (1..6). Endless cicla 4,5,6,1,2,3,... — mesmo wrap do
-- WorldRoad.rawBiome e do EnemyRenderer.resolveSpriteId de antes.
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

-- Sorteia o inimigo de um nó. `recent` = ids enfrentados por último (o mais
-- recente no fim); o último nunca repete, o penúltimo só se não houver outro.
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

-- Grava o inimigo nos nós de combate recém-gerados. Dois nós da MESMA
-- encruzilhada também não repetem entre si (quando o pool deixa).
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

-- Inimigo do nó corrente. Save antigo (nó sem enemyId) sorteia AGORA e
-- grava no nó — o Continuar seguinte lê o mesmo.
function EnemyRoster.resolveNode(run, node, nodeType)
    nodeType = nodeType or (node and node.type) or "battle"
    if node and node.enemyId then return node.enemyId end
    local id = EnemyRoster.pick(EnemyRoster.biomeAct(run), nodeType,
        run and run.recentEnemies)
    if node then node.enemyId = id end
    return id
end

-- Anota o inimigo enfrentado (alimenta o "sem repetir"). Guarda só os 4
-- últimos — o filtro olha dois.
function EnemyRoster.remember(run, id)
    if not run or not id then return end
    run.recentEnemies = run.recentEnemies or {}
    local r = run.recentEnemies
    r[#r + 1] = id
    while #r > 4 do table.remove(r, 1) end
end

-- Monta o inimigo: escala vida/dano pelo kit e instala o kit (rola o 1º
-- intent). `Enemy` vem por parâmetro pra este módulo não depender da
-- entidade (testes injetam a classe real).
-- `act` (opcional) aplica a escala de dano do ato (DAMAGE_SCALE_BY_ACT);
-- endless usa a do último ato.
function EnemyRoster.spawn(Enemy, id, stats, act)
    local kit = EnemyKits.KITS[id]
    if not kit then
        print("[EnemyRoster] sem kit para '" .. tostring(id) .. "' — inimigo genérico")
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
