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

-- ==============================================================================
-- Efeitos contínuos de jokers (chamados ao jogar uma carta de ataque/defesa).
-- ==============================================================================

-- turnContext (opcional, Fase 3+): tabela com { allSelectedCards, tagCounts,
-- activeCombos, cardsProcessed, turnNumber }. Se presente, combos amplificam o
-- valor ANTES dos jokers (multiplicador-sobre-multiplicador nao vira produtorio).
function EffectSystem:applyJokerEffects(game, card, baseValue, turnContext)
    local finalValue = baseValue
    local msgs = {}

    -- P0.9 (Jul/2026, rebalance v2 — LARGEST-MULTIPLIER-WINS): entre os jokers
    -- ativos, APENAS o MAIOR damage_multiplier e o MAIOR defense_multiplier
    -- contam. Sem isso, echo_form 1.5 x joker_001 1.5 = x2.25 em cadeia
    -- (produto x5.06 com combo+vulnerable — boss A2 em ~1.5 turnos), e duas
    -- copias do mesmo joker multiplicador dobravam de graca. Bonus FLAT
    -- (damage_bonus/defense_bonus) continuam somando TODOS; multiplicadores
    -- de COMBO e vulnerable sao camadas distintas do pipeline e ficam fora
    -- da regra. NAO reintroduzir produto em cadeia aqui.
    local bestMult = nil
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
                end
            end
        end
    end
    if bestMult then
        local newValue, m = self:processEffect(bestMult, card, finalValue, turnContext)
        if newValue ~= finalValue then
            finalValue = newValue
            if m then table.insert(msgs, m) end
        end
    end

    for _, joker in ipairs(game.jokerSlots) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                -- Multiplicadores ja resolvidos acima (so o maior conta).
                if effect.type ~= "damage_multiplier" and effect.type ~= "defense_multiplier" then
                    local newValue, msg = self:processEffect(effect, card, finalValue, turnContext)
                    if newValue ~= finalValue then
                        finalValue = newValue
                        if msg then table.insert(msgs, msg) end
                    end
                end
            end
        end
    end

    for _, msg in ipairs(msgs) do
        game:addMessage(msg, "info")
    end
    return finalValue
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

