-- src/systems/CombatSequence.lua
-- Coreografa o combate via EventManager. Substitui CombatAnimationSystem.lua
-- (530 LOC → ~180 LOC).
--
-- PRINCÍPIO-CHAVE: cartas voam pelo PRÓPRIO renderer (Card:draw via setTargetPos).
-- Herdam sombras dinâmicas, warp do mesh, juice, ambient tilt, dissolve.
-- Nada de `love.graphics.draw(card.image)` flat que o sistema antigo fazia.
--
-- PIPELINE (Set/2026): o VOO é agendado em tempo absoluto na fila "base"
-- (animação pura); a RESOLUÇÃO é uma cadeia de BEATS (src/systems/CombatBeats)
-- em que cada acontecimento ocupa um instante e segura o próximo:
--   cartas pousam → carta 1 impacta → jokers dela ticam → efeitos secundários
--   dela (veneno/cura/orbe/espinhos) → dissolve → carta 2 → ... → fim
--
-- API pública compatível com CombatAnimationSystem:
--   :startCombat(cards, onComplete, onCardProcessed)
--   :update(dt)  :draw()  :isBlocking()  :isAnimating()

local Sfx = require("src.systems.Sfx")
local FontManager = require("src.ui.FontManager")
local DissolveShader = require("src.ui.DissolveShader")
local Config = require("src.core.Config")
local CardFeel = require("src.systems.CardFeel")
local JokerProcFx = require("src.ui.JokerProcFx")

-- O RITMO mora todo em CombatBeats.HOLD (tabela unica, comentada). O antigo
-- PROC_TICK local virou CombatBeats.HOLD.JOKER_PROC; o stagger/procHold que
-- ESTICAVA o agendamento morreu com a fila de beats: agora a proxima carta
-- literalmente espera a anterior terminar, em vez de reservar tempo por
-- estimativa (EffectSystem:predictJokerProcs nao pauta mais nada).
local CombatBeats = require("src.systems.CombatBeats")

local CombatSequence = {}
CombatSequence.__index = CombatSequence

-- DEBUG FEEL (temporário, caça "carta parada no impacto" — mesmo método do
-- RDBG que achou a RAIZ dos espólios): loga em feel_debug.log no save dir o
-- que o DRAW recebe de hop/juice/swell na sessão REAL do jogador.
local Moveable = require("engine.Moveable")
local function flog(fmt, ...)
    pcall(love.filesystem.append, "feel_debug.log",
        ("[FEEL +%.2f] "):format(love.timer and love.timer.getTime() or 0)
        .. fmt:format(...) .. "\n")
end

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
        -- v3.1: 0.15→0.35 — a carta SEGURA no centro tempo suficiente pra
        -- reação física dela ser LIDA (0.15s junto de shake+partículas era
        -- invisível — "tão totalmente estáticas", feedback do dono).
        impactHold      = 0.35,
        dissolveTime    = 0.7,   -- duração do start_dissolve
        cardStagger     = 0.22,  -- gap entre cartas consecutivas (combo feel)
    }
    return self
end

