local TK = require("tools.testkit")

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

function M.run()
    local t = TK.new("tutorial: corvo narrador, roteiro, foco, guia")
    TK.bootstrap()
    local I18n = require("src.i18n.I18n")
    local Tutorial = require("src.systems.Tutorial")
    local Narrator = require("src.ui.Narrator")
    local ProfileStats = require("engine.ProfileStats")
    local UiScale = require("src.ui.UiScale")

    local missing = {}
    for _, loc in ipairs(LOCALES) do
        local data = require("src.i18n.locales.tutorial." .. loc)
        for _, conv in ipairs(Tutorial.SCRIPT) do
            for _, line in ipairs(conv.lines) do
                local s = data.script and data.script[conv.id] and data.script[conv.id][line.id]
                if not (type(s) == "string" and #s > 10) then
                    missing[#missing + 1] = loc .. ":" .. conv.id .. "." .. line.id
                end
            end
        end
        for _, k in ipairs({ "continue", "skip", "disable" }) do
            if not (data.footer and data.footer[k]) then missing[#missing + 1] = loc .. ":footer." .. k end
        end
        for name in pairs(Tutorial.ACTIONS) do
            if not (data.act and data.act[name]) then missing[#missing + 1] = loc .. ":act." .. name end
        end
        if not (data.narrator and data.narrator.name) then missing[#missing + 1] = loc .. ":narrator" end
    end
    t:eq("toda fala, rodapé e ação existem nos 5 idiomas", table.concat(missing, ","), "")

    local prevProfile = ProfileStats._swapForTests({})
    Tutorial._reset()
    Tutorial._forceForTests(true)
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.5)
    g.turn = "player"
    g._enemyActing = false
    g.battleTurn = 0
    g.selectedCards = {}
    local function anchorsNow()
        love.graphics.origin()
        Tutorial.anchor("hand", 300, 560, 400, 180)
        Tutorial.anchor("mana", 940, 680, 60, 60)
        Tutorial.anchor("intent", 470, 160, 90, 48)
        Tutorial.anchor("enemy", 440, 200, 150, 200)
        Tutorial.anchor("enemy_hp", 440, 410, 150, 12)
        Tutorial.anchor("play", 820, 600, 150, 46)
        Tutorial.anchor("end_turn", 820, 654, 150, 33)
        Tutorial.anchor("player_panel", 14, 660, 220, 90)
        Tutorial.anchor("preview", 760, 470, 220, 90)
        Tutorial.anchor("jokers", 14, 88, 260, 140)
    end
    local function step(secs)
        local n = math.max(1, math.floor((secs or 0.5) / (1 / 30)))
        for _ = 1, n do anchorsNow(); Tutorial.update(1 / 30, "playing", g) end
    end
    local function talkThrough()
        Tutorial.overlay:keypressed("return")
        Tutorial.overlay:keypressed("return")
    end

    Tutorial._quiet = false
    step(1.0)
    t:eq("cena em movimento: o narrador espera", Tutorial.activeId(), nil)
    Tutorial._quiet = true
    step(0.2)
    t:eq("condição precisa se manter (sem piscar)", Tutorial.activeId(), nil)
    step(0.6)
    t:eq("1ª batalha: o corvo se apresenta", Tutorial.activeId(), "intro")
    t:eq("abre na fala de apresentação", Tutorial.activeLine(), "hello")
    t:truthy("na fala, o tutorial é dono da entrada (InputFocus)", Tutorial.overlay:isVisible())
    t:eq("na fala, o modo é 'talk'", Tutorial.mode(), "talk")
    Tutorial.overlay:keypressed("return")
    t:eq("1º Enter só completa o texto (máquina de escrever)", Tutorial.activeLine(), "hello")
    Tutorial.overlay:keypressed("return")
    t:eq("2º Enter: próxima fala (o inimigo)", Tutorial.activeLine(), "enemy")
    Tutorial.overlay:mousepressed(500, 300, 1)
    Tutorial.overlay:mousepressed(500, 300, 1)
    t:eq("clique também avança (intenção)", Tutorial.activeLine(), "intent")
    talkThrough()
    t:eq("depois o herói", Tutorial.activeLine(), "hero")
    talkThrough()
    t:eq("depois a mão (ação: selecionar)", Tutorial.activeLine(), "hand")
    Narrator.finishReveal()
    t:eq("fala de ação: modo 'action'", Tutorial.mode(), "action")
    t:falsy("na ação, o tutorial LARGA o modal (o jogo recebe o clique)", Tutorial.overlay:isVisible())
    Tutorial.draw()
    t:truthy("clique FORA do recorte é barrado", Tutorial.blocksPointer(50, 50, "pressed"))
    t:truthy("...e o release dele também", Tutorial.blocksPointer(50, 50, "released"))
    t:falsy("clique DENTRO do recorte passa", Tutorial.blocksPointer(500, 640, "pressed"))
    t:falsy("...e o release dele também", Tutorial.blocksPointer(900, 100, "released"))
    t:truthy("atalho de outra ação (Q = encerrar) é barrado", Tutorial.blocksKey("q"))
    t:falsy("navegação passa (setas/Enter)", Tutorial.blocksKey("left") or Tutorial.blocksKey("return"))
    Tutorial.overlay:keypressed("return")
    t:eq("Enter não pula uma ação", Tutorial.activeLine(), "hand")
    g.selectedCards = { g.hand[1] }
    step(0.1)
    t:eq("selecionou: a fala segue (mana)", Tutorial.activeLine(), "mana")
    talkThrough()
    t:eq("depois a prévia de dano", Tutorial.activeLine(), "preview")
    talkThrough()
    t:eq("depois o JOGAR (ação)", Tutorial.activeLine(), "play")
    Narrator.finishReveal()
    t:falsy("na ação de jogar, E/Y (jogar) passa", Tutorial.blocksKey("e"))
    t:truthy("na ação de jogar, Q/X (encerrar) não passa", Tutorial.blocksKey("q"))
    table.remove(g.hand, 1)
    g.selectedCards = {}
    step(0.1)
    t:eq("jogou: a conversa da apresentação termina", Tutorial.activeId(), nil)
    t:truthy("apresentação fica VISTA no perfil", ProfileStats.isTipSeen("intro"))

    do
        local handBackup = {}
        for i, c in ipairs(g.hand) do handBackup[i] = c end
        Tutorial._show("intro", "hand", g)
        table.remove(g.hand, 1)
        step(0.1)
        t:eq("jogou na fala de selecionar: segue pra mana", Tutorial.activeLine(), "mana")
        talkThrough(); talkThrough()
        step(0.1)
        t:eq("...e a fala de jogar passa sozinha (conversa termina)", Tutorial.activeId(), nil)
        g.hand = handBackup
        g.selectedCards = {}
        Tutorial._reset()
    end

    g.player.mana = 1
    g.turn = "enemy"
    step(1.0)
    t:eq("na vez do inimigo o narrador cala", Tutorial.activeId(), nil)
    g.turn = "player"
    step(1.0)
    t:eq("de volta ao turno (mana gasta, sem seleção): ENCERRAR", Tutorial.activeId(), "end_turn")
    Narrator.finishReveal()
    t:falsy("na ação de encerrar, Q/X passa", Tutorial.blocksKey("q"))
    g.turn = "enemy"
    step(0.1)
    t:eq("encerrou: conversa termina", Tutorial.activeId(), nil)
    g.turn = "player"
    g.battleTurn = 1
    g.player.mana = g.player.maxMana or 3
    step(1.0)
    t:eq("2º turno: o corvo fecha o ciclo (intenção cumprida)", Tutorial.activeId(), "second_turn")

    g.player.armor = 5
    step(0.6)
    t:eq("com uma conversa aberta, outra não começa", Tutorial.activeId(), "second_turn")
    Tutorial.overlay:keypressed("escape")
    t:eq("Esc/B pula a conversa inteira", Tutorial.activeId(), nil)
    t:truthy("conversa pulada fica vista", ProfileStats.isTipSeen("second_turn"))
    step(1.0)
    t:eq("depois do respiro, a próxima (Bloqueio)", Tutorial.activeId(), "block")
    Tutorial.skipConversation()
    g.player.armor = 0

    do
        local createdAudio = false
        if not _G.audioSystem then
            local AM = require("engine.AudioManager")
            _G.audioSystem = AM:new()
            _G.audioSystem:setGroupVolume("master", 0)
            createdAudio = true
        end
        local audioOn = _G.audioSystem:isAudioAvailable()
        local before = love.audio.getActiveSourceCount()
        local maxVoices = 0
        for _ = 1, 20 do
            Tutorial._start("intro", g)
            for _ = 1, 120 do
                Narrator.update(1 / 30)
                maxVoices = math.max(maxVoices, Narrator.voiceCount())
            end
            Tutorial.skipConversation()
        end
        t:check("o corvo nunca segura mais que " .. Narrator.BLIP_COUNT .. " fontes (20 conversas)",
            maxVoices <= Narrator.BLIP_COUNT)
        if audioOn then
            t:check("com áudio, os blips tocaram de verdade (pool usado)", maxVoices > 0)
        end
        t:eq("fim da conversa: as fontes do corvo são soltas", Narrator.voiceCount(), 0)
        t:check("fontes ativas não acumulam depois de 20 conversas",
            love.audio.getActiveSourceCount() <= before)
        Tutorial._reset()
        if createdAudio then _G.audioSystem = nil end
    end

    TK.pump(g, 0.1)
    local timing = {}
    do
        ProfileStats.resetTips()
        Tutorial._reset()
        g.turn, g._enemyActing, g.battleTurn = "player", false, 0
        g.player.armor, g.player.mana = 0, g.player.maxMana or 3
        g.selectedCards = {}
        local handBackup = {}
        for i, c in ipairs(g.hand) do handBackup[i] = c end
        Tutorial._quiet = true
        anchorsNow()
        Tutorial._show("intro", "play", g)
        Tutorial._quiet = false
        table.remove(g.hand, 1)
        g.player.mana = (g.player.maxMana or 3) - 1
        step(0.1)
        t:eq("jogou na apresentação: a conversa termina", Tutorial.activeId(), nil)
        g.player.armor = 6
        step(0.2)
        t:eq("Bloqueio armado no meio da resolução (sem falar com a cena andando)", Tutorial.activeId(), nil)
        t:truthy("Bloqueio armado: a luta não encerra o turno sozinha (mão vazia)", Tutorial.holdsTurn())
        Tutorial._quiet = true
        local tFire
        for i = 1, 60 do
            step(1 / 30)
            if Tutorial.activeId() then tFire = i / 30 break end
        end
        t:eq("defesa no turno 1: a dica do Bloqueio vem ANTES do Encerrar Turno", Tutorial.activeId(), "block")
        t:eq("...ainda no turno 1, antes de o inimigo agir", g.turn .. ":" .. tostring(g.battleTurn), "player:0")
        t:check("...e sai em até 1,5s do momento quieto", tFire and tFire <= 1.5)
        Tutorial.skipConversation()
        step(1.0)
        t:eq("na fila, logo depois: Encerrar Turno (mesma janela)", Tutorial.activeId(), "end_turn")
        Tutorial.skipConversation()
        t:falsy("fila vazia: o turno volta a poder encerrar sozinho", Tutorial.holdsTurn())
        g.hand = handBackup
        g.player.armor = 0
        timing[#timing + 1] = "block (na apresentação) → " .. string.format("%.2fs", tFire or -1)

        local US = require("src.systems.UnlockSystem")
        local function scenario(id, state, prereq, arm, disarm)
            ProfileStats.resetTips()
            for _, p in ipairs(prereq or {}) do ProfileStats.markTipSeen(p) end
            Tutorial._reset()
            g.turn, g._enemyActing = "player", false
            arm()
            local fired
            for i = 1, 60 do
                anchorsNow()
                if state ~= "playing" then
                    for k, r in pairs(Tutorial._scenarioAnchors or {}) do
                        Tutorial.anchor(k, r[1], r[2], r[3], r[4])
                    end
                end
                Tutorial.update(1 / 30, state, g)
                if Tutorial.activeId() then fired = i / 30 break end
            end
            local got = Tutorial.activeId()
            Tutorial.skipConversation()
            if disarm then disarm() end
            Tutorial._scenarioAnchors = nil
            timing[#timing + 1] = ("%-12s → %s"):format(id, fired and string.format("%.2fs", fired) or "NÃO saiu")
            return got == id and fired and fired <= 1.5, got
        end
        local function A(t2) Tutorial._scenarioAnchors = t2 end
        local run = g.runManager.currentRun
        local cases = {
            { "end_turn", "playing", { "intro" }, function()
                g.selectedCards = {}; g.player.mana = 1 end, function() g.player.mana = g.player.maxMana or 3 end },
            { "second_turn", "playing", { "intro", "end_turn" }, function() g.battleTurn = 1 end,
              function() g.battleTurn = 0 end },
            { "boss", "playing", { "intro" }, function() run.currentNode = { type = "boss" }; g.battleTurn = 0 end,
              function() run.currentNode = { type = "battle" } end },
            { "elite", "playing", { "intro" }, function() run.currentNode = { type = "elite" }; g.battleTurn = 0 end,
              function() run.currentNode = { type = "battle" } end },
            { "block", "playing", { "intro" }, function() g.player.armor = 5 end, function() g.player.armor = 0 end },
            { "fog", "playing", { "intro" }, function() g.enemy.intentVisibility = "type_only" end,
              function() g.enemy.intentVisibility = "full" end },
            { "conduit", "playing", { "intro" }, function()
                g._cls = g.selectedClass; g.selectedClass = "mage"
                g.player.orbs = { { type = "lightning", value = 4 } }
                Tutorial.anchor("orbs", 14, 500, 180, 84); Tutorial.anchor("orb_next", 14, 500, 56, 76)
                Tutorial._scenarioAnchors = nil end,
              function() g.selectedClass = g._cls; g.player.orbs = {} end },
            { "jokers", "playing", { "intro" }, function() run.jokers = { "joker_x" } end,
              function() run.jokers = {} end },
            { "rewards", "cardReward", {}, function()
                Tutorial.setScreens({ cardReward = { visible = true, mode = "rewards" } })
                A({ offers = { 200, 200, 600, 300 }, reward_skip = { 400, 600, 200, 40 } }) end },
            { "shop", "cardReward", {}, function()
                Tutorial.setScreens({ cardReward = { visible = true, mode = "shop" } })
                A({ offers = { 100, 120, 600, 400 } }) end },
            { "dice", "cardReward", { "shop" }, function()
                Tutorial.setScreens({ cardReward = { visible = true, mode = "shop" }, dice = { visible = true } })
                A({ dice_table = { 300, 200, 400, 180 } }) end },
            { "rest", "rest", {}, function()
                Tutorial.setScreens({ rest = { visible = true, mode = "choose" } })
                A({ rest_options = { 300, 400, 400, 80 } }) end },
            { "forge", "rest", {}, function()
                Tutorial.setScreens({ rest = { visible = true, mode = "forge" } })
                A({ forge_cards = { 250, 200, 500, 300 } }) end },
            { "event", "event", {}, function()
                Tutorial.setScreens({ event = { visible = true } })
                A({ event_options = { 300, 420, 420, 160 } }) end },
            { "endless", "mapSelection", {}, function()
                Tutorial.setScreens({ endless = { visible = true } })
                A({ curse_options = { 280, 200, 460, 300 } }) end },
            { "class_select", "classSelection", {}, function()
                A({ class_hero = { 100, 200, 200, 200 }, class_start = { 650, 700, 300, 40 } }) end },
            { "seals", "classSelection", { "class_select" }, function()
                A({ seal_band = { 300, 20, 400, 40 } }) end },
        }
        cases[#cases + 1] = { "combo", "playing", { "intro" }, function()
            g._handBackup = g.hand
            local c = g.hand[1]
            local c2 = setmetatable({}, getmetatable(c))
            for k, v in pairs(c) do c2[k] = v end
            g.hand = { c, c2 }
        end, function() g.hand = g._handBackup end }
        local late = {}
        for _, c in ipairs(cases) do
            local ok, got = scenario(c[1], c[2], c[3], c[4], c[5])
            if not ok then late[#late + 1] = c[1] .. "(" .. tostring(got) .. ")" end
        end
        Tutorial.setScreens({})
        print("     tempo do gatilho até a fala:")
        for _, l in ipairs(timing) do print("       " .. l) end
        t:eq("toda dica de contexto sai em até 1,5s do 1º gatilho (" .. #cases .. " casos)",
            table.concat(late, ","), "")
        ProfileStats.resetTips()
        for _, id in ipairs({ "intro", "end_turn", "second_turn" }) do ProfileStats.markTipSeen(id) end
        Tutorial._reset()
    end

    local GameplayScene = require("src.scenes.GameplayScene")
    local prevSceneGame = GameplayScene.getGame()
    GameplayScene.init({ game = g })
    GameplayScene.resetTurnState()
    Tutorial._quiet = nil
    local run = g.runManager.currentRun
    run.currentNode = { type = "boss" }
    g.battleTurn = 0
    local realMode = GameplayScene.SCENE_MODE
    GameplayScene.SCENE_MODE = "worldroad"
    step(1.0)
    t:falsy("chefe: cena NÃO está quieta antes da cerimônia da porta", GameplayScene.isQuiet())
    t:eq("chefe: nada de narrador durante a cutscene", Tutorial.activeId(), nil)
    GameplayScene._debugForceBossEntered()
    t:truthy("chefe: depois da porta, a cena aquieta", GameplayScene.isQuiet())
    step(1.0)
    t:eq("chefe: a conversa vem depois da porta, no 1º turno", Tutorial.activeId(), "boss")
    Tutorial.skipConversation()
    ProfileStats.resetTips()
    for _, id in ipairs({ "intro", "end_turn", "second_turn", "block", "combo", "conduit", "jokers" }) do
        ProfileStats.markTipSeen(id)
    end
    g.battleTurn = 2
    step(1.0)
    t:eq("chefe no meio da luta (turno 3): não é hora", Tutorial.activeId(), nil)
    GameplayScene.SCENE_MODE = realMode
    GameplayScene.init({ game = prevSceneGame })
    GameplayScene.resetTurnState()
    run.currentNode = { type = "battle" }
    Tutorial._quiet = true

    do
        local UnlockSystem = require("src.systems.UnlockSystem")
        local prevOverride = UnlockSystem.isOverrideAll()
        local prevProf = ProfileStats._swapForTests({ runs = 0, wins = 0 })
        UnlockSystem.setOverrideAll(false)
        UnlockSystem._resetForTests()
        local txt = Tutorial.lockedClassesText()
        local missingReq = {}
        for _, id in ipairs({ "mage", "rogue" }) do
            local info = UnlockSystem.getClassUnlockInfo(id)
            t:falsy("perfil novo: " .. id .. " bloqueado", info.unlocked)
            local req = I18n.t(info.reqKey, info.vars)
            if not txt:find(req, 1, true) then missingReq[#missingReq + 1] = id end
        end
        t:eq("acorrentadas: o corvo lê o requisito do UnlockSystem (mago e ladino)",
            table.concat(missingReq, ","), "")
        t:falsy("acorrentadas: o Guerreiro (aberto) não entra na lista",
            txt:find(I18n.t("classes.warrior.name"), 1, true))

        local CSS = require("components.ClassSelectionScreen")
        local origW, origH, origD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
        local origReal = UiScale.realDimensions
        local badCS = {}
        for _, sz in ipairs({ { 1024, 768 }, { 1280, 800 }, { 1920, 1080 } }) do
            local W, H = sz[1], sz[2]
            love.graphics.getWidth = function() return W end
            love.graphics.getHeight = function() return H end
            love.graphics.getDimensions = function() return W, H end
            UiScale.realDimensions = function() return W, H end
            Tutorial._reset()
            local scr = CSS:new()
            scr:show(function() end, function() end)
            local cv = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas(cv)
            love.graphics.origin()
            scr:draw()
            love.graphics.setCanvas()
            local tag = W .. "x" .. H
            for _, id in ipairs({ "class_hero", "class_start", "class_details", "class_locked" }) do
                local a = Tutorial.anchorRect(id)
                if not a then
                    badCS[#badCS + 1] = tag .. " sem âncora " .. id
                elseif a.x < 0 or a.y < 0 or a.x + a.w > W or a.y + a.h > H then
                    badCS[#badCS + 1] = tag .. " " .. id .. " fora da tela"
                end
            end
            local hb = scr.buttons.help
            local hr = { x = hb.x, y = hb.y, w = hb.width, h = hb.height }
            for _, k in ipairs({ "chooser", "page", "seal", "back", "details", "start" }) do
                if Narrator.overlap(hr, scr.layout[k]) > 0 then badCS[#badCS + 1] = tag .. " '?' cobre " .. k end
            end
            Tutorial._show("class_select", nil, nil)
            local conv = Tutorial.byId("class_select")
            for i, line in ipairs(conv.lines) do
                local spot = Tutorial.spotRect(line.spot)
                local L = Tutorial.layoutFor(Tutorial.lineText(conv, line), spot, line, false)
                local ok, errs = Narrator.validate(L, W, H, spot, Tutorial.avoidZones())
                if not ok then badCS[#badCS + 1] = tag .. " " .. line.id .. ": " .. table.concat(errs, "; ") end
                if line.spot and not spot then badCS[#badCS + 1] = tag .. " " .. line.id .. " sem recorte" end
            end
            local seq = { Tutorial.activeLine() }
            for _ = 1, 8 do
                Tutorial.advance(); Tutorial.advance()
                if Tutorial.activeLine() and Tutorial.activeLine() ~= seq[#seq] then seq[#seq + 1] = Tutorial.activeLine() end
            end
            if tag == "1024x768" then
                t:eq("seleção de classe: ordem das falas", table.concat(seq, ">"),
                    "welcome>warrior>start>locked>details")
            end
            Tutorial._reset()
        end
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = origW, origH, origD
        UiScale.realDimensions = origReal
        for i = 1, math.min(6, #badCS) do print("     " .. badCS[i]) end
        t:eq("seleção de classe: âncoras na tela e corvo sem cobrir o recorte (3 tamanhos)", #badCS, 0)

        UnlockSystem.setOverrideAll(true)
        t:eq("nenhuma classe bloqueada: lista vazia", Tutorial.lockedClassesText(), "")
        Tutorial._show("class_select", "start", nil)
        Tutorial.advance(); Tutorial.advance()
        t:eq("nenhuma bloqueada: de 'começar' vai direto pros detalhes", Tutorial.activeLine(), "details")
        Tutorial._reset()
        ProfileStats.markTipSeen("class_select")
        t:truthy("'?' (explain) reabre a conversa já vista", Tutorial.explain("class_select"))
        Tutorial._reset()

        UnlockSystem.setOverrideAll(prevOverride)
        ProfileStats._swapForTests(prevProf)
        UnlockSystem._resetForTests()
    end

    _G.gameSettings = _G.gameSettings or {}
    local prevTips = _G.gameSettings.tipsEnabled
    Tutorial._forceForTests(false)
    Tutorial._allowHeadless = true
    ProfileStats.resetTips()
    Tutorial._reset()
    g.battleTurn = 0
    step(1.0)
    t:eq("religado: a apresentação volta", Tutorial.activeId(), "intro")
    Tutorial.draw()
    Tutorial.overlay:keypressed("q")
    t:eq("Q/X na 1ª fala: desliga o tutorial", _G.gameSettings.tipsEnabled, false)
    t:eq("e fecha a conversa", Tutorial.activeId(), nil)
    Tutorial._reset()
    step(1.0)
    t:eq("desligado: o corvo não volta", Tutorial.activeId(), nil)
    _G.gameSettings.tipsEnabled = true
    t:check("'Recomeçar o tutorial' devolve quantas esquecia", Tutorial.resetAll() >= 1)
    t:eq("perfil zerado", ProfileStats.tipsSeenCount(), 0)
    _G.gameSettings.tipsEnabled = prevTips
    Tutorial._allowHeadless = nil
    Tutorial._quiet = nil
    Tutorial._reset()
    ProfileStats._swapForTests(prevProfile)

    do
        local path = "profile_tutorial_test.tool.lua"
        love.filesystem.remove(path)
        ProfileStats._setPathForTests(path)
        ProfileStats.markTipSeen("intro")
        ProfileStats._setPathForTests(path)
        t:truthy("conversa vista sobrevive a reabrir o jogo (disco)", ProfileStats.isTipSeen("intro"))
        ProfileStats.resetTips()
        ProfileStats._setPathForTests(path)
        t:falsy("recomeçar também vai pro disco", ProfileStats.isTipSeen("intro"))
        ProfileStats._setPathForTests(nil)
        love.filesystem.remove(path)
    end

    local origW, origH, origD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    local origReal = UiScale.realDimensions
    local bad, checked = {}, 0
    for _, sz in ipairs({ { 1024, 768 }, { 1280, 800 }, { 1920, 1080 }, { 2560, 1440 } }) do
        local W, H = sz[1], sz[2]
        love.graphics.getWidth = function() return W end
        love.graphics.getHeight = function() return H end
        love.graphics.getDimensions = function() return W, H end
        UiScale.realDimensions = function() return W, H end
        local k = UiScale.k(W, H)
        local A = {
            hand = { x = W * 0.30, y = H - 200 * k, w = W * 0.40, h = 190 * k },
            mana = { x = W - 90 * k, y = H - 90 * k, w = 60 * k, h = 60 * k },
            intent = { x = W / 2 - 45 * k, y = H * 0.22, w = 90 * k, h = 48 * k },
            enemy = { x = W / 2 - 80 * k, y = H * 0.25, w = 160 * k, h = 230 * k },
            play = { x = W * 0.80, y = H * 0.78, w = 150 * k, h = 46 * k },
            end_turn = { x = W * 0.80, y = H * 0.78 + 54 * k, w = 150 * k, h = 33 * k },
            player_panel = { x = 14 * k, y = H - 110 * k, w = 220 * k, h = 90 * k },
            preview = { x = W * 0.74, y = H * 0.62, w = 230 * k, h = 90 * k },
            jokers = { x = 14 * k, y = 88 * k, w = 290 * k, h = 160 * k },
            orbs = { x = 10 * k, y = H - 210 * k, w = 184 * k, h = 84 * k },
            orb_next = { x = 10 * k, y = H - 210 * k, w = 56 * k, h = 76 * k },
            buff_focus = { x = 14 * k, y = H - 150 * k, w = 36 * k, h = 36 * k },
            hand_channel = { x = W * 0.30, y = H - 200 * k, w = 130 * k, h = 190 * k },
            hand_evoke = { x = W * 0.44, y = H - 200 * k, w = 130 * k, h = 190 * k },
            offers = { x = W * 0.25, y = H * 0.28, w = W * 0.50, h = H * 0.36 },
            reward_skip = { x = W / 2 - 80 * k, y = H * 0.70, w = 160 * k, h = 36 * k },
            shop_refresh = { x = W * 0.62, y = H * 0.84, w = 170 * k, h = 36 * k },
            shop_prices = { x = W * 0.12, y = H * 0.50, w = W * 0.55, h = H * 0.34 },
            shop_scroll = { x = W * 0.73, y = H * 0.13, w = W * 0.24, h = H * 0.70 },
            shop_dice = { x = W * 0.42, y = H * 0.84, w = 130 * k, h = 32 * k },
            dice_table = { x = W * 0.32, y = H * 0.25, w = W * 0.36, h = H * 0.22 },
            dice_bets = { x = W * 0.32, y = H * 0.52, w = W * 0.36, h = H * 0.10 },
            forge_cards = { x = W * 0.25, y = H * 0.25, w = W * 0.50, h = H * 0.40 },
            rest_options = { x = W / 2 - 200 * k, y = H * 0.55, w = 400 * k, h = 60 * k },
            event_options = { x = W * 0.30, y = H * 0.55, w = W * 0.40, h = H * 0.22 },
            curse_options = { x = W * 0.28, y = H * 0.28, w = W * 0.44, h = H * 0.40 },
            seal_band = { x = W * 0.30, y = H * 0.80, w = W * 0.40, h = 44 * k },
        }
        local function rectFor(spot)
            if spot == nil then return nil end
            if type(spot) == "function" then
                return { x = W * 0.35, y = H * 0.45, w = W * 0.30, h = H * 0.20 }
            end
            if type(spot) == "string" then return A[spot] end
            local x1, y1, x2, y2
            for _, id in ipairs(spot) do
                local a = A[id]
                if a then
                    x1 = math.min(x1 or a.x, a.x); y1 = math.min(y1 or a.y, a.y)
                    x2 = math.max(x2 or (a.x + a.w), a.x + a.w); y2 = math.max(y2 or (a.y + a.h), a.y + a.h)
                end
            end
            return x1 and { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
        end
        for _, loc in ipairs({ "pt_BR", "de" }) do
            I18n.setLocale(loc, true)
            for _, conv in ipairs(Tutorial.SCRIPT) do
                for i, line in ipairs(conv.lines) do
                    local spot = rectFor(line.spot)
                    local text = Tutorial.lineText(conv, line)
                    local L = Tutorial.layoutFor(text, spot, line, conv.id == "intro" and i == 1)
                    local ok, errs = Narrator.validate(L, W, H, spot, Tutorial.avoidZones())
                    checked = checked + 1
                    if not ok then
                        bad[#bad + 1] = ("%dx%d %s %s.%s: %s"):format(W, H, loc, conv.id, line.id,
                            table.concat(errs, "; "))
                    end
                end
            end
        end
    end
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = origW, origH, origD
    UiScale.realDimensions = origReal
    I18n.setLocale("pt_BR", true)
    for i = 1, math.min(6, #bad) do print("     " .. bad[i]) end
    t:eq(("narrador nunca sai da tela, cobre o recorte ou a TopBar (%d falas × tamanhos × idiomas)")
        :format(checked), #bad, 0)

    local GuideScreen = require("components.GuideScreen")
    local ComboSystem = require("src.systems.ComboSystem")
    local gbad = {}
    for _, loc in ipairs(LOCALES) do
        I18n.setLocale(loc, true)
        local combos = GuideScreen.comboEntries("warrior")
        if #combos ~= #ComboSystem.RULES then gbad[#gbad + 1] = loc .. ": nº de combos" end
        for _, e in ipairs(combos) do
            if e.title == e.id or e.effect == "" then gbad[#gbad + 1] = loc .. ":" .. e.id end
        end
        local gl = GuideScreen.glossaryEntries()
        if #gl ~= #require("src.data.keywords") then gbad[#gbad + 1] = loc .. ": glossário" end
        for _, e in ipairs(gl) do
            if e.title == e.id or e.effect == "" then gbad[#gbad + 1] = loc .. ":kw:" .. e.id end
        end
    end
    I18n.setLocale("pt_BR", true)
    t:eq("Guia: todo combo (nome + regra/efeito) e todo verbete nos 5 idiomas",
        table.concat(gbad, ","), "")
    local withEx = 0
    for _, e in ipairs(GuideScreen.comboEntries("warrior")) do
        if e.examples ~= "" then withEx = withEx + 1 end
    end
    t:check("Guia: combos trazem cartas de exemplo", withEx >= #ComboSystem.RULES - 2)
    local gs = GuideScreen:new()
    gs:show(g)
    gs:keypressed("right")
    t:eq("→ / RB troca para o glossário", gs.tab, 2)
    gs:keypressed("escape")
    t:falsy("Esc / B fecha o Guia", gs:isVisible())

    Tutorial._forceForTests(false)
    Tutorial._reset()
    return t:done()
end

return M
