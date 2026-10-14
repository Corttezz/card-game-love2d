local TagSystem = require("src.systems.TagSystem")
local ComboSystem = require("src.systems.ComboSystem")

local M = {}

local function ctxOf(cards, game)
    local ctx = { allSelectedCards = cards, tagCounts = TagSystem.countAllTags(cards),
        cardsProcessed = {}, activeCombos = {}, game = game }
    ComboSystem.detect(ctx, game)
    return ctx
end

local function has(ctx, id)
    for _, c in ipairs(ctx.activeCombos) do if c.id == id then return c end end
    return nil
end

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end
    print("---- combos simples smoke ----")

    local R = ComboSystem.RULE_BY_ID
    check("tres regras: volley, wall, pair", #ComboSystem.RULES == 3
        and R.volley and R.wall and R.pair)

    local solo = { id = "a", type = "attack" }
    check("1 carta: sem combo", #ctxOf({ solo }).activeCombos == 0)

    local atks = {}
    for i = 1, 6 do atks[i] = { id = "atk" .. i, type = "attack" } end
    local c = ctxOf(atks)
    local s = R.volley.step
    check("Saraivada: 1o ataque sem bonus", ComboSystem.applyToCardValue(atks[1], 10, c) == 10)
    check("Saraivada: 2o ataque +step", ComboSystem.applyToCardValue(atks[2], 10, c) == 10 + s)
    check("Saraivada: 3o ataque +2*step", ComboSystem.applyToCardValue(atks[3], 10, c) == 10 + 2 * s)
    check("Saraivada: teto em cap", ComboSystem.applyToCardValue(atks[6], 10, c)
        == 10 + R.volley.cap * s)
    check("Saraivada detectada com o total da jogada", has(c, "volley")
        and has(c, "volley").bonus.value == s * (1 + 2 + 3 + 3 + 3))

    local d1, a1, d2 = { id = "d1", type = "defense" }, { id = "x", type = "attack" },
        { id = "d2", type = "defense" }
    local cw = ctxOf({ d1, a1, d2 })
    check("Muralha: 2a defesa +step", ComboSystem.applyToCardValue(d2, 5, cw) == 5 + R.wall.step)
    check("Muralha nao toca ataque", ComboSystem.applyToCardValue(a1, 5, cw) == 5)

    local p1, p2, p3 = { id = "same", type = "attack" }, { id = "same", type = "attack" },
        { id = "same", type = "attack" }
    local cp = ctxOf({ p1, p2, p3 })
    check("Par: 2a copia +step do par", ComboSystem.applyToCardValue(p2, 10, cp)
        == 10 + R.volley.step + R.pair.step)
    check("Par: 3a copia +2*step do par", ComboSystem.applyToCardValue(p3, 10, cp)
        == 10 + 2 * R.volley.step + 2 * R.pair.step)
    check("Par detectado", has(cp, "pair") ~= nil)

    local q = { id = "q", type = "attack", tags = { "strike", "combo" } }
    local after = { id = "z", type = "attack" }
    local cq = ctxOf({ q, after })
    check("carta `combo` conta como 2 ataques", ComboSystem.applyToCardValue(after, 10, cq)
        == 10 + 2 * R.volley.step)

    local game = { jokerSlots = { { effects = {
        { type = "combo_boost", combo = "volley", value = 2 } } } } }
    local cj = ctxOf({ atks[1], atks[2] }, game)
    check("coringa: Saraivada x2", ComboSystem.applyToCardValue(atks[2], 10, cj) == 10 + 2 * s)
    local cjw = ctxOf({ d1, d2 }, game)
    check("coringa da Saraivada nao mexe na Muralha",
        ComboSystem.applyToCardValue(d2, 5, cjw) == 5 + R.wall.step)

    local five = {}
    for i = 1, 5 do five[i] = { id = "f" .. i, type = "attack" } end
    local cf = ctxOf(five)
    local total = 0
    for _, card in ipairs(five) do total = total + ComboSystem.applyToCardValue(card, 6, cf) end
    check("5 ataques de 6 = 30 + bonus plano", total == 30 + s * 9)

    local g8 = { enemy = { addStatusEffect = function() error("nao devia") end } }
    local ok = pcall(ComboSystem.applyOnceEffects, g8, ctxOf(atks))
    check("applyOnceEffects nao aplica nada", ok)

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
