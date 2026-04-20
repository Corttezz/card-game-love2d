-- src/systems/EffectSystem.lua
-- Sistema modular de efeitos de cartas.
-- Dois domínios:
--   1. Efeitos *contínuos* de jokers — modificam o dano/defesa/heal de cartas jogadas.
--   2. Efeitos de *trigger* — disparam em eventos ("attack", "defend", "turn_start").
-- Todos os efeitos são data-driven: leem `card.effects` (já injetado por CardDatabase:createCardInstance).

local EffectSystem = {}
EffectSystem.__index = EffectSystem

local I18n = require("src.i18n.I18n")
-- Helper local: mensagem traduzida via messages.<key>, com vars injetadas.
local function msg(key, vars) return I18n.t("messages." .. key, vars) end

function EffectSystem:new()
    return setmetatable({}, EffectSystem)
end

-- ==============================================================================
-- Efeitos contínuos de jokers (chamados ao jogar uma carta de ataque/defesa).
-- ==============================================================================

function EffectSystem:applyJokerEffects(game, card, baseValue)
    local finalValue = baseValue
    local msgs = {}

    for _, joker in ipairs(game.jokerSlots) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                local newValue, msg = self:processEffect(effect, card, finalValue)
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
function EffectSystem:processEffect(effect, card, currentValue)
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
        -- value é o nome do debuff (ex: "weak", "vulnerable", "poison"), stacks é duração.
        local debuff = { name = effect.value or "debuff", duration = effect.stacks or 1 }
        game.enemy:addStatusEffect(debuff)
        game:addMessage(msg("debuff_applied", { name = debuff.name, duration = debuff.duration }), "warning")
        return true

    elseif t == "discard_cards" then
        -- Descarta N cartas aleatórias da mão.
        for _ = 1, v do
            if #game.hand > 0 then
                table.remove(game.hand, love.math.random(#game.hand))
            end
        end
        game:addMessage(msg("discarded", { value = v }), "info")
        return true
    end

    -- Tipos conhecidos mas não implementados (orbes, força, etc.) — loga e retorna false
    -- para que o fallback exiba a descrição.
    if t == "channel_orb" or t == "evoke_orb" or t == "strength_scaling"
        or t == "exhaust" or t == "innate" then
        return false
    end

    return false
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
