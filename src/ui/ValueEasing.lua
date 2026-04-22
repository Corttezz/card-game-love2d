-- src/ui/ValueEasing.lua
-- Helper pra UIs terem um "display value" que eases smoothly toward o valor
-- real (gameplay-side). Desacopla lógica do jogo de feedback visual — spendMana
-- desce imediato no player.mana (gameplay vê), mas o ORB mostra o valor
-- descendo suavemente em ~0.3s.
--
-- Inspirado em ease_chips / ease_dollars / ease_mana do Balatro
-- (functions/common_events.lua:41+).
--
-- Uso em cada componente de UI:
--   local ValueEasing = require("src.ui.ValueEasing")
--
--   function Foo:new()
--     self.disp = {}  -- tabela nomeada pra valores eased
--   end
--
--   function Foo:update(dt, player)
--     ValueEasing.tick(self.disp, "mana", player.mana, dt, 10)
--     ValueEasing.tick(self.disp, "health", player.health, dt, 8)
--   end
--
--   function Foo:draw(player)
--     local displayedMana = math.floor(self.disp.mana or player.mana)
--     ...
--   end

local ValueEasing = {}

-- Tick: ease disp[key] toward target usando exp decay com rate K.
-- Init: se disp[key] é nil, seta imediato ao target (evita "anim de 0 → N"
-- quando o objeto é criado mid-game).
--   disp: tabela do chamador (não precisa existir — criada no init)
--   key: nome do campo (ex: "mana", "health", "gold")
--   target: valor atual real (game-side)
--   dt: delta time
--   k: taxa do ease (default 8). Maior = mais snappy. 8-12 é sweet spot.
function ValueEasing.tick(disp, key, target, dt, k)
    if not disp[key] then
        disp[key] = target
        return
    end
    k = k or 8
    local ease = 1 - math.exp(-k * dt)
    disp[key] = disp[key] + (target - disp[key]) * ease
    -- Snap quando quase lá (evita decimais eternos tipo 6.9998)
    if math.abs(target - disp[key]) < 0.05 then
        disp[key] = target
    end
end

-- Helper: retorna disp[key] floor'd pra exibição, fallback ao target.
function ValueEasing.get(disp, key, target)
    return math.floor(disp[key] or target or 0)
end

-- Força snap instantâneo (útil em transitions hard — novo inimigo, reset).
function ValueEasing.snap(disp, key, value)
    disp[key] = value
end

return ValueEasing
