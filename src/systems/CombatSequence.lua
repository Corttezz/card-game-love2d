local Debug = require("src.core.Debug")

local Sfx = require("src.systems.Sfx")
local FontManager = require("src.ui.FontManager")
local DissolveShader = require("src.ui.DissolveShader")
local CardFeel = require("src.systems.CardFeel")
local JokerProcFx = require("src.ui.JokerProcFx")

local CombatBeats = require("src.systems.CombatBeats")

local CombatSequence = {}
CombatSequence.__index = CombatSequence

local Moveable = require("engine.Moveable")
local FEEL_LOG = Debug.enabled
local function flog(fmt, ...)
    if not FEEL_LOG then return end
    pcall(love.filesystem.append, "feel_debug.log",
        ("[FEEL +%.2f] "):format(love.timer and love.timer.getTime() or 0)
        .. fmt:format(...) .. "\n")
end

function CombatSequence:new()
    local self = setmetatable({}, CombatSequence)
    self.active = false
    self.flyingCards = {}
    self.damageNumbers = {}

    self.timings = {
        preFlight       = 0.05,
        flightDuration  = 0.5,
        impactHold      = 0.35,
        dissolveTime    = 0.7,
        cardStagger     = 0.22,
    }
    return self
end

function CombatSequence:startCombat(cards, onComplete, onCardProcessed)
    if self.active or not cards or #cards == 0 then
        if onComplete then onComplete() end
        return
    end
    self.active = true
    self._onComplete = onComplete
    self._starvedFor = 0
    local pending = {}
    for _, c in ipairs(cards) do table.insert(pending, c) end
    cards = pending

    self.flyingCards = {}
    for _, c in ipairs(cards) do table.insert(self.flyingCards, c) end

    local EM = _G.EventManager
    local Ev = _G.Event
    if not EM or not Ev then
        for _, card in ipairs(cards) do
            if onCardProcessed then onCardProcessed(card) end
        end
        self:_finish(onComplete)
        return
    end

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local centerX = screenW * 0.5
    local centerY = screenH * 0.45
    local spacing = screenW * 0.12

    local n = #cards
    local offsetStart = -((n - 1) / 2) * spacing

    local function scheduleAt(delay, fn)
        EM.add(Ev:new({
            trigger = "after",
            delay = delay,
            blocking = false,
            blockable = false,
            func = function() fn(); return true end,
        }))
    end

    local launchStagger = 0.08
    local geom = {}
    for idx, card in ipairs(cards) do
        local cardW = (card.image and card.image:getWidth() or 100) * (card.currentScale or 1)
        local cardH = (card.image and card.image:getHeight() or 140) * (card.currentScale or 1)
        geom[idx] = {
            x = centerX + offsetStart + (idx - 1) * spacing - cardW / 2,
            y = centerY - cardH / 2,
            w = cardW, h = cardH,
        }
        local g = geom[idx]
        local launchPitchIdx = idx
        scheduleAt((idx - 1) * launchStagger + self.timings.preFlight, function()
            local pitch = math.min(1.4, 0.95 + (launchPitchIdx - 1) * 0.06)
            self:_playLaunchSfx(card, pitch)
            if card.setTargetPos then
                card:setTargetPos(g.x, g.y)
            else
                card.x, card.y = g.x, g.y
            end
        end)
    end
    local allLandedAt = self.timings.preFlight + (n - 1) * launchStagger
        + self.timings.flightDuration

    local function removeFlying(card)
        for i, c in ipairs(self.flyingCards) do
            if c == card then table.remove(self.flyingCards, i) break end
        end
    end

    local resolveCard
    resolveCard = function(idx)
        local card = cards[idx]
        if not card then
            CombatBeats.push("combat.settle", nil, self.timings.dissolveTime * 0.6)
            CombatBeats.push("combat.end", function()
                self:_finish(onComplete)
            end, "MICRO")
            return
        end
        local g = geom[idx]
        if not g then
            Debug.warn("[CombatSequence] sem geometria para a carta " .. tostring(idx)
                .. " de " .. tostring(#cards) .. " — encerrando a resolucao")
            CombatBeats.push("combat.end", function()
                self:_finish(onComplete)
            end, "MICRO")
            return
        end
        local cx, cy = g.x + g.w / 2, g.y + g.h / 2
        local pitch = math.min(1.4, 0.95 + (idx - 1) * 0.06)

        CombatBeats.push("card.impact." .. tostring(card.type), function()
            self:_playImpactSfx(card, pitch)
            self:_spawnImpactParticles(card, cx, cy)

            local sink = {}
            local result = onCardProcessed and onCardProcessed(card, sink) or {}
            self:_handleResult(card, result, cx, cy)

            if card.type == "attack" then
                if card.hop_up then card:hop_up(44, 0.50) end
                if card.swell_up then card:swell_up(0.20, 0.35) end
                if card.juice_up then card:juice_up(0.4, -0.24) end
            elseif card.type == "defense" then
                if card.shove_x then card:shove_x(nil, 0.55) end
                if card.juice_up then card:juice_up(0.10, 0.22) end
                if card.swell_up then card:swell_up(0.14, 0.40) end
            elseif card.type == "effect" then
                if card.hop_up then card:hop_up(20, 0.45) end
                if card.juice_up then card:juice_up(0.45, 0.28) end
                scheduleAt(0.18, function()
                    if card.juice_up then card:juice_up(0.32, -0.2) end
                end)
                scheduleAt(0.16, function()
                    Sfx.play("effectResolve", { pitch = pitch })
                end)
            else
                if card.juice_up then card:juice_up(0.5, 0.15) end
            end

            for k, proc in ipairs(result and result.jokerProcs or {}) do
                local kk, pp = k, proc
                CombatBeats.push("joker.proc", function()
                    JokerProcFx.tick(pp, kk)
                end, "JOKER_PROC")
            end

            CombatBeats.pushAll(sink)

            CombatBeats.push("card.dissolve", function()
                if card.start_dissolve then
                    local palette = DissolveShader.palette(card.type or "default")
                    card:start_dissolve(palette, true, self.timings.dissolveTime, true,
                        function() removeFlying(card) end)
                else
                    removeFlying(card)
                end
            end, "CARD_GAP")

            CombatBeats.push("card.next", function() resolveCard(idx + 1) end, "MICRO")
        end, "CARD_IMPACT")
    end

    CombatBeats.push("combat.cards_landed", function()
        resolveCard(1)
    end, allLandedAt + 0.10)
end

function CombatSequence:_finish(onComplete)
    self.active = false
    self._onComplete = nil
    self._starvedFor = 0
    self.damageNumbers = {}
    for _, card in ipairs(self.flyingCards) do
        if card.markRemoved then card:markRemoved() end
    end
    self.flyingCards = {}
    if onComplete then onComplete() end
end

function CombatSequence:_playLaunchSfx(card, pitch)
    local t = card.type
    local opts = pitch and { pitch = pitch } or nil
    if t == "attack" then
        Sfx.play("cardPlayAttack", opts)
    elseif t == "defense" then
        Sfx.play("cardPlayDefense", opts)
    elseif t == "effect" then
        Sfx.play("effectCast", opts)
    end
end

function CombatSequence:_playImpactSfx(card, pitch)
    if CardFeel.playImpact(card, pitch) then return end
    local t = card.type
    local opts = pitch and { pitch = pitch } or nil
    if t == "attack" then
        Sfx.play("swordSound", opts)
    elseif t == "defense" then
        Sfx.play("armorSound", opts)
    elseif t == "joker" then
        Sfx.play("jokerActivate", opts)
    elseif t == "effect" then
        Sfx.play("effectChime", opts)
    else
        Sfx.play("cardSelect", opts)
    end
end

function CombatSequence:_spawnImpactParticles(card, cx, cy)
    local theme = CardFeel.themeOf(card)
    if theme then
        CardFeel.burst(theme, cx, cy, 1.0)
        return
    end

    local ok, ParticleSystem = pcall(require, "src.systems.ParticleSystem")
    if not ok or not ParticleSystem then return end

    local t = card.type
    if t == "attack" then
        ParticleSystem.Presets.DAMAGE_EFFECT(cx, cy)
    elseif t == "defense" then
        local p = ParticleSystem.Presets.CARD_PLAYED(cx, cy)
        if p then p.colours = { {0.4, 0.7, 1.0, 1} } end
    elseif t == "joker" then
        ParticleSystem.Presets.JOKER_ACTIVATED(cx, cy)
    end
end

function CombatSequence:_handleResult(card, result, cx, cy)
    if not result then return end

    if result.damage and result.damage > 0 then
        self:_addDamageNumber(result.damage, cx, cy - 60, {1, 0.3, 0.3})
        if _G.triggerShake then
            local intensity = math.min(12, 3 + result.damage * 0.2)
            _G.triggerShake(intensity, 0.18)
        end
        local okER, ER = pcall(require, "src.ui.EnemyRenderer")
        if okER and ER.triggerHurt then ER.triggerHurt() end
        CardFeel.burstAtEnemy(CardFeel.themeOf(card) or "physical",
            math.min(1.6, 0.8 + result.damage * 0.03))
    end

    if result.defense and result.defense > 0 then
        self:_addDamageNumber("+" .. result.defense, cx, cy - 60, {0.3, 0.7, 1})
        CardFeel.burstAtPlayer("armor", 0.8)
    end
end

function CombatSequence:_addDamageNumber(text, x, y, color)
    table.insert(self.damageNumbers, {
        text    = tostring(text),
        x       = x,
        y       = y,
        color   = color,
        life    = 1.4,
        maxLife = 1.4,
        alpha   = 1,
    })
end

local STARVE_TIMEOUT = 0.75

function CombatSequence:update(dt)
    if self.active then
        if CombatBeats.isBusy() then
            self._starvedFor = 0
        else
            self._starvedFor = (self._starvedFor or 0) + dt
            if self._starvedFor >= STARVE_TIMEOUT then
                Debug.warn("[CombatSequence] cadeia de resolucao morreu sem chegar ao "
                    .. "fim (fila de beats vazia por " .. string.format("%.2f", self._starvedFor)
                    .. "s com o combate ativo) — encerrando pela rede. "
                    .. "Isto e BUG: algum elo da cadeia nao foi empurrado.")
                self:_finish(self._onComplete)
            end
        end
    end

    if not self.active and #self.damageNumbers == 0 and #self.flyingCards == 0 then
        return
    end

    for _, card in ipairs(self.flyingCards) do
        if card.updateRender then card:updateRender(dt) end
        card.isHovered = false
        if card.updateMouse then
            card:updateMouse(-999, -999, dt, false)
        end
    end

    for i = #self.damageNumbers, 1, -1 do
        local d = self.damageNumbers[i]
        d.life = d.life - dt
        d.y = d.y - 50 * dt
        d.alpha = math.max(0, d.life / d.maxLife)
        if d.life <= 0 then
            table.remove(self.damageNumbers, i)
        end
    end
end

function CombatSequence:draw()
    if #self.flyingCards == 0 and #self.damageNumbers == 0 then return end

    local now = love.timer and love.timer.getTime() or 0
    local sample = false
    if now - (self._dbgLast or 0) > 0.08 then
        self._dbgLast = now
        sample = true
    end

    for _, card in ipairs(self.flyingCards) do
        if card.draw and card.image then
            local x = (card.renderX and card.renderX ~= 0) and card.renderX or card.x
            local y = (card.renderY and card.renderY ~= 0) and card.renderY or card.y
            if sample and card.juice and (card.juice.hop_amt or (card.juice.timer or 99) < (card.juice.duration or 0)) then
                flog("DRAW id=%s x=%.0f y=%.0f hopOff=%.1f scaleF=%.3f swellF=%.3f rotOff=%.3f dis=%.2f",
                    tostring(card.id), x, y,
                    Moveable.hopOffset(card), Moveable.scaleFactor(card),
                    Moveable.swellFactor(card), Moveable.rotOffset(card),
                    card.dissolve or 0)
            end
            card:draw(x, y, false, false)
        end
    end

    if #self.damageNumbers > 0 then
        local font = FontManager.getResponsiveFont(0.04, 32, "height")
        love.graphics.setFont(font)
        for _, d in ipairs(self.damageNumbers) do
            love.graphics.setColor(d.color[1], d.color[2], d.color[3], d.alpha)
            local w = font:getWidth(d.text)
            love.graphics.setColor(0, 0, 0, d.alpha * 0.7)
            love.graphics.print(d.text, d.x - w / 2 + 2, d.y + 2)
            love.graphics.setColor(d.color[1], d.color[2], d.color[3], d.alpha)
            love.graphics.print(d.text, d.x - w / 2, d.y)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function CombatSequence:isBlocking()
    return self.active or CombatBeats.isBusy()
end

function CombatSequence:isAnimating()
    return self.active
end

return CombatSequence
