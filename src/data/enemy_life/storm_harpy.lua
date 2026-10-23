return {
    fidgets = {
        { clip = "fidget_shriek", fps = 10, weight = 2 },
        { clip = "fidget_flap", fps = 10, weight = 1 },
        { clip = "fidget_twitch", fps = 12, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    fx = {
        { kind = "glint", xr = 0.50, yr = 0.30, rate = 0.30, spread = 0.80, tint = { 0.75, 0.92, 1.00 } },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8 },
    },
}
