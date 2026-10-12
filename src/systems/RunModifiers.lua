-- src/systems/RunModifiers.lua
-- REGRAS QUE MULTIPLICAM A CORRIDA (Out/2026): Selos do Grimório (dificuldade
-- escolhida antes da run, cumulativa 1-10) e Maldições do endless (1-de-2 a
-- cada ciclo de 8 andares, empilháveis). Dados em src/data/run_modifiers.lua;
-- desenho e pesquisa em memory/endless_and_seals.md.
--
-- REGRA DE OURO: isto só MULTIPLICA por cima dos números base. Nenhum valor
-- de Config.Acts / cartas / inimigos muda aqui — o balanço base é das frentes
-- de combate; um selo 0 sem maldição devolve exatamente o jogo base (os
-- multiplicadores neutros são 1 e os somatórios 0).
--
-- Estado na run (viaja no save, sem migração — leitura com default):
--   run.seal    = 0..10
--   run.endless = { cycle = n, curses = { [id] = acúmulos },
--                   order = { id, ... },          -- ordem de escolha (UI)
--                   pending = { idA, idB } | nil } -- escolha aberta do ciclo
--
-- Quem consulta (um ponto de entrada por sistema):
--   ActSystem/Game  → enemyStats + decorateEnemy (vida, dano, Bloqueio)
--   MapManager      → eliteWeightMul
--   ShopSystem      → priceMul
--   RestScreen/Game → healMul("rest"|"act")
--   Game            → startingGold, victoryGoldDelta
--   ShopSystem      → rewardCardsDelta
--   ScoreSystem     → scoreMul

local Data = require("src.data.run_modifiers")

local RunModifiers = {}

RunModifiers.SEAL_MAX = #Data.SEALS
RunModifiers.SEALS = Data.SEALS
RunModifiers.CURSES = Data.CURSES

local CURSE_BY_ID = {}
for _, c in ipairs(Data.CURSES) do CURSE_BY_ID[c.id] = c end
function RunModifiers.getCurse(id) return CURSE_BY_ID[id] end

local MULT = { eliteWeight = true, restHeal = true, actHeal = true, price = true,
    hpNormal = true, hpBoss = true, dmgElite = true, dmgAll = true, hpAll = true }
local ADD = { victoryGold = true, rewardCards = true, enemyBlock = true }

function RunModifiers.seal(run)
    return math.max(0, math.min(RunModifiers.SEAL_MAX, math.floor((run and run.seal) or 0)))
end

-- Todas as regras ativas, já compostas: multiplicativas em produto,
-- aditivas em soma, startGold = o menor pedido (o mais duro vence).
function RunModifiers.rules(run)
    local out = {}
    local function apply(rules, times)
        for k, v in pairs(rules) do
            if MULT[k] then
                out[k] = (out[k] or 1) * (v ^ times)
            elseif ADD[k] then
                out[k] = (out[k] or 0) + v * times
            elseif k == "startGold" then
                out[k] = math.min(out[k] or math.huge, v)
            else
                print("[RunModifiers] regra desconhecida: " .. tostring(k))
            end
        end
    end
    for i = 1, RunModifiers.seal(run) do apply(Data.SEALS[i].rules, 1) end
    local e = run and run.endless
    for id, n in pairs((e and e.curses) or {}) do
        local c = CURSE_BY_ID[id]
        if c then apply(c.rules, n)
        else print("[RunModifiers] maldicao desconhecida no save: " .. tostring(id)) end
    end
    return out
end

local function mul(run, k) return RunModifiers.rules(run)[k] or 1 end
local function add(run, k) return RunModifiers.rules(run)[k] or 0 end

-- ===== Inimigo =====
function RunModifiers.enemyStats(run, stats, nodeType)
    if not stats then return stats end
    local r = RunModifiers.rules(run)
    local hp, dmg = r.hpAll or 1, r.dmgAll or 1
    if nodeType == "boss" or nodeType == "mini_boss" then
        hp = hp * (r.hpBoss or 1)
    else
        hp = hp * (r.hpNormal or 1)
    end
    if nodeType == "elite" then dmg = dmg * (r.dmgElite or 1) end
    if hp == 1 and dmg == 1 then return stats end
    local out = {}
    for k, v in pairs(stats) do out[k] = v end
    out.health = math.max(1, math.floor((stats.health or 1) * hp + 0.5))
    out.damage = math.max(1, math.floor((stats.damage or 1) * dmg + 0.5))
    return out
end

