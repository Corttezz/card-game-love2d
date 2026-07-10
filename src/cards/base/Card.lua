local Config = require("src.core.Config")
local CardInfoDisplay = require("src.ui.CardInfoDisplay")
local ImageCache = require("src.ui.ImageCache")
local HoloShader = require("src.ui.HoloShader")
local FoilShader = require("src.ui.FoilShader")
local PolychromeShader = require("src.ui.PolychromeShader")
local NegativeShader = require("src.ui.NegativeShader")
local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")
local CardArt = require("src.ui.CardArt")
local Sfx = require("src.systems.Sfx")
local CardMesh = require("src.ui.CardMesh")
local Moveable = require("engine.Moveable")
local DissolveShader = require("src.ui.DissolveShader")
local CardParticles = require("src.systems.CardParticles")
local Palette = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local FontManager = require("src.ui.FontManager")

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
    
    -- Carrega imagem via cache (fallback automático em caso de erro)
    instance.image = ImageCache.get(imagePath)

    -- Propriedades para hover e animação usando Config
    instance.x = 0 -- Posição X
    instance.y = 0 -- Posição Y
    instance.baseScale = Config.Cards.BASE_SCALE -- Tamanho base
    instance.targetScale = instance.baseScale -- Escala-alvo
    instance.currentScale = instance.baseScale -- Escala atual
    instance.width = instance.image:getWidth() * instance.baseScale
    instance.height = instance.image:getHeight() * instance.baseScale
    instance.isHovered = false -- Estado de hover
    
    -- Animação da borda
    instance.borderAnimationTime = 0 -- Tempo para animação da borda
    
    -- Componente para exibir informações da carta
    instance.cardInfoDisplay = CardInfoDisplay:new()
    -- Configura para cartas na mão (sem raridade por padrão)
    instance.cardInfoDisplay:configure({
        showRarity = false,
        showStats = true,
        showDescription = true
    })
    
    -- Ícones compartilhados entre todas as cartas (cache global)
    instance.attackIcon = ImageCache.get("assets/icons/attack.png")
    instance.manaIcon = ImageCache.get("assets/icons/mana.png")
    instance.armorIcon = ImageCache.get("assets/icons/armor.png")

    -- Drag state (Balatro-style reorder em hand + collection)
    instance.dragPending = false  -- mouse-down aconteceu mas não passou threshold
    instance.dragStartMX = 0
    instance.dragStartMY = 0
    instance.isDragging  = false
    instance.dragOffsetX = 0      -- posição da carta relativa ao mouse
    instance.dragOffsetY = 0

    -- Posição animada (eases towards targetX/Y pra movimento suave durante reorder)
    instance.targetX = 0
    instance.targetY = 0
    instance.renderX = 0 -- posição efetivamente desenhada (lerps em direção a targetX)
    instance.renderY = 0

    -- Juice (Moveable engine): kick multiplicativo de scale/rot quando a
    -- carta é selecionada, jogada, ou vira joker. Decai em ~0.4s.
    Moveable.initJuice(instance)

    -- Ambient tilt: cartas ociosas ondulam levemente (senóide defasada por id).
    -- ambientSeed garante que cartas da mão não oscilam em sync.
    instance._ambientSeed = love.math.random() * math.pi * 2
    instance._ambientTime = 0

    -- Estado de dissolve (0 = visível, 1 = sumiu). Animado por
    -- start_dissolve/start_materialize/explode via EventManager.ease.
    instance.dissolve = 0
    instance.dissolve_colours = nil
    instance._removed = false  -- flag pra CardParticles saber que carta sumiu

    -- Sistema de upgrade (Fase 3.1): N+ aplicado pelo RunManager:applyUpgradesToInstance.
    -- 0 = não forjada. >=1 = forjada N vezes (+2 atk/def por level + boost de effect).
    -- Render: badge "+N" desenhado em Card:_drawUpgradeBadge.
    instance.upgrades = 0
    -- Edition (Fase 3.2): nil | "foil" | "holo" | "polychrome" | "negative".
    instance.edition = nil
    -- Seal (Fase 3.3): nil | "Red" | "Blue" | "Gold" | "Purple".
    instance.seal = nil

    -- Flip state (0 = face pra cima, 1 = face pra baixo). Scale X colapsa
    -- no meio → ilusão de virada 3D sem shader.
    instance._flip = 0 -- 0..1..0 durante a anim; 0 estático

    return instance
end

-- Dispara juice kick. Proxy pro Moveable; usar nos momentos de "algo aconteceu":
--   card:juice_up(0.3, 0.1)  -- selecionada
--   card:juice_up(0.5, 0.15) -- jogada (mais forte)
function Card:juice_up(scale_mod, rot_mod)
    Moveable.juice_up(self, scale_mod, rot_mod)
end

-- ============================================================================
-- CARD STATE ANIMATIONS (inspirado em card.lua do Balatro, linhas 1973-2240)
-- ============================================================================
-- Todas coreografadas via _G.EventManager. Chame em resposta a eventos de jogo
-- ("carta exhausted", "joker comprado materializa", "pack abriu → explode").

