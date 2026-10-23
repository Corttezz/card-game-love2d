return {
    fidgets = {
        { clip = "fidget_tap", fps = 10, weight = 2 },
        { clip = "fidget_mutter", fps = 10, weight = 2 },
    },
    gap = { 2.5, 6 },
    fx = {
        { kind = "glint", xr = 0.82, yr = 0.12, rate = 0.8, spread = 0.05 },
        { kind = "frost", xr = 0.82, yr = 0.16, rate = 0.6, spread = 0.08, dir = "down" },
        { kind = "mist", xr = 0.45, yr = 0.95, rate = 0.4, spread = 0.45, dir = "side" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
    },
}
