local TK = require("tools.testkit")

local M = {}

function M.run()
    TK.bootstrap()
    local IV = require("src.systems.IntentVisibility")
    local Fog = require("src.data.intent_fog")
    local Enemy = require("src.entities.Enemy")
    local biomes = require("src.data.biomes")
    local list = biomes.list or biomes
    local runs = tonumber(os.getenv("FOG_REPORT_RUNS") or "") or 10
    local turns = tonumber(os.getenv("FOG_REPORT_TURNS") or "") or 6

    local function pct(v) return string.format("%3d%%", math.floor(v * 100 + 0.5)) end

    for idx, b in ipairs(list) do
        if Fog.biomes[b.id] then
            print(string.format("\n== %s (ato %d) — %d runs × %d anúncios/andar ==", b.id, idx, runs, turns))
            print("andar   densidade | esperado full/type/hidden | medido full/type/hidden")
            local totals = { full = 0, type_only = 0, hidden = 0 }
            local n = 0
            for floor = 1, 8 do
                local nodeType = (floor == 8) and "boss" or "battle"
                local run = { actNumber = idx, floorInAct = floor, currentNode = { type = nodeType } }
                local ctx = IV.contextFor(run)
                local exp = IV.expectedShares(ctx)
                local got = { full = 0, type_only = 0, hidden = 0 }
                local m = 0
                for r = 1, runs do
                    TK.seedRng(720000 + r)
                    local e = Enemy:new(100, 10, "generic")
                    e.fogContext = ctx
                    for _ = 1, turns do
                        e:rollIntent()
                        got[e:getIntentVisibility()] = got[e:getIntentVisibility()] + 1
                        m = m + 1
                    end
                end
                for k, v in pairs(got) do totals[k] = totals[k] + v end
                n = n + m
                print(string.format("%d%-6s  %.2f     | %s %s %s          | %s %s %s",
                    floor, nodeType == "boss" and " hall" or "", IV.density(ctx),
                    pct(exp.full), pct(exp.type_only), pct(exp.hidden),
                    pct(got.full / m), pct(got.type_only / m), pct(got.hidden / m)))
            end
            print(string.format("ato inteiro (medido): full %s | type_only %s | hidden %s",
                pct(totals.full / n), pct(totals.type_only / n), pct(totals.hidden / n)))
        end
    end
    return true
end

return M
