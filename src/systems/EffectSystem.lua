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

    for _, joker in ipairs(game.jokerSlots) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                local newValue, msg = self:processEffect(effect, card, finalValue, turnContext)
                if newValue ~= finalValue then
                    finalValue = newValue
                    if msg then table.insert(msgs, msg) end
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
function EffectSystem:applyCardEffects(game, card, baseValue)
    local finalValue = baseValue
    if not card.effects or type(card.effects) ~= "table" then
        return finalValue
    end
    for _, effect in ipairs(card.effects) do
        local t = effect.type
        local v = effect.value or 1

        if t == "strength_scaling" and card.type == "attack" then
            finalValue = finalValue + (game.player.strength or 0)

        elseif t == "dexterity_scaling" and card.type == "defense" then
            finalValue = finalValue + (game.player.dexterity or 0)

        elseif t == "damage_bonus_self" and card.type == "attack" then
            -- Bonus aditivo local da propria carta (ex: "10 + 2 por combo")
            finalValue = finalValue + v

        elseif t == "multi_hit" and card.type == "attack" then
            -- Ataque multiplo (N hits). Implementado via multiplicacao simples aqui;
            -- animacao/feel sera refinado quando integrarmos com CombatAnimationSystem.
            finalValue = finalValue * math.max(1, v)
        end
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
        for i = 1, v do game:drawCard() end
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
        game:addMessage(msg("debuff_applied", { name = debuff.name, duration = debuff.duration }), "warning")
        Sfx.play("debuffApplied")
        return true

    elseif t == "discard_cards" then
        for _ = 1, v do
            if #game.hand > 0 then
                table.remove(game.hand, love.math.random(#game.hand))
            end
        end
        game:addMessage(msg("discarded", { value = v }), "info")
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
            self:_evokeOrbEffect(game, overflow)
            game:addMessage("Orb sobrepujou: " .. overflow.type .. " evocado", "warning")
            Sfx.play("orbEvoke")
        end
        return true

    elseif t == "evoke_orb" then
        local orb = game.player:popOldestOrb()
        if not orb then
            game:addMessage("Sem orbs para evocar", "warning")
            return true
        end
        self:_evokeOrbEffect(game, orb)
        Sfx.play("orbEvoke")
        return true

    elseif t == "evoke_all_orbs" then
        local count = 0
        while #game.player.orbs > 0 do
            local orb = game.player:popOldestOrb()
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
        or t == "multi_hit" or t == "damage_bonus_self" then
        -- Efeitos processados em applyCardEffects (no damage path), nao aqui.
        -- Retorna true para suprimir o fallback de descricao.
        return true

    elseif t == "exhaust" or t == "innate" or t == "retain" then
        -- Flags, nao sao efeitos. Processados por Game ao jogar/montar mao.
        return true
    end

    return false
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

-- Aplica multiplicadores de heal vindos de jokers (heal_multiplier).
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
    return final
end

-- ==============================================================================
-- Efeitos de trigger — disparados pelo Game em eventos específicos.
-- triggerType: "attack" | "defend" | "turn_start"
-- context: tabela opcional com dados do evento (ex: {target = enemy}).
-- ==============================================================================

function EffectSystem:applyTriggerEffects(game, triggerType, context)
    for _, joker in ipairs(game.jokerSlots or {}) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                self:processTriggerEffect(game, effect, triggerType, context)
            end
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
        if context and context.target then
            context.target:takeDamage(v)
            game:addMessage(msg("reflect", { value = v }), "warning")
        end

    elseif t == "regen_per_turn" and triggerType == "turn_start" then
        local amount = self:applyHealMultiplier(game, v)
        game.player:heal(amount)
        game:addMessage(msg("regen", { value = amount }), "success")

    elseif t == "damage_per_turn" and triggerType == "turn_start" then
        game.player:takeDamage(v)
        game:addMessage(msg("penalty", { value = v }), "warning")
    end
end

return EffectSystem
