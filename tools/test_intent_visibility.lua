-- tools/test_intent_visibility.lua
-- TRAVA da NÉVOA DE INTENÇÃO (Out/2026, src/systems/IntentVisibility.lua).
--
-- Ideia do dono: nos biomas do fim da jornada a nevasca esconde parte do que
-- o inimigo anuncia (tipo sem número; na névoa fechada nem o tipo). Esta
-- suíte trava o que não pode quebrar:
--   1. DADOS: toda regra de névoa aponta pra um bioma real; frost e dusk
--      ligados, os outros limpos; a curva de densidade É a do clima na tela;
--      densidade cresce com o andar, o salão tem a sua, o endless cicla.
--   2. RESOLUÇÃO: a mesma rolagem dá o mesmo nível; sem névoa nem véu o Rng
--      NÃO anda; a rolagem usa o stream "misc" (o "enemy" fica intocado);
--      a mesma seed reproduz a sequência.
--   3. VÉU do inimigo (kit/fase) combina pelo pior nível; chance parcial.
--   4. REVELAÇÃO: carta revela agora + N; pulso do Raio revela o PRÓXIMO.
--   5. CONGELADO: o golpe escondido acerta EXATAMENTE o número congelado
--      (CLAUDE.md §6) — a névoa só muda a leitura.
--   6. HUD: intentSpec mostra "?" / desconhecido, tooltip da névoa nos 5
--      idiomas, nenhum número vaza; drawIntent + véu desenham sem erro.
--   7. CONTADORES: efeito `reveal_intent` existe, 4 cartas o carregam
--      (uma por classe + a neutra), o orbe de Raio revela o próximo anúncio.
--   8. MUNDO: o WeatherEngine engrossa quando o número some e volta quando
--      aparece; salão e inimigo morto não empurram o clima; reset zera.
--   9. PILOTO: getKnownIntent / getKnownIncomingDamage nunca entregam número
--      escondido.
--  10. TUTORIAL: conversa `fog` no roteiro, textos nos 5 idiomas.
--
--   love . test_one test_intent_visibility

local TK = require("tools.testkit")

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

local function hasNumber(s, n)
    return s ~= nil and s:find(tostring(n), 1, true) ~= nil
end

