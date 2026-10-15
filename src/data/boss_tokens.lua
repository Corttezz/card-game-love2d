local DIR = "assets/sprites/characters/enemies/"

return {
    tower_lich = {
        status = "runes", layout = "orbit", max = 4, full = true,
        sprites = { DIR .. "tower_lich/mechanic/rune_0.png", DIR .. "tower_lich/mechanic/rune_1.png",
                    DIR .. "tower_lich/mechanic/rune_2.png", DIR .. "tower_lich/mechanic/rune_3.png" },
        cu = 0.50, cv = 0.58, ru = 0.56, rv = 0.075, speed = 0.55, bob = 0.02,
        spawn = { 0.19, 0.24 },
        glow = { 0.55, 0.90, 1.00 },
        shard = { { 0.30, 0.34, 0.42 }, { 0.62, 0.92, 1.00 } },
        strikes = {
            rune = { kind = "token", burst = { { 0.62, 0.92, 1.00 }, { 0.40, 0.46, 0.60 } } },
        },
        sounds = {
            gain = { code = "bossRuneIgnite", path = "audio/sfx/boss/boss_rune_ignite.mp3",
                     volume = 0.34, pitch = 1.15 },
            lose = { code = "bossFrostShatter", path = "audio/sfx/boss/boss_frost_shatter.mp3",
                     volume = 0.36, pitch = 1.20 },
            hit = { code = "bossRuneIgnite", path = "audio/sfx/boss/boss_rune_ignite.mp3",
                    volume = 0.30, pitch = 0.80 },
        },
    },

    abyss_tyrant = {
        status = "chains", layout = "chains",
        link = DIR .. "abyss_tyrant/mechanic/chain_link.png", linkRows = { 1, 30 },
        chains = {
            { from = { 0.30, -0.55 }, to = { 0.50, 0.40 }, sag = 6 },
            { from = { -0.34, "ground" }, to = { 0.18, 0.72 }, sag = 10 },
            { from = { 1.34, "ground" }, to = { 0.83, 0.72 }, sag = 10 },
        },
        shard = { { 0.20, 0.18, 0.18 }, { 1.00, 0.55, 0.15 }, { 0.45, 0.30, 0.25 } },
        strikes = {
            fireball = { kind = "bolt", sprite = DIR .. "abyss_tyrant/mechanic/fireball.png",
                         from = { 0.50, 0.58 }, full = true, trail = { 1.00, 0.55, 0.15 },
                         burst = { { 1.00, 0.86, 0.32 }, { 0.95, 0.40, 0.08 }, { 0.30, 0.12, 0.08 } },
                         sound = { code = "impactFireTyrant", path = "audio/sfx/impact-fire.mp3",
                                   volume = 0.30, pitch = 0.85 } },
            ember = { kind = "bolt", sprite = DIR .. "abyss_tyrant/mechanic/fireball.png",
                      from = { 0.50, 0.58 }, trail = { 1.00, 0.55, 0.15 },
                      burst = { { 1.00, 0.86, 0.32 }, { 0.95, 0.40, 0.08 } },
                      sound = { code = "impactFireTyrant", path = "audio/sfx/impact-fire.mp3",
                                volume = 0.22, pitch = 1.15 } },
        },
        sounds = {
            lose = { code = "tyrantChainSnapMech", path = "audio/sfx/boss/tyrant_chain_snap.mp3",
                     volume = 0.45, pitch = 1.0 },
        },
    },
}
