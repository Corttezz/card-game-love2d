-- tools/test_no_hardcoded_pt.lua
-- TRAVA contra português cravado em código de UI.
--
-- POR QUE ESTE TESTE EXISTE
-- Duas telas multilíngues saíram BILÍNGUES em produção porque metade do texto
-- vinha do i18n e a outra metade era literal PT no meio do desenho:
--   • `Config.Acts[n].name` → "AKT 1 — Catacumbas" no Roteiro (Set/2026)
--   • `RoundEvalScreen:_buildDynaTexts` → título PT com botão traduzido
-- Consertar as duas não impede a terceira. Isto impede.
--
-- O QUE ELE PEGA (e o que NÃO pega)
-- O sinal é a ACENTUAÇÃO: um literal com ç/ã/õ/é/á/í/ó/ú/â/ê/ô/à dentro de um
-- arquivo de código é quase sempre texto de jogador esquecido. É o mesmo sinal
-- que um humano usa ao varrer o repo, só que automatizado.
--
-- NÃO pega PT sem acento ("Batalha", "Loja", "Descanso"). Isso é limite
-- conhecido, não descuido: uma lista de palavras PT daria falso positivo em
-- identificador, nome de asset e chave de tabela. Quando um caso desses
-- aparecer, o jeito é adicionar a ocorrência à revisão manual — não afrouxar
-- a regra que funciona.
--
-- O QUE ELE IGNORA (legitimamente)
--   • comentários — PT é a convenção do projeto (CLAUDE.md §9);
--   • saída de dev: print / Debug.* / error / assert — ferramenta, não UI;
--   • o fallback de I18n.t(chave, vars, "texto PT") — esse é o padrão CERTO;
--   • os próprios locales e os tools.
--
--   love . test_one test_no_hardcoded_pt
--   love . test_all

local TK = require("tools.testkit")

local M = {}

-- Diretórios varridos (tudo que pode desenhar) + arquivos soltos.
local DIRS = {
    "components", "src/ui", "src/ui/card", "src/ui/card/components",
    "src/systems", "src/core", "src/data", "src/scenes", "engine",
}
local FILES = { "main.lua" }

-- Linhas com estes marcadores são saída de DEV, não texto de jogador.
local DEV_PATTERNS = {
    "print%s*%(", "Debug%.%w+%s*%(", "error%s*%(", "assert%s*%(",
    "io%.write", "love%.filesystem%.append",
    "warn%w*%s*%(",               -- warnOnce e afins (wrappers de Debug.warn)
    "return%s+%w+%s*,%s*\"",      -- par (ok, "motivo") — erro interno, não UI
}

-- Exceções auditadas. Cada entrada precisa de motivo — a lista é o registro de
-- "eu olhei e decidi", não um tapete pra empurrar sujeira.
local ALLOW = {
    ["src/data/decks.lua"] =
        "modo clássico (legado): decks estáticos nunca exibidos na UI de run",
    ["src/data/biomes.lua"] =
        "biomes[].name não é lido por ninguém — só o .id é usado (WorldRoad/Roteiro)",
    ["src/ui/PackThemes.lua"] =
        "território do agente de pacotes (PackOpenScreen/PackSleeve) — reportado, não editado",
    -- components/RestScreen.lua saiu daqui (Set/2026): a linha
    -- "Já no nível máximo" virou `rest.forge_capped` e o arquivo passa a
    -- varredura sem exceção. Exceção cumprida é exceção REMOVIDA — deixá-la
    -- aqui depois de resolvida transforma a lista de decisões auditadas num
    -- tapete, que é exatamente o que o comentário acima proíbe.
}
-- Nota: src/data/achievements.lua NÃO está aqui porque os nomes das conquistas
-- não têm acento — a trava não os enxerga. Continuam em PT e sem chaves i18n;
-- é uma superfície conhecida, registrada no relatório, não uma exceção desta
-- lista (entrada morta aqui só afrouxaria a regra).

-- Um literal entre aspas duplas contém byte de acentuação latina?
-- Em UTF-8 as vogais acentuadas e o ç caem todas em 0xC3 + segundo byte.
-- DUAS exceções no mesmo prefixo 0xC3 que NÃO são letras: × (0xC3 0x97) e
-- ÷ (0xC3 0xB7) — sinais de multiplicação/divisão, usados de propósito nos
-- popups de proc de coringa ("×2") e nas descrições de efeito.
local MATH_SIGNS = { [151] = true, [183] = true }   -- 0x97, 0xB7
local function hasAccent(str)
    local i = str:find("\195", 1, true)
    while i do
        local nxt = str:byte(i + 1)
        if not (nxt and MATH_SIGNS[nxt]) then return true end
        i = str:find("\195", i + 1, true)
    end
    return false
end

