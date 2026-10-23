return {
    fidgets = {
        { clip = "fidget_censer", fps = 10, weight = 2 },
        { clip = "fidget_chant", fps = 10, weight = 1 },
        { clip = "fidget_tilt", fps = 12, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    fx = {
        { kind = "smoke", xr = 0.22, yr = 0.68, rate = 0.80, spread = 0.04, tint = { 0.70, 0.60, 0.85 }, dir = "up" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8 },
    },
}
