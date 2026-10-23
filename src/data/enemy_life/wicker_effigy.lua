return {
    fidgets = {
        { clip = "fidget_flare", fps = 10, weight = 2 },
        { clip = "fidget_turn", fps = 10, weight = 1 },
        { clip = "fidget_creak", fps = 10, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    fx = {
        { kind = "embers", xr = 0.32, yr = 0.34, rate = 0.80, spread = 0.05 },
        { kind = "embers", xr = 0.68, yr = 0.34, rate = 0.80, spread = 0.05 },
        { kind = "embers", xr = 0.50, yr = 0.55, rate = 0.60, spread = 0.06 },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8 },
    },
}
