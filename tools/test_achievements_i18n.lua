local TK = require("tools.testkit")

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

local MATH_SIGNS = { [151] = true, [183] = true }
local function hasAccent(str)
    local i = str:find("\195", 1, true)
    while i do
        local nxt = str:byte(i + 1)
        if not (nxt and MATH_SIGNS[nxt]) then return true end
        i = str:find("\195", i + 1, true)
    end
    return false
end

local function distinctCount(list)
    local seen, n = {}, 0
    for _, v in ipairs(list) do
        if not seen[v] then seen[v] = true; n = n + 1 end
    end
    return n
end

function M.run()
    TK.bootstrap()
    local t = TK.new("conquistas: i18n nos 5 idiomas")

    local I18n = require("src.i18n.I18n")
    local Defs = require("src.data.achievements")
    local entry = I18n.getLocale()

    t:truthy("catálogo tem conquistas (" .. #Defs .. ")", #Defs >= 20)

    local missing, notTranslated, accented = {}, {}, {}
    local nameDiffPtEn, descDiffPtEn = 0, 0

    for _, d in ipairs(Defs) do
        local names, descs = {}, {}
        for _, loc in ipairs(LOCALES) do
            I18n.setLocale(loc)
            local n = I18n.t("achievements.list." .. d.id .. ".name", nil, "__MISS__")
            local s = I18n.t("achievements.list." .. d.id .. ".desc", nil, "__MISS__")
            if n == "__MISS__" or s == "__MISS__" then
                table.insert(missing, d.id .. " (" .. loc .. ")")
                n, s = "", ""
            end
            if loc ~= "pt_BR" and loc ~= "en" and (hasAccent(n) or hasAccent(s)) then
                accented[loc] = true
            end
            names[#names + 1] = n
            descs[#descs + 1] = s
        end

        if distinctCount(names) < 2 then
            table.insert(notTranslated, d.id .. " (name)")
        end
        if distinctCount(descs) < 2 then
            table.insert(notTranslated, d.id .. " (desc)")
        end
        if names[1] ~= names[2] then nameDiffPtEn = nameDiffPtEn + 1 end
        if descs[1] ~= descs[2] then descDiffPtEn = descDiffPtEn + 1 end
    end

    I18n.setLocale(entry)

    if #missing > 0 then
        print("\n  Sem chave i18n:")
        for _, m in ipairs(missing) do print("    " .. m) end
    end
    t:eq("toda conquista tem name+desc nos 5 locales", #missing, 0)

    if #notTranslated > 0 then
        print("\n  Mesmo texto nos 5 idiomas (traduzir de verdade):")
        for _, m in ipairs(notTranslated) do print("    " .. m) end
    end
    t:eq("nenhum texto repetido igual nos 5 idiomas", #notTranslated, 0)

    for _, loc in ipairs({ "es", "fr", "de" }) do
        t:truthy("conquistas em " .. loc .. " são acentuadas (não transliteradas)", accented[loc])
    end

    t:truthy(("maioria dos nomes difere pt_BR vs en (%d/%d)")
        :format(nameDiffPtEn, #Defs), nameDiffPtEn >= math.floor(#Defs * 0.7))
    t:truthy(("descrições diferem pt_BR vs en (%d/%d)")
        :format(descDiffPtEn, #Defs), descDiffPtEn == #Defs)

    local AchievementSystem = require("src.systems.AchievementSystem")
    I18n.setLocale("de")
    local all = AchievementSystem.all()
    local first
    for _, a in ipairs(all) do
        if a.id == "primeira_pagina" then first = a end
    end
    I18n.setLocale(entry)
    t:truthy("AchievementSystem.all devolve texto traduzido", first ~= nil)
    if first then
        t:eq("all() em de traduz o nome", first.name, "Erste Seite")
        t:truthy("all() em de traduz a descrição",
            first.desc ~= Defs[1].desc and first.desc ~= "")
    end

    return t:done()
end

return M
