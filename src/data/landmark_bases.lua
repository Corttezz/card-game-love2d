return {
    dir = "assets/sprites/world/base/",
    biomes = {
        fields = "fl", highlands = "hi", abyss = "ab", frost = "fr", marsh = "ma", dusk = "du",
    },
    tint = {
        fl = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
        hi = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
        ab = { pad = { 1.45, 1.25, 1.10 }, path = { 1.35, 1.20, 1.10 }, props = { 1.30, 1.18, 1.08 } },
        fr = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
        ma = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
        du = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
    },
    famTint = {
        battle = { hi = { 0.62, 0.62, 0.70 }, fr = { 0.80, 0.82, 0.88 }, du = { 0.82, 0.78, 0.74 } },
        rest = { hi = { 0.58, 0.58, 0.66 }, fr = { 0.82, 0.84, 0.90 }, du = { 0.74, 0.68, 0.64 } },
    },
    family = {
        shop = {
            padX = 0.02, padFront = 17, pathFront = 21,
            props = { { "propa", -0.53, 1 }, { "propb", 0.54, 1 } },
            veg = { { -0.36, 1 }, { 0.38, 1 } },
            pool = { color = { 1.00, 0.72, 0.38 }, radiusK = 0.60, intensity = 2.4, sy = 0.30 },
        },
        event = {
            padX = 0.00, padFront = 15, pathFront = 19,
            props = { { "propa", 0.52, 1 } },
            veg = { { -0.43, 1 }, { 0.43, 1 } },
            pool = { color = { 1.00, 0.72, 0.38 }, radiusK = 0.50, intensity = 1.8, sy = 0.30 },
        },
        battle = {
            pad = "bpad", path = false, padX = 0.00, padFront = 9,
            props = { { "bprop", 0.95, 1 } },
        },
        rest = {
            pad = "rpad", path = false, padX = 0.00, padFront = 10,
            props = { { "rprop", -0.92, -2 } },
        },
        elite = {
            pad = "epad", path = false, padX = 0.00, padFront = 13, pathFront = 19,
            props = { { "epropa", -0.62, 1 }, { "epropb", 0.62, 1 } },
        },
    },
    door = {
        landmark_shop = 0.60, highlands_landmark_shop = 0.65, abyss_landmark_shop = 0.50,
        frost_landmark_shop = 0.63, marsh_landmark_shop = 0.78, dusk_landmark_shop = 0.60,
        landmark_event = 0.52, highlands_landmark_event = 0.50, abyss_landmark_event = 0.50,
        frost_landmark_event = 0.50, marsh_landmark_event = 0.50, dusk_landmark_event = 0.50,
    },
    props = {
        frost_landmark_shop = { { "propa", -0.53, 1 }, { "propb", 0.47, 1 } },
        highlands_landmark_elite = { { "epropa", -0.62, 1 } },
    },
    embers = { ab = { color = { 1.00, 0.55, 0.18 }, count = 3 } },
    poolColor = {
        landmark_event = { 0.45, 0.80, 1.00 }, highlands_landmark_event = { 0.62, 0.78, 1.00 },
        marsh_landmark_event = { 0.62, 1.00, 0.45 },
    },
}
