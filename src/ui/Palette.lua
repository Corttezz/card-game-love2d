-- src/ui/Palette.lua
-- Paleta 16 cores fixa, derivada da "DR-Darkworld Neon" (Deltarune Dark World, Lospec)
-- estendida com 4 tons ultra-escuros para fundos.
-- Regra: TODA cor do jogo sai daqui. Nunca hardcode RGB em arquivos novos.
--
-- Formato: {R, G, B, A} em 0..1 (formato LÖVE).

local Palette = {}

-- Função auxiliar para converter hex "#RRGGBB" em {r,g,b,a}.
local function hex(s, a)
    s = s:gsub("#", "")
    local r = tonumber(s:sub(1, 2), 16) / 255
    local g = tonumber(s:sub(3, 4), 16) / 255
    local b = tonumber(s:sub(5, 6), 16) / 255
    return { r, g, b, a or 1 }
end

-- ===== DARK BASE (fundos e sombras) =====
Palette.VOID         = hex("#050712")   -- quase preto
Palette.BG_DEEPEST   = hex("#0a0f1f")   -- fundo painel
Palette.BG_DEEP      = hex("#11172e")   -- fundo alternativo
Palette.BG_MID       = hex("#1c2345")   -- borda/outline escuro

-- ===== DR-DARKWORLD NEON (12 cores vibrantes) =====
Palette.GREEN_BRIGHT = hex("#33a56c")   -- sucesso / defense accent
Palette.CYAN         = hex("#40e4d4")   -- info / mana
Palette.CYAN_PALE    = hex("#c7e2f2")   -- texto claro
Palette.BLUE         = hex("#697ac3")   -- defense primary
Palette.BLUE_DEEP    = hex("#0c0b3b")   -- azul noite (uso limitado)
Palette.PURPLE_DEEP  = hex("#5b209d")   -- rare secondary
Palette.PURPLE       = hex("#a017d0")   -- rare primary (joker/effect)
Palette.PINK         = hex("#f983d8")   -- highlight magenta
Palette.YELLOW       = hex("#fbce3c")   -- legendary / jokers
Palette.ORANGE       = hex("#f4a731")   -- attack warm
Palette.MAGENTA      = hex("#ea0096")   -- attack primary
Palette.MAGENTA_DARK = hex("#891769")   -- attack shadow

-- ===== GRIMOIRE SEPIA (nova direção visual estilo pergaminho envelhecido) =====
-- Usadas pelo novo CardFrame (src/ui/card/). As cores acima ficam para
-- retrocompatibilidade e para overlays neon opcionais.
Palette.PARCHMENT_LIGHT = hex("#e8d5a0")   -- pergaminho claro (highlights do papel)
Palette.PARCHMENT       = hex("#b8a068")   -- pergaminho principal (fundo do frame)
Palette.PARCHMENT_DARK  = hex("#6a4f24")   -- pergaminho sombra (borda interna)
Palette.INK             = hex("#1a0f08")   -- tinta preta profunda (outline / texto)
Palette.BLOOD           = hex("#8b1e1e")   -- vermelho sangue (attack accent)
Palette.BLOOD_DARK      = hex("#4a1010")   -- vermelho sangue escuro
Palette.STEEL           = hex("#4a5260")   -- aço azulado (defense accent)
Palette.STEEL_LIGHT     = hex("#8a94a0")
Palette.AGED_GOLD       = hex("#b08a3e")   -- dourado envelhecido (legendary/joker)
Palette.AGED_GOLD_LIGHT = hex("#d4b060")
Palette.AGED_GOLD_DARK  = hex("#7a5e20")   -- dourado escuro (divisores sutis)
Palette.MOSS            = hex("#4a6030")   -- verde musgo (effect / poison)
Palette.RUST            = hex("#8b4a1e")   -- laranja ferrugem

