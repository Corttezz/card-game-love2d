-- src/systems/EffectSystem.lua
-- Sistema modular de efeitos de cartas

local EffectSystem = {}
EffectSystem.__index = EffectSystem

function EffectSystem:new()
    local instance = setmetatable({}, EffectSystem)
    return instance
end

-- Aplica efeitos de jokers baseado nos dados da carta
function EffectSystem:applyJokerEffects(game, card, baseValue)
    local finalValue = baseValue
    local effectsApplied = {}
    
    -- Percorre todos os jokers ativos
    for _, joker in ipairs(game.jokerSlots) do
        local jokerData = self:getCardData(joker)
        
        if jokerData and jokerData.effects then
            for _, effect in ipairs(jokerData.effects) do
                local newValue, effectMsg = self:processEffect(effect, card, finalValue)
                if newValue ~= finalValue then
                    finalValue = newValue
                    if effectMsg then
                        table.insert(effectsApplied, effectMsg)
                    end
                end
            end
        end
    end
    
    -- Mostra mensagens dos efeitos aplicados
    for _, effectMsg in ipairs(effectsApplied) do
        game:addMessage(effectMsg, "info")
    end
    
    return finalValue
end

-- Processa um efeito específico
function EffectSystem:processEffect(effect, card, currentValue)
    local effectType = effect.type
    local effectValue = effect.value or 1
    local effectTarget = effect.target
    
    -- Multipliers de dano
    if effectType == "damage_multiplier" and effectTarget == "attack" and card.type == "attack" then
        return currentValue * effectValue, "Dano multiplicado por " .. effectValue
        
    -- Multipliers de defesa  
    elseif effectType == "defense_multiplier" and effectTarget == "defense" and card.type == "defense" then
        return currentValue * effectValue, "Defesa multiplicada por " .. effectValue
        
    -- Bonus fixo de dano
    elseif effectType == "damage_bonus" and card.type == "attack" then
        return currentValue + effectValue, "+" .. effectValue .. " dano bônus"
        
    -- Bonus fixo de defesa
    elseif effectType == "defense_bonus" and card.type == "defense" then
        return currentValue + effectValue, "+" .. effectValue .. " defesa bônus"
    end
    
    -- Efeito não aplicável para esta carta
    return currentValue, nil
end

-- Aplica efeitos de "trigger" (quando algo acontece)
function EffectSystem:applyTriggerEffects(game, triggerType, context)
    for _, joker in ipairs(game.jokerSlots) do
        local jokerData = self:getCardData(joker)
        
        if jokerData and jokerData.effects then
            for _, effect in ipairs(jokerData.effects) do
                self:processTriggerEffect(game, effect, triggerType, context)
            end
        end
    end
end

-- Processa efeitos de trigger específicos
function EffectSystem:processTriggerEffect(game, effect, triggerType, context)
    local effectType = effect.type
    local effectValue = effect.value or 0
    
    -- Cura quando ataca
    if effectType == "on_attack_heal" and triggerType == "attack" then
        game.player:heal(effectValue)
        game:addMessage("Curou " .. effectValue .. " HP!", "success")
        
    -- Dano quando defende
    elseif effectType == "on_defend_damage" and triggerType == "defend" then
        if context and context.target then
            context.target:takeDamage(effectValue)
            game:addMessage("Dano reflexivo: " .. effectValue, "warning")
        end
        
    -- Regeneração por turno
    elseif effectType == "regen_per_turn" and triggerType == "turn_start" then
        game.player:heal(effectValue)
        game:addMessage("Regenerou " .. effectValue .. " HP", "success")
        
    -- Dano por turno
    elseif effectType == "damage_per_turn" and triggerType == "turn_start" then
        game.player:takeDamage(effectValue)
        game:addMessage("Perdeu " .. effectValue .. " HP", "warning")
    end
end

-- Busca dados da carta (placeholder - seria integrado com CardDatabase)
function EffectSystem:getCardData(card)
    -- Esta função seria integrada com o CardDatabase
    -- Por enquanto, retorna dados mock baseados no nome
    if card.name == "God of the Abyss" then
        return {
            effects = {
                {type = "damage_multiplier", target = "attack", value = 2.0}
            }
        }
    elseif card.name == "Shield Master" then
        return {
            effects = {
                {type = "defense_multiplier", target = "defense", value = 1.5}
            }
        }
    elseif card.name == "Vampire Lord" then
        return {
            effects = {
                {type = "on_attack_heal", value = 3}
            }
        }
    end
    
    return nil
end

-- Registra novos tipos de efeitos (extensibilidade)
function EffectSystem:registerEffect(effectType, processor)
    -- Permite adicionar novos efeitos dinamicamente
    -- Útil para mods ou expansões
end

return EffectSystem

