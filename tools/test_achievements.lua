local TK = require("tools.testkit")

local M = {}

local FROZEN = {
    primeiro_chefe = "ACH_PRIMEIRO_CHEFE", capitulo_final = "ACH_CAPITULO_FINAL",
    primeira_pagina = "ACH_PRIMEIRA_PAGINA", vitoria_guerreiro = "ACH_VITORIA_GUERREIRO",
    vitoria_mago = "ACH_VITORIA_MAGO", vitoria_ladino = "ACH_VITORIA_LADINO",
    trindade = "ACH_TRINDADE", despertar = "ACH_DESPERTAR",
    coro_coringas = "ACH_CORO_CORINGAS", grimorio_bolso = "ACH_GRIMORIO_BOLSO",
    enciclopedia = "ACH_ENCICLOPEDIA", voto_pobreza = "ACH_VOTO_POBREZA",
    asceta = "ACH_ASCETA", tinta_crua = "ACH_TINTA_CRUA",
    sem_rascunhos = "ACH_SEM_RASCUNHOS", relampago = "ACH_RELAMPAGO",
    fio_navalha = "ACH_FIO_NAVALHA", imaculado = "ACH_IMACULADO", miasma = "ACH_MIASMA",
    muralha = "ACH_MURALHA", tinta_viva = "ACH_TINTA_VIVA", golpe_tinta = "ACH_GOLPE_TINTA",
    conduite_pleno = "ACH_CONDUITE_PLENO", maos_limpas = "ACH_MAOS_LIMPAS",
    velas_10k = "ACH_VELAS_10K", escriba = "ACH_ESCRIBA", ferreiro = "ACH_FERREIRO",
    veterano = "ACH_VETERANO", bibliotecario = "ACH_BIBLIOTECARIO",
    alem_da_pagina = "ACH_ALEM_DA_PAGINA",
    ciclo_3 = "ACH_CICLO_3", ciclo_5 = "ACH_CICLO_5", ciclo_10 = "ACH_CICLO_10",
    primeiro_selo = "ACH_PRIMEIRO_SELO", selo_max_guerreiro = "ACH_SELO_MAX_GUERREIRO",
    selo_max_mago = "ACH_SELO_MAX_MAGO", selo_max_ladino = "ACH_SELO_MAX_LADINO",
}

local UI_KEYS = { "hint", "secret_name", "secret_desc", "toast_label", "tier_natural",
    "tier_build", "tier_skill", "tier_collection", "unlocked_on", "unlocked", "locked",
    "secret_tag", "progress", "total", "date_format" }

local AS, PS, Defs

local function fresh()
    local s = PS.get()
    s.achievements, s.achievementDates = {}, {}
    s.counters, s.cardsSeen, s.winsByClass = {}, {}, {}
    s.wins = 0
    AS._resetTransient()
    require("src.ui.AchievementToast").clear()
end

local function has(id) return AS.isUnlocked(id) end

local function fakeRun(over)
    local run = { currentDeck = {}, jokers = {}, classId = "warrior", actNumber = 1,
                  floorInAct = 1, currentFloor = 1, currentNode = { type = "battle" } }
    for k, v in pairs(over or {}) do run[k] = v end
    local g = TK.mockGame()
    g.isRunMode = true
    g.battleTurn = 2
    g.runManager = {
        currentRun = run,
        hasAnyUpgrade = function() return run._forged == true end,
        getMaxJokerSlots = function() return 3 end,
    }
    g.selectedClass = run.classId
    return g, run
end

