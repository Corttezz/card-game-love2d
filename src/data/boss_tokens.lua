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
}
