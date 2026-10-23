return {
    fidgets = {
        { clip = "fidget_shiver", fps = 10, weight = 2 },
        { clip = "fidget_tilt", fps = 9, weight = 2 },
    },
    gap = { 4.5, 9.5 },
    states = {
        poison = { clip = "state_poison", fps = 7 },
        weak = { clip = "state_weak", fps = 6 },
        enraged = { clip = "state_enraged", fps = 9 },
    },
    fx = {
        { kind = "mist", xr = 0.50, yr = 0.94, rate = 0.5, spread = 0.40, tint = { 0.30, 0.16, 0.42 }, dir = "side" },
    },
}