-- Helper: acessa EventManager se disponível (fallback gracioso).
local function EM()
    return _G.EventManager
end
local function Ev()
    return _G.Event
end

-- Marca carta como removida (pra CardParticles fazer cleanup). Callers que
-- removem a carta do mundo (discard, exhaust) devem chamar após a anim.
function Card:markRemoved()
    self._removed = true
end

-- Cancela qualquer animação de dissolve pendente (ease + markRemoved + fades).
-- Usado em Game:drawCard quando a carta é reciclada de volta pra mão: sem isso,
-- o ease continua rodando e sobrescreve `self.dissolve` após o reset, fazendo
-- a carta "desaparecer" na mão do jogador.
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

-- ------ start_dissolve ------
-- Animação de destruição: carta queima progressivamente e some. Usar em
-- exhaust, vendida, destruída por efeito.
--
-- @param colours {c1, c2} — burn colors (default: laranja/vermelho)
-- @param silent bool      — não toca som
-- @param timeFac number    — multiplicador de duração (default 1 → 0.7s total)
-- @param noJuice bool      — skip juice_up inicial
-- @param onComplete fn     — chamado ao final (útil pra remover do deck/hand)
function Card:start_dissolve(colours, silent, timeFac, noJuice, onComplete)
    -- Se outra dissolve anim já roda (caso raro — replay rápido), cancela
    -- antes de começar pra não ter 2 eases competindo.
    self:cancelDissolveAnim()
    local em, ev = EM(), Ev()
    local dissolveTime = 0.7 * (timeFac or 1)
    self.dissolve = 0
    self.dissolve_colours = colours or DissolveShader.palette("default")
    self._dissolveEvents = {}

    if not noJuice then self:juice_up(0.3, 0.08) end

    -- Partículas "cinzas voando" durante a queima
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
        -- Som leve de "papel sendo comprimido". Opcional — não falha se não existir.
        if em and ev then
            em.after(0.0, function()
                pcall(function() Sfx.play("cardExhaust") end)
            end)
        end
    end

    if em and ev then
        -- Ease do dissolve 0 → 1 ao longo da duração. Evento é trackeado em
        -- self._dissolveEvents pra poder ser cancelado via cancelDissolveAnim.
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

        -- Fade particles + cleanup
        table.insert(self._dissolveEvents, em.after(0.7 * dissolveTime, function()
            emitter:fade(0.3 * dissolveTime)
        end))
        table.insert(self._dissolveEvents, em.after(1.05 * dissolveTime, function()
            self:markRemoved()
            if onComplete then onComplete() end
        end))
    else
        -- Sem EventManager: snap imediato
        self.dissolve = 1
        self:markRemoved()
        if onComplete then onComplete() end
    end
end

-- ------ start_materialize ------
-- Reverso do dissolve: carta aparece "montando" a partir do nada. Usar em
-- comprar carta, receber recompensa, joker novo.
--
-- @param colours, silent, timeFac mesmos de start_dissolve
-- @param onComplete fn
function Card:start_materialize(colours, silent, timeFac, onComplete)
    local em, ev = EM(), Ev()
    local dissolveTime = 0.6 * (timeFac or 1)
    self.dissolve = 1
    self.dissolve_colours = colours or DissolveShader.palette(self.type or "default")
    self:juice_up(0.2, 0.05)

    -- Partículas coloridas ao redor enquanto materializa
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

-- ------ explode ------
-- Dissolução dramática com juice intenso, 2 pulsos de partículas, shake.
-- Usar em booster pack opening (carta source estoura → spawn de resultados).
--
-- @param colours, timeFac
-- @param onComplete fn
function Card:explode(colours, timeFac, onComplete)
    local em, ev = EM(), Ev()
    local explodeTime = 1.3 * (timeFac or 1)
    self.dissolve = 0
    self.dissolve_colours = colours or DissolveShader.palette("booster")

    local Sfx = require("src.systems.Sfx")
    pcall(function() Sfx.play("cardExhaust") end)

    -- Fase 1: partículas lentas, "carregando"
    local parts1 = CardParticles.emit(self, {
        timer = 0.01 * explodeTime,
        lifespan = 0.2 * explodeTime,
        scale = 0.3,
        speed = 30,
        colours = self.dissolve_colours,
        fill = true,
        max = 50,
    })

    -- Shake contínuo durante o "carregamento" via juice manual
    if em and ev then
        em.add(ev:new({
            blocking = false,
            trigger = "after",
            delay = 0.9 * explodeTime,
            func = function()
                -- Ease inicial dissolve 0 → 0.3 (textura começa a perder)
                em.add(ev:new({
                    trigger = "ease",
                    delay = 0.3 * explodeTime,
                    blocking = false,
                    ease = { ref_table = self, ref_value = "dissolve", ease_to = 0.3, type = "smooth" },
                }))
                return true
            end,
        }))

        -- Fase 2: explosão — partículas rápidas, shake, dissolve completo
        em.after(0.9 * explodeTime, function()
            local parts2 = CardParticles.emit(self, {
                timer = 0.003 * explodeTime,
                lifespan = 0.5,
                scale = 0.6,
                speed = 180,
                colours = self.dissolve_colours,
                fill = true,
                pulse_max = 30, -- explosão curta, não contínua
                max = 40,
            })
            parts1:fade(0.3 * explodeTime)
            self:juice_up(0.5, 0.2)
            if _G.triggerShake then _G.triggerShake(10, 0.3) end
            pcall(function() Sfx.play("enemyDeath") end) -- som de "boom" disponível

            -- Dissolve final 0.3 → 1
            em.add(ev:new({
                trigger = "ease",
                delay = 0.1 * explodeTime,
                blocking = false,
                ease = { ref_table = self, ref_value = "dissolve", ease_to = 1, type = "smooth" },
            }))

            -- Limpa parts2 após o burst
            em.after(0.4, function() parts2:fade(0.2) end)
        end)

        -- Cleanup final
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

