local Sfx = require("src.systems.Sfx")

local JokerProcFx = {}

function JokerProcFx.tick(proc, ordinal)
    if not proc then return end
    ordinal = ordinal or 1

    local joker = proc.joker
    local g = _G.game
    if g and g.jokerSlots and proc.slotIndex and g.jokerSlots[proc.slotIndex] then
        joker = g.jokerSlots[proc.slotIndex]
    end

    if joker then
        if joker.hop_up then joker:hop_up(26, 0.45) end
        if joker.swell_up then joker:swell_up(0.30, 0.45) end
        if joker.juice_up then joker:juice_up(0.5, -0.22) end
    end
    if require("src.core.Debug").enabled then pcall(love.filesystem.append, "feel_debug.log",
        ("[FEEL] JOKER-TICK slot=%s inst=%s viaLookup=%s hop_amt=%s\n"):format(
            tostring(proc.slotIndex), tostring(joker ~= nil),
            tostring(joker ~= proc.joker),
            tostring(joker and joker.juice and joker.juice.hop_amt))) end

    local sig = joker and joker.id and ("jokerSig_" .. joker.id)
    if sig and Sfx.has(sig) then
        Sfx.playWithVariation(sig, 1.0 + (ordinal - 1) * 0.05, 0.02)
    else
        Sfx.playWithVariation("jokerTick", 1.0 + (ordinal - 1) * 0.08, 0.03)
    end

    local ok, GameplayScene = pcall(require, "src.scenes.GameplayScene")
    if not ok or not GameplayScene.jokerSlotCenter then return end
    local x, y = GameplayScene.jokerSlotCenter(proc.slotIndex or 1)
    if not x then return end

    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if okFT then
        FloatingText.spawn(proc.label or "!", x, y - 12, {
            kind = proc.kind or "mult",
            fontSize = 16,
            lift = 30,
            hold = 0.4,
        })
    end

    local okPS, ParticleSystem = pcall(require, "src.systems.ParticleSystem")
    if okPS and ParticleSystem.Presets then
        ParticleSystem.Presets.JOKER_ACTIVATED(x, y)
    end
end

return JokerProcFx
