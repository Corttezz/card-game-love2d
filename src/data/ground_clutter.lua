return {
    cell = 1.05,
    chance = 0.85,
    relMin = 0.25,
    tMin = 0.50,
    tFade = 0.08,
    uMin = 1.30,
    uMax = 3.70,
    forkRelMax = 8.0,
    edgePad = 0.02,
    handPad = 10,
    cover = 0.22,

    biomes = {
        fields = {
            { kind = "tuft", k = 1.45, w = 3, sway = 0.05, family = "prop" },
            { kind = "flowers", k = 1.35, w = 2, sway = 0.04, family = "prop" },
            { kind = "rock", k = 1.40, w = 2, solid = true, family = "rock" },
            { kind = "stump", k = 1.30, w = 1, solid = true, family = "prop" },
        },
        highlands = {
            { kind = "grass", n = 3, k = 0.85, w = 3, sway = 0.03, family = "prop" },
            { kind = "litter", n = 2, k = 0.85, w = 2, solid = true, family = "prop" },
        },
        abyss = {
            { kind = "embers", n = 4, k = 1.40, w = 3, family = "prop" },
            { kind = "rock", k = 0.55, w = 1, solid = true, family = "rock" },
        },
        frost = {
            { kind = "drift", n = 3, k = 0.90, w = 3, solid = true, family = "prop" },
            { kind = "rock", k = 0.70, w = 1, solid = true, family = "rock" },
        },
        marsh = {
            { kind = "reeds", n = 3, k = 0.85, w = 3, sway = 0.03, family = "prop" },
            { kind = "roots", n = 3, k = 0.90, w = 2, solid = true, family = "prop" },
            { kind = "mushroom", k = 1.10, w = 1, solid = true, family = "prop" },
        },
        dusk = {
            { kind = "blooms", n = 3, k = 1.50, w = 3, sway = 0.05, family = "prop" },
            { kind = "leaves", n = 3, k = 1.10, w = 2, family = "prop" },
        },
    },
}
