return {
    fidgets = {
        { clip = "fidget_gape", fps = 10, weight = 2 },
    },
    gap = { 3.5, 8.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 10 },
    },
    fx = {
        { kind = "drips", xr = 0.13, yr = 0.78, rate = 0.7, spread = 0.04 },
        { kind = "drips", xr = 0.87, yr = 0.75, rate = 0.6, spread = 0.04 },
        { kind = "bubbles", xr = 0.47, yr = 0.24, rate = 0.4, spread = 0.05 },
    },
}
