local Config = require("src.core.Config")
local CardInfoDisplay = require("src.ui.CardInfoDisplay")
local ImageCache = require("src.ui.ImageCache")
local HoloShader = require("src.ui.HoloShader")
local FoilShader = require("src.ui.FoilShader")
local PolychromeShader = require("src.ui.PolychromeShader")
local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")
local CardArt = require("src.ui.CardArt")
local CardFrame = require("src.ui.CardFrame")
local Sfx = require("src.systems.Sfx")
local CardMesh = require("src.ui.CardMesh")
local Moveable = require("engine.Moveable")
local DissolveShader = require("src.ui.DissolveShader")
local CardParticles = require("src.systems.CardParticles")

local Card = {}
Card.__index = Card

function Card:new(name, cost, attack, defense, passive, type, subtype, imagePath)
    local instance = setmetatable({}, Card)
    instance.name = name
    instance.cost = cost
    instance.attack = attack
    instance.defense = defense
    instance.passive = passive or function()
    end
    instance.type = type
    instance.subtype = subtype

    instance.image = ImageCache.get(imagePath)

    instance.x = 0
    instance.y = 0
    instance.baseScale = Config.Cards.BASE_SCALE
    instance.targetScale = instance.baseScale
    instance.currentScale = instance.baseScale
    instance.width = instance.image:getWidth() * instance.baseScale
    instance.height = instance.image:getHeight() * instance.baseScale
    instance.isHovered = false

    instance.borderAnimationTime = 0

    instance.cardInfoDisplay = CardInfoDisplay:new()
    instance.cardInfoDisplay:configure({
        showRarity = false,
        showStats = true,
        showDescription = true
    })

    instance.attackIcon = ImageCache.get("assets/icons/attack.png")
    instance.manaIcon = ImageCache.get("assets/icons/mana.png")
    instance.armorIcon = ImageCache.get("assets/icons/armor.png")

    instance.dragPending = false
    instance.dragStartMX = 0
    instance.dragStartMY = 0
    instance.isDragging  = false
    instance.dragOffsetX = 0
    instance.dragOffsetY = 0

    instance.targetX = 0
    instance.targetY = 0
    instance.renderX = 0
    instance.renderY = 0

    Moveable.initJuice(instance)

    instance._ambientSeed = love.math.random() * math.pi * 2
    instance._ambientTime = 0

    instance.dissolve = 0
    instance.dissolve_colours = nil
    instance._removed = false

    instance.upgrades = 0
    instance.edition = nil
    instance.seal = nil

    instance._flip = 0

    return instance
end

function Card:juice_up(scale_mod, rot_mod)
    Moveable.juice_up(self, scale_mod, rot_mod)
end

function Card:hop_up(px, duration)
    Moveable.hop_up(self, px, duration)
end

function Card:swell_up(scale_add, duration)
    Moveable.swell_up(self, scale_add, duration)
end

function Card:shove_x(px, duration)
    Moveable.shove_x(self, px, duration)
end

local function EM()
    return _G.EventManager
end
local function Ev()
    return _G.Event
end

function Card:markRemoved()
    self._removed = true
end

function Card:cancelDissolveAnim()
    if self._dissolveEvents then
        for _, evt in ipairs(self._dissolveEvents) do
            if evt and not evt.completed then evt.completed = true end
        end
        self._dissolveEvents = nil
    end
    self.dissolve = 0
    self._removed = false
end

