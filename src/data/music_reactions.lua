local STYLES = {
    dust = {
        shape = "dot", colors = { { 0.86, 0.76, 0.60 }, { 0.70, 0.62, 0.50 } },
        size = 1, vy = { 22, 34 }, gravity = 30, vmax = 70, vx = { -2, 2 },
        sway = { 0, 2 }, swayHz = 1.4, alpha = 0.75, life = 9,
    },
    feather = {
        shape = "feather", colors = { { 0.36, 0.30, 0.52 }, { 0.48, 0.40, 0.66 }, { 0.26, 0.20, 0.34 } },
        size = 1, vy = { 9, 15 }, gravity = 2, vmax = 18, vx = { -3, 3 },
        sway = { 8, 14 }, swayHz = 2.2, alpha = 0.95, life = 18,
    },
    pebble = {
        shape = "dot", colors = { { 0.34, 0.29, 0.25 }, { 0.24, 0.20, 0.18 } },
        size = { 1, 2 }, vy = { 30, 50 }, gravity = 180, vmax = 220, vx = { -4, 4 },
        alpha = 1, life = 4,
    },
    shard = {
        shape = "shard", colors = { { 0.78, 0.70, 1.00 }, { 0.58, 0.82, 1.00 }, { 0.92, 0.90, 1.00 } },
        size = { 1, 2 }, vy = { 40, 60 }, gravity = 120, vmax = 180, vx = { -2, 2 },
        alpha = 0.9, life = 5,
    },
    ember = {
        shape = "ember", colors = { { 1.00, 0.55, 0.18 }, { 1.00, 0.75, 0.30 }, { 0.95, 0.35, 0.10 } },
        size = 1, vy = { 14, 24 }, gravity = 8, vmax = 30, vx = { -4, 4 },
        sway = { 3, 7 }, swayHz = 2.8, alpha = 1, life = 10,
    },
    snow = {
        shape = "dot", colors = { { 0.92, 0.96, 1.00 }, { 0.78, 0.88, 1.00 } },
        size = 1, vy = { 12, 20 }, gravity = 3, vmax = 24, vx = { -3, 3 },
        sway = { 4, 9 }, swayHz = 1.8, alpha = 0.9, life = 16,
    },
    ice = {
        shape = "shard", colors = { { 0.70, 0.86, 1.00 }, { 0.90, 0.97, 1.00 } },
        size = { 1, 2 }, vy = { 40, 60 }, gravity = 130, vmax = 190, vx = { -2, 2 },
        alpha = 0.95, life = 5,
    },
    spore = {
        shape = "dot", colors = { { 0.55, 0.70, 0.36 }, { 0.36, 0.48, 0.24 } },
        size = 1, vy = { 10, 18 }, gravity = 4, vmax = 24, vx = { -2, 2 },
        sway = { 3, 6 }, swayHz = 1.2, alpha = 0.8, life = 16,
    },
    mote = {
        shape = "dot", colors = { { 0.85, 0.82, 0.78 }, { 0.62, 0.60, 0.62 } },
        size = 1, vy = { 10, 16 }, gravity = 3, vmax = 20, vx = { -2, 2 },
        sway = { 2, 5 }, swayHz = 1.0, alpha = 0.7, life = 16,
    },
}

local AREA = {
    [1] = { x0 = 40, x1 = 360, y0 = 16, y1 = 40, floor0 = 186, floor1 = 236 },
    [2] = { x0 = 60, x1 = 340, y0 = 16, y1 = 40, floor0 = 196, floor1 = 238 },
    [3] = { x0 = 40, x1 = 360, y0 = 16, y1 = 40, floor0 = 190, floor1 = 236 },
    [4] = { x0 = 50, x1 = 350, y0 = 16, y1 = 40, floor0 = 206, floor1 = 240 },
    [5] = { x0 = 80, x1 = 320, y0 = 16, y1 = 40, floor0 = 196, floor1 = 240 },
    [6] = { x0 = 150, x1 = 250, y0 = 16, y1 = 40, floor0 = 200, floor1 = 240 },
}

local SHAKE = { hit = 1.6, drop = 3.2, hitDur = 0.12, dropDur = 0.30 }
local LIGHT = { hit = 0.35, drop = 0.7, swell = 0.25, hitDur = 0.28, dropDur = 0.6 }

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
    DEFAULT = boss({ { "dust", 2, 4 } }, { { "dust", 8, 12 } }, { "dust", 2.5 }),
    BY_BOSS = {
        carrion_king = boss({ { "dust", 2, 3 }, { "feather", 0, 1 } },
            { { "feather", 4, 6 }, { "dust", 6, 10 } }, { "dust", 2.5 }),
        tower_lich = boss({ { "dust", 1, 3 }, { "shard", 0, 1 } },
            { { "shard", 4, 6 }, { "dust", 5, 8 } }, { "dust", 2 }),
        abyss_tyrant = boss({ { "pebble", 1, 2 }, { "ember", 1, 2 } },
            { { "pebble", 4, 6 }, { "ember", 5, 8 } }, { "ember", 3 }),
        winter_monarch = boss({ { "snow", 2, 4 }, { "ice", 0, 1 } },
            { { "ice", 3, 5 }, { "snow", 8, 12 } }, { "snow", 3 }),
        rot_colossus = boss({ { "spore", 2, 3 } }, { { "spore", 6, 9 }, { "dust", 3, 5 } },
            { "spore", 2 }),
        eclipse_queen = boss({ { "mote", 1, 3 } }, { { "mote", 6, 9 } }, { "mote", 2 }),
    },
}
