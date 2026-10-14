local TK = require("tools.testkit")

local M = {}

local function pool(g)
    return #g.hand + #g.deck + #g.discard + #(g._exhaustedThisBattle or {})
end

local function dump(g, label)
    print(("[%s] hand=%d deck=%d discard=%d exhausted=%d POOL=%d")
        :format(label, #g.hand, #g.deck, #g.discard,
            #(g._exhaustedThisBattle or {}), pool(g)))
    local names = {}
    for _, c in ipairs(g.hand) do names[#names + 1] = c.id end
    print("  hand: " .. table.concat(names, ", "))
    print("  exhausted: " .. table.concat(g._exhaustedThisBattle or {}, ", "))
end

local function body()
    TK.seedRng(42)
    local g = TK.newRunGame("rogue")

    g:addCardToRun("rogue_backstab")
    g:addCardToRun("rogue_backstab")
    g:startGame()
    TK.pump(g, 1)

    local guard = 0
    local function inHand()
        local n = 0
        for _, c in ipairs(g.hand) do
            if c.id == "rogue_backstab" then n = n + 1 end
        end
        return n
    end
    while inHand() < 2 and guard < 10 do
        g:drawCard()
        guard = guard + 1
    end
    if inHand() < 2 then
        print("FALHA DE SETUP: nao consegui 2 backstabs na mao")
        return false
    end

    local before = pool(g)
    dump(g, "antes")

    g.enemy.health = 5

    for _, c in ipairs(g.hand) do
        if c.id == "rogue_backstab" then g:selectCard(c) end
    end
    print("selecionadas: " .. #g.selectedCards)

    g:playSelectedCards()
    local n = 0
    while g.combatAnimationSystem:isBlocking() and n < 900 do
        TK.pump(g, 1 / 30)
        n = n + 1
    end

    local after = pool(g)
    dump(g, "depois")

    if after ~= before then
        print(("REPRODUZIU: pool %d -> %d"):format(before, after))
        return false
    end
    print("pool integro — nao reproduziu")
    return true
end

function M.run()
    local ok, result = pcall(body)
    if not ok then
        print("ERRO no repro: " .. tostring(result))
        return false
    end
    return result
end

return M
