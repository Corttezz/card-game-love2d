local M = {}

local function mean(t)
    if #t == 0 then return 0 end
    local s = 0
    for _, v in ipairs(t) do s = s + v end
    return s / #t
end

function M.run(runsArg, floorsArg)
    local runs = tonumber(runsArg or os.getenv("SIM509_RUNS") or "3") or 3
    local floorsList = {}
    for f in tostring(floorsArg or os.getenv("SIM509_FLOORS") or "8,10,12"):gmatch("%d+") do
        floorsList[#floorsList + 1] = tonumber(f)
    end
    local BS = require("tools.balance_sim")
    local Autoplay = BS.setup("expert")
    local MapManager = require("src.systems.MapManager")
    local Config = require("src.core.Config")
    local realFloors = MapManager.FLOORS_PER_ACT
    local realPrint = print
    local classes = { "warrior", "mage", "rogue" }

    local out = {}
    local function line(s) out[#out + 1] = s; realPrint(s) end
    line(("## Andares por ato (%d atos, piloto expert, %d runs por classe)"):format(Config.TotalActs or 6, runs))
    line("")
    line("| Andares/ato | Vitórias | Andar médio alcançado | Lutas | Turnos por luta | Grimório final | Coringas | Morte por ato | CPU por run |")
    line("|---|---|---|---|---|---|---|---|---|")
    for _, F in ipairs(floorsList) do
        MapManager.FLOORS_PER_ACT = F
        local wins, n, floors, battles, tpb, deck, jok, cpu, deathAct = 0, 0, {}, {}, {}, {}, {}, {}, {}
        for _, cls in ipairs(classes) do
            for i = 1, runs do
                local t0 = os.clock()
                print = function() end
                local ok, rec = pcall(Autoplay.playRunRecord, cls, i, 509500 + i * 31)
                print = realPrint
                n = n + 1
                if not ok then
                    realPrint(("[sim509] crash F=%d %s #%d: %s"):format(F, cls, i, tostring(rec)))
                else
                    if rec.won then wins = wins + 1
                    elseif rec.death then
                        local a = rec.death.act or 0
                        deathAct[a] = (deathAct[a] or 0) + 1
                    end
                    floors[#floors + 1] = rec.floors or 0
                    battles[#battles + 1] = rec.battles or 0
                    if (rec.battles or 0) > 0 then tpb[#tpb + 1] = (rec.turns or 0) / rec.battles end
                    deck[#deck + 1] = #(rec.deck or {})
                    jok[#jok + 1] = #(rec.jokers or {})
                    cpu[#cpu + 1] = os.clock() - t0
                    realPrint(("[sim509] F=%d %s #%d: %s andares %d"):format(F, cls, i,
                        tostring(rec.outcome), rec.floors or 0))
                end
            end
        end
        local da = {}
        for a = 1, (Config.TotalActs or 6) + 1 do
            if deathAct[a] then da[#da + 1] = ("A%d:%d"):format(a, deathAct[a]) end
        end
        line(("| %d | %d/%d | %.1f | %.1f | %.1f | %.1f | %.1f | %s | %.1fs |"):format(F, wins, n, mean(floors),
            mean(battles), mean(tpb), mean(deck), mean(jok), #da > 0 and table.concat(da, " ") or "-", mean(cpu)))
    end
    MapManager.FLOORS_PER_ACT = realFloors
    BS.teardown()
    love.filesystem.write("sim_floors_509.md", table.concat(out, "\n") .. "\n")
    realPrint("[sim509] relatório: " .. love.filesystem.getSaveDirectory() .. "/sim_floors_509.md")
    return true
end

return M
