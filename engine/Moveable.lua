-- engine/Moveable.lua
-- Mixin de "juice" + T/VT pra qualquer objeto visual. Inspirado em
-- engine/moveable.lua do Balatro.
--
-- DOIS PADRÕES distintos que este módulo provê:
--
-- 1) T/VT (Target vs Visible Transform)
--    Você muda T.x/y (onde quer estar); VT.x/y interpola suavemente por frame.
--    O draw usa VT. Resultado: trocar posição vira animação automática.
--
--    Implementação (Fase 1 — Balatro-style): damping exponencial via
--    *velocity* (com momento + clamp), não tween posicional. Tornou-se padrão
--    pra qualquer obj novo no projeto.
--
--    Obs: Card legacy tem targetX/renderX próprio — não migrar agora pra evitar
--    risco. Use TVT em NOVOS objetos (Button, Tooltip, ShopSlotWidget, etc.).
--
-- 2) juice_up (bounce multiplicativo)
--    Chama `Moveable.juice_up(obj, scale_mod, rot_mod)` quando algo ACONTECE
--    (carta jogada, hit, mana gasto). scaleFactor()/rotOffset() compõem no draw.
--
-- Uso típico (sem herança):
--
--   Moveable.initJuice(self)
--   Moveable.initTVT(self, x, y)
--   ...
--   function obj:update(dt)
--       Moveable.updateJuice(self, dt)
--       Moveable.updateTVT(self, dt)
--   end
--   function obj:draw()
--       local s = self.VT.scale * Moveable.scaleFactor(self)
--       local r = self.VT.r + Moveable.rotOffset(self)
--       love.graphics.draw(..., self.VT.x, self.VT.y, r, s, s)
--   end

local Moveable = {}

-- ============ JUICE ============

-- Adiciona o campo .juice no objeto. Chame no construtor.
function Moveable.initJuice(obj)
    obj.juice = obj.juice or {
        scale = 0,    -- modificador aditivo na escala (tipicamente ±0.5)
        r = 0,        -- rotação em radianos
        scale_amt = 0,
        r_amt = 0,
        timer = 0,    -- vida restante em segundos
        duration = 0.4,
    }
end

-- Dispara um "kick" de juice. Sobrescreve juice anterior (não empilha).
-- Padrão Balatro: sine wave 50.8/40.8 freq com cubic falloff em 0.4s fixos.
-- scale_mod: 0.1 (sutil) — 0.5 (forte). Multiplicativo no draw via scaleFactor().
-- rot_mod:   0.05–0.2 (radianos). Direção alterna entre kicks consecutivos.
function Moveable.juice_up(obj, scale_mod, rot_mod)
    Moveable.initJuice(obj)
    -- Reduced motion (Balatro engine/moveable.lua:251 G.SETTINGS.reduced_motion):
    -- desliga TODO juice quando flag global ativa, pra acessibilidade ou
    -- preferência. Usuário marca em SettingsMenu → _G.gameSettings.reducedMotion.
    if _G.gameSettings and _G.gameSettings.reducedMotion then
        return
    end
    scale_mod = scale_mod or 0.4
    -- Direção alternante quando rot_mod não é dado (mais "vivo" em sequência).
    if not rot_mod then
        local dir = (obj.juice._lastDir or 1) * -1
        obj.juice._lastDir = dir
        rot_mod = 0.6 * scale_mod * dir
    end
    obj.juice.scale_amt = scale_mod
    obj.juice.r_amt = rot_mod
    obj.juice.timer = 0
    obj.juice.duration = 0.4

    -- Pre-shrink visual (Balatro): VT.scale começa "comprimido" pra dar pop ao
    -- soltar. Aplicado se obj tem VT; senão é no-op.
    if obj.VT and obj.VT.scale then
        obj.VT.scale = math.max(0.01, (obj.T and obj.T.scale or 1) - 0.6 * scale_mod)
    end
end

-- Atualiza decay. Chame em update(dt). Sine wave * cubic falloff (padrão Balatro).
function Moveable.updateJuice(obj, dt)
    local j = obj.juice
    if not j or j.duration <= 0 or j.timer >= j.duration then
        if j then j.scale, j.r = 0, 0 end
        return
    end
    j.timer = j.timer + dt
    local progress = j.timer / j.duration
    if progress >= 1 then
        j.scale, j.r = 0, 0
        return
    end

    -- Falloff cúbico (1-progress)^3 — padrão Balatro pra scale.
    local falloff_scale = (1 - progress) ^ 3
    local falloff_rot = (1 - progress) ^ 2

    -- Sine waves de alta frequência (50.8 / 40.8 rad/s no Balatro). Em love2d
    -- usamos timer absoluto, mesma ideia.
    j.scale = j.scale_amt * math.sin(50.8 * j.timer) * falloff_scale
    j.r = j.r_amt * math.sin(40.8 * j.timer) * falloff_rot
end

