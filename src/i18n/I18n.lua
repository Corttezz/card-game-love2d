-- src/i18n/I18n.lua
-- Modulo de internacionalizacao simples (zero-dep, so Lua + love.filesystem).
-- Uso basico:
--   I18n.init()                         -- na love.load
--   I18n.t("menu.play")                 -- "JOGAR" / "PLAY" conforme locale
--   I18n.t("shop.buy", { cost = 5 })    -- variaveis via {nome}
--   I18n.setLocale("en")                -- troca idioma (persiste em save file)
--   I18n.cardName(cardOrId)             -- atalho p/ nome de carta com fallback
--   I18n.cardDesc(cardOrId)             -- atalho p/ descricao de carta
--
-- Fallback: locale atual -> en -> fallback opcional -> key literal.

local I18n = {}

local DEFAULT_LOCALE  = "pt_BR"
local FALLBACK_LOCALE = "en"
local SETTINGS_FILE   = "i18n_settings.lua"

I18n.current = DEFAULT_LOCALE
I18n.data    = {}

-- Ordem de apresentacao do seletor de idioma (settings menu).
I18n.available = { "pt_BR", "en", "es", "fr", "de" }

I18n.labels = {
    pt_BR = "Portugues",
    en    = "English",
    es    = "Espanol",
    fr    = "Francais",
    de    = "Deutsch",
}

-- Callbacks disparados apos troca de idioma (ex: invalidar cache de fontes de carta).
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
    print("[I18n] Falha ao carregar locale '" .. locale .. "': " .. tostring(mod))
    return false
end

-- Inicializa: carrega default + fallback, depois aplica locale salvo (se houver).
function I18n.init()
    loadLocale(DEFAULT_LOCALE)
    if DEFAULT_LOCALE ~= FALLBACK_LOCALE then
        loadLocale(FALLBACK_LOCALE)
    end
    local saved = I18n.loadSetting()
    if saved and saved ~= I18n.current then
        I18n.setLocale(saved, true)  -- silent: nao dispara listeners no boot
    end
    -- Aplica fonte declarada pelo locale inicial (se houver) sem disparar
    -- listeners — equivalente ao 'silent boot'.
    local FontManager = pcall(require, "src.ui.FontManager") and require("src.ui.FontManager")
    if FontManager and FontManager.setFontPath then
        FontManager.setFontPath(I18n.getFont(I18n.current))
    end
end

function I18n.getLocale() return I18n.current end

function I18n.getAvailable() return I18n.available end

function I18n.getLabel(locale) return I18n.labels[locale] or locale end

-- Retorna o caminho de fonte declarado pelo locale (campo `font` opcional no
-- modulo do locale), ou nil se o locale nao especificar (= usa default).
-- Util para idiomas que precisam de glifos fora do ASCII/latim (CJK/cirilico).
function I18n.getFont(locale)
    locale = locale or I18n.current
    local data = I18n.data[locale]
    return data and data.font or nil
end

-- Define o locale atual. Retorna true se trocou, false se nao existe.
-- Se `silent = true`, nao dispara listeners (uso: boot).
function I18n.setLocale(locale, silent)
    if locale == I18n.current then return true end
    if not loadLocale(locale) then return false end
    I18n.current = locale
    I18n.saveSetting(locale)
    -- Aplica fonte do locale (locales com `font = "path"` trocam o TTF).
    local ok, FontManager = pcall(require, "src.ui.FontManager")
    if ok and FontManager and FontManager.setFontPath then
        FontManager.setFontPath(I18n.getFont(locale))
    end
    if not silent then fireLocaleChanged() end
    return true
end

-- Avanca pra proximo locale disponivel (uso do botao em Settings).
function I18n.cycleLocale()
    local idx = 1
    for i, code in ipairs(I18n.available) do
        if code == I18n.current then idx = i; break end
    end
    local next = I18n.available[(idx % #I18n.available) + 1]
    I18n.setLocale(next)
    return I18n.current
end

-- Resolve chave dot-separated num table aninhado.
local function lookup(data, key)
    local cursor = data
    for segment in tostring(key):gmatch("[^%.]+") do
        if type(cursor) ~= "table" then return nil end
        cursor = cursor[segment]
    end
    if type(cursor) == "string" then return cursor end
    return nil
end

-- Substitui placeholders `{nome}` pelos valores em `vars`.
local function substitute(template, vars)
    if not vars then return template end
    return (template:gsub("%{(%w+)%}", function(k)
        local v = vars[k]
        if v == nil then return "{" .. k .. "}" end
        return tostring(v)
    end))
end

-- Traducao: retorna string do locale atual para `key`.
-- Cadeia de fallback: current -> FALLBACK_LOCALE -> `fallback` param -> key literal.
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

-- Atalho: aceita carta (tabela com .id/.name/.description) ou id string.
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

-- Constroi o table de variaveis injetaveis a partir das stats da carta.
-- Permite que descricoes usem {atk}/{def}/{cost}/{value}/{stacks} e fiquem
-- consistentes mesmo quando o gameplay alterar a stat (ex: buff de Forca).
local function cardVars(card)
    local vars = {
        atk   = card.attack,
        def   = card.defense,
        cost  = card.cost,
    }
    local effects = card.effects
    if type(effects) == "table" and effects[1] then
        local e = effects[1]
        vars.value  = e.value
        vars.stacks = e.stacks
    end
    return vars
end

-- Traduz um efeito de carta (tabela `{ type, value, stacks, target, description }`).
-- Chaves suportadas: effects.<type>_<value>  (para efeitos com value = identificador
-- string tipo "lightning" / "vulnerable") e effects.<type> (genérica, usa {value}/{stacks}/{target}).
-- Fallback: effect.description literal (antiga PT-BR hard-coded), depois effect.type.
function I18n.effectDesc(effect)
    if not effect then return "" end
    local t = effect.type
    local vars = {
        value  = effect.value,
        stacks = effect.stacks,
        target = effect.target,
    }
    if t and type(effect.value) == "string" then
        local MISS = "\0__miss__\0"
        local compound = "effects." .. t .. "_" .. effect.value
        local v = I18n.t(compound, vars, MISS)
        if v ~= MISS then return v end
    end
    return I18n.t("effects." .. (t or "unknown"), vars,
                  effect.description or t or "?")
end

function I18n.cardDesc(cardOrId)
    local id, fallback, vars
    if type(cardOrId) == "table" then
        id = cardOrId.id
        fallback = cardOrId.description
        vars = cardVars(cardOrId)
    else
        id = tostring(cardOrId)
    end
    if not id then return fallback or "" end
    return I18n.t("cards." .. id .. ".desc", vars, fallback or "")
end

-- Persistencia: salva locale no save dir do LOVE.
function I18n.saveSetting(locale)
    if not (love and love.filesystem and love.filesystem.write) then return end
    local content = "return " .. string.format("%q", locale) .. "\n"
    love.filesystem.write(SETTINGS_FILE, content)
end

function I18n.loadSetting()
    if not (love and love.filesystem and love.filesystem.getInfo) then return nil end
    if not love.filesystem.getInfo(SETTINGS_FILE) then return nil end
    local chunk, err = love.filesystem.load(SETTINGS_FILE)
    if not chunk then
        print("[I18n] Falha ao carregar settings: " .. tostring(err))
        return nil
    end
    local ok, result = pcall(chunk)
    if ok and type(result) == "string" then return result end
    return nil
end

return I18n