function Card:start_dissolve(colours, silent, timeFac, noJuice, onComplete)
    self:cancelDissolveAnim()
    local em, ev = EM(), Ev()
    local dissolveTime = 0.7 * (timeFac or 1)
    self.dissolve = 0
    self.dissolve_colours = colours or DissolveShader.palette("default")
    self._dissolveEvents = {}

    if not noJuice then self:juice_up(0.3, 0.08) end

    local emitter = CardParticles.emit(self, {
        timer = 0.01 * dissolveTime,
        lifespan = 0.7 * dissolveTime,
        scale = 0.2,
        speed = 40,
        colours = self.dissolve_colours,
        fill = true,
        max = 30,
    })

    if not silent then
        local Sfx = require("src.systems.Sfx")
        if em and ev then
            em.after(0.0, function()
                pcall(function() Sfx.play("cardExhaust") end)
            end)
        end
    end

    if em and ev then
        local easeEv = em.add(ev:new({
            trigger = "ease",
            delay = dissolveTime,
            blocking = false,
            ease = {
                ref_table = self,
                ref_value = "dissolve",
                ease_to = 1,
                type = "smooth",
            },
        }))
        table.insert(self._dissolveEvents, easeEv)

        table.insert(self._dissolveEvents, em.after(0.7 * dissolveTime, function()
            emitter:fade(0.3 * dissolveTime)
        end))
        table.insert(self._dissolveEvents, em.after(1.05 * dissolveTime, function()
            self:markRemoved()
            if onComplete then onComplete() end
        end))
    else
        self.dissolve = 1
        self:markRemoved()
        if onComplete then onComplete() end
    end
end

function Card:start_materialize(colours, silent, timeFac, onComplete)
    local em, ev = EM(), Ev()
    local dissolveTime = 0.6 * (timeFac or 1)
    self.dissolve = 1
    self.dissolve_colours = colours or DissolveShader.palette(self.type or "default")
    self:juice_up(0.2, 0.05)

    local emitter = CardParticles.emit(self, {
        timer = 0.025 * dissolveTime,
        lifespan = 0.7 * dissolveTime,
        scale = 0.25,
        speed = 60,
        colours = self.dissolve_colours,
        fill = true,
        max = 40,
    })

    if not silent then
        local Sfx = require("src.systems.Sfx")
        if em and ev then
            em.after(0.0, function()
                pcall(function() Sfx.play("cardDraw") end)
            end)
        end
    end

    if em and ev then
        em.add(ev:new({
            trigger = "ease",
            delay = dissolveTime,
            blocking = false,
            ease = {
                ref_table = self,
                ref_value = "dissolve",
                ease_to = 0,
                type = "smooth",
            },
        }))
        em.after(0.5 * dissolveTime, function()
            emitter:stop()
        end)
        em.after(1.05 * dissolveTime, function()
            emitter:fade(0.2)
            if onComplete then onComplete() end
        end)
    else
        self.dissolve = 0
        if onComplete then onComplete() end
    end
end

function Card:explode(colours, timeFac, onComplete)
    local em, ev = EM(), Ev()
    local explodeTime = 1.3 * (timeFac or 1)
    self.dissolve = 0
    self.dissolve_colours = colours or DissolveShader.palette("booster")

    local Sfx = require("src.systems.Sfx")
    pcall(function() Sfx.play("cardExhaust") end)

    local parts1 = CardParticles.emit(self, {
        timer = 0.01 * explodeTime,
        lifespan = 0.2 * explodeTime,
        scale = 0.3,
        speed = 30,
        colours = self.dissolve_colours,
        fill = true,
        max = 50,
    })

    if em and ev then
        em.add(ev:new({
            blocking = false,
            trigger = "after",
            delay = 0.9 * explodeTime,
            func = function()
                em.add(ev:new({
                    trigger = "ease",
                    delay = 0.3 * explodeTime,
                    blocking = false,
                    ease = { ref_table = self, ref_value = "dissolve", ease_to = 0.3, type = "smooth" },
                }))
                return true
            end,
        }))

        em.after(0.9 * explodeTime, function()
            local parts2 = CardParticles.emit(self, {
                timer = 0.003 * explodeTime,
                lifespan = 0.5,
                scale = 0.6,
                speed = 180,
                colours = self.dissolve_colours,
                fill = true,
                pulse_max = 30,
                max = 40,
            })
            parts1:fade(0.3 * explodeTime)
            self:juice_up(0.5, 0.2)
            if _G.triggerShake then _G.triggerShake(10, 0.3) end
            pcall(function()
                if Sfx.has and Sfx.has("cardExplode") then
                    Sfx.play("cardExplode")
                else
                    Sfx.play("enemyDeath")
                end
            end)

            em.add(ev:new({
                trigger = "ease",
                delay = 0.1 * explodeTime,
                blocking = false,
                ease = { ref_table = self, ref_value = "dissolve", ease_to = 1, type = "smooth" },
            }))

            em.after(0.4, function() parts2:fade(0.2) end)
        end)

        em.after(1.5 * explodeTime, function()
            self:markRemoved()
            if onComplete then onComplete() end
        end)
    else
        self.dissolve = 1
        self:markRemoved()
        if onComplete then onComplete() end
    end
