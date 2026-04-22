-- tools/smoke_combos.lua
-- Smoke test da Fase 3: ComboSystem — deteccao, aplicacao em valor, once-effects.
-- Roda via: love . smoke_combos

local TagSystem = require("src.systems.TagSystem")
local ComboSystem = require("src.systems.ComboSystem")
local Player = require("src.entities.Player")
local Enemy = require("src.entities.Enemy")

local M = {}

-- Mock de turnContext, imita o construido por Game:playSelectedCards.
local function makeContext(cards)
    return {
        allSelectedCards = cards,
        tagCounts = TagSystem.countAllTags(cards),
        cardsProcessed = {},
        activeCombos = {},
    }
end

local function makeGame()
    local g = { player = Player:new(), enemy = Enemy:new(100, 5), messages = {} }
    function g:addMessage(text, level) table.insert(self.messages, { text = text, level = level }) end
    return g
end

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- Fase 3 combos smoke test ----")

    -- 1. strike_combo: 2 ataques disparam damage_multiplier 1.4
    local ctx1 = makeContext({
        { type = "attack" },
        { type = "attack" },
    })
    ComboSystem.detect(ctx1)
    check("strike_combo dispara com 2 ataques", #ctx1.activeCombos >= 1)
    local card = { type = "attack" }
    local dmg = ComboSystem.applyToCardValue(card, 10, ctx1)
    check("strike_combo multiplica 10 -> 14", dmg == 14)

    -- 2. triple_strike: 3+ ataques acumula 1.4x e +6
    local ctx2 = makeContext({
        { type = "attack" },
        { type = "attack" },
        { type = "attack" },
    })
    ComboSystem.detect(ctx2)
    -- Deve ter strike_combo E triple_strike
    local hasTriple = false
    for _, c in ipairs(ctx2.activeCombos) do
        if c.id == "triple_strike" then hasTriple = true end
    end
    check("triple_strike dispara com 3 ataques", hasTriple)
    local dmg2 = ComboSystem.applyToCardValue({ type = "attack" }, 10, ctx2)
    -- 10 * 1.4 (strike_combo) + 6 (triple) = 20
    check("triple combina multiplier e bonus: 10 -> 20", dmg2 == 20)

    -- 3. defend_wall: 2 defesas
    local ctx3 = makeContext({
        { type = "defense" },
        { type = "defense" },
    })
    ComboSystem.detect(ctx3)
    local def = ComboSystem.applyToCardValue({ type = "defense" }, 10, ctx3)
    check("defend_wall multiplica 10 -> 14", def == 14)

    -- 4. cycle_motion: pair_tags draw+discard
    local ctx4 = makeContext({
        { type = "effect", tags = { "draw" } },
        { type = "effect", tags = { "discard" } },
    })
    ComboSystem.detect(ctx4)
    local hasCycle = false
    for _, c in ipairs(ctx4.activeCombos) do
        if c.id == "cycle_motion" then hasCycle = true end
    end
    check("cycle_motion dispara com draw+discard", hasCycle)

    -- 5. finisher_chain: strike + finisher
    local ctx5 = makeContext({
        { type = "attack" }, -- strike implicito
        { type = "attack", tags = { "finisher" } },
    })
    ComboSystem.detect(ctx5)
    local hasFin = false
    for _, c in ipairs(ctx5.activeCombos) do
        if c.id == "finisher_chain" then hasFin = true end
    end
    check("finisher_chain dispara com strike+finisher", hasFin)

    -- 6. Nenhum combo com 1 carta so
    local ctx6 = makeContext({ { type = "attack" } })
    ComboSystem.detect(ctx6)
    check("sem combo com 1 carta so", #ctx6.activeCombos == 0)

    -- 7. poison_stack aplica debuff no inimigo (once effect)
    local ctx7 = makeContext({
        { type = "attack", tags = { "poison" } },
        { type = "attack", tags = { "poison" } },
    })
    ComboSystem.detect(ctx7)
    local game = makeGame()
    ComboSystem.applyOnceEffects(game, ctx7)
    check("poison_stack aplica debuff poison no inimigo",
        game.enemy:getStatusStacks("poison") >= 2)

    -- 8. lifesteal_burst cura player (once effect)
    local ctx8 = makeContext({
        { type = "attack" }, -- strike implicito
        { type = "attack", tags = { "lifesteal" } },
    })
    ComboSystem.detect(ctx8)
    local game8 = makeGame()
    game8.player.health = 50
    ComboSystem.applyOnceEffects(game8, ctx8)
    check("lifesteal_burst cura player em +4", game8.player.health == 54)

    -- 9. applyToCardValue e no-op sem combos ativos
    local emptyCtx = makeContext({ { type = "attack" } })
    ComboSystem.detect(emptyCtx)
    local val = ComboSystem.applyToCardValue({ type = "attack" }, 10, emptyCtx)
    check("no-op sem combos", val == 10)

    -- 10. channel_burst precisa de 3 channels
    local ctx10 = makeContext({
        { type = "effect", tags = { "channel" } },
        { type = "effect", tags = { "channel" } },
    })
    ComboSystem.detect(ctx10)
    local hasBurst2 = false
    for _, c in ipairs(ctx10.activeCombos) do
        if c.id == "channel_burst" then hasBurst2 = true end
    end
    check("channel_burst NAO dispara com 2", not hasBurst2)

    local ctx10b = makeContext({
        { type = "effect", tags = { "channel" } },
        { type = "effect", tags = { "channel" } },
        { type = "effect", tags = { "channel" } },
    })
    ComboSystem.detect(ctx10b)
    local hasBurst3 = false
    for _, c in ipairs(ctx10b.activeCombos) do
        if c.id == "channel_burst" then hasBurst3 = true end
    end
    check("channel_burst dispara com 3 channels", hasBurst3)

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
