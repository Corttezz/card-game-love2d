-- src/ui/CardBackHover.lua
-- State machine de hover pra CardBack — replica a lógica de Card:updateMouse
-- (src/cards/base/Card.lua:394+) num formato standalone reutilizável.
--
-- Como Card.lua tem ~700 LOC com lifecycle de gameplay (drag, drop, dissolve,
-- juice, etc), aqui extraímos só a parte de hover/tilt pra usar em cartas
-- decorativas (menu floaters, splash flying cards) sem precisar instanciar
-- Card real.
--
-- Uso:
--   -- Por carta, mantém um state table:
--   local state = CardBackHover.new()
--
--   -- Por frame:
--   CardBackHover.update(state, mx, my, cx, cy, w, h, dt)
--   CardBack.draw(cx, cy, w, h, state)   -- state já tem tiltX/tiltY/hoverStrength/etc

local Config = require("src.core.Config")

local CardBackHover = {}

-- Cria estado inicial. Pode ser passado direto pra CardBack.draw.
function CardBackHover.new()
    return {
        alpha               = 1,
        scale               = 1,
        rot                 = 0,
        dissolve            = 0,
        tiltX               = 0,
        tiltY               = 0,
        hoverStrength       = 0,
        liftOffset          = 0,
        perspectiveRotation = 0,
        -- Internos:
        _ambientTime        = 0,
        _ambientSeed        = math.random() * math.pi * 2,
        _isHovered          = false,
    }
end

-- Calcula tilts/lift/etc baseado em mouse + bounding box.
-- mx, my       = posição do mouse
-- cx, cy       = centro da carta
-- w, h         = dimensões renderizadas
-- dt           = delta time (pra ambient breathing)
-- liftDir      = "up" (default) ou "down" (cartas da mão descem no hover)
function CardBackHover.update(state, mx, my, cx, cy, w, h, dt, liftDir)
    -- Hover detection: cursor dentro do bbox da carta.
    local hw, hh = w / 2, h / 2
    local isHovered = (mx >= cx - hw and mx <= cx + hw and my >= cy - hh and my <= cy + hh)
    state._isHovered = isHovered

    if isHovered then
        -- Distância normalizada do mouse ao centro [-1, 1].
        local nx = math.max(-1, math.min(1, (mx - cx) / hw))
        local ny = math.max(-1, math.min(1, (my - cy) / hh))
        local centerDistance = math.sqrt(nx * nx + ny * ny) / math.sqrt(2)
        local depthMultiplier = 1 - (centerDistance * 0.3)

        local TILT_RANGE   = Config.Cards.TILT_RANGE   or 0.15
        local DEPTH_TILT_X = Config.Cards.DEPTH_TILT_X or 0.12
        local DEPTH_TILT_Y = Config.Cards.DEPTH_TILT_Y or 0.08
        local LIFT_AMOUNT  = Config.Cards.LIFT_AMOUNT  or 25

        state.tiltX = nx * TILT_RANGE + (nx * DEPTH_TILT_X * depthMultiplier)
        state.tiltY = ny * TILT_RANGE + (ny * DEPTH_TILT_Y * depthMultiplier)

        if liftDir == "down" then
            state.liftOffset = LIFT_AMOUNT * depthMultiplier
        else
            state.liftOffset = -LIFT_AMOUNT * depthMultiplier
        end

        state.perspectiveRotation = nx * 0.05 * depthMultiplier
        state.hoverStrength = math.min(1, (state.hoverStrength or 0) + dt * 8)
    else
        -- Decay liftOffset / perspective rotation suavemente quando sai.
        local decay = 1 - math.exp(-6 * dt)
        state.liftOffset          = (state.liftOffset or 0) * (1 - decay)
        state.perspectiveRotation = (state.perspectiveRotation or 0) * (1 - decay)
        state.hoverStrength       = (state.hoverStrength or 0) * (1 - decay)

        -- Ambient tilt (Balatro-style breathing, mesmo Card.lua faz).
        -- Onda senoidal defasada por seed (evita sincronia entre cartas).
        local AMBIENT_SPEED  = Config.Cards.AMBIENT_TILT_SPEED  or 1.4
        local AMBIENT_AMOUNT = Config.Cards.AMBIENT_TILT_AMOUNT or 0.02
        state._ambientTime = (state._ambientTime or 0) + dt
        state.tiltX = math.sin(state._ambientTime * AMBIENT_SPEED + state._ambientSeed) * AMBIENT_AMOUNT
        state.tiltY = math.cos(state._ambientTime * AMBIENT_SPEED * 0.7 + state._ambientSeed) * AMBIENT_AMOUNT * 0.6
    end
end

function CardBackHover.isHovered(state)
    return state._isHovered or false
end

return CardBackHover
