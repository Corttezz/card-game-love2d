local STYLES = {
    dust = {
        shape = "dot", colors = { { 0.86, 0.76, 0.60 }, { 0.70, 0.62, 0.50 } },
        size = { 1, 1.9 }, vy = { 3, 9 }, gravity = 38, vmax = 46, vx = { -1.5, 1.5 },
        sway = { 0, 1.5 }, swayHz = 1.4, alpha = 0.88, life = 9, streakGap = 1.3,
    },
    feather = {
        shape = "feather", colors = { { 0.58, 0.48, 0.84 }, { 0.70, 0.60, 0.94 }, { 0.44, 0.34, 0.64 } },
        size = { 2, 4 }, vy = { 4, 8 }, gravity = 2, vmax = 11, vx = { -2, 2 },
        sway = { 10, 16 }, swayHz = 1.1, alpha = 0.95, life = 20, rest = 1.5,
    },
    pebble = {
        shape = "dot", colors = { { 0.56, 0.49, 0.41 }, { 0.44, 0.38, 0.32 }, { 0.64, 0.57, 0.48 } },
        size = { 1, 3 }, big = { 0.08, { 4, 5 } },
        vy = { 0, 12 }, gravity = 230, vmax = 330, vx = { -5, 5 },
        bounce = 0.32, bounceMin = 40, puff = 4, puffColor = { 0.72, 0.64, 0.52 }, puffAlpha = 0.6,
        rest = 2.5, alpha = 1, life = 6,
    },
    shard = {
        shape = "shard", colors = { { 0.78, 0.70, 1.00 }, { 0.58, 0.82, 1.00 }, { 0.92, 0.90, 1.00 } },
        size = { 1, 2 }, vy = { 0, 10 }, gravity = 170, vmax = 260, vx = { -3, 3 },
        bounce = 0.26, bounceMin = 50, puff = 2, puffColor = { 0.62, 0.58, 0.80 }, puffAlpha = 0.45,
        rest = 0.9, alpha = 0.9, life = 5,
    },
    ember = {
        shape = "ember", colors = { { 1.00, 0.55, 0.18 }, { 1.00, 0.75, 0.30 }, { 0.95, 0.35, 0.10 } },
        size = 1, vy = { 4, 10 }, gravity = 10, vmax = 26, vx = { -4, 4 },
        sway = { 3, 7 }, swayHz = 2.8, alpha = 1, life = 10,
    },
    snow = {
        shape = "dot", colors = { { 0.92, 0.96, 1.00 }, { 0.78, 0.88, 1.00 } },
        size = { 1, 1.9 }, vy = { 3, 8 }, gravity = 4, vmax = 20, vx = { -3, 3 },
        sway = { 4, 9 }, swayHz = 1.8, alpha = 0.9, life = 16, rest = 0.6, streakGap = 2.2,
    },
    ice = {
        shape = "shard", colors = { { 0.70, 0.86, 1.00 }, { 0.90, 0.97, 1.00 } },
        size = { 1, 2 }, vy = { 0, 10 }, gravity = 180, vmax = 270, vx = { -3, 3 },
        bounce = 0.3, bounceMin = 50, puff = 2, puffColor = { 0.80, 0.90, 1.00 }, puffAlpha = 0.45,
        rest = 1.0, alpha = 0.95, life = 5,
    },
    spore = {
        shape = "dot", colors = { { 0.55, 0.70, 0.36 }, { 0.36, 0.48, 0.24 } },
        size = { 1, 1.9 }, vy = { 2, 6 }, gravity = 5, vmax = 20, vx = { -2, 2 },
        sway = { 3, 6 }, swayHz = 1.2, alpha = 0.8, life = 16, streakGap = 2.0,
    },
    mote = {
        shape = "dot", colors = { { 0.85, 0.82, 0.78 }, { 0.62, 0.60, 0.62 } },
        size = { 1, 1.9 }, vy = { 2, 6 }, gravity = 4, vmax = 18, vx = { -2, 2 },
        sway = { 2, 5 }, swayHz = 1.0, alpha = 0.7, life = 16, streakGap = 2.0,
    },
    air_dust = {
        shape = "dot", colors = { { 0.80, 0.70, 0.56 }, { 0.66, 0.58, 0.46 } },
        size = 1, vy = { 1.2, 3.0 }, vx = { -1, 1 }, sway = { 1, 2.5 }, swayHz = 0.45,
        alpha = 0.55, life = { 6, 10 },
    },
    air_ember = {
        shape = "dot", colors = { { 1.00, 0.62, 0.24 }, { 0.95, 0.45, 0.14 } },
        size = 1, vy = { -2.5, -0.8 }, vx = { -1.5, 1.5 }, sway = { 1.5, 3 }, swayHz = 0.6,
        alpha = 0.4, life = { 5, 9 },
    },
    air_snow = {
        shape = "dot", colors = { { 0.90, 0.95, 1.00 }, { 0.76, 0.86, 1.00 } },
        size = 1, vy = { 1.5, 3.5 }, vx = { -1.5, 1.5 }, sway = { 2, 4 }, swayHz = 0.5,
        alpha = 0.4, life = { 6, 10 },
    },
    air_spore = {
        shape = "dot", colors = { { 0.60, 0.76, 0.40 }, { 0.42, 0.56, 0.28 } },
        size = 1, vy = { 0.8, 2.2 }, vx = { -1, 1 }, sway = { 1.5, 3 }, swayHz = 0.4,
        alpha = 0.55, life = { 6, 10 },
    },
    air_mote = {
        shape = "dot", colors = { { 0.88, 0.84, 0.80 }, { 0.70, 0.66, 0.70 } },
        size = 1, vy = { 0.8, 2.0 }, vx = { -1, 1 }, sway = { 1, 2.5 }, swayHz = 0.35,
        alpha = 0.52, life = { 6, 10 },
    },
}

