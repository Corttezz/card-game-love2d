local M = {}

M.W, M.H = 960, 540

function M.run(arg)
    io.stdout:setvbuf("line")
    local P = require("tools.props_inimigo")
    local TK = require("tools.testkit")
    local t = TK.new("test_enemy_props")
    local act = tonumber(arg or "")
    local list = P.propBearers(act)
    t:truthy("ha inimigos com prop", #list > 0)
    for _, cr in ipairs(list) do
        local pick = (cr.act % 2 == 0) and "shop" or "battle"
        local log = P.capture(cr.act, cr, P.nextFor(cr.act, cr.id), { w = M.W, h = M.H, pick = pick, forkTypes = { "battle", "shop" } })
        local tag = string.format("ato%d %s (%s)", cr.act, cr.id, pick)
        t:truthy(tag .. ": captura sem erro " .. tostring(log.err), log.ok)
        if log.mustAttach then
            t:truthy(tag .. ": corpo e prop medidos juntos", log.attached > 0)
        end
        t:truthy(string.format("%s: prop preso ao chao do inimigo (desvio %.2f arte-px <= %.1f)", tag, log.maxOff, P.TOL_ART),
            log.maxOff <= P.TOL_ART)
        t:truthy(tag .. ": prop nunca passa da crista nem da estrada (" .. log.crestHits .. "/" .. log.roadHits .. ")",
            log.crestHits == 0 and log.roadHits == 0)
        t:truthy(tag .. ": prop antigo nunca fica parado na tela com a camera andando (" .. log.oldStill .. ")", log.oldStill == 0)
        if pick == "battle" then
            t:truthy(tag .. ": nenhum prop antigo sobra depois da caminhada (" .. log.oldLeft .. ")", log.oldLeft == 0)
        end
        log = nil
        collectgarbage("collect")
    end
    return t:done()
end

return M
