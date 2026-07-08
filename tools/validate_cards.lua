-- tools/validate_cards.lua
-- Validacao ofline do catalogo de cartas. Roda via:
--   love . validate_cards
-- Checa:
--   - Toda carta tem tags (array nao-vazio apos normalizacao) e deriva do tipo
--   - Todo effect.type e processado pelo EffectSystem (ou e placeholder conhecido)
--   - Histograma custo x raridade x classe
--   - Cartas com effects = {} (vazio) sao listadas como debito

local CardDatabase = require("src.systems.CardDatabase")
local TagSystem = require("src.systems.TagSystem")

local M = {}

-- Tipos de effect.type que o EffectSystem resolve (fase 2+).
-- Mantenha em sync com src/systems/EffectSystem.lua.
local PROCESSED_EFFECT_TYPES = {
    -- jokers / card-effects
    damage_multiplier = true, defense_multiplier = true,
    damage_bonus = true, defense_bonus = true,
    strength_scaling = true, dexterity_scaling = true,
    multi_hit = true, damage_bonus_self = true,
    -- card passives
    instant_heal = true, self_damage = true,
    restore_mana = true, increase_max_mana = true,
    add_armor = true, magic_damage = true, draw_cards = true,
    apply_debuff = true, apply_buff = true,
    discard_cards = true,
    gain_strength = true, gain_dexterity = true,
    channel_orb = true, evoke_orb = true, evoke_all_orbs = true,
    aoe_magic_damage = true, mystery = true,
    exhaust = true, innate = true, retain = true,
    -- triggers (jokers)
    on_attack_heal = true, on_defend_damage = true,
    on_attack_debuff = true, on_turn_start_draw = true,
    regen_per_turn = true, damage_per_turn = true,
    heal_multiplier = true,
    -- Removidos: tag_observer_multiplier / tag_stack_bonus (declarados em
    -- versão anterior do plano combo-aware mas nunca implementados em
    -- EffectSystem). Reintroduzir só quando algum joker realmente precisar.
}

function M.run()
    local db = CardDatabase:new()
    local all = db:getAllCards()

    local report = {
        total = 0,
        byClass = {},       -- class -> count
        byRarity = {},      -- rarity -> count
        emptyEffects = {},  -- lista de IDs com effects={}
        unknownTypes = {},  -- lista de { id, type }
        missingImplicitTag = {}, -- IDs onde tags nao serao derivadas
        histogram = {},     -- rarity x cost
    }

    for id, card in pairs(all) do
        report.total = report.total + 1
        local cls = card.class or "_none"
        report.byClass[cls] = (report.byClass[cls] or 0) + 1
        local rar = card.rarity or "_none"
        report.byRarity[rar] = (report.byRarity[rar] or 0) + 1

        -- histograma rarity+cost
        local key = rar .. ":cost" .. tostring(card.cost or 0)
        report.histogram[key] = (report.histogram[key] or 0) + 1

        -- empty effects
        if type(card.effects) == "table" and #card.effects == 0
           and card.type ~= "attack" and card.type ~= "defense" then
            -- attack/defense podem legitimamente ser "so dano" se stats sao balanceados
            table.insert(report.emptyEffects, id)
        elseif type(card.effects) == "table" and #card.effects == 0
               and (card.type == "attack" or card.type == "defense") then
            -- Lista separada: debito de "so dano base" sem efeito sinergico
            table.insert(report.emptyEffects, id .. " (" .. card.type .. " vazio)")
        end

        -- unknown effect types
        if card.effects then
            for _, e in ipairs(card.effects) do
                if e.type and not PROCESSED_EFFECT_TYPES[e.type] then
                    table.insert(report.unknownTypes, { id = id, type = e.type })
                end
            end
        end

        -- tags derivadas
        local tags = TagSystem.getCardTags(card)
        if #tags == 0 then table.insert(report.missingImplicitTag, id) end
    end

    -- Print report
    print("==== Card Catalog Validation ====")
    print("TOTAL: " .. report.total)

    print("\n-- by class --")
    for cls, n in pairs(report.byClass) do print(string.format("  %-10s %d", cls, n)) end

    print("\n-- by rarity --")
    for r, n in pairs(report.byRarity) do print(string.format("  %-10s %d", r, n)) end

    print("\n-- empty effects (" .. #report.emptyEffects .. ") --")
    local showCount = math.min(30, #report.emptyEffects)
    for i = 1, showCount do print("  " .. report.emptyEffects[i]) end
    if #report.emptyEffects > showCount then
        print("  ... +" .. (#report.emptyEffects - showCount) .. " more")
    end

    print("\n-- unknown effect types (" .. #report.unknownTypes .. ") --")
    for _, u in ipairs(report.unknownTypes) do
        print("  " .. u.id .. " -> " .. u.type)
    end

    print("\n-- cards without derivable tags (" .. #report.missingImplicitTag .. ") --")
    for _, id in ipairs(report.missingImplicitTag) do print("  " .. id) end

    print("\n==== Done ====")
    return #report.unknownTypes == 0
end

return M
