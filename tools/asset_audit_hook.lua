-- tools/asset_audit_hook.lua
-- Instrumentacao da auditoria de imagens orfas (Out/2026). Envolve os pontos
-- de entrada de arquivo do LOVE e registra todo caminho que o jogo TOCA:
-- imagem carregada, getInfo que achou algo, pasta varrida. Ligada por env:
--   ASSET_AUDIT=<arquivo de log absoluto>
-- e instalada por uma linha TEMPORARIA no topo do main.lua (nao commitada).
-- O log alimenta a classificacao USADO x ORFAO junto com a analise estatica.

local out = os.getenv("ASSET_AUDIT")
if not out or out == "" then return end

local fh = io.open(out, "a")
if not fh then return end
local seen = {}

local function rec(tag, p)
    if type(p) ~= "string" then return end
    local k = tag .. " " .. p
    if seen[k] then return end
    seen[k] = true
    fh:write(k, "\n")
    fh:flush()
end

local function wrap(mod, name, tag, onlyHit)
    local orig = mod and mod[name]
    if not orig then return end
    mod[name] = function(a, ...)
        local r = { orig(a, ...) }
        if not onlyHit or r[1] then rec(tag, a) end
        return unpack(r)
    end
end

if love.graphics then wrap(love.graphics, "newImage", "IMG") end
if love.image then wrap(love.image, "newImageData", "IMG") end
wrap(love.filesystem, "getInfo", "INFO", true)
wrap(love.filesystem, "getDirectoryItems", "DIR")
wrap(love.filesystem, "newFileData", "FILE")
wrap(love.filesystem, "read", "FILE", true)
