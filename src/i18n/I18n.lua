local Debug = require("src.core.Debug")

local I18n = {}

local DEFAULT_LOCALE  = "pt_BR"
local FALLBACK_LOCALE = "en"
local function settingsFile()
    return _G.HEADLESS_TOOL and "i18n_settings.tool.lua" or "i18n_settings.lua"
end

I18n.current = DEFAULT_LOCALE
I18n.data    = {}

I18n.available = { "pt_BR", "en", "es", "fr", "de" }

I18n.labels = {
    pt_BR = "Português (Brasil)",
    en    = "English",
    es    = "Español",
    fr    = "Français",
    de    = "Deutsch",
}

local listeners = {}

function I18n.onLocaleChanged(cb)
    if type(cb) == "function" then listeners[#listeners + 1] = cb end
end

local function fireLocaleChanged()
    for _, cb in ipairs(listeners) do
        pcall(cb, I18n.current)
    end
end

local function loadLocale(locale)
    if I18n.data[locale] then return true end
    local ok, mod = pcall(require, "src.i18n.locales." .. locale)
    if ok and type(mod) == "table" then
        I18n.data[locale] = mod
        return true
    end
    Debug.err("[I18n] Falha ao carregar locale '" .. locale .. "': " .. tostring(mod))
    return false
end

function I18n.init()
    loadLocale(DEFAULT_LOCALE)
    if DEFAULT_LOCALE ~= FALLBACK_LOCALE then
        loadLocale(FALLBACK_LOCALE)
    end
    local saved = _G.TOOL_FORCE_LOCALE or I18n.loadSetting()
    if saved and saved ~= I18n.current then
        I18n.setLocale(saved, true)
    end
    local FontManager = pcall(require, "src.ui.FontManager") and require("src.ui.FontManager")
    if FontManager and FontManager.setFontPath then
        FontManager.setFontPath(I18n.getFont(I18n.current))
    end
end

function I18n.getLocale() return I18n.current end

function I18n.getAvailable() return I18n.available end

function I18n.getLabel(locale) return I18n.labels[locale] or locale end

function I18n.getFont(locale)
    locale = locale or I18n.current
    local data = I18n.data[locale]
    return data and data.font or nil
end

function I18n.setLocale(locale, silent)
    if locale == I18n.current and I18n.data[locale] then return true end
    if not loadLocale(locale) then return false end
    I18n.current = locale
    I18n.saveSetting(locale)
    local ok, FontManager = pcall(require, "src.ui.FontManager")
    if ok and FontManager and FontManager.setFontPath then
        FontManager.setFontPath(I18n.getFont(locale))
    end
    if not silent then fireLocaleChanged() end
    return true
end

function I18n.cycleLocale()
    local idx = 1
    for i, code in ipairs(I18n.available) do
        if code == I18n.current then idx = i; break end
    end
    local next = I18n.available[(idx % #I18n.available) + 1]
    I18n.setLocale(next)
    return I18n.current
end

local function lookup(data, key)
    local cursor = data
    for segment in tostring(key):gmatch("[^%.]+") do
        if type(cursor) ~= "table" then return nil end
        cursor = cursor[segment]
    end
    if type(cursor) == "string" then return cursor end
    return nil
end

local function substitute(template, vars)
    if not vars then return template end
    return (template:gsub("%{(%w+)%}", function(k)
        local v = vars[k]
        if v == nil then return "{" .. k .. "}" end
        return tostring(v)
    end))
end

function I18n.t(key, vars, fallback)
    local data = I18n.data[I18n.current]
    local result = data and lookup(data, key)
    if not result and I18n.current ~= FALLBACK_LOCALE then
        local fbData = I18n.data[FALLBACK_LOCALE]
        result = fbData and lookup(fbData, key)
    end
    if not result then
        result = fallback or key
    end
    return substitute(result, vars)
end

function I18n.cardName(cardOrId)
    local id, fallback
    if type(cardOrId) == "table" then
        id = cardOrId.id
        fallback = cardOrId.name
    else
        id = tostring(cardOrId)
    end
    if not id then return fallback or "?" end
    return I18n.t("cards." .. id .. ".name", nil, fallback or id)
end

local function cardVars(card)
    local vars = {
        atk   = card.attack,
        def   = card.defense,
        cost  = card.cost,
    }
    local effects = card.effects
    if type(effects) == "table" then
        local suffix = { [1] = "", [2] = "2", [3] = "3", [4] = "4" }
        for i = 1, 4 do
            local e = effects[i]
            if e then
                local s = suffix[i]
                vars["value" .. s]    = e.value
                vars["stacks" .. s]   = e.stacks
                vars["duration" .. s] = e.duration
                if type(e.value) == "number" and type(e.type) == "string"
                    and e.type:find("_multiplier$") then
                    vars["pct" .. s] = math.floor((e.value - 1) * 100 + 0.5)
                end
            end
        end
    end
    return vars
end

function I18n.effectDesc(effect)
    if not effect then return "" end
    local t = effect.type
    local vars = {
        value    = effect.value,
        stacks   = effect.stacks or 1,
        target   = effect.target,
        duration = effect.duration or 2,
    }
    if type(effect.value) == "number" and t and t:find("_multiplier$") then
        vars.pct = math.floor((effect.value - 1) * 100 + 0.5)
    end
    local qualifier = (type(effect.value) == "string" and effect.value)
        or effect.orbType or effect.debuffName or effect.combo
    if t and qualifier then
        local MISS = "\0__miss__\0"
        local compound = "effects." .. t .. "_" .. qualifier
        local v = I18n.t(compound, vars, MISS)
        if v ~= MISS then return v end
    end
    return I18n.t("effects." .. (t or "unknown"), vars,
                  effect.description or t or "?")
end

function I18n.cardDesc(cardOrId)
    local id, fallback, card
    if type(cardOrId) == "table" then
        id = cardOrId.id
        fallback = cardOrId.description
        card = cardOrId
    else
        id = tostring(cardOrId)
    end
    if not id then return fallback or "" end
    if not (card and (card.effects or card.attack or card.defense)) then
        local ok, CardDatabase = pcall(require, "src.systems.CardDatabase")
        if ok and CardDatabase then
            local okc, cd = pcall(function() return CardDatabase:getCard(id) end)
            if okc and cd then card = cd end
        end
    end
    local vars = card and cardVars(card) or nil
    return I18n.t("cards." .. id .. ".desc", vars, fallback or "")
end

function I18n.saveSetting(locale)
    if not (love and love.filesystem and love.filesystem.write) then return end
    local ok, SaveManager = pcall(require, "engine.SaveManager")
    if not ok then
        Debug.warn("[I18n] SaveManager indisponivel, idioma nao salvo: " .. tostring(SaveManager))
        return
    end
    local content = "return { locale = " .. string.format("%q", locale) .. " }\n"
    local f = settingsFile()
    if love.filesystem.getInfo(f) then
        local chunk = SaveManager.loadDataChunk(f)
        local okc, old = pcall(chunk or error)
        if okc and type(old) == "string" then love.filesystem.remove(f) end
    end
    local wrote, err = SaveManager.writeFile(f, content)
    if not wrote then Debug.warn("[I18n] Falha ao salvar idioma: " .. tostring(err)) end
end

function I18n.loadSetting()
    if not (love and love.filesystem and love.filesystem.getInfo) then return nil end
    local ok, SaveManager = pcall(require, "engine.SaveManager")
    if not ok then return nil end
    local f = settingsFile()
    if love.filesystem.getInfo(f) then
        local chunk = SaveManager.loadDataChunk(f)
        if chunk then
            local okc, result = pcall(chunk)
            if okc and type(result) == "string" then return result end
        end
    end
    local data = SaveManager.readDataFile(f)
    if type(data) == "table" and type(data.locale) == "string" then return data.locale end
    return nil
end

return I18n
