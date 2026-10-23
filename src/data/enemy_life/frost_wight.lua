return {
    fidgets = {
        { clip = "fidget_tilt", fps = 9, weight = 2 },
        { clip = "fidget_claws", fps = 10, weight = 2 },
        { clip = "fidget_gust", fps = 11, weight = 1 },
    },
    gap = { 3, 7 },
    fx = {
        { kind = "frost", xr = 0.38, yr = 0.5, rate = 0.8, spread = 0.4, dir = "down" },
        { kind = "mist", xr = 0.38, yr = 0.92, rate = 0.6, spread = 0.5, dir = "side" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.45, yr = 0.12, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
