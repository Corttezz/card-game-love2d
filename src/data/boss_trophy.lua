return {
    step        = { kind = "trophy", dur = 4.40 },
    stepReduced = { kind = "trophy", dur = 2.20 },

    timing = {
        delay  = 0.35,
        rise   = 1.45,
        settle = 0.95,
        fade   = 0.45,
        reducedIn = 0.35,
    },
    spin = { turns = 5 },
    target = { x = 0.50, y = 0.40 },
    cardH = 0.34,
    startScale = 0.22,

    themes = {
        carrion_king = {
            particle = "feather", rate = 34, burst = 26,
            colors = { { 0.22, 0.18, 0.30 }, { 0.48, 0.38, 0.66 }, { 0.95, 0.74, 0.34 } },
            glow = { 0.66, 0.46, 0.95 }, ray = { 0.95, 0.74, 0.38 },
            riseSound = "bossCrowsFlee",
        },
        tower_lich = {
            particle = "shard", rate = 30, burst = 28,
            colors = { { 0.70, 0.88, 1.00 }, { 0.42, 0.62, 0.92 }, { 0.92, 0.97, 1.00 } },
            glow = { 0.52, 0.80, 1.00 }, ray = { 0.80, 0.93, 1.00 },
            riseSound = "bossRuneIgnite",
        },
        abyss_tyrant = {
            particle = "ember", rate = 42, burst = 30,
            colors = { { 1.00, 0.56, 0.16 }, { 0.95, 0.28, 0.08 }, { 1.00, 0.86, 0.42 } },
            glow = { 1.00, 0.46, 0.14 }, ray = { 1.00, 0.72, 0.30 },
            riseSound = "tyrantChainSnap",
        },
        winter_monarch = {
            particle = "snow", rate = 36, burst = 28,
            colors = { { 0.94, 0.97, 1.00 }, { 0.70, 0.84, 0.96 }, { 0.55, 0.72, 0.92 } },
            glow = { 0.70, 0.86, 1.00 }, ray = { 0.88, 0.95, 1.00 },
            riseSound = "bossIceCrackle",
        },
        rot_colossus = {
            particle = "spore", rate = 32, burst = 26,
            colors = { { 0.56, 0.86, 0.30 }, { 0.36, 0.56, 0.20 }, { 0.80, 0.96, 0.50 } },
            glow = { 0.50, 0.90, 0.32 }, ray = { 0.76, 0.96, 0.52 },
            riseSound = "bossSporeCollapse",
        },
        eclipse_queen = {
            particle = "petal", rate = 34, burst = 30,
            colors = { { 0.78, 0.22, 0.62 }, { 0.42, 0.20, 0.58 }, { 0.98, 0.80, 0.40 } },
            glow = { 0.82, 0.34, 0.90 }, ray = { 1.00, 0.82, 0.44 },
            riseSound = "bossEclipseBreak",
        },
    },
    default = {
        particle = "ember", rate = 30, burst = 24,
        colors = { { 0.95, 0.80, 0.50 }, { 0.70, 0.56, 0.34 }, { 1.00, 0.95, 0.75 } },
        glow = { 0.95, 0.80, 0.50 }, ray = { 1.00, 0.90, 0.60 },
    },
}
