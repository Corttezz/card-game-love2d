local Game = require("src.core.Game")

local M = {}

local function makeCard(id, type_, exhaust)
    return { id = id, type = type_ or "attack", name = id, attack = 1, defense = 1,
             effects = {}, exhaust = exhaust }
end

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- Discard pile smoke test ----")

    local g = Game:new()
    g.deck = { makeCard("a"), makeCard("b") }
    g.hand = {}
    g.discard = {}
    g:drawCard()
    g:drawCard()
    check("drawCard 2x esvazia deck", #g.deck == 0)
    check("drawCard 2x enche a mao", #g.hand == 2)
    check("discard permanece vazio", #g.discard == 0)

    local handBefore = #g.hand
    g:drawCard()
    check("drawCard com tudo vazio e no-op", #g.hand == handBefore)

    local g2 = Game:new()
    g2.deck = {}
    g2.hand = {}
    g2.discard = { makeCard("x"), makeCard("y"), makeCard("z") }
    g2:drawCard()
    check("drawCard com deck vazio + discard=3 reembaralha e puxa 1",
        #g2.hand == 1 and #g2.discard == 0)
    check("deck fica com 2 apos reshuffle+draw", #g2.deck == 2)

    local g3 = Game:new()
    g3.deck = {}
    g3.hand = {}
    g3.discard = {}
    g3.selectedCards = {}
    g3._exhaustedThisBattle = {}
    g3.jokerSlots = {}
    local exhaustCard = makeCard("ex", "attack", true)
    g3:processCardInCombat(exhaustCard, nil)
    check("exhaust nao entra no discard", #g3.discard == 0)
    check("exhaust registrado em _exhaustedThisBattle",
        #g3._exhaustedThisBattle == 1 and g3._exhaustedThisBattle[1] == "ex")

    local g4 = Game:new()
    g4.deck = {}
    g4.hand = {}
    g4.discard = {}
    g4.selectedCards = {}
    g4.jokerSlots = {}
    g4._exhaustedThisBattle = {}
    local normalCard = makeCard("n", "attack", false)
    g4:processCardInCombat(normalCard, nil)
    check("attack normal vai pro discard",
        #g4.discard == 1 and g4.discard[1].id == "n")

    local g5 = Game:new()
    g5.deck = {}
    g5.hand = {}
    g5.discard = {}
    g5.selectedCards = {}
    g5.jokerSlots = {}
    g5._exhaustedThisBattle = {}
    local jokerCard = makeCard("j", "joker", false)
    jokerCard.passive = function() end
    g5:processCardInCombat(jokerCard, nil)
    check("joker NAO vai pro discard", #g5.discard == 0)

    local g6 = Game:new()
    g6.isRunMode = false
    g6.hand = { makeCard("a") }
    g6.discard = { makeCard("b"), makeCard("c") }
    g6.deck = { makeCard("d") }
    g6.selectedCards = {}
    g6:resetHandAndDeck()
    check("resetHandAndDeck zera discard", #g6.discard == 0)

    local Config = require("src.core.Config")
    local perTurn = Config.Game.CARDS_PER_TURN or 5
    local g7 = Game:new()
    g7.hand = {}
    g7.deck = { makeCard("a"), makeCard("b"), makeCard("c"), makeCard("d"),
                makeCard("e"), makeCard("f") }
    g7.discard = {}
    g7:drawForTurn()
    check("drawForTurn compra CARDS_PER_TURN (" .. perTurn .. ")",
        #g7.hand == perTurn)

    local g8 = Game:new()
    g8.hand = { makeCard("x") }
    g8.deck = { makeCard("a"), makeCard("b"), makeCard("c"), makeCard("d"),
                makeCard("e"), makeCard("f") }
    g8.discard = {}
    g8:drawForTurn()
    check("drawForTurn com retain na mao = retain + " .. perTurn,
        #g8.hand == 1 + perTurn)

    local g9 = Game:new()
    g9.hand = {}
    g9.deck = { makeCard("a"), makeCard("b") }
    g9.discard = {}
    g9:drawForTurn()
    check("drawForTurn com deck=2 limita a 2", #g9.hand == 2)

    local g10 = Game:new()
    g10.hand = {}
    g10.deck = {}
    g10.discard = { makeCard("a"), makeCard("b"), makeCard("c"), makeCard("d"),
                    makeCard("e"), makeCard("f") }
    g10:drawForTurn()
    check("drawForTurn reembaralha discard e puxa " .. perTurn,
        #g10.hand == perTurn and #g10.discard == 0)

    local g11 = Game:new()
    local keep = makeCard("keep"); keep.retain = true
    g11.hand = { makeCard("a"), keep, makeCard("b") }
    g11.discard = {}
    g11:discardHandEndOfTurn()
    check("discardHandEndOfTurn descarta nao-retain",
        #g11.hand == 1 and g11.hand[1].id == "keep" and #g11.discard == 2)

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
