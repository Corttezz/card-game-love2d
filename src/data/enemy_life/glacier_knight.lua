return {
    fidgets = {
        { clip = "fidget_look", fps = 9, weight = 2 },
        { clip = "fidget_shrug", fps = 10, weight = 1 },
    },
    gap = { 3.5, 8 },
    fx = {
        { kind = "frost", xr = 0.25, yr = 0.2, rate = 0.6, spread = 0.06, dir = "up" },
        { kind = "frost", xr = 0.62, yr = 0.2, rate = 0.6, spread = 0.06, dir = "up" },
        { kind = "mist", xr = 0.4, yr = 0.94, rate = 0.5, spread = 0.5, dir = "side" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.49, yr = 0.22, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
