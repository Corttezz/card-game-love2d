return {
    fidgets = {
        { clip = "fidget_snap", fps = 12, weight = 2 },
        { clip = "fidget_spear", fps = 10, weight = 2 },
    },
    gap = { 3.5, 8.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 10 },
    },
    fx = {
        { kind = "drips", xr = 0.84, yr = 0.86, rate = 0.5, spread = 0.04 },
        { kind = "drips", xr = 0.47, yr = 0.70, rate = 0.4, spread = 0.08 },
        { kind = "flies", xr = 0.52, yr = 0.20, rate = 0.4, spread = 0.20 },
    },
}
