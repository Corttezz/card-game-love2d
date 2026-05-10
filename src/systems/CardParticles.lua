-- src/systems/CardParticles.lua
-- Thin compat shim sobre ParticlesManager. Mantém a API legacy
-- (CardParticles.emit / .update / .draw / .clear / .activeCount) para call sites
-- existentes, mas internamente delega tudo ao ParticlesManager unificado.
--
-- A ideia: card-attached emitters não são uma categoria especial — são apenas
-- Particles com `attach = card`. ParticlesManager.update/draw cuidam do tick.

local ParticlesManager = require("engine.ParticlesManager")

local CardParticles = {}

-- Cria emissor seguindo uma carta. cfg compatível com a API antiga
-- (timer/lifespan/scale/speed/colours/fill/max/pulse_max/vel_variation).
function CardParticles.emit(card, cfg)
    cfg = cfg or {}

    -- Calcula bbox inicial do card (Particles:syncAttach refina a cada frame).
    local x, y, w, h = card.x or 0, card.y or 0, 100, 140
    if card.image and card.currentScale then
        w = card.image:getWidth() * card.currentScale
        h = card.image:getHeight() * card.currentScale
    end

    return ParticlesManager.spawn(x, y, w, h, {
        attach        = card,
        fill          = cfg.fill,
        timer         = cfg.timer or 0.03,
        lifespan      = cfg.lifespan or 0.8,
        scale         = cfg.scale or 0.3,
        speed         = cfg.speed or 80,
        max           = cfg.max or 200,
        pulse_max     = cfg.pulse_max,
        vel_variation = cfg.vel_variation or 1,
        colours       = cfg.colours or { {1, 1, 1, 1} },
        layer         = cfg.layer or 5, -- carta-attached fica acima do smoke
    })
end

-- update/draw centralizados no ParticlesManager. Chamadas do main.lua
-- continuam funcionando sem mudança.
function CardParticles.update(dt) ParticlesManager.update(dt) end
function CardParticles.draw()      ParticlesManager.draw() end
function CardParticles.clear()     ParticlesManager.clear() end
function CardParticles.activeCount() return ParticlesManager.activeCount() end

return CardParticles
