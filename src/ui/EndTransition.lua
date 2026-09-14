-- src/ui/EndTransition.lua
-- A transição de FIM DE RUN (morte / vitória): desliga a TV, troca de tela,
-- religa. Com uma TRAVA DE REENTRADA, que é a razão deste módulo existir.
--
-- O BUG QUE ISTO MATA (Set/2026, relatado pelo dono: "ao morrer no jogo a tela
-- fica preta e não tem como voltar pro menu, só fechando o jogo"):
--
-- O fim de run é disparado por uma CONDIÇÃO, não por um evento.
-- `GameplayScene.update` chama a transição sempre que `game:checkGameOver()`
-- é verdadeiro — e morte não deixa de ser verdadeira no frame seguinte. Cada
-- chamada substituía o `powerAnim` do CRTShader por um novo, com o cronômetro
-- zerado. A 60 fps isso reiniciava o desligamento 60 vezes por segundo: o
-- callback que troca `currentState` nunca chegava ao fim, a TV ficava
-- desligada para sempre e nenhuma tecla respondia, porque o estado continuava
-- sendo "playing".
--
-- A lição geral, que vale para qualquer efeito com callback no projeto:
-- **animação disparada por condição precisa de trava; animação disparada por
-- evento não.** Quem dispara todo frame tem que perguntar "já estou fazendo
-- isso?" antes de começar de novo.
--
-- Mora num módulo (e não inline no main.lua) porque o guard precisava ser
-- TESTÁVEL — dentro do closure de `love.load` nenhum teste o alcança, e foi
-- justamente um caminho sem teste que deixou o defeito chegar ao dono.

local EndTransition = {}

-- Destino da transição em curso, ou nil quando não há nenhuma.
local pendingTo = nil

-- start(name, fadeOut, apply)
--   name    : "gameOver" | "victory"
--   fadeOut : função(duração, callback) — normalmente CRTShader.powerOff
--   apply   : função(name) — troca o estado e religa a TV
-- Devolve true se ESTA chamada iniciou a transição; false se foi ignorada por
-- já haver uma em curso.
function EndTransition.start(name, fadeOut, apply)
    if pendingTo then return false end
    pendingTo = name
    fadeOut(0.9, function()
        pendingTo = nil
        apply(name)
    end)
    return true
end

-- Sair de gameOver/victory (voltar ao menu, recomeçar) limpa a transição.
-- Sem isto, uma transição que ficasse de pé travaria a PRÓXIMA morte — o
-- mesmo sintoma, uma run depois, e muito mais difícil de relacionar à causa.
function EndTransition.clear() pendingTo = nil end

function EndTransition.pending() return pendingTo end

return EndTransition
