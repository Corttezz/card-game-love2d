local ParticlesManager = require("engine.ParticlesManager")

local CardParticles = {}

function CardParticles.emit(card, cfg)
    cfg = cfg or {}

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
        layer         = cfg.layer or 5,
    })
end

function CardParticles.update(dt) ParticlesManager.update(dt) end
function CardParticles.draw()      ParticlesManager.draw() end
function CardParticles.clear()     ParticlesManager.clear() end
function CardParticles.activeCount() return ParticlesManager.activeCount() end

return CardParticles
