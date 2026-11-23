local TK = require("tools.testkit")

local M = {}

local function body(t)
    TK.bootstrap()
    local Rng = require("src.systems.Rng")
    local MapManager = require("src.systems.MapManager")
    local RunManager = require("src.systems.RunManager")
    local Config = require("src.core.Config")
    local F = MapManager.FLOORS_PER_ACT

    local crossings, maps = 0, 0
    local tangled, wide, twins, minN, maxN = 0, 0, 0, math.huge, 0
    for seed = 1, 60 do
        Rng.setActive(Rng.new(seed))
        local map = MapManager.buildActMap(1 + (seed % 6))
        maps = maps + 1
        if MapManager.hasCrossing(map) then crossings = crossings + 1 end
        local ok = #map.floors == F
        for f = 1, F - 1 do
            local seen = {}
            for _, n in ipairs(map.floors[f]) do
                ok = ok and #(n.mapNext or {}) >= 1
                for _, j in ipairs(n.mapNext or {}) do seen[j] = true end
            end
            for j = 1, #map.floors[f + 1] do ok = ok and seen[j] == true end
        end
        ok = ok and map.floors[F][1].type == "boss" and map.floors[F - 1][1].type == "mini_boss"
        local total = 0
        for f = 1, F do
            local row = map.floors[f]
            total = total + #row
            for i, a in ipairs(row) do
                if #(a.mapNext or {}) > 3 then wide = wide + 1 end
                local kidTypes = {}
                for _, j in ipairs(a.mapNext or {}) do
                    local ty = map.floors[f + 1][j].type
                    if kidTypes[ty] and #map.floors[f + 1] > 1 then twins = twins + 1 end
                    kidTypes[ty] = true
                    for k = i + 1, #row do
                        for _, jb in ipairs(row[k].mapNext or {}) do
                            if jb < j then tangled = tangled + 1 end
                        end
                    end
                end
            end
        end
        local starts = {}
        for _, n in ipairs(map.floors[1]) do
            if starts[n.type] then twins = twins + 1 end
            starts[n.type] = true
        end
        minN, maxN = math.min(minN, total), math.max(maxN, total)
        if not ok then t:check("mapa válido seed " .. seed, false) end
    end
    t:eq("todo mapa do ato tem caminhos que se juntam", crossings, maps)
    t:eq("trilhas nunca se cruzam por cima", tangled, 0)
    t:eq("cada nó abre no máximo 3 ramos", wide, 0)
    t:eq("ramos irmãos nunca repetem o tipo", twins, 0)
    t:truthy("mapa ramificado e desigual (" .. minN .. "-" .. maxN .. " nós)", minN >= 12 and maxN > 20 and maxN > minN)

    Rng.setActive(Rng.new(4242))
    local rm = RunManager:new()
    rm:startNewRun("warrior")
    local run = rm.currentRun
    local first = rm:generateNextNodes(3)
    t:truthy("mapa do ato nasce com a run", run.actMap and run.actMap.act == 1)
    t:eq("andar 1: as 3 trilhas", #first, 3)
    local boss = run.actMap.floors[F][1]
    t:truthy("chefe revelado desde o andar 1", boss.enemyId)

    local function follow(pickIdx)
        local node = rm:chooseNode(pickIdx, { hp = 50, maxHp = 50, gold = 0 })
        rm:advanceFloorInAct(6)
        return node
    end
    local okPath = true
    for f = 1, F - 1 do
        local node = follow(1)
        local nxt = rm:generateNextNodes(3)
        local want = {}
        for _, j in ipairs(node.mapNext or {}) do want[j] = true end
        for _, n in ipairs(nxt) do
            okPath = okPath and n.mapFloor == f + 1 and want[n.mapLane] == true
        end
        okPath = okPath and #nxt == #(node.mapNext or {})
    end
    t:check("cada escolha só abre os filhos do nó escolhido", okPath)
    local last = rm:getPendingNodes()
    t:eq("último andar é o chefe revelado", last[1] and last[1].enemyId, boss.enemyId)

    follow(1)
    rm:generateNextNodes(3)
    t:eq("ato 2 gera mapa novo", run.actMap.act, 2)
    t:eq("ato 2 abre as 3 trilhas", #rm:getPendingNodes(), 3)

    t:eq("Cristal de Éter: 1º custa 25", rm:getCrystalCost(), Config.Offers.CRYSTAL_COST_BASE)
    rm:registerCrystal()
    t:eq("Cristal de Éter: 2º custa 38", rm:getCrystalCost(), 38)
    rm:registerCrystal()
    rm:registerCrystal()
    t:eq("Cristal de Éter: 4º custa 84", rm:getCrystalCost(), 84)

    local Player = require("src.entities.Player")
    local p = Player:new()
    for _ = 1, 12 do
        p.baseMaxMana = p.baseMaxMana + 1
        p.maxMana = p.maxMana + 1
    end
    p:resetMaxMana()
    t:eq("mana sem teto: 3 + 12 cristais = 15", p.maxMana, 15)

    local ShopSystem = require("src.systems.ShopSystem")
    local shop = ShopSystem:new()
    shop:setContext({ runManager = rm })
    local seen
    for _ = 1, 40 do
        shop._offeredUpgradeIds = {}
        local o = shop:generateUpgradeOffer()
        if o and o.id == "mana_upgrade" then seen = o break end
    end
    t:eq("loja cobra o preço crescente do Cristal", seen and seen.cost, rm:getCrystalCost())

    local RM = require("src.systems.RunModifiers")
    t:eq("15 Selos", RM.SEAL_MAX, 15)
    run.seal = 11
    t:eq("Selo 11: Cristal 50% mais caro", rm:getCrystalCost(), math.floor(25 * 1.5 ^ 3 * 1.5 + 0.5))
    run.seal = 10
    t:eq("Selo 10 não traz o 11", rm:getCrystalCost(), 84)
    local s15 = { seal = 15 }
    local st = { health = 100, damage = 10 }
    t:near("Selo 15: chefe +15% e +10%", RM.enemyStats(s15, st, "boss").health, 126.5, 0.5)
    t:eq("Selo 15: dano comum ×1,1 ×1,1", RM.enemyStats(s15, st, "battle").damage,
        math.floor(10 * 1.10 * 1.10 + 0.5))
    t:near("Selo 15: elites 1,5 × 1,3", RM.eliteWeightMul(s15), 1.5 * 1.3, 1e-9)
    t:near("Selo 15: pontos ×2,5", RM.scoreMul(s15), 2.5, 1e-9)
    local Enemy = require("src.entities.Enemy")
    local en = Enemy:new(200, 10)
    RM.decorateEnemy(s15, en)
    t:eq("Selo 15: Bloqueio inicial 5% da vida", en.armor, 10)
    local missing = {}
    for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
        local L = require("src.i18n.locales.run_modifiers." .. loc).seals
        for _, s in ipairs(RM.SEALS) do
            local e = L[s.id]
            if not (e and e.name and e.desc) then missing[#missing + 1] = loc .. ":" .. s.id end
        end
    end
    t:eq("todo Selo tem nome e descrição nos 5 idiomas", table.concat(missing, ","), "")

    local starters = require("src.systems.CardRegistry").STARTER_DECKS
    for cls, deck in pairs(starters or {}) do
        t:eq("grimório inicial com 2 cartas: " .. cls, #deck, 2)
    end
end

function M.run()
    local t = TK.new("mapa do ato e Cristal #509")
    local ok, err = pcall(body, t)
    if not ok then t:check("sem erro: " .. tostring(err), false) end
    return t:done()
end

return M