-- ------ flip ------
-- Vira a carta (ilusão 3D colapsando scaleX). 0.3s total. Aplica no draw.
function Card:flip(onHalfway, onComplete)
    local em, ev = EM(), Ev()
    if not em or not ev then
        if onHalfway then onHalfway() end
        if onComplete then onComplete() end
        return
    end

    -- Fase 1: scale X → 0 em 0.15s
    em.add(ev:new({
        trigger = "ease",
        delay = 0.15,
        blocking = false,
        ease = { ref_table = self, ref_value = "_flip", ease_to = 0.5, type = "smooth" },
    }))
    em.after(0.15, function()
        if onHalfway then onHalfway() end
    end)
    -- Fase 2: scale X → 1 em 0.15s
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

function Card:updateMouse(mx, my, dt, isHovered)
    -- Bbox de detecção: UNIÃO da posição home (layoutX/Y) com a renderizada
    -- (self.x/y animado). Cobrindo as duas, o usuário consegue:
    -- 1) entrar em hover na posição home da carta na mão;
    -- 2) seguir a carta com o mouse enquanto ela sobe (ex: cardY-130 em
    --    GameplayScene) sem perder o hover;
    -- 3) sair do hover só quando o mouse de fato deixa o caminho inteiro do lift.
    --
    -- Sem isso voltavam os dois bugs:
    -- - se o bbox seguisse só self.y, o lift saía do mouse → flicker.
    -- - se o bbox ficasse só em layoutY, o usuário não conseguia hoverar a
    --   versão lifted da carta.
    --
    -- targetScale (vs currentScale): evita encolhimento bistável quando offsetY
    -- pula -DEPTH_OFFSET imediato e a altura ainda está em ease.
    local layoutX = self.layoutX or self.x
    local layoutY = self.layoutY or self.y
    local scaleFactor = self.targetScale or self.currentScale
    local cardWidth = self.image:getWidth() * scaleFactor
    local cardHeight = self.image:getHeight() * scaleFactor

    -- Calcula deslocamento vertical se estiver em hover
    local offsetY = 0
    -- Margem extra na direção do lift visual interno (liftOffset dentro do
    -- Card:draw). Sem isso, mouse na borda visível da carta lifted sai do bbox.
    local extraMarginTop = 0
    local extraMarginBottom = 0
    if self.isHovered and not self.noHoverLift then
        if self.isRewardCard then
            offsetY = Config.Cards.DEPTH_OFFSET
            extraMarginTop = Config.Cards.LIFT_AMOUNT or 0  -- reward sobe
        else
            offsetY = -Config.Cards.DEPTH_OFFSET
            extraMarginBottom = Config.Cards.LIFT_AMOUNT or 0  -- hand desce
        end
    end

    -- União home + render: cobre todo o caminho do lift externo (cardY → cardY-130)
    local minX = math.min(layoutX, self.x)
    local maxX = math.max(layoutX, self.x)
    local minY = math.min(layoutY, self.y)
    local maxY = math.max(layoutY, self.y)

    -- Verifica se o mouse está sobre a carta ajustada
    local wasHovered = self.isHovered
    local bboxLeft = minX
    local bboxRight = maxX + cardWidth
    local bboxTop = minY + offsetY - extraMarginTop
    local bboxBottom = maxY + offsetY + cardHeight + extraMarginBottom
    if mx >= bboxLeft and mx <= bboxRight and my >= bboxTop and my <= bboxBottom and
        isHovered then
        self.isHovered = true
        -- cursor "mão" sobre carta (mesmo contrato do Button)
        require("src.ui.CursorManager").request("hand")
        -- Hover proporcional ao baseScale (não hardcode global). Antes
        -- usávamos Config.Cards.HOVER_SCALE fixo em 1.466 — quebrava cards
        -- com baseScale custom (ex: shop com slot maior, baseScale ~2.4).
        -- Hover bump 1.06× é suficiente pra feedback visual sem dominar a tela.
        self.targetScale = self.baseScale * (Config.Cards.HOVER_SCALE_MULT or 1.06)
        if not wasHovered then
            -- Pitch random + juice kick: hover-enter Balatro-style
            -- (engine/text.lua:201 + card.lua:4307). Cada hover soa diferente
            -- e a carta "salta" sutilmente, dando feedback tátil sem precisar
            -- de animação extra.
            -- F12.5: SEM baseVolume aqui — AudioManager usa Config.Audio.HOVER_VOLUME
            -- (=0.03) carregado em main.lua. Antes 0.5 sobrescrevia, tocando 17x
            -- mais alto que pretendido (queixa "barulho da carta sai muito alto").
            Sfx.playWithVariation("hoverCard", 0.95, 0.18)
            Moveable.juice_up(self, 0.05, 0.03)
        end

        -- *** Efeito de movimento 3D Balatro-style ***
        -- Tilt relativo à posição renderizada (animada): cursor "puxa" a carta
        -- visualmente, mesmo se o mouse estiver fora do bbox visível (clamp).
        local mouseXRelative = (mx - self.x) / cardWidth
        local mouseYRelative = (my - (self.y + offsetY)) / cardHeight
        if mouseXRelative < 0 then mouseXRelative = 0 elseif mouseXRelative > 1 then mouseXRelative = 1 end
        if mouseYRelative < 0 then mouseYRelative = 0 elseif mouseYRelative > 1 then mouseYRelative = 1 end

        -- Normaliza para [-1, 1] para efeitos mais naturais
        local normalizedX = (mouseXRelative - 0.5) * 2
        local normalizedY = (mouseYRelative - 0.5) * 2

        -- *** Efeito de profundidade baseado na posição do mouse ***
        local depthStrength = Config.Cards.PERSPECTIVE_STRENGTH
        local depthOffset = Config.Cards.DEPTH_OFFSET
        
        -- Quanto mais próximo do centro, mais "profunda" a carta fica
        local centerDistance = math.sqrt(normalizedX^2 + normalizedY^2)
        local depthMultiplier = 1 - (centerDistance * 0.3)
        
        -- Deslocamento baseado na profundidade percebida
        self.offsetHoverX = normalizedX * Config.Cards.MOVE_RANGE * depthMultiplier
        self.offsetHoverY = normalizedY * Config.Cards.MOVE_RANGE * depthMultiplier
        
        -- *** Efeito de rotação 3D Balatro-style ***
        local tiltRange = Config.Cards.TILT_RANGE
        local depthTiltX = Config.Cards.DEPTH_TILT_X
        local depthTiltY = Config.Cards.DEPTH_TILT_Y
        
        -- Inclinação baseada na posição do mouse + profundidade
        self.tiltX = normalizedX * tiltRange + (normalizedX * depthTiltX * depthMultiplier)
        self.tiltY = normalizedY * tiltRange + (normalizedY * depthTiltY * depthMultiplier)
        
        -- *** Efeito de elevação (carta "levanta" do fundo) ***
        -- noHoverLift: usado em shop/relic onde cartas devem ficar paradas
        -- na posição (Balatro shop pattern — cartas só escalam +6% sem se
        -- mover). Mantém tilt 3D + scale + halo, mas zero translation Y.
        local liftAmount = Config.Cards.LIFT_AMOUNT
        if self.noHoverLift then
            self.liftOffset = 0
        elseif self.isRewardCard then
            -- Cartas de reward sobem no hover (liftOffset negativo)
            self.liftOffset = -liftAmount * depthMultiplier
        else
            -- Cartas da mão descem no hover (liftOffset positivo)
            self.liftOffset = liftAmount * depthMultiplier
        end
        
        -- *** Sombra dinâmica baseada na profundidade ***
        local shadowOffsetBaseX = Config.Cards.SHADOW_OFFSET_BASE_X
        local shadowOffsetBaseY = Config.Cards.SHADOW_OFFSET_BASE_Y
        local shadowStretchX = Config.Cards.SHADOW_STRETCH_X
        local shadowStretchY = Config.Cards.SHADOW_STRETCH_Y
        
        -- Sombra se move conforme a profundidade da carta
        self.shadowOffsetX = shadowOffsetBaseX + (normalizedX * shadowStretchX * depthMultiplier)
        self.shadowOffsetY = shadowOffsetBaseY + (normalizedY * shadowStretchY * depthMultiplier)
        
        -- Escala da sombra varia com a profundidade
        local shadowScaleBase = Config.Cards.SHADOW_SCALE_BASE
        local shadowScaleVariation = Config.Cards.SHADOW_SCALE_VARIATION
        self.shadowScale = shadowScaleBase - (centerDistance * shadowScaleVariation)
        
        -- *** Efeito de perspectiva adicional ***
        -- A carta parece "girar" ligeiramente em 3D
        self.perspectiveRotation = normalizedX * 0.05 * depthMultiplier

    else
        self.isHovered = false
        self.targetScale = self.baseScale -- Volta ao tamanho normal

        -- Reseta os deslocamentos quando não estiver em hover
        self.offsetHoverX = 0
        self.offsetHoverY = 0
        self.tiltX = 0
        self.tiltY = 0
        self.liftOffset = 0
        self.perspectiveRotation = 0
        self.shadowOffsetX = 0
        self.shadowOffsetY = 0
        self.shadowScale = 0.9

        -- Ambient tilt (Balatro-style): cartas ociosas respiram. Onda senoidal
        -- defasada por seed (evita sincronia). Amplitude ~0.02 rad (~1°).
        -- Só roda quando NÃO hovered — hover assume tilt.
        -- Reduced motion (G.SETTINGS.reduced_motion no Balatro): zera o tilt
        -- pra acessibilidade.
        if _G.gameSettings and _G.gameSettings.reducedMotion then
            self.tiltX = 0
            self.tiltY = 0
        else
            self._ambientTime = (self._ambientTime or 0) + dt
            local ambient = math.sin(self._ambientTime * Config.Cards.AMBIENT_TILT_SPEED + self._ambientSeed)
            self.tiltX = ambient * Config.Cards.AMBIENT_TILT_AMOUNT
            -- Y em segunda harmônica pra movimento não-circular (mais orgânico)
            self.tiltY = math.cos(self._ambientTime * Config.Cards.AMBIENT_TILT_SPEED * 0.7 + self._ambientSeed) * Config.Cards.AMBIENT_TILT_AMOUNT * 0.6
        end
    end

    -- Decay do juice kick (scale/rot bounce disparado por juice_up).
    Moveable.updateJuice(self, dt)

    -- *** Smoother hover (Balatro-style) ***
    -- 1) Ease-out exponencial no scale (vs lerp linear antigo). Feel parecido
    --    mas com desaceleração natural no fim.
    local ease = 1 - math.exp(-Config.Cards.SCALE_EASE_K * dt)
    self.currentScale = self.currentScale + (self.targetScale - self.currentScale) * ease

    -- 2) Micro-bob quando hovered: ±HOVER_BOB_AMOUNT px vertical, freq SPEED rad/s.
    --    Somado ao totalOffsetY do draw via self.hoverBob.
    if self.isHovered then
        self._bobTime = (self._bobTime or 0) + dt
        self.hoverBob = math.sin(self._bobTime * Config.Cards.HOVER_BOB_SPEED) * Config.Cards.HOVER_BOB_AMOUNT
    else
        self._bobTime = 0
        self.hoverBob = (self.hoverBob or 0) * math.exp(-6 * dt) -- decai suave quando sai
    end

    -- 3) Velocity tilt: carta movendo rápido (drag/reorder) ganha tilt na direção
    --    do movimento. Damped com exp decay pra settle natural.
    local vx = (self.x - (self._lastX or self.x)) / math.max(dt, 0.001)
    self._lastX = self.x
    local targetTilt = math.max(-Config.Cards.VEL_TILT_MAX, math.min(Config.Cards.VEL_TILT_MAX, vx * Config.Cards.VEL_TILT_GAIN))
    local tiltEase = 1 - math.exp(-Config.Cards.VEL_TILT_DAMP * dt)
    self._velTilt = (self._velTilt or 0) + (targetTilt - (self._velTilt or 0)) * tiltEase

    -- 4) Hover strength (0..1) — intensidade do perspective warp. Suaviza entrada/saída
    --    via ease-out exp pra evitar pop in do warp.
    local targetHover = self.isHovered and 1 or 0
    local hoverEaseK = Config.Cards.HOVER_STRENGTH_EASE_K or 14
    local hoverEase = 1 - math.exp(-hoverEaseK * dt)
    self.hoverStrength = (self.hoverStrength or 0) + (targetHover - (self.hoverStrength or 0)) * hoverEase

    -- Atualiza animação da borda
    self.borderAnimationTime = self.borderAnimationTime + dt * Config.Cards.BORDER_ANIMATION_SPEED
