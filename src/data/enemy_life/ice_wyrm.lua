return {
    fidgets = {
        { clip = "fidget_hiss", fps = 11, weight = 3 },
        { clip = "fidget_look", fps = 9, weight = 1 },
    },
    gap = { 2.5, 6 },
    fx = {
        { kind = "frost", xr = 0.86, yr = 0.22, rate = 1, spread = 0.06, dir = "side" },
        { kind = "mist", xr = 0.5, yr = 0.92, rate = 0.5, spread = 0.5, dir = "side" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.7, yr = 0.12, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
