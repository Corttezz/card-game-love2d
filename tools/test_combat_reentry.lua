local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("combat_reentry")

    local game = TK.newRunGame("warrior")
    local mao = game.hand or game.player and game.player.hand
    t:truthy("ha cartas na mao pra testar", mao and #mao >= 2)

    local alvo = mao[1]
    t:truthy("seleciona normalmente ANTES do combate", game:selectCard(alvo) ~= false)
    t:eq("uma carta selecionada", #game.selectedCards, 1)

    game:playSelectedCards()

    local seq = game.combatAnimationSystem
    t:truthy("a sequencia esta ativa", seq and seq.active == true)

    local antes = #game.selectedCards
    local manaAntes = game.player.mana
    local outra = mao[2] or mao[1]
    t:eq("selectCard e RECUSADO durante a resolucao", game:selectCard(outra), false)
    t:eq("a lista de selecionadas nao mudou", #game.selectedCards, antes)
    t:eq("e a mana nao foi mexida", game.player.mana, manaAntes)

    t:noerror("o combate resolve ate o fim", function() TK.pump(game, 12) end)

    local CombatSequence = require("src.systems.CombatSequence")
    local seq2 = CombatSequence:new()
    local viva = {}
    for i = 1, 2 do
        viva[i] = { type = "attack", cost = 1, name = "fake" .. i, currentScale = 1 }
    end

    local resolvidas, terminou = 0, false
    t:noerror("startCombat com lista viva", function()
        seq2:startCombat(viva,
            function() terminou = true end,
            function(card)
                resolvidas = resolvidas + 1
                table.insert(viva, { type = "attack", cost = 1, name = "intrusa",
                                     currentScale = 1 })
                return {}
            end)
    end)

    t:noerror("bombear ate o fim nao estoura", function()
        for _ = 1, 900 do _G.EventManager.update(1 / 60) end
    end)
    t:eq("resolveu exatamente as 2 cartas originais", resolvidas, 2)
    t:truthy("e a sequencia terminou", terminou)

    return t:done()
end

return M
