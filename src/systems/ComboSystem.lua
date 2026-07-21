-- src/systems/ComboSystem.lua
-- Detecta sinergias entre cartas jogadas no mesmo turno, gerando multiplicadores
-- e bonus que o EffectSystem aplica antes dos jokers.
--
-- Contrato:
--   ComboSystem.detect(turnContext) -> { combo1, combo2, ... }
--   Cada combo tem { id, rule, matches (lista de cartas) }
--   ComboSystem.applyToCardValue(card, baseValue, turnContext, targetType) -> novoValor
--     targetType e "attack" ou "defense". So aplica combos cujo bonus match.
--
-- RULES sao dataDRiven: adicionar novas regras e so acrescentar uma entrada.
-- Tipos de regra suportados:
--   "min_count_tag"   — N+ cartas com a tag
--   "pair_tags"       — cartas cobrindo todas as tags em `requires`
--
-- Tipos de bonus suportados:
--   "damage_multiplier"  — multiplica dano em ataques
--   "defense_multiplier" — multiplica defesa em defesas
--   "damage_bonus"       — soma dano fixo em ataques
--   "defense_bonus"      — soma defesa fixa em defesas
--   "apply_debuff"       — aplica debuff no inimigo apos resolver cartas
--   "heal"               — cura player

local TagSystem = require("src.systems.TagSystem")
local Sfx = require("src.systems.Sfx")

local ComboSystem = {}

-- Regras ativas. Ordem importa: combos superiores no pipeline aplicam antes.
-- id tambem serve de chave i18n (messages.combo.<id>) no futuro.
ComboSystem.RULES = {
    { id = "strike_combo",
      rule = "min_count_tag", tag = "strike", minCount = 2,
      bonus = { type = "damage_multiplier", value = 1.4 },
      label = "Combo de Ataques" },

    { id = "defend_wall",
      rule = "min_count_tag", tag = "defend", minCount = 2,
      bonus = { type = "defense_multiplier", value = 1.4 },
      label = "Muralha" },

    { id = "triple_strike",
      rule = "min_count_tag", tag = "strike", minCount = 3,
      bonus = { type = "damage_bonus", value = 6 },
      label = "Triplo Golpe" },

    { id = "armor_tower",
      rule = "min_count_tag", tag = "armor", minCount = 2,
      bonus = { type = "defense_bonus", value = 6 },
      label = "Torre de Armaduras" },

    { id = "poison_stack",
      rule = "min_count_tag", tag = "poison", minCount = 2,
      bonus = { type = "apply_debuff", debuff = "poison", stacks = 2, duration = 2 },
      label = "Veneno Concentrado" },

    { id = "channel_burst",
      rule = "min_count_tag", tag = "channel", minCount = 3,
      bonus = { type = "evoke_on_combo", value = 1 },
      label = "Explosao Arcana" },

    { id = "cycle_motion",
      rule = "pair_tags", requires = { "draw", "discard" },
      -- Rebalance v2 (Jul/2026, P1.2): +3 -> +5 (warrior/rogue ganharam
      -- massa de draw+discard; o combo precisava pagar o setup).
      bonus = { type = "damage_bonus", value = 5 },
      label = "Em Movimento" },

    { id = "finisher_chain",
      rule = "pair_tags", requires = { "strike", "finisher" },
      bonus = { type = "damage_multiplier", value = 1.3 },
      label = "Remate" },

    { id = "lifesteal_burst",
      rule = "pair_tags", requires = { "strike", "lifesteal" },
      bonus = { type = "heal", value = 4 },
      label = "Ferida Vital" },

    { id = "magic_focus",
      rule = "min_count_tag", tag = "magic", minCount = 2,
      bonus = { type = "damage_multiplier", value = 1.5 },
      -- Rebalance v2 (Jul/2026, P1.1): label renomeado ('Foco Arcano' colidia
      -- com o nome da carta mage_arcane_focus).
      label = "Convergencia Arcana" },

    { id = "thorn_reflex",
      rule = "pair_tags", requires = { "defend", "thorn" },
      -- Rebalance v2 (Jul/2026, P1.2): +4 -> +6 (agora ha massa critica de
      -- thorn em CARTA: Escudo de Espinhos + thorn_cloak + flame_barrier).
      bonus = { type = "defense_bonus", value = 6 },
      label = "Reflexos Espinhados" },

    -- Rebalance v2 (Jul/2026, P1.3): combos elementais novos — payoff das
    -- tags lightning/ice (ja no CATALOG) pro Canalizador do mago.
    { id = "tempestade",
      rule = "min_count_tag", tag = "lightning", minCount = 2,
      bonus = { type = "damage_bonus", value = 5 },
      label = "Tempestade" },

    { id = "zero_absoluto",
      rule = "min_count_tag", tag = "ice", minCount = 2,
      bonus = { type = "defense_bonus", value = 5 },
      label = "Zero Absoluto" },
}