end

-- Define a posição alvo (reorder animado). Primeira chamada snapa sem anim.
function Card:setTargetPos(tx, ty)
    self.targetX = tx
    self.targetY = ty
    if not self._posInitialized then
        self.renderX = tx
        self.renderY = ty
        self._posInitialized = true
    end
end

-- Interpola renderX/Y em direção a targetX/Y com ease-out exp. Chamado por frame.
-- Drag force-snapa pro mouse (callers usam setRenderPos pra bypass durante drag).
function Card:updateRender(dt)
    local k = 16 -- decel rápida, sensação tátil Balatro
    local ease = 1 - math.exp(-k * dt)
    self.renderX = self.renderX + (self.targetX - self.renderX) * ease
    self.renderY = self.renderY + (self.targetY - self.renderY) * ease
end

-- Força posição renderizada (usada durante drag — card gruda no mouse).
function Card:setRenderPos(rx, ry)
    self.renderX = rx
    self.renderY = ry
    self.targetX = rx
    self.targetY = ry
end

-- Canvas offscreen reusável pra cards com holo/glow (warp + holo composition).
-- Criado lazy com dimensões do canvas da carta; reusa entre frames.
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

-- Métodos para compatibilidade com o sistema de jokers
function Card:getWidth()
    return self.width or (self.image and self.image:getWidth() * (self.currentScale or self.baseScale) or 0)
