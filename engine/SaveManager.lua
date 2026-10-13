-- engine/SaveManager.lua
-- Persistência de save (run) e settings. Inspirado em
-- balatro-source/engine/save_manager.lua, mas síncrono e com formato Lua.
--
-- Diferenças vs Balatro:
--   - Sem thread (LÖVE/OpenAL não justifica pra escala atual).
--   - Sem string_packer custom — usa serialize() para Lua source code.
--   - Atomic write real: .tmp verificado + rename + uma geração .bak (ver writeFile).
--   - Versioning + migrations runner integrado em loadRun.

local SaveManager = {}

local Migrations = require("engine.SaveMigrations")

-- Caminhos relativos ao save directory do LÖVE.
-- SANDBOX de ferramenta (_G.HEADLESS_TOOL, setado pelo main.lua quando o
-- jogo roda com QUALQUER argumento): run/settings viram *.tool.lua — as
-- tools de screenshot/teste chamam startNewRun+checkpointRun e SOBRESCREVIAM
-- o save real do jogador ("abandonei a run e ela ressuscita" — o fantasma
-- era o save das capturas de validação).
local PATHS_PLAYER = {
    settings = "settings.lua",
    run      = "run.save.lua",
}
local PATHS_TOOL = {
    settings = "settings.tool.lua",
    run      = "run.tool.lua",
}
local PATHS = setmetatable({}, {
    __index = function(_, k)
        return (_G.HEADLESS_TOOL and PATHS_TOOL or PATHS_PLAYER)[k]
    end,
})

local DEFAULT_SETTINGS = {
    masterVolume = 1.0,
    musicVolume  = 0.3,
    sfxVolume    = 0.7,
    ambientVolume = 1.0,   -- slider Ambiente (o nível base já é baixo: Config.Audio.AMBIENT_VOLUME)
    -- Primeiro acesso entra em tela cheia: 1024x768 numa tela moderna lê como
    -- janelinha, e o jogador novo não sabe que existe a opção. Quem já jogou
    -- tem o valor no arquivo e este default não o alcança — por isso o
    -- `love.load` também aumenta a janela de quem escolheu NÃO usar fullscreen.
    fullscreen   = true,
    crtShader    = true,
    locale       = "pt_BR",
    -- Acessibilidade Balatro-style (G.SETTINGS.reduced_motion / screenshake).
    -- screenshake: multiplicador 0..1 da intensidade do shake (1 = full).
    -- reducedMotion: true desliga juice_up + ambient tilt + screen shake.
    screenshake   = 1.0,
    reducedMotion = false,
    -- LightEngine (cena WorldRoad): false = frame idêntico ao pré-motor
    lighting      = true,
    -- Out/2026 (Configurações v3): vsync do monitor e ritmo do combate
    -- (multiplicador de VELOCIDADE exibido; CombatBeats.speed = 1/x).
    vsync         = true,
    combatSpeed   = 1,
    -- Escala da interface (src/ui/UiScale): multiplicador sobre o Auto.
    uiScale       = 1,
    -- Dicas do tutorial (src/systems/Tutorial): Configurações → Jogo.
    tipsEnabled   = true,
    -- Prévia de dano (src/ui/DamagePreviewPanel): false = só o resumo (dano,
    -- Bloqueio, LETAL, fichas de combo); true = a conta carta a carta.
    -- Alterna na própria placa (clique / V / foco+A); sem linha em
    -- Configurações → Jogo (aba de altura fixa, 5 linhas — test_pause_menu).
    previewDetails = false,
}

SaveManager.PATHS = PATHS
SaveManager.DEFAULT_SETTINGS = DEFAULT_SETTINGS

-- Serializa table Lua para source code retornável via `return`.
-- Suporta number/boolean/string/table com keys string ou number.
-- Cycles não são suportados (saves do jogo são DAGs).
-- Palavras reservadas não podem ser chave nua (`end = 1` não parseia — e o
-- writeFile recusaria o save inteiro por causa de uma chave).
local LUA_KEYWORDS = {}
for w in ([[and break do else elseif end false for function goto if in
    local nil not or repeat return then true until while]]):gmatch("%a+") do
    LUA_KEYWORDS[w] = true