-- Avalia se uma regra dispara dado um turnContext (com tagCounts).
local function ruleMatches(rule, turnContext)
    if rule.rule == "min_count_tag" then
        local count = (turnContext.tagCounts and turnContext.tagCounts[rule.tag]) or 0
        return count >= (rule.minCount or 2)
    elseif rule.rule == "pair_tags" then
        -- Balance v2 (Jul/2026): as tags precisam vir de CARTAS DISTINTAS.
        -- Antes, uma carta com strike+finisher se auto-combinava ×1.3
        -- sozinha (todo finisher tinha premium fantasma embutido).
        local req = rule.requires or {}
        local snapshot = turnContext.allSelectedCards or turnContext.snapshot or {}
        local TagSystem = require("src.systems.TagSystem")
        -- tenta uma atribuição: para cada tag exigida, uma carta diferente.
        local function assign(tagIdx, usedCards)
            if tagIdx > #req then return true end
            for ci, card in ipairs(snapshot) do
                if not usedCards[ci]
                    and TagSystem.cardHasTag(card, req[tagIdx]) then
                    usedCards[ci] = true
                    if assign(tagIdx + 1, usedCards) then return true end
                    usedCards[ci] = nil
                end
            end
            return false
        end
        return assign(1, {})
    end
    return false
end

-- Detecta combos ativos dado um turnContext. Retorna lista de { id, rule, bonus, label }.
-- Efeito colateral: anexa em turnContext.activeCombos (idempotente se chamado 2x).
function ComboSystem.detect(turnContext)
    turnContext.activeCombos = turnContext.activeCombos or {}
    if not turnContext.tagCounts then return turnContext.activeCombos end
    -- Limpa deteccao anterior se for re-chamada
    for i = #turnContext.activeCombos, 1, -1 do
        turnContext.activeCombos[i] = nil
    end
    for _, rule in ipairs(ComboSystem.RULES) do
        if ruleMatches(rule, turnContext) then
            table.insert(turnContext.activeCombos, rule)
        end
    end
    return turnContext.activeCombos
end

-- Aplica combos de valor (damage_*/defense_*) sobre um valor base para uma carta.
-- Chamado pelo Game:processCardInCombat depois do applyCardEffects e ANTES dos jokers.
-- Isso garante que jokers com multiplicador multipliquem o valor ja potencializado.
function ComboSystem.applyToCardValue(card, baseValue, turnContext)
    if not turnContext or not turnContext.activeCombos then return baseValue end
    local v = baseValue
    for _, combo in ipairs(turnContext.activeCombos) do
        local b = combo.bonus
        if b then
            if card.type == "attack" then
                if b.type == "damage_multiplier" then
                    v = v * (b.value or 1)
                elseif b.type == "damage_bonus" then
                    v = v + (b.value or 0)
                end
            elseif card.type == "defense" then
                if b.type == "defense_multiplier" then
                    v = v * (b.value or 1)
                elseif b.type == "defense_bonus" then
                    v = v + (b.value or 0)
                end
            end
        end
    end
    return v
end

-- Aplica combos de EVENTO (debuff/heal/evoke) uma unica vez por turno (chamado
-- apos todas as cartas do turno ja terem sido processadas). turnContext carrega
-- activeCombos; game e usado para efeitos colaterais.
function ComboSystem.applyOnceEffects(game, turnContext)
    if not turnContext or not turnContext.activeCombos then return end
    for _, combo in ipairs(turnContext.activeCombos) do
        local b = combo.bonus
        if b then
            if b.type == "apply_debuff" and game.enemy then
                game.enemy:addStatusEffect({
                    name = b.debuff or "poison",
                    stacks = b.stacks or 1,
                    duration = b.duration or 2,
                })
                game:addMessage("Combo " .. (combo.label or combo.id) .. ": +"
                    .. (b.stacks or 1) .. " " .. (b.debuff or "debuff"), "warning")
            elseif b.type == "heal" and game.player then
                -- P2.5 (Jul/2026, rebalance v2): heal de combo roteia pelo
                -- heal_multiplier (com floor via P2.4) — sem isso Calice do
                -- Sabio/dark_embrace nao amplificavam o lifesteal_burst.
                local amount = b.value or 0
                if game.effectSystem and game.effectSystem.applyHealMultiplier then
                    amount = game.effectSystem:applyHealMultiplier(game, amount)
                end
                game.player:heal(amount)
                game:addMessage("Combo " .. (combo.label or combo.id) .. ": +"
                    .. amount .. " HP", "success")
            elseif b.type == "evoke_on_combo" then
                -- Evoca 1 orb extra ao fim do turno
                local orb = game.player:popOldestOrb()
                if orb and game.effectSystem then
                    game.effectSystem:_evokeOrbEffect(game, orb)
                    game:addMessage("Combo " .. (combo.label or combo.id)
                        .. ": orb bonus evocado", "success")
                end
            end
        end
    end
end

-- Toast inicial ao detectar combos. Chamado por Game:playSelectedCards uma vez.
function ComboSystem.announce(game, turnContext)
    if not turnContext.activeCombos or #turnContext.activeCombos == 0 then return end
    for _, combo in ipairs(turnContext.activeCombos) do
        game:addMessage("COMBO! " .. (combo.label or combo.id), "success")
    end
    Sfx.play("comboTrigger")
end

return ComboSystem
