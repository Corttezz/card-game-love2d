return {
    fidgets = {
        { clip = "fidget_twitch", fps = 12, weight = 2 },
        { clip = "fidget_sniff", fps = 10, weight = 2 },
        { clip = "fidget_claw", fps = 9, weight = 1 },
    },
    gap = { 3.5, 8.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 10 },
    },
    fx = {
        { kind = "drips", xr = 0.22, yr = 0.69, rate = 0.6, spread = 0.03 },
        { kind = "drips", xr = 0.55, yr = 0.69, rate = 0.5, spread = 0.03 },
        { kind = "flies", xr = 0.39, yr = 0.20, rate = 0.5, spread = 0.20 },
    },
}