local AREA = {
    [1] = { x0 = 40, x1 = 360, y0 = 34, y1 = 62, floor0 = 186, floor1 = 236 },
    [2] = { x0 = 60, x1 = 340, y0 = 34, y1 = 62, floor0 = 196, floor1 = 238 },
    [3] = { x0 = 40, x1 = 360, y0 = 34, y1 = 62, floor0 = 190, floor1 = 236 },
    [4] = { x0 = 50, x1 = 350, y0 = 34, y1 = 62, floor0 = 206, floor1 = 240 },
    [5] = { x0 = 80, x1 = 320, y0 = 34, y1 = 62, floor0 = 196, floor1 = 240 },
    [6] = { x0 = 150, x1 = 250, y0 = 34, y1 = 62, floor0 = 200, floor1 = 240 },
}

local SHAKE = { hit = 1.6, drop = 3.2, hitDur = 0.12, dropDur = 0.30 }
local LIGHT = { hit = 0.45, drop = 0.7, swell = 0.25, hitDur = 0.32, dropDur = 0.6 }

local function boss(hit, drop, swell, extra)
    local r = { hit = hit, drop = drop, swell = swell, shake = SHAKE, light = LIGHT }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

return {
    STYLES = STYLES,
    AREA = AREA,
    COOLDOWN = { shake = 0.45, drop = 4.0, debris = 0.3, breath = 4.0 },
    REDUCED_LIGHT = 0.35,
    RAIN = { now = 0.35, spread = 1.0 },
    TRICKLE = { min = 0.6, max = 1.2 },
    DEFAULT = boss({ { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "dust", 0, 6, "streak" }, { "dust", 2, 5 } },
        { { "dust", 28, 44 }, { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "pebble", 4, 8 } },
        { "dust", 2.5 },
        { trickle = { "dust", 5, 8 }, ambient = { "air_dust", 12, 0.5 } }),
    BY_BOSS = {
        carrion_king = boss({ { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "dust", 0, 6, "streak" }, { "dust", 2, 5 }, { "feather", 0, 1 } },
            { { "dust", 28, 44 }, { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "feather", 2, 4 }, { "pebble", 4, 8 } },
            { "dust", 2.5 },
            { trickle = { "dust", 5, 8 }, ambient = { "air_dust", 12, 0.5 } }),
        tower_lich = boss({ { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "dust", 0, 6, "streak" }, { "dust", 2, 4 }, { "shard", 0, 1 } },
            { { "shard", 6, 10 }, { "dust", 24, 36 }, { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "pebble", 4, 6 } },
            { "dust", 2 },
            { trickle = { "dust", 5, 8 }, ambient = { "air_mote", 12, 0.5 } }),
        abyss_tyrant = boss({ { "pebble", 1, 3 }, { "ember", 2, 4 }, { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "dust", 0, 6, "streak" } },
            { { "pebble", 10, 16 }, { "ember", 8, 14 }, { "dust", 24, 36 }, { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" }, { "dust", 5, 8, "streak" } },
            { "ember", 3 },
            { trickle = { "dust", 5, 8 }, ambient = { "air_ember", 12, 0.5 } }),
        winter_monarch = boss({ { "snow", 4, 8 }, { "snow", 5, 8, "streak" }, { "snow", 5, 8, "streak" }, { "snow", 0, 6, "streak" }, { "ice", 0, 2 } },
            { { "ice", 6, 10 }, { "snow", 28, 40 }, { "snow", 5, 8, "streak" }, { "snow", 5, 8, "streak" }, { "snow", 5, 8, "streak" } }, { "snow", 3 },
            { trickle = { "snow", 5, 8 }, ambient = { "air_snow", 12, 0.5 } }),
        rot_colossus = boss({ { "spore", 4, 6 }, { "spore", 5, 8, "streak" }, { "spore", 5, 8, "streak" }, { "spore", 0, 6, "streak" } },
            { { "spore", 20, 28 }, { "dust", 12, 18 }, { "spore", 5, 8, "streak" }, { "spore", 5, 8, "streak" }, { "spore", 5, 8, "streak" }, { "pebble", 4, 6 } },
            { "spore", 2 },
            { trickle = { "spore", 5, 8 }, ambient = { "air_spore", 12, 0.5 } }),
        eclipse_queen = boss({ { "mote", 2, 6 }, { "mote", 5, 8, "streak" }, { "mote", 5, 8, "streak" }, { "mote", 0, 6, "streak" } },
            { { "mote", 20, 28 }, { "mote", 5, 8, "streak" }, { "mote", 5, 8, "streak" }, { "mote", 5, 8, "streak" } }, { "mote", 2 },
            { trickle = { "mote", 5, 8 }, ambient = { "air_mote", 10, 0.5 } }),
    },
}
