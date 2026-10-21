return {
    dir = "assets/sprites/world/base/",
    biomes = {
        fields = "fl", highlands = "hi", abyss = "ab", frost = "fr", marsh = "ma", dusk = "du",
    },
    veg = {
        fl = "fl_veg", hi = "world:highlands_bush_0", ab = "world:abyss_bush_0",
        fr = "world:frost_drift_0", ma = "world:marsh_reeds_0", du = "world:dusk_bush_0",
    },
    tint = {
        fl = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
        hi = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
        ab = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
        fr = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
        ma = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
        du = { pad = { 1.00, 1.00, 1.00 }, path = { 1.00, 1.00, 1.00 } },
    },
    family = {
        shop = {
            padW = 1.55, padX = 0.02, padFront = 17, padBack = 0.32, pathW = 0.22, pathFront = 13,
            props = { { "propa", -0.53, 1, 0.22 }, { "propb", 0.54, 1, 0.25 } },
            veg = { { -0.36, 1, 0.20 }, { 0.38, 1, 0.17 } },
            pool = { color = { 1.00, 0.72, 0.38 }, radiusK = 0.60, intensity = 2.4, sy = 0.30 },
        },
        event = {
            padW = 1.45, padX = 0.00, padFront = 15, padBack = 0.30, pathW = 0.20, pathFront = 11,
            props = { { "propa", 0.52, 1, 0.22 } },
            veg = { { -0.43, 1, 0.20 }, { 0.43, 1, 0.18 } },
            pool = { color = { 1.00, 0.72, 0.38 }, radiusK = 0.50, intensity = 1.8, sy = 0.30 },
        },
    },
    door = {
        landmark_shop = 0.60, highlands_landmark_shop = 0.65, abyss_landmark_shop = 0.50,
        frost_landmark_shop = 0.63, marsh_landmark_shop = 0.78, dusk_landmark_shop = 0.60,
        landmark_event = 0.52, highlands_landmark_event = 0.50, abyss_landmark_event = 0.50,
        frost_landmark_event = 0.50, marsh_landmark_event = 0.50, dusk_landmark_event = 0.50,
    },
    poolColor = {
        landmark_event = { 0.45, 0.80, 1.00 }, highlands_landmark_event = { 0.62, 0.78, 1.00 },
        marsh_landmark_event = { 0.62, 1.00, 0.45 },
    },
}
