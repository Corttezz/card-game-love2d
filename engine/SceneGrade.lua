local LightEngine = require("engine.LightEngine")
local DATA = require("src.data.scene_integration")

local SceneGrade = {}

SceneGrade.FAMILIES = {
    "ground", "road", "grass", "prop", "tree", "rock", "landmark",
    "castle", "mountain", "enemy", "luminaire", "critter",
}

SceneGrade.KIND_FAMILY = {
    tree = "tree", pine = "tree", deadtree = "tree", bush = "tree",
    rock = "rock", ruin = "rock",
    stump = "prop", fence = "prop", sign = "prop", flowers = "prop", tuft = "prop",
}

local NO_GRADE = { mountain = true }
local CONTRAST_REACH = 0.25
SceneGrade.FAMILY_DEPTH = { landmark = 0.35, enemy = 0.35 }

local S = {
    bid = "fields", stamp = -1, fromBid = nil, blendK = 1,
    tr = 1, tg = 1, tb = 1,
    shr = 0, shg = 0, shb = 0,
    satNear = 1, satFar = 1, contrastFar = 1,
    fr = 1, fg = 1, fb = 1, fogNear = 0, fogFar = 0, fogCurve = 1,
    ar = 1, ag = 1, ab = 1,
    liftRef = 0, maxLift = 1,
    groundFar = 1, groundReach = 0.6, treeGain = 1, tnr = 1, tng = 1, tnb = 1,
    tdNear = 0.6, tdFar = 0.3, tdSat = 1, tdBright = 1, tdFog = 0,
    depth = 1,
}

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function lerp(a, b, k) return a + (b - a) * k end

local function gradeOf(bid)
    local e = DATA[bid] or DATA.fields
    return e.grade
end

local function resolve(g, tod, into)
    into.tr = lerp(g.day[1], g.dusk[1], tod)
    into.tg = lerp(g.day[2], g.dusk[2], tod)
    into.tb = lerp(g.day[3], g.dusk[3], tod)
    into.shr, into.shg, into.shb = g.shadowTint[1], g.shadowTint[2], g.shadowTint[3]
    into.satNear, into.satFar = g.satNear, g.satFar
    into.contrastFar = lerp(g.contrastFarDay or g.contrastFar, g.contrastFar, tod)
    local fd = g.fogDusk or g.fog
    into.fr = math.min(1.6, lerp(g.fog[1], fd[1], tod) * 1.9)
    into.fg = math.min(1.6, lerp(g.fog[2], fd[2], tod) * 1.9)
    into.fb = math.min(1.6, lerp(g.fog[3], fd[3], tod) * 1.9)
    into.fogNear, into.fogFar, into.fogCurve = g.fogNear, g.fogFar, g.fogCurve
    into.liftRef, into.maxLift = g.liftRef or 0, g.maxLift or 1
    into.groundFar, into.groundReach = g.groundFar or 1, g.groundReach or 0.6
    into.treeGain = g.treeGain or 1
    local tn = g.treeNear
    into.tnr, into.tng, into.tnb = tn and tn[1] or 1, tn and tn[2] or 1, tn and tn[3] or 1
    local td = g.treeDepth
    into.tdNear, into.tdFar = td and td.near or 0.6, td and td.far or 0.3
    into.tdSat, into.tdBright, into.tdFog = td and td.sat or 1, td and td.bright or 1, td and td.fog or 0
    return into
end

local prevLine = {}
local FIELDS = { "tr", "tg", "tb", "shr", "shg", "shb", "satNear", "satFar",
                 "contrastFar", "fr", "fg", "fb", "fogNear", "fogFar", "fogCurve",
                 "liftRef", "maxLift", "groundFar", "groundReach", "treeGain", "tnr", "tng", "tnb",
                 "tdNear", "tdFar", "tdSat", "tdBright", "tdFog" }

