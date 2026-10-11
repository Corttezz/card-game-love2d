-- tools/test_locale_glyphs.lua
-- Todo caractere de TODO texto dos 5 locales existe na fonte do jogo?
--
-- Glifo ausente no Press Start 2P não dá erro: a LÖVE desenha um vazio (ou
-- um quadrado) e a frase sai com buraco — "¿Salir del juego?" virando
-- " Salir del juego?". Ninguém percebe olhando código; só o jogador de
-- espanhol/alemão/francês percebe, na tela. Esta trava percorre as tabelas
-- inteiras e pergunta à fonte REAL (`Font:hasGlyphs`) caractere por caractere.
--
-- Roda: love . test_one test_locale_glyphs

local M = {}
local TK = require("tools.testkit")

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

local function walk(tbl, path, out)
    for k, v in pairs(tbl) do
        local p = path .. "." .. tostring(k)
        if type(v) == "string" then
            out[#out + 1] = { path = p, text = v }
        elseif type(v) == "table" then
            walk(v, p, out)
        end
    end
end

-- Itera codepoints UTF-8 (a fonte é consultada por caractere, não por byte).
local function chars(s)
    local utf8 = require("utf8")
    local list = {}
    local ok = pcall(function()
        for _, c in utf8.codes(s) do list[#list + 1] = utf8.char(c) end
    end)
    return ok and list or nil
end

function M.run()
    TK.bootstrap()
    local t = TK.new("test_locale_glyphs")
    local FontManager = require("src.ui.FontManager")
    local font = FontManager.getFont(12)

    -- A sonda funciona? (sem isto um hasGlyphs sempre-true passaria verde)
    t:falsy("sonda: a fonte NAO tem ideograma (prova que hasGlyphs mede)",
        font:hasGlyphs("漢"))
    t:truthy("sonda: a fonte tem o basico", font:hasGlyphs("A"))

    local total, missing = 0, {}
    for _, loc in ipairs(LOCALES) do
        local data = require("src.i18n.locales." .. loc)
        local entries = {}
        walk(data, loc, entries)
        for _, e in ipairs(entries) do
            total = total + 1
            local cs = chars(e.text)
            if not cs then
                missing[#missing + 1] = e.path .. "  (UTF-8 INVALIDO)"
            else
                for _, ch in ipairs(cs) do
                    if ch ~= "\n" and not font:hasGlyphs(ch) then
                        missing[#missing + 1] = e.path .. "  sem glifo '" .. ch .. "'"
                        break
                    end
                end
            end
        end
    end

    t:check("varreu os 5 locales de verdade (" .. total .. " textos > 2000)", total > 2000)
    for i = 1, math.min(#missing, 40) do print("    " .. missing[i]) end
    t:eq("textos com caractere que a fonte NAO desenha (sai buraco na tela)", #missing, 0)
    return t:done()
end

return M