-- Remove o que está depois de um `--` fora de string (heurística suficiente:
-- comentário com aspas antes do `--` é raro e só geraria FALSO POSITIVO, que
-- é o lado seguro pra uma trava).
local function stripComment(line)
    local inStr = false
    local i = 1
    while i <= #line do
        local c = line:sub(i, i)
        if c == '"' and line:sub(i - 1, i - 1) ~= "\\" then
            inStr = not inStr
        elseif not inStr and c == "-" and line:sub(i + 1, i + 1) == "-" then
            return line:sub(1, i - 1)
        end
        i = i + 1
    end
    return line
end

local function isDevLine(line)
    for _, p in ipairs(DEV_PATTERNS) do
        if line:find(p) then return true end
    end
    return false
end

-- Linha que passa o literal como FALLBACK do I18n.t é o padrão correto.
local function isI18nFallback(line)
    return line:find("I18n%.t%s*%(") ~= nil
        or line:find("I18nMod%.t%s*%(") ~= nil
        or line:find("%f[%w]t%s*%(\"") ~= nil and line:find("i18n") ~= nil
end

-- Saldo de parênteses de uma linha (ignorando os que estão dentro de string).
local function parenDelta(code)
    local d, inStr = 0, false
    for i = 1, #code do
        local c = code:sub(i, i)
        if c == '"' and code:sub(i - 1, i - 1) ~= "\\" then
            inStr = not inStr
        elseif not inStr then
            if c == "(" then d = d + 1 elseif c == ")" then d = d - 1 end
        end
    end
    return d
end

-- Varre por LINHA LÓGICA, não física. Uma chamada quebrada em várias linhas
-- (`print(...` ou `I18n.t(...` com o fallback na linha de baixo) tinha a
-- continuação julgada sozinha e virava falso positivo — aconteceu em 6
-- arquivos na primeira execução desta trava.
local function scanFile(path)
    local content = love.filesystem.read(path)
    if not content then return nil end
    local hits = {}
    local n = 0
    local buf, bufLine, depth = nil, 0, 0
    local function flush()
        if not buf then return end
        if buf:find('"') and hasAccent(buf)
            and not isDevLine(buf) and not isI18nFallback(buf) then
            for lit in buf:gmatch('"([^"]*)"') do
                if hasAccent(lit) then
                    table.insert(hits, { line = bufLine, text = lit })
                end
            end
        end
        buf, depth = nil, 0
    end
    for line in (content .. "\n"):gmatch("(.-)\r?\n") do
        n = n + 1
        local code = stripComment(line)
        if buf then buf = buf .. " " .. code else buf, bufLine = code, n end
        depth = depth + parenDelta(code)
        if depth <= 0 then flush() end
    end
    flush()
    return hits
end

local function listLua(dir)
    local out = {}
    local items = love.filesystem.getDirectoryItems(dir)
    for _, name in ipairs(items) do
        local p = dir .. "/" .. name
        local info = love.filesystem.getInfo(p)
        if info and info.type == "file" and name:sub(-4) == ".lua" then
            table.insert(out, p)
        end
    end
    table.sort(out)
    return out
end

function M.run()
    TK.bootstrap()
    local t = TK.new("i18n: sem PT cravado em UI")

    local targets = {}
    for _, d in ipairs(DIRS) do
        for _, p in ipairs(listLua(d)) do table.insert(targets, p) end
    end
    for _, f in ipairs(FILES) do table.insert(targets, f) end

    local offenders, allowedHits, scanned = {}, 0, 0
    for _, path in ipairs(targets) do
        local hits = scanFile(path)
        if hits then
            scanned = scanned + 1
            if #hits > 0 then
                if ALLOW[path] then
                    allowedHits = allowedHits + #hits
                else
                    table.insert(offenders, { path = path, hits = hits })
                end
            end
        end
    end

    t:truthy("varreu os arquivos de UI (" .. scanned .. ")", scanned > 40)

    if #offenders > 0 then
        print("\n  Literais em português fora do i18n:")
        for _, o in ipairs(offenders) do
            for _, h in ipairs(o.hits) do
                print(("    %s:%d  \"%s\""):format(o.path, h.line, h.text))
            end
        end
        print("    -> mande pro i18n (5 locales) ou, se for saída de dev,")
        print("       use print/Debug.*; se for exceção real, registre em ALLOW.")
    end
    t:eq("nenhum literal acentuado em caminho de desenho", #offenders, 0)

    -- A lista de exceções não pode virar tapete: se uma entrada deixou de ter
    -- ocorrência, ela sai (senão a trava afrouxa sem ninguém notar).
    for path in pairs(ALLOW) do
        local hits = scanFile(path)
        if hits and #hits == 0 then
            print("    -> ALLOW obsoleto (arquivo já limpo): " .. path)
        end
    end
    t:truthy("exceções auditadas ainda em uso (" .. allowedHits .. " ocorrências)",
        allowedHits > 0)

    return t:done()
end

return M
