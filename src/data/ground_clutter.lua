return {
    cell = 1.05,
    chance = 0.85,
    relMin = -9,
    tFore = 0.50,
    shadowT = 0.20,
    tuftT = 0.10,
    variation = { tint = 0.05, bright = 0.10, scale = 0.10, windPhase = true },
    uMin = 1.30,
    uMax = 3.70,
    edgePad = 0.02,
    handPad = 10,
    cover = 0.22,

    biomes = {
        fields = {
            { kind = "tuft", k = 1.45, w = 3, sway = 0.05, cast = true, shadowK = 0.5, family = "prop" },
            { kind = "flowers", k = 1.35, w = 2, sway = 0.04, cast = true, shadowK = 0.5, family = "prop" },
            { kind = "rock", k = 1.40, w = 2, solid = true, family = "rock" },
            { kind = "stump", k = 1.30, w = 1, solid = true, family = "prop" },
        },
        highlands = {
            { kind = "grass", n = 3, k = 0.85, w = 3, sway = 0.03, cast = true, shadowK = 0.6, family = "prop" },
            { kind = "litter", n = 2, k = 0.85, w = 2, solid = true, family = "prop" },
        },
        abyss = {
            { kind = "thorns", n = 3, k = 0.85, w = 3, sway = 0.02, cast = true, contact = true, shadowK = 0.6, family = "prop" },
            { kind = "cinders", n = 3, k = 0.85, w = 2, solid = true, family = "prop" },
            { kind = "stones", n = 3, k = 0.80, w = 1.5, solid = true, family = "rock" },
        },
        frost = {
            { kind = "drift", n = 3, k = 0.90, w = 3, solid = true, family = "prop" },
            { kind = "rock", k = 0.70, w = 1, solid = true, family = "rock" },
        },
        marsh = {
            { kind = "reeds", n = 3, k = 0.85, w = 3, sway = 0.03, cast = true, shadowK = 0.5, family = "prop" },
            { kind = "roots", n = 3, k = 0.90, w = 2, solid = true, family = "prop" },
        },
        dusk = {
            { kind = "blooms", n = 3, k = 1.50, w = 3, sway = 0.05, cast = true, shadowK = 0.5, family = "prop" },
            { kind = "leaves", n = 3, k = 1.10, w = 2, contact = true, family = "prop" },
        },
    },
}
