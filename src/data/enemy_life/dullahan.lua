return {
    fidgets = {
        { clip = "fidget_raise", fps = 10, weight = 2 },
        { clip = "fidget_gust", fps = 10, weight = 1 },
    },
    gap = { 4.0, 9.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 10 },
    },
    fx = {
        { kind = "embers", xr = 0.52, yr = 0.06, rate = 0.8, spread = 0.05, tint = { 0.62, 0.40, 0.95 }, dir = "up" },
        { kind = "embers", xr = 0.71, yr = 0.30, rate = 0.5, spread = 0.04, tint = { 0.62, 0.40, 0.95 }, dir = "up" },
    },
}