end

function Card:getHeight()
    return self.height or (self.image and self.image:getHeight() * (self.currentScale or self.baseScale) or 0)
end

function Card:draw(x, y, showPlayableBorder, isRewardCard)
    -- Borda azul "playable" desativada (feedback visual substituído por hover/brightness).
    showPlayableBorder = false
    -- Atualiza posição
    self.x = x
    self.y = y

    -- Calcula deslocamentos para hover com efeito 3D
    -- noHoverLift (shop/relic): zera o baseOffsetY pra carta não saltar pra
    -- cima/baixo no hover. Mantém scale + tilt + offsetHoverX (parallax suave).
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
    -- BASE_LIFT: mesmo idle, carta flutua constante acima da mesa (Balatro).
    -- Usado pra render da carta: -BASE_LIFT (sobe). Sombra usa valor positivo.
    local baseFloat = Config.Cards.BASE_LIFT or 0
    -- Ondulação harmônica idle (Fase 6.3 do refactor Balatro): cartas ociosas
    -- oscilam Y em ~3px com frequência baixa, defasadas pelo seed pra não
    -- sincronizar. Some quando hovered (lift assume).
    local ambientY = 0
    if not self.isHovered and not self.isDragging then
        ambientY = math.sin(love.timer.getTime() * 0.666 + (self._ambientSeed or 0)) * 3
    end
    local totalOffsetY = baseOffsetY + hoverOffsetY + bobOffset + ambientY - baseFloat

    local offsetX = self.offsetHoverX or 0
    local offsetY = self.offsetHoverY or 0

    local tiltX = self.tiltX or 0
    local tiltY = (self.tiltY or 0) + (self._velTilt or 0)
    local perspectiveRotation = self.perspectiveRotation or 0

    -- Scale uniforme (sem o hack legado de scale não-uniforme por tilt).
    -- Perspectiva "press" agora vem do shear abaixo.
    -- Juice: bump multiplicativo de scale quando `juice_up` foi chamado.
    local s = self.currentScale * Moveable.scaleFactor(self)
    local scaleX = s
    local scaleY = s

    -- Flip effect: colapsa scaleX pro meio (0.5 → invisível) e volta.
    -- Usado em Card:flip() pra simular virada 3D sem shader.
    if self._flip and self._flip > 0 then
        local flipT = self._flip -- 0..0.5..0
        scaleX = s * (1 - flipT * 2)
        if scaleX < 0 then scaleX = -scaleX end -- evita inverter draw
    end

    -- Sombra direcional (luz acima do centro da tela) — calcula offset screen-space
    -- mas aplica DENTRO do push/pop pra herdar o warp do shader (acompanha deformação).
    -- Componentes:
    --   dirX  — posição horizontal da carta na tela (bordas → sombra oposta)
    --   press — lado da carta que o usuário pressionou (direita afunda → sombra esquerda)
    local imgW = self.image:getWidth() * s
    local cardCxAbs = x + offsetX + imgW / 2
    local screenW = love.graphics.getWidth()
    local dirX = (cardCxAbs - screenW / 2) / (screenW / 2)
    if dirX > 1 then dirX = 1 elseif dirX < -1 then dirX = -1 end
    -- Normaliza tilt pelo range max pra ficar em [-1, 1] (igual ao mouseUV do shader)
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
    -- CRÍTICO: sombra DEVE fade junto com dissolve. Sem isso, durante materialize
    -- (dissolve 1→0) a sombra chega antes da carta; durante start_dissolve (0→1)
    -- a sombra fica pairando depois da carta queimar. Visualmente, sombra e carta
    -- têm que ser uma coisa só.
    if self.dissolve and self.dissolve > 0.001 then
        shadowAlpha = shadowAlpha * (1 - self.dissolve)
    end

    -- *** Carta Principal ***
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.push()

    local cardCenterX = x + offsetX + (self.image:getWidth() * scaleX) / 2
    local cardCenterY = y + totalOffsetY + (self.image:getHeight() * scaleY) / 2

    love.graphics.translate(cardCenterX, cardCenterY)

    -- Rotação Z sutil (tombamento lateral quando move rápido) + juice rot
    love.graphics.rotate(perspectiveRotation + Moveable.rotOffset(self))

    -- Escala uniforme (sem hack legado de scale não-uniforme por tilt)
    love.graphics.scale(scaleX, scaleY)

    -- Offset pra desenhar centralizado no origin transladado
    local drawX = -self.image:getWidth() / 2
    local drawY = -self.image:getHeight() / 2

    -- Perspective warp via mesh+shader (Balatro-style). Uniforms:
    --   mouse:  [tiltX, tiltY] já normalizados em [-1, 1] via TILT_RANGE
    --   hover:  intensidade suave 0..1
    --   time:   pro wobble idle
    local mouseUV = {
        (tiltX or 0) / (Config.Cards.TILT_RANGE or 0.15),
        (tiltY or 0) / (Config.Cards.TILT_RANGE or 0.15),
    }
    -- clamp
    if mouseUV[1] > 1 then mouseUV[1] = 1 elseif mouseUV[1] < -1 then mouseUV[1] = -1 end
    if mouseUV[2] > 1 then mouseUV[2] = 1 elseif mouseUV[2] < -1 then mouseUV[2] = -1 end

    local hoverAmt = self.hoverStrength or 0
    local timeNow = love.timer.getTime()
    local shader = CardMesh.getShader()
    local fx = self.visualEffect

    -- ===== SOMBRA warpada (antes do card principal) =====
    -- Mesmo mesh+shader do card, mas com tint preto + offset lateral de luz.
    -- Como estamos dentro do push (scale aplicado), o offset é em coords da
    -- carta (pré-scale), então dividimos pelo scale pra compensar.
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

    -- Dissolve/materialize path: bypass mesh warp + holo (eles não compõem
    -- com dissolve shader sem double-shader pipeline). Usa DissolveShader
    -- diretamente na textura. Feio? Não — a dissolução esconde a perda de
    -- warp porque a carta está sumindo/aparecendo de qualquer jeito.
    if self.dissolve and self.dissolve > 0.001 then
        if DissolveShader.isAvailable() then
            DissolveShader.apply(self.image, self.dissolve, self.dissolve_colours)
            love.graphics.draw(self.image, drawX, drawY)
            DissolveShader.clear()
        else
            -- Fallback sem shader: só apaga com alpha
            local alpha = 1 - self.dissolve
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(self.image, drawX, drawY)
            love.graphics.setColor(1, 1, 1, 1)
        end
    elseif self.edition then
        -- Edition path (Fase 3.2): renderiza mesh warpado num canvas, depois
        -- aplica o shader da edition (foil/holo/polychrome/negative). Tem prioridade
        -- sobre o rarity glow legacy (fx=="holo"/"glow").
        local editionShader, editionStrength = self:_getEditionShader()
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
        if editionShader and editionShader.draw then
            editionShader.draw(offCanvas, drawX, drawY, editionStrength, 0, 1, 1)
        else
            love.graphics.draw(offCanvas, drawX, drawY)
        end
    elseif shader and fx ~= "holo" and fx ~= "glow" then
        -- Fast path: mesh warp sozinho (sem composição com holo)
        local mesh = CardMesh.getMesh(self.image:getWidth(), self.image:getHeight())
        mesh:setTexture(self.image)
        love.graphics.setShader(shader)
        CardMesh.setUniforms(shader, mouseUV, hoverAmt, timeNow, self.image)
        -- saleDim (F2 UI Overhaul): item impagável escurece pro tom do fundo
        if self.saleDim then love.graphics.setColor(0.55, 0.52, 0.48, 1) end
        love.graphics.draw(mesh, drawX, drawY)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setShader()
    elseif (fx == "holo" or fx == "glow") then
        -- Composição warp + holo via canvas intermediário.
        --
        -- IMPORTANTE: LÖVE NÃO salva transformações em setCanvas. Se a gente só
        -- mudar canvas, o translate+scale do card center continua ativo, e o
        -- mesh seria desenhado FORA do offCanvas (que tem só w×h pixels),
        -- resultando em canvas vazio → HoloShader.draw em nada → carta invisível.
        -- Fix: push("all") + origin() pra zerar transform dentro do offCanvas.
        local strength = (fx == "holo") and 0.75 or 0.35
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
        -- Agora aplica HoloShader sobre o canvas já warpado (transform externa
        -- já restaurada — drawX/drawY são coords locais pré-scale).
        HoloShader.draw(offCanvas, drawX, drawY, strength, 0, 1, 1)
    else
        -- Fallback sem shader (shader não carregou): draw direto
        if self.saleDim then love.graphics.setColor(0.55, 0.52, 0.48, 1) end
        love.graphics.draw(self.image, drawX, drawY)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Animation layer (halo, embers, drip, flash, ring...) — pós-canvas.
    -- Scale já foi aplicado no stack via love.graphics.scale, então passa (1,1).
    if CardAnimationLayer.isEnabled() then
        if not self._cachedArt then
            local okA, a = pcall(CardArt.resolve, self)
            self._cachedArt = okA and a or { bgPattern = nil }
        end
        CardAnimationLayer.draw(self, self._cachedArt, drawX, drawY, 1, 1)
    end

    -- Upgrade badge "+N" (Fase 3.1). Desenhado dentro do transform da carta —
    -- escala junto. Fade com dissolve pra acompanhar entrada/saída.
    if self.upgrades and self.upgrades > 0 then
        self:_drawUpgradeBadge(drawX, drawY)
    end

    -- Seal indicator (Fase 3.3). Disco colorido no canto superior-esquerdo.
    if self.seal then
        self:_drawSealIndicator(drawX, drawY)
    end

    -- Restaura transformações
    love.graphics.pop()

    -- Texto só aparece no hover e agora está na parte de cima
    -- Mas não desenha se for uma carta de reward (a descrição será desenhada pela CardRewardScreen)
    if self.isHovered and not isRewardCard then
        -- Define altura proporcional à escala atual
        local textOffsetY = y + totalOffsetY - 70

        -- Usa o componente CardInfoDisplay para desenhar as informações
        self.cardInfoDisplay:draw(self, x, textOffsetY + 20, {
            showRarity = false, -- Cartas na mão não mostram raridade
            showStats = true,
            showDescription = true  -- Agora mostra a descrição no hover
        })
    end
