return {
    fidgets = {
        { clip = "fidget_blink", fps = 12, weight = 3 },
        { clip = "fidget_dart", fps = 10, weight = 2 },
        { clip = "fidget_curl", fps = 10, weight = 2 },
    },
    gap = { 2.5, 6 },
    fx = {
        { kind = "drips", xr = 0.48, yr = 0.95, rate = 0.6, spread = 0.5, dir = "down" },
        { kind = "embers", xr = 0.5, yr = 0.08, rate = 0.4, spread = 0.5, dir = "up" },
        { kind = "downdraft", xr = 0.5, yr = 1, spread = 0.55, strokes = { 11 } },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.5, yr = 0.15, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
