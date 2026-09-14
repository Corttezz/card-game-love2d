-- src/systems/EffectSystem.lua
-- Sistema modular de efeitos de cartas.
-- Dois domínios:
--   1. Efeitos *contínuos* de jokers — modificam o dano/defesa/heal de cartas jogadas.
--   2. Efeitos de *trigger* — disparam em eventos ("attack", "defend", "turn_start").
-- Todos os efeitos são data-driven: leem `card.effects` (já injetado por CardDatabase:createCardInstance).

local EffectSystem = {}
EffectSystem.__index = EffectSystem

local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")
local CardFeel = require("src.systems.CardFeel")
local CombatBeats = require("src.systems.CombatBeats")
-- Helper local: mensagem traduzida via messages.<key>, com vars injetadas.
local function msg(key, vars) return I18n.t("messages." .. key, vars) end

-- Ponte pra UI (OrbRow) — pcall pra rodar headless sem UI (mesmo idioma dos
-- pcall(require EnemyRenderer/FloatingText) no Game.lua). fn inexistente =
-- no-op. DECLARADA AQUI NO TOPO: locals de Lua so existem abaixo da definicao
-- (regressao pega pelo test_all: channel_orb usava antes da declaracao).
local function notifyOrbUI(fn, ...)
    local ok, OrbRow = pcall(require, "src.ui.OrbRow")
    if ok and OrbRow and OrbRow[fn] then
        pcall(OrbRow[fn], ...)
    end
end

function EffectSystem:new()
    return setmetatable({}, EffectSystem)
end

-- Coletor de PASSOS do combate (ver src/systems/CombatBeats.lua). O Game seta
-- `game._beatSink` enquanto resolve uma carta; com ele presente, cada efeito
-- vira um acontecimento com instante proprio em vez de todos no mesmo frame.
-- Ausente (API chamada direto por teste/autoplay) = sincrono, como sempre foi.
local function sinkOf(game)
    return game and game._beatSink or nil
end

-- Todo dano ao inimigo pode cruzar os 30% de vida e ENFURECE-LO (+50% de dano
-- permanente). Era mudo; agora o Game da um instante proprio ao cruzamento.
-- Chamado depois de CADA takeDamage daqui. `game` leve (mockGame dos testes)
-- nao tem o metodo — vira no-op, como o resto das pontes de UI deste arquivo.
local function checkEnrage(game)
    if game and game.announceEnrageIfPending then
        game:announceEnrageIfPending(sinkOf(game))
    end
end

-- DANO TEM CARA DE DANO. Magia e evoke acertam o inimigo pelo EffectSystem, que
-- (ao contrario da carta de ataque, servida pelo CombatSequence) nao tinha
-- numero nem reacao — so um burst. Sem isso o jogador do mago via a mesma
-- explosao generica pra "levou dano" e pra "ganhou um orbe". `v` negativo nunca
-- chega aqui; headless/UI ausente = no-op.
local function showEnemyDamage(v)
    if not v or v <= 0 then return end
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if not okER then return end
    if ER.triggerHurt then pcall(ER.triggerHurt) end
    if not ER.getLastPos then return end
    local ex, ey = ER.getLastPos()
    if not ex then return end
    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if okFT and FloatingText.spawn then
        FloatingText.spawn("-" .. tostring(v), ex, ey - 40, { kind = "damage" })
    end
end

-- ==============================================================================
-- Efeitos contínuos de jokers (chamados ao jogar uma carta de ataque/defesa).
-- ==============================================================================

