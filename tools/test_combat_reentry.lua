-- tools/test_combat_reentry.lua
-- Mexer na MÃO enquanto as cartas resolvem.
--
-- O defeito (Set/2026, crash na cara do dono no meio de um turno):
--
--     src/systems/CombatSequence.lua:170: attempt to index local 'g' (a nil value)
--
-- `Game:playSelectedCards` passava `self.selectedCards` — a tabela VIVA — para
-- o CombatSequence, que monta a geometria UMA vez e depois percorre a lista
-- carta a carta. Enquanto isso `Game:selectCard` continuava aceitando cliques
-- e fazendo `table.insert`/`table.remove` NA MESMA TABELA.
--
-- Antes do ritmo por beats a resolução durava fração de segundo e ninguém
-- conseguia clicar no meio. Com cada acontecimento ocupando seu instante ela
-- passou a durar SEGUNDOS, e a janela virou o tamanho de um turno inteiro:
-- era só clicar numa carta da mão.
--
-- Dois estragos, e o silencioso é o pior:
--   - SELECIONAR: a carta nova existe em `cards[idx]` e não em `geom[idx]` —
--     crash, combate morto no meio do turno.
--   - DESSELECIONAR: nada quebra. A mana de uma carta que já está sendo
--     jogada volta pro jogador, e os índices desalinham.

local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("combat_reentry")

    -- ===== A mão trava durante a resolução =====
    local game = TK.newRunGame("warrior")
    local mao = game.hand or game.player and game.player.hand
    t:truthy("ha cartas na mao pra testar", mao and #mao >= 2)

    local alvo = mao[1]
    t:truthy("seleciona normalmente ANTES do combate", game:selectCard(alvo) ~= false)
    t:eq("uma carta selecionada", #game.selectedCards, 1)

    game:playSelectedCards()

    local seq = game.combatAnimationSystem
    t:truthy("a sequencia esta ativa", seq and seq.active == true)

    -- AQUI era o crash: clicar numa carta da mao no meio da resolucao.
    local antes = #game.selectedCards
    local manaAntes = game.player.mana
    local outra = mao[2] or mao[1]
    t:eq("selectCard e RECUSADO durante a resolucao", game:selectCard(outra), false)
    t:eq("a lista de selecionadas nao mudou", #game.selectedCards, antes)
    t:eq("e a mana nao foi mexida", game.player.mana, manaAntes)

    -- E o turno inteiro roda ate o fim sem estourar.
    t:noerror("o combate resolve ate o fim", function() TK.pump(game, 12) end)

    -- ===== A sequencia sobrevive a lista mutando por fora =====
    -- Mesmo que alguem contorne o guard (outro call site, um teste, um mod), a
    -- CombatSequence tem que aguentar: ela copia a lista na entrada.
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
                -- O sabotador: a lista CRESCE no meio da resolucao.
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