end

-- ===== Editions (Fase 3.2) =====

-- Mapping edition → (shader, strength_default).
local EDITION_SHADERS = {
    foil       = { shader = FoilShader,       strength = 0.6 },
    holo       = { shader = HoloShader,       strength = 0.75 },
    polychrome = { shader = PolychromeShader, strength = 0.7 },
    negative   = { shader = NegativeShader,   strength = 1.0 },
}

-- Retorna (shader, strength) pra edition atual. Nil se sem edition ou shader
-- não disponível (load failed).
function Card:_getEditionShader()
    if not self.edition then return nil, 0 end
    local entry = EDITION_SHADERS[self.edition]
    if not entry or not entry.shader then return nil, 0 end
    if entry.shader.isAvailable and not entry.shader.isAvailable() then
        return nil, 0
    end
    return entry.shader, entry.strength
end

-- Aplica edition na carta. Dispara feedback visual (juice + sfx).
-- editionName: "foil" | "holo" | "polychrome" | "negative" | nil (remove)
-- options: { silent = bool } pra suprimir feedback (ex: durante setup de save load)
function Card:setEdition(editionName, options)
    options = options or {}
    self.edition = editionName

    if options.silent then return end

    -- Juice + sfx por tipo (mesma ideia do Balatro card.lua:set_edition).
    if editionName then
        Moveable.juice_up(self, 0.5)
        local sfxByEdition = {
            foil = "deckStart", holo = "deckStart",
            polychrome = "deckStart", negative = "swordSound",
        }
        local sfxName = sfxByEdition[editionName]
        if sfxName then Sfx.play(sfxName) end
    end
