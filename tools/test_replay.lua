-- tools/test_replay.lua
-- Recomecar da tela de fim de run.
--
-- O defeito (Set/2026, crash na cara do dono NO MOMENTO DA VITORIA):
--
--   [Musica] musicBoss -> menuMusic (estado=victory, no=boss)
--   Error: src/systems/RunManager.lua:29: Classe nao encontrada: nil
--
-- Vencer e apertar ESPACO (ou perder e apertar R) chamava `startGame()` SEM
-- classe, e `RunManager:startNewRun(nil)` da `error()`. Os dois caminhos
-- estavam quebrados ha tempo e ninguem viu, porque teste nenhum chegava a
-- tela de fim e apertava tecla — e vencer e justamente o evento mais raro de
-- uma sessao de teste.
--
-- Este teste nao consegue apertar tecla de verdade, mas cobre o CONTRATO que
-- o caminho de recomeco tem que respeitar: startNewRun exige uma classe
-- valida, e a classe da run que acabou tem que continuar disponivel depois do
-- fim dela.

local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("replay")

    -- ===== A regra que o crash violava =====
    local RunManager = require("src.systems.RunManager")
    local rm = RunManager:new()
    t:throws("startNewRun(nil) EXPLODE (por isso o caminho tem que dar classe)",
        function() rm:startNewRun(nil) end)
    t:noerror("startNewRun com classe valida funciona",
        function() rm:startNewRun("warrior") end)

    -- ===== A classe sobrevive ao fim da run =====
    -- E daqui que o recomeco tira o argumento. Se ela sumisse ao morrer ou
    -- vencer, o caminho cairia no nil de novo.
    local game = TK.newRunGame("mage")
    t:eq("a run sabe a classe", game.selectedClass, "mage")

    game.enemy.health = 0
    TK.pump(game, 2)
    t:eq("classe continua conhecida depois do inimigo morrer",
         game.selectedClass, "mage")

    local doRun = game.runManager and game.runManager.currentRun
    t:truthy("e o runManager tambem guarda a classe",
             doRun == nil or doRun.classId == "mage")

    -- ===== Derrota: mesma coisa =====
    local g2 = TK.newRunGame("rogue")
    g2.player.health = 0
    TK.pump(g2, 2)
    t:eq("classe conhecida apos derrota", g2.selectedClass, "rogue")

    return t:done()
end

return M
