return {
    fidgets = {
        { clip = "fidget_snarl", fps = 11, weight = 3 },
        { clip = "fidget_sniff", fps = 10, weight = 2 },
        { clip = "fidget_shake", fps = 12, weight = 1 },
    },
    gap = { 2.5, 6 },
    fx = {
        { kind = "embers", xr = 0.3, yr = 0.06, rate = 1.2, spread = 0.3, dir = "up" },
        { kind = "embers", xr = 0.9, yr = 0.1, rate = 0.6, spread = 0.05, dir = "up" },
        { kind = "smoke", xr = 0.16, yr = 0.4, rate = 0.5, spread = 0.05, dir = "up" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.3, yr = 0.2, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