end

function Card:flip(onHalfway, onComplete)
    local em, ev = EM(), Ev()
    if not em or not ev then
        if onHalfway then onHalfway() end
        if onComplete then onComplete() end
        return
    end

    em.add(ev:new({
        trigger = "ease",
        delay = 0.15,
        blocking = false,
        ease = { ref_table = self, ref_value = "_flip", ease_to = 0.5, type = "smooth" },
    }))
    em.after(0.15, function()
        if onHalfway then onHalfway() end
    end)
    em.add(ev:new({
        trigger = "ease",
        delay = 0.15,
        blocking = false,
        ease = { ref_table = self, ref_value = "_flip", ease_to = 0, type = "smooth" },
    }))
    em.after(0.30, function()
        if onComplete then onComplete() end
    end)
end

function Card:use(target)
    if self.type == "attack" then
        target:takeDamage(self.attack)
    elseif self.type == "defense" then
        target:addDefense(self.defense)
    end

    self.passive(target)
end

function Card.hoverTilt(relX, relY)
    if relX < 0 then relX = 0 elseif relX > 1 then relX = 1 end
    if relY < 0 then relY = 0 elseif relY > 1 then relY = 1 end
    local C = Config.Cards
    local nx, ny = (relX - 0.5) * 2, (relY - 0.5) * 2
    local centerDistance = math.sqrt(nx * nx + ny * ny)
    local depth = 1 - (centerDistance * 0.3)
    local tiltX = nx * C.TILT_RANGE + (nx * C.DEPTH_TILT_X * depth)
    local tiltY = ny * C.TILT_RANGE + (ny * C.DEPTH_TILT_Y * depth)
    local range = C.TILT_RANGE or 0.15
    local function n1(v) v = v / range; if v > 1 then return 1 elseif v < -1 then return -1 end return v end
    return {
        nx = nx, ny = ny, depth = depth, centerDistance = centerDistance,
        tiltX = tiltX, tiltY = tiltY, uvX = n1(tiltX), uvY = n1(tiltY),
        offsetX = nx * C.MOVE_RANGE * depth, offsetY = ny * C.MOVE_RANGE * depth,
        shadowX = C.SHADOW_OFFSET_BASE_X + (nx * C.SHADOW_STRETCH_X * depth),
        shadowY = C.SHADOW_OFFSET_BASE_Y + (ny * C.SHADOW_STRETCH_Y * depth),
        shadowScale = C.SHADOW_SCALE_BASE - (centerDistance * C.SHADOW_SCALE_VARIATION),
        rot = nx * 0.05 * depth,
    }
end

