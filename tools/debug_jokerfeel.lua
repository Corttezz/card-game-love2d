-- tools/debug_jokerfeel.lua (TEMPORÁRIO — investigação "joker não se move no proc")
-- Simula o fluxo real: run + joker ativo + carta de ataque jogada + pump com
-- updateMouse por frame (como drawJokersAsCards faz) e mede o movimento.
local M = {}

function M.run()
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    require("src.i18n.I18n").init()
    local Game = require("src.core.Game")
    local Moveable = require("engine.Moveable")

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    game:addJokerToRun("joker_005") -- +2 dano em ataques (damage_bonus)
    print("jokerSlots ativos:", #game.jokerSlots)
    local slotJoker = game.jokerSlots[1]

    local atk
    for _, c in ipairs(game.hand) do
        if c.type == "attack" then atk = c break end
    end
    print("carta de ataque:", atk and atk.id or "NENHUMA")
    game:selectCard(atk)
    game:playSelectedCards()

    local maxHop, maxScale = 0, 0
    local tickedSame, tickedAny = false, false
    local dt = 1 / 60
    for frame = 1, 150 do -- 2.5s
        _G.EventManager.update(dt)
        game.combatAnimationSystem:update(dt)
        -- espelho do drawJokersAsCards: updateMouse por frame no slot
        local j = game.jokerSlots[1]
        if j then
            j:updateMouse(-999, -999, dt, false)
            local off = math.abs(Moveable.hopOffset(j))
            local sc = math.abs(Moveable.scaleFactor(j) - 1)
            if off > maxHop then maxHop = off end
            if sc > maxScale then maxScale = sc end
            if j.juice and j.juice.hop_amt and j.juice.hop_amt > 0 then
                tickedAny = true
                if j == slotJoker then tickedSame = true end
            end
        end
    end
    print(string.format("slot[1] ainda é a MESMA instância? %s",
        tostring(game.jokerSlots[1] == slotJoker)))
    print(string.format("hop chegou na instância DESENHADA? %s (em alguma: %s)",
        tostring(tickedSame), tostring(tickedAny)))
    print(string.format("pico de hop: %.1f px | pico de juice scale: %.2f", maxHop, maxScale))
    return true
end

return M
