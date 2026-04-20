-- src/ui/CardArt.lua
-- Lookup de arte por carta (com fallback derivado).
-- Recebe `card` (instância ou dados-raw) e retorna tabela normalizada:
--   { icon, bg, accent (color table), effect, decoration, artScale, artOffsetY }
--
-- artScale:
--   nil    → cover-fit padrão (preenche o slot, scale inteiro via CardArtSlot)
--   <num>  → scale fixo (ex: 1 = ícone nativo sem zoom, 1.5 = meio-zoom, 2 = igual cover)
-- artOffsetY:
--   <num>  → empurra o ícone pra cima (-) ou pra baixo (+), em pixels do canvas (96×144).
--            útil pra cartas onde o subject do sprite não fica no centro vertical.

local atlas = require("src.data.card_art")
local IconLoader = require("src.ui.IconLoader")
local Palette = require("src.ui.Palette")

local CardArt = {}

-- Fallbacks por tipo de carta quando o ID não está no atlas.
local TYPE_DEFAULTS = {
    attack  = { icon = "sword_short",  bg = "impact",  accent = "ATTACK",  decoration = "sparks" },
    defense = { icon = "shield_round", bg = "metal",   accent = "DEFENSE", decoration = "sparks" },
    joker   = { icon = "skull",        bg = "abyss",   accent = "JOKER",   decoration = "smoke" },
    effect  = { icon = "potion_red",   bg = "soft",    accent = "EFFECT",  decoration = "sparks" },
}

-- Fallback por classe (para distinguir warrior_* vs mage_* genéricos).
local CLASS_ICON_HINT = {
    warrior = { attack = "sword_short", defense = "shield_kite" },
    mage    = { attack = "bolt",        defense = "orb" },
    rogue   = { attack = "dagger",      defense = "shield_round" },
}

-- Effect derivado da raridade quando não especificado pela entrada do atlas.
local RARITY_EFFECT = {
    legendary = "holo",
    rare      = "glow",
    uncommon  = "shine",
    common    = nil,
    basic     = nil,
}

-- Scale padrão por ícone quando a entrada do atlas não especifica `artScale`.
-- - Armas + fogo: ausentes (=nil) → cover-fit (scale 2, preenchem o slot).
-- - Resto: scale 1.4 (~90×90 em slot 86×106 — preenche quase tudo com leve ar).
--   Fracional só funciona pra PNG; matriz 16×16 cairia pra 1 (integer), mas
--   todos os ícones listados aqui têm PNG correspondente em assets/sprites/icons.
local MID = 1.4
local ICON_DEFAULT_SCALE = {
    -- Defensivos
    shield_round  = MID, shield_kite = MID, armor_plate = MID, barrier = MID, helm = MID,
    -- Poções / pickups / tokens
    potion_red    = MID, potion_blue = MID, crystal = MID, gem = MID, coin = MID,
    heart         = MID, scroll = MID,
    -- Mágicos / arcanos
    orb           = MID, rune = MID,
    -- Criaturas / dark
    skull         = MID, skull_crowned = MID, eye = MID, claw = MID, fang = MID, mask = MID,
    -- Elementos frios
    snowflake     = MID, water_drop = MID,
    -- Abstrato
    star          = MID, moon = MID, jester_hat = MID,
    -- Fogo e armas ficam AUSENTES de propósito → cover-fit padrão (scale 2):
    --   flame, fireball, sword_short, sword_great, dagger, axe, bolt
}

-- Resolve uma carta → tabela de arte pronta pro CardFrame.
function CardArt.resolve(card)
    local id    = card.id or "?"
    local entry = atlas[id]

    -- Se não tiver entrada, monta uma derivada de (type, class).
    if not entry then
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

    -- Traduz accent (string "MAGENTA") em cor.
    local accentColor = Palette[entry.accent] or Palette.CYAN_PALE

    -- Effect herdado da raridade quando não especificado.
    local effect = entry.effect or RARITY_EFFECT[card.rarity]

    -- artScale: prioridade entrada > default por ícone > nil (cover automático)
    local artScale = entry.artScale or ICON_DEFAULT_SCALE[entry.icon]

    return {
        icon       = IconLoader.get(entry.icon),   -- handle (image OR matrix)
        iconName   = entry.icon,
        bgPattern  = entry.bg or "impact",
        accent     = accentColor,
        effect     = effect,            -- nil | "shine" | "glow" | "holo"
        decoration = entry.decoration,  -- nil | "sparks" | "dust" | "smoke" | "flash"
        artScale   = artScale,          -- nil = cover automático; número = force
        artOffsetY = entry.artOffsetY or 0,
    }
end

-- Retorna a lista de padrões de background conhecidos (útil pra debug).
function CardArt.backgroundPatterns()
    return {
        "stone", "blood", "metal", "rage", "fire", "wind", "void", "abyss",
        "ghost", "impact", "wave", "storm", "arcane", "ice", "soft",
        "poison", "shadow",
    }
end

return CardArt
