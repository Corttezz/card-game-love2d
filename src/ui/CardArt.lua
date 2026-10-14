local atlas = require("src.data.card_art")
local IconLoader = require("src.ui.IconLoader")
local Palette = require("src.ui.Palette")
local Debug = require("src.core.Debug")

local CardArt = {}

local warnedMissing = {}

local TYPE_DEFAULTS = {
    attack  = { icon = "sword_short",  bg = "impact",  accent = "ATTACK",  decoration = "sparks" },
    defense = { icon = "shield_round", bg = "metal",   accent = "DEFENSE", decoration = "sparks" },
    joker   = { icon = "skull",        bg = "abyss",   accent = "JOKER",   decoration = "smoke" },
    effect  = { icon = "potion_red",   bg = "soft",    accent = "EFFECT",  decoration = "sparks" },
}

local CLASS_ICON_HINT = {
    warrior = { attack = "sword_short", defense = "shield_kite" },
    mage    = { attack = "bolt",        defense = "orb" },
    rogue   = { attack = "dagger",      defense = "shield_round" },
}

local RARITY_EFFECT = {
    legendary = "holo",
    rare      = "glow",
    uncommon  = "shine",
    common    = nil,
    basic     = nil,
}

local MID = 1.4
local ICON_DEFAULT_SCALE = {
    shield_round  = MID, shield_kite = MID, armor_plate = MID, barrier = MID, helm = MID,
    potion_red    = MID, potion_blue = MID, crystal = MID, gem = MID, coin = MID,
    heart         = MID, scroll = MID,
    orb           = MID, rune = MID,
    skull         = MID, skull_crowned = MID, eye = MID, claw = MID, fang = MID, mask = MID,
    snowflake     = MID, water_drop = MID,
    star          = MID, moon = MID, jester_hat = MID,
}

function CardArt.resolve(card)
    local id    = card.id or "?"
    local entry = atlas[id]

    if not entry then
        if not warnedMissing[id] then
            warnedMissing[id] = true
            Debug.warn(("CardArt: '%s' nao tem entrada em src/data/card_art.lua — "):format(id)
                .. "usando fallback por tipo. A ARTE VAI REPETIR com outras cartas "
                .. "do mesmo tipo. Adicione a entrada no atlas.")
        end
        local defaults = TYPE_DEFAULTS[card.type] or TYPE_DEFAULTS.attack
        local classHint = card.class and CLASS_ICON_HINT[card.class]
        local iconOverride = classHint and classHint[card.type]
        entry = {
            icon = iconOverride or defaults.icon,
            bg = defaults.bg,
            accent = defaults.accent,
            decoration = defaults.decoration,
        }
    end

    local accentColor = Palette[entry.accent] or Palette.CYAN_PALE

    local effect = entry.effect or RARITY_EFFECT[card.rarity]

    local artScale = entry.artScale or ICON_DEFAULT_SCALE[entry.icon]

    return {
        icon       = IconLoader.get(entry.icon),
        iconName   = entry.icon,
        bgPattern  = entry.bg or "impact",
        accent     = accentColor,
        effect     = effect,
        decoration = entry.decoration,
        artScale   = artScale,
        artOffsetY = entry.artOffsetY or 0,
    }
end

function CardArt.backgroundPatterns()
    return {
        "stone", "blood", "metal", "rage", "fire", "wind", "void", "abyss",
        "ghost", "impact", "wave", "storm", "arcane", "ice", "soft",
        "poison", "shadow",
    }
end

return CardArt
