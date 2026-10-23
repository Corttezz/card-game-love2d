return {
    fidgets = {
        { clip = "fidget_flare", fps = 10, weight = 2 },
    },
    gap = { 3.5, 8.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 10 },
    },
    fx = {
        { kind = "embers", xr = 0.22, yr = 0.08, rate = 0.6, spread = 0.05, tint = { 0.72, 0.60, 0.95 }, dir = "up" },
        { kind = "embers", xr = 0.62, yr = 0.06, rate = 0.6, spread = 0.05, tint = { 0.72, 0.60, 0.95 }, dir = "up" },
        { kind = "smoke", xr = 0.38, yr = 0.88, rate = 0.5, spread = 0.25, tint = { 0.30, 0.24, 0.42 } },
    },
}