end

local function serialize(o, indent)
    indent = indent or ""
    local t = type(o)
    if t == "number" then
        -- tostring(math.huge) = "inf", que relido vira a variável `inf` (nil).
        if o ~= o then return "0/0" end
        if o == math.huge then return "1/0" end
        if o == -math.huge then return "-1/0" end
        return tostring(o)
    elseif t == "boolean" then
        return tostring(o)
    elseif t == "string" then
        return string.format("%q", o)
    elseif t == "table" then
        local parts = { "{\n" }
        local next_indent = indent .. "  "
        for k, v in pairs(o) do
            local keyStr
            if type(k) == "string" and k:match("^[%a_][%w_]*$") and not LUA_KEYWORDS[k] then
                keyStr = k .. " = "
            else
                keyStr = "[" .. (type(k) == "string" and string.format("%q", k) or serialize(k)) .. "] = "
            end
            parts[#parts + 1] = next_indent .. keyStr .. serialize(v, next_indent) .. ",\n"
        end
        parts[#parts + 1] = indent .. "}"
        return table.concat(parts)
    end
    return "nil"
end
SaveManager.serialize = serialize

-- Escrita atômica de VERDADE (Out/2026 — auditoria de integridade de save).
--
-- O que havia antes: escrevia <path>.tmp, validava e depois REESCREVIA o
-- <path> final com `love.filesystem.write` — um crash nessa segunda escrita
-- deixava o arquivo final truncado, e o perfil (que nem passava por aqui)
-- era gravado direto. Perfil truncado → load caía nos defaults → o próximo
-- save gravava os defaults por cima: conquistas, desbloqueios e vitórias
-- perdidos de uma vez.
--
-- Protocolo agora (para TODO arquivo persistente: perfil, run, settings):
--   1. escreve <path>.tmp e LÊ DE VOLTA: bytes iguais + parse + devolve tabela;
--   2. se o <path> atual é válido, ele vira <path>.bak (uma geração só);
--      se é inválido, nunca vira .bak (o .bak é a última versão BOA) — vai
--      pra <path>.corrupt-<timestamp> antes de ser substituído;
--   3. promove o .tmp com `os.rename` (rename é atômico no mesmo volume).
--      love.filesystem não tem rename, então o caminho real sai de
--      `getSaveDirectory()`. No Windows o rename falha com destino existente
--      (por isso o destino é removido antes) e falha com caminho não-ASCII
--      (os.rename usa a codepage ANSI; usuário "José" existe) — o FALLBACK
--      escreve o final direto e confere lendo de volta. Nesse fallback a
--      janela de risco é coberta pelos outros dois: o .tmp (novo, válido) e o
--      .bak (anterior, válido) seguem no disco até o final conferir.
--   Leitura (readDataFile): <path> → <path>.tmp → <path>.bak, o primeiro que
--   parseia. Principal ilegível é copiado pra .corrupt-<ts> e AVISA alto.
SaveManager.quarantined = {}  -- path → arquivo .corrupt já gerado nesta sessão

-- Valida o TEXTO de um save: parseia, roda sem ambiente, devolve tabela.
local function decodeData(raw, name)
    if type(raw) ~= "string" or raw == "" then return nil, "vazio" end
    if raw:byte(1) == 27 then return nil, "binary chunk refused" end
    local chunk, err = loadstring(raw, "=" .. (name or "save"))
    if not chunk then return nil, err end
    setfenv(chunk, {})
    local ok, value = pcall(chunk)
    if not ok then return nil, tostring(value) end
    if type(value) ~= "table" then return nil, "nao devolveu tabela" end
    return value
end
SaveManager.decodeData = decodeData

-- Rename no disco real (sobrescrevível nos testes pra simular o fallback).
function SaveManager._rename(fromRel, toRel)
    local fs = love.filesystem
    local dir = fs.getSaveDirectory and fs.getSaveDirectory()
    if not (dir and dir ~= "" and os and os.rename) then return false end
    local ok = os.rename(dir .. "/" .. fromRel, dir .. "/" .. toRel)
    return ok and true or false
end

local function quarantine(path, raw)
    if SaveManager.quarantined[path] then return SaveManager.quarantined[path] end
    local dest = ("%s.corrupt-%s"):format(path, os.date("%Y%m%d-%H%M%S"))
    if raw and love.filesystem.write(dest, raw) then
        SaveManager.quarantined[path] = dest
        print("[SaveManager] !!! " .. path .. " ILEGIVEL — copia preservada em " .. dest)
        return dest
    end
    return nil
end

-- Grava `text` em `path` com o protocolo acima. `validate(text)` opcional
-- (default: decodeData). Devolve true ou false, motivo.
function SaveManager.writeFile(path, text, validate)
    local fs = love.filesystem
    validate = validate or function(t) return decodeData(t, path) end
    local tmpPath, bakPath = path .. ".tmp", path .. ".bak"

    local ok, err = fs.write(tmpPath, text)
    if not ok then return false, "tmp write: " .. tostring(err) end
    local back = fs.read(tmpPath)
    if back ~= text then
        fs.remove(tmpPath)
        return false, "tmp readback divergiu"
    end
    local good, perr = validate(back)
    if not good then
        fs.remove(tmpPath)
        return false, "tmp parse: " .. tostring(perr)
    end

    -- Rotação: o principal atual só vira .bak se for BOM.
    if fs.getInfo(path) then
        local cur = fs.read(path)
        if cur and validate(cur) then
            if fs.getInfo(bakPath) then fs.remove(bakPath) end
            if not SaveManager._rename(path, bakPath) then
                fs.write(bakPath, cur)
            end
        else
            quarantine(path, cur)
        end
    end

    -- Promoção.
    if fs.getInfo(path) then fs.remove(path) end
    local promoted = SaveManager._rename(tmpPath, path)
    if not promoted then
        local ok2, err2 = fs.write(path, text)
        if not ok2 or fs.read(path) ~= text then
            -- .tmp (válido) fica no disco: readDataFile o encontra.
            return false, "final write: " .. tostring(err2)
        end
    end
    if fs.read(path) ~= text then
        return false, "final readback divergiu"
    end
    if fs.getInfo(tmpPath) then fs.remove(tmpPath) end
    return true
end

-- Atomic write de uma tabela (serializa + writeFile).
local function atomicWrite(path, data)
    return SaveManager.writeFile(path, "return " .. serialize(data))
end

-- Lê um arquivo de dados com recuperação. Devolve value, info:
--   info.source      "main" | "tmp" | "bak" | nil (nada legível)
--   info.existed     algum dos três arquivos existia
--   info.mainCorrupt o principal existia e não parseou
--   info.corruptCopy caminho da cópia .corrupt-<ts>
function SaveManager.readDataFile(path)
    local fs = love.filesystem
    local info = { existed = false, mainCorrupt = false }
    local order = { { "main", path }, { "tmp", path .. ".tmp" }, { "bak", path .. ".bak" } }
    for _, entry in ipairs(order) do
        local which, p = entry[1], entry[2]
        if fs.getInfo(p) then
            info.existed = true
            local raw = fs.read(p)
            local value, err = decodeData(raw, p)
            if value then
                info.source = which
                if which ~= "main" then
                    print(("[SaveManager] !!! %s RECUPERADO de %s"):format(path, p))
                end
                return value, info
            end
            print(("[SaveManager] parse falhou em %s: %s"):format(p, tostring(err)))
            if which == "main" then
                info.mainCorrupt = true
                info.corruptCopy = quarantine(path, raw)
            end
        end
    end
    return nil, info
end

-- Carrega um arquivo de DADOS do save dir sem dar a ele poder de codigo.
-- Save e arquivo do usuario (Steam Cloud, save compartilhado num forum): com
-- love.filesystem.load ele rodaria com acesso a os/io. Aqui: so texto (bytecode
-- recusado — o LuaJIT nao valida bytecode) e ambiente VAZIO.
function SaveManager.loadDataChunk(path)
    local raw = love.filesystem.read(path)
    if not raw then return nil, "read failed" end
    if raw:byte(1) == 27 then return nil, "binary chunk refused" end
    local chunk, err = loadstring(raw, "=" .. path)
    if not chunk then return nil, err end
    setfenv(chunk, {})
    return chunk
end

-- Lê arquivo Lua serializado (com recuperação .tmp/.bak), retorna `default`
-- em caso de ausência ou corrupção total.
local function safeRead(path, default)
    local value = SaveManager.readDataFile(path)
    if value == nil then return default end
    return value
end

-- Merge raso: aplica valores de `b` em cima de `a` (cópia). Usado pra
-- preencher settings antigos com keys novas sem perder o que o user tem.
local function shallowMerge(a, b)
    local out = {}
    for k, v in pairs(a) do out[k] = v end
    for k, v in pairs(b) do
        if out[k] == nil then out[k] = v end
    end
    return out
end

-- ============== Settings ==============

function SaveManager.saveSettings(settings)
    return atomicWrite(PATHS.settings, settings)
end

function SaveManager.loadSettings()
    local raw = safeRead(PATHS.settings, nil)
    if raw == nil then
        -- Primeira execução: grava defaults (não obrigatório, mas evita
        -- inconsistência caso usuário só toque fullscreen sem ajustar volume).
        return shallowMerge({}, DEFAULT_SETTINGS)
    end
    -- Backfill keys novas que possam ter sido adicionadas em versões futuras.
    return shallowMerge(raw, DEFAULT_SETTINGS)
end

-- ============== Run ==============

function SaveManager.saveRun(runData)
    local payload = {
        version = Migrations.CURRENT_VERSION,
        savedAt = os.time(),
        runData = runData,
    }
    return atomicWrite(PATHS.run, payload)
end

function SaveManager.loadRun()
    local payload = safeRead(PATHS.run, nil)
    if not payload or not payload.runData then return nil end

    -- Roda migrations in-place. Migrations.run mutate `payload`.
    local migrated, err = Migrations.run(payload)
    if not migrated then
        print("[SaveManager] migration falhou: " .. tostring(err))
        return nil
    end

    return payload.runData, payload
end

-- Save de run que NÃO carrega (corrompido, migration falhou): sai do caminho
-- sem ser destruído — vai pra `<run>.corrupt` (o dono pode mandar o arquivo
-- pra análise). Sem isto o botão Continuar ficava no menu pra sempre e cada
-- clique falhava calado. Devolve true se havia algo pra mover.
function SaveManager.quarantineRun()
    local fs = love.filesystem
    local base = PATHS.run
    local any = false
    for _, p in ipairs({ base, base .. ".tmp", base .. ".bak" }) do
        if fs.getInfo(p) then
            any = true
            -- Só o principal vira .corrupt (o legado que o dono manda pra
            -- análise); .tmp/.bak de um save que nem assim carregou saem
            -- junto, senão o Continuar "ressuscitaria" pelo fallback.
            if p == base then
                local raw = fs.read(p)
                if raw then fs.write(base .. ".corrupt", raw) end
            end
            fs.remove(p)
        end
    end
    if any then
        print("[SaveManager] save de run ilegivel movido para " .. base .. ".corrupt")
    end
    return any
end

-- Há run se QUALQUER geração existe: um crash entre a rotação e a promoção
-- deixa só .tmp/.bak, e readDataFile sabe carregá-los.
function SaveManager.hasRun()
    local fs = love.filesystem
    local base = PATHS.run
    return fs.getInfo(base) ~= nil or fs.getInfo(base .. ".tmp") ~= nil
        or fs.getInfo(base .. ".bak") ~= nil
end

-- Apaga TODAS as gerações: run abandonada/morta com .bak no disco voltaria
-- no Continuar pelo fallback de leitura.
function SaveManager.deleteRun()
    local fs = love.filesystem
    local base = PATHS.run
    for _, p in ipairs({ base, base .. ".tmp", base .. ".bak" }) do
        if fs.getInfo(p) then fs.remove(p) end
    end
end

return SaveManager
