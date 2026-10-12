-- tools/test_locale_accents.lua
-- Acento de verdade nos 5 idiomas (Out/2026).
--
-- Três defeitos da mesma família, todos invisíveis no código e óbvios na
-- tela de quem joga em outro idioma:
--   1. A fonte (Press Start 2P) desenhava as MAIÚSCULAS acentuadas como uma
--      letra encolhida com acento na mesma célula: "CRÉDITOS" saía
--      "CRéDITOS". O remédio foi redesenhar os glifos (tools/font_latin_caps.py);
--      aqui medimos os pixels: a maiúscula acentuada contém a letra base
--      INTEIRA e o acento fica FORA dela.
--   2. Os locales misturavam texto acentuado e transliterado ("Forca",
--      "dano" em espanhol, "degats", "fuer"/"Staerke"). Lista de ASCII-ismos
--      conhecidos por idioma: se voltar, falha.
--   3. O glossário de palavras-chave do tooltip era português em todo idioma.
--      Cada verbete precisa casar a sua carta-exemplo em cada idioma e mostrar
--      nome/texto traduzidos.
--
-- Roda: love . test_one test_locale_accents

local M = {}
local TK = require("tools.testkit")

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

-- Palavras que NUNCA devem aparecer num texto do locale (comparação por
-- palavra inteira, sem diferenciar caixa). Cada uma já apareceu de verdade.
local ASCIIISMS = {
    pt_BR = { "nao", "voce", "forca", "pocao", "lamina", "resistencia", "inicio",
              "aleatoria", "aleatorio", "vulneravel", "magico", "ate", "maxima",
              "nivel", "configuracoes", "arquetipo", "colecao", "ultimo", "sao",
              "mao", "furia", "explosao", "coracao", "rapido", "misterio",
              "precisao", "tambem", "entao", "acao", "pagina", "paginas",
              "retencao", "comeca", "relatorio", "taticas", "unicas",
              "jokers", "the rock", "blood sword", "iron shield", "endless",
              "run nova", "a run" },
    es    = { "dano", "travesia", "debil", "comodin", "maximo", "magico",
              "corazon", "pagina", "relampago", "menu", "despues", "aqui",
              "atras", "ultima", "ningun", "pocion", "explosion", "musica",
              "configuracion", "tambien", "maestria", "picaro", "volumenes",
              "jokers", "endless", "la run" },
    fr    = { "degats", "debut", "epuiser", "defense", "epines", "periple",
              "dexterite", "premiere", "meme", "vulnerable", "maitrise",
              "maitre", "inne", "fleches", "etage", "tempete", "deja", "etre",
              "ete", "ecran", "video", "probleme", "succes", "defausse",
              "echap", "evoque", "jusqu a", "parametres", "endless", "la run" },
    de    = { "fuer", "zuege", "zuegen", "staerke", "erschoepfen", "zurueck",
              "waehlen", "ueber", "menue", "hauptmenue", "schwaeche",
              "zusaetzliche", "zufaellige", "zaehlt", "spaeter", "loescht",
              "koennen", "moechtest", "muessen", "run aufgeben", "endless" },
    en    = {},
}

-- Rótulos que só fazem sentido com a maiúscula acentuada desenhada.
local TITLES = {
    { "pt_BR", "settings.title", "CONFIGURAÇÕES" },
    { "pt_BR", "credits.title",  "CRÉDITOS" },
}

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

-- Palavra inteira (sem letra ASCII nem byte UTF-8 colado dos lados).
local function hasWord(lower, word)
    local from = 1
    while true do
        local i, j = lower:find(word, from, true)
        if not i then return false end
        local before = i > 1 and lower:sub(i - 1, i - 1) or " "
        local after = lower:sub(j + 1, j + 1)
        if after == "" then after = " " end
        if not before:match("[%a\128-\255]") and not after:match("[%a\128-\255]") then
            return true
        end
        from = i + 1
    end
end

-- Pixels acesos de um texto renderizado num canvas.
local function litPixels(font, text)
    local c = love.graphics.newCanvas(96, 96)
    love.graphics.push("all")
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print(text, 16, 32)
    love.graphics.pop()
    local data = c:newImageData()
    local set, top, bottom = {}, math.huge, -math.huge
    for y = 0, 95 do
        for x = 0, 95 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.5 then
                set[y * 96 + x] = true
                if y < top then top = y end
                if y > bottom then bottom = y end
            end
        end
    end
    return set, top, bottom
end

