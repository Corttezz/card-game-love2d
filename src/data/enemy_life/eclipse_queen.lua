return {
    fidgets = {
        { clip = "fidget_sway", fps = 8, weight = 3 },
    },
    gap = { 5.5, 10.5 },
    states = {
        poison = { clip = "state_poison", fps = 7 },
        weak = { clip = "state_weak", fps = 6 },
        enraged = { clip = "state_enraged", fps = 8 },
    },
    fx = {
        { kind = "downdraft", xr = 0.50, yr = 1, spread = 0.60, strokes = { 5 } },
        { kind = "mist", xr = 0.50, yr = 0.94, rate = 0.5, spread = 0.40, tint = { 0.92, 0.62, 0.26 }, dir = "side" },
    },
}