-- ===== Gema de mana (CardCostBadge) — lápis-lazúli ENVELHECIDO.
-- Feedback do dono (Jul/2026): a 1ª versão usava o azul vivo do ManaOrb e
-- "gritava" sobre o pergaminho — a carta é relíquia, a gema também tem que
-- ser. Tons dessaturados na família do STEEL (#4a5260), só um fio mais
-- azuis pra ainda ler como mana. A FORMA (losango facetado + engaste ouro)
-- é a aprovada — mexer só nas cores.
Palette.MANA_DEEP  = hex("#232c40")   -- faceta inferior (sombra da gema)
Palette.MANA       = hex("#45536e")   -- corpo da gema (aço-lazúli morto)
Palette.MANA_LIGHT = hex("#77869e")   -- faceta superior iluminada (empoeirada)
Palette.MANA_GLINT = hex("#c4cdd8")   -- brilho especular (prata suave)

-- ===== TAROT (tema específico do joker — azul-meia-noite + dourado) =====
Palette.TAROT_NAVY       = hex("#1a1638")   -- azul-meia-noite (fundo do frame)
Palette.TAROT_NAVY_DARK  = hex("#0a0820")
Palette.TAROT_CREAM      = hex("#e8d098")   -- cream (fundo da art slot)
Palette.TAROT_GOLD       = hex("#d4a836")   -- ouro tarot (anéis + ornamentos)
Palette.TAROT_GOLD_DARK  = hex("#8a6a1a")

-- ===== Aliases semânticos (direcionados ao grimório) =====
-- UI states: continua compatível com DR-Darkworld,
-- mas o Card compositor usa os aliases grimoire abaixo.
Palette.TEXT         = Palette.CYAN_PALE
Palette.TEXT_DIM     = Palette.BLUE
Palette.TEXT_DARK    = Palette.BG_DEEPEST
Palette.OUTLINE      = Palette.VOID
Palette.OUTLINE_SOFT = Palette.BG_MID

-- Card types (cor de borda/accent no frame)
Palette.ATTACK       = Palette.BLOOD
Palette.ATTACK_DARK  = Palette.BLOOD_DARK
Palette.DEFENSE      = Palette.STEEL
Palette.DEFENSE_DARK = Palette.INK
Palette.JOKER        = Palette.AGED_GOLD
Palette.JOKER_DARK   = Palette.RUST
Palette.EFFECT       = Palette.MOSS
Palette.EFFECT_DARK  = Palette.PARCHMENT_DARK

-- Rarity colors (tom grimório, não neon)
Palette.RARITY_BASIC     = Palette.PARCHMENT_DARK
Palette.RARITY_COMMON    = Palette.PARCHMENT_LIGHT
Palette.RARITY_UNCOMMON  = Palette.MOSS
Palette.RARITY_RARE      = Palette.BLOOD
Palette.RARITY_LEGENDARY = Palette.AGED_GOLD

-- Status feedback
Palette.SUCCESS = Palette.GREEN_BRIGHT
Palette.WARNING = Palette.ORANGE
Palette.ERROR   = Palette.MAGENTA
Palette.INFO    = Palette.CYAN

-- ===== UI Chrome (botões, painéis, modais pixelados) =====
-- Estados semânticos — sempre referenciar por nome, não hardcodar cor no Button.
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

-- Painéis / modais
Palette.PANEL_FILL              = Palette.INK
Palette.PANEL_OUTLINE           = Palette.AGED_GOLD
Palette.PANEL_OUTLINE_INNER     = Palette.AGED_GOLD_DARK
Palette.PANEL_TEXT              = Palette.PARCHMENT_LIGHT
Palette.PANEL_TEXT_DIM          = Palette.PARCHMENT

-- ===== Utilitários =====

-- Retorna a cor por índice numérico (uso interno dos bitmaps de ícone).
-- Convenção no PixelIcons: 0 = transparente.
Palette.INDEXED = {
    [0]  = { 0, 0, 0, 0 },       -- transparente (special)
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
    [17] = { 1, 1, 1, 1 },        -- white puro (highlights de metal)
}

-- Retorna cor por índice (fallback = transparente).
function Palette.byIndex(i)
    return Palette.INDEXED[i] or Palette.INDEXED[0]
end

-- Aplica cor ao love.graphics (helper para evitar unpack manual).
function Palette.set(color, alphaOverride)
    if alphaOverride then
        love.graphics.setColor(color[1], color[2], color[3], alphaOverride)
    else
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    end
end

-- Interpola linearmente entre duas cores (t = 0..1).
function Palette.lerp(c1, c2, t)
    return {
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        c1[3] + (c2[3] - c1[3]) * t,
        (c1[4] or 1) + ((c2[4] or 1) - (c1[4] or 1)) * t,
    }
end

-- Escurece uma cor (fator 0..1, 0 = preto).
function Palette.darken(c, factor)
    factor = factor or 0.5
    return { c[1] * factor, c[2] * factor, c[3] * factor, c[4] or 1 }
end

-- Clareia (blend com branco).
function Palette.lighten(c, factor)
    factor = factor or 0.3
    return Palette.lerp(c, { 1, 1, 1, 1 }, factor)
end

-- Retorna cor baseada em raridade (helper semântico).
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

-- Retorna cor baseada em tipo de carta.
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