function M.run()
    TK.bootstrap()
    local t = TK.new("test_locale_accents")
    local I18n = require("src.i18n.I18n")
    local prevLocale = I18n.getLocale()

    -- ===== 1. Glifos das maiúsculas acentuadas =====
    local FontManager = require("src.ui.FontManager")
    local font = FontManager.getFont(16)
    local PAIRS = {
        { "A", "ÀÁÂÃÄÅ" }, { "E", "ÈÉÊË" }, { "I", "ÌÍÎÏ" }, { "O", "ÒÓÔÕÖ" },
        { "U", "ÙÚÛÜ" }, { "N", "Ñ" }, { "Y", "Ý" }, { "C", "Ç" },
    }
    local utf8 = require("utf8")
    local badFull, badAccent = {}, {}
    for _, pair in ipairs(PAIRS) do
        local base, btop, bbottom = litPixels(font, pair[1])
        for _, cp in utf8.codes(pair[2]) do
            local ch = utf8.char(cp)
            local acc, atop, abottom = litPixels(font, ch)
            -- a letra base inteira, nos mesmos pixels (nada encolhido)
            for k in pairs(base) do
                if not acc[k] then badFull[#badFull + 1] = ch; break end
            end
            -- o acento fica FORA da letra: acima (ou abaixo, na cedilha)
            local outside = (ch == "Ç") and (abottom > bbottom) or (atop < btop)
            if not outside then badAccent[#badAccent + 1] = ch end
        end
    end
    t:eq("maiúscula acentuada contém a letra base inteira (" .. table.concat(badFull, "") .. ")",
        #badFull, 0)
    t:eq("acento desenhado fora da letra, não dentro da célula (" .. table.concat(badAccent, "") .. ")",
        #badAccent, 0)

    -- ===== 2. ASCII-ismos por locale =====
    local TextCase = require("src.i18n.TextCase")
    for _, loc in ipairs(LOCALES) do
        local data = require("src.i18n.locales." .. loc)
        local entries = {}
        walk(data, loc, entries)
        local found = {}
        for _, e in ipairs(entries) do
            local lower = TextCase.lower(e.text:gsub("%b{}", " "))
            for _, w in ipairs(ASCIIISMS[loc] or {}) do
                if hasWord(lower, w) then
                    found[#found + 1] = e.path .. "  '" .. w .. "'"
                end
            end
        end
        for i = 1, math.min(#found, 15) do print("    " .. found[i]) end
        t:eq(loc .. ": textos transliterados (palavra sem acento conhecida)", #found, 0)
    end

    for _, row in ipairs(TITLES) do
        I18n.setLocale(row[1], true)
        t:eq(row[1] .. " " .. row[2], I18n.t(row[2]), row[3])
    end

    -- ===== 3. Glossário de keywords traduzido =====
    local Keywords = require("src.data.keywords")
    local CardInfoDisplay = require("src.ui.CardInfoDisplay")
    local SAMPLE = {
        orb_lightning = "mage_zap",        orb_ice   = "mage_chill",
        orb_fire      = "mage_fireball",   orb_holy  = "mage_healing_drop",
        orb_dark      = "mage_arcane_orb", orb       = "mage_consume",
        exhaust       = "warrior_feed",    poison    = "rogue_venom_coating",
        vulnerable    = "warrior_bash",    weak      = "rogue_neutralize",
        retain        = "warrior_kite_guard", innate = "mage_chill",
        block         = "warrior_defend",  focus     = "mage_arcane_focus",
        strength      = "warrior_inflame", dexterity = "warrior_inflame",
    }
    for _, kw in ipairs(Keywords) do
        t:truthy("keyword " .. kw.id .. " tem carta-exemplo", SAMPLE[kw.id])
    end
    local ptNames = {}
    I18n.setLocale("pt_BR", true)
    for _, kw in ipairs(Keywords) do ptNames[kw.id] = I18n.t("keyword." .. kw.id .. ".name") end
    for _, loc in ipairs(LOCALES) do
        I18n.setLocale(loc, true)
        local miss, noText = {}, {}
        for _, kw in ipairs(Keywords) do
            local name = I18n.t("keyword." .. kw.id .. ".name", nil, "")
            local text = I18n.t("keyword." .. kw.id .. ".text", nil, "")
            if name == "" or text == "" or name == "keyword." .. kw.id .. ".name" then
                noText[#noText + 1] = kw.id
            end
            local hits = CardInfoDisplay.collectKeywords(I18n.cardDesc(SAMPLE[kw.id] or ""))
            local okHit = false
            for _, h in ipairs(hits) do
                if h.id == kw.id and h.name == name then okHit = true end
            end
            if not okHit then miss[#miss + 1] = kw.id .. "<" .. tostring(SAMPLE[kw.id]) .. ">" end
        end
        t:eq(loc .. ": todo verbete tem nome e texto no locale (" .. table.concat(noText, ",") .. ")",
            #noText, 0)
        t:eq(loc .. ": todo verbete casa a carta-exemplo traduzida (" .. table.concat(miss, ",") .. ")",
            #miss, 0)
    end
    -- O nome exibido em alemão não pode ser o português (o defeito original).
    I18n.setLocale("de", true)
    local same = 0
    for _, kw in ipairs(Keywords) do
        if I18n.t("keyword." .. kw.id .. ".name") == ptNames[kw.id] then same = same + 1 end
    end
    t:check("glossário em alemão não é o português (" .. same .. " nomes iguais)", same <= 1)
    -- "fogo" sozinho não é orbe de Fogo; "gelo" dentro de "Congelar" não conta.
    I18n.setLocale("pt_BR", true)
    local h = CardInfoDisplay.collectKeywords("Barreira de Fogo: ganha Bloqueio.")
    local orbHit = false
    for _, x in ipairs(h) do if x.id:find("^orb") then orbHit = true end end
    t:falsy("pt: 'Fogo' sem contexto de orbe não puxa verbete de orbe", orbHit)

    I18n.setLocale(prevLocale, true)
    return t:done()
end

return M