end

-- Aplica seal na carta. Triggers visuais idem.
function Card:setSeal(sealName, options)
    options = options or {}
    self.seal = sealName
    if options.silent then return end
    if sealName then
        Moveable.juice_up(self, 0.3)
        Sfx.play("cardSelect")
    end
end

-- ===== Badges (visual) =====

-- Badge "+N" no canto inferior-direito da carta. Chamado dentro do transform
-- (origin no centro da carta, scale aplicado). Coords drawX/drawY = canto sup-esq.
function Card:_drawUpgradeBadge(drawX, drawY)
    local imgW = self.image:getWidth()
    local imgH = self.image:getHeight()
    local badgeW, badgeH = 22, 14
    local bx = drawX + imgW - badgeW - 3
    local by = drawY + imgH - badgeH - 3

    local alpha = 1
    if self.dissolve and self.dissolve > 0.001 then
        alpha = math.max(0, 1 - self.dissolve)
    end

    -- Fundo: ouro envelhecido (combina com paleta sépia do CardFrame).
    local fill = { Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2], Palette.AGED_GOLD_DARK[3], alpha }
    local outline = { Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], alpha }
    PixelCanvas.rect(bx, by, badgeW, badgeH, fill)
    PixelCanvas.rectOutline(bx, by, badgeW, badgeH, outline)

    love.graphics.setColor(1.0, 0.95, 0.7, alpha)
    love.graphics.setFont(FontManager.getFont(8))
    love.graphics.printf("+" .. tostring(self.upgrades), bx, by + 3, badgeW, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

-- Seal: disco colorido pequeno no canto superior-esquerdo.
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
    -- Pulse leve com tempo (idle "vivo").
    local t = love.timer.getTime() * 2
    local pulse = 1 + 0.08 * math.sin(t + (self._ambientSeed or 0))
    local r = radius * pulse

    -- Halo externo
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.35)
    love.graphics.circle("fill", cx, cy, r + 2)
    -- Disco principal
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.circle("fill", cx, cy, r)
    -- Outline
    love.graphics.setColor(0, 0, 0, alpha * 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.setColor(1, 1, 1, 1)
end

return Card
