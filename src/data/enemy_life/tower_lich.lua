return {
    fidgets = {
        { clip = "fidget_orb", fps = 10, weight = 2 },
        { clip = "fidget_tilt", fps = 10, weight = 1 },
        { clip = "fidget_hand", fps = 10, weight = 1 },
    },
    gap = { 5.0, 10.0 },
    states = {
        poison = { clip = "state_poison", fps = 8 },
        enraged = { clip = "state_enraged", fps = 8, fx = {
            { kind = "frost", xr = 0.17, yr = 0.22, rate = 1.20, spread = 0.06 },
        } },
    },
}
