local TK = require("tools.testkit")
local CoinBurst = require("src.ui.CoinBurst")

local M = {}

local function pump(secs)
    local t = 0
    while t < secs do CoinBurst.update(1 / 60); t = t + 1 / 60 end
end

function M.run()
    local t = TK.new("coinburst")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false

    CoinBurst.clear()
    CoinBurst.spawn(4, 400, 20)
    local poucas = CoinBurst.count()
    CoinBurst.clear()
    CoinBurst.spawn(500, 400, 20)
    local muitas = CoinBurst.count()
    t:truthy("ganho pequeno gera moedas", poucas >= 3)
    t:truthy("ganho grande gera mais", muitas > poucas)
    t:truthy("mas satura (nunca vira festa)", muitas <= 12)

    CoinBurst.clear()
    CoinBurst.spawn(50, 400, 20)
    t:truthy("nasceram moedas", CoinBurst.count() > 0)
    pump(4.0)
    t:eq("todas as moedas somem em 4s", CoinBurst.count(), 0)

    CoinBurst.clear()
    CoinBurst.spawn(50, -5000, -5000)
    pump(5.0)
    t:eq("moeda com alvo impossivel nao vaza", CoinBurst.count(), 0)

    CoinBurst.clear()
    _G.gameSettings.reducedMotion = true
    CoinBurst.spawn(50, 400, 20)
    t:eq("reducedMotion nao gera moeda", CoinBurst.count(), 0)
    _G.gameSettings.reducedMotion = false

    CoinBurst.clear()
    t:noerror("ganho zero", function() CoinBurst.spawn(0, 400, 20) end)
    t:noerror("ganho negativo (gasto)", function() CoinBurst.spawn(-30, 400, 20) end)
    t:noerror("amount nil", function() CoinBurst.spawn(nil, 400, 20) end)
    t:noerror("alvo nil", function() CoinBurst.spawn(10, nil, nil) end)
    t:eq("nenhuma dessas gerou moeda", CoinBurst.count(), 0)
    t:noerror("update sem moedas", function() CoinBurst.update(0.016) end)
    t:noerror("draw sem moedas", function() CoinBurst.draw() end)

    CoinBurst.clear()
    _G.gameSettings.reducedMotion = false
    CoinBurst.spawn(50, 400, 20)
    pump(1.0)
    local pousadas, movidas = 0, 0
    for _, c in ipairs(CoinBurst._coins()) do
        if c.landed then
            pousadas = pousadas + 1
            local px, py = c.x, c.y
            CoinBurst.update(1 / 60)
            if c.x ~= px or c.y ~= py then movidas = movidas + 1 end
        end
    end
    t:truthy("ha moedas ja pousadas pra checar", pousadas > 0)
    t:eq("moeda pousada NAO se move mais", movidas, 0)

    CoinBurst.clear()
    CoinBurst.spawn(50, 400, 20)
    pump(1.0)
    local fora = 0
    for _, c in ipairs(CoinBurst._coins()) do
        if not c.landed then fora = fora + 1 end
    end
    t:eq("toda moeda chegou ao alvo em 1s", fora, 0)

    return t:done()
end

return M