function Card:updateMouse(mx, my, dt, isHovered)
    local layoutX = self.layoutX or self.x
    local layoutY = self.layoutY or self.y
    local scaleFactor = self.targetScale or self.currentScale
    local cardWidth = self.image:getWidth() * scaleFactor
    local cardHeight = self.image:getHeight() * scaleFactor

    local offsetY = 0
    local extraMarginTop = 0
    local extraMarginBottom = 0
    if self.isHovered and not self.noHoverLift then
        if self.isRewardCard then
            offsetY = Config.Cards.DEPTH_OFFSET
            extraMarginTop = Config.Cards.LIFT_AMOUNT or 0
        else
            offsetY = -Config.Cards.DEPTH_OFFSET
            extraMarginBottom = Config.Cards.LIFT_AMOUNT or 0
        end
    end

    local minX = math.min(layoutX, self.x)
    local maxX = math.max(layoutX, self.x)
    local minY = math.min(layoutY, self.y)
    local maxY = math.max(layoutY, self.y)

    local wasHovered = self.isHovered
    local bboxLeft = minX
    local bboxRight = maxX + cardWidth
    local bboxTop = minY + offsetY - extraMarginTop
    local bboxBottom = maxY + offsetY + cardHeight + extraMarginBottom
    if mx >= bboxLeft and mx <= bboxRight and my >= bboxTop and my <= bboxBottom and
        isHovered then
        self.isHovered = true
        require("src.ui.CursorManager").request("hand")
        self.targetScale = self.baseScale * (Config.Cards.HOVER_SCALE_MULT or 1.06)
        if not wasHovered then
            Sfx.playWithVariation("hoverCard", 0.95, 0.18)
            Moveable.juice_up(self, 0.05, 0.03)
        end

        local ht = Card.hoverTilt((mx - self.x) / cardWidth, (my - (self.y + offsetY)) / cardHeight)
        local depthMultiplier = ht.depth

        self.offsetHoverX = ht.offsetX
        self.offsetHoverY = ht.offsetY

        self.tiltX = ht.tiltX
        self.tiltY = ht.tiltY

        local liftAmount = Config.Cards.LIFT_AMOUNT
        if self.noHoverLift then
            self.liftOffset = 0
        elseif self.isRewardCard then
            self.liftOffset = -liftAmount * depthMultiplier
        else
            self.liftOffset = liftAmount * depthMultiplier
        end

        self.shadowOffsetX = ht.shadowX
        self.shadowOffsetY = ht.shadowY
        self.shadowScale = ht.shadowScale

        self.perspectiveRotation = ht.rot

    else
        self.isHovered = false
        self.targetScale = self.baseScale

        self.offsetHoverX = 0
        self.offsetHoverY = 0
        self.tiltX = 0
        self.tiltY = 0
        self.liftOffset = 0
        self.perspectiveRotation = 0
        self.shadowOffsetX = 0
        self.shadowOffsetY = 0
        self.shadowScale = 0.9

        if _G.gameSettings and _G.gameSettings.reducedMotion then
            self.tiltX = 0
            self.tiltY = 0
        else
            self._ambientTime = (self._ambientTime or 0) + dt
            local ambient = math.sin(self._ambientTime * Config.Cards.AMBIENT_TILT_SPEED + self._ambientSeed)
            self.tiltX = ambient * Config.Cards.AMBIENT_TILT_AMOUNT
            self.tiltY = math.cos(self._ambientTime * Config.Cards.AMBIENT_TILT_SPEED * 0.7 + self._ambientSeed) * Config.Cards.AMBIENT_TILT_AMOUNT * 0.6
        end
    end

    Moveable.updateJuice(self, dt)

    local ease = 1 - math.exp(-Config.Cards.SCALE_EASE_K * dt)
    self.currentScale = self.currentScale + (self.targetScale - self.currentScale) * ease

    if self.isHovered then
        self._bobTime = (self._bobTime or 0) + dt
        self.hoverBob = math.sin(self._bobTime * Config.Cards.HOVER_BOB_SPEED) * Config.Cards.HOVER_BOB_AMOUNT
    else
        self._bobTime = 0
        self.hoverBob = (self.hoverBob or 0) * math.exp(-6 * dt)
    end

    local vx = (self.x - (self._lastX or self.x)) / math.max(dt, 0.001)
    self._lastX = self.x
    local targetTilt = math.max(-Config.Cards.VEL_TILT_MAX, math.min(Config.Cards.VEL_TILT_MAX, vx * Config.Cards.VEL_TILT_GAIN))
    local tiltEase = 1 - math.exp(-Config.Cards.VEL_TILT_DAMP * dt)
    self._velTilt = (self._velTilt or 0) + (targetTilt - (self._velTilt or 0)) * tiltEase

    local targetHover = self.isHovered and 1 or 0
    local hoverEaseK = Config.Cards.HOVER_STRENGTH_EASE_K or 14
    local hoverEase = 1 - math.exp(-hoverEaseK * dt)
    self.hoverStrength = (self.hoverStrength or 0) + (targetHover - (self.hoverStrength or 0)) * hoverEase

    self.borderAnimationTime = self.borderAnimationTime + dt * Config.Cards.BORDER_ANIMATION_SPEED
