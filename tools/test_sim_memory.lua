local TK = require("tools.testkit")

local M = {}

local function heapKB()
    collectgarbage("collect"); collectgarbage("collect")
    return collectgarbage("count")
end

function M.run()
    local t = TK.new("piloto: memoria estavel entre batalhas simuladas")
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local EM = _G.EventManager
    local Autoplay = require("tools.autoplay")
    t:truthy("autoplay expoe evalDeckSim + drainPresentation",
        type(Autoplay.evalDeckSim) == "function" and type(Autoplay.drainPresentation) == "function")
    if type(Autoplay.evalDeckSim) ~= "function" then return t:done() end

    local realPrint = print
    local game = TK.newRunGame("mage")
    TK.pump(game, 0.5)
    Autoplay._resetBattleStats()

    EM.queues = { base = {}, ui = {} }
    local runQueues = EM.queues
    EM.after(999, function() end)
    local before = EM.pendingCount()

    local function evalOnce()
        local ok, err = pcall(Autoplay.evalDeckSim, game, nil)
        print = realPrint
        return ok, err
    end

    local ok, err = evalOnce()
    t:truthy("evalDeckSim roda (" .. tostring(err) .. ")", ok)
    t:truthy("fila da run volta a ser a MESMA tabela", EM.queues == runQueues)
    t:eq("fila da run volta com o mesmo tamanho (replays isolados)", EM.pendingCount(), before)

    local h1 = heapKB()
    for _ = 1, 3 do evalOnce() end
    local h2 = heapKB()
    t:truthy(("heap estavel entre rodadas de replay (%.0f KB -> %.0f KB)"):format(h1, h2),
        h2 - h1 < 8 * 1024)
    t:eq("fila da run intacta apos varias rodadas", EM.pendingCount(), before)

    Autoplay.drainPresentation()
    t:eq("FloatingText vazio", require("src.ui.FloatingText").count(), 0)
    t:eq("particulas vazias", require("engine.ParticlesManager").activeCount(), 0)
    t:falsy("ComboBanner sem faixa ativa", require("src.ui.ComboBanner").isActive())

    EM.clear()
    return t:done()
end

return M
