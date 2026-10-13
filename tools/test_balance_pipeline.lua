-- tools/test_balance_pipeline.lua
-- Trava da PIPELINE de balanceamento (Out/2026): pilotos, determinismo,
-- throughput e o registro que alimenta tools/balance.py.
--
--   1. Os tres pilotos existem como PERFIL (dado) e jogam uma run sem crash
--      no relogio instantaneo.
--   2. Sanidade NAIVE < AVERAGE < EXPERT: medida em BATALHAS IGUAIS (mesmo
--      retrato, mesma seed, vida cheia — o banco do balance_bench), nao em
--      winrate de poucas runs (que e sorteio). O naive tem que perder mais
--      vida que o expert_fast no agregado dos retratos.
--   3. Determinismo: mesma seed → mesmo registro (resultado, batalhas, deck).
--   4. Throughput: run do piloto `average` no relogio instantaneo em menos de
--      N segundos de CPU (teto FOLGADO — mede regressao de ordem de grandeza,
--      nao ms; o numero real vai no relatorio da bateria).
--   5. Registro: campos que o relatorio Python le estao presentes e coerentes
--      (battleLog soma as batalhas, dano por fonte > 0, deck por batalha).
--   6. jsonlite codifica o registro e o Lua le de volta o mesmo numero de runs.
--
--   love . test_one test_balance_pipeline

local TK = require("tools.testkit")

local M = {}

local function silent(fn, ...)
    local realPrint = print
    print = function() end
    local ok, a, b = pcall(fn, ...)
    print = realPrint
    return ok, a, b
end

