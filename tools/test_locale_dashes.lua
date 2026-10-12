-- tools/test_locale_dashes.lua
-- Sem travessão nos textos do jogo (Out/2026).
--
-- Pedido do dono: "tira todos os travessões das falas do corvo, grita IA".
-- Vale pra TODO texto que o jogador lê: o travessão (—), o meia-risca (–) e o
-- hífen solto usado como travessão (" - ") viraram ponto, vírgula, dois-
-- pontos ou reticências, com a frase reescrita. Palavra composta com hífen
-- ("pós-jogo", "zlib-Lizenz") continua valendo: só o hífen ENTRE ESPAÇOS cai.
-- Faixa de número se escreve por extenso ("2 a 6", "2 to 6").
--
-- Varre as tabelas CARREGADAS (sub-locales entram pelo require do
-- principal), então comentário de arquivo não conta.
--
-- Roda: love . test_one test_locale_dashes

local M = {}
local TK = require("tools.testkit")

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

local function walk(t, path, out, seen)
    if seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
        local p = path .. "." .. tostring(k)
        if type(v) == "string" then
            if v:find("\226\128\148", 1, true) or v:find("\226\128\147", 1, true)
                or v:find(" - ", 1, true) then
                out[#out + 1] = p .. " = " .. v:sub(1, 90)
            end
        elseif type(v) == "table" then
            walk(v, p, out, seen)
        end
    end
end

function M.run()
    local t = TK.new("locales: sem travessão como pontuação")
    local total = 0
    for _, loc in ipairs(LOCALES) do
        package.loaded["src.i18n.locales." .. loc] = nil
        local data = require("src.i18n.locales." .. loc)
        local bad = {}
        walk(data, loc, bad, {})
        total = total + #bad
        for i = 1, math.min(5, #bad) do print("     " .. bad[i]) end
        t:eq(loc .. ": nenhum —, – ou ' - ' em texto do jogo", #bad, 0)
    end
    return t:done()
end

return M
