-- tools/balance_bench.lua
-- BANCO DE BATALHAS (Out/2026): mede a qualidade do COMBATE do piloto sem o
-- ruido da run inteira.
--
-- Por que existe: uma run tem ~10-30 batalhas, decisoes de deck, mapa e loja
-- — comparar duas politicas de combate pelo winrate de 30 runs e medir
-- sorteio. Aqui: (1) grava o RETRATO do comeco de cada batalha de runs reais
-- (deck, forja, coringas, ato/andar/no), (2) rejoga CADA retrato com cada
-- politica, mesma seed, vida cheia, e (3) compara HP perdido e mortes.
-- Mesma batalha, mesmo embaralhamento, mesmos intents: so a decisao muda.
--
--   love . balance_bench [runsGravadas] [classes] [seed] [politicas]
--   ex: love . balance_bench 6 all 700000 v5,v6
--
-- Saida: console + BALANCE_OUT (ou <save>/balance_bench_report.md).

local M = {}

function M.run(runsArg, classArg, seedArg, policiesArg)
    local runs = tonumber(runsArg or "6") or 6
    local classes = { "warrior", "mage", "rogue" }
    if classArg and classArg ~= "all" then
        classes = {}
        for c in classArg:gmatch("[^,]+") do classes[#classes + 1] = c end
    end
    local seed = tonumber(seedArg or "700000") or 700000
    local policies = {}
    for pol in (policiesArg or "v5,v6"):gmatch("[^,]+") do policies[#policies + 1] = pol end

    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    require("src.i18n.I18n").init()
    local Autoplay = require("tools.autoplay")
    Autoplay.quiet = true
    local realPrint = print

    -- 1) grava retratos jogando runs com a politica de referencia (v5)
    local snaps = {}
    Autoplay.policy = "v5"
    Autoplay.onBattleStart = function(snap) snaps[#snaps + 1] = snap end
    for _, cls in ipairs(classes) do
        for i = 1, runs do
            print = function() end
            pcall(Autoplay.playRunRecord, cls, i, seed + i)
            print = realPrint
        end
    end
    Autoplay.onBattleStart = nil
    realPrint(("[balance_bench] %d batalhas gravadas"):format(#snaps))

    -- 2) rejoga cada retrato com cada politica (2 seeds por retrato)
    local res = {}  -- res[pol][class][act] = {n, lost, deaths, turns}
    for _, pol in ipairs(policies) do
        Autoplay.policy = pol
        res[pol] = {}
        for si, snap in ipairs(snaps) do
            for k = 1, 2 do
                -- BENCH_TRACE=classe:ato liga o diario so dessas batalhas
                -- (diagnostico: ver turno a turno ONDE a politica perde HP)
                local trace = os.getenv("BENCH_TRACE")
                local traced = trace and trace == (snap.class .. ":" .. tostring(snap.act))
                Autoplay.quiet = not traced
                if traced then
                    local rep = Autoplay.getReport()
                    rep[#rep + 1] = ("\n# [%s] retrato %d replay %d"):format(pol, si, k)
                end
                print = function() end
                local ok, r = pcall(Autoplay.replayBattle, snap, seed * 3 + si * 7 + k)
                print = realPrint
                Autoplay.quiet = true
                if ok and r then
                    local byC = res[pol][snap.class] or {}
                    res[pol][snap.class] = byC
                    local key = math.min(snap.act or 1, 6)
                    local b = byC[key] or { n = 0, lost = 0, deaths = 0, turns = 0 }
                    byC[key] = b
                    b.n = b.n + 1
                    b.lost = b.lost + math.min(r.hpLost, r.maxHp)
                    if not r.won then b.deaths = b.deaths + 1 end
                    b.turns = b.turns + (tonumber(r.turns) or 40)
                else
                    realPrint("[balance_bench] replay falhou: " .. tostring(r))
                end
            end
        end
        realPrint("[balance_bench] politica " .. pol .. " ok")
    end

    -- 3) relatorio
    local out = {}
    local function p(fmt, ...) out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
    p("# Banco de batalhas — combate do piloto")
    p("")
    p("%d retratos (%d runs/classe gravadas com v5), 2 replays cada, vida cheia.", #snaps, runs)
    p("")
    p("| classe | ato | batalhas | %s |", table.concat(policies, " HP perdido | ") .. " HP perdido")
    p("|---|---|---|%s", string.rep("---|", #policies))
    for _, cls in ipairs(classes) do
        for act = 1, 6 do
            local cells, n = {}, 0
            for _, pol in ipairs(policies) do
                local b = res[pol][cls] and res[pol][cls][act]
                if b and b.n > 0 then
                    n = b.n
                    cells[#cells + 1] = string.format("%.1f (mortes %d, %.1f t)",
                        b.lost / b.n, b.deaths, b.turns / b.n)
                else
                    cells[#cells + 1] = "-"
                end
            end
            if n > 0 then p("| %s | A%d | %d | %s |", cls, act, n, table.concat(cells, " | ")) end
        end
    end
    p("")
    p("## Total por politica")
    for _, pol in ipairs(policies) do
        local n, lost, deaths = 0, 0, 0
        for _, byC in pairs(res[pol]) do
            for _, b in pairs(byC) do n = n + b.n; lost = lost + b.lost; deaths = deaths + b.deaths end
        end
        p("- **%s**: %d batalhas, HP perdido medio %.2f, mortes %d", pol, n, lost / math.max(1, n), deaths)
    end
    local text = table.concat(out, "\n")
    print(text)
    if os.getenv("BENCH_TRACE") then
        love.filesystem.write("balance_bench_trace.md", table.concat(Autoplay.getReport(), "\n"))
        print("[balance_bench] diario das batalhas rastreadas: <save>/balance_bench_trace.md")
    end
    local path = os.getenv("BALANCE_OUT")
    if path and path ~= "" then
        local f = io.open(path, "w")
        if f then f:write(text); f:close() end
    else
        love.filesystem.write("balance_bench_report.md", text)
    end
    love.event.quit()
end

return M