function EffectSystem:processEffectCard(game, effect)
    local t = effect.type
    local v = effect.value or 0

    if t == "instant_heal" then
        local amount = self:applyHealMultiplier(game, v)
        game.player:heal(amount)
        game:addMessage(msg("healed", { value = amount }), "success")
        return true

    elseif t == "self_damage" then
        -- Custo em sangue: HP direto, ignora armor (F0 gameplay-overhaul —
        -- cartas tipo Sangria prometem "Perde N HP" e precisam cumprir).
        game.player:loseHealth(v)
        game:addMessage("-" .. v .. " HP (custo)", "warning")
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
        game.score = game.score + v
        game:addMessage(msg("magic_damage", { value = v }), "success")
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
        game:addMessage("Força +" .. v, "success")
        Sfx.play("strengthGain")
        return true

    elseif t == "gain_dexterity" then
        game.player:gainDexterity(v)
        game:addMessage("Destreza +" .. v, "success")
        return true

    elseif t == "apply_buff" then
        -- Aplica buff nomeado no jogador (ex: "focus"). value=nome, stacks=intensidade,
        -- duration em turnos.
        local name = effect.value or "buff"
        local stacks = effect.stacks or 1
        local duration = effect.duration or 3
        game.player:addBuff(name, duration, stacks)
        game:addMessage("Buff: " .. name .. " (" .. stacks .. "x, " .. duration .. "t)", "success")
        return true

    elseif t == "channel_orb" then
        -- Empilha orb. orbType (default lightning), value = potencia.
        local orb = { type = effect.orbType or "lightning", value = v }
        local overflow = game.player:addOrb(orb)
        game:addMessage("Canaliza " .. orb.type .. " (" .. orb.value .. ")", "info")
        Sfx.play("orbChannel")
        if overflow then
            -- Overflow: orb mais antigo e evocado automaticamente
            notifyOrbUI("notifyEvoke", 1, overflow)
            self:_evokeOrbEffect(game, overflow)
            game:addMessage("Orb sobrepujou: " .. overflow.type .. " evocado", "warning")
            Sfx.play("orbEvoke")
        end
        -- UI: orbe "nasce" no slot (pop-in). Depois do overflow pra animacao
        -- de saida nao engolir a de entrada.
        notifyOrbUI("notifyChannel", #game.player.orbs)
        return true

    elseif t == "evoke_orb" then
        local orb = game.player:popOldestOrb()
        if not orb then
            game:addMessage("Sem orbs para evocar", "warning")
            return true
        end
        notifyOrbUI("notifyEvoke", 1, orb)
        self:_evokeOrbEffect(game, orb)
        Sfx.play("orbEvoke")
        return true

    elseif t == "evoke_all_orbs" then
        local count = 0
        while #game.player.orbs > 0 do
            local orb = game.player:popOldestOrb()
            notifyOrbUI("notifyEvoke", 1, orb)
            self:_evokeOrbEffect(game, orb)
            count = count + 1
        end
        if count > 0 then
            game:addMessage("Evocou " .. count .. " orbs!", "success")
            Sfx.play("orbEvoke")
        end
        return true

    elseif t == "aoe_magic_damage" then
        -- Por ora so ha 1 inimigo; aoe e alias de magic_damage. Stub pronto p/ multi-enemy.
        game.enemy:takeDamage(v)
        game.score = game.score + v
        game:addMessage(msg("magic_damage", { value = v }), "success")
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
        game:addMessage("Mistério revelado!", "info")
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
    if orb.type == "lightning" then
        game.enemy:takeDamage(v)
        game:addMessage("Raio evocado: " .. v .. " dano", "success")
    elseif orb.type == "ice" then
        game.player:addArmor(v)
        game:addMessage("Gelo evocado: +" .. v .. " armor", "info")
    elseif orb.type == "dark" then
        game.enemy:takeDamage(v * 2)
        game:addMessage("Sombra evocada: " .. (v * 2) .. " dano", "success")
    elseif orb.type == "fire" then
        game.enemy:takeDamage(v)
        game.enemy:addStatusEffect({ name = "poison", duration = 2, stacks = math.max(1, math.floor(v / 2)) })
        game:addMessage("Fogo evocado: " .. v .. " dano + queima", "warning")
    elseif orb.type == "holy" then
        local amount = self:applyHealMultiplier(game, v)
        game.player:heal(amount)
        game:addMessage("Luz evocada: +" .. amount .. " HP", "success")
    end
end

-- Pulso passivo dos orbes (fim do turno do jogador, identidade Defect/StS):
-- cada orbe canalizado dispara uma versao fraca do seu evoke — o motor do
-- mago gera pressao POR TURNO, nao so no evoke (auditoria Jul/2026: orbe
-- inerte era a raiz do mago 0/6 no autoplay — dano anemico e DEFEND do
-- inimigo anulava turnos inteiros). Foco soma no valor base antes da
-- divisao, entao escala pulso E evoke.
function EffectSystem:orbPassiveTick(game)
    local p = game.player
    if not p or not p.orbs or #p.orbs == 0 then return end
    local focus = (p.getBuffStacks and p:getBuffStacks("focus")) or 0
    local dmg, armor, heal = 0, 0, 0
    -- Usabilidade (Jul/2026): pulso POR ORBE tem feedback visual proprio —
    -- flash no slot + numero flutuante saindo DO orbe (causalidade: o jogador
    -- ve QUAL orbe fez O QUE). Formula canonica em orbPulseValue.
    for i, orb in ipairs(p.orbs) do
        local pulse = EffectSystem.orbPulseValue(orb, focus)
        if orb.type == "lightning" or orb.type == "fire" then
            dmg = dmg + pulse
            notifyOrbUI("notifyPulse", i, "-" .. pulse, "damage")
        elseif orb.type == "ice" then
            armor = armor + pulse
            notifyOrbUI("notifyPulse", i, "+" .. pulse, "armor")
        elseif orb.type == "holy" then
            heal = heal + pulse
            notifyOrbUI("notifyPulse", i, "+" .. pulse, "heal")
        elseif orb.type == "dark" then
            orb.value = (orb.value or 1) + 2   -- cresce canalizado; evoke dobra
            notifyOrbUI("notifyPulse", i, "+2", "grow")
        end
    end
    if dmg > 0 and game.enemy and game.enemy:isAlive() then
        game.enemy:takeDamage(dmg)
        game:addMessage("Orbes pulsam: " .. dmg .. " dano", "info")
        local okER, ER = pcall(require, "src.ui.EnemyRenderer")
        if okER and ER.triggerHurt then ER.triggerHurt() end
    end
    if armor > 0 then
        p:addArmor(armor)
        game:addMessage("Orbes pulsam: +" .. armor .. " armor", "info")
    end
    if heal > 0 then
        local amount = self:applyHealMultiplier(game, heal)
        p:heal(amount)
        game:addMessage("Orbes pulsam: +" .. amount .. " HP", "info")
    end
end

-- Aplica multiplicadores de heal vindos de jokers (heal_multiplier).
-- P2.4 (Jul/2026, rebalance v2): retorno com math.floor — sem ele, 5 x 1.5
-- rendia 7.5 HP fracionario no HUD (Prece Radiante sob Calice do Sabio).
function EffectSystem:applyHealMultiplier(game, amount)
    local final = amount
    for _, joker in ipairs(game.jokerSlots or {}) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                if effect.type == "heal_multiplier" then
                    final = final * (effect.value or 1)
                end
            end
        end
    end
    return math.floor(final)
end

-- ==============================================================================
-- Efeitos de trigger — disparados pelo Game em eventos específicos.
-- triggerType: "attack" | "defend" | "turn_start"
-- context: tabela opcional com dados do evento (ex: {target = enemy}).
-- ==============================================================================

function EffectSystem:applyTriggerEffects(game, triggerType, context)
    -- 1) Triggers de jokers ativos (ex: lifesteal, regen).
    -- P2.3 (Jul/2026): marca a FONTE joker no context — processTriggerEffect
    -- usa isso pra limitar on_defend_damage de joker a 1x/turno por joker.
    for _, joker in ipairs(game.jokerSlots or {}) do
        if joker.effects then
            if context then context.sourceJoker = joker end
            for _, effect in ipairs(joker.effects) do
                self:processTriggerEffect(game, effect, triggerType, context)
            end
            if context then context.sourceJoker = nil end
        end
    end

    -- 2) Triggers da carta sendo jogada (passada pelo Game via context.sourceCard).
    -- Ex: defense card "Barreira de Fogo" tem on_defend_damage → reflete dano.
    -- Sem isso, triggers em cartas non-joker seriam silenciosamente no-op.
    if context and context.sourceCard and context.sourceCard.effects then
        for _, effect in ipairs(context.sourceCard.effects) do
            self:processTriggerEffect(game, effect, triggerType, context)
        end
    end
