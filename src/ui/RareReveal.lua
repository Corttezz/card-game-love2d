local RareReveal = {}

RareReveal.CHARGE = 0.75
RareReveal.SIGNATURE_AT = 0.55
RareReveal.SETTLE = 1.6

function RareReveal.new(opts)
    opts = opts or {}
    return {
        t = -(opts.delay or 0),
        reduced = opts.reduced and true or false,
        seed = opts.seed or 7919,
        burstDone = false,
        sigDone = false,
    }
end

function RareReveal.hidden(st)
    if not st or st.reduced then return false end
    return st.t < RareReveal.CHARGE
end

function RareReveal.started(st)
    return st ~= nil and st.t >= 0
end

function RareReveal.sinceBurst(st)
    if not st then return math.huge end
    if st.reduced then return st.t end
    return st.t - RareReveal.CHARGE
end

function RareReveal.settled(st)
    return st ~= nil and RareReveal.sinceBurst(st) >= RareReveal.SETTLE
end

function RareReveal.update(st, dt, w, h, hooks)
    if not st then return end
    hooks = hooks or {}
    local before = st.t
    st.t = st.t + dt

    if st.reduced then
        if before < 0 and st.t >= 0 and not st.burstDone then
            st.burstDone = true
            if hooks.onBurst then hooks.onBurst(true) end
        end
        if st.t >= RareReveal.SIGNATURE_AT and not st.sigDone and st.burstDone then
            st.sigDone = true
            if hooks.onSignature then hooks.onSignature() end
        end
        return
    end

    if before < 0 and st.t >= 0 and hooks.onCharge then hooks.onCharge() end

    if st.t >= RareReveal.CHARGE and not st.burstDone then
        st.burstDone = true
        if hooks.onBurst then hooks.onBurst(false) end
    end

    if st.burstDone and not st.sigDone and RareReveal.sinceBurst(st) >= RareReveal.SIGNATURE_AT then
        st.sigDone = true
        if hooks.onSignature then hooks.onSignature() end
    end
end

RareReveal.RADIUS = 0.9
RareReveal.REST_ALPHA = 0.5
RareReveal.REDUCED_ALPHA = 0.5

function RareReveal.haloParams(st, w, h)
    if not RareReveal.started(st) then return nil end
    local R = math.max(w, h) * RareReveal.RADIUS
    if st.reduced then
        return { r = R, alpha = RareReveal.REDUCED_ALPHA * math.min(1, st.t / 0.3), motion = false, sparkle = 0 }
    end
    if st.t < RareReveal.CHARGE then
        local k = st.t / RareReveal.CHARGE
        return { r = R * (0.3 + 0.7 * k * k), alpha = 0.35 + 0.65 * k, motion = true, sparkle = 0 }
    end
    local a = RareReveal.sinceBurst(st)
    local settle = math.min(1, a / RareReveal.SETTLE)
    local peak = (1 - settle) * (1 - settle)
    return {
        r = R * (1 + 0.12 * peak),
        alpha = RareReveal.REST_ALPHA + (1 - RareReveal.REST_ALPHA) * peak,
        motion = true,
        sparkle = 0.55 + 0.45 * peak,
    }
end

function RareReveal.drawBack(st, cx, cy, w, h)
    local p = RareReveal.haloParams(st, w, h)
    if not p then return end
    local RevealGlow = require("src.ui.RevealGlow")
    local now = love.timer.getTime()
    RevealGlow.halo(cx, cy, p.r, { t = now, alpha = p.alpha, motion = p.motion })
    if p.sparkle > 0 then
        RevealGlow.sparkles(cx, cy, p.r, { t = now, alpha = p.sparkle, seed = st.seed % 997, motion = p.motion })
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return RareReveal
