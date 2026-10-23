return {
    fidgets = {
        { clip = "fidget_runes", fps = 10, weight = 2 },
        { clip = "fidget_fists", fps = 10, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    fx = {
        { kind = "ash", xr = 0.45, yr = 0.50, rate = 0.30, spread = 0.40, dir = "down" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8 },
    },
}
