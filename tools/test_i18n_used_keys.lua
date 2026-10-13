-- tools/test_i18n_used_keys.lua
-- Trava: toda chave LITERAL passada a I18n.t(...) no codigo de runtime existe
-- nos 5 locales. O test_i18n confere uma lista fixa de chaves criticas; este
-- varre o codigo — chave nova no .lua sem a entrada no locale falha aqui, e
-- nao so quando o jogador abre a tela em alemao.
--
-- Chaves montadas por concatenacao ("acts.act" .. n, "status." .. name) nao
-- sao verificaveis estaticamente: o literal termina em "." ou "_" e e pulado.
--
-- Rodar: love . test_one test_i18n_used_keys

local M = {}

local ROOTS = { "main.lua", "components", "engine", "src" }
local SKIP_PREFIX = "src/i18n/locales"

local function listLua(path, out)
    local info = love.filesystem.getInfo(path)
    if not info then return end
    if info.type == "file" then
        if path:match("%.lua$") then out[#out + 1] = path end
        return
    end
    if path:sub(1, #SKIP_PREFIX) == SKIP_PREFIX then return end
    for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
        listLua(path .. "/" .. item, out)
    end
end

local function lookup(tbl, key)
    local cur = tbl
    for seg in key:gmatch("[^.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[seg]
    end
    return cur
end

function M.run()
    local I18n = require("src.i18n.I18n")
    local locales = I18n.getAvailable()
    local data = {}
    for _, code in ipairs(locales) do
        data[code] = require("src.i18n.locales." .. code)
    end

    local files = {}
    for _, r in ipairs(ROOTS) do listLua(r, files) end

    local used = {}   -- key -> "arquivo:linha" (primeira ocorrencia)
    for _, f in ipairs(files) do
        local src = love.filesystem.read(f)
        if src then
            local ln = 0
            for line in (src .. "\n"):gmatch("(.-)\n") do
                ln = ln + 1
                -- Linha de comentario nao conta (exemplos de uso no cabecalho).
                -- O literal tem que FECHAR o argumento (`"chave")` ou `"chave",`):
                -- `"acts.act" .. n` e concatenacao, nao chave.
                if not line:match("^%s*%-%-") then
                    for key in line:gmatch('I18n%.t%(%s*"([^"]+)"%s*[,)]') do
                        if not key:match("[._]$") and not used[key] then
                            used[key] = f .. ":" .. ln
                        end
                    end
                end
            end
        end
    end

    local nUsed, missing = 0, {}
    for key, where in pairs(used) do
        nUsed = nUsed + 1
        for _, code in ipairs(locales) do
            if lookup(data[code], key) == nil then
                missing[#missing + 1] = ("%s ausente em %s (%s)"):format(key, code, where)
            end
        end
    end
    table.sort(missing)

    print(("[test_i18n_used_keys] %d arquivos, %d chaves literais, %d locales"):format(
        #files, nUsed, #locales))
    for _, m in ipairs(missing) do print("  [FAIL] " .. m) end
    if #missing == 0 then
        print("[ OK ] toda chave literal de I18n.t existe nos " .. #locales .. " locales")
        return true
    end
    return false
end

return M
