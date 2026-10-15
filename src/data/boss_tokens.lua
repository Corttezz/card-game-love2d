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

    winter_monarch = {
        status = "frost", layout = "screen",
        corner = DIR .. "winter_monarch/mechanic/frost_corner.png",
        iceBlock = DIR .. "winter_monarch/mechanic/ice_block.png",
        strikes = {
            shard = { kind = "bolt", sprite = DIR .. "winter_monarch/mechanic/ice_shard.png",
                      from = { 0.156, 0.178 }, full = true, arc = 14, trail = { 0.70, 0.90, 1.00 },
                      burst = { { 0.90, 0.97, 1.00 }, { 0.55, 0.78, 1.00 }, { 0.30, 0.45, 0.70 } },
                      sound = { code = "impactIceMonarch", path = "audio/sfx/impact-ice.mp3",
                                volume = 0.90, pitch = 1.05 } },
        },
        sounds = {
            gain = { code = "impactIceMonarch", path = "audio/sfx/impact-ice.mp3",
                     volume = 0.70, pitch = 0.80 },
            freeze = { code = "bossIceCrackle", path = "audio/sfx/boss/boss_ice_crackle.mp3",
                       volume = 1.00, pitch = 1.0 },
            melt = { code = "shopCrystalMelt", path = "audio/sfx/shop-crystal-shatter.mp3",
                     volume = 0.40, pitch = 1.30 },
        },
    },

    rot_colossus = {
        status = "roots", layout = "ground", max = 4, full = true,
        sprites = { DIR .. "rot_colossus/mechanic/root_0.png", DIR .. "rot_colossus/mechanic/root_1.png",
                    DIR .. "rot_colossus/mechanic/root_2.png", DIR .. "rot_colossus/mechanic/root_3.png" },
        baseRow = 62,
        slots = { { u = 0.13, front = true }, { u = 0.80, front = true },
                  { u = 0.02, front = false }, { u = 0.93, front = false } },
        sap = { 0.45, 0.95, 0.35 },
        shard = { { 0.30, 0.22, 0.14 }, { 0.45, 0.60, 0.20 }, { 0.62, 0.85, 0.30 } },
        strikes = {
            root = { kind = "rise", sprite = DIR .. "rot_colossus/mechanic/root_1.png", baseRow = 62,
                     burst = { { 0.30, 0.22, 0.14 }, { 0.45, 0.60, 0.20 }, { 0.62, 0.85, 0.30 } },
                     sound = { code = "impactPoisonRoot", path = "audio/sfx/impact-poison.mp3",
                               volume = 1.00, pitch = 0.75 } },
        },
        sounds = {
            gain = { code = "bossRootsCrawlMech", path = "audio/sfx/boss/boss_roots_crawl.mp3",
                     volume = 0.90, pitch = 1.0 },
            lose = { code = "colossusCrackMech", path = "audio/sfx/boss/colossus_crack.mp3",
                     volume = 0.75, pitch = 1.1 },
        },
    },
}