-- Compatibilidade: startCombat(cards, onComplete, onCardProcessed)
--
-- DUAS LINHAS DO TEMPO (Set/2026):
--   1. VOO — animacao pura, agendada na fila "base" em tempo ABSOLUTO. Todas
--      as cartas caem na mesa quase juntas ("mao na mesa", modelo Balatro).
--   2. RESOLUCAO — a espinha CAUSAL, na fila de beats (CombatBeats). Um
--      acontecimento por instante, cada um segurando o proximo:
--        carta 1 impacta > jokers dela ticam um a um > efeitos secundarios
--        dela (veneno, cura, orbe, espinhos) um a um > dissolve > carta 2...
--      A cadeia e empurrada DE DENTRO do beat anterior (regra do CombatBeats):
--      so assim os passos dinamicos de uma carta entram antes da proxima.
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
        -- Fallback sync: processa tudo sem animacao
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

    -- Helper: agenda ANIMACAO em delay absoluto (nao-blocking, paralelo) na
    -- fila base. EM.after cria eventos BLOCKING que serializam a fila; pra
    -- keyframes visuais precisamos de tempo ABSOLUTO. blockable=false porque
    -- Card:start_dissolve enfileira um ease BLOQUEANTE na base.
    local function scheduleAt(delay, fn)
        EM.add(Ev:new({
            trigger = "after",
            delay = delay,
            blocking = false,
            blockable = false,
            func = function() fn(); return true end,
        }))
    end

    -- ===== Linha 1: VOO (estetico, todas quase juntas) =====
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
            -- SFX dedicado de "jogar carta" no lancamento (whoosh), antes do
            -- impacto (sword/armor). Pitch crescente por carta no combo.
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

    -- ===== Linha 2: RESOLUCAO (cadeia causal) =====
    local function removeFlying(card)
        for i, c in ipairs(self.flyingCards) do
            if c == card then table.remove(self.flyingCards, i) break end
        end
    end

    local resolveCard
    resolveCard = function(idx)
        local card = cards[idx]
        if not card then
            -- Ultima carta dissolvendo: o combate so "termina" quando ela some,
            -- senao _finish arranca as cartas da tela no meio do dissolve.
            CombatBeats.push("combat.settle", nil, self.timings.dissolveTime * 0.6)
            CombatBeats.push("combat.end", function()
                self:_finish(onComplete)
            end, "MICRO")
            return
        end
        local g = geom[idx]
        local cx, cy = g.x + g.w / 2, g.y + g.h / 2
        local pitch = math.min(1.4, 0.95 + (idx - 1) * 0.06)

        CombatBeats.push("card.impact." .. tostring(card.type), function()
            self:_playImpactSfx(card, pitch)
            self:_spawnImpactParticles(card, cx, cy)

            -- `sink` coleta os efeitos SECUNDARIOS da carta (Game os empurra
            -- ali em vez de executar tudo no mesmo instante do dano).
            local sink = {}
            local result = onCardProcessed and onCardProcessed(card, sink) or {}
            self:_handleResult(card, result, cx, cy)

            -- Game feel v2/v3.1: reacao FISICA por tipo no impacto — AMPLA e
            -- LONGA o bastante pra sobreviver ao ruido do momento (shake de
            -- tela + particulas + numero acontecem juntos e mascaravam a
            -- reacao curta). Cada tipo ganha um SEGUNDO pulso de assentamento.
            if card.type == "attack" then
                -- v3.2: pulo CHUNKY (estala-segura-cai-quica) + pop de escala
                -- (swell curto le melhor que vibracao de 50rad/s) + tilt.
                if card.hop_up then card:hop_up(44, 0.50) end
                if card.swell_up then card:swell_up(0.20, 0.35) end
                if card.juice_up then card:juice_up(0.4, -0.24) end
            elseif card.type == "defense" then
                -- v3.3: a defesa APARA o golpe — checa pro lado torta (shove
                -- horizontal + tilt), segura, e volta com um TIQUE de mola.
                if card.shove_x then card:shove_x(nil, 0.55) end
                if card.juice_up then card:juice_up(0.10, 0.22) end
                if card.swell_up then card:swell_up(0.14, 0.40) end
            elseif card.type == "effect" then
                if card.hop_up then card:hop_up(20, 0.45) end
                if card.juice_up then card:juice_up(0.45, 0.28) end
                scheduleAt(0.18, function()
                    if card.juice_up then card:juice_up(0.32, -0.2) end
                end)
                -- 3a camada sonora do efeito (cast no voo -> chime no impacto
                -- -> resolve fechando). Ver _playLaunchSfx/_playImpactSfx.
                scheduleAt(0.16, function()
                    Sfx.play("effectResolve", { pitch = pitch })
                end)
            else
                if card.juice_up then card:juice_up(0.5, 0.15) end
            end

            -- Procs de joker (Balatro): cada joker que contribuiu tica em
            -- SEQUENCIA — juice no slot + popup do valor + som com pitch
            -- crescente. UM BEAT CADA: o jogador conta os jokers.
            for k, proc in ipairs(result and result.jokerProcs or {}) do
                local kk, pp = k, proc
                CombatBeats.push("joker.proc", function()
                    JokerProcFx.tick(pp, kk)
                end, "JOKER_PROC")
            end

            -- Efeitos secundarios coletados no sink (veneno, cura, orbe,
            -- espinhos armados, gatilhos de joker): um acontecimento por vez.
            CombatBeats.pushAll(sink)

            -- A carta so queima DEPOIS de tudo que ela causou ter acontecido
            -- (causalidade Balatro: o jogador ve o joker reagir com a carta
            -- ainda na tela).
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

    -- A resolucao so comeca quando TODAS as cartas pousaram.
    CombatBeats.push("combat.cards_landed", function()
        resolveCard(1)
    end, allLandedAt + 0.10)
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
    elseif t == "effect" then
        -- 1ª camada do efeito: whoosh de conjuração no lançamento (v2).
        Sfx.play("effectCast", opts)
    end
end

function CombatSequence:_playImpactSfx(card, pitch)
    -- Game feel v1: tema da carta (fire/ice/poison/...) tem SOM PRÓPRIO —
    -- a Bola de Fogo soa fogo, não espada. Sem tema → identidade física.
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
        -- 2ª camada do efeito: chime de ativação (a 3ª, effectResolve, é
        -- agendada no impacto). Cartas de efeito TEMÁTICAS já retornaram
        -- no CardFeel.playImpact acima — aqui é o fallback sem tema.
        Sfx.play("effectChime", opts)
    else
        Sfx.play("cardSelect", opts)
    end
end

function CombatSequence:_spawnImpactParticles(card, cx, cy)
    -- Game feel v1: burst com a paleta/física do TEMA (fogo sobe laranja,
    -- gelo cai azul, veneno borbulha verde). Sem tema → presets por tipo.
    local theme = CardFeel.themeOf(card)
    if theme then
        CardFeel.burst(theme, cx, cy, 1.0)
        return
    end

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
        -- O golpe estoura NO INIMIGO (StS): burst temático no sprite dele —
        -- o jogador vê o fogo/raio/veneno CHEGANDO, não só saindo da carta.
        CardFeel.burstAtEnemy(CardFeel.themeOf(card) or "physical",
            math.min(1.6, 0.8 + result.damage * 0.03))
    end

    if result.defense and result.defense > 0 then
        self:_addDamageNumber("+" .. result.defense, cx, cy - 60, {0.3, 0.7, 1})
        -- Escudo sobe no PAINEL do jogador (onde a barra de armor vive).
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

    -- DEBUG FEEL: amostra a cada ~0.08s o que o draw REAL recebe.
    local now = love.timer and love.timer.getTime() or 0
    local sample = false
    if now - (self._dbgLast or 0) > 0.08 then
        self._dbgLast = now
        sample = true
    end

    -- Desenha cartas voando COM O PRÓPRIO RENDERER: herda sombras, warp,
    -- juice, ambient tilt, dissolve. Isso é o grande ganho vs sistema antigo.
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

    -- (o overlay FDBG magenta saiu — cumpriu o papel na caça ao bug de
    -- feel; o diagnóstico continua no feel_debug.log, invisível em jogo)

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

-- Contrato critico: enquanto isto for true, main/GameplayScene NAO dispara
-- turno do inimigo, game over, victory nem nextPhase. Agora inclui a FILA DE
-- BEATS — o jogo nao avanca enquanto houver acontecimento de combate pendente
-- (o dano do veneno, o orbe pulsando, o coringa ticando). Sem isso a tela de
-- espolios abriria por cima da resolucao.
function CombatSequence:isBlocking()
    return self.active or CombatBeats.isBusy()
end

function CombatSequence:isAnimating()
    return self.active
end

return CombatSequence
