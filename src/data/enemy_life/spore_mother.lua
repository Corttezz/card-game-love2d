return {
    fidgets = {
        { clip = "fidget_puff", fps = 10, weight = 2 },
        { clip = "fidget_tilt", fps = 10, weight = 2 },
        { clip = "fidget_roots", fps = 9, weight = 1 },
    },
    gap = { 4.0, 9.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 9 },
    },
    fx = {
        { kind = "spores", xr = 0.50, yr = 0.30, rate = 0.9, spread = 0.36 },
        { kind = "drips", xr = 0.50, yr = 0.36, rate = 0.6, spread = 0.30, tint = { 0.45, 0.95, 0.60 } },
    },
}
