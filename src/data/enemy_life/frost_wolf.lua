return {
    fidgets = {
        { clip = "fidget_sniff", fps = 10, weight = 2 },
        { clip = "fidget_shake", fps = 12, weight = 2 },
        { clip = "fidget_snarl", fps = 11, weight = 2 },
    },
    gap = { 2.5, 6 },
    fx = {
        { kind = "frost", xr = 0.12, yr = 0.46, rate = 1, spread = 0.05, dir = "side" },
        { kind = "mist", xr = 0.45, yr = 0.95, rate = 0.5, spread = 0.5, dir = "side" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.3, yr = 0.18, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