end

function Card:setTargetPos(tx, ty)
    self.targetX = tx
    self.targetY = ty
    if not self._posInitialized then
        self.renderX = tx
        self.renderY = ty
        self._posInitialized = true
    end
end

function Card:updateRender(dt)
    local k = 16
    local ease = 1 - math.exp(-k * dt)
    self.renderX = self.renderX + (self.targetX - self.renderX) * ease
    self.renderY = self.renderY + (self.targetY - self.renderY) * ease
end

function Card:setRenderPos(rx, ry)
    self.renderX = rx
    self.renderY = ry
    self.targetX = rx
    self.targetY = ry
end

function Card:_getOffscreenCanvas()
    local w = self.image:getWidth()
    local h = self.image:getHeight()
    if not self._offCanvas or self._offCanvasW ~= w or self._offCanvasH ~= h then
        self._offCanvas = love.graphics.newCanvas(w, h)
        self._offCanvas:setFilter("nearest", "nearest")
        self._offCanvasW, self._offCanvasH = w, h
    end
    return self._offCanvas
end

function Card:getWidth()
    return self.width or (self.image and self.image:getWidth() * (self.currentScale or self.baseScale) or 0)
end

function Card:getHeight()
    return self.height or (self.image and self.image:getHeight() * (self.currentScale or self.baseScale) or 0)
end

