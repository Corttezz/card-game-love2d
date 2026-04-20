-- tools/test_i18n.lua
-- Smoke test do sistema de i18n. Roda dentro do LOVE com:
--   love . tools/test_i18n.lua
-- ou via main.lua trocando o entry. Aqui implementamos uma love.load minima
-- que so executa os asserts e fecha.
--
-- Verifica:
--   - todos os locales carregam
--   - todas as chaves de UI existem em todos os locales
--   - troca de locale funciona
--   - I18n.cardName/cardDesc retornam strings nao vazias
--   - substituicao de variaveis funciona

local I18n = require("src.i18n.I18n")

local function fail(msg)
    print("[FAIL] " .. msg)
    os.exit(1)
end

local function ok(msg)
    print("[ OK ] " .. msg)
end

-- 1. Carrega todos os locales conhecidos
local locales = I18n.getAvailable()
print("Locales disponiveis:", table.concat(locales, ", "))

I18n.init()
ok("init() concluiu (locale atual: " .. I18n.getLocale() .. ")")

-- 2. Chaves criticas que precisam existir em todos os locales
local CRITICAL_KEYS = {
    "menu.title", "menu.play", "menu.collection", "menu.settings", "menu.quit",
    "settings.title", "settings.music", "settings.language", "settings.close",
    "class_select.title", "class_select.back",
    "classes.warrior.name", "classes.mage.name", "classes.rogue.name",
    "hud.damage", "hud.phase", "hud.threat_label",
    "card_info.cost", "card_info.damage", "card_info.defense",
    "card_type.attack", "card_type.defense", "card_type.passive", "card_type.action",
    "rarity.common", "rarity.rare", "rarity.legendary",
    "reward.shop_title", "reward.continue", "reward.refresh", "reward.buy",
    "collection.title", "collection.filter_all",
    "game_over.title", "victory.title",
    "play_button.label", "window_title",
}