-- Bloqueio inicial (maldição Couraça Abissal), em fração da vida máxima.
-- Passa por cima do teto de armadura do inimigo de propósito: é o "escudo"
-- com que ele entra na luta, não um ganho de turno.
function RunModifiers.decorateEnemy(run, enemy)
    if not enemy then return end
    local frac = add(run, "enemyBlock")
    if frac > 0 then
        local b = math.floor((enemy.maxHealth or enemy.health or 0) * frac)
        enemy.armor = (enemy.armor or 0) + b
        enemy.maxArmor = math.max(enemy.maxArmor or 0, enemy.armor)
    end
end

-- ===== Mapa / loja / cura / ouro =====
function RunModifiers.eliteWeightMul(run) return mul(run, "eliteWeight") end
function RunModifiers.priceMul(run) return mul(run, "price") end

-- kind = "rest" (fogueira) | "act" (entre atos / ciclos do endless)
function RunModifiers.healMul(run, kind)
    return mul(run, kind == "rest" and "restHeal" or "actHeal")
end

-- Preço com o multiplicador (arredonda pra cima: a casa nunca perde centavo).
function RunModifiers.price(run, cost)
    if not cost or cost <= 0 then return cost end
    local m = RunModifiers.priceMul(run)
    if m == 1 then return cost end
    return math.ceil(cost * m - 1e-9)
end

function RunModifiers.startingGold(run, default)
    local g = RunModifiers.rules(run).startGold
    if g == nil then return default end
    return g
end

function RunModifiers.victoryGoldDelta(run) return add(run, "victoryGold") end
function RunModifiers.rewardCardsDelta(run) return add(run, "rewardCards") end

-- ===== Pontuação =====
-- Selo +10%/nível; cada acúmulo de maldição soma o `score` dela.
function RunModifiers.scoreMul(run)
    local m = 1 + Data.SEAL_SCORE * RunModifiers.seal(run)
    local e = run and run.endless
    for id, n in pairs((e and e.curses) or {}) do
        local c = CURSE_BY_ID[id]
        if c then m = m + (c.score or 0) * n end
    end
    return m
end

-- ===== Endless: ciclos e maldições =====
function RunModifiers.endlessState(run)
    if not run then return nil end
    run.endless = run.endless or { cycle = 0, curses = {}, order = {} }
    run.endless.curses = run.endless.curses or {}
    run.endless.order = run.endless.order or {}
    return run.endless
end

function RunModifiers.cycle(run)
    return (run and run.endless and run.endless.cycle) or 0
end

function RunModifiers.pending(run)
    return run and run.endless and run.endless.pending
end

function RunModifiers.curseStacks(run, id)
    local e = run and run.endless
    return (e and e.curses and e.curses[id]) or 0
end

function RunModifiers.totalCurseStacks(run)
    local n = 0
    local e = run and run.endless
    for _, k in pairs((e and e.curses) or {}) do n = n + k end
    return n
end

-- Lista ordenada { {id, stacks} } pra UI (TopBar, pausa, roteiro).
function RunModifiers.curseList(run)
    local out = {}
    local e = run and run.endless
    if not e then return out end
    for _, id in ipairs(e.order or {}) do
        if (e.curses[id] or 0) > 0 then out[#out + 1] = { id = id, stacks = e.curses[id] } end
    end
    return out
end

-- Abre o ciclo seguinte: cycle+1 e sorteia 2 maldições DIFERENTES que ainda
-- não bateram o teto (stream "event" do Rng da run — reprodutível por seed e
-- salva junto). Chamado por RunManager:advanceFloorInAct ao entrar/girar o
-- endless. Idempotente se já há escolha aberta.
function RunModifiers.beginEndlessCycle(run)
    local e = RunModifiers.endlessState(run)
    if not e then return nil end
    if e.pending then return e.pending end
    e.cycle = (e.cycle or 0) + 1
    local pool = {}
    for _, c in ipairs(Data.CURSES) do
        if (e.curses[c.id] or 0) < (c.max or math.huge) then pool[#pool + 1] = c.id end
    end
    if #pool == 0 then return nil end
    local rng = require("src.systems.Rng").get()
    local a = table.remove(pool, rng:random("event", #pool))
    local b = (#pool > 0) and table.remove(pool, rng:random("event", #pool)) or nil
    e.pending = { a, b }
    return e.pending
end

-- Escolhe uma das maldições abertas. Devolve true se aplicou.
function RunModifiers.chooseCurse(run, id)
    local e = run and run.endless
    if not e or not e.pending then return false end
    local ok = false
    for _, p in ipairs(e.pending) do if p == id then ok = true end end
    if not ok then
        print("[RunModifiers] maldicao fora da escolha aberta: " .. tostring(id))
        return false
    end
    if (e.curses[id] or 0) == 0 then table.insert(e.order, id) end
    e.curses[id] = (e.curses[id] or 0) + 1
    e.pending = nil
    return true
end

return RunModifiers
