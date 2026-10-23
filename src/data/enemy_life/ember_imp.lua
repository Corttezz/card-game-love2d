return {
    fidgets = {
        { clip = "fidget_tailflick", fps = 12, weight = 3 },
        { clip = "fidget_cackle", fps = 11, weight = 2 },
    },
    gap = { 2.5, 6 },
    fx = {
        { kind = "embers", xr = 0.47, yr = 0.08, rate = 1.2, spread = 0.18, dir = "up" },
        { kind = "embers", xr = 0.86, yr = 0.1, rate = 0.6, spread = 0.06, dir = "up" },
        { kind = "ash", xr = 0.5, yr = 0.2, rate = 0.5, spread = 0.4, dir = "up" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.45, yr = 0.15, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
