local Sfx = require("src.systems.Sfx")
local TagSystem = require("src.systems.TagSystem")

local CardFeel = {}

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
    lifesteal = { sfx = "impactDark",      gravity = -85,  speed = 75,  count = 13,
                  colours = { {0.75, 0.15, 0.25, 1}, {0.55, 0.08, 0.15, 1}, {0.95, 0.35, 0.40, 1} } },

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

local RESOLVE_ORDER = {
    "fire", "ice", "lightning", "dark", "holy",
    "poison", "lifesteal", "heal", "magic",
}

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

function CardFeel.playImpact(card, pitch)
    local theme = CardFeel.themeOf(card)
    local cfg = theme and CardFeel.THEMES[theme]
    if not cfg or not cfg.sfx then return false end
    Sfx.play(cfg.sfx, pitch and { pitch = pitch } or nil)
    return true
end

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

function CardFeel.burstAtEnemy(theme, k)
    local ok, ER = pcall(require, "src.ui.EnemyRenderer")
    if not ok or not ER.getLastPos then return end
    local ex, ey = ER.getLastPos()
    if not ex then return end
    return CardFeel.burst(theme, ex, ey - 20, k)
end

function CardFeel.burstAtPlayer(theme, k)
    if not love.graphics then return end
    return CardFeel.burst(theme, 120, love.graphics.getHeight() - 120, k)
end

return CardFeel