-- Game feel v1 (Jul/2026): helper de PROC — registra que um joker contribuiu
-- (rótulo tipo "×2"/"+3"/"+4 PV") num sink, com o índice do slot pra UI ticar
-- o joker certo (JokerProcFx). Sink ausente = no-op (headless/chamadas antigas).
local function pushJokerProc(game, sink, joker, label, kind)
    if not joker then return end
    local slotIndex
    for i, j in ipairs(game.jokerSlots or {}) do
        if j == joker then slotIndex = i break end
    end
    if not slotIndex then return end
    local proc = { slotIndex = slotIndex, joker = joker,
                   label = label, kind = kind or "mult" }
    if sink then
        sink[#sink + 1] = proc
        return
    end
    -- SEM sink = proc FORA do pipeline de carta (ex: turn_start — compra
    -- extra, regen, Forma Demoniaca...). Antes era no-op e o joker ficava
    -- MUDO ("Aprendizado de Máquina não triga visualmente" — feedback
    -- Jul/2026). Dispara DIRETO no JokerProcFx, escalonado: vários procs
    -- no mesmo instante ticam em sequência (0.18s), não em uníssono.
    local now = (love.timer and love.timer.getTime()) or 0
    if not game._directProcT or now - game._directProcT > 0.6 then
        game._directProcT, game._directProcN = now, 0
    end
    game._directProcN = (game._directProcN or 0) + 1
    local ord = game._directProcN
    local function fire()
        local ok, JokerProcFx = pcall(require, "src.ui.JokerProcFx")
        if ok and JokerProcFx.tick then pcall(JokerProcFx.tick, proc, ord) end
    end
    local EM = _G.EventManager
    if EM and EM.after and ord > 1 then
        EM.after((ord - 1) * 0.18, fire)
    else
        fire()
    end
end

-- API pública do proc direto (Game usa pro retain_armor do Bastião, que
-- dispara fora do EffectSystem — em Player:onTurnStart).
function EffectSystem:notifyJokerProc(game, joker, label, kind)
    pushJokerProc(game, nil, joker, label, kind)
end

-- Formata multiplicador sem ".0" (2.0 → "×2", 1.5 → "×1.5").
local function multLabel(v)
    return "×" .. string.format("%g", v or 1)
end

-- turnContext (opcional, Fase 3+): tabela com { allSelectedCards, tagCounts,
-- activeCombos, cardsProcessed, turnNumber }. Se presente, combos amplificam o
-- valor ANTES dos jokers (multiplicador-sobre-multiplicador nao vira produtorio).
--
-- RETORNO (game feel v1): (finalValue, procs) — procs é o array de contribuições
-- de joker pro tick sequencial estilo Balatro. Chamadas antigas que só leem o
-- primeiro retorno continuam funcionando.
function EffectSystem:applyJokerEffects(game, card, baseValue, turnContext)
    local finalValue = baseValue
    local msgs = {}
    local procs = {}

    -- P0.9 (Jul/2026, rebalance v2 — LARGEST-MULTIPLIER-WINS): entre os jokers
    -- ativos, APENAS o MAIOR damage_multiplier e o MAIOR defense_multiplier
    -- contam. Sem isso, echo_form 1.5 x joker_001 1.5 = x2.25 em cadeia
    -- (produto x5.06 com combo+vulnerable — boss A2 em ~1.5 turnos), e duas
    -- copias do mesmo joker multiplicador dobravam de graca. Bonus FLAT
    -- (damage_bonus/defense_bonus) continuam somando TODOS; multiplicadores
    -- de COMBO e vulnerable sao camadas distintas do pipeline e ficam fora
    -- da regra. NAO reintroduzir produto em cadeia aqui.
    local bestMult, bestMultJoker = nil, nil
    for _, joker in ipairs(game.jokerSlots) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                local isMatchingMult =
                    (effect.type == "damage_multiplier" and effect.target == "attack"
                        and card.type == "attack")
                    or (effect.type == "defense_multiplier" and effect.target == "defense"
                        and card.type == "defense")
                if isMatchingMult and (not bestMult
                    or (effect.value or 1) > (bestMult.value or 1)) then
                    bestMult = effect
                    bestMultJoker = joker
                end
            end
        end
    end
    if bestMult then
        local newValue, m = self:processEffect(bestMult, card, finalValue, turnContext)
        if newValue ~= finalValue then
            finalValue = newValue
            if m then table.insert(msgs, m) end
            pushJokerProc(game, procs, bestMultJoker, multLabel(bestMult.value), "mult")
        end
    end

    for _, joker in ipairs(game.jokerSlots) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                -- Multiplicadores ja resolvidos acima (so o maior conta).
                if effect.type ~= "damage_multiplier" and effect.type ~= "defense_multiplier" then
                    local newValue, msg = self:processEffect(effect, card, finalValue, turnContext)
                    if newValue ~= finalValue then
                        local delta = newValue - finalValue
                        finalValue = newValue
                        if msg then table.insert(msgs, msg) end
                        pushJokerProc(game, procs, joker,
                            (delta >= 0 and "+" or "") .. string.format("%g", delta), "chips")
                    end
                end
            end
        end
    end

    for _, msg in ipairs(msgs) do
        game:addMessage(msg, "info")
    end
    return finalValue, procs
end

-- Game feel v1: PREVISÃO de quantos procs de joker uma carta vai disparar —
-- usada pelo Game ANTES do startCombat pra esticar o stagger (a próxima carta
-- espera os ticks da anterior). Aproximação barata da mesma lógica de
-- applyJokerEffects + triggers on_attack/on_defend; contar 1 a mais/menos só
-- muda pacing, nunca valores.
function EffectSystem:predictJokerProcs(game, card)
    if not game or not game.jokerSlots or #game.jokerSlots == 0 then return 0 end
    local isAtk = card.type == "attack"
    local isDef = card.type == "defense"
    if not isAtk and not isDef then return 0 end
    local n, multSeen = 0, false
    for _, joker in ipairs(game.jokerSlots) do
        for _, e in ipairs(joker.effects or {}) do
            local t = e.type
            if isAtk then
                if t == "damage_multiplier" and e.target == "attack" then
                    if not multSeen then n = n + 1; multSeen = true end
                elseif t == "damage_bonus" or t == "on_attack_heal"
                    or t == "on_attack_debuff" then
                    n = n + 1
                end
            else
                if t == "defense_multiplier" and e.target == "defense" then
                    if not multSeen then n = n + 1; multSeen = true end
                elseif t == "defense_bonus" or t == "on_defend_damage" then
                    n = n + 1
                end
            end
        end
    end
    return n
end

-- Retorna (novoValor, mensagem?) para um efeito aplicado a uma carta específica.
-- turnContext e passado para permitir efeitos tag-aware futuros (Fase 3).
function EffectSystem:processEffect(effect, card, currentValue, turnContext)
    local t = effect.type
    local v = effect.value or 1
    local target = effect.target

    if t == "damage_multiplier" and target == "attack" and card.type == "attack" then
        return currentValue * v, msg("dmg_multiplier", { value = v })

    elseif t == "defense_multiplier" and target == "defense" and card.type == "defense" then
        return currentValue * v, msg("def_multiplier", { value = v })

    elseif t == "damage_bonus" and card.type == "attack" then
        return currentValue + v, msg("dmg_bonus", { value = v })

    elseif t == "defense_bonus" and card.type == "defense" then
        return currentValue + v, msg("def_bonus", { value = v })
    end

    return currentValue, nil
end

-- Bonus aditivo a ataques baseado em player.strength. Usado como efeito NA
-- PROPRIA CARTA (card.effects, nao joker). Chamado pelo Game ao resolver ataque.
-- Retorna (novoValor, mensagem?) para consumo pelo Game:processCardInCombat.
--
-- IMPORTANTE: strength_scaling/dexterity_scaling são FLAG-ONLY aqui — Strength
-- e Dexterity do player já são adicionados em Game:processCardInCombat via o
-- parâmetro statBonus de computeCardValue. Antes da Fase 2 do refactor de
-- balance, este branch também somava → strength entrava 2x para cartas que
-- declaravam o effect. Mantemos o effect declarado nas cartas (semântica útil
-- para tooltip/UI/validate_cards) mas não dobramos a aplicação.
function EffectSystem:applyCardEffects(game, card, baseValue)
    local finalValue = baseValue
    if not card.effects or type(card.effects) ~= "table" then
        return finalValue
    end
    for _, effect in ipairs(card.effects) do
        local t = effect.type
        local v = effect.value or 1

        if t == "damage_bonus_self" and card.type == "attack" then
            -- Bonus aditivo local da propria carta (ex: "10 + 2 por combo")
            finalValue = finalValue + v

        elseif t == "multi_hit" and card.type == "attack" then
            -- Ataque multiplo (N hits). Implementado via multiplicacao simples aqui;
            -- animacao/feel sera refinado quando integrarmos com CombatAnimationSystem.
            finalValue = finalValue * math.max(1, v)
        end
        -- strength_scaling/dexterity_scaling: flag-only, ver comentário acima.
    end
    return finalValue
end

-- ==============================================================================
-- Efeitos de cartas de efeito (potions/utilitárias) — jogadas, consumidas.
-- ==============================================================================

-- Efeitos que JA emitem os proprios passos (orbes evocam/canalizam um a um).
-- Envolve-los num passo externo os colapsaria de volta num instante so.
local SELF_STEPPED = {
    channel_orb = true, evoke_orb = true, evoke_all_orbs = true,
}
-- Mudanca de ESTADO merece o beat longo; numero que sobe e desce, o curto.
local EFFECT_HOLD = {
    apply_debuff = "STATUS", apply_buff = "STATUS",
    gain_strength = "STATUS", gain_dexterity = "STATUS",
    increase_max_mana = "STATUS",
}

-- Entrada SEQUENCIADA de um efeito de carta: com `game._beatSink` ativo cada
-- efeito ocupa um instante proprio (ver CombatBeats); sem sink roda na hora.
-- `showFallback` reproduz o comportamento do `card.passive` compilado pelo
-- CardDatabase (descrever no feed o efeito que o engine nao reconhece).
function EffectSystem:processEffectCardStepped(game, effect, showFallback)
    local run = function()
        local handled = self:processEffectCard(game, effect)
        if not handled and showFallback then
            local text = I18n.effectDesc(effect)
            if text and text ~= "" then game:addMessage(text, "info") end
        end
    end
    if SELF_STEPPED[effect.type] then
        run()
        return
    end
    CombatBeats.step(sinkOf(game), "effect." .. tostring(effect.type), run,
        EFFECT_HOLD[effect.type] or "SIDE_EFFECT")
end

function EffectSystem:processEffectCard(game, effect)
    local t = effect.type
    local v = effect.value or 0

    if t == "instant_heal" then
        local amount = self:applyHealMultiplier(game, v)
        game.player:heal(amount)
        game:addMessage(msg("healed", { value = amount }), "success")
        -- Game feel v1: cura SOA (shimmer) e brilha verde no painel do jogador.
        Sfx.play("healShimmer")
        CardFeel.burstAtPlayer("heal", 1.0)
        return true

    elseif t == "self_damage" then
        -- Custo em sangue: HP direto, ignora armor (F0 gameplay-overhaul —
        -- cartas tipo Sangria prometem "Perde N HP" e precisam cumprir).
        game.player:loseHealth(v)
        game:addMessage(msg("hp_cost", { value = v }), "warning")
        return true

    elseif t == "restore_mana" then
        game.player.mana = math.min(game.player.maxMana, game.player.mana + v)
        game:addMessage(msg("mana_restored", { value = v }), "info")
        return true

    elseif t == "increase_max_mana" then
        game.player.maxMana = game.player.maxMana + v
        game.player.mana = game.player.mana + v
        game:addMessage(msg("max_mana_up", { value = v }), "success")
        return true

    elseif t == "add_armor" then
        game.player:addArmor(v)
        game:addMessage(msg("armor_up", { value = v }), "info")
        return true

    elseif t == "magic_damage" then
        game.enemy:takeDamage(v)
        checkEnrage(game)
        game.score = game.score + v
        game:addMessage(msg("magic_damage", { value = v }), "success")
        -- Game feel v1: dano mágico de effect card também estoura no inimigo
        -- (cartas de ATAQUE já ganham burst via CombatSequence; efeito não).
        CardFeel.burstAtEnemy("magic", 0.9)
        showEnemyDamage(v)
        return true

    elseif t == "draw_cards" then
        for i = 1, v do game:drawCard((i - 1) * 0.08) end
        game:addMessage(msg("drew_cards", { value = v }), "info")
        return true

    elseif t == "apply_debuff" then
        -- value = nome do debuff ("poison"/"weak"/"vulnerable"),
        -- stacks = intensidade (ex: 3 de poison = 3 dano por turno),
        -- duration = turnos que dura (default 2).
        local debuff = {
            name = effect.value or "debuff",
            duration = effect.duration or 2,
            stacks = effect.stacks or 1,
        }
        game.enemy:addStatusEffect(debuff)
        -- F4: Miasma (15+ poison acumulado no inimigo).
        if debuff.name == "poison" then
            require("src.systems.AchievementSystem").onPoisonApplied(game, game.enemy)
        end
        game:addMessage(msg("debuff_applied", { name = debuff.name, duration = debuff.duration }), "warning")
        Sfx.play("debuffApplied")
        -- Game feel v1: o debuff APARECE no corpo do inimigo com a cor dele
        -- (veneno verde, weak lavanda, vulnerable rosado).
        CardFeel.burstAtEnemy(CardFeel.THEMES[debuff.name] and debuff.name or "poison", 0.8)
        return true

    elseif t == "discard_cards" then
        -- BUG FIX (Jul/2026): a carta descartada tem que IR PRO DISCARD, não
        -- sumir. table.remove(game.hand) só a arrancava da mão — nunca entrava
        -- em game.discard, então nunca voltava no reshuffle. Efeito: Sobrevivente
        -- (discard_cards=1) deletava 1 carta não-jogada por turno; em poucas
        -- rodadas o deck de batalha degenerava pras 3 cartas que o jogador
        -- jogava (as únicas que iam pro discard direito), infinitamente. O deck
        -- DA RUN (currentDeck) nunca foi tocado — o bug era só na instância da
        -- batalha. Ver smoke_discard test 13.
        local discarded = 0
        for _ = 1, v do
            if #game.hand > 0 then
                local card = table.remove(game.hand, love.math.random(#game.hand))
                table.insert(game.discard, card)
                discarded = discarded + 1
            end
        end
        game:addMessage(msg("discarded", { value = discarded }), "info")
        return true

    -- ===== Fase 2: novos efeitos =====

    elseif t == "gain_strength" then
        game.player:gainStrength(v)
        game:addMessage(msg("strength_up", { value = v }), "success")
        Sfx.play("strengthGain")
        CardFeel.burstAtPlayer("buff", 0.9)
        return true

    elseif t == "gain_dexterity" then
        game.player:gainDexterity(v)
        game:addMessage(msg("dexterity_up", { value = v }), "success")
        Sfx.play("strengthGain", { pitch = 1.15 })
        CardFeel.burstAtPlayer("armor", 0.9)
        return true

    elseif t == "apply_buff" then
        -- Aplica buff nomeado no jogador (ex: "focus"). value=nome, stacks=intensidade,
        -- duration em turnos.
        local name = effect.value or "buff"
        local stacks = effect.stacks or 1
        local duration = effect.duration or 3
        game.player:addBuff(name, duration, stacks)
        game:addMessage(msg("buff_applied",
            { name = name, stacks = stacks, duration = duration }), "success")
        return true

    elseif t == "channel_orb" then
        -- Empilha orb. orbType (default lightning), value = potencia.
        self:_stepChannelOrb(game, { type = effect.orbType or "lightning", value = v },
            sinkOf(game))
        return true

    elseif t == "evoke_orb" then
        if #(game.player.orbs or {}) == 0 then
            game:addMessage(msg("no_orbs"), "warning")
            return true
        end
        self:_stepEvokeOrb(game, sinkOf(game), 1)
        return true

    elseif t == "evoke_all_orbs" then
        -- UM ORBE POR VEZ (Set/2026): antes os 3 evocavam no mesmo instante e
        -- o jogador via um borrão de números sem saber qual orbe fez o quê.
        local count = #game.player.orbs
        for k = 1, count do
            self:_stepEvokeOrb(game, sinkOf(game), k)
        end
        if count > 0 then
            CombatBeats.step(sinkOf(game), "orb.evoke_all_done", function()
                game:addMessage(msg("evoked_orbs", { value = count }), "success")
            end, "MICRO")
        end
        return true

    elseif t == "aoe_magic_damage" then
        -- Por ora so ha 1 inimigo; aoe e alias de magic_damage. Stub pronto p/ multi-enemy.
        game.enemy:takeDamage(v)
        checkEnrage(game)
        game.score = game.score + v
        game:addMessage(msg("magic_damage", { value = v }), "success")
        CardFeel.burstAtEnemy("magic", 1.2)
        showEnemyDamage(v)
        return true

    elseif t == "mystery" then
        -- Sorteia efeito de um pool curto (MVP: lista fixa pra ser expandida em eventos/cards).
        local pool = effect.pool or {
            { type = "instant_heal", value = 6 },
            { type = "draw_cards", value = 2 },
            { type = "add_armor", value = 8 },
            { type = "magic_damage", value = 8 },
            { type = "gain_strength", value = 2 },
            { type = "channel_orb", orbType = "lightning", value = 3 },
        }
        local pick = pool[love.math.random(#pool)]
        game:addMessage(msg("mystery"), "info")
        return self:processEffectCard(game, pick)

    elseif t == "strength_scaling" or t == "dexterity_scaling"
        or t == "multi_hit" or t == "damage_bonus_self"
        or t == "retain_armor" then
        -- Efeitos processados em applyCardEffects (no damage path), nao aqui.
        -- Retorna true para suprimir o fallback de descricao.
        return true

    elseif t == "exhaust" or t == "innate" or t == "retain" then
        -- Flags, nao sao efeitos. Processados por Game ao jogar/montar mao.
        return true
    end

    return false
end

-- ==============================================================================
-- Orbes: formulas CANONICAS de pulso/evoke (fonte unica — a UI OrbRow exibe
-- estes mesmos numeros; mudou a formula aqui, a tela acompanha de graca).
-- ==============================================================================

-- Valor do PULSO por turno de um orbe (0 = nao pulsa; dark cresce em vez disso).
function EffectSystem.orbPulseValue(orb, focus)
    local ev = (orb.value or 1) + (focus or 0)
    if orb.type == "lightning" or orb.type == "ice" then
        return math.ceil(ev / 2)
    elseif orb.type == "fire" or orb.type == "holy" then
        return math.ceil(ev / 3)
    end
    return 0 -- dark: nao pulsa, cresce +2/turno
end

-- Valor do EVOKE de um orbe (dark evoca em dobro).
function EffectSystem.orbEvokeValue(orb, focus)
    local ev = (orb.value or 1) + (focus or 0)
    if orb.type == "dark" then return ev * 2 end
    return ev
end

-- Aplica o efeito mecanico de um orb evocado. Mapa central de tipos:
--   lightning: dano direto
--   ice      : armor
--   dark     : dano dobrado (simbolo: orb cresce enquanto canalizado; MVP = 2x valor)
--   fire     : dano em dot (aplica debuff "burn" via poison por ora; refinar)
--   holy     : cura
function EffectSystem:_evokeOrbEffect(game, orb)
    if not orb then return end
    local v = orb.value or 1
    -- FOCO (auditoria Jul/2026): o buff "focus" existia no HUD (pill) mas
    -- NADA concedia nem consumia — mecanica fantasma. Agora e o eixo de
    -- scaling do mago (identidade StS Defect): +1 de potencia por stack em
    -- CADA orbe evocado. Concedido por Foco Arcano / Consumir.
    local focus = 0
    if game.player and game.player.getBuffStacks then
        focus = game.player:getBuffStacks("focus") or 0
    end
    v = v + focus
    -- Game feel v1: o evoke ATERRISSA visivelmente — burst do elemento no
    -- alvo (dano → inimigo; armor/cura → painel do jogador).
    if orb.type == "lightning" then
        game.enemy:takeDamage(v)
        checkEnrage(game)
        game:addMessage(msg("evoke_lightning", { value = v }), "success")
        CardFeel.burstAtEnemy("lightning", 1.1)
        showEnemyDamage(v)
    elseif orb.type == "ice" then
        game.player:addArmor(v)
        game:addMessage(msg("evoke_ice", { value = v }), "info")
        CardFeel.burstAtPlayer("ice", 0.9)
    elseif orb.type == "dark" then
        game.enemy:takeDamage(v * 2)
        checkEnrage(game)
        game:addMessage(msg("evoke_shadow", { value = v * 2 }), "success")
        CardFeel.burstAtEnemy("dark", 1.2)
        showEnemyDamage(v * 2)
    elseif orb.type == "fire" then
        game.enemy:takeDamage(v)
        checkEnrage(game)
        game.enemy:addStatusEffect({ name = "poison", duration = 2, stacks = math.max(1, math.floor(v / 2)) })
        game:addMessage(msg("evoke_fire", { value = v }), "warning")
        CardFeel.burstAtEnemy("fire", 1.1)
        showEnemyDamage(v)
    elseif orb.type == "holy" then
        local amount = self:applyHealMultiplier(game, v)
        game.player:heal(amount)
        game:addMessage(msg("evoke_holy", { value = amount }), "success")
        CardFeel.burstAtPlayer("holy", 1.0)
    end
end

-- ==============================================================================
-- CANALIZAR x EVOCAR: dois acontecimentos que o jogador precisa DISTINGUIR
-- ==============================================================================
-- Pedido do dono (Set/2026), jogando com o mago: "Chuva de Meteoros canaliza
-- muitas ao mesmo tempo, fica confuso se esta dando dano ou se canalizando uma
-- nova". O defeito NAO era falta de beat — os beats ja existiam. Era que o
-- ESTADO mudava fora deles: `player:addOrb` rodava na COLETA (dentro do beat de
-- impacto da carta), entao os 3 orbes APARECIAM na fileira no mesmo instante do
-- numero de dano e os beats seguintes so tocavam som e pop-in em cima de orbes
-- que ja estavam la. O mesmo valia pro evoke: o orbe sumia no impacto e o flash
-- caia depois, no slot 1, em cima de um orbe que nem era aquele.
--
-- Agora a MUTACAO mora dentro do beat. E a linguagem separa os dois sentidos:
--   canalizar -> vai PARA a fileira: streak entrando, pop-in, pitch SUBINDO
--                com o slot (a fileira vira teclado: 1 grave, 3 agudo);
--   evocar    -> SAI da fileira pro combate: fantasma do orbe deixando o slot,
--                pitch GRAVE e descendo;
--   overflow  -> um TERCEIRO acontecimento (o orbe mais antigo e expulso pra
--                abrir vaga), com instante proprio e o som mais grave de todos.
local CHANNEL_PITCH_BASE, CHANNEL_PITCH_STEP = 0.92, 0.15
local EVOKE_PITCH_BASE,   EVOKE_PITCH_STEP   = 1.02, 0.10
local OVERFLOW_PITCH = 0.72

-- Canaliza UM orbe como acontecimento(s) proprio(s).
-- Beat 1 "orb.make_room" (MICRO): barato quando ha vaga. Quando a fileira esta
--   CHEIA ele expulsa o mais antigo e reivindica o instante via extendCurrent
--   (padrao do passo CONDICIONAL, o mesmo do enemy.enrage_check) — o jogador
--   ve o orbe SAIR antes do novo entrar, em vez de um sumir do nada.
-- Beat 2 "orb.channel" (ORB): o orbe entra. `addOrb` so roda AQUI.
function EffectSystem:_stepChannelOrb(game, orb, sink)
    local p = game.player
    if not p or not p.addOrb then return end

    CombatBeats.step(sink, "orb.make_room", function()
        if #(p.orbs or {}) < (p.orbSlots or 3) then return end
        local overflow = p:popOldestOrb()
        if not overflow then return end
        -- O evento raro aconteceu: marca no trace e estica o beat barato.
        CombatBeats.mark("orb.overflow")
        CombatBeats.extendCurrent("ORB")
        notifyOrbUI("notifyEvoke", 1, overflow, "overflow")
        self:_evokeOrbEffect(game, overflow)
        game:addMessage(msg("orb_overflow", { name = overflow.type }), "warning")
        Sfx.play("orbEvoke", { pitch = OVERFLOW_PITCH })
    end, "MICRO")

    CombatBeats.step(sink, "orb.channel", function()
        p:addOrb(orb)
        local slot = #p.orbs
        game:addMessage(msg("channeled", { name = orb.type, value = orb.value }), "info")
        -- Contavel como o cash out: um som por orbe, pitch subindo com o slot.
        Sfx.play("orbChannel",
            { pitch = CHANNEL_PITCH_BASE + (slot - 1) * CHANNEL_PITCH_STEP })
        notifyOrbUI("notifyChannel", slot, orb)
    end, "ORB")
end

-- Evoca o orbe mais antigo como acontecimento proprio. `ord`/`total` so afinam
-- o pitch quando o evoke vem em lote (evoke_all_orbs): desce a cada orbe, o
-- gesto sonoro contrario ao da canalizacao.
function EffectSystem:_stepEvokeOrb(game, sink, ord)
    CombatBeats.step(sink, "orb.evoke", function()
        local orb = game.player:popOldestOrb()
        if not orb then return end
        notifyOrbUI("notifyEvoke", 1, orb, "evoke")
        self:_evokeOrbEffect(game, orb)
        local pitch = EVOKE_PITCH_BASE - ((ord or 1) - 1) * EVOKE_PITCH_STEP
        Sfx.play("orbEvoke", { pitch = math.max(0.78, pitch) })
    end, "ORB")
end

-- Pulso passivo dos orbes (fim do turno do jogador, identidade Defect/StS):
-- cada orbe canalizado dispara uma versao fraca do seu evoke — o motor do
-- mago gera pressao POR TURNO, nao so no evoke (auditoria Jul/2026: orbe
-- inerte era a raiz do mago 0/6 no autoplay — dano anemico e DEFEND do
-- inimigo anulava turnos inteiros). Foco soma no valor base antes da
-- divisao, entao escala pulso E evoke.
function EffectSystem:orbPassiveTick(game, sink)
    local p = game.player
    if not p or not p.orbs or #p.orbs == 0 then return end
    sink = sink or sinkOf(game)
    local focus = (p.getBuffStacks and p:getBuffStacks("focus")) or 0
    -- UM ORBE POR VEZ (Set/2026, pedido do dono: "um exemplo e o mago com as
    -- orbes"). ANTES: o laco somava dmg/armor/heal dos 3 orbes e aplicava um
    -- numero agregado no mesmo instante — o jogador via "-7" e nao tinha como
    -- saber de onde veio. AGORA cada orbe pulsa no beat dele: flash no slot,
    -- numero saindo DAQUELE orbe, efeito aplicado, respiro, proximo.
    -- Formula canonica em orbPulseValue (fonte unica com a UI).
    for i, orb in ipairs(p.orbs) do
        local idx, o = i, orb
        local pulse = EffectSystem.orbPulseValue(o, focus)
        CombatBeats.step(sink, "orb.pulse." .. tostring(o.type), function()
            -- O pulso era o unico dos tres momentos do orbe SEM som (auditoria
            -- Set/2026). E meio-evoke, entao soa como um evoke pequeno: mesmo
            -- timbre, pitch alto, subindo com o slot — a fileira toca da
            -- esquerda pra direita e o jogador CONTA os orbes que agiram.
            Sfx.play("orbEvoke", { pitch = 1.28 + (idx - 1) * 0.10 })
            if o.type == "lightning" or o.type == "fire" then
                notifyOrbUI("notifyPulse", idx, "-" .. pulse, "damage")
                if pulse > 0 and game.enemy and game.enemy:isAlive() then
                    game.enemy:takeDamage(pulse)
                    checkEnrage(game)
                    game:addMessage(msg("orb_pulse_dmg", { value = pulse }), "info")
                    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
                    if okER and ER.triggerHurt then ER.triggerHurt() end
                end
            elseif o.type == "ice" then
                notifyOrbUI("notifyPulse", idx, "+" .. pulse, "armor")
                if pulse > 0 then
                    p:addArmor(pulse)
                    game:addMessage(msg("orb_pulse_armor", { value = pulse }), "info")
                end
            elseif o.type == "holy" then
                notifyOrbUI("notifyPulse", idx, "+" .. pulse, "heal")
                if pulse > 0 then
                    local amount = self:applyHealMultiplier(game, pulse)
                    p:heal(amount)
                    game:addMessage(msg("orb_pulse_heal", { value = amount }), "info")
                end
            elseif o.type == "dark" then
                o.value = (o.value or 1) + 2   -- cresce canalizado; evoke dobra
                notifyOrbUI("notifyPulse", idx, "+2", "grow")
            end
        end, "ORB")
    end
end

-- Aplica multiplicadores de heal vindos de jokers (heal_multiplier).
-- P2.4 (Jul/2026, rebalance v2): retorno com math.floor — sem ele, 5 x 1.5
-- rendia 7.5 HP fracionario no HUD (Prece Radiante sob Calice do Sabio).
function EffectSystem:applyHealMultiplier(game, amount, procSink)
    local final = amount
    for _, joker in ipairs(game.jokerSlots or {}) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                if effect.type == "heal_multiplier" then
                    local before = final
                    final = final * (effect.value or 1)
                    -- EFEITO QUE MUDA UM NUMERO TEM QUE TICAR (Set/2026, pedido
                    -- do dono sobre o Abraco Sombrio): o joker tinha defense_bonus
                    -- ticando e heal_multiplier MUDO — metade dele era invisivel.
                    -- Sem sink o proc dispara direto (escalonado no JokerProcFx).
                    if math.floor(final) ~= math.floor(before) then
                        pushJokerProc(game, procSink, joker,
                            multLabel(effect.value or 1) .. " PV", "heal")
                    end
                end
            end
        end
    end
    return math.floor(final)
end

-- ==============================================================================
-- ESPINHOS (thorn) — estado armado por cartas/jokers de on_defend_damage e
-- DISPARADO pelo golpe do inimigo. Fonte unica do valor pra logica e pra UI.
-- ==============================================================================

-- Quanto o jogador reflete AGORA (0 = sem espinhos armados).
function EffectSystem.thornStacks(game)
    local p = game and game.player
    if not p or not p.getBuffStacks then return 0 end
    return p:getBuffStacks("thorn") or 0
end

-- Dispara o reflexo. Chamado pelo Game DEPOIS do golpe do inimigo aterrissar,
-- no beat proprio dele. Retorna o dano refletido (0 se nao havia espinhos).
function EffectSystem:fireThornReflect(game)
    local v = EffectSystem.thornStacks(game)
    if v <= 0 then return 0 end
    local enemy = game.enemy
    if not enemy or not enemy.isAlive or not enemy:isAlive() then return 0 end
    enemy:takeDamage(v)
    game:addMessage(msg("reflect", { value = v }), "warning")
    -- Game feel v1: espinhos têm som metálico próprio + burst no inimigo
    -- (o dano refletido é VISÍVEL chegando nele).
    Sfx.play("thornReflect")
    CardFeel.burstAtEnemy("physical", 0.7)
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if okER and ER.triggerHurt then ER.triggerHurt() end
    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if okFT and okER and ER.getLastPos then
        local ex, ey = ER.getLastPos()
        if ex and ey then
            FloatingText.spawn("-" .. v, ex, ey, { kind = "damage", fontSize = 20 })
        end
    end
    return v
end

-- ==============================================================================
-- Efeitos de trigger — disparados pelo Game em eventos específicos.
-- triggerType: "attack" | "defend" | "turn_start"
-- context: tabela opcional com dados do evento (ex: {target = enemy}).
-- ==============================================================================

-- Mapa tipo-de-efeito -> gatilho que o dispara. Serve a DOIS propositos:
--   1) saber, SEM executar, se um efeito tem algo a fazer neste gatilho — sem
--      isso cada joker inerte viraria um BEAT vazio e o turno ganhava ar morto;
--   2) documentar o contrato num lugar só.
-- AO ADICIONAR UM TRIGGER NOVO em processTriggerEffect, REGISTRE AQUI — senão
-- ele nunca dispara. A trava `test_beats` compara este mapa com o código-fonte
-- de processTriggerEffect e falha se divergirem.
EffectSystem.TRIGGER_OF = {
    on_attack_heal     = "attack",
    on_attack_debuff   = "attack",
    on_defend_damage   = "defend",
    channel_per_turn   = "turn_start",
    strength_per_turn  = "turn_start",
    regen_per_turn     = "turn_start",
    damage_per_turn    = "turn_start",
    on_turn_start_draw = "turn_start",
}

-- context.beatSink (Set/2026): quando presente, cada trigger que TEM o que
-- fazer vira um PASSO na fila em vez de rodar junto com todos os outros — um
-- acontecimento por instante (ver src/systems/CombatBeats.lua). Sem sink o
-- comportamento e o antigo, sincrono (API direta: testes, autoplay).
function EffectSystem:applyTriggerEffects(game, triggerType, context)
    local sink = context and context.beatSink

    -- 1) Triggers de jokers ativos (ex: lifesteal, regen).
    -- P2.3 (Jul/2026): marca a FONTE joker no context — processTriggerEffect
    -- usa isso pra limitar on_defend_damage de joker a 1x/turno por joker.
    for _, joker in ipairs(game.jokerSlots or {}) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                if EffectSystem.TRIGGER_OF[effect.type] == triggerType then
                    local j, e = joker, effect
                    CombatBeats.step(sink, "trigger." .. triggerType .. "." .. tostring(e.type),
                        function()
                            if context then context.sourceJoker = j end
                            self:processTriggerEffect(game, e, triggerType, context)
                            if context then context.sourceJoker = nil end
                        end, EffectSystem.beatHoldFor(e.type))
                end
            end
        end
    end

    -- 2) Triggers da carta sendo jogada (passada pelo Game via context.sourceCard).
    -- Ex: defense card "Barreira de Fogo" tem on_defend_damage → arma espinhos.
    -- Sem isso, triggers em cartas non-joker seriam silenciosamente no-op.
    if context and context.sourceCard and context.sourceCard.effects then
        for _, effect in ipairs(context.sourceCard.effects) do
            if EffectSystem.TRIGGER_OF[effect.type] == triggerType then
                local e = effect
                CombatBeats.step(sink, "trigger." .. triggerType .. "." .. tostring(e.type),
                    function()
                        if context then context.sourceJoker = nil end
                        self:processTriggerEffect(game, e, triggerType, context)
                    end, EffectSystem.beatHoldFor(e.type))
            end
        end
    end
end

-- Quanto tempo cada trigger ocupa. Mudanca de ESTADO (buff/debuff/espinhos)
-- ganha o beat longo; numero que so sobe e desce ganha o curto.
local TRIGGER_HOLD = {
    on_defend_damage   = "STATUS",
    on_attack_debuff   = "STATUS",
    strength_per_turn  = "STATUS",
    channel_per_turn   = "ORB",
}
function EffectSystem.beatHoldFor(effectType)
    return TRIGGER_HOLD[effectType] or "SIDE_EFFECT"
end

function EffectSystem:processTriggerEffect(game, effect, triggerType, context)
    local t = effect.type
    local v = effect.value or 0

    if t == "on_attack_heal" and triggerType == "attack" then
        local amount = self:applyHealMultiplier(game, v, context and context.procSink)
        game.player:heal(amount)
        game:addMessage(msg("lifesteal", { value = amount }), "success")
        -- Game feel v1: lifesteal SOA (shimmer discreto) e o joker fonte tica.
        -- healShimmerSoft: alias registrado mais baixo (opts.volume mutaria o base).
        Sfx.play("healShimmerSoft")
        pushJokerProc(game, context and context.procSink, context and context.sourceJoker,
            "+" .. amount .. " PV", "heal")

    elseif t == "on_defend_damage" and triggerType == "defend" then
        -- ESPINHOS VIRARAM ESTADO (Set/2026, pedido do dono: "esse dano nao
        -- deveria ser so quando o inimigo atacar?"). ANTES: jogar a carta ja
        -- causava o dano na hora — o reflexo acontecia mesmo que o inimigo
        -- nunca atacasse, e a palavra "refletir" era mentira. AGORA (padrao
        -- StS / Flame Barrier): a carta ARMA o buff "thorn" no jogador, que
        -- dura o turno; quem dispara o dano e o GOLPE do inimigo
        -- (Game:_enemyStrikeChain -> EffectSystem:fireThornReflect), no
        -- instante proprio dele. O buff expira no Player:onTurnStart seguinte.
        --
        -- P2.3 preservado: thorn cuja FONTE e JOKER ARMA no maximo 1x por
        -- turno POR JOKER (flag resetada em Game:drawForTurn) — o teto de
        -- stacks por turno continua o mesmo de antes do rebalance. Thorn de
        -- CARTA (context.sourceCard) continua acumulando POR CARTA jogada.
        local fired = true
        local joker = context and context.sourceJoker
        if joker then
            game._jokerThornFiredThisTurn = game._jokerThornFiredThisTurn or {}
            if game._jokerThornFiredThisTurn[joker] then
                fired = false
            else
                game._jokerThornFiredThisTurn[joker] = true
            end
        end
        if fired and game.player and game.player.addBuff then
            -- duration 1 = "dura ate o inicio do meu proximo turno".
            game.player:addBuff("thorn", 1, v)
            local total = game.player:getBuffStacks("thorn")
            game:addMessage(I18n.t("messages.thorn_ready", { value = total },
                "Espinhos armados: {value}"), "info")
            pushJokerProc(game, context and context.procSink, joker,
                "+" .. v .. " " .. I18n.t("status.thorn.name", nil, "Espinhos"), "buff")
            local okCF, CF = pcall(require, "src.systems.CardFeel")
            if okCF then CF.burstAtPlayer("armor", 0.6) end
        end

    elseif t == "channel_per_turn" and triggerType == "turn_start" then
        -- P2.1 (Jul/2026, rebalance v2 — engine flagada #1): motor de orbes
        -- (mage_electrodynamics). Canaliza 1 orbe do tipo declarado no inicio
        -- de cada turno. Espelho de strength_per_turn; overflow FIFO evoca o
        -- orbe mais antigo, igual ao channel_orb de carta.
        if game.player and game.player.addOrb then
            -- Mesma rotina da carta (_stepChannelOrb): abrir vaga e canalizar
            -- sao passos distintos. Aqui o sink e nil DE PROPOSITO — este
            -- trigger JA roda dentro do beat "trigger.turn_start.channel_per_turn"
            -- (hold ORB); empurrar pra fila agora jogaria o orbe pro fim do
            -- turno. Quando ha overflow, o extendCurrent de _stepChannelOrb
            -- estica ESTE beat, que e o instante certo.
            self:_stepChannelOrb(game,
                { type = effect.orbType or "lightning", value = math.max(1, v) }, nil)
            pushJokerProc(game, context and context.procSink,
                context and context.sourceJoker, "+1 Orbe", "buff")
        end

    elseif t == "strength_per_turn" and triggerType == "turn_start" then
        -- Demon Form: Força cumulativa por turno (identidade StS clássica).
        game.player:gainStrength(v)
        game:addMessage(msg("demon_form", { value = v }), "success")
        pushJokerProc(game, context and context.procSink,
            context and context.sourceJoker, "+" .. v .. " Forca", "buff")

    elseif t == "regen_per_turn" and triggerType == "turn_start" then
        local amount = self:applyHealMultiplier(game, v, context and context.procSink)
        game.player:heal(amount)
        game:addMessage(msg("regen", { value = amount }), "success")
        pushJokerProc(game, context and context.procSink,
            context and context.sourceJoker, "+" .. amount .. " PV", "heal")

    elseif t == "damage_per_turn" and triggerType == "turn_start" then
        -- Custo auto-infligido: HP direto, SEM passar pela armadura (senão
        -- o downside de cartas tipo Berserk é fictício — auditoria F0).
        game.player:loseHealth(v)
        game:addMessage(msg("penalty", { value = v }), "warning")
        pushJokerProc(game, context and context.procSink,
            context and context.sourceJoker, "-" .. v .. " PV", "damage")

    elseif t == "on_turn_start_draw" and triggerType == "turn_start" then
        -- Joker que compra cartas extra no início do turno (ex: joker_004
        -- "Bobo da Corte", mage_creative_ai). value = quantas cartas.
        local n = math.max(1, v)
        for i = 1, n do
            game:drawCard((i - 1) * 0.06)
        end
        game:addMessage(msg("extra_draw", { value = n }), "info")
        pushJokerProc(game, context and context.procSink,
            context and context.sourceJoker, "+" .. n .. " cartas", "buff")

    elseif t == "on_attack_debuff" and triggerType == "attack" then
        -- Joker que aplica debuff a cada ataque (ex: rogue_envenom poison-on-hit).
        -- effect.debuffName = "poison"/"weak"/"vulnerable"
        if context and context.target and context.target.addStatusEffect then
            local name = effect.debuffName or "poison"
            context.target:addStatusEffect({
                name = name,
                stacks = effect.stacks or 1,
                duration = effect.duration or 2,
            })
            game:addMessage(msg("applied", { name = name }), "warning")
            Sfx.play("debuffApplied")
            -- Game feel v1: o debuff APARECE no corpo do inimigo + joker tica.
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then
                CardFeel.burstAtEnemy(CardFeel.THEMES[name] and name or "poison", 0.8)
            end
            pushJokerProc(game, context.procSink, context.sourceJoker,
                I18n.t("status." .. name .. ".name", nil, name), "buff")
        end
    end
end

return EffectSystem