function M.run()
    local t = TK.new("névoa de intenção: dados, resolução, véu, revelação, congelamento, HUD, mundo")
    TK.bootstrap()
    TK.seedRng(777)

    local IV = require("src.systems.IntentVisibility")
    local Fog = require("src.data.intent_fog")
    local biomes = require("src.data.biomes")
    local Enemy = require("src.entities.Enemy")
    local EnemyKits = require("src.data.enemies")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local RunModifiers = require("src.systems.RunModifiers")
    local WeatherEngine = require("engine.WeatherEngine")
    local I18n = require("src.i18n.I18n")
    local savedLocale = I18n.getLocale and I18n.getLocale() or "pt_BR"
    I18n.setLocale("pt_BR", true)

    -- ======================================================================
    -- 1. DADOS
    -- ======================================================================
    local list = biomes.list or biomes
    local byId = {}
    for _, b in ipairs(list) do byId[b.id] = b end
    for id, rule in pairs(Fog.biomes) do
        t:truthy("névoa '" .. id .. "' aponta pra um bioma real", byId[id] ~= nil)
        t:check(id .. ": base <= peak (0..1)", rule.base >= 0 and rule.base <= rule.peak and rule.peak <= 1)
        t:check(id .. ": heavy em 0..1", (rule.heavy or 0) >= 0 and (rule.heavy or 0) <= 1)
        t:check(id .. ": hall em 0..1", (rule.hall or 0) >= 0 and (rule.hall or 0) <= 1)
        t:truthy(id .. ": cor do véu", type(rule.color) == "table" and #rule.color >= 3)
    end
    t:truthy("frost (ato 4) LIGADO por padrão", Fog.biomes.frost ~= nil)
    t:truthy("dusk (ato 6) LIGADO por padrão", Fog.biomes.dusk ~= nil)
    for _, id in ipairs({ "fields", "highlands", "abyss", "marsh" }) do
        t:falsy(id .. " sem névoa (atos 1-3 e 5 intactos)", Fog.biomes[id])
    end
    for _, lvl in ipairs({ "type_only", "hidden" }) do
        local b = Fog.worldBoost[lvl]
        t:check("worldBoost." .. lvl .. " em 0..1", type(b) == "number" and b > 0 and b <= 1)
    end
    t:check("hidden empurra o clima mais que type_only",
        Fog.worldBoost.hidden > Fog.worldBoost.type_only)

    -- a curva da névoa É a do clima (copiada de propósito: roda sem motor)
    for _, p in ipairs({ 0, 0.2, 0.5, 0.8, 1 }) do
        t:near("curva(" .. p .. ") = WeatherEngine.intensityFor", IV.fogCurve(p),
            WeatherEngine.intensityFor(p), 1e-9)
    end

    -- contexto por ato: só os biomas da tabela recebem névoa
    for act = 1, 6 do
        local run = { actNumber = act, floorInAct = 3, currentNode = { type = "battle" } }
        local bid = IV.biomeIdFor(run)
        local ctx = IV.contextFor(run)
        t:eq("ato " .. act .. " (" .. tostring(bid) .. "): névoa=" .. tostring(Fog.biomes[bid] ~= nil),
            ctx ~= nil, Fog.biomes[bid] ~= nil)
        if ctx then t:eq("ato " .. act .. ": contexto carrega o bioma", ctx.biomeId, bid) end
    end
    t:eq("sem run = sem contexto", IV.contextFor(nil), nil)

    -- densidade: 1º andar = base, porta do castelo = peak, monótona
    local function ctxAt(floor, nodeType)
        return IV.contextFor({ actNumber = 4, floorInAct = floor, currentNode = { type = nodeType or "battle" } })
    end
    local fr = Fog.biomes.frost
    t:near("frost andar 1 = base", IV.density(ctxAt(1)), fr.base, 1e-6)
    t:near("frost andar 8 (estrada) = peak", IV.density(ctxAt(8)), fr.peak, 1e-6)
    local prev = -1
    local mono = true
    for f = 1, 8 do
        local d = IV.density(ctxAt(f))
        if d < prev - 1e-9 then mono = false end
        prev = d
    end
    t:truthy("densidade cresce com o andar (como a neve)", mono)
    t:near("salão do chefe = densidade fixa `hall`", IV.density(ctxAt(8, "boss")), fr.hall, 1e-6)
    t:truthy("salão marcado no contexto", ctxAt(8, "boss").hall == true)
    t:eq("densidade sem contexto = 0", IV.density(nil), 0)

    -- "subjetivo, não cego" (lead): o TIPO só some no pico da nevasca
    local s1 = IV.expectedShares(ctxAt(1))
    t:eq("frost andar 1: NUNCA some o tipo (hidden = 0)", s1.hidden, 0)
    t:check("frost andar 1: um terço dos anúncios sem número", s1.type_only > 0.3 and s1.type_only < 0.4)
    local s7 = IV.expectedShares(ctxAt(7))
    t:check("frost andar 7 (pico): hidden entre 15% e 30%", s7.hidden >= 0.15 and s7.hidden <= 0.30)
    local sh = IV.expectedShares(ctxAt(8, "boss"))
    t:check("frost salão: hidden entre 10% e 25%", sh.hidden >= 0.10 and sh.hidden <= 0.25)
    for _, bid in ipairs({ "frost", "dusk" }) do
        local sAct = 0
        for f = 1, 7 do
            sAct = sAct + IV.expectedShares(IV.contextFor({ actNumber = (bid == "frost") and 4 or 6,
                floorInAct = f, currentNode = { type = "battle" } })).hidden
        end
        t:check(bid .. ": hidden médio na estrada abaixo de 10%", sAct / 7 < 0.10)
    end
    t:eq("stormCurve no salão = 1", IV.stormCurve(ctxAt(8, "boss")), 1)
    t:eq("stormCurve no andar 1 = 0", IV.stormCurve(ctxAt(1)), 0)

    -- endless cicla 4,5,6,1,2,3 (mesmo wrap do EnemyRoster.biomeAct)
    local function endlessCtx(floor)
        return IV.contextFor({ actNumber = 6, endlessMode = true, currentFloor = floor,
            floorInAct = 2, currentNode = { type = "battle" } })
    end
    t:eq("endless andar 25 = geleira", IV.biomeIdFor({ actNumber = 6, endlessMode = true, currentFloor = 25 }), "frost")
    t:eq("endless andar 41 = crepúsculo", IV.biomeIdFor({ actNumber = 6, endlessMode = true, currentFloor = 41 }), "dusk")
    t:eq("endless andar 49 = campos (sem névoa)", endlessCtx(49), nil)
    t:truthy("endless andar 25 tem névoa", endlessCtx(25) ~= nil)

    -- ======================================================================
    -- 2. RESOLUÇÃO (rolagem injetada)
    -- ======================================================================
    local wolf = Enemy:new(100, 10, "frost_wolf")   -- kit SEM véu
    t:eq("inimigo sem contexto nasce com visibilidade cheia", wolf:getIntentVisibility(), "full")
    wolf.fogContext = ctxAt(8)                       -- densidade = peak (0.80)
    local dens = IV.density(wolf.fogContext)
    local function roll(v) return function() return v end end
    local lvl, cause = IV.resolve(wolf, roll(0.99))
    t:eq("rolagem acima da densidade = clareira (full)", lvl, "full")
    t:eq("clareira não tem causa", cause, nil)
    lvl, cause = IV.resolve(wolf, roll(dens - 0.01))
    t:eq("rolagem logo abaixo da densidade = type_only", lvl, "type_only")
    t:eq("causa = névoa", cause, "fog")
    lvl, cause = IV.resolve(wolf, roll(dens * fr.heavy - 0.01))
    t:eq("rolagem dentro da fração `heavy` = hidden", lvl, "hidden")
    t:eq("causa hidden = névoa", cause, "fog")

    -- sem névoa e sem véu o Rng não anda (a rolagem nem é chamada)
    wolf.fogContext = nil
    local called = false
    lvl = IV.resolve(wolf, function() called = true; return 0 end)
    t:eq("sem névoa/véu: full", lvl, "full")
    t:falsy("sem névoa/véu: a rolagem NÃO é chamada", called)

    -- stream: "misc" anda, "enemy" fica intocado
    wolf.fogContext = ctxAt(8)
    local rng = TK.seedRng(9001)
    local function snap(stream)
        local st = rng:getStreamState(stream)
        return tostring(st.state) .. "#" .. tostring(st.counter)
    end
    local enemyBefore, miscBefore = snap("enemy"), snap("misc")
    wolf:refreshIntentVisibility()
    t:eq("resolver não mexe no stream 'enemy'", snap("enemy"), enemyBefore)
    t:check("resolver anda o stream 'misc'", snap("misc") ~= miscBefore)

    -- mesma seed = mesma sequência de níveis
    local function sequence(seed)
        TK.seedRng(seed)
        local e = Enemy:new(100, 10, "frost_wolf")
        e.fogContext = ctxAt(5)
        local out = {}
        for _ = 1, 24 do
            e:rollIntent()
            out[#out + 1] = e:getIntentVisibility()
        end
        return table.concat(out, ",")
    end
    local sA, sB = sequence(4321), sequence(4321)
    t:eq("mesma seed: mesma sequência de visibilidade", sA, sB)
    t:truthy("a sequência tem clareira E névoa (andar 5)", sA:find("full") and (sA:find("type_only") or sA:find("hidden")))

    -- ======================================================================
    -- 3. VÉU do inimigo
    -- ======================================================================
    t:eq("worst(type_only, hidden) = hidden", IV.worst("type_only", "hidden"), "hidden")
    t:eq("worst(full, type_only) = type_only", IV.worst("full", "type_only"), "type_only")
    t:eq("worst(nil, full) = full", IV.worst(nil, "full"), "full")

    for id, kit in pairs(EnemyKits.KITS) do
        local specs = {}
        if kit.veil then specs[#specs + 1] = { id, kit.veil } end
        for i, ph in ipairs(kit.phases or {}) do
            if ph.veil then specs[#specs + 1] = { id .. "/fase" .. i, ph.veil } end
        end
        for _, s in ipairs(specs) do
            local v = s[2]
            t:check("véu de " .. s[1] .. ": nível válido (" .. tostring(v.level) .. ")",
                v.level == "type_only" or v.level == "hidden")
            t:check("véu de " .. s[1] .. ": chance em (0,1]",
                (v.chance or 1) > 0 and (v.chance or 1) <= 1)
        end
    end
    t:truthy("frost_wight tem véu", EnemyKits.KITS.frost_wight.veil)
    t:truthy("rime_shaman tem véu", EnemyKits.KITS.rime_shaman.veil)
    t:truthy("dusk_shade tem véu", EnemyKits.KITS.dusk_shade.veil)
    local eq = EnemyKits.KITS.eclipse_queen
    t:eq("Rainha do Eclipse: véu só na FASE 2", eq.veil, nil)
    t:eq("Rainha do Eclipse fase 2: véu hidden", eq.phases[1].veil and eq.phases[1].veil.level, "hidden")

    TK.seedRng(11)
    local wight = Enemy:new(100, 10, "frost_wight")   -- véu type_only, chance 1, SEM névoa
    local allVeiled = true
    for _ = 1, 12 do
        wight:rollIntent()
        if wight:getIntentVisibility() ~= "type_only" or wight.intentVeilCause ~= "veil" then
            allVeiled = false
        end
    end
    t:truthy("espectro do gelo: TODO anúncio sem número, causa = véu", allVeiled)

    local shaman = Enemy:new(100, 10, "rime_shaman")  -- chance 0.5
    t:eq("xamã: rolagem alta = número aparece", (IV.resolve(shaman, roll(0.9))), "full")
    t:eq("xamã: rolagem baixa = type_only", (IV.resolve(shaman, roll(0.1))), "type_only")

    -- véu + névoa: o pior vence
    local shade = Enemy:new(100, 10, "dusk_shade")     -- véu type_only 0.7
    shade.fogContext = IV.contextFor({ actNumber = 6, floorInAct = 8, currentNode = { type = "battle" } })
    local dd = IV.density(shade.fogContext)
    local hv = Fog.biomes.dusk.heavy
    -- 1ª rolagem (névoa) cai no `heavy` → hidden; 2ª (véu) cai → type_only; fica hidden
    local seq = { dd * hv * 0.5, 0.1 }
    local i = 0
    lvl = IV.resolve(shade, function() i = i + 1; return seq[i] end)
    t:eq("névoa hidden + véu type_only = hidden (o pior)", lvl, "hidden")
    -- névoa clareira (0.99) + véu (0.1) → type_only por causa do véu
    i = 0; seq = { 0.99, 0.1 }
    lvl, cause = IV.resolve(shade, function() i = i + 1; return seq[i] end)
    t:eq("clareira + véu = type_only", lvl, "type_only")
    t:eq("causa = véu", cause, "veil")

    -- fase: a Rainha só esconde depois do Eclipse
    local queen = Enemy:new(100, 10, "eclipse_queen")
    t:eq("Rainha fase 1: sem véu", queen:veilSpec(), nil)
    queen.health = 40
    queen:_checkPhase()
    t:truthy("Rainha fase 2: véu ativo", queen:veilSpec() ~= nil)
    t:eq("Rainha fase 2: rolagem baixa = hidden", (IV.resolve(queen, roll(0.1))), "hidden")

    -- ======================================================================
    -- 4. REVELAÇÃO
    -- ======================================================================
    wight:rollIntent()
    t:eq("(pré) espectro escondido", wight:getIntentVisibility(), "type_only")
    wight:revealIntent(2)
    t:eq("revealIntent: agora cheio", wight:getIntentVisibility(), "full")
    t:eq("revealIntent: causa reveal", wight.intentVeilCause, "reveal")
    wight:rollIntent()
    t:eq("revealIntent(2): o próximo anúncio também vem inteiro", wight:getIntentVisibility(), "full")
    wight:rollIntent()
    t:eq("...e o seguinte volta ao véu", wight:getIntentVisibility(), "type_only")
    wight:revealNextIntent(1)
    t:eq("revealNextIntent: o corrente NÃO muda", wight:getIntentVisibility(), "type_only")
    wight:rollIntent()
    t:eq("revealNextIntent: o próximo vem inteiro", wight:getIntentVisibility(), "full")
    wight:rollIntent()
    t:eq("...e depois o véu volta", wight:getIntentVisibility(), "type_only")

    -- ======================================================================
    -- 5. CONGELADO: o golpe escondido acerta o número congelado
    -- ======================================================================
    TK.seedRng(2024)
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.3)
    local run = g.runManager.currentRun
    run.actNumber, run.floorInAct, run.currentNode = 4, 5, { type = "battle" }
    g.enemy = EnemyRoster.spawn(Enemy, "frost_wight", { health = 500, damage = 10 })
    RunModifiers.decorateEnemy(run, g.enemy)
    g._deathHandled, g._deathStaged = false, false
    t:truthy("decorateEnemy entrega o contexto do bioma ao inimigo",
        g.enemy.fogContext and g.enemy.fogContext.biomeId == "frost")
    t:eq("espectro na geleira: escondido desde o 1º anúncio", g.enemy:getIntentVisibility(), "type_only")
    g.enemy:forceIntent("wight_claw", g.player)
    g.player.health, g.player.armor = g.player.maxHealth, 0
    g.battleTurn = 1
    g.enemy.intentVisibility = "hidden"
    local real = g.enemy:getIncomingDamage(g.player)
    t:check("golpe congelado tem número (" .. tostring(real) .. ")", real > 0)
    t:eq("getKnownIncomingDamage escondido = nil", g.enemy:getKnownIncomingDamage(g.player), nil)
    local known = g.enemy:getKnownIntent(g.player)
    t:eq("getKnownIntent hidden: kind desconhecido", known.kind, "unknown")
    t:eq("getKnownIntent hidden: sem perHit", known.perHit, nil)
    g.enemy.intentVisibility = "type_only"
    known = g.enemy:getKnownIntent(g.player)
    t:eq("getKnownIntent type_only: o tipo aparece", known.kind, "attack")
    t:eq("getKnownIntent type_only: sem perHit", known.perHit, nil)
    t:eq("getKnownIntent type_only: sem hits", known.hits, nil)
    t:eq("getKnownIntent type_only: sem armor", known.armor, nil)
    t:truthy("getKnownIntent type_only: marcado hidden", known.hidden)
    g.enemy.intentVisibility = "full"
    known = g.enemy:getKnownIntent(g.player)
    t:eq("getKnownIntent full: perHit igual ao congelado", known.perHit, g.enemy:getIntent().perHit)
    t:eq("getKnownIncomingDamage full = real", g.enemy:getKnownIncomingDamage(g.player), real)

    g.enemy.intentVisibility = "hidden"
    local hpBefore = g.player.health
    g.turn = "enemy"
    g._enemyActing = false
    g:enemyTurn()
    TK.pump(g, 8)
    t:eq("golpe ESCONDIDO acerta exatamente o número congelado", hpBefore - g.player.health, real)
    t:eq("depois do turno o inimigo anunciou de novo (visibilidade válida)",
        IV.RANK[g.enemy:getIntentVisibility()] ~= nil, true)

    -- ======================================================================
    -- 6. HUD: intentSpec e desenho
    -- ======================================================================
    local EnemyHud = require("src.ui.EnemyHud")
    local IntentVeil = require("src.ui.IntentVeil")
    g.enemy:forceIntent("wight_claw", g.player)
    local n = g.enemy:intentHitDamage(g.player)
    g.enemy.intentVisibility, g.enemy.intentVeilCause = "full", nil
    local spec = EnemyHud.intentSpec(g.enemy, g.player)
    t:eq("full: texto = número", spec.text, tostring(n))
    t:eq("full: visibilidade no spec", spec.visibility, "full")

    g.enemy.intentVisibility, g.enemy.intentVeilCause = "type_only", "fog"
    spec = EnemyHud.intentSpec(g.enemy, g.player)
    t:eq("type_only: texto = ?", spec.text, I18n.t("enemy_kit.intent.unknown_value"))
    t:eq("type_only: ícone do tipo continua", spec.kind, "attack")
    t:eq("type_only: value zerado (nada pra interpolar)", spec.value, 0)
    t:falsy("type_only: o número NÃO vaza pelo tooltip", hasNumber(spec.body, n))
    t:truthy("type_only: tooltip explica a névoa", spec.body:find(I18n.t("enemy_kit.intent.veil_number"), 1, true))
    t:truthy("type_only: cor do véu do bioma", spec.veilColor ~= nil)

    g.enemy.intentVisibility, g.enemy.intentVeilCause = "hidden", "veil"
    spec = EnemyHud.intentSpec(g.enemy, g.player)
    t:eq("hidden: ícone desconhecido", spec.kind, "unknown")
    t:eq("hidden: sem texto", spec.text, nil)
    t:eq("hidden: sem extras", #spec.extras, 0)
    t:eq("hidden: título = Névoa", spec.title, I18n.t("enemy_kit.intent.veil_title"))
    t:falsy("hidden: o número NÃO vaza", hasNumber(spec.body, n))
    t:truthy("hidden: causa véu cita a criatura",
        spec.body:find(I18n.t("end_screen.enemy.frost_wight"), 1, true) ~= nil)
    local w, h = EnemyHud.getIntentDims(g.enemy, g.player)
    t:check("hidden: box tem medida", w > 0 and h > 0)

    for _, loc in ipairs(LOCALES) do
        I18n.setLocale(loc, true)
        for _, key in ipairs({ "veil_title", "veil_number", "veil_all", "veil_enemy", "veil_hint",
                               "veil_debuff", "unknown_value" }) do
            t:check(loc .. ": enemy_kit.intent." .. key, I18n.t("enemy_kit.intent." .. key, nil, "") ~= "")
        end
        t:check(loc .. ": status.intent_unknown.name", I18n.t("status.intent_unknown.name", nil, "") ~= "")
        t:check(loc .. ": effects.reveal_intent", I18n.t("effects.reveal_intent", nil, "") ~= "")
        t:check(loc .. ": messages.intent_revealed", I18n.t("messages.intent_revealed", nil, "") ~= "")
        local sp = EnemyHud.intentSpec(g.enemy, g.player)
        t:check(loc .. ": tooltip da névoa não vazia", sp.body ~= nil and #sp.body > 10)
    end
    I18n.setLocale("pt_BR", true)

    -- desenho: box + véu num canvas, o véu aparece depois de alguns quadros
    local realTime = love.timer.getTime
    local base = realTime()
    local fake = 0
    love.timer.getTime = function() return base + fake end
    IntentVeil.reset()
    local canvas = love.graphics.newCanvas(640, 480)
    local okDraw = t:noerror("drawIntent com névoa desenha sem erro", function()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        for k = 1, 8 do
            fake = k * 0.1
            EnemyHud.drawIntent(g.enemy, 320, 240, nil, nil, g.player)
        end
        love.graphics.setCanvas()
    end)
    if okDraw then
        t:check("véu visível sobre o box escondido (alpha > 0.3)", IntentVeil.currentAlpha(g.enemy) > 0.3)
        t:near("alvo do véu hidden", IntentVeil.alphaFor("hidden"), IntentVeil.ALPHA.hidden, 1e-9)
        t:eq("alvo do véu full = 0", IntentVeil.alphaFor("full"), 0)
        g.enemy.intentVisibility = "full"
        love.graphics.setCanvas(canvas)
        for k = 9, 30 do
            fake = k * 0.1
            EnemyHud.drawIntent(g.enemy, 320, 240, nil, nil, g.player)
        end
        love.graphics.setCanvas()
        t:check("revelado: o véu se dissipa (alpha < 0.05)", IntentVeil.currentAlpha(g.enemy) < 0.05)
    end
    love.timer.getTime = realTime
    IntentVeil.reset()

    -- ======================================================================
    -- 7. CONTADORES
    -- ======================================================================
    g.enemy.intentVisibility, g.enemy.intentVeilCause = "type_only", "fog"
    g.enemy._revealTurns = 0
    g.effectSystem:processEffectCard(g, { type = "reveal_intent", value = 2 })
    t:eq("reveal_intent: visibilidade cheia agora", g.enemy:getIntentVisibility(), "full")
    t:eq("reveal_intent 2: um anúncio seguinte guardado", g.enemy._revealTurns, 1)

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local carriers = {}
    for id, cd in pairs(db:getAllCards()) do
        for _, e in ipairs(cd.effects or {}) do
            if e.type == "reveal_intent" then carriers[#carriers + 1] = id end
        end
    end
    table.sort(carriers)
    t:eq("4 cartas revelam (uma por classe + neutra)", table.concat(carriers, ","),
        "effect_scroll_wisdom,mage_arcane_sight,rogue_expose_weakness,warrior_spot_weakness")
    local classes = {}
    for _, id in ipairs(carriers) do classes[db:getCard(id).class or "basic"] = true end
    for _, c in ipairs({ "warrior", "mage", "rogue", "basic" }) do
        t:truthy("classe " .. c .. " tem um contador", classes[c])
    end

    -- pulso do Raio revela o PRÓXIMO anúncio
    g.enemy.intentVisibility = "type_only"
    g.enemy._revealTurns = 0
    g.player.orbs = { { type = "lightning", value = 4 } }
    local ehp = g.enemy.health
    g.effectSystem:orbPassiveTick(g)
    TK.pump(g, 1.5)
    t:check("o pulso do Raio causou dano", g.enemy.health < ehp)
    t:eq("o pulso do Raio NÃO muda o anúncio corrente", g.enemy:getIntentVisibility(), "type_only")
    t:eq("o pulso do Raio revela o PRÓXIMO anúncio", g.enemy._revealTurns, 1)
    g.player.orbs = { { type = "ice", value = 4 } }
    g.enemy._revealTurns = 0
    g.effectSystem:orbPassiveTick(g)
    TK.pump(g, 1.5)
    t:eq("o pulso de Gelo não revela nada", g.enemy._revealTurns, 0)
    g.player.orbs = {}

    -- ======================================================================
    -- 8. MUNDO: o clima acompanha o estado
    -- ======================================================================
    IV.noteActive(g.enemy)
    g.enemy.intentVisibility = "hidden"
    t:near("worldFog hidden = boost da tabela", IV.worldFog(), Fog.worldBoost.hidden, 1e-9)
    g.enemy.intentVisibility = "type_only"
    t:near("worldFog type_only = boost da tabela", IV.worldFog(), Fog.worldBoost.type_only, 1e-9)
    g.enemy.intentVisibility = "full"
    t:eq("worldFog full = 0", IV.worldFog(), 0)
    t:eq("hook instalado no WeatherEngine", WeatherEngine.fogHook, IV.worldFog)

    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    WeatherEngine.reset()
    local function weather(frames)
        for k = 1, frames do
            WeatherEngine.update(1 / 30, { biomeId = "frost", camZ = 5.5, progress = 0, time = 100 + k / 30 })
        end
    end
    weather(30)
    local calm = WeatherEngine.intensity()
    t:near("sem névoa: intensidade = curva do começo do ato", calm, WeatherEngine.intensityFor(0), 1e-6)
    g.enemy.intentVisibility = "hidden"
    weather(120)
    local thick = WeatherEngine.intensity()
    t:check("número escondido: a nevasca ENGROSSA (" .. string.format("%.2f -> %.2f", calm, thick) .. ")",
        thick > calm + 0.5)
    t:check("boost nunca passa de 1", thick <= 1)
    t:check("a tempestade fecha junto", WeatherEngine.storm() > 0.5)
    -- INVARIANTE (lead): "?" nunca sobre céu limpo — assentado o clima, a
    -- bruma de tela (renderedFog) está acima do limiar sempre que o intent
    -- está encoberto, e abaixo quando revelado. 15 quadros ≈ 0,5 s: menos
    -- que os beats entre o anúncio e a vez voltar ao jogador.
    local TH = IV.FOG_THRESHOLD
    t:check("renderedFog hidden >= limiar (" .. TH .. ")", WeatherEngine.renderedFog() >= TH)
    g.enemy.intentVisibility = "type_only"
    weather(15)
    t:check("type_only, 0,5 s depois: renderedFog >= limiar", WeatherEngine.renderedFog() >= TH)
    g.enemy.intentVisibility = "full"
    weather(45)
    t:check("revelado, 1,5 s depois: renderedFog < limiar", WeatherEngine.renderedFog() < TH)
    weather(105)
    t:near("revelado: a nevasca volta ao normal", WeatherEngine.intensity(), calm, 0.02)

    -- CADEIA REAL (lead): o anúncio escondido acontece no turno do inimigo
    -- (beat enemy.next_intent) e a bruma precisa ter fechado ANTES de a vez
    -- voltar ao jogador (turn.player_ready). O espectro do gelo tem véu com
    -- chance 1: todo anúncio sai type_only, sem depender da rolagem.
    do
        local CombatBeats = require("src.systems.CombatBeats")
        g.enemy.intentVisibility = "full"
        g.enemy._revealTurns = 0
        g.enemy.fogContext.hall = false
        g.enemy.health = 500
        g.player.health, g.player.armor = g.player.maxHealth, 0
        IV.noteActive(g.enemy)
        WeatherEngine.reset()
        weather(60)
        t:check("(pré) número à mostra, bruma aberta", WeatherEngine.renderedFog() < TH)
        CombatBeats.startTrace()
        g.turn = "enemy"
        g._enemyActing = false
        g:enemyTurn()
        local fogAtReturn, visAtReturn, frames = nil, nil, 0
        for k = 1, 300 do
            TK.pump(g, 1 / 30)
            WeatherEngine.update(1 / 30, { biomeId = "frost", camZ = 5.5, progress = 0.6, time = 200 + k / 30 })
            frames = k
            if g.turn == "player" and not g._enemyActing and not CombatBeats.isBusy() then
                fogAtReturn = WeatherEngine.renderedFog()
                visAtReturn = g.enemy:getIntentVisibility()
                break
            end
        end
        t:truthy("a vez voltou ao jogador (" .. frames .. " quadros)", fogAtReturn ~= nil)
        t:eq("o anúncio novo veio encoberto (véu do espectro)", visAtReturn, "type_only")
        t:check(string.format("quando a vez volta a bruma JÁ fechou (renderedFog %.2f >= %.2f)",
            fogAtReturn or 0, TH), (fogAtReturn or 0) >= TH)
        local sawNext = false
        for _, l in ipairs(CombatBeats.log) do if l == "enemy.next_intent" then sawNext = true end end
        t:truthy("o anúncio passou pelo beat enemy.next_intent", sawNext)
    end

    -- a bruma é DESENHADA (bandas no flushAll) quando há véu, e não há
    -- banda alguma com o número à mostra
    do
        local WorldRoad = require("src.ui.WorldRoad")
        local W, H = love.graphics.getDimensions()
        local function frame()
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, 60, W, H - 60, 4)
            WorldRoad.drawOverlays(0, 60, W, H - 60)
        end
        WorldRoad.clearCache()
        WorldRoad.setBiome(4)
        WorldRoad._camZ = 5.5
        g.enemy.intentVisibility = "hidden"
        IV.noteActive(g.enemy)
        for _ = 1, 45 do frame() end
        t:check("bruma de tela desenhada com o intent escondido (bandas > 0)",
            (WeatherEngine.stats.hazeBands or 0) > 0)
        t:check("...e o clima da cena fechou (renderedFog >= limiar)", WeatherEngine.renderedFog() >= TH)
        g.enemy.intentVisibility = "full"
        for _ = 1, 90 do frame() end
        t:eq("revelado: nenhuma banda de bruma", WeatherEngine.stats.hazeBands or 0, 0)
    end
    -- salão: o clima do domo não responde; quem responde é o InteriorFX
    -- (hook de chefes-visual-3, e37a148) — mesmo limiar, mesma propriedade
    g.enemy.intentVisibility = "hidden"
    g.enemy.fogContext.hall = true
    t:eq("salão do chefe não empurra o clima do domo", IV.worldFog(), 0)
    t:near("salão: hallFog = boost da tabela", IV.hallFog(), Fog.worldBoost.hidden, 1e-9)
    g.enemy.fogContext.hall = false
    t:eq("estrada: hallFog = 0", IV.hallFog(), 0)
    do
        local InteriorFX = require("src.ui.InteriorFX")
        t:eq("hook instalado no InteriorFX", InteriorFX.fogHook, IV.hallFog)
        local hall = InteriorFX.hallFor(4)
        g.enemy.fogContext.hall = true
        InteriorFX.clear()
        local function hallFrames(n) for _ = 1, n do InteriorFX.update(1 / 30, hall) end end
        g.enemy.intentVisibility = "hidden"
        hallFrames(15)
        t:check("salão, hidden, 0,5 s: renderedFog >= limiar", InteriorFX.renderedFog() >= TH)
        g.enemy.intentVisibility = "type_only"
        hallFrames(30)
        t:check("salão, type_only: renderedFog >= limiar", InteriorFX.renderedFog() >= TH)
        g.enemy.intentVisibility = "full"
        hallFrames(45)
        t:check("salão, revelado, 1,5 s: renderedFog < limiar", InteriorFX.renderedFog() < TH)
        InteriorFX.clear()
        t:eq("InteriorFX.clear zera a névoa", InteriorFX.renderedFog(), 0)
        g.enemy.fogContext.hall = false
    end
    -- inimigo morto não empurra
    local hp0 = g.enemy.health
    g.enemy.health = 0
    t:eq("inimigo morto não empurra o clima", IV.worldFog(), 0)
    g.enemy.health = hp0
    weather(60)
    WeatherEngine.reset()
    t:eq("reset zera o boost", WeatherEngine.veilBoost(), 0)
    IV.reset()
    t:eq("IV.reset: sem inimigo ativo = 0", IV.worldFog(), 0)
    _G.gameSettings = savedSettings

    -- ======================================================================
    -- 9. PILOTO não enxerga número escondido
    -- ======================================================================
    local NUMERIC = { "perHit", "hits", "armor", "strength", "heal", "raw", "summon" }
    for _, lvl2 in ipairs({ "type_only", "hidden" }) do
        g.enemy.intentVisibility = lvl2
        local k2 = g.enemy:getKnownIntent(g.player)
        local leaked = {}
        for _, f in ipairs(NUMERIC) do
            if k2[f] ~= nil then leaked[#leaked + 1] = f end
        end
        t:eq(lvl2 .. ": getKnownIntent sem campos numéricos", table.concat(leaked, ","), "")
        t:eq(lvl2 .. ": getKnownIncomingDamage = nil", g.enemy:getKnownIncomingDamage(g.player), nil)
    end
    g.enemy.intentVisibility = "full"
    t:eq("full: getKnownIntent carrega visibility", g.enemy:getKnownIntent(g.player).visibility, "full")

    -- o piloto de verdade (tools/balance_ai.knownThreat) decide pelo conhecido
    local AI = require("tools.balance_ai")
    g.enemy:forceIntent("wight_claw", g.player)
    local realHit = g.enemy:intentHitDamage(g.player)
    local expected = math.ceil(g.enemy:expectedDamagePerTurn())
    g.enemy.intentVisibility = "full"
    local th = AI.knownThreat(g.enemy, g.player)
    t:eq("piloto full: lê o número congelado", th.perHit * th.hits, realHit)
    t:truthy("piloto full: known", th.known)
    g.enemy.intentVisibility = "type_only"
    th = AI.knownThreat(g.enemy, g.player)
    t:falsy("piloto type_only: NÃO é conhecido", th.known)
    t:eq("piloto type_only: estima pela média do kit", th.perHit * th.hits, expected)
    g.enemy.intentVisibility = "hidden"
    th = AI.knownThreat(g.enemy, g.player)
    t:falsy("piloto hidden: NÃO é conhecido", th.known)
    t:eq("piloto hidden: estima pela média do kit", th.perHit * th.hits, expected)
    t:eq("piloto hidden: sem bloqueio nem perfurante", (th.armor or 0) + (th.pierce and 1 or 0), 0)
    g.enemy:forceIntent("freezing_touch", g.player)   -- golpe de dano que aplica Frágil
    g.enemy.intentVisibility = "type_only"
    th = AI.knownThreat(g.enemy, g.player)
    t:eq("piloto type_only (ataque): dano estimado", th.perHit * th.hits, expected)
    g.enemy.intentVisibility = "full"
    -- e o autoplay escolhe cartas por esse caminho (fonte, não só a API)
    local src = love.filesystem.read("tools/autoplay.lua") or ""
    t:truthy("autoplay.chooseBatch decide por AI.knownThreat", src:find("AI.knownThreat(enemy, p)", 1, true))
    t:truthy("autoplay mantém a MEDIÇÃO (diag) no dano real",
        src:find("game.enemy:getIncomingDamage(game.player)", 1, true))

    -- ======================================================================
    -- 10. TUTORIAL
    -- ======================================================================
    local Tutorial = require("src.systems.Tutorial")
    local conv = Tutorial.byId and Tutorial.byId("fog")
    t:truthy("conversa `fog` no roteiro", conv ~= nil)
    if conv then
        t:eq("fog: 2 falas", #conv.lines, 2)
        t:eq("fog: 1ª fala aponta o intent", conv.lines[1].spot, "intent")
        g.enemy.intentVisibility = "type_only"
        g.turn = "player"
        t:truthy("fog: gatilho arma com o número escondido", conv.latch(g))
        g.enemy.intentVisibility = "full"
        t:falsy("fog: gatilho NÃO arma com o número à mostra", conv.latch(g))
    end
    for _, loc in ipairs(LOCALES) do
        local data = require("src.i18n.locales.tutorial." .. loc)
        local s = data.script and data.script.fog
        t:truthy(loc .. ": script.fog.veil", s and type(s.veil) == "string" and #s.veil > 10)
        t:truthy(loc .. ": script.fog.counter", s and type(s.counter) == "string" and #s.counter > 10)
    end

    I18n.setLocale(savedLocale, true)
    return t:done()
end

return M
