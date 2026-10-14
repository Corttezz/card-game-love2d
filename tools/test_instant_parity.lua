local TK = require("tools.testkit")

local M = {}

local function playTraced(Autoplay, class, seed, maxBattles)
    local EM = require("engine.EventManager")
    EM.clear()
    Autoplay.drainPresentation()
    Autoplay.traceSink = {}
    local realPrint = print
    print = function() end
    local ok, rec = pcall(Autoplay.playRunRecord, class, 1, seed, { maxBattles = maxBattles })
    print = realPrint
    local trace = Autoplay.traceSink
    Autoplay.traceSink = nil
    if not ok then return nil, tostring(rec) end
    trace[#trace + 1] = ("END %s floors=%d hp=%d gold=%d deck=%d"):format(
        tostring(rec.outcome), rec.floors or 0, rec.hpEnd or -1, rec.gold or -1,
        rec.deck and #rec.deck or -1)
    return trace, rec
end

local function firstDiff(a, b)
    for i = 1, math.max(#a, #b) do
        if a[i] ~= b[i] then return i, a[i], b[i] end
    end
    return nil
end

local function body()
    local t = TK.new("relogio instantaneo: paridade com o relogio de quadros")
    TK.bootstrap()
    local BS = require("tools.balance_sim")
    local Autoplay = BS.setup("average")
    local Instant = require("tools.instant_engine")
    local CombatBeats = require("src.systems.CombatBeats")
    local savedSpeed, savedDt = CombatBeats.speed, Autoplay.pumpDt
    CombatBeats.speed = 1.0
    Autoplay.pumpDt = nil

    local maxBattles = tonumber(os.getenv("PARITY_BATTLES") or "5") or 5
    local nSeeds = tonumber(os.getenv("PARITY_SEEDS") or "1") or 1
    local classes = { "warrior", "mage", "rogue" }

    local tFrames, tInstant = 0, 0
    for _, class in ipairs(classes) do
        for k = 1, nSeeds do
            local seed = 880000 + k * 101 + ({ warrior = 1, mage = 2, rogue = 3 })[class]
            Instant.uninstall(Autoplay)
            local t0 = os.clock()
            local a, errA = playTraced(Autoplay, class, seed, maxBattles)
            tFrames = tFrames + (os.clock() - t0)
            Instant.install(Autoplay)
            t0 = os.clock()
            local b, errB = playTraced(Autoplay, class, seed, maxBattles)
            tInstant = tInstant + (os.clock() - t0)
            local label = ("%s seed %d"):format(class, seed)
            t:truthy(label .. ": relogio de quadros jogou (" .. tostring(errA) .. ")", a ~= nil)
            t:truthy(label .. ": relogio instantaneo jogou (" .. tostring(errB) .. ")", b ~= nil)
            if a and b then
                t:check(label .. ": turnos jogados (" .. #a .. ")", #a >= 3)
                local i, la, lb = firstDiff(a, b)
                if i then
                    print("  primeira divergencia, linha " .. i)
                    print("    quadros : " .. tostring(la))
                    print("    instante: " .. tostring(lb))
                end
                t:check(label .. ": traco identico em " .. #a .. " turnos", i == nil)
                local c = playTraced(Autoplay, class, seed, maxBattles)
                local j = c and firstDiff(b, c)
                t:check(label .. ": mesma seed duas vezes = mesmo jogo", c ~= nil and j == nil)
            end
        end
    end

    do
        Instant.install(Autoplay)
        local a = playTraced(Autoplay, "warrior", 880001 + 7, maxBattles)
        local b = playTraced(Autoplay, "warrior", 880001 + 7919, maxBattles)
        t:check("seeds diferentes = jogos diferentes", a and b and firstDiff(a, b) ~= nil)
    end

    print(("  tempo: quadros %.2fs x instantaneo %.2fs (x%.1f)"):format(
        tFrames, tInstant, tFrames / math.max(1e-6, tInstant)))
    if tInstant > tFrames then
        print(("  AVISO: instantaneo %.2fs > quadros %.2fs nesta rodada (carga da maquina?)")
            :format(tInstant, tFrames))
    end
    t:eq("nenhum dreno estourou o teto de saltos", Instant.stats.stalls, 0)

    Instant.uninstall(Autoplay)
    CombatBeats.speed, Autoplay.pumpDt = savedSpeed, savedDt
    return t:done()
end

function M.run()
    local ok, res = pcall(body)
    require("tools.balance_sim").teardown()
    if not ok then error(res, 0) end
    return res
end

return M
