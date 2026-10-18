local function landmarks(scorchR, scorchA, glowA)
    return {
        rest   = { scorch = { radius = scorchR, alpha = scorchA }, embers = true,
                   smoke = "thin", pulse = 0.18 },
        battle = { flagWave = true, dust = { rate = 0.4, alpha = 0.10 } },
        shop   = { windowGlow = { alpha = glowA or 0.22, spread = 1.4 }, smoke = "chimney" },
        event  = { lanternGlow = true },
        elite  = { runeFlicker = true },
        castle = { lowFog = true, hillShadow = true },
    }
end

return {
    fields = {
        grade = {
            day = { 1.00, 0.97, 0.90 }, dusk = { 0.92, 0.84, 0.94 },
            shadowTint = { 0.36, 0.22, 0.46 },
            satNear = 1.0, satFar = 0.45, contrastFar = 0.72,
            fog = { 0.55, 0.42, 0.28 }, fogNear = 0.0, fogFar = 0.45, fogCurve = 1.6,
        },
        contact = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.10, tuftsMin = 3, tuftsMax = 6, tuftScale = { 0.8, 1.2 } },
        lowFog = { alpha = 0.18, height = 0.09, drift = 0.02 },
        trees = { tint = 0.05, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.030, trunkSway = 0.010, bushSway = 0.040 },
        landmarks = landmarks(1.7, 0.55, 0.32),
    },
    highlands = {
        grade = {
            day = { 0.90, 0.92, 1.00 }, dusk = { 0.62, 0.66, 0.92 },
            shadowTint = { 0.30, 0.28, 0.52 },
            satNear = 0.95, satFar = 0.50, contrastFar = 0.58,
            fog = { 0.38, 0.34, 0.48 }, fogNear = 0.02, fogFar = 0.52, fogCurve = 1.5,
        },
        contact = { alpha = 0.50, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.09, tuftsMin = 2, tuftsMax = 5, tuftScale = { 0.7, 1.1 } },
        lowFog = { alpha = 0.26, height = 0.11, drift = 0.015 },
        trees = { tint = 0.04, scale = 0.07, flip = true, windPhase = true,
                  canopySway = 0.034, trunkSway = 0.012, bushSway = 0.045 },
        landmarks = landmarks(1.25, 0.45),
    },
    abyss = {
        grade = {
            day = { 1.00, 0.80, 0.68 }, dusk = { 0.86, 0.46, 0.36 },
            shadowTint = { 0.30, 0.10, 0.10 },
            satNear = 1.0, satFar = 0.62, contrastFar = 0.55,
            fog = { 0.55, 0.20, 0.10 }, fogNear = 0.0, fogFar = 0.40, fogCurve = 1.7,
        },
        contact = { alpha = 0.60, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.07, tuftsMin = 2, tuftsMax = 4, tuftScale = { 0.7, 1.0 } },
        lowFog = { alpha = 0.14, height = 0.07, drift = 0.03 },
        trees = { tint = 0.06, scale = 0.09, flip = true, windPhase = true,
                  canopySway = 0.016, trunkSway = 0.008, bushSway = 0.030 },
        landmarks = landmarks(1.5, 0.6),
    },
    frost = {
        grade = {
            day = { 0.90, 0.94, 1.00 }, dusk = { 0.64, 0.70, 0.90 },
            shadowTint = { 0.30, 0.38, 0.58 },
            satNear = 0.85, satFar = 0.45, contrastFar = 0.66,
            fog = { 0.55, 0.60, 0.68 }, fogNear = 0.04, fogFar = 0.55, fogCurve = 1.4,
        },
        contact = { alpha = 0.45, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.07, tuftsMin = 2, tuftsMax = 4, tuftScale = { 0.6, 1.0 } },
        lowFog = { alpha = 0.30, height = 0.12, drift = 0.012 },
        trees = { tint = 0.03, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.026, trunkSway = 0.008, bushSway = 0.030 },
        landmarks = landmarks(1.2, 0.5),
    },
    marsh = {
        grade = {
            day = { 0.86, 0.94, 0.80 }, dusk = { 0.60, 0.72, 0.58 },
            shadowTint = { 0.16, 0.24, 0.16 },
            satNear = 1.0, satFar = 0.55, contrastFar = 0.58,
            fog = { 0.38, 0.42, 0.24 }, fogNear = 0.03, fogFar = 0.50, fogCurve = 1.5,
        },
        contact = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.13, tuftsMin = 4, tuftsMax = 7, tuftScale = { 0.9, 1.4 } },
        lowFog = { alpha = 0.28, height = 0.10, drift = 0.018 },
        trees = { tint = 0.05, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.028, trunkSway = 0.010, bushSway = 0.050 },
        landmarks = landmarks(1.3, 0.45),
    },
    dusk = {
        grade = {
            day = { 1.00, 0.92, 0.80 }, dusk = { 0.78, 0.56, 0.70 },
            shadowTint = { 0.34, 0.18, 0.36 },
            satNear = 1.0, satFar = 0.60, contrastFar = 0.62,
            fog = { 0.72, 0.48, 0.22 }, fogNear = 0.0, fogFar = 0.42, fogCurve = 1.6,
        },
        contact = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.10, tuftsMin = 3, tuftsMax = 6, tuftScale = { 0.8, 1.2 } },
        lowFog = { alpha = 0.20, height = 0.09, drift = 0.02 },
        trees = { tint = 0.05, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.036, trunkSway = 0.012, bushSway = 0.045 },
        landmarks = landmarks(1.35, 0.5),
    },
}