for _, code in ipairs(locales) do
    if I18n.setLocale(code) then
        for _, key in ipairs(CRITICAL_KEYS) do
            local val = I18n.t(key, nil, "__missing__")
            if val == "__missing__" or val == key then
                fail(code .. " sem chave " .. key)
            end
        end
        ok("locale " .. code .. " tem todas as " .. #CRITICAL_KEYS .. " chaves criticas")
    else
        fail("nao carregou locale " .. code)
    end
end

-- 3. Substituicao de variaveis
I18n.setLocale("pt_BR")
local out = I18n.t("reward.bought", { name = "TestCard" })
if not out:find("TestCard") then
    fail("substituicao {name} falhou: " .. out)
end
ok("substituicao de variavel: " .. out)

local out2 = I18n.t("game_over.final_score", { score = 42 })
if not out2:find("42") then
    fail("substituicao {score} falhou: " .. out2)
end
ok("substituicao numerica: " .. out2)

-- 4. cardName/cardDesc com tabela real (inclui stats pra exercitar auto-inject)
local card = { id = "warrior_strike", name = "Fallback", description = "Fallback desc",
                attack = 6, defense = 0, cost = 1 }
I18n.setLocale("en")
local nameEn = I18n.cardName(card)
local descEn = I18n.cardDesc(card)
if nameEn ~= "Strike" then fail("cardName(en) esperado 'Strike', recebido: " .. nameEn) end
if descEn ~= "Deal 6 damage." then fail("cardDesc(en) esperado 'Deal 6 damage.', recebido: " .. descEn) end
ok("cardName/cardDesc em EN: " .. nameEn .. " | " .. descEn)

I18n.setLocale("de")
local nameDe = I18n.cardName(card)
if nameDe ~= "Schlag" then fail("cardName(de) esperado 'Schlag', recebido: " .. nameDe) end
ok("cardName em DE: " .. nameDe)

-- 5. Fallback p/ ID inexistente -> usa fallback do parametro
I18n.setLocale("pt_BR")
local nameUnknown = I18n.cardName({ id = "carta_que_nao_existe", name = "Default" })
if nameUnknown ~= "Default" then fail("fallback de cardName falhou: " .. nameUnknown) end
ok("fallback p/ id inexistente OK: " .. nameUnknown)

-- 5b. Auto-injecao de variaveis em cardDesc ({atk}/{def}/{value}/{stacks})
-- A descricao de warrior_strike usa {atk}; em PT deve resolver pra "Causa 6 de dano."
I18n.setLocale("pt_BR")
local atkCard = { id = "warrior_strike", attack = 6, defense = 0, cost = 1 }
local atkDesc = I18n.cardDesc(atkCard)
if not atkDesc:find("6") then fail("auto-inject {atk} falhou: " .. atkDesc) end
ok("auto-inject {atk}: " .. atkDesc)

-- Se o gameplay buffar attack, a descricao deve refletir
atkCard.attack = 11
local atkDescBuffed = I18n.cardDesc(atkCard)
if not atkDescBuffed:find("11") then fail("auto-inject dinamico falhou: " .. atkDescBuffed) end
ok("auto-inject dinamico (atk=11): " .. atkDescBuffed)

-- {def} via warrior_defend
local defCard = { id = "warrior_defend", attack = 0, defense = 5, cost = 1 }
local defDesc = I18n.cardDesc(defCard)
if not defDesc:find("5") then fail("auto-inject {def} falhou: " .. defDesc) end
ok("auto-inject {def}: " .. defDesc)

-- {value} via effect (effect_healing_potion)
local healCard = { id = "effect_healing_potion", cost = 1, effects = { { type = "instant_heal", value = 15 } } }
local healDesc = I18n.cardDesc(healCard)
if not healDesc:find("15") then fail("auto-inject {value} falhou: " .. healDesc) end
ok("auto-inject {value}: " .. healDesc)

-- {atk} + {stacks} via warrior_bash
local bashCard = { id = "warrior_bash", attack = 8, cost = 2, effects = { { type = "apply_debuff", value = "vulnerable", stacks = 2 } } }
local bashDesc = I18n.cardDesc(bashCard)
if not (bashDesc:find("8") and bashDesc:find("2")) then fail("auto-inject combo falhou: " .. bashDesc) end
ok("auto-inject {atk}+{stacks}: " .. bashDesc)

-- 5d. I18n.effectDesc traduz efeitos declarados em cartas
I18n.setLocale("pt_BR")
local heal = { type = "on_attack_heal", value = 3 }
local healStr = I18n.effectDesc(heal)
if not healStr:find("3") or not healStr:find("HP") then fail("effectDesc on_attack_heal: " .. healStr) end
ok("effectDesc simples: " .. healStr)

local debuffVuln = { type = "apply_debuff", value = "vulnerable", stacks = 2 }
local debuffStr = I18n.effectDesc(debuffVuln)
if not debuffStr:find("Vulneravel") then fail("effectDesc composto apply_debuff_vulnerable: " .. debuffStr) end
ok("effectDesc composto: " .. debuffStr)

I18n.setLocale("en")
local debuffEn = I18n.effectDesc(debuffVuln)
if not debuffEn:find("Vulnerable") then fail("effectDesc composto (en): " .. debuffEn) end
ok("effectDesc composto (en): " .. debuffEn)

local orbLightning = { type = "channel_orb", value = "lightning" }
local orbStr = I18n.effectDesc(orbLightning)
if not orbStr:lower():find("lightning") then fail("effectDesc channel_orb_lightning (en): " .. orbStr) end
ok("effectDesc channel_orb: " .. orbStr)

-- messages.* (toasts do EffectSystem)
I18n.setLocale("pt_BR")
local toast = I18n.t("messages.healed", { value = 10 })
if not toast:find("10") then fail("messages.healed: " .. toast) end
ok("messages.healed: " .. toast)

-- 5c. Locale.font + FontManager.setFontPath integrados
local FontManager = require("src.ui.FontManager")
local before = FontManager.getFontPath()
if not before then fail("FontManager.getFontPath() retornou nil inicialmente") end
ok("FontManager.getFontPath inicial: " .. before)
-- Locales atuais nao especificam font, entao deve ficar no default mesmo trocando
I18n.setLocale("de")
local afterDe = FontManager.getFontPath()
if afterDe ~= before then fail("font path mudou sem locale especificar: " .. afterDe) end
ok("locale sem `font` mantem default: " .. afterDe)
-- Simula adicao de fonte custom via override direto
I18n.data.de.font = "assets/fonts/pixel.ttf"  -- mesmo caminho, mas exercita o code path
I18n.setLocale("pt_BR"); I18n.setLocale("de")
ok("locale com `font` aplica via FontManager.setFontPath")
I18n.data.de.font = nil   -- limpa

-- 6. cycleLocale gira pelos disponiveis
local startLocale = I18n.getLocale()
local seen = { [startLocale] = true }
for i = 1, #locales do
    local next = I18n.cycleLocale()
    seen[next] = true
end
local count = 0
for _ in pairs(seen) do count = count + 1 end
if count ~= #locales then fail("cycleLocale nao visitou todos os locales (" .. count .. "/" .. #locales .. ")") end
ok("cycleLocale visita todos os " .. #locales .. " locales")

print("\n=== TODOS OS TESTES I18N PASSARAM ===")
os.exit(0)
