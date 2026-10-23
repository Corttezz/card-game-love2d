local Debug = require("src.core.Debug")

local EnemyPoses = {}

local GROUNDED = {
    pose = "grounded",
    hover = 0, bob = 0, bobSpeed = 0,
    shadowK = 1.0, shadowA = 1.0,
}
EnemyPoses.GROUNDED = GROUNDED

EnemyPoses.BY_ID = {
    abyss_tyrant      = { pose = "grounded",
                          idle = { fps = 6, cycle = true } },
    blood_duke        = { pose = "grounded" },
    bog_ghoul         = { pose = "grounded" },
    cursed_scarecrow  = { pose = "grounded", idle = { fps = 6, cycle = true } },
    ember_imp         = { pose = "grounded", shadowBaseK = 0.18 },
    frost_wight       = { pose = "grounded" },
    glacier_knight    = { pose = "grounded" },
    grave_slime       = { pose = "grounded", shadowBaseK = 0.30 },
    harvest_reaper    = { pose = "grounded", idle = { fps = 6, cycle = true } },
    mire_hag          = { pose = "grounded" },
    moon_gargoyle     = { pose = "grounded", shadowBaseK = 0.15, idle = { fps = 6, cycle = true } },
    obsidian_sentinel = { pose = "grounded" },
    rot_colossus      = { pose = "grounded",
                          idle = { fps = 5, cycle = true } },
    rune_golem        = { pose = "grounded", idle = { fps = 5, cycle = true } },
    stone_golem       = { pose = "grounded" },
    winter_monarch    = { pose = "grounded", axisX = 56,
                          idle = { fps = 6, cycle = true } },

    hollow_farmer     = { pose = "grounded", idle = { fps = 6, cycle = true } },
    plague_rats       = { pose = "grounded", groundRow = 89, shadowBaseK = 0.35, idle = { fps = 6, cycle = true } },
    blight_bull       = { pose = "grounded", axisX = 56, shadowBaseK = 0.18, idle = { fps = 5, cycle = true } },
    wicker_effigy     = { pose = "grounded", idle = { fps = 5, cycle = true } },
    ram_cultist       = { pose = "grounded", idle = { fps = 6, cycle = true } },
    storm_harpy       = { pose = "grounded", idle = { fps = 6, cycle = true } },
    spectral_knight   = { pose = "grounded", axisX = 44, idle = { fps = 5, cycle = true } },
    storm_griffin     = { pose = "grounded", shadowBaseK = 0.15, idle = { fps = 6, cycle = true } },
    hellhound         = { pose = "grounded", axisX = 45, shadowBaseK = 0.18, idle = { fps = 6, cycle = true } },
    abyss_acolyte     = { pose = "grounded", idle = { fps = 6, cycle = true } },
    pit_brute         = { pose = "grounded", idle = { fps = 5, cycle = true } },
    frost_wolf        = { pose = "grounded", shadowBaseK = 0.18, idle = { fps = 6, cycle = true } },
    rime_shaman       = { pose = "grounded", axisX = 47, idle = { fps = 6, cycle = true } },
    frost_troll       = { pose = "grounded", idle = { fps = 5, cycle = true } },
    ice_wyrm          = { pose = "grounded", shadowBaseK = 0.25, idle = { fps = 5, cycle = true } },
    plague_toad       = { pose = "grounded", shadowBaseK = 0.25, idle = { fps = 6, cycle = true } },
    leech_horror      = { pose = "grounded", idle = { fps = 6, cycle = true } },
    croc_warrior      = { pose = "grounded", axisX = 50, shadowBaseK = 0.15, idle = { fps = 6, cycle = true } },
    spore_mother      = { pose = "grounded", idle = { fps = 5, cycle = true } },
    grave_thrall      = { pose = "grounded", axisX = 41, idle = { fps = 6, cycle = true } },
    dullahan          = { pose = "grounded", idle = { fps = 6, cycle = true } },
    fallen_angel      = { pose = "grounded", idle = { fps = 5, cycle = true } },

    abyss_wraith = { pose = "floating",
                     hover = 0.10, bob = 0.022, bobSpeed = 0.85,
                     shadowK = 0.55, shadowA = 0.45 },

    dusk_shade   = { pose = "floating",
                     hover = 0.09, bob = 0.020, bobSpeed = 0.95,
                     shadowK = 0.58, shadowA = 0.48 },

    carrion_king = { pose = "floating",
                     hover = 0.07, bob = 0.012, bobSpeed = 4.19,
                     drift = 0.010,
                     shadowK = 0.68, shadowA = 0.58,
                     idle = { fps = 8, cycle = true } },

    tower_lich   = { pose = "floating",
                     hover = 0.075, bob = 0.028, bobSpeed = 1.10,
                     drift = 0.016,
                     shadowK = 0.62, shadowA = 0.50,
                     idle = { fps = 6, cycle = true } },

    abyss_watcher = { pose = "floating",
                      hover = 0.08, bob = 0.020, bobSpeed = 0.80,
                      shadowK = 0.60, shadowA = 0.50,
                      idle = { fps = 6, cycle = true } },
    dusk_bat      = { pose = "floating",
                      hover = 0.10, bob = 0.014, bobSpeed = 4.19,
                      shadowK = 0.55, shadowA = 0.45,
                      idle = { fps = 8, cycle = true } },

    eclipse_queen = { pose = "floating",
                      hover = 0.06, bob = 0.020, bobSpeed = 0.90,
                      drift = 0.010,
                      shadowK = 0.66, shadowA = 0.55,
                      idle = { fps = 5, cycle = true } },
}

local warned = {}

function EnemyPoses.get(spriteId)
    if not spriteId then return GROUNDED end
    local p = EnemyPoses.BY_ID[spriteId]
    if not p then
        if not warned[spriteId] then
            warned[spriteId] = true
            Debug.warn("[enemy_poses] AVISO: '" .. tostring(spriteId)
                .. "' sem pose declarada — assumindo 'grounded'. "
                .. "Declare em src/data/enemy_poses.lua.")
        end
        return GROUNDED
    end
    return {
        pose     = p.pose or "grounded",
        hover    = p.hover or 0,
        bob      = p.bob or 0,
        bobSpeed = p.bobSpeed or 1.0,
        shadowK  = p.shadowK or 1.0,
        shadowA  = p.shadowA or 1.0,
        drift    = p.drift or 0,
        idle     = p.idle,
        axisX    = p.axisX,
        shadowBaseK = p.shadowBaseK,
        shadowRiseK = p.shadowRiseK,
    }
end

function EnemyPoses.isFloating(spriteId)
    local p = EnemyPoses.BY_ID[spriteId]
    return (p and p.pose == "floating") or false
end

return EnemyPoses
