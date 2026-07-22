-- src/systems/CardFeel.lua
-- Identidade AUDIOVISUAL por tema de carta (game feel v1, Jul/2026).
-- Inspiração: StS (cada golpe tem VFX no inimigo) + Balatro (cada evento soa).
--
-- Toda carta resolve pra um TEMA via tags (TagSystem): elementos primeiro
-- (fire/ice/lightning/dark/holy/magic), depois mecânicas (poison/heal/lifesteal).
-- Cada tema define: SFX de impacto + paleta de partículas + física (gravity:
-- fogo sobe, gelo cai, veneno borbulha). Sem tema → fallback do tipo
-- (swordSound/armorSound), que continua sendo a identidade "física".
--
-- USO (CombatSequence / Game / EffectSystem):
--   CardFeel.themeOf(card)                 -- "fire" | ... | nil
--   CardFeel.playImpact(card, pitch)       -- true se tocou som temático
--   CardFeel.burst(theme, x, y, k)         -- burst de partículas na posição
--   CardFeel.burstAtEnemy(theme, k)        -- burst no sprite do inimigo
--   CardFeel.burstAtPlayer(theme, k)       -- burst no painel do jogador
--
-- Headless-safe: Sfx é no-op sem áudio; partículas só spawnam se love.graphics.

local Sfx = require("src.systems.Sfx")
local TagSystem = require("src.systems.TagSystem")

local CardFeel = {}

-- ============================================================================
-- CATÁLOGO DE TEMAS
-- colours: paleta do burst | gravity: px/s² (neg = sobe) | speed/count: energia
-- sfx: código registrado em main.lua (audio/sfx/impact-*.mp3, ElevenLabs)
-- ============================================================================
CardFeel.THEMES = {
    fire      = { sfx = "impactFire",      gravity = -150, speed = 130, count = 18,
                  colours = { {1, 0.55, 0.15, 1}, {1, 0.32, 0.05, 1}, {1, 0.82, 0.30, 1} } },
    ice       = { sfx = "impactIce",       gravity = 110,  speed = 120, count = 15,
                  colours = { {0.60, 0.85, 1, 1}, {0.80, 0.95, 1, 1}, {0.38, 0.68, 0.95, 1} } },
    lightning = { sfx = "impactLightning", gravity = 0,    speed = 220, count = 13,
                  colours = { {1, 0.95, 0.40, 1}, {1, 0.85, 0.15, 1}, {1, 1, 0.82, 1} } },
    dark      = { sfx = "impactDark",      gravity = -60,  speed = 85,  count = 15,
                  colours = { {0.45, 0.25, 0.60, 1}, {0.25, 0.14, 0.35, 1}, {0.62, 0.42, 0.80, 1} } },
    holy      = { sfx = "impactHoly",      gravity = -95,  speed = 90,  count = 15,
                  colours = { {1, 0.95, 0.70, 1}, {1, 0.85, 0.50, 1}, {1, 1, 0.90, 1} } },
    magic     = { sfx = "impactArcane",    gravity = -45,  speed = 115, count = 15,
                  colours = { {0.70, 0.45, 0.95, 1}, {0.50, 0.30, 0.85, 1}, {0.86, 0.72, 1, 1} } },
    poison    = { sfx = "impactPoison",    gravity = -75,  speed = 70,  count = 15,
                  colours = { {0.45, 0.80, 0.25, 1}, {0.30, 0.60, 0.15, 1}, {0.70, 0.90, 0.40, 1} } },
    heal      = { sfx = "healShimmer",     gravity = -105, speed = 60,  count = 13,
                  colours = { {0.50, 0.95, 0.55, 1}, {0.80, 1, 0.72, 1}, {0.95, 1, 0.90, 1} } },
    -- Lifesteal: som sombrio + paleta sangue (drena, não "cura fofo").
    lifesteal = { sfx = "impactDark",      gravity = -85,  speed = 75,  count = 13,
                  colours = { {0.75, 0.15, 0.25, 1}, {0.55, 0.08, 0.15, 1}, {0.95, 0.35, 0.40, 1} } },

    -- Temas "internos" (não resolvidos por tag; usados por Game/EffectSystem):
    physical  = { sfx = nil,               gravity = 170,  speed = 150, count = 12,
                  colours = { {0.90, 0.88, 0.82, 1}, {0.75, 0.72, 0.65, 1}, {1, 0.95, 0.75, 1} } },
    armor     = { sfx = nil,               gravity = -35,  speed = 75,  count = 12,
                  colours = { {0.55, 0.72, 1, 1}, {0.42, 0.58, 0.85, 1}, {0.80, 0.88, 1, 1} } },
    buff      = { sfx = nil,               gravity = -130, speed = 85,  count = 14,
                  colours = { {1, 0.42, 0.25, 1}, {0.95, 0.25, 0.15, 1}, {1, 0.65, 0.35, 1} } },
    weak      = { sfx = nil,               gravity = 55,   speed = 55,  count = 11,
                  colours = { {0.62, 0.50, 0.82, 1}, {0.48, 0.38, 0.65, 1} } },
    vulnerable = { sfx = nil,              gravity = 55,   speed = 55,  count = 11,
                  colours = { {0.85, 0.45, 0.58, 1}, {0.68, 0.30, 0.42, 1} } },
}

