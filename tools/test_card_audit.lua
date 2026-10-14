local TK = require("tools.testkit")
local Audit = require("tools.audit_cards")

local M = {}

function M.run()
    local t = TK.new("auditoria carta a carta (comportamento x dados x descricao)")
    local ok, res = xpcall(Audit.collect, debug.traceback)
    if not t:check("auditoria roda sem crash" .. (ok and "" or (": " .. tostring(res))), ok) then
        return t:done()
    end

    t:check(("mediu >= 100 cartas nao-joker (mediu %d)"):format(res.counted.cards),
        res.counted.cards >= 100)
    t:check(("mediu >= 25 jokers (mediu %d)"):format(res.counted.jokers),
        res.counted.jokers >= 25)
    t:check(("mediu cartas forjadas (%d medicoes)"):format(res.counted.forged),
        res.counted.forged >= 100)
    t:check(("mediu ataque/defesa com Forca/Destreza (%d)"):format(res.counted.withStats or 0),
        (res.counted.withStats or 0) >= 50)

    for _, s in ipairs(res.behavior) do t:check("FAZ o que os dados dizem: " .. s, false) end
    t:eq("divergencias comportamento x dados", #res.behavior, 0)
    for _, s in ipairs(res.desc) do t:check("DIZ o que faz: " .. s, false) end
    t:eq("divergencias descricao x dados", #res.desc, 0)
    return t:done()
end

return M
