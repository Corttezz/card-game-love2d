return {
    fidgets = {
        { clip = "fidget_snort", fps = 10, weight = 2 },
        { clip = "fidget_paw", fps = 10, weight = 1 },
        { clip = "fidget_shake", fps = 10, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    fx = {
        { kind = "smoke", xr = 0.48, yr = 0.55, rate = 0.60, spread = 0.08, tint = { 0.80, 0.76, 0.70 } },
        { kind = "flies", xr = 0.50, yr = 0.40, rate = 0.40, spread = 0.40 },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8, fx = {
            { kind = "smoke", xr = 0.48, yr = 0.56, rate = 1.40, spread = 0.10, tint = { 0.85, 0.80, 0.74 } },
        } },
    },
}
