-- src/systems/UnlockSystem.lua
-- STUB — substituído pela frente progressão no merge.
--
-- Implementa SÓ o contrato que a ClassSelectionScreen consome, com regra
-- fixa e estado em memória (nada persiste). A versão real lê o perfil
-- (chefes vencidos, atos completos, runs vencidas, XP de maestria).
--
-- Contrato:
--   isClassUnlocked(classId)   -> bool
--   getClassUnlockInfo(classId)-> { unlocked, reqKey, vars, progress, goal }
--   getClassMastery(classId)   -> { level, maxLevel, xp, xpToNext }
--
-- Regra planejada: warrior liberado; mage ao vencer o chefe do Ato 2;
-- rogue ao completar o Ato 4 OU vencer uma run.

local UnlockSystem = {}

-- Estado em memória do stub (progresso fictício de perfil novo).
local state = {
    bestActBossBeaten = 0,   -- maior ato cujo chefe foi vencido
    runsWon = 0,
}

local RULES = {
    warrior = nil,  -- sempre liberado
    mage  = { reqKey = "unlock.class.mage_req",  goal = 2,
              progress = function() return math.min(2, state.bestActBossBeaten) end },
    rogue = { reqKey = "unlock.class.rogue_req", goal = 4,
              progress = function()
                  if state.runsWon > 0 then return 4 end
                  return math.min(4, state.bestActBossBeaten)
              end },
}

function UnlockSystem.isClassUnlocked(classId)
    local r = RULES[classId]
    if not r then return true end
    return r.progress() >= r.goal
end

function UnlockSystem.getClassUnlockInfo(classId)
    local r = RULES[classId]
    if not r then
        return { unlocked = true, reqKey = "unlock.class.default", vars = {},
                 progress = 1, goal = 1 }
    end
    local p = r.progress()
    return { unlocked = p >= r.goal, reqKey = r.reqKey,
             vars = { act = r.goal }, progress = p, goal = r.goal }
end

function UnlockSystem.getClassMastery(classId)
    return { level = 1, maxLevel = 5, xp = 0, xpToNext = 100 }
end

return UnlockSystem
