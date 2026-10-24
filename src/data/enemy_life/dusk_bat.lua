return {
    fidgets = {
        { clip = "fidget_screech", fps = 12, weight = 2 },
        { clip = "fidget_stretch", fps = 10, weight = 1 },
    },
    gap = { 3.0, 7.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 10 },
    },
    fx = {
        { kind = "downdraft", xr = 0.50, yr = 1, spread = 0.55, strokes = { 7 } },
    },
}
