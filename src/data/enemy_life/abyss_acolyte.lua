return {
    fidgets = {
        { clip = "fidget_pages", fps = 10, weight = 3 },
        { clip = "fidget_beckon", fps = 10, weight = 2 },
    },
    gap = { 3, 7 },
    fx = {
        { kind = "embers", xr = 0.24, yr = 0.12, rate = 1, spread = 0.08, dir = "up" },
        { kind = "smoke", xr = 0.24, yr = 0.14, rate = 0.4, spread = 0.05, dir = "up" },
        { kind = "ash", xr = 0.5, yr = 0.8, rate = 0.4, spread = 0.5, dir = "up" },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
    },
}
