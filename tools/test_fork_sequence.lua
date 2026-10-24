local TK = require("tools.testkit")

local M = {}

M.CASES = {
    { act = 5, types = { "battle", "rest", "shop" }, pick = 1 },
    { act = 5, types = { "battle", "rest", "shop" }, pick = 3 },
    { act = 6, types = { "battle", "rest", "shop" }, pick = 2 },
    { act = 1, types = { "shop", "battle" }, pick = 2 },
}

function M.run()
    local t = TK.new("encruzilhada em sequencia: nada aparece, some, salta ou troca de lugar quadro a quadro")
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local Seq = require("tools.estrada_seq")
    local ok, err = pcall(function()
        for _, c in ipairs(M.CASES) do
            local log = Seq.capture(c.act, c.types, c.pick, { w = 1920, h = 1080 })
            local flags = Seq.analyze(log)
            local tag = ("ato %d, %d opções, escolhe %d (%s)"):format(c.act, #c.types, c.pick, c.types[c.pick])
            t:check(("%s: sequência roda (%d quadros) %s"):format(tag, log.n or 0, tostring(log.err or "")),
                log.ok and (log.n or 0) > 200)
            local first = flags[1]
            t:check(("%s: 0 saltos/estalos (%d: %s)"):format(tag, #flags, Seq.summary(flags)
                .. (first and string.format(" | f%d %s %s %s", first.f, first.kind, first.what, first.info or "") or "")),
                #flags == 0)
            collectgarbage()
        end
    end)
    t:truthy("execução sem erro: " .. tostring(err), ok)
    require("src.ui.WorldRoad").resetRun()
    return t:done()
end

return M
