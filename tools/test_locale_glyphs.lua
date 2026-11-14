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
    local TextCase = require("src.i18n.TextCase")
    t:eq("upper com acento (fr)", TextCase.upper("légendaire"), "LÉGENDAIRE")
    t:eq("upper com acento (pt)", TextCase.upper("ação"), "AÇÃO")
    t:eq("upper com acento (de)", TextCase.upper("zurück"), "ZURÜCK")
    t:eq("upper ASCII intacto", TextCase.upper("Pegar"), "PEGAR")

    local HintBar = require("src.ui.HintBar")
    local utf8 = require("utf8")
    local bad = 0
    for w = 40, 400, 7 do
        local _, out = HintBar._fit("Ação ÉCHAP é longuíssimo é é é é é é é é é é é é é", w, { 8 })
        if not utf8.len(out) then bad = bad + 1 end
    end
    t:eq("truncar texto acentuado nunca gera UTF-8 invalido", bad, 0)

    -- circunflexo e til das minusculas descolados do corpo (tools/font_lower_accents.py):
    -- colado, o "â" de "Pântano" lia como "å" no titulo da cena do ato 5
    local okR, big = pcall(love.graphics.newFont, "assets/fonts/pixel.ttf", 64)
    if okR then
        local cv = love.graphics.newCanvas(96, 160)
        local function hasGap(ch)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(big)
            love.graphics.print(ch, 8, 40)
            love.graphics.setCanvas()
            local d = cv:newImageData()
            local w, h = d:getDimensions()
            local seenInk, inGap = false, false
            for y = 0, h - 1 do
                local on = false
                for x = 0, w - 1 do
                    local _, _, _, a = d:getPixel(x, y)
                    if a > 0.5 then on = true; break end
                end
                if on and not seenInk then seenInk = true
                elseif not on and seenInk then inGap = true
                elseif on and inGap then return true end
            end
            return false
        end
        for _, ch in ipairs({ "â", "ê", "î", "ô", "û", "ã", "õ", "ñ" }) do
            t:truthy("'" .. ch .. "': acento separado da letra por uma linha vazia", hasGap(ch))
        end
        t:falsy("sonda: 'a' sem acento nao tem linha vazia (prova que a medida funciona)", hasGap("a"))
    else
        t:truthy("rasterizador da fonte do jogo", false)
    end
    return t:done()
end

return M