-- Ordem de resolução: elemento define a identidade antes da mecânica
-- (Bola de Fogo com poison secundário SOA fogo; o veneno aparece no debuff).
local RESOLVE_ORDER = {
    "fire", "ice", "lightning", "dark", "holy",
    "poison", "lifesteal", "heal", "magic",
}

-- Cache por carta (tags não mudam em runtime). weak keys: não segura instância.
local themeCache = setmetatable({}, { __mode = "k" })

function CardFeel.themeOf(card)
    if not card then return nil end
    local cached = themeCache[card]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local found = nil
    for _, theme in ipairs(RESOLVE_ORDER) do
        if TagSystem.cardHasTag(card, theme) then
            found = theme
            break
        end
    end
    themeCache[card] = found or false
    return found
end

-- ============================================================================
-- SOM
-- ============================================================================

-- Toca o SFX de impacto do tema da carta. Retorna true se havia tema com som
-- (caller usa fallback físico sword/armor quando false).
function CardFeel.playImpact(card, pitch)
    local theme = CardFeel.themeOf(card)
    local cfg = theme and CardFeel.THEMES[theme]
    if not cfg or not cfg.sfx then return false end
    Sfx.play(cfg.sfx, pitch and { pitch = pitch } or nil)
    return true
end

-- ============================================================================
-- PARTÍCULAS
-- ============================================================================

-- Burst temático em (x, y). k = intensidade 0.5..2 (escala count/speed).
function CardFeel.burst(theme, x, y, k)
    local cfg = CardFeel.THEMES[theme]
    if not cfg or not love.graphics then return end
    k = k or 1
    local ok, ParticlesManager = pcall(require, "engine.ParticlesManager")
    if not ok then return end
    return ParticlesManager.spawn(x, y, 0, 0, {
        timer         = 0.015,
        lifespan      = 0.85,
        scale         = 0.38,
        speed         = cfg.speed * k,
        colours       = cfg.colours,
        pulse_max     = math.floor(cfg.count * k + 0.5),
        vel_variation = 0.6,
        gravity       = cfg.gravity,
        layer         = 7,
    })
end

-- Burst no sprite do inimigo (usa bbox do EnemyRenderer). Headless = no-op.
function CardFeel.burstAtEnemy(theme, k)
    local ok, ER = pcall(require, "src.ui.EnemyRenderer")
    if not ok or not ER.getLastPos then return end
    local ex, ey = ER.getLastPos()
    if not ex then return end
    return CardFeel.burst(theme, ex, ey - 20, k)
end

-- Burst no painel do jogador (canto inferior-esquerdo, mesmo âncora dos
-- FloatingText de dano recebido em Game:enemyTurn).
function CardFeel.burstAtPlayer(theme, k)
    if not love.graphics then return end
    return CardFeel.burst(theme, 120, love.graphics.getHeight() - 120, k)
end

return CardFeel
