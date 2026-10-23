return {
    fidgets = {
        { clip = "fidget_blink", fps = 12, weight = 3 },
        { clip = "fidget_shift", fps = 10, weight = 1 },
    },
    gap = { 3.0, 7.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 10 },
    },
    fx = {
        { kind = "drips", xr = 0.53, yr = 0.32, rate = 0.8, spread = 0.03 },
        { kind = "bubbles", xr = 0.73, yr = 0.18, rate = 0.5, spread = 0.06 },
        { kind = "flies", xr = 0.50, yr = 0.10, rate = 0.6, spread = 0.25 },
    },
}
