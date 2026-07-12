-- src/systems/CombatSequence.lua
-- Coreografa o combate via EventManager. Substitui CombatAnimationSystem.lua
-- (530 LOC → ~180 LOC).
--
-- PRINCÍPIO-CHAVE: cartas voam pelo PRÓPRIO renderer (Card:draw via setTargetPos).
-- Herdam sombras dinâmicas, warp do mesh, juice, ambient tilt, dissolve.
-- Nada de `love.graphics.draw(card.image)` flat que o sistema antigo fazia.
--
-- PIPELINE (por carta, escalonado com cardStagger):
--   t=0         → preFlight delay
--   t=0.05      → setTargetPos(centro + idx*spacing); renderer da carta toma conta
--   t=0.55      → impacto: sfx + partículas + onCardProcessed(card) + damage number
--   t=0.70      → start_dissolve (carta queima via DissolveShader)
--   t=~1.2      → cleanup de flyingCards, onComplete
--
-- API pública compatível com CombatAnimationSystem:
--   :startCombat(cards, onComplete, onCardProcessed)
--   :update(dt)  :draw()  :isBlocking()  :isAnimating()

local Sfx = require("src.systems.Sfx")
local FontManager = require("src.ui.FontManager")
local DissolveShader = require("src.ui.DissolveShader")
local Config = require("src.core.Config")

local CombatSequence = {}
CombatSequence.__index = CombatSequence

function CombatSequence:new()
    local self = setmetatable({}, CombatSequence)
    self.active = false
    -- Cartas atualmente voando. Desenhadas por draw() usando Card:draw (full fidelity).
    self.flyingCards = {}
    -- Damage numbers flutuantes (apenas sobem+fade; não é MessageSystem porque é spatial).
    self.damageNumbers = {}

    self.timings = {
        preFlight       = 0.05,  -- delay antes de cartas saírem
        flightDuration  = 0.5,   -- tempo até chegarem ao centro (ease já no renderer)
        impactHold      = 0.15,  -- tempo no centro pra ler dano antes de dissolver
        dissolveTime    = 0.7,   -- duração do start_dissolve
        cardStagger     = 0.22,  -- gap entre cartas consecutivas (combo feel)
    }
    return self
end

-- Compatibilidade: startCombat(cards, onComplete, onCardProcessed)
function CombatSequence:startCombat(cards, onComplete, onCardProcessed)
    if self.active or not cards or #cards == 0 then
        if onComplete then onComplete() end
        return
    end
    self.active = true
    self.flyingCards = {}
    for _, c in ipairs(cards) do table.insert(self.flyingCards, c) end

    local EM = _G.EventManager
    local Ev = _G.Event
    if not EM or not Ev then
        -- Fallback sync: processa tudo sem animação
        for _, card in ipairs(cards) do
            if onCardProcessed then onCardProcessed(card) end
        end
        self:_finish(onComplete)
        return
    end

    -- Layout: centraliza cartas no meio da tela com spacing responsivo
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local centerX = screenW * 0.5
    local centerY = screenH * 0.45  -- levemente acima do centro (space pro HUD)
    local spacing = screenW * 0.12  -- ~120 px em 1024 wide

    local n = #cards
    local offsetStart = -((n - 1) / 2) * spacing

    -- Helper: agenda callback em delay absoluto (não-blocking, paralelo).
    -- EM.after do engine cria eventos BLOCKING por default, que serializam a
    -- fila (cada evento só começa o timer quando o anterior completa). Pra
    -- keyframes de animação precisamos de tempo ABSOLUTO — por isso manual.
    local function scheduleAt(delay, fn)
        EM.add(Ev:new({
            trigger = "after",
            delay = delay,
            blocking = false,
            func = function() fn(); return true end,
        }))
    end

    for idx, card in ipairs(cards) do
        -- Alvo computado levando em conta scale atual (renderer vai usar top-left)
        local cardW = (card.image and card.image:getWidth() or 100) * (card.currentScale or 1)
        local cardH = (card.image and card.image:getHeight() or 140) * (card.currentScale or 1)
        local targetX = centerX + offsetStart + (idx - 1) * spacing - cardW / 2
        local targetY = centerY - cardH / 2

        local leaveAt = (idx - 1) * self.timings.cardStagger

        -- ========== Fase 1: flight ==========
        local launchPitchIdx = idx  -- captura pra closure (combo cascade pitch)
        scheduleAt(leaveAt + self.timings.preFlight, function()
            -- SFX dedicado de "jogar carta" no lançamento (whoosh), antes do
            -- impacto (sword/armor). Pitch crescente por carta no combo.
            local pitch = math.min(1.4, 0.95 + (launchPitchIdx - 1) * 0.06)
            self:_playLaunchSfx(card, pitch)
            if card.setTargetPos then
                card:setTargetPos(targetX, targetY)
            else
                card.x, card.y = targetX, targetY
            end
        end)

        -- ========== Fase 2: impacto ==========
        local impactAt = leaveAt + self.timings.preFlight + self.timings.flightDuration
        local pitchIdx = idx  -- captura pra closure (combo cascade pitch)
        scheduleAt(impactAt, function()
            -- Pitch crescente por carta no combo (Fase 6.2). 1ª carta = 0.95,
            -- cada próxima +0.06 → última carta de combo grande mais aguda. Cap em 1.4.
            local pitch = math.min(1.4, 0.95 + (pitchIdx - 1) * 0.06)
            self:_playImpactSfx(card, pitch)
            self:_spawnImpactParticles(card, targetX + cardW / 2, targetY + cardH / 2)
            local result = onCardProcessed and onCardProcessed(card) or {}
            self:_handleResult(card, result, targetX + cardW / 2, targetY + cardH / 2)
            if card.juice_up then card:juice_up(0.5, 0.15) end
        end)

        -- ========== Fase 3: dissolve ==========
        local dissolveAt = impactAt + self.timings.impactHold
        scheduleAt(dissolveAt, function()
            if card.start_dissolve then
                local palette = DissolveShader.palette(card.type or "default")
                card:start_dissolve(palette, true, self.timings.dissolveTime, true, function()
                    for i, c in ipairs(self.flyingCards) do
                        if c == card then
                            table.remove(self.flyingCards, i)
                            break
                        end
                    end
                end)
            else
                for i, c in ipairs(self.flyingCards) do
                    if c == card then
                        table.remove(self.flyingCards, i)
                        break
                    end
                end
            end
        end)
    end

    -- ========== Fase 4: fim ==========
    local lastImpactAt = (n - 1) * self.timings.cardStagger + self.timings.preFlight + self.timings.flightDuration
    local totalDuration = lastImpactAt + self.timings.impactHold + self.timings.dissolveTime * 0.85
    scheduleAt(totalDuration, function()
        self:_finish(onComplete)
    end)
