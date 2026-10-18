local Debug = require("src.core.Debug")

local SaveManager = {}

local Migrations = require("engine.SaveMigrations")

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
    ambientVolume = 1.0,
    fullscreen   = true,
    crtShader    = true,
    crtLevel     = "normal",
    locale       = "en",
    screenshake   = 1.0,
    reducedMotion = false,
    lighting      = true,
    vsync         = true,
    combatSpeed   = 1,
    uiScale       = 1,
    tipsEnabled   = true,
    previewDetails = false,
    muteOnFocusLoss = true,
    musicReact    = true,
}

SaveManager.PATHS = PATHS
SaveManager.DEFAULT_SETTINGS = DEFAULT_SETTINGS

local LUA_KEYWORDS = {}
for w in ([[and break do else elseif end false for function goto if in
    local nil not or repeat return then true until while]]):gmatch("%a+") do
    LUA_KEYWORDS[w] = true
end

local function serialize(o, indent)
    indent = indent or ""
    local t = type(o)
    if t == "number" then
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

SaveManager.quarantined = {}

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
        Debug.err("[SaveManager] !!! " .. path .. " ILEGIVEL — copia preservada em " .. dest)
        return dest
    end
    return nil
end

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

    if fs.getInfo(path) then fs.remove(path) end
    local promoted = SaveManager._rename(tmpPath, path)
    if not promoted then
        local ok2, err2 = fs.write(path, text)
        if not ok2 or fs.read(path) ~= text then
            return false, "final write: " .. tostring(err2)
        end
    end
    if fs.read(path) ~= text then
        return false, "final readback divergiu"
    end
    if fs.getInfo(tmpPath) then fs.remove(tmpPath) end
    return true
end

local function atomicWrite(path, data)
    return SaveManager.writeFile(path, "return " .. serialize(data))
end

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
                    Debug.warn(("[SaveManager] !!! %s RECUPERADO de %s"):format(path, p))
                end
                return value, info
            end
            Debug.warn(("[SaveManager] parse falhou em %s: %s"):format(p, tostring(err)))
            if which == "main" then
                info.mainCorrupt = true
                info.corruptCopy = quarantine(path, raw)
            end
        end
    end
    return nil, info
end

function SaveManager.loadDataChunk(path)
    local raw = love.filesystem.read(path)
    if not raw then return nil, "read failed" end
    if raw:byte(1) == 27 then return nil, "binary chunk refused" end
    local chunk, err = loadstring(raw, "=" .. path)
    if not chunk then return nil, err end
    setfenv(chunk, {})
    return chunk
end

local function safeRead(path, default)
    local value = SaveManager.readDataFile(path)
    if value == nil then return default end
    return value
end

local function shallowMerge(a, b)
    local out = {}
    for k, v in pairs(a) do out[k] = v end
    for k, v in pairs(b) do
        if out[k] == nil then out[k] = v end
    end
    return out
end

function SaveManager.saveSettings(settings)
    return atomicWrite(PATHS.settings, settings)
end

function SaveManager.loadSettings()
    local raw = safeRead(PATHS.settings, nil)
    if raw == nil then
        return shallowMerge({}, DEFAULT_SETTINGS)
    end
    return shallowMerge(raw, DEFAULT_SETTINGS)
end

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

    local migrated, err = Migrations.run(payload)
    if not migrated then
        Debug.err("[SaveManager] migration falhou: " .. tostring(err))
        return nil
    end

    return payload.runData, payload
end

function SaveManager.quarantineRun()
    local fs = love.filesystem
    local base = PATHS.run
    local any = false
    for _, p in ipairs({ base, base .. ".tmp", base .. ".bak" }) do
        if fs.getInfo(p) then
            any = true
            if p == base then
                local raw = fs.read(p)
                if raw then fs.write(base .. ".corrupt", raw) end
            end
            fs.remove(p)
        end
    end
    if any then
        Debug.warn("[SaveManager] save de run ilegivel movido para " .. base .. ".corrupt")
    end
    return any
end

function SaveManager.hasRun()
    local fs = love.filesystem
    local base = PATHS.run
    return fs.getInfo(base) ~= nil or fs.getInfo(base .. ".tmp") ~= nil
        or fs.getInfo(base .. ".bak") ~= nil
end

function SaveManager.deleteRun()
    local fs = love.filesystem
    local base = PATHS.run
    for _, p in ipairs({ base, base .. ".tmp", base .. ".bak" }) do
        if fs.getInfo(p) then fs.remove(p) end
    end
end

return SaveManager
