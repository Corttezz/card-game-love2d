local Instant = {}

Instant.DT = 1.0

Instant.MAX_ITERS = 400

Instant.stats = { drains = 0, iters = 0, stalls = 0 }

local EM = require("engine.EventManager")

local function tickWorld(game, dt)
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if okER and ER.update then ER.update(dt) end
    if game.enemy and game.enemy.update then game.enemy:update(dt) end
    if game.combatAnimationSystem and game.combatAnimationSystem.update then
        game.combatAnimationSystem:update(dt)
    end
end

function Instant.drain(game)
    local dt = Instant.DT
    local cs = game.combatAnimationSystem
    local n = 0
    while true do
        n = n + 1
        EM.update(dt)
        tickWorld(game, dt)
        local busy = EM.pendingCount() > 0
            or (cs and cs.isBlocking and cs:isBlocking())
        if not busy then break end
        if n >= Instant.MAX_ITERS then
            Instant.stats.stalls = Instant.stats.stalls + 1
            print(("[instant_engine] fila nao esvaziou em %d saltos (%d eventos pendentes, "
                .. "combate %s) — abandonando o dreno. Isto e BUG de cadeia."):format(
                n, EM.pendingCount(), tostring(cs and cs:isBlocking())))
            break
        end
    end
    Instant.stats.drains = Instant.stats.drains + 1
    Instant.stats.iters = Instant.stats.iters + n
    return n
end

function Instant.makePump(drainPresentation)
    return function(game, _secs)
        if drainPresentation then drainPresentation() end
        return Instant.drain(game)
    end
end

function Instant.install(Autoplay)
    Autoplay = Autoplay or require("tools.autoplay")
    if Autoplay.pumpImpl and Autoplay.pumpImpl.__instant then return Autoplay end
    local pump = Instant.makePump(Autoplay.drainPresentation)
    Autoplay.pumpImpl = setmetatable({ __instant = true }, { __call = function(_, g, s) return pump(g, s) end })
    Autoplay.clockMode = "instant"
    return Autoplay
end

function Instant.uninstall(Autoplay)
    Autoplay = Autoplay or require("tools.autoplay")
    Autoplay.pumpImpl = nil
    Autoplay.clockMode = "frames"
    return Autoplay
end

function Instant.resetStats()
    Instant.stats = { drains = 0, iters = 0, stalls = 0 }
end

return Instant
