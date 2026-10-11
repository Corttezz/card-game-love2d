-- src/systems/SteamBridge.lua
-- Ponte entre as conquistas LOCAIS (AchievementSystem/ProfileStats) e a Steam.
--
-- LOVE puro nao fala com o Steamworks. O caminho previsto e o binding
-- `luasteam` (github.com/uspgamedev/luasteam): uma DLL/SO nativa carregada
-- via require("luasteam") + steam_api64.dll + steam_appid.txt ao lado do
-- executavel. NADA disso vem no repo — ver memory/steam_achievements.md.
--
-- Contrato:
--   * A conquista LOCAL e a fonte de verdade (o jogo funciona igual sem
--     Steam; o perfil guarda tudo). A Steam e um espelho.
--   * Sem Steam: TODA chamada e no-op — mas AVISADA, uma vez, no console
--     ("fallback silencioso e proibido", CLAUDE.md). Nunca derruba o jogo.
--   * Com Steam: init() sincroniza o que ja estava desbloqueado localmente
--     (quem jogou antes de a Steam existir nao perde nada) e cada unlock()
--     chama SetAchievement + StoreStats.
--
-- API:
--   SteamBridge.init()                       -- idempotente; true se ativa
--   SteamBridge.isActive()
--   SteamBridge.unlock(apiName)              -- SetAchievement + StoreStats
--   SteamBridge.indicateProgress(apiName, cur, max)
--   SteamBridge.syncAll(defs, isUnlockedFn)  -- empurra os locais pra Steam
--   SteamBridge.update()                     -- runCallbacks (love.update)
--   SteamBridge.shutdown()
--   SteamBridge._setBackend(fake)            -- testes injetam um fake

local SteamBridge = {}

local backend = nil      -- modulo luasteam (ou fake de teste)
local active = false
local tried = false
local warned = false
-- Registro do que foi pedido (testes e diagnostico leem isso, Steam ou nao).
SteamBridge.log = {}

local function warnOnce(reason)
    if warned then return end
    warned = true
    print("[SteamBridge] Steam INATIVA (" .. tostring(reason) .. ") — "
        .. "conquistas ficam so no perfil local. Ver memory/steam_achievements.md")
end

function SteamBridge.init()
    if tried then return active end
    tried = true
    if _G.HEADLESS_TOOL and not backend then
        -- Tools/testes nunca tocam a Steam real do jogador.
        warnOnce("ferramenta headless")
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
    print("[SteamBridge] Steam ATIVA — conquistas espelhadas no Steamworks")
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
        print("[SteamBridge] AVISO: backend sem userStats." .. fn)
        return false
    end
    local ok, res = pcall(us[fn], ...)
    if not ok then
        print("[SteamBridge] AVISO: userStats." .. fn .. " falhou: " .. tostring(res))
        return false
    end
    return res ~= false
end

function SteamBridge.unlock(apiName)
    if not apiName then
        print("[SteamBridge] AVISO: unlock sem API name")
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

-- Empurra pra Steam o que ja esta desbloqueado no perfil local.
function SteamBridge.syncAll(defs, isUnlocked)
    if not active then return 0 end
    local n = 0
    for _, d in ipairs(defs or {}) do
        if d.steam and isUnlocked(d.id) then
            if call("sync", "setAchievement", d.steam) then n = n + 1 end
        end
    end
    if n > 0 then call("sync", "storeStats") end
    print("[SteamBridge] sync: " .. n .. " conquista(s) locais espelhadas")
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

-- Testes: injeta um backend fake (tabela com init/userStats/...) e zera o
-- estado. Passar nil volta ao estado "nunca inicializado".
function SteamBridge._setBackend(fake)
    backend = fake
    active = false
    tried = false
    warned = false
    SteamBridge.log = {}
end

return SteamBridge