end

function CombatSequence:_finish(onComplete)
    self.active = false
    self.damageNumbers = {}
    -- flyingCards pode ainda ter resíduo se dissolve não completou — limpa.
    -- Se houver cartas sobrando, marca como removidas pra CardParticles fazer cleanup.
    for _, card in ipairs(self.flyingCards) do
        if card.markRemoved then card:markRemoved() end
    end
    self.flyingCards = {}
    if onComplete then onComplete() end
end

-- ============================================================================
-- IMPACT HANDLERS
-- ============================================================================

-- SFX de lançamento da carta (whoosh de "jogar"), tocado na Fase 1 antes do
-- impacto. Só attack/defense têm som dedicado; joker/effect já soam no impacto.
function CombatSequence:_playLaunchSfx(card, pitch)
    local t = card.type
    local opts = pitch and { pitch = pitch } or nil
    if t == "attack" then
        Sfx.play("cardPlayAttack", opts)
    elseif t == "defense" then
        Sfx.play("cardPlayDefense", opts)
    end
end

function CombatSequence:_playImpactSfx(card, pitch)
    local t = card.type
    local opts = pitch and { pitch = pitch } or nil
    if t == "attack" then
        Sfx.play("swordSound", opts)
    elseif t == "defense" then
        Sfx.play("armorSound", opts)
    elseif t == "joker" then
        Sfx.play("jokerActivate", opts)
    else
        Sfx.play("cardSelect", opts)
    end
end

function CombatSequence:_spawnImpactParticles(card, cx, cy)
    local ok, ParticleSystem = pcall(require, "src.systems.ParticleSystem")
    if not ok or not ParticleSystem then return end

    -- Presets já registram a instância no ParticlesManager (spawn). Caller só
    -- precisa invocar — o retorno é a instância pra opcional :fade/:remove.
    local t = card.type
    if t == "attack" then
        ParticleSystem.Presets.DAMAGE_EFFECT(cx, cy)
    elseif t == "defense" then
        local p = ParticleSystem.Presets.CARD_PLAYED(cx, cy)
        -- Tinge de azul claro pra defesa (override da paleta padrão).
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
    end

    if result.defense and result.defense > 0 then
        self:_addDamageNumber("+" .. result.defense, cx, cy - 60, {0.3, 0.7, 1})
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

-- ============================================================================
-- UPDATE / DRAW
-- ============================================================================

function CombatSequence:update(dt)
    if not self.active and #self.damageNumbers == 0 and #self.flyingCards == 0 then
        return
    end

    -- Tick do render das cartas voando (ease renderX→targetX)
    for _, card in ipairs(self.flyingCards) do
        if card.updateRender then card:updateRender(dt) end
        -- Hover é falso durante voo (clique não deve selecionar carta no ar).
        -- updateMouse ainda roda no main pra ambient tilt, então setamos isHovered = false.
        card.isHovered = false
        if card.updateMouse then
            -- Chama updateMouse com mouse fora (mx=-999) pra ambient tilt tickar
            card:updateMouse(-999, -999, dt, false)
        end
    end

    -- Damage numbers: sobem e somem
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

    -- Desenha cartas voando COM O PRÓPRIO RENDERER: herda sombras, warp,
    -- juice, ambient tilt, dissolve. Isso é o grande ganho vs sistema antigo.
    for _, card in ipairs(self.flyingCards) do
        if card.draw and card.image then
            local x = (card.renderX and card.renderX ~= 0) and card.renderX or card.x
            local y = (card.renderY and card.renderY ~= 0) and card.renderY or card.y
            card:draw(x, y, false, false)
        end
    end

    -- Damage numbers (por cima)
    if #self.damageNumbers > 0 then
        local font = FontManager.getResponsiveFont(0.04, 32, "height")
        love.graphics.setFont(font)
        for _, d in ipairs(self.damageNumbers) do
            love.graphics.setColor(d.color[1], d.color[2], d.color[3], d.alpha)
            local w = font:getWidth(d.text)
            -- Contorno preto leve pra legibilidade
            love.graphics.setColor(0, 0, 0, d.alpha * 0.7)
            love.graphics.print(d.text, d.x - w / 2 + 2, d.y + 2)
            love.graphics.setColor(d.color[1], d.color[2], d.color[3], d.alpha)
            love.graphics.print(d.text, d.x - w / 2, d.y)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- ============================================================================
-- STATUS QUERIES (compat com CombatAnimationSystem)
-- ============================================================================

function CombatSequence:isBlocking()
    return self.active
end

function CombatSequence:isAnimating()
    return self.active
end

return CombatSequence
