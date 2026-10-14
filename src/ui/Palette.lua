local Palette = {}

local function hex(s, a)
    s = s:gsub("#", "")
    local r = tonumber(s:sub(1, 2), 16) / 255
    local g = tonumber(s:sub(3, 4), 16) / 255
    local b = tonumber(s:sub(5, 6), 16) / 255
    return { r, g, b, a or 1 }
end

Palette.VOID         = hex("#050712")
Palette.BG_DEEPEST   = hex("#0a0f1f")
Palette.BG_DEEP      = hex("#11172e")
Palette.BG_MID       = hex("#1c2345")

Palette.GREEN_BRIGHT = hex("#33a56c")
Palette.CYAN         = hex("#40e4d4")
Palette.CYAN_PALE    = hex("#c7e2f2")
Palette.BLUE         = hex("#697ac3")
Palette.BLUE_DEEP    = hex("#0c0b3b")
Palette.PURPLE_DEEP  = hex("#5b209d")
Palette.PURPLE       = hex("#a017d0")
Palette.PINK         = hex("#f983d8")
Palette.YELLOW       = hex("#fbce3c")
Palette.ORANGE       = hex("#f4a731")
Palette.MAGENTA      = hex("#ea0096")
Palette.MAGENTA_DARK = hex("#891769")

Palette.PARCHMENT_LIGHT = hex("#e8d5a0")
Palette.PARCHMENT       = hex("#b8a068")
Palette.PARCHMENT_DARK  = hex("#6a4f24")
Palette.INK             = hex("#1a0f08")
Palette.BLOOD           = hex("#8b1e1e")
Palette.BLOOD_DARK      = hex("#4a1010")
Palette.STEEL           = hex("#4a5260")
Palette.STEEL_LIGHT     = hex("#8a94a0")
Palette.AGED_GOLD       = hex("#b08a3e")
Palette.AGED_GOLD_LIGHT = hex("#d4b060")
Palette.AGED_GOLD_DARK  = hex("#7a5e20")
Palette.MOSS            = hex("#4a6030")
Palette.RUST            = hex("#8b4a1e")

Palette.TOAST_DANGER = hex("#ff6e5c")
Palette.TOAST_WARN   = hex("#ffa851")
Palette.TOAST_GOOD   = hex("#9be36e")
Palette.TOAST_INFO   = hex("#86c8ff")
Palette.TOAST_GOLD   = hex("#ffd75e")
Palette.TOAST_ARCANE = hex("#d8b8ff")

Palette.ARCANE_INK      = hex("#120c1a")
Palette.ARCANE          = hex("#7b4bbd")
Palette.ARCANE_LIGHT    = hex("#d8b8ff")

Palette.MANA_DEEP  = hex("#232c40")
Palette.MANA       = hex("#45536e")
Palette.MANA_LIGHT = hex("#77869e")
Palette.MANA_GLINT = hex("#c4cdd8")

Palette.TAROT_NAVY       = hex("#1a1638")
Palette.TAROT_NAVY_DARK  = hex("#0a0820")
Palette.TAROT_CREAM      = hex("#e8d098")
Palette.TAROT_GOLD       = hex("#d4a836")
Palette.TAROT_GOLD_DARK  = hex("#8a6a1a")

Palette.TEXT         = Palette.CYAN_PALE
Palette.TEXT_DIM     = Palette.BLUE
Palette.TEXT_DARK    = Palette.BG_DEEPEST
Palette.OUTLINE      = Palette.VOID
Palette.OUTLINE_SOFT = Palette.BG_MID

Palette.ATTACK       = Palette.BLOOD
Palette.ATTACK_DARK  = Palette.BLOOD_DARK
Palette.DEFENSE      = Palette.STEEL
Palette.DEFENSE_DARK = Palette.INK
Palette.JOKER        = Palette.AGED_GOLD
Palette.JOKER_DARK   = Palette.RUST
Palette.EFFECT       = Palette.MOSS
Palette.EFFECT_DARK  = Palette.PARCHMENT_DARK

