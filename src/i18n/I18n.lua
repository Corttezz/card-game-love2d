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
-- SANDBOX de ferramenta — mesma proteção do engine/SaveManager.lua (PATHS_TOOL).
-- Antes isto era uma constante fixa e ficava FORA do sandbox: qualquer tool que
-- trocasse locale (o `test_i18n` percorre os 5 idiomas) sobrescrevia o idioma
-- REAL do jogador. Rodar `love . test_all` deixava o jogo em alemão — foi o que
-- aconteceu em Set/2026. `run`/`settings` já eram protegidos; este arquivo não.
local function settingsFile()
    return _G.HEADLESS_TOOL and "i18n_settings.tool.lua" or "i18n_settings.lua"
end

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
    -- FORCE de ferramenta tem precedencia sobre o idioma persistido.
    -- Motivo (Set/2026): captura visual precisa ser DETERMINISTICA no idioma.
    -- O main.lua ja setava pt_BR pros tools de screenshot_/preview_, mas 19
    -- deles chamam I18n.init() DEPOIS disso -- e o init relia o save por cima,
    -- desfazendo o force. A trava tem que morar AQUI, onde todo caminho passa.
    -- Tool que quer outro idioma seta _G.TOOL_FORCE_LOCALE antes do init.
    local saved = _G.TOOL_FORCE_LOCALE or I18n.loadSetting()
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
    -- "Já é o atual" só vale com a tabela CARREGADA: sem I18n.init() o
    -- current nasce pt_BR com data vazia, e setLocale("pt_BR") saía cedo —
    -- todo I18n.t caía no fallback do código e o teste passava por acaso
    -- (smoke_acts lia "Catacumbas" do Config, não do locale; Out/2026).
    if locale == I18n.current and I18n.data[locale] then return true end
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
-- consistentes mesmo quando o gameplay alterar a stat (ex: forja +N).
-- Auditoria Jul/2026: efeitos 2 e 3 tambem expostos ({value2}/{stacks2}/
-- {duration2}/{value3}) — antes so o effects[1] interpolava e toda carta
-- multi-efeito acabava com numero hard-coded que apodrecia a cada rebalance.
local function cardVars(card)
    local vars = {
        atk   = card.attack,
        def   = card.defense,
        cost  = card.cost,
    }
    local effects = card.effects
    if type(effects) == "table" then
        -- Auditoria de cartas (Out/2026): ate o 4o efeito (Tempestade
        -- Primordial tinha "+1 de Foco" cravado no 4o) e {pct} = percentual
        -- de um *_multiplier (1.5 -> 50), pro "+50%" acompanhar o dado.
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

-- Traduz um efeito de carta (tabela `{ type, value, stacks, target, description }`).
-- Chaves suportadas: effects.<type>_<value>  (para efeitos com value = identificador
-- string tipo "lightning" / "vulnerable") e effects.<type> (genérica, usa {value}/{stacks}/{target}).
-- Fallback: effect.description literal (antiga PT-BR hard-coded), depois effect.type.
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
    -- Compostos (auditoria de cartas Out/2026): o IDENTIFICADOR que muda o
    -- texto pode morar em `value` (apply_debuff "poison"), `orbType`
    -- (channel_orb "ice") ou `debuffName` (on_attack_debuff "poison"). Antes
    -- so `value` era olhado e todo canalizar virava "Canaliza 1 orbe".
    local qualifier = (type(effect.value) == "string" and effect.value)
        or effect.orbType or effect.debuffName
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
    -- BUG Jul/2026 ("valor {value}" cru na loja): chamadores passam tabela
    -- MÍNIMA ({id, description} — ex: ofertas da CardRewardScreen) ou só o id.
    -- Sem effects/stats, os placeholders {value}/{atk}/{def} ficavam crus na
    -- tela. Busca os dados completos no CardDatabase (require lazy — sem
    -- ciclo de load; getCard é barato, tabela em memória).
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

-- Persistencia: salva locale no save dir do LOVE.
-- Out/2026: grava pelo caminho único e seguro do SaveManager (tmp + verificação
-- + .bak) e lê com recuperação .tmp/.bak. Formato: `return { locale = "xx" }`
-- (tabela, que é o que o SaveManager valida). O formato antigo `return "xx"`
-- continua sendo lido, sem poder de código (loadDataChunk).
function I18n.saveSetting(locale)
    if not (love and love.filesystem and love.filesystem.write) then return end
    local ok, SaveManager = pcall(require, "engine.SaveManager")
    if not ok then
        print("[I18n] SaveManager indisponivel, idioma nao salvo: " .. tostring(SaveManager))
        return
    end
    local content = "return { locale = " .. string.format("%q", locale) .. " }\n"
    -- Arquivo no formato legado (`return "xx"`) sai antes: senão a rotação do
    -- writeFile o julgaria ilegível e geraria uma cópia de quarentena à toa.
    local f = settingsFile()
    if love.filesystem.getInfo(f) then
        local chunk = SaveManager.loadDataChunk(f)
        local okc, old = pcall(chunk or error)
        if okc and type(old) == "string" then love.filesystem.remove(f) end
    end
    local wrote, err = SaveManager.writeFile(f, content)
    if not wrote then print("[I18n] Falha ao salvar idioma: " .. tostring(err)) end
end

function I18n.loadSetting()
    if not (love and love.filesystem and love.filesystem.getInfo) then return nil end
    local ok, SaveManager = pcall(require, "engine.SaveManager")
    if not ok then return nil end
    local f = settingsFile()
    -- Formato legado primeiro (o chunk devolve a string direto): passar ele
    -- pelo readDataFile o marcaria como corrompido e geraria cópia de quarentena.
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
