-- engine/Moveable.lua
-- Mixin de "juice" + T/VT pra qualquer objeto visual. Inspirado em
-- engine/moveable.lua do Balatro.
--
-- DOIS PADRÕES distintos que este módulo provê:
--
-- 1) T/VT (Target vs Visible Transform)
--    Você muda T.x/y (onde quer estar); VT.x/y interpola suavemente por frame.
--    O draw usa VT. Resultado: trocar posição vira animação automática.
--    Obs: seu Card já implementa algo equivalente (targetX/renderX). Este
--    módulo serve de base pra NOVOS objetos (Button, Tooltip, enemy sprite).
--
-- 2) juice_up (bounce multiplicativo)
--    Chama `Moveable.juice_up(obj, scale_mod, rot_mod)` quando algo ACONTECE
--    (carta jogada, hit, mana gasto). Em Moveable.update scale/rot decaem
--    com exp. Em Moveable.apply você multiplica/adiciona no draw.
--
-- Uso simples (sem herança, só compõe num objeto existente):
--
--   local Moveable = require("engine.Moveable")
--
--   function Card:new(...)
--       ...
--       Moveable.initJuice(self)  -- adiciona .juice table
--       Moveable.initTVT(self, x, y)  -- opcional: adiciona .T e .VT
--   end
--
--   function Card:update(dt)
--       Moveable.updateJuice(self, dt)
--       Moveable.updateTVT(self, dt, 12)  -- k=12 controla "rigidez"
--   end
--
--   function Card:someEvent()
--       Moveable.juice_up(self, 0.4, 0.1)  -- kick: scale+0.4, rot±0.1
--   end
--
--   No draw:
--       local s = self.currentScale * Moveable.scaleFactor(self)
--       local r = Moveable.rotOffset(self)

local Moveable = {}

-- ============ JUICE ============

-- Adiciona o campo .juice no objeto. Chame no construtor.
function Moveable.initJuice(obj)
    obj.juice = obj.juice or {
        scale = 0,   -- modificador aditivo na escala (tipicamente ±0.5)
        r = 0,       -- rotação em radianos
        timer = 0,   -- vida restante em segundos
        duration = 0.4, -- duração total ao juice_up
    }
end

-- Dispara um "kick" de juice. Sobrescreve juice anterior (não empilha, pra
-- não virar festa). Valores típicos:
--   scale_mod: 0.1 (sutil) — 0.5 (forte). Multiplicativo no draw.
--   rot_mod:   0.05–0.2 (radianos)
function Moveable.juice_up(obj, scale_mod, rot_mod)
    Moveable.initJuice(obj)
    scale_mod = scale_mod or 0.3
    rot_mod = rot_mod or 0.1
    -- Direção alterna a cada kick consecutivo (mais vivo visualmente)
    local dir = (obj.juice._lastDir or 1) * -1
    obj.juice._lastDir = dir
    obj.juice.scale = scale_mod
    obj.juice.r = rot_mod * dir
    obj.juice.timer = 0
    obj.juice.duration = 0.4
end

-- Atualiza decay. Chame em update(dt).
function Moveable.updateJuice(obj, dt)
    local j = obj.juice
    if not j or j.timer >= j.duration then return end
    j.timer = j.timer + dt
    if j.timer >= j.duration then
        j.scale, j.r = 0, 0
    end
end

-- Fator de escala atual do juice. Use no draw multiplicando seu scale base.
-- Curva: sin(pi * progress) — começa em 0, pico no meio, volta a 0. Bounce natural.
function Moveable.scaleFactor(obj)
    local j = obj.juice
    if not j or j.timer >= j.duration or j.duration <= 0 then return 1 end
    local t = j.timer / j.duration
    local wave = math.sin(math.pi * t)  -- 0→1→0
    return 1 + j.scale * wave
end

-- Offset de rotação atual. Soma no seu rot base.
function Moveable.rotOffset(obj)
    local j = obj.juice
    if not j or j.timer >= j.duration or j.duration <= 0 then return 0 end
    local t = j.timer / j.duration
    local wave = math.sin(math.pi * t)
    return j.r * wave
end

-- ============ T vs VT (opcional) ============

-- Inicializa T (target) e VT (visible). Chame no construtor de novos objetos.
-- Objetos legados (Card) já têm targetX/renderX próprios — não use aqui pra
-- evitar duplicação de estado.
function Moveable.initTVT(obj, x, y, scale, rot)
    obj.T = obj.T or { x = x or 0, y = y or 0, scale = scale or 1, r = rot or 0 }
    obj.VT = obj.VT or { x = x or 0, y = y or 0, scale = scale or 1, r = rot or 0 }
end

-- Ease VT em direção a T. k controla a "rigidez": 8=flutuante, 16=tátil, 24=snappy.
function Moveable.updateTVT(obj, dt, k)
    if not obj.T or not obj.VT then return end
    k = k or 12
    local ease = 1 - math.exp(-k * dt)
    obj.VT.x = obj.VT.x + (obj.T.x - obj.VT.x) * ease
    obj.VT.y = obj.VT.y + (obj.T.y - obj.VT.y) * ease
    obj.VT.scale = obj.VT.scale + (obj.T.scale - obj.VT.scale) * ease
    obj.VT.r = obj.VT.r + (obj.T.r - obj.VT.r) * ease
end

-- Snap: força VT = T imediatamente (usado em "teleport" / reset de cena).
function Moveable.snap(obj)
    if obj.T and obj.VT then
        obj.VT.x, obj.VT.y = obj.T.x, obj.T.y
        obj.VT.scale, obj.VT.r = obj.T.scale, obj.T.r
    end
end

return Moveable
