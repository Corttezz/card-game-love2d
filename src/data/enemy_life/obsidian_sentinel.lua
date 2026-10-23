return {
    fidgets = {
        { clip = "fidget_look", fps = 9, weight = 2 },
        { clip = "fidget_flex", fps = 10, weight = 2 },
    },
    gap = { 3.5, 8 },
    fx = {
        { kind = "embers", xr = 0.34, yr = 0.4, rate = 0.8, spread = 0.35, dir = "up" },
        { kind = "smoke", xr = 0.34, yr = 0.3, rate = 0.4, spread = 0.3, dir = "up" },
    },
    states = {
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.49, yr = 0.22, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
