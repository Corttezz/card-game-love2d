local IntentVisibility = {}

local FogData = require("src.data.intent_fog")

IntentVisibility.LEVELS = { "full", "type_only", "hidden" }
IntentVisibility.RANK = { full = 3, type_only = 2, hidden = 1 }

local function isLevel(v) return IntentVisibility.RANK[v] ~= nil end

function IntentVisibility.worst(a, b)
    if not a then return b end
    if not b then return a end
    return (IntentVisibility.RANK[a] <= IntentVisibility.RANK[b]) and a or b
end

local function smooth(a, b, x)
    local t = math.min(1, math.max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
end
function IntentVisibility.fogCurve(prog)
    return 0.12 + 0.88 * (smooth(0, 1, prog) ^ 1.3)
end

function IntentVisibility.biomeIdFor(run)
    if not run then return nil end
    local a = run.actNumber or 1
    if run.endlessMode then
        a = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
    end
    a = ((a - 1) % 6) + 1
    local biomes = require("src.data.biomes")
    local list = biomes.list or biomes
    local b = list[a]
    return b and b.id or nil
end

function IntentVisibility.ruleFor(biomeId)
    return biomeId and FogData.biomes[biomeId] or nil
end

function IntentVisibility.contextFor(run, nodeType)
    if not run then return nil end
    local bid = IntentVisibility.biomeIdFor(run)
    local rule = IntentVisibility.ruleFor(bid)
    if not rule then return nil end
    nodeType = nodeType or (run.currentNode and run.currentNode.type) or "battle"
    local floor = run.floorInAct or 1
    local progress = math.min(1, math.max(0, (floor - 1) / 7))
    local ctx = { biomeId = bid, progress = progress, hall = (nodeType == "boss") }
    ctx.density = IntentVisibility.density(ctx)
    return ctx
end

function IntentVisibility.stormCurve(ctx)
    if not ctx then return 0 end
    if ctx.hall then return 1 end
    return smooth(0.60, 0.92, ctx.progress or 0)
end

function IntentVisibility.expectedShares(ctx)
    local d = IntentVisibility.density(ctx)
    local rule = ctx and IntentVisibility.ruleFor(ctx.biomeId) or nil
    local hidden = d * ((rule and rule.heavy) or 0) * IntentVisibility.stormCurve(ctx)
    return { full = 1 - d, type_only = d - hidden, hidden = hidden }
end

IntentVisibility.FOG_THRESHOLD = FogData.fogThreshold or 0.3

function IntentVisibility.density(ctx)
    if not ctx then return 0 end
    local rule = IntentVisibility.ruleFor(ctx.biomeId)
    if not rule then return 0 end
    if ctx.hall then return rule.hall or 0 end
    local k = IntentVisibility.fogCurve(ctx.progress or 0)
    local n = (k - 0.12) / 0.88
    return rule.base + (rule.peak - rule.base) * n
end

function IntentVisibility.resolve(enemy, roll)
    if not enemy then return "full", nil end
    if (enemy._revealTurns or 0) > 0 then
        enemy._revealTurns = enemy._revealTurns - 1
        return "full", "reveal"
    end
    roll = roll or function()
        return require("src.systems.Rng").get():random("misc")
    end
    local level, cause = "full", nil

    local ctx = enemy.fogContext
    local density = ctx and (ctx.density or IntentVisibility.density(ctx)) or 0
    if density > 0 then
        local rule = IntentVisibility.ruleFor(ctx.biomeId) or {}
        local r = roll()
        if r < density then
            local heavy = (rule.heavy or 0) * IntentVisibility.stormCurve(ctx)
            level = (r < density * heavy) and "hidden" or "type_only"
            cause = "fog"
        end
    end

    local veil = enemy.veilSpec and enemy:veilSpec() or nil
    if veil and isLevel(veil.level) then
        local chance = veil.chance or 1
        if chance >= 1 or roll() < chance then
            local before = level
            level = IntentVisibility.worst(level, veil.level)
            if level ~= before or cause == nil then cause = "veil" end
        end
    end

    return require("src.systems.CounterJokers").filterVisibility(enemy, level, cause)
end

local active = nil

function IntentVisibility.noteActive(enemy) active = enemy end
function IntentVisibility.activeEnemy() return active end
function IntentVisibility.reset() active = nil end

local function fogOf(e, wantHall)
    if not e or not e.fogContext then return 0 end
    if (e.fogContext.hall == true) ~= wantHall then return 0 end
    if e.isAlive and not e:isAlive() then return 0 end
    local lvl = e.intentVisibility or "full"
    return (FogData.worldBoost or {})[lvl] or 0
end
function IntentVisibility.worldFog() return fogOf(active, false) end
function IntentVisibility.hallFog() return fogOf(active, true) end

local VEIL_DEFAULT = { 0.62, 0.52, 0.72 }
function IntentVisibility.veilColor(enemy)
    local ctx = enemy and enemy.fogContext
    local rule = ctx and IntentVisibility.ruleFor(ctx.biomeId)
    return (rule and rule.color) or VEIL_DEFAULT
end

do
    local ok, WeatherEngine = pcall(require, "engine.WeatherEngine")
    if ok and type(WeatherEngine) == "table" then
        WeatherEngine.fogHook = IntentVisibility.worldFog
    end
    local okI, InteriorFX = pcall(require, "src.ui.InteriorFX")
    if okI and type(InteriorFX) == "table" then
        InteriorFX.fogHook = IntentVisibility.hallFog
    end
end

return IntentVisibility
