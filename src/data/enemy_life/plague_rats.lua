return {
    fidgets = {
        { clip = "fidget_squirm", fps = 10, weight = 2 },
        { clip = "fidget_hiss", fps = 12, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    fx = {
        { kind = "flies", xr = 0.50, yr = 0.35, rate = 0.80, spread = 0.45 },
    },
    states = {
        poison = { clip = "state_poison", fps = 8, fx = {
            { kind = "drips", xr = 0.50, yr = 0.70, rate = 1.00, spread = 0.40 },
        } },
        weak = { clip = "state_weak", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8, fx = {
            { kind = "smoke", xr = 0.70, yr = 0.30, rate = 0.80, spread = 0.20, tint = { 0.80, 0.78, 0.72 } },
        } },
    },
}
