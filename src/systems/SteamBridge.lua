local Debug = require("src.core.Debug")

local SteamBridge = {}

local backend = nil
local active = false
local tried = false
local warned = false
SteamBridge.log = {}

local function warnOnce(reason)
    if warned then return end
    warned = true
    Debug.warn("[SteamBridge] Steam INATIVA (" .. tostring(reason) .. ") — "
        .. "conquistas ficam so no perfil local. Ver memory/steam_achievements.md")
end

function SteamBridge.init()
    if tried then return active end
    tried = true
    if (_G.HEADLESS_TOOL or _G.CHEAT_MODE) and not backend then
        warnOnce(_G.CHEAT_MODE and "modo cheat" or "ferramenta headless")
        return false
    end
    if not backend then
        local ok, mod = pcall(require, "luasteam")
        if not ok or type(mod) ~= "table" then
            warnOnce("modulo luasteam ausente")
            return false
        end
        backend = mod
    end
    local okInit, res = pcall(backend.init)
    if not okInit or res == false then
        warnOnce("Steam.init falhou: " .. tostring(res))
        backend = nil
        return false
    end
    active = true
    Debug.log("[SteamBridge] Steam ATIVA — conquistas espelhadas no Steamworks")
    return true
end

function SteamBridge.isActive() return active end

local function call(path, fn, ...)
    if not active then
        warnOnce("chamada " .. path .. " sem init")
        return false
    end
    local us = backend.userStats
    if not us or type(us[fn]) ~= "function" then
        Debug.warn("[SteamBridge] AVISO: backend sem userStats." .. fn)
        return false
    end
    local ok, res = pcall(us[fn], ...)
    if not ok then
        Debug.warn("[SteamBridge] AVISO: userStats." .. fn .. " falhou: " .. tostring(res))
        return false
    end
    return res ~= false
end

function SteamBridge.unlock(apiName)
    if not apiName then
        Debug.warn("[SteamBridge] AVISO: unlock sem API name")
        return false
    end
    table.insert(SteamBridge.log, { op = "unlock", api = apiName })
    if not active then warnOnce("unlock " .. apiName); return false end
    local ok = call("unlock", "setAchievement", apiName)
    call("unlock", "storeStats")
    return ok
end

function SteamBridge.indicateProgress(apiName, cur, max)
    table.insert(SteamBridge.log,
        { op = "progress", api = apiName, cur = cur, max = max })
    if not active then return false end
    return call("progress", "indicateAchievementProgress", apiName, cur, max)
end

function SteamBridge.syncAll(defs, isUnlocked)
    if not active then return 0 end
    local n = 0
    for _, d in ipairs(defs or {}) do
        if d.steam and isUnlocked(d.id) then
            if call("sync", "setAchievement", d.steam) then n = n + 1 end
        end
    end
    if n > 0 then call("sync", "storeStats") end
    Debug.log("[SteamBridge] sync: " .. n .. " conquista(s) locais espelhadas")
    return n
end

function SteamBridge.update()
    if not active then return end
    if backend.runCallbacks then pcall(backend.runCallbacks) end
end

function SteamBridge.shutdown()
    if active and backend.shutdown then pcall(backend.shutdown) end
    active = false
end

function SteamBridge._setBackend(fake)
    backend = fake
    active = false
    tried = false
    warned = false
    SteamBridge.log = {}
end

return SteamBridge