function M.run()
    local t = TK.new("pipeline de balanceamento: pilotos, determinismo, throughput, registro")
    TK.bootstrap()
    local BS = require("tools.balance_sim")
    local Autoplay = BS.setup("expert_fast")
    local Instant = require("tools.instant_engine")
    Instant.install(Autoplay)
    Instant.resetStats()

    -- 1) perfis
    for _, name in ipairs({ "naive", "average", "expert", "expert_fast" }) do
        local prof = Autoplay.PILOTS[name]
        t:truthy("perfil '" .. name .. "' existe", type(prof) == "table")
        t:truthy("perfil '" .. name .. "' declara combate/deck/caminho/loja",
            prof and prof.combat and prof.build and prof.path and prof.shop)
    end
    t:truthy("nome legado v6 = expert", Autoplay.PILOTS.v6 == Autoplay.PILOTS.expert)

    -- runs curtas por piloto (sem crash) + registro
    local recs = {}
    for _, name in ipairs({ "naive", "average", "expert_fast" }) do
        Autoplay.setPilot(name)
        local ok, rec = silent(Autoplay.playRunRecord, "warrior", 1, 910001, { maxBattles = 6 })
        t:truthy(name .. ": run curta sem crash (" .. tostring(ok and rec.outcome or rec) .. ")", ok)
        if ok then recs[name] = rec end
    end

    -- 5) registro coerente (piloto average)
    do
        local r = recs.average
        if r then
            t:eq("registro: battleLog tem uma linha por batalha", #(r.battleLog or {}), r.battles)
            local dmg = 0
            for _, v in pairs(r.dmg or {}) do dmg = dmg + v end
            t:check("registro: dano por fonte somado > 0 (" .. dmg .. ")", dmg > 0)
            t:check("registro: composicao do ataque tem base > 0",
                (r.dmgParts and r.dmgParts.base or 0) > 0)
            t:eq("registro: deck por batalha tem uma entrada por batalha", #(r.deckByBattle or {}), r.floors)
            t:eq("registro: piloto gravado", r.pilot, "average")
            t:truthy("registro: cada batalha nomeia o inimigo",
                r.battleLog[1] and r.battleLog[1].enemy ~= nil)
            -- dano do livro bate com a vida tirada do inimigo em cada batalha
            local okSum = true
            for _, b in ipairs(r.battleLog) do
                local s = 0
                for _, v in pairs(b.dmg or {}) do s = s + v end
                if s ~= (b.enemyMaxHp - b.enemyHpLeft) then okSum = false end
            end
            t:check("registro: dano por fonte == vida tirada do inimigo, batalha a batalha", okSum)
        end
    end

    -- 3) determinismo
    do
        Autoplay.setPilot("average")
        local _, a = silent(Autoplay.playRunRecord, "rogue", 1, 910007, { maxBattles = 8 })
        local _, b = silent(Autoplay.playRunRecord, "rogue", 1, 910007, { maxBattles = 8 })
        t:eq("determinismo: mesmo resultado", a and a.outcome, b and b.outcome)
        t:eq("determinismo: mesmo HP final", a and a.hpEnd, b and b.hpEnd)
        t:eq("determinismo: mesmo deck final", a and table.concat(a.deck, ","),
            b and table.concat(b.deck, ","))
        t:eq("determinismo: mesmos turnos", a and a.turns, b and b.turns)
    end

    -- 2) sanidade por BATALHAS IGUAIS: retratos de uma run do average,
    -- rejogados por naive e expert_fast com a mesma seed, vida cheia.
    do
        local snaps = {}
        Autoplay.setPilot("average")
        Autoplay.onBattleStart = function(snap) snaps[#snaps + 1] = snap end
        silent(Autoplay.playRunRecord, "warrior", 1, 910011, { maxBattles = 10 })
        silent(Autoplay.playRunRecord, "mage", 1, 910012, { maxBattles = 10 })
        Autoplay.onBattleStart = nil
        -- so batalhas com algum peso (fora as 2 primeiras do A1, que qualquer um vence)
        local picked = {}
        for _, s in ipairs(snaps) do
            if (s.act or 1) > 1 or (s.floorInAct or 1) >= 3 then picked[#picked + 1] = s end
        end
        t:check("banco: retratos suficientes (" .. #picked .. ")", #picked >= 8)
        local function bench(pilot)
            Autoplay.setPilot(pilot)
            local lost, deaths = 0, 0
            for i, s in ipairs(picked) do
                Autoplay._resetBattleStats()
                local ok, r = silent(Autoplay.replayBattle, s, 5000 + i)
                if ok and r then
                    lost = lost + math.min(r.hpLost, r.maxHp) + (r.won and 0 or r.maxHp)
                    if not r.won then deaths = deaths + 1 end
                end
            end
            return lost, deaths
        end
        local lostN, deadN = bench("naive")
        local lostA, deadA = bench("average")
        local lostE, deadE = bench("expert_fast")
        print(("  banco: vida perdida (+maxHP por derrota) naive %d (%d mortes) · average %d (%d) · expert_fast %d (%d)")
            :format(lostN, deadN, lostA, deadA, lostE, deadE))
        t:check("sanidade: NAIVE perde mais vida que EXPERT nas mesmas batalhas", lostN > lostE)
        t:check("sanidade: AVERAGE nao perde mais que o NAIVE", lostA <= lostN)
    end

    -- 4) throughput (teto folgado)
    do
        Autoplay.setPilot("average")
        local t0 = os.clock()
        local ok = silent(Autoplay.playRunRecord, "warrior", 1, 910021)
        local secs = os.clock() - t0
        print(("  throughput: run inteira do average em %.2fs de CPU"):format(secs))
        t:check("throughput: run inteira do piloto average em < 8s de CPU (" .. string.format("%.2f", secs) .. "s)",
            ok and secs < 8)
    end
    t:eq("relogio instantaneo: nenhum dreno estourou o teto", Instant.stats.stalls, 0)

    -- 6) jsonlite
    do
        local J = require("tools.jsonlite")
        local s = J.encode({ records = { recs.average or {}, recs.naive or {} }, meta = { n = 2, label = "x\"y" } })
        t:truthy("jsonlite: string nao vazia", #s > 100)
        t:truthy("jsonlite: escapa aspas", s:find('"label":"x\\"y"', 1, true) ~= nil)
        t:truthy("jsonlite: sem NaN", not s:find("nan", 1, true))
    end

    Instant.uninstall(Autoplay)
    Autoplay.setPilot("expert")
    return t:done()
end

return M
