-- tools/test_coinburst.lua
-- As moedas que voam pro contador quando o jogador ganha ouro.
--
-- O que se protege aqui não é a beleza da animação — é que ela EXISTA em todo
-- ganho e que nunca vaze. O componente é global e roda em todos os estados;
-- uma moeda que não converge fica viva para sempre por cima da UI inteira.

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

    -- Ganho pequeno e ganho grande: o número de moedas SATURA.
    CoinBurst.clear()
    CoinBurst.spawn(4, 400, 20)
    local poucas = CoinBurst.count()
    CoinBurst.clear()
    CoinBurst.spawn(500, 400, 20)
    local muitas = CoinBurst.count()
    t:truthy("ganho pequeno gera moedas", poucas >= 3)
    t:truthy("ganho grande gera mais", muitas > poucas)
    t:truthy("mas satura (nunca vira festa)", muitas <= 12)

    -- Convergência: TODA moeda tem que sumir. Este é o teste que importa —
    -- o componente desenha por cima de tudo, em todos os estados.
    CoinBurst.clear()
    CoinBurst.spawn(50, 400, 20)
    t:truthy("nasceram moedas", CoinBurst.count() > 0)
    pump(4.0)
    t:eq("todas as moedas somem em 4s", CoinBurst.count(), 0)

    -- Alvo absurdo (tela minúscula, coordenada fora): ainda assim expira.
    CoinBurst.clear()
    CoinBurst.spawn(50, -5000, -5000)
    pump(5.0)
    t:eq("moeda com alvo impossivel nao vaza", CoinBurst.count(), 0)

    -- reducedMotion tira o MOVIMENTO. A informação (o valor) continua vindo
    -- do FloatingText da TopBar, que não passa por aqui.
    CoinBurst.clear()
    _G.gameSettings.reducedMotion = true
    CoinBurst.spawn(50, 400, 20)
    t:eq("reducedMotion nao gera moeda", CoinBurst.count(), 0)
    _G.gameSettings.reducedMotion = false

    -- Entradas ruins não podem estourar: isto roda no funil de ouro, que é
    -- chamado a cada frame em que o saldo muda.
    CoinBurst.clear()
    t:noerror("ganho zero", function() CoinBurst.spawn(0, 400, 20) end)
    t:noerror("ganho negativo (gasto)", function() CoinBurst.spawn(-30, 400, 20) end)
    t:noerror("amount nil", function() CoinBurst.spawn(nil, 400, 20) end)
    t:noerror("alvo nil", function() CoinBurst.spawn(10, nil, nil) end)
    t:eq("nenhuma dessas gerou moeda", CoinBurst.count(), 0)
    t:noerror("update sem moedas", function() CoinBurst.update(0.016) end)
    t:noerror("draw sem moedas", function() CoinBurst.draw() end)

    -- REGRESSAO (Set/2026): a moeda que CHEGOU nao pode continuar se mexendo.
    -- A primeira versao era fisica livre e so iniciava o fade na chegada: a
    -- moeda seguia sendo integrada, passava do contador, era puxada de volta e
    -- ORBITAVA ate sumir. O dono viu e descreveu como "umas particulas de
    -- moeda ficam meio que rodando e caindo". Fade nao encerra movimento.
    CoinBurst.clear()
    _G.gameSettings.reducedMotion = false
    CoinBurst.spawn(50, 400, 20)
    -- deixa todas chegarem (voo 0,55s + stagger)
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

    -- E toda moeda chega ao contador: nenhuma pode expirar no meio do caminho.
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
