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
local CardArtAtlas = require("src.data.card_art")
local PixelIcons = require("src.ui.PixelIcons")

local M = {}

-- ---------------------------------------------------------------------------
-- Trava de arte (2026-09): a arte da carta vem do atlas `src/data/card_art.lua`,
-- NAO do campo legado `image`. Carta sem entrada no atlas cai no fallback por
-- tipo do CardArt.resolve e passa a dividir o mesmo icone com todas as outras
-- cartas do mesmo tipo (foi assim que Adrenalina virou Pocao de Cura).
-- Estas checagens falham a suite pra impedir a regressao.
-- ---------------------------------------------------------------------------

-- Um nome de icone so e valido se existe PNG em assets/sprites/icons OU uma
-- matriz real em PixelIcons. PixelIcons.get devolve `question` pra nome
-- desconhecido, entao dois icones invalidos renderizariam iguais em silencio.
local function iconExists(name)
    if not name or name == "" then return false end
    if love.filesystem.getInfo("assets/sprites/icons/" .. name .. ".png") then
        return true
    end
    return PixelIcons[name] ~= nil
end

-- Retorna { missingEntry, duplicateIcons, brokenIcons, deadEntries }
local function auditCardArt(all)
    local missingEntry, brokenIcons, deadEntries = {}, {}, {}
    local iconToIds = {}

    for id, _ in pairs(all) do
        local entry = CardArtAtlas[id]
        if not entry then
            table.insert(missingEntry, id)
        else
            local icon = entry.icon
            if not iconExists(icon) then
                table.insert(brokenIcons, { id = id, icon = tostring(icon) })
            end
            iconToIds[icon] = iconToIds[icon] or {}
            table.insert(iconToIds[icon], id)
        end
    end

    -- Entradas do atlas que nao correspondem a nenhuma carta (lixo/typo).
    for id, _ in pairs(CardArtAtlas) do
        if not all[id] then table.insert(deadEntries, id) end
    end

    local duplicateIcons = {}
    for icon, ids in pairs(iconToIds) do
        if #ids > 1 then
            table.sort(ids)
            table.insert(duplicateIcons, { icon = icon, ids = ids })
        end
    end

    table.sort(missingEntry)
    table.sort(deadEntries)
    table.sort(duplicateIcons, function(a, b) return a.icon < b.icon end)
    table.sort(brokenIcons, function(a, b) return a.id < b.id end)

    return missingEntry, duplicateIcons, brokenIcons, deadEntries
end

-- Tipos de effect.type que o EffectSystem resolve (fase 2+).
-- Mantenha em sync com src/systems/EffectSystem.lua.
local PROCESSED_EFFECT_TYPES = {
    -- jokers / card-effects
    damage_multiplier = true, defense_multiplier = true,
    damage_bonus = true, defense_bonus = true,
    strength_scaling = true, dexterity_scaling = true,
    multi_hit = true, damage_bonus_self = true,
    -- card passives
    instant_heal = true, self_damage = true, strength_per_turn = true,
    retain_armor = true,
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
    -- P2.1 (Jul/2026, rebalance v2): trigger turn_start que canaliza orbe
    -- (mage_electrodynamics). Ver EffectSystem:processTriggerEffect.
    channel_per_turn = true,
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

    -- ===== Trava de arte =====
    local missingArt, dupIcons, brokenIcons, deadEntries = auditCardArt(all)

    print("\n-- cards WITHOUT card_art atlas entry (" .. #missingArt .. ") --")
    for _, id in ipairs(missingArt) do
        print("  " .. id .. "  <- cai no fallback por tipo, arte VAI repetir")
    end

    print("\n-- icons shared by 2+ cards (" .. #dupIcons .. ") --")
    for _, d in ipairs(dupIcons) do
        print("  " .. d.icon .. " -> " .. table.concat(d.ids, ", "))
    end

    print("\n-- atlas entries with unresolvable icon (" .. #brokenIcons .. ") --")
    for _, b in ipairs(brokenIcons) do
        print("  " .. b.id .. " -> '" .. b.icon .. "' (sem PNG e sem matriz)")
    end

    print("\n-- atlas entries without a matching card (" .. #deadEntries .. ") --")
    for _, id in ipairs(deadEntries) do print("  " .. id) end

    local artOk = #missingArt == 0 and #dupIcons == 0
                  and #brokenIcons == 0 and #deadEntries == 0

    print("\n==== Done ====")
    if not artOk then
        print("FALHOU: arte de carta. Toda carta precisa de entrada propria em "
            .. "src/data/card_art.lua e de um icone que nao seja usado por "
            .. "outra carta.")
    end
    return #report.unknownTypes == 0 and artOk
end

return M