end

function EffectSystem:processTriggerEffect(game, effect, triggerType, context)
    local t = effect.type
    local v = effect.value or 0

    if t == "on_attack_heal" and triggerType == "attack" then
        local amount = self:applyHealMultiplier(game, v)
        game.player:heal(amount)
        game:addMessage(msg("lifesteal", { value = amount }), "success")

    elseif t == "on_defend_damage" and triggerType == "defend" then
        -- P2.3 (Jul/2026, rebalance v2): thorn cuja FONTE e JOKER dispara no
        -- maximo 1x por turno POR JOKER (flag resetada em Game:drawForTurn).
        -- Sem a trava, o reflexo escalava linearmente com defesas jogadas
        -- (draw engine = 4-5 defesas/turno => 54+ refletidos so de jokers e
        -- invulnerabilidade no boss A3). Thorn de CARTA (context.sourceCard,
        -- ex: Barreira de Fogo / Escudo de Espinhos) continua POR CARTA.
        if context and context.target then
            local fired = true
            local joker = context.sourceJoker
            if joker then
                game._jokerThornFiredThisTurn = game._jokerThornFiredThisTurn or {}
                if game._jokerThornFiredThisTurn[joker] then
                    fired = false
                else
                    game._jokerThornFiredThisTurn[joker] = true
                end
            end
            if fired then
                context.target:takeDamage(v)
                game:addMessage(msg("reflect", { value = v }), "warning")
            end
        end

    elseif t == "channel_per_turn" and triggerType == "turn_start" then
        -- P2.1 (Jul/2026, rebalance v2 — engine flagada #1): motor de orbes
        -- (mage_electrodynamics). Canaliza 1 orbe do tipo declarado no inicio
        -- de cada turno. Espelho de strength_per_turn; overflow FIFO evoca o
        -- orbe mais antigo, igual ao channel_orb de carta.
        if game.player and game.player.addOrb then
            local orb = { type = effect.orbType or "lightning", value = math.max(1, v) }
            local overflow = game.player:addOrb(orb)
            game:addMessage("Canaliza " .. orb.type .. " (" .. orb.value .. ")", "info")
            Sfx.play("orbChannel")
            if overflow then
                notifyOrbUI("notifyEvoke", 1, overflow)
                self:_evokeOrbEffect(game, overflow)
                game:addMessage("Orb sobrepujou: " .. overflow.type .. " evocado", "warning")
                Sfx.play("orbEvoke")
            end
            notifyOrbUI("notifyChannel", #game.player.orbs)
        end

    elseif t == "strength_per_turn" and triggerType == "turn_start" then
        -- Demon Form: Força cumulativa por turno (identidade StS clássica).
        game.player:gainStrength(v)
        game:addMessage("+" .. v .. " Forca (Forma Demoniaca)", "success")

    elseif t == "regen_per_turn" and triggerType == "turn_start" then
        local amount = self:applyHealMultiplier(game, v)
        game.player:heal(amount)
        game:addMessage(msg("regen", { value = amount }), "success")

    elseif t == "damage_per_turn" and triggerType == "turn_start" then
        -- Custo auto-infligido: HP direto, SEM passar pela armadura (senão
        -- o downside de cartas tipo Berserk é fictício — auditoria F0).
        game.player:loseHealth(v)
        game:addMessage(msg("penalty", { value = v }), "warning")

    elseif t == "on_turn_start_draw" and triggerType == "turn_start" then
        -- Joker que compra cartas extra no início do turno (ex: joker_004
        -- "Bobo da Corte", mage_creative_ai). value = quantas cartas.
        local n = math.max(1, v)
        for i = 1, n do
            game:drawCard((i - 1) * 0.06)
        end
        game:addMessage("Compra extra: +" .. n, "info")

    elseif t == "on_attack_debuff" and triggerType == "attack" then
        -- Joker que aplica debuff a cada ataque (ex: rogue_envenom poison-on-hit).
        -- effect.debuffName = "poison"/"weak"/"vulnerable"
        if context and context.target and context.target.addStatusEffect then
            context.target:addStatusEffect({
                name = effect.debuffName or "poison",
                stacks = effect.stacks or 1,
                duration = effect.duration or 2,
            })
            game:addMessage("Aplicou " .. (effect.debuffName or "poison"), "warning")
            Sfx.play("debuffApplied")
        end
    end
end

return EffectSystem
