return {
    fidgets = {
        { clip = "fidget_screech", fps = 10, weight = 2 },
        { clip = "fidget_flap", fps = 10, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    fx = {
        { kind = "glint", xr = 0.77, yr = 0.12, rate = 0.60, spread = 0.06, tint = { 0.55, 0.93, 0.95 } },
        { kind = "glint", xr = 0.22, yr = 0.66, rate = 0.60, spread = 0.06, tint = { 0.55, 0.93, 0.95 } },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8 },
    },
}
