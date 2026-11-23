local Sfx = require("src.systems.Sfx")
local I18n = require("src.i18n.I18n")

local EffectFeedback = {}

EffectFeedback.SOUNDS = {
    exhaust    = { "exhaustBurn", "cardExhaust" },
    copy       = { "cardCopy", "cardDraw" },
    retain     = { "cardRetain", "cardDraw" },
    discard    = { "cardDiscard", "cardDeselect" },
    reshuffle  = { "deckShuffle", "deckStart" },
    innate     = { "innateRise", "cardDraw" },
    mana       = { "manaRestore", "effectChime" },
    maxMana    = { "manaMaxUp", "effectChime" },
    selfDamage = { "selfDamage", "impactDark" },
    buff       = { "buffApplied", "strengthGain" },
    reveal     = { "intentReveal", "effectChime" },
    armor      = { "armorSound" },
}

function EffectFeedback.soundFor(event)
    local list = EffectFeedback.SOUNDS[event]
    if not list then return nil end
    for _, name in ipairs(list) do
        if Sfx.has(name) then return name end
    end
    return list[#list]
end

function EffectFeedback.play(event, opts)
    local name = EffectFeedback.soundFor(event)
    if name then Sfx.play(name, opts) end
    return name
end

local function hasGraphics() return love.graphics ~= nil and love.graphics.getWidth ~= nil end

local function label(key, vars, x, y, opts)
    if not hasGraphics() then return end
    local ok, FloatingText = pcall(require, "src.ui.FloatingText")
    if not ok then return end
    FloatingText.spawn(I18n.t("messages." .. key, vars), x, y, opts)
end

local function cardTop(card)
    local s = card.currentScale or 1
    local w = (card.image and card.image:getWidth() or 100) * s
    local x = (card.renderX and card.renderX ~= 0) and card.renderX or card.x or 0
    local y = (card.renderY and card.renderY ~= 0) and card.renderY or card.y or 0
    return x + w / 2, y - 10
end

local function playerPos()
    return 120, love.graphics.getHeight() - 150
end

local function manaPos()
    local ManaOrb = require("src.ui.ManaOrb")
    if ManaOrb.lastX then return ManaOrb.lastX, ManaOrb.lastY - 56 end
    return love.graphics.getWidth() - 50, love.graphics.getHeight() - 110
end

local function feel(fn, ...)
    local ok, CardFeel = pcall(require, "src.systems.CardFeel")
    if ok and CardFeel[fn] then CardFeel[fn](...) end
end

local function handFx()
    if not hasGraphics() then return nil end
    return require("src.ui.HandFx")
end

local COLORS = {
    retain  = { 0.98, 0.80, 0.34, 1 },
    discard = { 0.92, 0.62, 0.52, 1 },
    shuffle = { 0.93, 0.85, 0.66, 1 },
    innate  = { 1.00, 0.93, 0.62, 1 },
    mana    = { 0.45, 0.78, 1.00, 1 },
}

local LABEL_KEY = { retain = "fx_retained", innate = "fx_innate" }

function EffectFeedback.exhaust()
    return EffectFeedback.play("exhaust")
end

function EffectFeedback.copy()
    return EffectFeedback.play("copy")
end

function EffectFeedback.discard(game, card, idx)
    if not card then return end
    EffectFeedback.play("discard", { pitch = 1.0 + ((idx or 1) - 1) * 0.06 })
    local fx = handFx()
    if not fx then return end
    local tx, ty
    if game and game.getDeckOrigin then tx, ty = game:getDeckOrigin() end
    fx.discard(card, tx, ty)
    local x, y = cardTop(card)
    label("fx_discarded", nil, x, y, { color = COLORS.discard, fontSize = 15 })
end

function EffectFeedback.reshuffle(game, n)
    EffectFeedback.play("reshuffle")
    local fx = handFx()
    if not fx then return end
    local x, y
    if game and game.getDeckOrigin then x, y = game:getDeckOrigin() end
    fx.reshuffle(n, x, y)
    if x then label("fx_reshuffled", nil, x - 40, y - 70, { color = COLORS.shuffle, fontSize = 15, hold = 0.6 }) end
end

function EffectFeedback.onCardArrives(card, n)
    if not card then return false end
    local kind = card._fxRetained and "retain" or (card._fxInnate and "innate") or nil
    card._fxRetained, card._fxInnate = nil, nil
    if not kind then return false end
    EffectFeedback.play(kind, { pitch = 1.0 + ((n or 1) - 1) * 0.03 })
    local fx = handFx()
    if fx then
        fx[kind](card)
        local x, y = cardTop(card)
        label(LABEL_KEY[kind], nil, x, y, { color = COLORS[kind], fontSize = 15, hold = 0.6 })
    end
    return true
end

local function handHidden()
    local ok, HandDeal = pcall(require, "src.ui.HandDeal")
    return ok and HandDeal.hidesHand() or false
end

function EffectFeedback.retainKept(cards)
    local hidden = handHidden()
    for i, c in ipairs(cards or {}) do
        c._fxRetained = true
        if not hidden then EffectFeedback.onCardArrives(c, i) end
    end
end

function EffectFeedback.markInnate(cards)
    for _, c in ipairs(cards or {}) do c._fxInnate = true end
end

function EffectFeedback.mana(v)
    EffectFeedback.play("mana")
    if not hasGraphics() then return end
    local x, y = manaPos()
    local Fl = require("src.ui.FloatingText")
    Fl.spawn("+" .. tostring(v), x, y, { color = COLORS.mana, fontSize = 18 })
end

function EffectFeedback.maxMana(v)
    EffectFeedback.play("maxMana")
    if not hasGraphics() then return end
    local x, y = manaPos()
    label("fx_max_mana", { value = v }, x - 30, y - 20, { color = COLORS.mana, fontSize = 16, hold = 0.7 })
    feel("burst", "magic", x, y + 56, 0.8)
end

function EffectFeedback.selfDamage(v)
    EffectFeedback.play("selfDamage")
    if not hasGraphics() then return end
    local x, y = playerPos()
    require("src.ui.FloatingText").spawn("-" .. tostring(v), x, y, { kind = "damage" })
    feel("burstAtPlayer", "lifesteal", 0.9)
    if _G.triggerShake then _G.triggerShake(3, 0.12) end
end

function EffectFeedback.buff()
    EffectFeedback.play("buff")
    feel("burstAtPlayer", "buff", 0.9)
end

function EffectFeedback.armor(v)
    EffectFeedback.play("armor")
    if not hasGraphics() then return end
    local x, y = playerPos()
    require("src.ui.FloatingText").spawn("+" .. tostring(v), x, y, { kind = "armor" })
    feel("burstAtPlayer", "armor", 0.8)
end

function EffectFeedback.reveal()
    EffectFeedback.play("reveal")
    feel("burstAtEnemy", "holy", 0.8)
end

return EffectFeedback