function Card:draw(x, y, showPlayableBorder, isRewardCard)
    showPlayableBorder = false
    self.x = x
    self.y = y

    local _prevImage = self.image
    do
        local shown = CardFrame.displayImage(self)
        if shown then self.image = shown end
    end

    local baseOffsetY = 0
    if self.isHovered and not self.noHoverLift then
        if isRewardCard then
            baseOffsetY = Config.Cards.DEPTH_OFFSET
        else
            baseOffsetY = -Config.Cards.DEPTH_OFFSET
        end
    end
    local hoverOffsetY = self.liftOffset or 0
    local bobOffset = self.hoverBob or 0
    local baseFloat = Config.Cards.BASE_LIFT or 0
    local ambientY = 0
    if not self.isHovered and not self.isDragging then
        ambientY = math.sin(love.timer.getTime() * 0.666 + (self._ambientSeed or 0)) * 3
    end
    local totalOffsetY = baseOffsetY + hoverOffsetY + bobOffset + ambientY - baseFloat
        + Moveable.hopOffset(self)

    local offsetX = (self.offsetHoverX or 0) + Moveable.shoveOffset(self)

    local tiltX = self.tiltX or 0
    local tiltY = (self.tiltY or 0) + (self._velTilt or 0)
    local perspectiveRotation = self.perspectiveRotation or 0

    local s = self.currentScale * Moveable.scaleFactor(self) * Moveable.swellFactor(self)
    local scaleX = s
    local scaleY = s

    if self._flip and self._flip > 0 then
        local flipT = self._flip
        scaleX = s * (1 - flipT * 2)
        if scaleX < 0 then scaleX = -scaleX end
    end

    local imgW = self.image:getWidth() * s
    local cardCxAbs = x + offsetX + imgW / 2
    local screenW = love.graphics.getWidth()
    local dirX = (cardCxAbs - screenW / 2) / (screenW / 2)
    if dirX > 1 then dirX = 1 elseif dirX < -1 then dirX = -1 end
    local tiltNormX = (tiltX or 0) / (Config.Cards.TILT_RANGE or 0.15)
    local tiltNormY = (tiltY or 0) / (Config.Cards.TILT_RANGE or 0.15)
    if tiltNormX > 1 then tiltNormX = 1 elseif tiltNormX < -1 then tiltNormX = -1 end
    if tiltNormY > 1 then tiltNormY = 1 elseif tiltNormY < -1 then tiltNormY = -1 end
    local pressShift = Config.Cards.SHADOW_PRESS_SHIFT or 14
    local shadowOffsetX = -dirX * Config.Cards.SHADOW_MAX_HORIZ_OFFSET
                        - tiltNormX * pressShift * (self.hoverStrength or 0)
    local liftTotal = math.abs(hoverOffsetY) + baseFloat
    local shadowOffsetY = Config.Cards.SHADOW_BASE_OFFSET_Y + liftTotal * 0.5
                        - tiltNormY * pressShift * (self.hoverStrength or 0) * 0.7
    local shadowAlpha = Config.Cards.SHADOW_ALPHA + (self.isDragging and 0.15 or 0) + liftTotal * 0.003
    if shadowAlpha > 0.85 then shadowAlpha = 0.85 end
    if self.dissolve and self.dissolve > 0.001 then
        shadowAlpha = shadowAlpha * (1 - self.dissolve)
    end

    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.push()

    local cardCenterX = x + offsetX + (self.image:getWidth() * scaleX) / 2
    local cardCenterY = y + totalOffsetY + (self.image:getHeight() * scaleY) / 2
    self.lastDrawRect = { x = x + offsetX, y = y + totalOffsetY,
        w = self.image:getWidth() * scaleX, h = self.image:getHeight() * scaleY }
    require("src.ui.NavCursor").target(self, self.lastDrawRect.x, self.lastDrawRect.y,
        self.lastDrawRect.w, self.lastDrawRect.h,
        { py = 0.82, group = self.navGroup })

    love.graphics.translate(cardCenterX, cardCenterY)

    love.graphics.rotate(perspectiveRotation + Moveable.rotOffset(self))

    love.graphics.scale(scaleX, scaleY)

    local drawX = -self.image:getWidth() / 2
    local drawY = -self.image:getHeight() / 2

    local mouseUV = {
        (tiltX or 0) / (Config.Cards.TILT_RANGE or 0.15),
        (tiltY or 0) / (Config.Cards.TILT_RANGE or 0.15),
    }
    if mouseUV[1] > 1 then mouseUV[1] = 1 elseif mouseUV[1] < -1 then mouseUV[1] = -1 end
    if mouseUV[2] > 1 then mouseUV[2] = 1 elseif mouseUV[2] < -1 then mouseUV[2] = -1 end

    local hoverAmt = self.hoverStrength or 0
    local timeNow = love.timer.getTime()
    local shader = CardMesh.getShader()
    local fx = self.visualEffect

    if shader then
        local mesh = CardMesh.getMesh(self.image:getWidth(), self.image:getHeight())
        mesh:setTexture(self.image)
        love.graphics.setShader(shader)
        CardMesh.setUniforms(shader, mouseUV, hoverAmt, timeNow, self.image)
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        love.graphics.draw(mesh, drawX + shadowOffsetX / s, drawY + shadowOffsetY / s)
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        love.graphics.draw(self.image, drawX + shadowOffsetX / s, drawY + shadowOffsetY / s)
        love.graphics.setColor(1, 1, 1, 1)
    end

    if self.dissolve and self.dissolve > 0.001 then
        if DissolveShader.isAvailable() then
            DissolveShader.apply(self.image, self.dissolve, self.dissolve_colours)
            love.graphics.draw(self.image, drawX, drawY)
            DissolveShader.clear()
        else
            local alpha = 1 - self.dissolve
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(self.image, drawX, drawY)
            love.graphics.setColor(1, 1, 1, 1)
        end
    elseif self.edition then
        local editionShader, editionStrength = self:_getEditionShader()
        local holoGate = self:_holoGate(hoverAmt)
        local offCanvas = self:_getOffscreenCanvas()
        local prevCanvas = love.graphics.getCanvas()
        love.graphics.setCanvas(offCanvas)
        love.graphics.push("all")
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 0)
        if shader then
            local mesh = CardMesh.getMesh(self.image:getWidth(), self.image:getHeight())
            mesh:setTexture(self.image)
            love.graphics.setShader(shader)
            CardMesh.setUniforms(shader, mouseUV, hoverAmt, timeNow, self.image)
            love.graphics.draw(mesh, 0, 0)
            love.graphics.setShader()
        else
            love.graphics.draw(self.image, 0, 0)
        end
        love.graphics.pop()
        love.graphics.setCanvas(prevCanvas)
        if editionShader == HoloShader then
            HoloShader.draw(offCanvas, drawX, drawY, HoloShader.strengthFor("holo", holoGate),
                0, 1, 1, 0, 0, { kind = 1, anim = holoGate })
        elseif editionShader and editionShader.draw then
            editionShader.draw(offCanvas, drawX, drawY, editionStrength, 0, 1, 1)
        else
            love.graphics.draw(offCanvas, drawX, drawY)
        end
    elseif shader and fx ~= "holo" and fx ~= "glow" then
        local mesh = CardMesh.getMesh(self.image:getWidth(), self.image:getHeight())
        mesh:setTexture(self.image)
        love.graphics.setShader(shader)
        CardMesh.setUniforms(shader, mouseUV, hoverAmt, timeNow, self.image)
        if self.saleDim then love.graphics.setColor(0.55, 0.52, 0.48, 1) end
        love.graphics.draw(mesh, drawX, drawY)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setShader()
    elseif (fx == "holo" or fx == "glow") then
        local holoGate = self:_holoGate(hoverAmt)
        local strength = HoloShader.strengthFor(fx, holoGate)
        local offCanvas = self:_getOffscreenCanvas()
        local prevCanvas = love.graphics.getCanvas()
        love.graphics.setCanvas(offCanvas)
        love.graphics.push("all")
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 0)
        if shader then
            local mesh = CardMesh.getMesh(self.image:getWidth(), self.image:getHeight())
            mesh:setTexture(self.image)
            love.graphics.setShader(shader)
            CardMesh.setUniforms(shader, mouseUV, hoverAmt, timeNow, self.image)
            love.graphics.draw(mesh, 0, 0)
            love.graphics.setShader()
        else
            love.graphics.draw(self.image, 0, 0)
        end
        love.graphics.pop()
        love.graphics.setCanvas(prevCanvas)
        HoloShader.draw(offCanvas, drawX, drawY, strength, 0, 1, 1, 0, 0,
            { kind = (fx == "holo") and 1 or 0, anim = holoGate })
    else
        if self.saleDim then love.graphics.setColor(0.55, 0.52, 0.48, 1) end
        love.graphics.draw(self.image, drawX, drawY)
        love.graphics.setColor(1, 1, 1, 1)
    end

    if CardAnimationLayer.isEnabled() then
        if not self._cachedArt then
            local okA, a = pcall(CardArt.resolve, self)
            self._cachedArt = okA and a or { bgPattern = nil }
        end
        CardAnimationLayer.draw(self, self._cachedArt, drawX, drawY, 1, 1)
    end

    if self.seal then
        self:_drawSealIndicator(drawX, drawY)
    end

    if self.isNewDiscovery then
        require("src.ui.DiscoveryMark").drawOnCard(self, self.image, drawX, drawY,
            mouseUV, hoverAmt, timeNow)
    end

    love.graphics.pop()

    self.image = _prevImage

    if self.isHovered and not isRewardCard then
        local anchorY = y + totalOffsetY
        if self.tooltipBelow then
            anchorY = anchorY + (self.image and self.image:getHeight() or 144)
                * (self.currentScale or 1)
        end
        local opts = self._tooltipOpts or {}
        self._tooltipOpts = opts
        opts.showRarity = false
        opts.showStats = true
        opts.showDescription = true
        opts.below = self.tooltipBelow
        opts.side = self.tooltipSide
        opts.cardX = x + offsetX
        opts.cardW = imgW
        opts.minY = self.tooltipMinY
        if self.deferTooltip then
            self._tooltipAt = self._tooltipAt or {}
            self._tooltipAt.x, self._tooltipAt.y = x, anchorY
            self._tooltipPending = true
        else
            self.cardInfoDisplay:draw(self, x, anchorY, opts)
        end
    end
