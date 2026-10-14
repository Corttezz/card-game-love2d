local TK = require("tools.testkit")

local M = {}

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

    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")

    local game = TK.newRunGame("rogue")
    Autoplay._resetBattleStats()

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

    local ok, err = pcall(Autoplay._playBattle, game, "TESTE-ciclo")
    t:truthy("a batalha roda sem erro (" .. tostring(err) .. ")", ok)

    t:check("o piloto ATACA mesmo com a mao cheia de cartas de ciclo"
        .. " (inimigo " .. tostring(hpInimigoAntes) .. " -> "
        .. tostring(game.enemy.health) .. ")",
        game.enemy.health < hpInimigoAntes)

    return t:done()
end

return M
