return {
    fidgets = {
        { clip = "fidget_flex", fps = 10, weight = 2 },
        { clip = "fidget_glare", fps = 9, weight = 2 },
        { clip = "fidget_cape", fps = 10, weight = 1 },
    },
    gap = { 3, 7 },
    fx = {
        { kind = "embers", xr = 0.5, yr = 0.55, rate = 0.8, spread = 0.5, dir = "up" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.49, yr = 0.15, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
