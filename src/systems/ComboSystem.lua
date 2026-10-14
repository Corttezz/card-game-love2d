local TagSystem = require("src.systems.TagSystem")
local Sfx = require("src.systems.Sfx")

local ComboSystem = {}

local function notifyComboUI(combos)
    pcall(function()
        require("src.ui.ComboBanner").show(combos)
    end)
end

local function raiseComboBanner(turnContext)
    if not turnContext or not turnContext._comboAnnounced then return end
    if turnContext._comboBannerShown then return end
    turnContext._comboBannerShown = true
    notifyComboUI(turnContext.activeCombos)
end
ComboSystem.raiseBanner = raiseComboBanner

ComboSystem.RULES = {
    { id = "volley", kind = "attack",  step = 3, cap = 3, tag = "strike",
      bonusType = "damage_bonus",  label = "Saraivada" },
    { id = "wall",   kind = "defense", step = 5, cap = 3, tag = "defend",
      bonusType = "defense_bonus", label = "Muralha" },
    { id = "pair",   kind = "same",    step = 4, cap = 2,
      bonusType = "card_bonus",    label = "Par" },
}

local RULE_BY_ID = {}
for _, r in ipairs(ComboSystem.RULES) do RULE_BY_ID[r.id] = r end
ComboSystem.RULE_BY_ID = RULE_BY_ID

local function queueWeight(card)
    return TagSystem.cardHasTag(card, "combo") and 2 or 1
end

function ComboSystem.boostFor(game, ruleId)
    local best = 1
    for _, joker in ipairs((game and game.jokerSlots) or {}) do
        for _, e in ipairs(joker.effects or {}) do
            if e.type == "combo_boost" and e.combo == ruleId and (e.value or 1) > best then
                best = e.value or 1
            end
        end
    end
    return best
end

local function ruleBonusFor(rule, card, cards, game)
    if not card then return 0 end
    local before = 0
    if rule.kind == "same" then
        if card.type ~= "attack" and card.type ~= "defense" then return 0 end
        for _, c in ipairs(cards) do
            if c == card then break end
            if c.id and c.id == card.id then before = before + 1 end
        end
    else
        if card.type ~= rule.kind then return 0 end
        for _, c in ipairs(cards) do
            if c == card then break end
            if c.type == rule.kind then before = before + queueWeight(c) end
        end
    end
    if before <= 0 then return 0 end
    local b = rule.step * math.min(before, rule.cap)
    return math.floor(b * ComboSystem.boostFor(game, rule.id))
end
ComboSystem.ruleBonusFor = ruleBonusFor

local function playOf(turnContext)
    return (turnContext and (turnContext.allSelectedCards or turnContext.snapshot)) or {}
end

function ComboSystem.detect(turnContext, game)
    turnContext.activeCombos = turnContext.activeCombos or {}
    for i = #turnContext.activeCombos, 1, -1 do turnContext.activeCombos[i] = nil end
    game = game or turnContext.game
    local cards = playOf(turnContext)
    for _, rule in ipairs(ComboSystem.RULES) do
        local total = 0
        for _, c in ipairs(cards) do total = total + ruleBonusFor(rule, c, cards, game) end
        if total > 0 then
            table.insert(turnContext.activeCombos, {
                id = rule.id, label = rule.label, rule = rule,
                bonus = { type = rule.bonusType, value = total },
            })
        end
    end
    return turnContext.activeCombos
end

function ComboSystem.cardSteps(card, baseValue, turnContext, game)
    local steps = {}
    if not turnContext then return baseValue, steps end
    game = game or turnContext.game
    local cards = playOf(turnContext)
    local v = baseValue
    for _, rule in ipairs(ComboSystem.RULES) do
        local b = ruleBonusFor(rule, card, cards, game)
        if b > 0 then
            v = v + b
            steps[#steps + 1] = { combo = rule, op = "add", value = b, after = v }
        end
    end
    return v, steps
end

function ComboSystem.applyToCardValue(card, baseValue, turnContext)
    local v = ComboSystem.cardSteps(card, baseValue, turnContext)
    if v ~= baseValue then raiseComboBanner(turnContext) end
    return v
end

function ComboSystem.applyOnceEffects(_game, turnContext)
    if not turnContext or not turnContext.activeCombos then return end
    if #turnContext.activeCombos > 0 then raiseComboBanner(turnContext) end
end

function ComboSystem.announce(_game, turnContext)
    if not turnContext.activeCombos or #turnContext.activeCombos == 0 then return end
    turnContext._comboAnnounced = true
    Sfx.play("comboTrigger")
end

return ComboSystem
