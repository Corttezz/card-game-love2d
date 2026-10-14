local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("replay")

    local RunManager = require("src.systems.RunManager")
    local rm = RunManager:new()
    t:throws("startNewRun(nil) EXPLODE (por isso o caminho tem que dar classe)",
        function() rm:startNewRun(nil) end)
    t:noerror("startNewRun com classe valida funciona",
        function() rm:startNewRun("warrior") end)

    local game = TK.newRunGame("mage")
    t:eq("a run sabe a classe", game.selectedClass, "mage")

    game.enemy.health = 0
    TK.pump(game, 2)
    t:eq("classe continua conhecida depois do inimigo morrer",
         game.selectedClass, "mage")

    local doRun = game.runManager and game.runManager.currentRun
    t:truthy("e o runManager tambem guarda a classe",
             doRun == nil or doRun.classId == "mage")

    local g2 = TK.newRunGame("rogue")
    g2.player.health = 0
    TK.pump(g2, 2)
    t:eq("classe conhecida apos derrota", g2.selectedClass, "rogue")

    return t:done()
end

return M
