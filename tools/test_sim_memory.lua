-- tools/test_sim_memory.lua
-- Trava de MEMORIA do piloto de balanceamento (tools/autoplay.lua).
--
-- O defeito (Out/2026): `love . balance_sim 30 mage` crescia sem parar — 1,4 GB
-- em 5 min, 9 GB e travado na run 17 — enquanto a mesma seed num processo novo
-- terminava em 22 s. O heap Lua, medido apos collect completo por run, ia de
-- 3 MB a 191 MB na 1a run e 525 MB na 2a. Duas causas, ambas do SIMULADOR:
--   1. Singletons de APRESENTACAO (FloatingText, ParticlesManager, ComboBanner,
--      OrbRow, CoinBurst) so esvaziam no update deles, que o love.update/HUD
--      chama todo frame — e o piloto nunca chama. ~110 mil particulas por run
--      ficavam presas, cada uma segurando a carta (e por ela o Game) a que
--      estava atada.
--   2. Cada replay da simulacao de deck (evalDeckSim) monta um Game descartavel
--      que deixa eventos BLOQUEANTES na fila global do EventManager; eles se
--      acumulavam e rodavam por cima da run real.
-- O jogo em si ficou limpo: com o piloto corrigido o heap fica em ~6 MB e a
-- memoria de textura em ~52 MB por 4 runs seguidas (tools/leak_probe.lua).
--
-- Como falha com o defeito presente: sem o dreno, as contagens dos singletons
-- passam de zero depois das batalhas; sem o isolamento, a fila da run nao volta
-- a ser a mesma tabela/tamanho; o heap cresce dezenas de MB entre as rodadas.

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

    -- fila da run com um marcador: tem que sobreviver intacta aos replays
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

    -- singletons de apresentacao: o dreno do piloto zera todos
    Autoplay.drainPresentation()
    t:eq("FloatingText vazio", require("src.ui.FloatingText").count(), 0)
    t:eq("particulas vazias", require("engine.ParticlesManager").activeCount(), 0)
    t:falsy("ComboBanner sem faixa ativa", require("src.ui.ComboBanner").isActive())

    EM.clear()
    return t:done()
end

return M