function M.run()
    TK.bootstrap()
    local t = TK.new("conquistas: gatilhos, persistencia, Steam, emblemas, layout")
    AS = require("src.systems.AchievementSystem")
    PS = require("engine.ProfileStats")
    Defs = require("src.data.achievements")
    local SteamBridge = require("src.systems.SteamBridge")

    local seenApi, seenId, count = {}, {}, 0
    for _, d in ipairs(Defs) do
        count = count + 1
        t:falsy("id unico: " .. d.id, seenId[d.id]); seenId[d.id] = true
        t:truthy("API name valido: " .. tostring(d.steam),
            type(d.steam) == "string" and d.steam:match("^ACH_[A-Z0-9_]+$") ~= nil)
        t:falsy("API name unico: " .. tostring(d.steam), seenApi[d.steam]); seenApi[d.steam] = true
        t:eq("API name congelado: " .. d.id, d.steam, FROZEN[d.id])
        t:truthy("tier conhecido: " .. d.id,
            d.tier == "natural" or d.tier == "build" or d.tier == "skill" or d.tier == "collection")
    end
    for id in pairs(FROZEN) do
        t:truthy("conquista congelada ainda existe: " .. id, AS.def(id) ~= nil)
    end
    t:truthy("ate 100 conquistas (limite padrao Steam)", count <= 100)

    local AI = require("src.ui.AchievementIcons")
    for _, d in ipairs(Defs) do
        for _, locked in ipairs({ false, true }) do
            local p = AI.path(d.id, locked)
            t:truthy("emblema existe: " .. p, love.filesystem.getInfo(p) ~= nil)
            if love.filesystem.getInfo(p) then
                local img = love.image.newImageData(p)
                t:truthy("emblema 64x64: " .. p, img:getWidth() == 64 and img:getHeight() == 64)
            end
            local sp = "steam/achievements/icons/" .. d.steam .. (locked and "_locked" or "") .. ".png"
            t:truthy("icone Steam existe: " .. sp, love.filesystem.getInfo(sp) ~= nil)
            if love.filesystem.getInfo(sp) then
                local img = love.image.newImageData(sp)
                t:truthy("icone Steam 256x256: " .. sp,
                    img:getWidth() == 256 and img:getHeight() == 256)
            end
        end
    end
    local meta = love.filesystem.read("steam/achievements/achievements.json")
    t:truthy("metadados Steam existem", meta ~= nil)
    if meta then
        for _, d in ipairs(Defs) do
            t:truthy("metadado cita " .. d.steam, meta:find('"' .. d.steam .. '"', 1, true) ~= nil)
        end
    end

    local I18n = require("src.i18n.I18n")
    local entry = I18n.getLocale()
    for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
        I18n.setLocale(loc)
        for _, k in ipairs(UI_KEYS) do
            t:truthy(loc .. " tem achievements." .. k,
                I18n.t("achievements." .. k, nil, "__MISS__") ~= "__MISS__")
        end
    end
    I18n.setLocale(entry)

    fresh()
    t:truthy("unlock novo devolve true", AS.unlock("primeira_pagina", nil))
    t:falsy("unlock repetido devolve false", AS.unlock("primeira_pagina", nil))
    t:truthy("unlock grava no perfil", PS.get().achievements.primeira_pagina == true)
    t:truthy("unlock grava a data", type(PS.get().achievementDates.primeira_pagina) == "number")
    local SaveManager = require("engine.SaveManager")
    local chunk = loadstring("return " .. SaveManager.serialize(PS.get()))
    local back = chunk and chunk()
    t:truthy("perfil serializado preserva conquista + data",
        back and back.achievements.primeira_pagina == true
        and back.achievementDates.primeira_pagina == PS.get().achievementDates.primeira_pagina)
    PS.get().achievements.id_aposentado = true
    local n, total = AS.countUnlocked()
    t:eq("countUnlocked ignora id fora do catalogo", n, 1)
    t:eq("total = catalogo", total, #Defs)
    t:falsy("unlock de id desconhecido recusa", AS.unlock("nao_existe", nil))
    t:truthy("unlock empurra toast", require("src.ui.AchievementToast").pending() >= 1)

    fresh()
    local function entryOf(id)
        for _, e in ipairs(AS.all()) do if e.id == id then return e end end
    end
    local sec = entryOf("fio_navalha")
    t:truthy("secreta bloqueada esconde nome", sec.secret and sec.name == I18n.t("achievements.secret_name"))
    AS.unlock("fio_navalha", nil)
    sec = entryOf("fio_navalha")
    t:truthy("secreta liberada mostra nome", not sec.secret and sec.name ~= I18n.t("achievements.secret_name"))

    fresh()
    local g, run = fakeRun({ currentNode = { type = "boss" }, actNumber = 1 })
    g.battleTurn = 3
    AS.onBattleWon(g)
    t:truthy("primeiro_chefe: chefe derrotado", has("primeiro_chefe"))
    t:falsy("capitulo_final: chefe do ato 1 nao conta", has("capitulo_final"))
    t:falsy("relampago: inimigo agiu", has("relampago"))
    run.actNumber = 3
    AS.onBattleWon(g)
    t:truthy("capitulo_final: chefe do ato 3", has("capitulo_final"))

    fresh()
    g, run = fakeRun({ currentNode = { type = "battle" } })
    g.battleTurn = 0
    g.player.health = 1
    AS.onBattleWon(g)
    t:truthy("relampago: venceu antes do inimigo agir", has("relampago"))
    t:truthy("fio_navalha: 1 HP", has("fio_navalha"))
    t:falsy("primeiro_chefe: batalha comum nao conta", has("primeiro_chefe"))
    t:truthy("maos_limpas: nenhum ataque jogado", has("maos_limpas"))

    fresh()
    g = fakeRun()
    AS.onCardsPlayed(g, { allSelectedCards = { { type = "attack" } }, activeCombos = {} })
    AS.onBattleWon(g)
    t:falsy("maos_limpas: ataque jogado nesta batalha", has("maos_limpas"))
    t:falsy("fio_navalha: vida cheia", has("fio_navalha"))
    g.enemy = require("src.entities.Enemy"):new(10, 1)
    AS.onBattleWon(g)
    t:truthy("maos_limpas: inimigo novo sem ataque", has("maos_limpas"))

    fresh()
    g = fakeRun({ currentNode = { type = "boss" } })
    g.scoreSystem = { lastBattle = { flawless = true } }
    AS.onBattleWon(g)
    t:truthy("imaculado: chefe sem dano", has("imaculado"))
    fresh()
    g = fakeRun({ currentNode = { type = "elite" } })
    g.scoreSystem = { lastBattle = { flawless = true } }
    AS.onBattleWon(g)
    t:falsy("imaculado: elite nao conta", has("imaculado"))

    fresh()
    g = fakeRun()
    g.score = 9999; AS.onBattleWon(g)
    t:falsy("velas_10k: 9999", has("velas_10k"))
    g.score = 10000; AS.onBattleWon(g)
    t:truthy("velas_10k: 10000", has("velas_10k"))

    fresh()
    g = fakeRun()
    g.jokerSlots = { {}, {} }; AS.onBattleWon(g)
    t:falsy("coro_coringas: 2 de 3 slots", has("coro_coringas"))
    g.jokerSlots = { {}, {}, {} }; AS.onBattleWon(g)
    t:truthy("coro_coringas: slots cheios", has("coro_coringas"))

    fresh()
    local Config = require("src.core.Config")
    local MapManager = require("src.systems.MapManager")
    local base = Config.TotalActs * MapManager.FLOORS_PER_ACT
    g, run = fakeRun({ endlessMode = true, currentFloor = base + 9 })
    AS.onBattleWon(g)
    t:eq("endlessFloor deriva do currentFloor", AS.endlessFloor(run), 9)
    t:falsy("alem_da_pagina: andar 9", has("alem_da_pagina"))
    t:eq("progresso do infinito registrado", select(1, AS.progressOf("alem_da_pagina")), 9)
    run.currentFloor = base + 10
    AS.onBattleWon(g)
    t:truthy("alem_da_pagina: andar 10", has("alem_da_pagina"))

    fresh()
    g = fakeRun()
    AS.onCardsPlayed(g, { allSelectedCards = {}, activeCombos = { 1, 2 } })
    t:falsy("tinta_viva: 2 combos", has("tinta_viva"))
    AS.onCardsPlayed(g, { allSelectedCards = {}, activeCombos = { 1, 2, 3 } })
    t:truthy("tinta_viva: 3 combos", has("tinta_viva"))

    fresh()
    PS.get().counters.cardsPlayed = 2498
    AS.onCardsPlayed(g, { allSelectedCards = { {}, {} }, activeCombos = {} })
    t:truthy("escriba: 2500 cartas", has("escriba"))
    fresh()
    PS.get().counters.cardsPlayed = 2400
    AS.onCardsPlayed(g, { allSelectedCards = { {} }, activeCombos = {} })
    t:falsy("escriba: 2401", has("escriba"))
    local cur, tgt = AS.progressOf("escriba")
    t:truthy("escriba: progresso 2401/2500", cur == 2401 and tgt == 2500)

    fresh()
    AS.onCardDamage(g, {}, 59)
    t:falsy("golpe_tinta: 59", has("golpe_tinta"))
    AS.onCardDamage(g, {}, 60)
    t:truthy("golpe_tinta: 60", has("golpe_tinta"))

    fresh()
    g.player.orbs = { {}, {} }
    AS.onOrbChanneled(g)
    t:falsy("conduite_pleno: 2 orbes", has("conduite_pleno"))
    g.player.orbs = { {}, {}, {} }
    AS.onOrbChanneled(g)
    t:truthy("conduite_pleno: 3 orbes", has("conduite_pleno"))

    fresh()
    g.enemy.statusEffects = { { name = "poison", stacks = 14 } }
    AS.onPoisonApplied(g, g.enemy)
    t:falsy("miasma: 14", has("miasma"))
    g.enemy.statusEffects = { { name = "poison", stacks = 15 } }
    AS.onPoisonApplied(g, g.enemy)
    t:truthy("miasma: 15", has("miasma"))

    fresh()
    AS.onArmorCapped(g)
    t:truthy("muralha: cap de bloqueio", has("muralha"))

    fresh()
    PS.get().counters.forges = 23
    AS.onForge(g)
    t:falsy("ferreiro: 24", has("ferreiro"))
    AS.onForge(g)
    t:truthy("ferreiro: 25", has("ferreiro"))

    fresh()
    local CardDatabase = require("src.systems.CardDatabase")
    local ids = {}
    for id in pairs(CardDatabase:getAllCards()) do ids[#ids + 1] = id end
    table.sort(ids)
    for i = 1, #ids - 1 do PS.markSeen(ids[i]) end
    PS.get().cardsSeen.carta_que_nao_existe = true
    AS.onCardSeen(g, ids[#ids - 1])
    t:falsy("bibliotecario: falta 1 carta", has("bibliotecario"))
    AS.onCardSeen(g, ids[#ids])
    t:truthy("bibliotecario: catalogo completo", has("bibliotecario"))

    local function victory(over, setup)
        fresh()
        local vg, vrun = fakeRun(over)
        if setup then setup(vg, vrun) end
        AS.onVictory(vg)
        return vg, vrun
    end
    local rare
    for id, cd in pairs(CardDatabase:getAllCards()) do
        if cd.rarity == "rare" and cd.type ~= "joker" then rare = id; break end
    end
    local common
    for id, cd in pairs(CardDatabase:getAllCards()) do
        if cd.rarity == "common" and cd.type ~= "joker" then common = id; break end
    end

    victory({ classId = "mage", currentDeck = { common, common, common } })
    t:truthy("primeira_pagina: vitoria", has("primeira_pagina"))
    t:truthy("vitoria_mago", has("vitoria_mago"))
    t:falsy("vitoria_guerreiro: venceu com mago", has("vitoria_guerreiro"))
    t:truthy("grimorio_bolso: deck de 3", has("grimorio_bolso"))
    t:truthy("voto_pobreza: sem loja", has("voto_pobreza"))
    t:truthy("sem_rascunhos: sem forja", has("sem_rascunhos"))
    t:truthy("asceta: sem coringa", has("asceta"))
    t:truthy("tinta_crua: so comuns", has("tinta_crua"))
    t:falsy("enciclopedia: deck pequeno", has("enciclopedia"))

    local big = {}
    for i = 1, 30 do big[i] = common end
    big[30] = { id = rare, up = 1 }
    victory({ classId = "rogue", currentDeck = big, _usedShop = true, _forged = true,
              jokers = { "joker_001" } })
    t:truthy("vitoria_ladino", has("vitoria_ladino"))
    t:truthy("enciclopedia: 30 cartas", has("enciclopedia"))
    t:falsy("grimorio_bolso: deck grande", has("grimorio_bolso"))
    t:falsy("voto_pobreza: comprou na loja", has("voto_pobreza"))
    t:falsy("sem_rascunhos: forjou", has("sem_rascunhos"))
    t:falsy("asceta: tem coringa", has("asceta"))
    t:falsy("tinta_crua: rara em entrada-tabela NAO passa (regressao)", has("tinta_crua"))

    victory({ classId = "warrior", currentDeck = { common } }, function()
        local s = PS.get()
        s.winsByClass = { warrior = true, mage = true, rogue = true }
        s.wins = 10
    end)
    t:truthy("vitoria_guerreiro", has("vitoria_guerreiro"))
    t:truthy("trindade: 3 classes", has("trindade"))
    t:truthy("veterano: 10 vitorias", has("veterano"))
    victory({ classId = "warrior", currentDeck = { common } }, function()
        local s = PS.get()
        s.winsByClass = { warrior = true, mage = true }
        s.wins = 9
    end)
    t:falsy("trindade: 2 classes", has("trindade"))
    t:falsy("veterano: 9 vitorias", has("veterano"))

    local realUS = package.loaded["src.systems.UnlockSystem"]
    local unlocked = { warrior = true }
    package.loaded["src.systems.UnlockSystem"] = {
        isClassUnlockedReal = function(id) return unlocked[id] == true end,
    }
    fresh()
    AS.checkClassUnlocks(nil)
    t:falsy("despertar: 1 de 3 classes", has("despertar"))
    t:eq("despertar: progresso 1/3", select(1, AS.progressOf("despertar")), 1)
    unlocked.mage, unlocked.rogue = true, true
    AS.checkClassUnlocks(nil)
    t:truthy("despertar: 3 de 3 classes", has("despertar"))
    package.loaded["src.systems.UnlockSystem"] = realUS

    fresh()
    local rg = TK.newRunGame("rogue")
    local rrun = rg.runManager.currentRun
    t:truthy("onRunStarted marca o deck inicial como visto",
        PS.get().cardsSeen[require("src.systems.RunManager").entryId(rrun.currentDeck[1])] == true)
    rrun.actNumber = Config.TotalActs
    rrun.floorInAct = MapManager.FLOORS_PER_ACT
    rrun.currentNode = { type = "boss" }
    rg.enemy.health = 0
    rg:checkVictory()
    t:truthy("Game:checkVictory dispara onVictory (primeira_pagina)", has("primeira_pagina"))
    t:truthy("Game:checkVictory dispara a conquista da classe", has("vitoria_ladino"))

    local src = love.filesystem.read("src/core/Game.lua")
    for _, hook in ipairs({ "onRunStarted", "onCardsPlayed", "onCardDamage", "onArmorCapped",
                            "onBattleWon", "onVictory", "onCardSeen" }) do
        t:truthy("Game.lua chama AchievementSystem." .. hook,
            src:find("AchievementSystem." .. hook .. "(", 1, true) ~= nil)
    end
    local es = love.filesystem.read("src/systems/EffectSystem.lua")
    t:truthy("EffectSystem chama onOrbChanneled", es:find("onOrbChanneled(", 1, true) ~= nil)
    t:truthy("EffectSystem chama onPoisonApplied", es:find("onPoisonApplied(", 1, true) ~= nil)
    local rest = love.filesystem.read("components/RestScreen.lua")
    t:truthy("RestScreen chama onForge", rest:find("onForge(", 1, true) ~= nil)

    SteamBridge._setBackend(nil)
    fresh()
    t:falsy("sem Steam: init falha avisando (headless)", SteamBridge.init())
    t:falsy("sem Steam: unlock vira no-op", SteamBridge.unlock("ACH_TESTE"))
    local calls = {}
    local fake = {
        init = function() return true end,
        runCallbacks = function() end,
        userStats = {
            setAchievement = function(n) calls[#calls + 1] = "set:" .. n; return true end,
            storeStats = function() calls[#calls + 1] = "store"; return true end,
            indicateAchievementProgress = function(n, c, m)
                calls[#calls + 1] = ("prog:%s:%d/%d"):format(n, c, m); return true end,
        },
    }
    SteamBridge._setBackend(fake)
    t:truthy("Steam fake: init ativa", SteamBridge.init())
    AS.unlock("muralha", nil)
    t:truthy("unlock espelha SetAchievement com o API name",
        table.concat(calls, ","):find("set:ACH_MURALHA,store", 1, true) ~= nil)
    calls = {}
    PS.get().counters.forges = 5
    AS.onForge(nil)
    t:truthy("progresso 25% vai pra Steam (IndicateAchievementProgress)",
        table.concat(calls, ","):find("prog:ACH_FERREIRO:6/25", 1, true) ~= nil)
    calls = {}
    PS.get().achievements.primeira_pagina = true
    SteamBridge.syncAll(Defs, AS.isUnlocked)
    t:truthy("syncAll espelha os desbloqueios locais",
        table.concat(calls, ","):find("set:ACH_PRIMEIRA_PAGINA", 1, true) ~= nil)
    SteamBridge._setBackend(nil)

    local Screen = require("components.AchievementsScreen")
    local entries = AS.all()
    local function inside(r, box)
        return r[1] >= box[1] and r[2] >= box[2]
            and r[1] + r[3] <= box[1] + box[3] + 0.5 and r[2] + r[4] <= box[2] + box[4] + 0.5
    end
    local function overlap(a, b)
        return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
    end
    for _, sz in ipairs({ { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1366, 768 },
                          { 1920, 1080 }, { 2560, 1440 } }) do
        local L = Screen.layout(entries, sz[1], sz[2])
        local tag = sz[1] .. "x" .. sz[2]
        local ok, n2 = true, 0
        for i = 1, #entries do
            local r = L.cells[i]
            if not r then ok = false else
                n2 = n2 + 1
                if not inside(r, L.grid) then ok = false end
            end
        end
        t:truthy(tag .. ": toda conquista tem celula dentro da GRADE", ok and n2 == #entries)
        t:falsy(tag .. ": GRADE nao invade o DETALHE", overlap(L.grid, L.detail))
        t:truthy(tag .. ": DETALHE dentro do painel", inside(L.detail, L.panel))
        t:truthy(tag .. ": emblema >= 28px", L.cell >= 28)
        local clash = false
        for i = 1, #entries do
            for j = i + 1, #entries do
                if overlap(L.cells[i], L.cells[j]) then clash = true end
            end
        end
        t:falsy(tag .. ": celulas nao se sobrepoem", clash)
        local right = Screen.neighbor(L, 1, { 1, 0 })
        t:truthy(tag .. ": seta direita vai pra celula a direita",
            right and L.cells[right][1] > L.cells[1][1] and L.cells[right][2] == L.cells[1][2])
        local down = Screen.neighbor(L, 1, { 0, 1 })
        t:truthy(tag .. ": seta baixo desce", down and L.cells[down][2] > L.cells[1][2])
        t:eq(tag .. ": seta esquerda na 1a celula fica parada", Screen.neighbor(L, 1, { -1, 0 }), nil)
        local Toast = require("src.ui.AchievementToast")
        local tx, ty, tw, th = Toast.rect(sz[1], sz[2])
        t:truthy(tag .. ": toast dentro da tela",
            tx >= 0 and ty >= 0 and tx + tw <= sz[1] and ty + th <= sz[2])
    end

    fresh()
    return t:done()
end

return M