-- Fator de escala atual do juice. Use no draw multiplicando seu scale base.
-- Curva: oscilação Balatro ao redor de 1.0 com decay cúbico.
function Moveable.scaleFactor(obj)
    local j = obj.juice
    if not j or j.timer >= j.duration or j.duration <= 0 then return 1 end
    return 1 + j.scale
end

-- Offset de rotação atual. Soma no seu rot base.
function Moveable.rotOffset(obj)
    local j = obj.juice
    if not j or j.timer >= j.duration or j.duration <= 0 then return 0 end
    return j.r
end

-- ============ T vs VT (velocity-based damping, padrão Balatro) ============

-- Inicializa T (target) e VT (visible) + velocity. Chame no construtor.
function Moveable.initTVT(obj, x, y, scale, rot)
    x = x or 0; y = y or 0; scale = scale or 1; rot = rot or 0
    obj.T = obj.T or { x = x, y = y, scale = scale, r = rot }
    obj.VT = obj.VT or { x = x, y = y, scale = scale, r = rot }
    obj.velocity = obj.velocity or { x = 0, y = 0, scale = 0, r = 0 }
end

-- Damping exponencial constants (Balatro): rates per second.
-- xy=50, scale=60 (mais lento que xy), r=190 (mais rápido que xy).
-- Velocidade máxima default 70*dt*60 → 4200 px/s a 60fps. Override via obj.MAX_VEL.
local DAMP_XY    = 50
local DAMP_SCALE = 60
local DAMP_R     = 190
local DEFAULT_MAX_VEL_PER_FRAME = 70

-- Atualiza VT em direção a T usando velocity-based exponential damping.
-- Inclui hover/drag scale modifiers se obj.zoom=true e obj.states existir.
function Moveable.updateTVT(obj, dt)
    if not obj.T or not obj.VT then return end
    obj.velocity = obj.velocity or { x = 0, y = 0, scale = 0, r = 0 }

    local exp_xy    = math.exp(-DAMP_XY    * dt)
    local exp_scale = math.exp(-DAMP_SCALE * dt)
    local exp_r     = math.exp(-DAMP_R     * dt)
    local max_vel   = (obj.MAX_VEL or DEFAULT_MAX_VEL_PER_FRAME) * dt * 60

    -- X/Y: velocity carrega momento; clamp por magnitude.
    local dx = obj.T.x - obj.VT.x
    local dy = obj.T.y - obj.VT.y
    if math.abs(dx) > 0.01 or math.abs(dy) > 0.01
       or math.abs(obj.velocity.x) > 0.01 or math.abs(obj.velocity.y) > 0.01 then
        obj.velocity.x = exp_xy * obj.velocity.x + (1 - exp_xy) * dx * 35 * dt
        obj.velocity.y = exp_xy * obj.velocity.y + (1 - exp_xy) * dy * 35 * dt

        local mag2 = obj.velocity.x * obj.velocity.x + obj.velocity.y * obj.velocity.y
        if mag2 > max_vel * max_vel and mag2 > 0 then
            local mag = math.sqrt(mag2)
            obj.velocity.x = max_vel * obj.velocity.x / mag
            obj.velocity.y = max_vel * obj.velocity.y / mag
        end
        obj.VT.x = obj.VT.x + obj.velocity.x
        obj.VT.y = obj.VT.y + obj.velocity.y
    end

    -- Scale desejado: T.scale + hover/drag (se obj.zoom). Juice é multiplicado no
    -- draw via scaleFactor() — não compor aqui.
    local des_scale = obj.T.scale
    if obj.zoom and obj.states then
        if obj.states.drag and obj.states.drag.is then
            des_scale = des_scale + 0.10
        end
        if obj.states.hover and obj.states.hover.is then
            des_scale = des_scale + 0.05
        end
    end

    local ds = des_scale - obj.VT.scale
    if math.abs(ds) > 0.0005 or math.abs(obj.velocity.scale) > 0.001 then
        obj.velocity.scale = exp_scale * obj.velocity.scale + (1 - exp_scale) * ds
        obj.VT.scale = obj.VT.scale + obj.velocity.scale
    end

    -- Rotação (decay mais rápido, sem velocity cap — rotações são pequenas).
    local dr = obj.T.r - obj.VT.r
    if math.abs(dr) > 0.0005 or math.abs(obj.velocity.r) > 0.001 then
        obj.velocity.r = exp_r * obj.velocity.r + (1 - exp_r) * dr
        obj.VT.r = obj.VT.r + obj.velocity.r
    end
end

-- Tween posicional simples (sem velocity). Mantido pra casos que não querem
-- momento/overshoot (ex: tooltip que precisa "encaixar" instantaneamente).
-- k controla rigidez: 8=flutuante, 16=tátil, 24=snappy.
function Moveable.simpleEaseTVT(obj, dt, k)
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
        if obj.velocity then
            obj.velocity.x, obj.velocity.y = 0, 0
            obj.velocity.scale, obj.velocity.r = 0, 0
        end
    end
end

return Moveable
