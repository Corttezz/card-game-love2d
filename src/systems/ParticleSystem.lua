-- src/systems/ParticleSystem.lua
-- Compat layer + presets sobre o ParticlesManager unificado.
--
-- Antes deste refactor, este arquivo continha sua própria classe Emitter +
-- ParticleManager (singleton em ParticleSystem.Manager) que NUNCA recebia
-- emitters spawnados — ficava só atualizando uma lista vazia em GameUI.
-- Removido. Os Presets agora retornam instâncias Particles vivas no
-- ParticlesManager global.
--
-- USO:
--   local p = ParticleSystem.Presets.JOKER_ACTIVATED(x, y)  -- spawna
--   p:fade(0.4)                                             -- ou :remove()
--
-- ParticleSystem.Manager.update/draw são alias pro ParticlesManager pra back-compat
-- com call sites antigos em GameUI.lua etc.

local ParticlesManager = require("engine.ParticlesManager")

local ParticleSystem = {}

ParticleSystem.Manager = {
    update = function(_, dt) ParticlesManager.update(dt) end,
    draw   = function(_)     ParticlesManager.draw() end,
    clear  = function(_)     ParticlesManager.clear() end,
}

-- Presets comuns. Cada um retorna a instância Particles spawnada (chamável
-- com :fade(duration) ou :remove() pelo caller).
ParticleSystem.Presets = {
    -- Brilho dourado de joker ativando (burst pra cima).
    JOKER_ACTIVATED = function(x, y)
        return ParticlesManager.spawn(x, y, 0, 0, {
            timer         = 0.04,
            lifespan      = 1.0,
            scale         = 0.4,
            speed         = 100,
            colours       = { {1, 0.8, 0.2, 1}, {1, 0.6, 0.1, 1} },
            pulse_max     = 12,
            vel_variation = 0.6,
            layer         = 6,
        })
    end,

    -- Faísca dourada saindo de carta jogada.
    CARD_PLAYED = function(x, y)
        return ParticlesManager.spawn(x, y, 0, 0, {
            timer         = 0.05,
            lifespan      = 0.8,
            scale         = 0.3,
            speed         = 80,
            colours       = { {0.95, 0.7, 0.25, 1} },
            pulse_max     = 8,
            vel_variation = 0.7,
            layer         = 5,
        })
    end,

    -- Halo azul claro de hover.
    HOVER_EFFECT = function(x, y)
        return ParticlesManager.spawn(x, y, 0, 0, {
            timer         = 0.06,
            lifespan      = 0.6,
            scale         = 0.2,
            speed         = 30,
            colours       = { {0.6, 0.8, 1, 0.8} },
            pulse_max     = 6,
            layer         = 5,
        })
    end,

    -- Pulso vermelho de impacto/dano.
    DAMAGE_EFFECT = function(x, y)
        return ParticlesManager.spawn(x, y, 0, 0, {
            timer         = 0.03,
            lifespan      = 0.7,
            scale         = 0.35,
            speed         = 130,
            colours       = { {1, 0.3, 0.3, 1}, {0.8, 0.1, 0.1, 1} },
            pulse_max     = 14,
            vel_variation = 0.5,
            layer         = 7,
        })
    end,
}

return ParticleSystem
