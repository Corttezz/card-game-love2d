local Debug = require("src.core.Debug")

local ResumeFlow = {}

function ResumeFlow.plan(run)
    local node = run and run.currentNode
    local pending = run and run.pendingNodes
    local atFork = (pending ~= nil and #pending > 0)
    local nodeType = node and node.type
    return {
        nodeType = nodeType,
        atFork = atFork,
        bossInterior = (nodeType == "boss") and not atFork,
    }
end

local KNOWN = { cashout = true, rewards = true, rest = true, event = true, shop = true }
function ResumeFlow.stageAction(run)
    local stage = run and run.stage
    local pending = run and run.pendingNodes
    if pending and #pending > 0 then return "fork" end
    if stage == nil or stage == "battle" then return "battle" end
    if KNOWN[stage] then return stage end
    if stage ~= "event_done" and stage ~= "rest_done" and stage ~= "fork" then
        Debug.warn("[ResumeFlow] estagio desconhecido '" .. tostring(stage)
            .. "' — seguindo pra encruzilhada")
    end
    return "map"
end

function ResumeFlow.apply(game, scene)
    scene = scene or require("src.scenes.GameplayScene")
    local run = game and game.runManager and game.runManager.currentRun
    local plan = ResumeFlow.plan(run)

    if scene.resumeWorld then scene.resumeWorld(game) end

    if plan.bossInterior and scene._debugForceBossEntered then
        scene._debugForceBossEntered()
    end

    return plan
end

return ResumeFlow
