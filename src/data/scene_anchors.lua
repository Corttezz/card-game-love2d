local Debug = require("src.core.Debug")

local SceneBackground = require("src.ui.SceneBackground")

local SceneAnchors = {}

SceneAnchors.DEFAULT = {
    xr = 0.5, yr = 0.76,
    shadowA = 1.0, lightXr = 0.5, lightBehind = true,
}

SceneAnchors.BY_SCENE = {
    castle_hall_1 = { xr = 0.50, yr = 0.78, backYr = 0.72,
                      shadowA = 1.00, lightXr = 0.5, lightBehind = true },

    castle_hall_2 = { xr = 0.50, yr = 0.83, backYr = 0.83, deathYr = 0.885,
                      shadowA = 0.92, lightXr = 0.5, lightBehind = true },

    castle_hall_3 = { xr = 0.50, yr = 0.78, backYr = 0.73,
                      shadowA = 0.75, lightXr = 0.5, lightBehind = true },

    castle_hall_4 = { xr = 0.50, yr = 0.78, backYr = 0.75,
                      shadowA = 0.85, lightXr = 0.5, lightBehind = true },

    castle_hall_5 = { xr = 0.50, yr = 0.82, backYr = 0.79,
                      shadowA = 0.55, lightXr = 0.5, lightBehind = true },

    castle_hall_6 = { xr = 0.50, yr = 0.78, backYr = 0.75,
                      shadowA = 0.95, lightXr = 0.5, lightBehind = true },

    catacumbs   = { xr = 0.50, yr = 0.80, shadowA = 0.95,
                    lightXr = 0.5, lightBehind = true },
    stone_tower = { xr = 0.50, yr = 0.82, shadowA = 0.90,
                    lightXr = 0.5, lightBehind = true },
    abyss       = { xr = 0.50, yr = 0.80, shadowA = 0.60,
                    lightXr = 0.5, lightBehind = false },
    gameplay    = { xr = 0.50, yr = 0.76, shadowA = 1.00,
                    lightXr = 0.5, lightBehind = true },
}

local warned = {}

function SceneAnchors.get(scene)
    local a = scene and SceneAnchors.BY_SCENE[scene]
    if not a then
        if scene and not warned[scene] then
            warned[scene] = true
            Debug.warn("[scene_anchors] AVISO: cena '" .. tostring(scene)
                .. "' sem linha de chão declarada — usando o padrão "
                .. "(yr=0.76). Declare em src/data/scene_anchors.lua.")
        end
        return SceneAnchors.DEFAULT
    end
    return a
end

function SceneAnchors.groundAnchor(scene, width, height, yrOverride)
    local a = SceneAnchors.get(scene)
    local yr = yrOverride or a.yr
    local tr = SceneBackground.getCoverTransform(scene, width, height)
    if not tr then
        return math.floor(width * a.xr), math.floor(height * yr)
    end
    return math.floor(tr.ox + a.xr * tr.dw),
           math.floor(tr.oy + yr * tr.dh)
end

SceneAnchors.HORIZON_YR = 0.42

function SceneAnchors.depthSizeK(scene, width, height, fromY, toY, exp)
    local a = SceneAnchors.get(scene)
    local _, hy = SceneAnchors.groundAnchor(scene, width, height,
        a.horizonYr or SceneAnchors.HORIZON_YR)
    if not fromY or not toY or fromY <= hy or toY >= fromY then return 1 end
    local k = math.max(0, toY - hy) / (fromY - hy)
    return math.max(0.5, math.min(1, k ^ (exp or 1)))
end

return SceneAnchors
