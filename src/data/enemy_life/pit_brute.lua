return {
    fidgets = {
        { clip = "fidget_snort", fps = 10, weight = 3 },
        { clip = "fidget_regrip", fps = 10, weight = 2 },
    },
    gap = { 3, 7 },
    fx = {
        { kind = "embers", xr = 0.5, yr = 0.38, rate = 0.8, spread = 0.45, dir = "up" },
        { kind = "smoke", xr = 0.51, yr = 0.24, rate = 0.4, spread = 0.05, dir = "up" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.51, yr = 0.15, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
