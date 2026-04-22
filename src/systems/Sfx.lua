-- src/systems/Sfx.lua
-- Wrapper thin pro _G.audioSystem. Substitui o padrão repetido:
--   if _G.audioSystem then _G.audioSystem:playSound("name") end
-- por:
--   Sfx.play("name")
--
-- O AudioSystem já é no-op gracioso quando áudio não está disponível (WSL2,
-- sistema sem driver, etc.), então o único guard necessário é contra `_G.audioSystem`
-- ser nil (pode acontecer antes de love.load terminar).

local Sfx = {}

function Sfx.play(name)
    if _G.audioSystem then _G.audioSystem:playSound(name) end
end

return Sfx
