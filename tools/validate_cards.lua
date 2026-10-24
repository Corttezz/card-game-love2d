local CardDatabase = require("src.systems.CardDatabase")
local TagSystem = require("src.systems.TagSystem")
local CardArtAtlas = require("src.data.card_art")
local PixelIcons = require("src.ui.PixelIcons")

local M = {}

local function iconExists(name)
    if not name or name == "" then return false end
    if love.filesystem.getInfo("assets/sprites/icons/" .. name .. ".png") then
        return true
    end
    return PixelIcons[name] ~= nil
end

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

local PROCESSED_EFFECT_TYPES = {
    damage_multiplier = true, defense_multiplier = true,
    echo_first_attack = true,
    combo_boost = true,
    counter_debuff = true, counter_frost = true, counter_sight = true, counter_pierce = true,
    damage_bonus = true, defense_bonus = true,
    strength_scaling = true, dexterity_scaling = true,
    multi_hit = true, damage_bonus_self = true,
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
    on_attack_heal = true, on_defend_damage = true,
    on_attack_debuff = true, on_turn_start_draw = true,
    regen_per_turn = true, damage_per_turn = true,
    heal_multiplier = true,
    channel_per_turn = true,
    reveal_intent = true,
}

function M.run()
    local db = CardDatabase:new()
    local all = db:getAllCards()

    local report = {
        total = 0,
        byClass = {},
        byRarity = {},
        emptyEffects = {},
        unknownTypes = {},
        missingImplicitTag = {},
        histogram = {},
    }

    for id, card in pairs(all) do
        report.total = report.total + 1
        local cls = card.class or "_none"
        report.byClass[cls] = (report.byClass[cls] or 0) + 1
        local rar = card.rarity or "_none"
        report.byRarity[rar] = (report.byRarity[rar] or 0) + 1

        local key = rar .. ":cost" .. tostring(card.cost or 0)
        report.histogram[key] = (report.histogram[key] or 0) + 1

        if type(card.effects) == "table" and #card.effects == 0
           and card.type ~= "attack" and card.type ~= "defense" then
            table.insert(report.emptyEffects, id)
        elseif type(card.effects) == "table" and #card.effects == 0
               and (card.type == "attack" or card.type == "defense") then
            table.insert(report.emptyEffects, id .. " (" .. card.type .. " vazio)")
        end

        if card.effects then
            for _, e in ipairs(card.effects) do
                if e.type and not PROCESSED_EFFECT_TYPES[e.type] then
                    table.insert(report.unknownTypes, { id = id, type = e.type })
                end
            end
        end

        local tags = TagSystem.getCardTags(card)
        if #tags == 0 then table.insert(report.missingImplicitTag, id) end
    end

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

    local noAnim, noSig = {}, {}
    for id, card in pairs(all) do
        local entry = CardArtAtlas[id]
        local icon = entry and entry.icon
        if icon and not love.filesystem.getInfo(
                "assets/sprites/icons_anim/" .. icon .. "/frame_000.png") then
            table.insert(noAnim, id .. " (" .. icon .. ")")
        end
        if card.type == "joker" and not love.filesystem.getInfo(
                "audio/sfx/joker-sig/" .. id .. ".mp3") then
            table.insert(noSig, id)
        end
    end
    table.sort(noAnim); table.sort(noSig)
    print("\n-- cartas SEM icone animado (" .. #noAnim .. ") --")
    for _, x in ipairs(noAnim) do print("  " .. x) end
    print("\n-- coringas SEM assinatura sonora (" .. #noSig .. ") --")
    for _, x in ipairs(noSig) do print("  " .. x) end

    local artOk = #missingArt == 0 and #dupIcons == 0
                  and #brokenIcons == 0 and #deadEntries == 0
                  and #noAnim == 0 and #noSig == 0

    local cloneJokers = {}
    do
        local porSig = {}
        for id, card in pairs(all) do
            if card.type == "joker" and card.effects and #card.effects > 0 then
                local partes = {}
                for _, e in ipairs(card.effects) do
                    local campos = {}
                    for k, v in pairs(e) do
                        if k ~= "description" and type(v) ~= "table"
                            and type(v) ~= "function" then
                            campos[#campos + 1] = tostring(k) .. "=" .. tostring(v)
                        end
                    end
                    table.sort(campos)
                    partes[#partes + 1] = table.concat(campos, ",")
                end
                table.sort(partes)
                local sig = table.concat(partes, " | ")
                porSig[sig] = porSig[sig] or {}
                table.insert(porSig[sig], { id = id, class = card.class or "basic" })
            end
        end
        for sig, lista in pairs(porSig) do
            if #lista > 1 then
                for i = 1, #lista do
                    for j = i + 1, #lista do
                        local a, b = lista[i], lista[j]
                        if a.class == b.class
                            or a.class == "basic" or b.class == "basic" then
                            table.insert(cloneJokers,
                                { a = a.id, b = b.id, sig = sig })
                        end
                    end
                end
            end
        end
        table.sort(cloneJokers, function(x, y) return x.a < y.a end)
    end

    print("\n-- coringas CLONADOS ofertaveis na mesma run (" .. #cloneJokers .. ") --")
    for _, c in ipairs(cloneJokers) do
        print("  " .. c.a .. "  ==  " .. c.b .. "   [" .. c.sig .. "]")
    end

    print("\n==== Done ====")
    if not artOk then
        print("FALHOU: arte de carta. Toda carta precisa de entrada propria em "
            .. "src/data/card_art.lua, de um icone que nao seja usado por "
            .. "outra carta, de icone ANIMADO (icons_anim/) e, se coringa, "
            .. "de assinatura em audio/sfx/joker-sig/.")
    end
    if #cloneJokers > 0 then
        print("FALHOU: coringa clonado. Dois coringas que a MESMA run pode "
            .. "oferecer tem a mesma assinatura de efeito — como coringa nao "
            .. "tem custo nem stats, nao sobra decisao nenhuma entre eles. "
            .. "Reformule um (mude a MECANICA, nao so o numero).")
    end
    return #report.unknownTypes == 0 and artOk and #cloneJokers == 0
end

return M
