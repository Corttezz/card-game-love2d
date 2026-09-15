-- tools/test_autoplay_pilot.lua
-- Trava da POLITICA DE TURNO do piloto de IA (tools/autoplay.lua).
--
-- Por que este teste existe
-- -------------------------
-- O autoplay e o INSTRUMENTO de medicao de balanco: winrate, profundidade,
-- dano/turno por ato, causa das mortes. Instrumento quebrado nao produz um
-- numero ruim — produz um numero CONVINCENTE e errado, e foi o que aconteceu.
--
-- O defeito (Set/2026): a fase MOTOR (cartas de compra/mana jogadas sozinhas)
-- e a fase BATCH (o conjunto que ataca e defende) dividiam UM orcamento de 6
-- "levas". O motor rodava primeiro. Uma carta que se paga em mana — Sosia
-- (custa 1, compra 2, devolve 1) — num deck pequeno reaparece na mao a cada
-- reembaralhamento, entao o motor a rejogava ate estourar as 6 levas e a fase
-- BATCH nunca acontecia. O bot passava a batalha INTEIRA ciclando cartas sem
-- atacar nem defender, e morria com 0 de dano causado.
--
-- O guard de nao-progresso nao pegava isso, e com razao: a mao CRESCE a cada
-- Sosia. Progride — so nao progride na direcao de ganhar.
--
-- Custo real medido: numa bateria de 8 corridas de ladino com seed fixa, a
-- corrida #3 morreu em A1-F5 com score 64 enquanto as vizinhas faziam ~12.000.
-- E como o ladino e a classe com mais cartas de ciclo, o vies caia sempre na
-- mesma classe — a que se estava tentando avaliar.
--
-- O que este teste checa, e como ele falha com o defeito presente
-- ---------------------------------------------------------------
-- Monta a batalha patologica de proposito (mao e deck so de ciclo + UM
-- ataque), conduz UM turno pelo cerebro real do piloto e exige que o inimigo
-- tenha PERDIDO VIDA. Com o orcamento unico restaurado (MOTOR_MAX_LEVAS
-- removido), o inimigo termina o turno com a vida intacta e o teste fica
-- vermelho. Verificado revertendo a correcao antes de commitar.

local TK = require("tools.testkit")

local M = {}

-- Carta de ciclo que se auto-sustenta: custa 1 de mana e devolve 1, comprando
-- 2. E o formato exato que travava o motor.
local function cicloCard()
    local CardDatabase = require("src.systems.CardDatabase")
    return CardDatabase:createCardInstance(CardDatabase:getCard("rogue_doppelganger"))
end

local function ataqueCard()
    local CardDatabase = require("src.systems.CardDatabase")
    return CardDatabase:createCardInstance(CardDatabase:getCard("rogue_strike"))
end

function M.run()
    local t = TK.new("autoplay: politica de turno do piloto")

    local Autoplay = require("tools.autoplay")
    t:truthy("autoplay expoe superficie de teste (_playBattle)",
        type(Autoplay._playBattle) == "function")
    if type(Autoplay._playBattle) ~= "function" then return t:done() end

    -- O piloto usa _G.EventManager/_G.Event (CombatSequence depende deles).
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")

    local game = TK.newRunGame("rogue")
    Autoplay._resetBattleStats()

    -- Cenario patologico: mao cheia de ciclo + 1 ataque; deck so de ciclo,
    -- pra que o reembaralhamento devolva ciclo pra sempre. Inimigo com vida
    -- alta o bastante pra sobreviver ao turno (queremos medir SE atacou, nao
    -- se matou) e sem dano, pra que a batalha nao acabe por morte do jogador
    -- antes de a politica de turno ser exercida.
    game.hand = { cicloCard(), cicloCard(), ataqueCard() }
    game.deck = { cicloCard(), cicloCard(), cicloCard(), cicloCard() }
    game.discard = {}
    game.selectedCards = {}
    game.turn = "player"

    local Enemy = require("src.entities.Enemy")
    game.enemy = Enemy:new(400, 0)
    game.enemy.nextIntentDamage = 0
    local hpInimigoAntes = game.enemy.health

    game.player.health = game.player.maxHealth
    game.player:restoreMana()

    -- Uma batalha inteira: com o defeito ela termina sem um unico ponto de
    -- dano; sem o defeito o ataque sai ja no primeiro turno.
    local ok, err = pcall(Autoplay._playBattle, game, "TESTE-ciclo")
    t:truthy("a batalha roda sem erro (" .. tostring(err) .. ")", ok)

    t:check("o piloto ATACA mesmo com a mao cheia de cartas de ciclo"
        .. " (inimigo " .. tostring(hpInimigoAntes) .. " -> "
        .. tostring(game.enemy.health) .. ")",
        game.enemy.health < hpInimigoAntes)

    return t:done()
end

return M
