return {
    fidgets = {
        { clip = "fidget_scythe", fps = 10, weight = 2 },
        { clip = "fidget_tilt", fps = 10, weight = 1 },
        { clip = "fidget_gust", fps = 10, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    fx = {
        { kind = "glint", xr = 0.45, yr = 0.12, rate = 0.50, spread = 0.25 },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8 },
    },
}
