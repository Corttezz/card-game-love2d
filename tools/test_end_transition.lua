-- tools/test_end_transition.lua
-- A trava de reentrada da transição de fim de run.
--
-- Reproduz o defeito que o dono viu: "ao morrer no jogo a tela fica preta e
-- não tem como voltar pro menu, só fechando o jogo". O fim de run é disparado
-- por CONDIÇÃO (`checkGameOver()` continua verdadeiro todo frame), e sem trava
-- cada frame reiniciava o desligamento do CRT — o callback que troca o estado
-- nunca chegava ao fim.
--
-- O teste simula o desligamento como o CRTShader faz de verdade: guarda o
-- callback e só o chama quando a duração pedida se esgota. Uma chamada nova
-- SUBSTITUI a anterior e zera o cronômetro — é exatamente esse
-- comportamento que transformava a chamada repetida em travamento.

local TK = require("tools.testkit")
local ET = require("src.ui.EndTransition")

local M = {}

-- CRT falso: acumula tempo e dispara o callback ao completar a duração.
local function novoCrtFalso()
    local crt = { anim = nil, religou = 0 }
    function crt.powerOff(dur, cb)
        crt.anim = { t = 0, dur = dur, cb = cb }   -- substitui, como o real
    end
    function crt.update(dt)
        if not crt.anim then return end
        crt.anim.t = crt.anim.t + dt
        if crt.anim.t >= crt.anim.dur then
            local cb = crt.anim.cb
            crt.anim = nil
            cb()
        end
    end
    return crt
end

function M.run()
    local t = TK.new("end_transition")

    -- ===== O caso do bug: a condição dispara todo frame =====
    ET.clear()
    local crt = novoCrtFalso()
    local estado = "playing"
    local aplicou = 0
    local iniciou = 0

    for _ = 1, 120 do      -- 2 segundos a 60fps, com a morte sempre verdadeira
        if estado == "playing" then
            if ET.start("gameOver", crt.powerOff, function(n)
                estado = n
                aplicou = aplicou + 1
            end) then iniciou = iniciou + 1 end
        end
        crt.update(1 / 60)
    end

    t:eq("so UMA transicao e iniciada, apesar de 120 chamadas", iniciou, 1)
    t:eq("a transicao COMPLETA (era aqui que travava)", aplicou, 1)
    t:eq("o estado chegou em gameOver", estado, "gameOver")
    t:eq("nao ha transicao pendente no fim", ET.pending(), nil)

    -- ===== Sair da tela final libera a proxima run =====
    ET.clear()
    local crt2 = novoCrtFalso()
    local estado2, aplicou2 = "playing", 0
    ET.start("gameOver", crt2.powerOff, function(n) estado2 = n; aplicou2 = aplicou2 + 1 end)
    for _ = 1, 120 do crt2.update(1 / 60) end
    t:eq("1a run terminou", aplicou2, 1)

    ET.clear()                       -- equivale a voltar ao menu
    estado2 = "playing"
    ET.start("gameOver", crt2.powerOff, function(n) estado2 = n; aplicou2 = aplicou2 + 1 end)
    for _ = 1, 120 do crt2.update(1 / 60) end
    t:eq("2a run TAMBEM termina (trava nao fica presa)", aplicou2, 2)
    t:eq("estado da 2a run", estado2, "gameOver")

    -- ===== Vitoria usa o mesmo caminho =====
    ET.clear()
    local crt3 = novoCrtFalso()
    local estado3 = "playing"
    for _ = 1, 120 do
        if estado3 == "playing" then
            ET.start("victory", crt3.powerOff, function(n) estado3 = n end)
        end
        crt3.update(1 / 60)
    end
    t:eq("vitoria tambem completa", estado3, "victory")

    -- ===== CRT desligado nas Settings: corte seco, callback imediato =====
    ET.clear()
    local estado4 = "playing"
    ET.start("gameOver", function(_, cb) cb() end, function(n) estado4 = n end)
    t:eq("com corte seco o estado troca na hora", estado4, "gameOver")
    t:eq("e a trava e liberada", ET.pending(), nil)

    return t:done()
end

return M
