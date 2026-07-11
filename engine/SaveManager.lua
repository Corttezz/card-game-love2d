-- engine/SaveManager.lua
-- Persistência de save (run) e settings. Inspirado em
-- balatro-source/engine/save_manager.lua, mas síncrono e com formato Lua.
--
-- Diferenças vs Balatro:
--   - Sem thread (LÖVE/OpenAL não justifica pra escala atual).
--   - Sem string_packer custom — usa serialize() para Lua source code.
--   - Atomic write simulado: escreve .tmp, valida parse, então finaliza.
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
    fullscreen   = false,
    crtShader    = true,
    locale       = "pt_BR",
    -- Acessibilidade Balatro-style (G.SETTINGS.reduced_motion / screenshake).
    -- screenshake: multiplicador 0..1 da intensidade do shake (1 = full).
    -- reducedMotion: true desliga juice_up + ambient tilt + screen shake.
    screenshake   = 1.0,
    reducedMotion = false,
    -- LightEngine (cena WorldRoad): false = frame idêntico ao pré-motor
    lighting      = true,
}

SaveManager.PATHS = PATHS
SaveManager.DEFAULT_SETTINGS = DEFAULT_SETTINGS

-- Serializa table Lua para source code retornável via `return`.
-- Suporta number/boolean/string/table com keys string ou number.
-- Cycles não são suportados (saves do jogo são DAGs).
local function serialize(o, indent)
    indent = indent or ""
    local t = type(o)
    if t == "number" or t == "boolean" then
        return tostring(o)
    elseif t == "string" then
        return string.format("%q", o)
    elseif t == "table" then
        local parts = { "{\n" }
        local next_indent = indent .. "  "
        for k, v in pairs(o) do
            local keyStr
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                keyStr = k .. " = "
            else
                keyStr = "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "] = "
            end
            parts[#parts + 1] = next_indent .. keyStr .. serialize(v, next_indent) .. ",\n"
        end
        parts[#parts + 1] = indent .. "}"
        return table.concat(parts)
    end
    return "nil"
end
SaveManager.serialize = serialize

-- Atomic write. Estratégia: escreve em <path>.tmp, faz parse-check, depois
-- promove pra <path>. Crash no meio do write deixa só o .tmp órfão (limpo
-- no próximo write ou ignorável).
local function atomicWrite(path, data)
    local serialized = "return " .. serialize(data)
    local tmpPath = path .. ".tmp"

    local ok, err = love.filesystem.write(tmpPath, serialized)
    if not ok then
        return false, "tmp write: " .. tostring(err)
    end

    -- Validação: se tmp não parseia, abortamos sem promover.
    local chunk, parseErr = love.filesystem.load(tmpPath)
    if not chunk then
        love.filesystem.remove(tmpPath)
        return false, "tmp parse: " .. tostring(parseErr)
    end

    -- Promove tmp → final.
    local ok2, err2 = love.filesystem.write(path, serialized)
    if not ok2 then
        love.filesystem.remove(tmpPath)
        return false, "final write: " .. tostring(err2)
    end

    love.filesystem.remove(tmpPath)
    return true
end

-- Lê arquivo Lua serializado, retorna `default` em caso de ausência ou corrupção.
local function safeRead(path, default)
    if not love.filesystem.getInfo(path) then return default end

    local chunk, err = love.filesystem.load(path)
    if not chunk then
        print("[SaveManager] parse falhou em " .. path .. ": " .. tostring(err))
        return default
    end

    local ok, value = pcall(chunk)
    if not ok or type(value) ~= "table" then
        print("[SaveManager] save corrompido em " .. path)
        return default
    end

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

function SaveManager.hasRun()
    return love.filesystem.getInfo(PATHS.run) ~= nil
end

function SaveManager.deleteRun()
    if love.filesystem.getInfo(PATHS.run) then
        love.filesystem.remove(PATHS.run)
    end
    -- Limpa eventual .tmp órfão.
    if love.filesystem.getInfo(PATHS.run .. ".tmp") then
        love.filesystem.remove(PATHS.run .. ".tmp")
    end
end

return SaveManager