end

function Card:drawDeferredTooltip()
    if not self._tooltipPending then return false end
    self._tooltipPending = false
    local at = self._tooltipAt
    self.cardInfoDisplay:draw(self, at.x, at.y, self._tooltipOpts)
    return true
end

function Card:_holoGate(hoverAmt)
    local gate = hoverAmt or self.hoverStrength or 0
    if self.isSelected then gate = 1 end
    if gate > 1 then gate = 1 elseif gate < 0 then gate = 0 end
    return gate
end

local EDITION_SHADERS = {
    foil       = { shader = FoilShader,       strength = 0.6 },
    holo       = { shader = HoloShader,       strength = 0.5 },
    polychrome = { shader = PolychromeShader, strength = 0.7 },
}

function Card:_getEditionShader()
    if not self.edition then return nil, 0 end
    local entry = EDITION_SHADERS[self.edition]
    if not entry or not entry.shader then return nil, 0 end
    if entry.shader.isAvailable and not entry.shader.isAvailable() then
        return nil, 0
    end
    return entry.shader, entry.strength
end

function Card:setEdition(editionName, options)
    options = options or {}
    self.edition = editionName

    if options.silent then return end

    if editionName then
        Moveable.juice_up(self, 0.5)
        local sfxByEdition = {
            foil = "deckStart", holo = "deckStart",
            polychrome = "deckStart",
        }
        local sfxName = sfxByEdition[editionName]
        if sfxName then Sfx.play(sfxName) end
    end
end

function Card:setSeal(sealName, options)
    options = options or {}
    self.seal = sealName
    if options.silent then return end
    if sealName then
        Moveable.juice_up(self, 0.3)
        Sfx.play("cardSelect")
    end
end

local SEAL_COLORS = {
    Red    = {0.85, 0.18, 0.18},
    Blue   = {0.30, 0.55, 0.95},
    Gold   = {0.95, 0.78, 0.20},
    Purple = {0.62, 0.32, 0.85},
}
function Card:_drawSealIndicator(drawX, drawY)
    local color = SEAL_COLORS[self.seal]
    if not color then return end

    local alpha = 1
    if self.dissolve and self.dissolve > 0.001 then
        alpha = math.max(0, 1 - self.dissolve)
    end

    local cx = drawX + 8
    local cy = drawY + 8
    local radius = 5
    local t = love.timer.getTime() * 2
    local pulse = 1 + 0.08 * math.sin(t + (self._ambientSeed or 0))
    local r = radius * pulse

    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.35)
    love.graphics.circle("fill", cx, cy, r + 2)
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.circle("fill", cx, cy, r)
    love.graphics.setColor(0, 0, 0, alpha * 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.setColor(1, 1, 1, 1)
end

return Card
