local PackThemes = {}

PackThemes.KINDS = {

    Standard = {
        mood = {
            top = {0.075, 0.052, 0.036}, bottom = {0.255, 0.170, 0.098},
            motes = "dust", count = 44,
            colours = { {0.894, 0.780, 0.627}, {0.867, 0.663, 0.435}, {0.686, 0.376, 0.310} },
        },
        labelKey  = "pack.kind_standard",
        base       = {0.894, 0.780, 0.627},
        accent     = {0.686, 0.376, 0.310},
        glow       = {0.867, 0.663, 0.435},
        flash      = {1.000, 0.960, 0.865},
        titleHi    = {1.000, 0.930, 0.760},
        titleLo    = {0.867, 0.663, 0.435},

        sheenAmt     = 0.28,
        sparkles     = 4,
        sparkleSpeed = 0.55,

        burstFile  = "assets/sprites/packs/effects/burst.png",
        burstScale = 2.55,
        burstSpin  = 0.30,
        burstTime  = 0.50,

        ringScale  = 1.00,
        ringTime   = 0.45,

        debris = {
            count = 14, speed = 240, gravity = 520, life = 0.85,
            size = 6, spin = 6.0, drag = 0.90,
        },

        sealFile    = "audio/sfx/pack-seal-standard.mp3",
        sealCode    = "packSeal_standard",
        sealVolume  = 0.42,
        sfxAccent   = "sceneRustle",
        accentVol   = 0.55,
        accentPitch = 1.00,
        sealPitch   = 1.00,
        revealPitch = 0.90,
    },

    Buffoon = {
        mood = {
            top = {0.090, 0.022, 0.036}, bottom = {0.330, 0.075, 0.105},
            motes = "confetti", count = 40,
            colours = { {0.914, 0.655, 0.165}, {0.800, 0.230, 0.240}, {0.960, 0.860, 0.560} },
        },
        labelKey  = "pack.kind_buffoon",
        base       = {0.537, 0.133, 0.220},
        accent     = {0.914, 0.655, 0.165},
        glow       = {0.930, 0.560, 0.160},
        flash      = {1.000, 0.800, 0.350},
        titleHi    = {1.000, 0.850, 0.300},
        titleLo    = {0.800, 0.230, 0.240},

        sheenAmt     = 0.42,
        sparkles     = 6,
        sparkleSpeed = 1.30,

        burstFile  = "assets/sprites/packs/effects/burst_buffoon.png",
        burstScale = 2.00,
        burstSpin  = 0.95,
        burstTime  = 0.45,

        ringScale  = 1.15,
        ringTime   = 0.40,

        debris = {
            count = 26, speed = 360, gravity = 700, life = 0.95,
            size = 6, spin = 11.0, drag = 0.88,
        },

        sealFile    = "audio/sfx/pack-seal-buffoon.mp3",
        sealCode    = "packSeal_buffoon",
        sealVolume  = 1.00,
        sfxAccent   = "impactFire",
        accentVol   = 0.45,
        accentPitch = 1.05,
        sealPitch   = 0.95,
        revealPitch = 1.05,
    },

    Arcana = {
        mood = {
            top = {0.030, 0.030, 0.090}, bottom = {0.160, 0.090, 0.280},
            motes = "sparks", count = 34,
            colours = { {0.660, 0.340, 0.760}, {0.969, 0.835, 0.357}, {0.482, 0.216, 0.498} },
        },
        labelKey  = "pack.kind_arcana",
        base       = {0.133, 0.184, 0.471},
        accent     = {0.482, 0.216, 0.498},
        glow       = {0.660, 0.340, 0.760},
        flash      = {0.720, 0.450, 0.950},
        titleHi    = {0.969, 0.835, 0.357},
        titleLo    = {0.700, 0.420, 0.900},

        sheenAmt     = 0.36,
        sparkles     = 6,
        sparkleSpeed = 0.40,

        burstFile  = "assets/sprites/packs/effects/burst_arcana.png",
        burstScale = 1.95,
        burstSpin  = 0.50,
        burstTime  = 0.60,

        ringScale  = 1.05,
        ringTime   = 0.55,

        debris = {
            count = 20, speed = 190, gravity = 60, life = 1.20,
            size = 5, spin = 3.0, drag = 0.82, additive = true,
        },

        sealFile    = "audio/sfx/pack-seal-arcana.mp3",
        sealCode    = "packSeal_arcana",
        sealVolume  = 0.42,
        sfxAccent   = "impactArcane",
        accentVol   = 0.50,
        accentPitch = 0.95,
        sealPitch   = 0.92,
        revealPitch = 0.95,
    },

    Celestial = {
        mood = {
            top = {0.012, 0.018, 0.060}, bottom = {0.085, 0.100, 0.230},
            motes = "stars", count = 70,
            colours = { {0.973, 0.922, 0.647}, {0.800, 0.880, 1.000}, {0.541, 0.584, 0.749} },
        },
        labelKey  = "pack.kind_celestial",
        base       = {0.149, 0.149, 0.333},
        accent     = {0.541, 0.584, 0.749},
        glow       = {0.682, 0.702, 0.863},
        flash      = {0.800, 0.880, 1.000},
        titleHi    = {0.973, 0.922, 0.647},
        titleLo    = {0.682, 0.702, 0.863},

        sheenAmt     = 0.36,
        sparkles     = 7,
        sparkleSpeed = 0.30,

        burstFile  = "assets/sprites/packs/effects/burst_celestial.png",
        burstScale = 2.15,
        burstSpin  = 0.15,
        burstTime  = 0.65,

        ringScale  = 1.30,
        ringTime   = 0.60,

        debris = {
            count = 24, speed = 300, gravity = 0, life = 1.10,
            size = 5, spin = 0.0, drag = 0.97, additive = true,
        },

        sealFile    = "audio/sfx/pack-seal-celestial.mp3",
        sealCode    = "packSeal_celestial",
        sealVolume  = 1.00,
        sfxAccent   = "impactHoly",
        accentVol   = 0.45,
        accentPitch = 1.10,
        sealPitch   = 1.08,
        revealPitch = 1.05,
    },

    Spectral = {
        mood = {
            top = {0.020, 0.055, 0.040}, bottom = {0.095, 0.220, 0.140},
            motes = "wisps", count = 32,
            colours = { {0.550, 0.950, 0.620}, {0.850, 1.000, 0.820}, {0.349, 0.580, 0.353} },
        },
        labelKey  = "pack.kind_spectral",
        base       = {0.706, 0.859, 0.651},
        accent     = {0.349, 0.580, 0.353},
        glow       = {0.550, 0.950, 0.620},
        flash      = {0.720, 1.000, 0.760},
        titleHi    = {0.850, 1.000, 0.820},
        titleLo    = {0.349, 0.580, 0.353},

        sheenAmt     = 0.32,
        sparkles     = 5,
        sparkleSpeed = 0.22,

        burstFile  = "assets/sprites/packs/effects/burst_spectral.png",
        burstScale = 1.75,
        burstSpin  = -0.28,
        burstTime  = 0.80,

        ringScale  = 0.90,
        ringTime   = 0.75,

        debris = {
            count = 18, speed = 130, gravity = -160, life = 1.45,
            size = 6, spin = 1.5, drag = 0.86, additive = true,
        },

        sealFile    = "audio/sfx/pack-seal-spectral.mp3",
        sealCode    = "packSeal_spectral",
        sealVolume  = 0.94,
        sfxAccent   = "impactDark",
        accentVol   = 0.50,
        accentPitch = 0.85,
        sealPitch   = 0.85,
        revealPitch = 0.88,
    },
}

function PackThemes.registerSealSounds(audio)
    audio = audio or _G.audioSystem
    if not (audio and audio.loadSound) then return 0 end
    local n = 0
    for _, th in pairs(PackThemes.KINDS) do
        if th.sealCode and th.sealFile
            and not (audio.sources and audio.sources[th.sealCode])
            and love.filesystem.getInfo(th.sealFile) then
            audio:loadSound(th.sealCode, th.sealFile, th.sealVolume or 0.5)
            n = n + 1
        end
    end
    return n
end

function PackThemes.get(kind)
    return PackThemes.KINDS[kind] or PackThemes.KINDS.Standard
end

function PackThemes.label(kind)
    local I18n = require("src.i18n.I18n")
    local th = PackThemes.KINDS[kind]
    if th and th.labelKey then
        return I18n.t(th.labelKey)
    end
    return I18n.t("pack.kind_generic", { kind = tostring(kind or "?") })
end

function PackThemes.rgba(c, a)
    c = c or {1, 1, 1}
    return c[1], c[2], c[3], a == nil and 1 or a
end

return PackThemes
