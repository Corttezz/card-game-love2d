return {
    fidgets = {
        { clip = "fidget_grip", fps = 10, weight = 2 },
        { clip = "fidget_look", fps = 10, weight = 1 },
        { clip = "fidget_twitch", fps = 12, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    fx = {
        { kind = "flies", xr = 0.50, yr = 0.45, rate = 0.50, spread = 0.30 },
    },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8 },
    },
}
