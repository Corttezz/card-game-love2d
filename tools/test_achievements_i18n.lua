-- tools/test_achievements_i18n.lua
-- As 20 conquistas estão traduzidas DE VERDADE nos 5 idiomas.
--
-- POR QUE NÃO BASTA O test_i18n
-- Paridade de chave só prova que a chave EXISTE. Copiar a string portuguesa
-- para os cinco locales passa na paridade e continua errado na tela — foi
-- exatamente o risco que o assert do `smoke_acts` passou a cobrir para os
-- nomes de ato. Com 20 conquistas × 2 campos × 5 idiomas o risco cresce, e
-- conferir no olho não escala.
--
-- O QUE ESTE TESTE EXIGE
--   1. toda conquista tem name + desc em TODOS os locales (nada de cair no
--      fallback do catálogo);
--   2. o texto MUDA entre idiomas — pelo menos 2 valores distintos entre os 5
--      (permite acerto legítimo tipo "Miasma" em pt/en/es, que ainda difere de
--      "Miasme" em fr);
--   3. a maioria dos nomes é de fato distinta entre pt_BR e en (guarda contra
--      alguém colar o bloco PT inteiro num locale novo);
--   4. acento SÓ em pt_BR — de/es/fr seguem a transliteração ASCII do projeto.
--
--   love . test_one test_achievements_i18n
--   love . test_all

local TK = require("tools.testkit")

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

-- Tem byte de acentuação latina? (0xC3 + segundo byte; × e ÷ não contam)
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
            -- Acento só no pt_BR (convenção dos locales do projeto).
            if loc ~= "pt_BR" and (hasAccent(n) or hasAccent(s)) then
                table.insert(accented, d.id .. " (" .. loc .. ")")
            end
            names[#names + 1] = n
            descs[#descs + 1] = s
        end

        -- Texto tem que MUDAR entre idiomas, não ser o PT copiado 5x.
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

    if #accented > 0 then
        print("\n  Acento fora do pt_BR (de/es/fr usam ASCII no projeto):")
        for _, m in ipairs(accented) do print("    " .. m) end
    end
    t:eq("acento só no pt_BR", #accented, 0)

    -- Guarda contra "colei o bloco PT no locale novo": a maioria dos NOMES
    -- tem de diferir entre pt_BR e en. Alguns coincidem de verdade
    -- ("Miasma", "Asceta"), por isso é maioria e não totalidade.
    t:truthy(("maioria dos nomes difere pt_BR vs en (%d/%d)")
        :format(nameDiffPtEn, #Defs), nameDiffPtEn >= math.floor(#Defs * 0.7))
    t:truthy(("descrições diferem pt_BR vs en (%d/%d)")
        :format(descDiffPtEn, #Defs), descDiffPtEn == #Defs)

    -- E o caminho REAL de exibição (AchievementSystem.all) tem que devolver o
    -- texto traduzido — não o fallback do catálogo.
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
