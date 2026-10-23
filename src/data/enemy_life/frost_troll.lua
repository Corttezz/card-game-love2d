return {
    fidgets = {
        { clip = "fidget_snort", fps = 10, weight = 3 },
        { clip = "fidget_scratch", fps = 10, weight = 2 },
    },
    gap = { 3, 7 },
    fx = {
        { kind = "frost", xr = 0.64, yr = 0.36, rate = 0.6, spread = 0.05, dir = "side" },
        { kind = "mist", xr = 0.5, yr = 0.95, rate = 0.5, spread = 0.5, dir = "side" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
    },
}