function SceneGrade.begin(bid, tod, fromBid, blendK, amb)
    tod = clamp01(tod or 1)
    S.bid = DATA[bid] and bid or "fields"
    S.fromBid = (fromBid and DATA[fromBid]) and fromBid or nil
    S.blendK = blendK or 1
    resolve(gradeOf(S.bid), tod, S)
    if fromBid and DATA[fromBid] and blendK and blendK < 1 then
        resolve(gradeOf(fromBid), tod, prevLine)
        local k = clamp01(blendK)
        for i = 1, #FIELDS do
            local f = FIELDS[i]
            S[f] = lerp(prevLine[f], S[f], k)
        end
    end
    if amb then
        S.ar, S.ag, S.ab = amb[1] or 1, amb[2] or 1, amb[3] or 1
    else
        S.ar, S.ag, S.ab = LightEngine.ambientColor()
    end
    S.stamp = love.timer.getTime()
end

function SceneGrade.isActive()
    return (love.timer.getTime() - S.stamp) < 0.1
end

function SceneGrade.biome() return S.bid end

function SceneGrade.familyOf(kind, isLuminaire)
    if isLuminaire then return "luminaire" end
    return SceneGrade.KIND_FAMILY[kind] or "prop"
end

function SceneGrade.fogAlpha(t)
    t = clamp01(t or 1)
    return S.fogNear + (S.fogFar - S.fogNear) * ((1 - t) ^ S.fogCurve)
end

function SceneGrade.fogColor() return S.fr, S.fg, S.fb end
function SceneGrade.fogParams() return S.fogNear, S.fogFar, S.fogCurve end
function SceneGrade.ground() return S.groundFar, S.groundReach end
function SceneGrade.shadowTint() return S.shr, S.shg, S.shb end

function SceneGrade.color(family, t, out)
    out = out or {}
    if NO_GRADE[family] or not SceneGrade.isActive() then
        out[1], out[2], out[3] = 1, 1, 1
        return out
    end
    t = clamp01(t or 1)
    local fk = SceneGrade.FAMILY_DEPTH[family]
    if fk then t = 1 - (1 - t) * fk end
    local r, g, b = S.tr, S.tg, S.tb
    local fa = SceneGrade.fogAlpha(t)
    local dk = 0
    if family == "tree" then
        dk = clamp01((S.tdNear - t) / math.max(1e-3, S.tdNear - S.tdFar))
        fa = 1 - (1 - fa) * (1 - dk * S.tdFog)
    end
    r, g, b = lerp(r, S.fr, fa), lerp(g, S.fg, fa), lerp(b, S.fb, fa)
    local sat = lerp(S.satFar, S.satNear, t) * lerp(1, S.tdSat, dk)
    local l = 0.299 * r + 0.587 * g + 0.114 * b
    r, g, b = lerp(l, r, sat), lerp(l, g, sat), lerp(l, b, sat)
    local bright = lerp(S.contrastFar, 1, math.min(1, t / CONTRAST_REACH))
    if family == "tree" then
        local k = math.min(1, t / 0.6)
        bright = bright * lerp(1, S.treeGain, k) * lerp(1, S.tdBright, dk)
        r, g, b = r * lerp(1, S.tnr, k), g * lerp(1, S.tng, k), b * lerp(1, S.tnb, k)
    end
    out[1] = clamp01(r * bright)
    out[2] = clamp01(g * bright)
    out[3] = clamp01(b * bright)
    return out
end

function SceneGrade.flatColor(family, out)
    out = out or {}
    local l = 0.299 * S.ar + 0.587 * S.ag + 0.114 * S.ab
    local k = 1
    if S.liftRef > 0 and l > 0 then k = math.min(S.maxLift, math.max(1, S.liftRef / l)) end
    out[1], out[2], out[3] = math.min(1, S.ar * k), math.min(1, S.ag * k), math.min(1, S.ab * k)
    return out
end

function SceneGrade.cfg(section)
    local id = S.bid
    if S.fromBid and S.blendK < 0.5 then id = S.fromBid end
    local e = DATA[id] or DATA.fields
    return e[section]
end

function SceneGrade.setDepth(t) S.depth = clamp01(t or 1) end
function SceneGrade.depth() return S.depth end

return SceneGrade
