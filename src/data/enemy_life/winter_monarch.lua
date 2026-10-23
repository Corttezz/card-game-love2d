return {
    fidgets = {
        { clip = "fidget_cape", fps = 10, weight = 2 },
        { clip = "fidget_glare", fps = 9, weight = 1 },
    },
    gap = { 3, 7 },
    fx = {
        { kind = "glint", xr = 0.16, yr = 0.17, rate = 0.8, spread = 0.05 },
        { kind = "frost", xr = 0.5, yr = 0.4, rate = 0.8, spread = 0.5, dir = "down" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 11, fx = { { kind = "smoke", xr = 0.45, yr = 0.12, rate = 0.8, spread = 0.06, dir = "up" } } },
    },
}
