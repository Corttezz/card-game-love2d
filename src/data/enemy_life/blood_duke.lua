return {
    fidgets = {
        { clip = "fidget_fangs", fps = 10, weight = 2 },
        { clip = "fidget_blink", fps = 12, weight = 3 },
    },
    gap = { 4.0, 9.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        weak = { clip = "state_weak", fps = 7 },
        enraged = { clip = "state_enraged", fps = 10 },
    },
    fx = {
        { kind = "mist", xr = 0.45, yr = 0.92, rate = 0.6, spread = 0.35, tint = { 0.40, 0.10, 0.16 }, dir = "side" },
    },
}