Palette.RARITY_BASIC     = Palette.PARCHMENT_DARK
Palette.RARITY_COMMON    = Palette.PARCHMENT_LIGHT
Palette.RARITY_UNCOMMON  = Palette.MOSS
Palette.RARITY_RARE      = Palette.BLOOD
Palette.RARITY_LEGENDARY = Palette.AGED_GOLD

Palette.SUCCESS = Palette.GREEN_BRIGHT
Palette.WARNING = Palette.ORANGE
Palette.ERROR   = Palette.MAGENTA
Palette.INFO    = Palette.CYAN

Palette.BUTTON_FILL             = Palette.PARCHMENT_DARK
Palette.BUTTON_FILL_HOVER       = Palette.AGED_GOLD
Palette.BUTTON_FILL_PRESSED     = Palette.PARCHMENT
Palette.BUTTON_FILL_DISABLED    = Palette.STEEL
Palette.BUTTON_OUTLINE_HI       = Palette.AGED_GOLD_LIGHT
Palette.BUTTON_OUTLINE_LO       = Palette.AGED_GOLD_DARK
Palette.BUTTON_OUTLINE_DISABLED = Palette.STEEL_LIGHT
Palette.BUTTON_TEXT             = Palette.PARCHMENT_LIGHT
Palette.BUTTON_TEXT_INVERT      = Palette.INK
Palette.BUTTON_TEXT_DISABLED    = Palette.STEEL_LIGHT
Palette.BUTTON_SHADOW           = Palette.INK

Palette.PANEL_FILL              = Palette.INK
Palette.PANEL_OUTLINE           = Palette.AGED_GOLD
Palette.PANEL_OUTLINE_INNER     = Palette.AGED_GOLD_DARK
Palette.PANEL_TEXT              = Palette.PARCHMENT_LIGHT
Palette.PANEL_TEXT_DIM          = Palette.PARCHMENT

Palette.INDEXED = {
    [0]  = { 0, 0, 0, 0 },
    [1]  = Palette.VOID,
    [2]  = Palette.BG_DEEPEST,
    [3]  = Palette.BG_DEEP,
    [4]  = Palette.BG_MID,
    [5]  = Palette.GREEN_BRIGHT,
    [6]  = Palette.CYAN,
    [7]  = Palette.CYAN_PALE,
    [8]  = Palette.BLUE,
    [9]  = Palette.BLUE_DEEP,
    [10] = Palette.PURPLE_DEEP,
    [11] = Palette.PURPLE,
    [12] = Palette.PINK,
    [13] = Palette.YELLOW,
    [14] = Palette.ORANGE,
    [15] = Palette.MAGENTA,
    [16] = Palette.MAGENTA_DARK,
    [17] = { 1, 1, 1, 1 },
}

function Palette.byIndex(i)
    return Palette.INDEXED[i] or Palette.INDEXED[0]
end

function Palette.set(color, alphaOverride)
    if alphaOverride then
        love.graphics.setColor(color[1], color[2], color[3], alphaOverride)
    else
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    end
end

function Palette.lerp(c1, c2, t)
    return {
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        c1[3] + (c2[3] - c1[3]) * t,
        (c1[4] or 1) + ((c2[4] or 1) - (c1[4] or 1)) * t,
    }
end

function Palette.darken(c, factor)
    factor = factor or 0.5
    return { c[1] * factor, c[2] * factor, c[3] * factor, c[4] or 1 }
end

function Palette.lighten(c, factor)
    factor = factor or 0.3
    return Palette.lerp(c, { 1, 1, 1, 1 }, factor)
end

function Palette.forRarity(rarity)
    local map = {
        basic     = Palette.RARITY_BASIC,
        common    = Palette.RARITY_COMMON,
        uncommon  = Palette.RARITY_UNCOMMON,
        rare      = Palette.RARITY_RARE,
        legendary = Palette.RARITY_LEGENDARY,
    }
    return map[rarity] or Palette.RARITY_COMMON
end

function Palette.forCardType(cardType)
    local map = {
        attack  = Palette.ATTACK,
        defense = Palette.DEFENSE,
        joker   = Palette.JOKER,
        effect  = Palette.EFFECT,
    }
    return map[cardType] or Palette.CYAN_PALE
end

return Palette
