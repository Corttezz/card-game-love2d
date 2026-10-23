return {
    fidgets = {
        { clip = "fidget_snort", fps = 10, weight = 2 },
        { clip = "fidget_flex", fps = 10, weight = 2 },
        { clip = "fidget_shake", fps = 10, weight = 1 },
    },
    gap = { 4.5, 9.5 },
    states = {
        poison = { clip = "state_poison", fps = 7 },
        weak = { clip = "state_weak", fps = 6 },
        enraged = { clip = "state_enraged", fps = 9 },
    },
    fx = {
        { kind = "mist", xr = 0.45, yr = 0.92, rate = 0.5, spread = 0.40, dir = "side" },
    },
}
