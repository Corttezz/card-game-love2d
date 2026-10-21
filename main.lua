require("src.core.Release").install()

local Game = require("src.core.Game")
local CardFrame = require("src.ui.CardFrame")
local Button = require("components.Button")
local Menu = require("components.Menu")
local GameUI = require("components.GameUI")
local CardRewardScreen = require("components.CardRewardScreen")
local ClassSelectionScreen = require("components.ClassSelectionScreen")
local CollectionScreen = require("components.CollectionScreen")
local SettingsMenu = require("components.SettingsMenu")
local TopBar = require("components.TopBar")
local MapScreen = require("components.MapScreen")
local MapManager = require("src.systems.MapManager")
local RestScreen = require("components.RestScreen")
local EventScreen = require("components.EventScreen")
local Events = require("src.data.events")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local SmokeSystem = require("src.systems.SmokeSystem")
local SmokeConfig = require("src.config.SmokeConfig")
local AudioManager = require("engine.AudioManager")
local SaveManager  = require("engine.SaveManager")
local CRTShader = require("src.ui.CRTShader")
local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")
local EventManager = require("engine.EventManager")
local Event = require("engine.Event")
local DissolveShader = require("src.ui.DissolveShader")
local FlashShader = require("src.ui.FlashShader")
local BoosterShader = require("src.ui.BoosterShader")
local FoilShader = require("src.ui.FoilShader")
local PolychromeShader = require("src.ui.PolychromeShader")
local Debug = require("src.core.Debug")
local PackOpenScreen = require("components.PackOpenScreen")
local FloatingText = require("src.ui.FloatingText")
local RoundEvalScreen = require("components.RoundEvalScreen")
local CardParticles = require("src.systems.CardParticles")
local ScreenShake = require("src.systems.ScreenShake")
local EndScreens = require("src.scenes.EndScreens")
local GameplayScene = require("src.scenes.GameplayScene")
local BootScene = require("src.scenes.BootScene")

local game
local menu
local gameUI
local cardRewardScreen
local classSelectionScreen
local collectionScreen
local achievementsScreen
local endTurnButton
local settingsMenu
local pauseMenu
local topBar
local mapScreen
local deckViewerScreen
local restScreen
local eventScreen
local packOpenScreen
local roundEvalScreen
local playButton
local currentState = "boot"

local smokeSystem
local audioSystem

local function startGame(classId, seal)
    currentState = "playing"

    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.5, 0.4) end

    game:startNewRun(classId, { seal = seal or 0 })

    game:startGame()
    game:checkpointRun()
    gameUI:show()
    classSelectionScreen:hide()
    GameplayScene.requestArrival()

    if smokeSystem then
        SmokeConfig.applyToSystem(smokeSystem, "act1")
    end
end

local function returnToMenu()
    if currentState ~= "menu" then Sfx.play("menuClose") end
    currentState = "menu"

    EventManager.clear()

    require("src.ui.InputFocus").hideAll()
    if cardRewardScreen and cardRewardScreen:isVisible() then cardRewardScreen:hide() end
    require("src.ui.EndTransition").clear()
    if CRTShader.getPower and CRTShader.getPower() < 1 then CRTShader.powerOn(0.6) end

    if game and game.runManager then
        game.runManager.currentRun = nil
        game.runManager.isRunActive = false
    end
    require("src.systems.Rng").clearActive()

    game = Game:new()
    if cardRewardScreen then cardRewardScreen.shopSystem = game.shopSystem end
    if topBar then topBar:setGame(game) end
    GameplayScene.setGame(game)
    gameUI:hide()
    menu:show()
    if menu.enterWithIntro then menu:enterWithIntro() end
end

local function replayRun()
    local classe = game and game.selectedClass
    if not classe and game and game.runManager and game.runManager.currentRun then
        classe = game.runManager.currentRun.classId
    end
    if classe then
        local run = game and game.runManager and game.runManager.currentRun
        local seal = math.min((run and run.seal) or 0,
            require("src.systems.UnlockSystem").getMaxSeal(classe))
        startGame(classe, seal)
    else
        Debug.warn("[replay] run sem classe conhecida — abrindo a selecao de classe")
        currentState = "classSelection"
        classSelectionScreen:show(
            function(classId, seal) startGame(classId, seal) end,
            function() returnToMenu() end)
    end
end

local showMapSelection

local function applyActSmoke()
    if not smokeSystem or not game or not game.runManager then return end
    local run = game.runManager.currentRun
    if not run then return end
    local preset
    local porAto = { "act1", "act2", "act3", "act1", "act2", "act3" }
    if run.endlessMode then preset = "act3"
    else preset = porAto[run.actNumber] or "act3" end
    SmokeConfig.applyToSystem(smokeSystem, preset)
end

_G.openCardPicker = function(mode, onDone)
    local prevState = currentState
    currentState = "rest"
    restScreen.pickerFrom = prevState
    restScreen:show(game, function()
        restScreen.pickerFrom = nil
        currentState = prevState
        if onDone then onDone(restScreen.lastPickDone == true) end
    end, mode or "forge")
end

_G.openForgeScreen = function(onDone)
    _G.openCardPicker("forge", onDone)
end

local function skipBattleAndShowMap()
    game._exhaustedThisBattle = game._exhaustedThisBattle or {}
    showMapSelection()
    game:checkpointRun()
end

local function setRunStage(stage, extra)
    local run = game and game.runManager and game.runManager.currentRun
    if not run then return end
    run.stage = stage
    run.stageEventId = extra
    game:checkpointRun()
end

local function openNonBattleNode(t, eventId)
    local BT = MapManager.NODE_TYPES
    if t == BT.REST then
        mapScreen:hide()
        currentState = "rest"
        restScreen.pickerFrom = nil
        setRunStage("rest")
        restScreen:show(game, function()
            currentState = "mapSelection"
            skipBattleAndShowMap()
        end)
        return true
    elseif t == BT.EVENT then
        mapScreen:hide()
        local run = game.runManager.currentRun
        run.eventHistory = run.eventHistory or {}
        local ev = eventId and Events.get(eventId) or nil
        if not ev then
            ev = Events.roll(run.actNumber or 1, run.eventHistory,
                require("src.systems.EnemyRoster").biomeAct(run))
            if not ev then return false end
            run.eventHistory[ev.id] = run.actNumber or 1
            game.runManager:journalEvent(ev.id, nil, nil)
        end
        currentState = "event"
        setRunStage("event", ev.id)
        eventScreen:show(ev, game, function()
            skipBattleAndShowMap()
        end)
        return true
    elseif t == BT.SHOP then
        mapScreen:hide()
        currentState = "cardReward"
        setRunStage("shop")
        cardRewardScreen:show(game,
            function(offer)
            end,
            function()
                skipBattleAndShowMap()
            end,
            "shop"
        )
        return true
    end
    return false
end

local function onNodeChosen(node, index)
    if not node then return end
    game.runManager:chooseNode(index, {
        hp = game.player and game.player.health,
        maxHp = game.player and game.player.maxHealth,
        gold = game.economySystem and game.economySystem.currentGold,
    })

    local t = node.type
    local BT = MapManager.NODE_TYPES

    if t == BT.BATTLE or t == BT.ELITE or t == BT.MINI_BOSS or t == BT.BOSS then
        mapScreen:hide()
        currentState = "playing"
        if FlashShader and FlashShader.trigger then
            local intensity = (t == BT.BOSS or t == BT.MINI_BOSS) and 0.7 or 0.4
            FlashShader.trigger(intensity, 0.45)
        end
        game:nextPhase()
        applyActSmoke()

    elseif t == BT.REST or t == BT.EVENT or t == BT.SHOP then
        if not openNonBattleNode(t) then
            mapScreen:hide()
            currentState = "playing"
            game:nextPhase()
        end
    else
        mapScreen:hide()
        currentState = "playing"
        game:nextPhase()
    end
end

showMapSelection = function()
    game.runManager:journalEnd({
        hp = game.player and game.player.health,
        maxHp = game.player and game.player.maxHealth,
        gold = game.economySystem and game.economySystem.currentGold,
    })

    if not game.runManager:getPendingNodes() then
        local status = game.runManager:advanceFloorInAct()
        if status == "endless_start" then
            game:addMessage(I18n.t("messages.endless_unlocked", nil,
                "Modo Endless desbloqueado!"), "success")
        end
        game.runManager:generateNextNodes(3)
    end
    local pending = game.runManager:getPendingNodes()
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    if GameplayScene.SCENE_MODE == "worldroad"
       and WorldRoad.showFork(pending, onNodeChosen) then
        currentState = "mapSelection"
    else
        mapScreen:show(pending, onNodeChosen)
        currentState = "mapSelection"
    end
    setRunStage("fork")
end
_G.__showMapSelection = function() showMapSelection() end

local function continueAfterReward()
    if game.gameState == "victory" then
        currentState = "victory"
    else
        showMapSelection()
    end
end

local showRoundEval
local showCardRewards

showRoundEval = function()
    currentState = "roundEval"
    setRunStage("cashout")

    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.4, 0.35) end
    Sfx.play("battleVictory")

    local sources = game:_buildRoundEvalSources()
    roundEvalScreen:show(game, sources, function()
        showCardRewards()
    end)
end

showCardRewards = function()
    currentState = "cardReward"
    setRunStage("rewards")

    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.4, 0.35) end

    cardRewardScreen:show(game,
        function(offer)
        end,
        function()
            continueAfterReward()
        end,
        "rewards"
    )
end

EndScreens.setCallbacks({
    onRetry = function() replayRun() end,
    onMenu = function() returnToMenu() end,
    onEndless = function()
        if not game:enterEndless() then
            Debug.warn("[endless] enterEndless recusou (run sem vitoria registrada?)")
            return
        end
        require("src.ui.EndTransition").clear()
        showRoundEval()
    end,
})

_G.__resumeRunStage = function()
    local run = game and game.runManager and game.runManager.currentRun
    local action = require("src.systems.ResumeFlow").stageAction(run)
    if action == "battle" or action == "fork" then return false end
    if action == "map" then showMapSelection() return true end
    if game.enemy then
        game.enemy.health = 0
        game._deathHandled, game._deathStaged = true, true
        require("src.ui.EnemyRenderer").triggerDeath(game.enemy.spriteId)
        require("src.ui.BossCinematic").markDeathSeen(game)
    end
    if action == "cashout" then showRoundEval() return true end
    if action == "rewards" then showCardRewards() return true end
    local BT = MapManager.NODE_TYPES
    local t = (action == "rest" and BT.REST) or (action == "event" and BT.EVENT)
        or (action == "shop" and BT.SHOP)
    if openNonBattleNode(t, run.stageEventId) then return true end
    showMapSelection()
    return true
end

_G.__cheatApi = {
    game = function() return game end,
    state = function() return currentState end,
    showMapSelection = function() showMapSelection() end,
    showRoundEval = function() showRoundEval() end,
    onNodeChosen = function(node, index) onNodeChosen(node, index) end,
    startGame = function(classId, seal) startGame(classId, seal or 0) end,
    returnToMenu = function() returnToMenu() end,
    screens = function()
        return {
            reward = cardRewardScreen, roundEval = roundEvalScreen, map = mapScreen,
            rest = restScreen, event = eventScreen, packOpen = packOpenScreen,
            menu = menu, settings = settingsMenu, collection = collectionScreen,
            classSelect = classSelectionScreen,
        }
    end,
}

function love.load(loveArgs)
    require("src.ui.UiScale").adoptDefaults()
    loveArgs = require("src.core.Release").filterArgs(loveArgs)
    loveArgs = require("src.systems.CheatMode").claimArgs(loveArgs)
    local toolArg = loveArgs and loveArgs[1]
    if toolArg then
        _G.HEADLESS_TOOL = true
        require("src.systems.UnlockSystem").setOverrideAll(true)
        if os.getenv("TOOL_WINDOW") then
            local tw, th = os.getenv("TOOL_WINDOW"):match("^(%d+)x(%d+)$")
            if tw then
                love.window.setMode(tonumber(tw), tonumber(th), { resizable = true })
            end
        end
        local HW = require("tools.headless_window")
        if HW.active() and not os.getenv("TOOL_WINDOW") then
            local okM, errM = pcall(love.window.setMode, 1024, 768, {
                borderless = true, resizable = false, vsync = false,
                x = -32000, y = -32000,
            })
            if not okM then
                Debug.warn("[sandbox] janela headless 1024x768 falhou: " .. tostring(errM))
            end
            HW.hide()
        end
    end
    require("src.systems.UnlockSystem").ensure()

    if toolArg and (tostring(toolArg):match("^screenshot_")
                    or tostring(toolArg):match("^preview_")) then
        _G.TOOL_FORCE_LOCALE = os.getenv("TOOL_LOCALE") or "pt_BR"
    end

    if not toolArg and Debug.enabled then
        pcall(love.filesystem.append, "reward_debug.log",
            ("[RDBG] ===== BOOT v%s em %s =====\n"):format(
                tostring(require("src.core.Config").VERSION), os.date("%H:%M:%S")))
        pcall(love.filesystem.write, "feel_debug.log",
            ("[FEEL] ===== BOOT v%s em %s =====\n"):format(
                tostring(require("src.core.Config").VERSION), os.date("%H:%M:%S")))
    end

    if loveArgs and loveArgs[1] == "preview_cards" then
        require("src.ui.PixelCanvas").enableNearest()
        I18n.init()
        require("tools.preview_cards").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_button_border" then
        require("tools.preview_button_border").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_card_art_fix" then
        require("src.ui.PixelCanvas").enableNearest()
        I18n.init()
        require("tools.preview_card_art_fix").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_fx" then
        require("src.ui.PixelCanvas").enableNearest()
        I18n.init()
        require("tools.preview_fx").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_rareglow" then
        require("src.ui.PixelCanvas").enableNearest()
        I18n.init()
        require("tools.preview_rareglow").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_anim" then
        require("src.ui.PixelCanvas").enableNearest()
        I18n.init()
        require("tools.preview_anim").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_card_anim" then
        require("tools.preview_card_anim").run(loveArgs[2])
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_gameplay" then
        require("tools.screenshot_gameplay").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_mapscreen" then
        require("tools.screenshot_mapscreen").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_enemy_scene" then
        require("tools.screenshot_enemy_scene").run(loveArgs[2])
        return
    end
    if loveArgs and loveArgs[1] == "screenshot_resume_boss" then
        require("tools.screenshot_resume_boss").run(loveArgs[2])
        return
    end
    if loveArgs and loveArgs[1] == "screenshot_worldroad" then
        require("tools.screenshot_worldroad").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "measure_lightpool" then
        require("tools.measure_lightpool").run(loveArgs[2])
        return
    end

    local autoPlayClass = nil
    if loveArgs and loveArgs[1] == "play" then
        autoPlayClass = loveArgs[2] or "warrior"
    end

    if loveArgs and loveArgs[1] == "screenshot_bootfx" then
        require("tools.screenshot_bootfx").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_rewards" then
        require("tools.screenshot_rewards").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_event" then
        local ok = require("tools.screenshot_event").run(loveArgs[2])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "check_event_i18n" then
        local ok = require("tools.check_event_i18n").run(loveArgs[2])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "check_font_metrics" then
        local ok = require("tools.check_font_metrics").run(loveArgs[2])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_cashout" then
        local ok = require("tools.screenshot_cashout").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_event_anim" then
        local ok = require("tools.screenshot_event_anim").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "sfx_envelope" then
        local ok = require("tools.sfx_envelope").run(loveArgs[2], loveArgs[3])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "check_music" then
        local ok = require("tools.check_music").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "preview_coinburst" then
        require("tools.preview_coinburst").run()
        return
    end

    if loveArgs and loveArgs[1] == "probe_continue" then
        require("tools.probe_continue").run()
        return
    end

    if loveArgs and loveArgs[1] == "orb_compare" then
        require("tools.orb_compare").run()
        return
    end

    if loveArgs and loveArgs[1] == "bake_orb_anim" then
        local ok = require("tools.bake_orb_anim").run(loveArgs[2], loveArgs[3], loveArgs[4])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "orb_anim_compare" then
        local ok = require("tools.orb_anim_compare").run(loveArgs[2])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "orb_zoom" then
        require("tools.orb_zoom").run(loveArgs[2], loveArgs[3])
        return
    end

    if loveArgs and loveArgs[1] == "dim" then
        require("tools.dim").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "anim_drift" then
        local ok = require("tools.anim_drift").run(loveArgs[2])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "scan_clones" then
        local ok = require("tools.scan_clones").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "grade_locais" then
        local ok = require("tools.grade_locais").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "sheet" then
        local ok = require("tools.sheet").run(loveArgs[2], loveArgs[3], loveArgs[4])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "check_loop" then
        local ok = require("tools.check_loop").run(loveArgs[2])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "check_sfx" then
        local ok = require("tools.check_sfx").run(loveArgs[2])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_forge" then
        local w, h = loveArgs[2], loveArgs[3]
        if w == "-" then w = nil end
        if h == "-" then h = nil end
        require("tools.screenshot_forge").run(w, h, loveArgs[4])
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_death" then
        require("tools.screenshot_death").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_endscreens" then
        require("tools.screenshot_endscreens").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_achievements" then
        require("tools.screenshot_achievements").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "preview_battle_hud" then
        _G.PREVIEW_HUD_CAP = (loveArgs[2] == "cap")
        _G.PREVIEW_HUD_ORB = (loveArgs[2] == "orb")
        _G.PREVIEW_HUD_PULSE = (loveArgs[2] == "pulse")
        _G.PREVIEW_HUD_ORBS = (loveArgs[2] == "orbs")
        _G.PREVIEW_HUD_ORBS_EVOKE = (loveArgs[3] == "evoke")
        _G.PREVIEW_HUD_ORBS_ANIM = (loveArgs[3] == "anim")
        require("tools.preview_battle_hud").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_card_live" then
        require("tools.preview_card_live").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "smoke_tags" then
        local ok = require("tools.smoke_tags").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_effects" then
        local ok = require("tools.smoke_effects").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_combos" then
        local ok = require("tools.smoke_combos").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_map" then
        local ok = require("tools.smoke_map").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "test_systems" then
        local ok = require("tools.test_systems").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_acts" then
        local ok = require("tools.smoke_acts").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_discard" then
        local ok = require("tools.smoke_discard").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_upgrades" then
        local ok = require("tools.smoke_upgrades").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_shop" then
        local ok = require("tools.smoke_shop").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_packs" then
        local ok = require("tools.smoke_packs").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_packopen" then
        require("tools.screenshot_packopen").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_shop" then
        require("tools.screenshot_shop").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_collection" then
        require("tools.screenshot_collection").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_unlocks" then
        require("tools.screenshot_unlocks").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_round_eval" then
        require("tools.screenshot_round_eval").run(loveArgs[2], loveArgs[3])
        return
    end

    if loveArgs and loveArgs[1] == "test_saveflow" then
        local ok = require("tools.test_saveflow").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_turnbanner" then
        require("tools.screenshot_turnbanner").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_combobanner" then
        require("tools.screenshot_combobanner").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_cursor" then
        require("tools.screenshot_cursor").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_menuanim" then
        require("tools.screenshot_menuanim").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_ui" then
        require("tools.screenshot_ui").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_topbar_gear" then
        require("tools.screenshot_topbar_gear").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_crt" then
        require("tools.screenshot_crt").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_attack" then
        require("tools.screenshot_attack").run()
        return
    end

    if loveArgs and loveArgs[1] == "autoplay" then
        require("tools.autoplay").run(loveArgs[2], loveArgs[3], loveArgs[4])
        return
    end

    if loveArgs and loveArgs[1] == "balance_sim" then
        require("tools.balance_sim").run(loveArgs[2], loveArgs[3], loveArgs[4], loveArgs[5])
        return
    end
    if loveArgs and loveArgs[1] == "leak_probe" then
        require("tools.leak_probe").run(loveArgs[2], loveArgs[3], loveArgs[4], loveArgs[5])
        return
    end
    if loveArgs and loveArgs[1] == "balance_bench" then
        require("tools.balance_bench").run(loveArgs[2], loveArgs[3], loveArgs[4], loveArgs[5])
        return
    end

    if loveArgs and loveArgs[1] == "validate_cards" then
        local ok = require("tools.validate_cards").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_ui_turn" then
        local ok = require("tools.smoke_ui_turn").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_menu_v2" then
        require("tools.screenshot_menu_v2").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_class_select" then
        require("tools.screenshot_class_select").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_joker_manager" then
        require("tools.screenshot_joker_manager").run()
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_journal" then
        local mode = loveArgs[2]
        if mode == "-" then mode = nil end
        require("tools.screenshot_journal").run(mode, loveArgs[3])
        return
    end

    if loveArgs and loveArgs[1] == "screenshot_pause" then
        require("tools.screenshot_pause").run(loveArgs[2])
        return
    end

    if loveArgs and loveArgs[1] == "smoke_crt_mouse" then
        local ok = require("tools.smoke_crt_mouse").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_turn_order" then
        local ok = require("tools.smoke_turn_order").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "test_one" and loveArgs[2] then
        local ok = require("tools." .. loveArgs[2]).run(loveArgs[3])
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "test_all" then
        local ok = require("tools.run_all_tests").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "test_i18n" then
        local ok = require("tools.test_i18n").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    if loveArgs and loveArgs[1] == "smoke_all" then
        local okT = require("tools.smoke_tags").run()
        local okE = require("tools.smoke_effects").run()
        local okC = require("tools.smoke_combos").run()
        local okM = require("tools.smoke_map").run()
        local okA = require("tools.smoke_acts").run()
        local okD = require("tools.smoke_discard").run()
        local okU = require("tools.smoke_upgrades").run()
        local okS = require("tools.smoke_shop").run()
        local okP = require("tools.smoke_packs").run()
        local okO = require("tools.smoke_turn_order").run()
        local okUI = require("tools.smoke_ui_turn").run()
        local okCRT = require("tools.smoke_crt_mouse").run()
        local ok = okT and okE and okC and okM and okA and okD and okU and okS and okP and okO and okUI and okCRT
        require("tools.testkit").verdict(ok)
        love.event.quit(ok and 0 or 1)
        return
    end

    I18n.init()

    I18n.onLocaleChanged(function()
        love.window.setTitle(I18n.t("window_title"))
    end)

    local persistedSettings = SaveManager.loadSettings()

    if not _G.HEADLESS_TOOL then
        local WindowPlacement = require("src.core.WindowPlacement")
        local display = WindowPlacement.restore(persistedSettings)
        if persistedSettings.fullscreen then
            love.window.setFullscreen(true)
        else
            local okDim, dw, dh = pcall(love.window.getDesktopDimensions, display)
            if okDim then
                local alvoW, alvoH = Config.Utils.tamanhoJanelaInicial(
                    dw, dh, love.graphics.getWidth())
                if alvoW then
                    local _, _, flags = love.window.getMode()
                    flags.centered = true
                    flags.display = display
                    love.window.setMode(alvoW, alvoH, flags)
                end
            end
            WindowPlacement.restorePosition(persistedSettings, display)
        end
    end

    audioSystem = AudioManager:new({
        masterVolume = persistedSettings.masterVolume,
        musicVolume  = persistedSettings.musicVolume,
        sfxVolume    = persistedSettings.sfxVolume,
        ambientVolume = persistedSettings.ambientVolume,
    })
    audioSystem:printStatus()

    _G.audioSystem = audioSystem
    _G.persistedSettings = persistedSettings

    _G.gameSettings = persistedSettings
    SettingsMenu.applyRuntime(persistedSettings)

    _G.EventManager = EventManager
    _G.Event = Event

    if audioSystem:isAudioAvailable() then
        audioSystem:loadSound("menuMusic", "audio/music.mp3", {
            volume = 0.43,
            group  = "music",
            stream = true,
            loop   = true,
        })

        require("src.systems.MusicDirector").registerTracks(audioSystem)

        audioSystem:loadSound("hoverCard", "audio/hoverCard.wav", Config.Audio.HOVER_VOLUME)
        audioSystem:loadSound("cardSelect", "audio/clickselect2-92097.mp3", Config.Audio.CLICK_SELECT_VOLUME)
        audioSystem:loadSound("deckStart", "audio/deckStart.mp3", Config.Audio.DECK_START_VOLUME)
        audioSystem:loadSound("swordSound", "audio/sword-sound-260274.mp3", 0.7)
        audioSystem:loadSound("armorSound", "audio/punching-light-armour-87442.mp3", 0.7)

        audioSystem:loadSound("cardPlayAttack", "audio/sfx/card-play-attack.mp3", Config.Audio.CARD_PLAY_ATTACK_VOLUME)
        audioSystem:loadSound("cardPlayDefense", "audio/sfx/card-play-defense.mp3", Config.Audio.CARD_PLAY_DEFENSE_VOLUME)
        audioSystem:loadSound("cardDraw", "audio/sfx/card-draw.mp3", Config.Audio.CARD_DRAW_VOLUME)
        audioSystem:loadSound("cardExhaust", "audio/sfx/card-exhaust.mp3", Config.Audio.CARD_EXHAUST_VOLUME)
        audioSystem:loadSound("comboTrigger", "audio/sfx/combo-trigger.mp3", Config.Audio.COMBO_TRIGGER_VOLUME)
        audioSystem:loadSound("jokerActivate", "audio/sfx/joker-activate.mp3", Config.Audio.JOKER_ACTIVATE_VOLUME)
        audioSystem:loadSound("orbChannel", "audio/sfx/orb-channel.mp3", Config.Audio.ORB_CHANNEL_VOLUME)
        audioSystem:loadSound("orbEvoke", "audio/sfx/orb-evoke.mp3", Config.Audio.ORB_EVOKE_VOLUME)
        audioSystem:loadSound("debuffApplied", "audio/sfx/debuff-applied.mp3", Config.Audio.DEBUFF_APPLIED_VOLUME)
        audioSystem:loadSound("strengthGain", "audio/sfx/strength-gain.mp3", Config.Audio.STRENGTH_GAIN_VOLUME)
        audioSystem:loadSound("poisonTick", "audio/sfx/poison-tick.mp3", Config.Audio.POISON_TICK_VOLUME)
        audioSystem:loadSound("enemyAttack", "audio/sfx/enemy-attack.mp3", Config.Audio.ENEMY_ATTACK_VOLUME)
        audioSystem:loadSound("enemyDeath", "audio/sfx/enemy-death.mp3", Config.Audio.ENEMY_DEATH_VOLUME)
        audioSystem:loadSound("buttonClick", "audio/sfx/button-click.mp3", Config.Audio.BUTTON_CLICK_VOLUME)
        audioSystem:loadSound("menuOpen", "audio/sfx/menu-open.mp3", Config.Audio.MENU_OPEN_VOLUME)
        audioSystem:loadSound("menuClose", "audio/sfx/menu-close.mp3", Config.Audio.MENU_CLOSE_VOLUME)
        audioSystem:loadSound("menuHover", "audio/sfx/menu-hover.mp3", Config.Audio.MENU_HOVER_VOLUME)
        audioSystem:loadSound("collectionFlip", "audio/sfx/collection-flip.mp3", Config.Audio.COLLECTION_FLIP_VOLUME)
        audioSystem:loadSound("purchaseConfirm", "audio/sfx/purchase-confirm.mp3", Config.Audio.PURCHASE_CONFIRM_VOLUME)
        audioSystem:loadSound("cardDiscovered", "audio/sfx/card-discovered.mp3", Config.Audio.CARD_DISCOVERED_VOLUME)
        audioSystem:loadSound("purchaseDeny", "audio/sfx/purchase-deny.mp3", Config.Audio.PURCHASE_DENY_VOLUME)
        require("src.systems.WeatherAudio").registerSounds(audioSystem)
        require("src.systems.PlaceAudio").registerSounds(audioSystem)
        audioSystem:loadSound("battleVictory", "audio/sfx/battle-victory.mp3", Config.Audio.BATTLE_VICTORY_VOLUME)
        audioSystem:loadSound("goldGain", "audio/sfx/gold-gain.mp3", Config.Audio.GOLD_GAIN_VOLUME)
        audioSystem:loadSound("nodeSelect", "audio/sfx/node-select.mp3", Config.Audio.NODE_SELECT_VOLUME)
        audioSystem:loadSound("restComplete", "audio/sfx/rest-complete.mp3", Config.Audio.REST_COMPLETE_VOLUME)
        audioSystem:loadSound("actComplete", "audio/sfx/act-complete.mp3", Config.Audio.ACT_COMPLETE_VOLUME)
        audioSystem:loadSound("runVictory", "audio/sfx/run-victory.mp3", Config.Audio.RUN_VICTORY_VOLUME)
        audioSystem:loadSound("runDefeat", "audio/sfx/run-defeat.mp3", Config.Audio.RUN_DEFEAT_VOLUME)

        audioSystem:loadSound("coinClink",     "audio/sfx/coin-clink.mp3",       0.55)
        audioSystem:loadSound("coinTotalThud", "audio/sfx/coin-total-thud.mp3",  0.65)
        audioSystem:loadSound("cashOutChime",  "audio/sfx/cash-out-chime.mp3",   0.55)
        audioSystem:loadSound("packSealBreak", "audio/sfx/pack-seal-break.mp3",  0.70)
        audioSystem:loadSound("packCardReveal","audio/sfx/pack-card-reveal.mp3", 0.55)
        audioSystem:loadSound("packCardPick",  "audio/sfx/pack-card-pick.mp3",   0.65)
        audioSystem:loadSound("shopOpen",      "audio/sfx/shop-open.mp3",        0.65)
        audioSystem:loadSound("shopReroll",    "audio/sfx/shop-reroll.mp3",      0.60)

        audioSystem:loadSound("forkHoverFire",  "audio/sfx/fork-hover-fire.mp3",  0.40)
        audioSystem:loadSound("forkHoverDoor",  "audio/sfx/fork-hover-door.mp3",  0.24)
        audioSystem:loadSound("forkHoverFlag",  "audio/sfx/fork-hover-flag.mp3",  0.36)
        audioSystem:loadSound("forkHoverElite", "audio/sfx/fork-hover-elite.mp3", 0.40)
        audioSystem:loadSound("forkHoverTent",  "audio/sfx/fork-hover-tent.mp3",  0.36)

        audioSystem:loadSound("sceneRustle",     "audio/sfx/scene-rustle.mp3",      0.34)
        audioSystem:loadSound("sceneWoodKnock",  "audio/sfx/scene-wood-knock.mp3",  0.36)
        audioSystem:loadSound("sceneLampCreak",  "audio/sfx/scene-lamp-creak.mp3",  0.34)
        audioSystem:loadSound("sceneLampWood",   "audio/sfx/scene-lamp-wood.mp3",   0.34)
        audioSystem:loadSound("sceneStoneThud",  "audio/sfx/scene-stone-thud.mp3",  0.36)
        audioSystem:loadSound("sceneGrassSwish", "audio/sfx/scene-grass-swish.mp3", 0.26)
        audioSystem:loadSound("sceneCloudPoof",  "audio/sfx/scene-cloud-poof.mp3",  0.32)

        audioSystem:loadSound("castleGateOpen",  "audio/sfx/castle-gate-open.mp3",  0.62)
        audioSystem:loadSound("castleGateMagic", "audio/sfx/castle-gate-magic.mp3", 0.58)

        for code, path in pairs({
            forgeStrike = "audio/sfx/forge-strike.mp3",
            forgeReveal = "audio/sfx/forge-reveal.mp3",
        }) do
            if love.filesystem.getInfo(path) then
                audioSystem:loadSound(code, path, 0.65)
            end
        end

        if love.filesystem.getInfo("audio/sfx/card-explode.mp3") then
            audioSystem:loadSound("cardExplode", "audio/sfx/card-explode.mp3",
                Config.Audio.CARD_EXPLODE_VOLUME)
        end

        for code, cfg in pairs({
            cardShelfPlace  = { "audio/sfx/card-shelf-place.mp3",  0.22 },
            shopLeaveWhoosh = { "audio/sfx/shop-leave-whoosh.mp3", 0.50 },
            cardDeselect    = { "audio/sfx/card-deselect.mp3",     0.16 },
            eventEnterWind  = { "audio/sfx/event-enter-wind.mp3",  0.20 },
            eventChoiceSeal = { "audio/sfx/event-choice-seal.mp3", 0.22 },
            shopBellHover     = { "audio/sfx/shop-bell-hover.mp3",     0.30 },
            shopBellRing      = { "audio/sfx/shop-bell-ring.mp3",      0.45 },
            shopDicePickup    = { "audio/sfx/shop-dice-pickup.mp3",    0.35 },
            shopPackLift      = { "audio/sfx/shop-pack-lift.mp3",      0.35 },
            shopPotionBubble  = { "audio/sfx/shop-potion-bubble.mp3",  0.35 },
            shopCrystalHum    = { "audio/sfx/shop-crystal-hum.mp3",    0.35 },
            shopPressClunk    = { "audio/sfx/shop-press-clunk.mp3",    0.35 },
            shopScissorsSnip  = { "audio/sfx/shop-scissors-snip.mp3",  0.35 },
            shopAnvilRing     = { "audio/sfx/shop-anvil-ring.mp3",     0.32 },
            shopChestCoins    = { "audio/sfx/shop-chest-coins.mp3",    0.35 },
            shopBookFlip      = { "audio/sfx/shop-book-flip.mp3",      0.35 },
            shopRelicTake     = { "audio/sfx/shop-relic-take.mp3",     0.35 },
            shopPackOpenTear  = { "audio/sfx/shop-pack-open-tear.mp3", 0.45 },
            shopPotionDrink   = { "audio/sfx/shop-potion-drink.mp3",   0.45 },
            shopCrystalShatter = { "audio/sfx/shop-crystal-shatter.mp3", 0.45 },
        }) do
            if love.filesystem.getInfo(cfg[1]) then
                audioSystem:loadSound(code, cfg[1], cfg[2])
            end
        end

        if not audioSystem.sources["cardDeselect"] then
            audioSystem:loadSound("cardDeselect", "audio/clickselect2-92097.mp3", 0.40)
        end
        audioSystem:loadSound("error", "audio/sfx/purchase-deny.mp3", 0.55)

        audioSystem:loadSound("bootTvPowerOn",  "audio/sfx/boot-tv-power-on.mp3", 0.70)
        audioSystem:loadSound("bootCardWhoosh", "audio/sfx/boot-card-whoosh.mp3", 0.60)
        audioSystem:loadSound("bootImpact",     "audio/sfx/boot-impact.mp3",      0.75)
        audioSystem:loadSound("bootElectric",   "audio/sfx/boot-electric.mp3",    0.55)
        audioSystem:loadSound("bootVortex",     "audio/sfx/boot-vortex.mp3",      0.60)

        audioSystem:loadSound("impactFire",      "audio/sfx/impact-fire.mp3",      0.55)
        audioSystem:loadSound("impactIce",       "audio/sfx/impact-ice.mp3",       0.55)
        audioSystem:loadSound("impactLightning", "audio/sfx/impact-lightning.mp3", 0.52)
        audioSystem:loadSound("impactDark",      "audio/sfx/impact-dark.mp3",      0.55)
        audioSystem:loadSound("impactHoly",      "audio/sfx/impact-holy.mp3",      0.52)
        audioSystem:loadSound("impactArcane",    "audio/sfx/impact-arcane.mp3",    0.52)
        audioSystem:loadSound("impactPoison",    "audio/sfx/impact-poison.mp3",    0.55)
        audioSystem:loadSound("healShimmer",     "audio/sfx/heal-shimmer.mp3",     0.50)
        audioSystem:loadSound("healShimmerSoft", "audio/sfx/heal-shimmer.mp3",     0.30)
        audioSystem:loadSound("jokerTick",       "audio/sfx/joker-tick.mp3",       0.58)
        audioSystem:loadSound("enemyBuffRoar",   "audio/sfx/enemy-buff-roar.mp3",  0.55)
        audioSystem:loadSound("thornReflect",    "audio/sfx/thorn-reflect.mp3",    0.48)

        audioSystem:loadSound("effectCast",    "audio/sfx/effect-cast.mp3",    0.45)
        audioSystem:loadSound("effectChime",   "audio/sfx/effect-chime.mp3",   0.50)
        audioSystem:loadSound("effectResolve", "audio/sfx/effect-resolve.mp3", 0.50)

        for _, f in ipairs(love.filesystem.getDirectoryItems("audio/sfx/joker-sig")) do
            local sigId = f:match("^(.+)%.mp3$")
            if sigId then
                audioSystem:loadSound("jokerSig_" .. sigId, "audio/sfx/joker-sig/" .. f, 0.52)
            end
        end
    end

    menu = Menu:new()
    menu:setPlayCallback(function()
        Sfx.play("menuOpen")
        currentState = "classSelection"
        classSelectionScreen:show(
            function(classId, seal)
                startGame(classId, seal)
            end,
            function()
                currentState = "menu"
                menu:show()
            end
        )
        menu:hide()
    end)
    menu:setContinueCallback(function()
        Sfx.play("menuOpen")
        if not game.runManager:loadRun() then
            Debug.warn("[main] AVISO: Continuar sem save válido — run posta em quarentena, diálogo ao jogador")
            require("engine.SaveManager").quarantineRun()
            menu:show()
            local T = require("src.i18n.I18n").t
            require("src.ui.ConfirmDialog").show({
                title   = T("confirm.corrupt_title"),
                body    = T("confirm.corrupt_body"),
                confirm = T("confirm.ok"),
            })
            return
        end
        currentState = "playing"
        if FlashShader and FlashShader.trigger then FlashShader.trigger(0.5, 0.4) end
        game:resumeRun()
        require("src.systems.ResumeFlow").apply(game,
            require("src.scenes.GameplayScene"))
        gameUI:show()
        menu:hide()
        if not _G.__resumeRunStage() and game.runManager:getPendingNodes() then
            _G.__showMapSelection()
        end
        if smokeSystem then
            local act = math.min(3, (game.runManager.currentRun.actNumber or 1))
            SmokeConfig.applyToSystem(smokeSystem, "act" .. act)
        end
    end)
    menu:setCollectionCallback(function()
        Sfx.play("menuOpen")
        currentState = "collection"
        menu:hide()
        collectionScreen:show(function()
            Sfx.play("menuClose")
            currentState = "menu"
            menu:show()
        end)
    end)
    menu:setSettingsCallback(function()
        settingsMenu:toggle()
    end)
    menu:setAchievementsCallback(function()
        currentState = "achievements"
        menu:hide()
        achievementsScreen:show(function()
            currentState = "menu"
            menu:show()
        end)
    end)

    gameUI = GameUI:new()

    game = Game:new()

    cardRewardScreen = CardRewardScreen:new(game.shopSystem)

    classSelectionScreen = ClassSelectionScreen:new()

    collectionScreen = CollectionScreen:new()

    achievementsScreen = require("components.AchievementsScreen"):new()
    require("src.systems.AchievementSystem").install()

    settingsMenu = SettingsMenu:new()
    deckViewerScreen = require("components.DeckViewerScreen"):new()
    _G.jokerManagerScreen = require("components.JokerManagerScreen"):new()
    _G.toggleJokerManager = function()
        if _G.jokerManagerScreen then _G.jokerManagerScreen:toggle(game) end
    end

    _G.runJournalScreen = require("components.RunJournalScreen"):new()
    _G.toggleRunJournal = function()
        if _G.runJournalScreen then _G.runJournalScreen:toggle(game) end
    end
    _G.guideScreen = require("components.GuideScreen"):new()
    _G.toggleGuide = function()
        if _G.guideScreen then _G.guideScreen:toggle(game) end
    end

    _G.scribeDiceScreen = require("components.ScribeDiceScreen"):new()
    _G.openScribeDice = function(g, onClose)
        _G.scribeDiceScreen:show(g, onClose)
    end

    _G.endlessCurseScreen = require("components.EndlessCurseScreen"):new()
    _G.unlockShowcase = require("components.UnlockShowcase"):new()

    pauseMenu = require("components.PauseMenu"):new()
    _G.togglePauseMenu = function(opts)
        if pauseMenu:isVisible() then
            pauseMenu:hide()
            return
        end
        if require("src.ui.EndTransition").pending() then return end
        pauseMenu:show(game, {
            onOpenSettings = function()
                settingsMenu:show({
                    onClose = function() _G.togglePauseMenu({ quiet = true }) end,
                })
            end,
            onOpenDeck = function() deckViewerScreen:toggle(game) end,
            onOpenJokers = function()
                if _G.toggleJokerManager then _G.toggleJokerManager() end
            end,
            onOpenJournal = function()
                if _G.toggleRunJournal then _G.toggleRunJournal() end
            end,
            onOpenGuide = function()
                if _G.toggleGuide then _G.toggleGuide() end
            end,
            onSaveQuit = function()
                local run = game.runManager and game.runManager.currentRun
                local midBattle = run and run.stage == "battle"
                    and currentState == "playing"
                if not midBattle and game.runManager and game.runManager.hasActiveRun
                    and game.runManager:hasActiveRun() then
                    game:checkpointRun()
                end
                returnToMenu()
            end,
            onAbandon = function()
                game:abandonRun()
                returnToMenu()
            end,
        }, opts)
    end

    topBar = TopBar:new()
    _G.topBar = topBar

    topBar:setDeckClickCallback(function()
        deckViewerScreen:toggle(game)
    end)

    topBar:setActClickCallback(function()
        if _G.toggleRunJournal then _G.toggleRunJournal() end
    end)

    mapScreen = MapScreen:new()

    restScreen = RestScreen:new()
    eventScreen = EventScreen:new()

    packOpenScreen = PackOpenScreen:new()

    roundEvalScreen = RoundEvalScreen:new()

    do
        local IF = require("src.ui.InputFocus")
        IF.clear()
        IF.register("bossCinematic", require("src.ui.BossCinematic").overlay)
        IF.register("map",          mapScreen,               { keepChrome = true })
        IF.register("rest",         restScreen,              { keepChrome = true })
        IF.register("event",        eventScreen,             { keepChrome = true })
        IF.register("roundEval",    roundEvalScreen,         { keepChrome = true })
        IF.register("packOpen",     packOpenScreen)
        IF.register("scribeDice",   _G.scribeDiceScreen)
        IF.register("endlessCurse", _G.endlessCurseScreen)
        IF.register("deckViewer",   deckViewerScreen)
        IF.register("jokerManager", _G.jokerManagerScreen)
        IF.register("runJournal",   _G.runJournalScreen)
        IF.register("pause",        pauseMenu)
        IF.register("settings",     settingsMenu)
        IF.register("unlockShowcase", _G.unlockShowcase)
        IF.register("confirm",      require("src.ui.ConfirmDialog").handle)
        IF.register("guide",        _G.guideScreen)
        IF.register("classInspect", classSelectionScreen.inspectHandle)
        IF.register("tutorialTip",  require("src.systems.Tutorial").overlay)
        require("src.systems.Tutorial").setScreens({
            cardReward = cardRewardScreen, rest = restScreen, event = eventScreen,
            dice = _G.scribeDiceScreen, endless = _G.endlessCurseScreen })
    end

    _G.openBoosterPack = function(pack, onComplete)
        if not packOpenScreen or not packOpenScreen.show then return end

        if cardRewardScreen and cardRewardScreen.slideOut and cardRewardScreen.mode ~= "shop" then
            cardRewardScreen:slideOut()
        end

        packOpenScreen:show(pack, function(selected)
            if cardRewardScreen and cardRewardScreen.slideIn then
                cardRewardScreen:slideIn()
            end
            if onComplete then onComplete(selected) end
        end)
    end

    topBar:setGame(game)

    game.onToggleSettings = function() settingsMenu:toggle() end

    CRTShader.load()
    require("src.ui.CursorManager").load()
    if persistedSettings.crtShader == false then CRTShader.setEnabled(false) end
    CRTShader.setLevel(CRTShader.levelFromSettings(persistedSettings))
    CRTShader.setPower(0)

    require("src.ui.InputFocus").installMouseGate(CRTShader.screenToContent)
    require("src.ui.InputFocus").setPositionOverride(require("src.ui.NavCursor").position)
    _G.getCurrentState = function() return currentState end

    DissolveShader.load()
    FlashShader.load()
    BoosterShader.load()
    FoilShader.load()
    PolychromeShader.load()
    if not require("src.ui.HoloShader").load() then
        Debug.warn("[main] AVISO: HoloShader indisponível — raras/lendárias sem holo, edition holo sem efeito")
    end

    ScreenShake.install()

    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local buttonX = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_X_RATIO, love.graphics.getWidth()) - buttonWidth / 2
    local buttonY = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_Y_RATIO, love.graphics.getHeight()) - buttonHeight / 2

    playButton = Button:new(buttonX, buttonY, buttonWidth, buttonHeight, I18n.t("play_button.label"), function()
        if game.turn == "player" then
            game:playSelectedCards()
        end
    end, Theme.Colors.SUCCESS, 18)

    endTurnButton = Button:new(buttonX, buttonY + buttonHeight + 10,
        buttonWidth, math.floor(buttonHeight * 0.72),
        I18n.t("play_button.end_turn"), function()
        if game.turn == "player" then
            game:endTurn()
        end
    end, Theme.Colors.WARNING, 14)
    endTurnButton:setIcon("arrow_right")

    I18n.onLocaleChanged(function()
        if playButton and playButton.text ~= nil then
            playButton.text = I18n.t("play_button.label")
        end
        if endTurnButton and endTurnButton.text ~= nil then
            endTurnButton.text = I18n.t("play_button.end_turn")
        end
    end)

    smokeSystem = SmokeSystem:new()

    SmokeConfig.applyToSystem(smokeSystem, "default")

    love.window.setTitle(I18n.t("window_title"))

    GameplayScene.init({
        game          = game,
        playButton    = playButton,
        endTurnButton  = endTurnButton,
        topBar        = topBar,
        gameUI        = gameUI,
        smokeSystem   = smokeSystem,
        setCurrentState = function(name)
            if name == "gameOver" or name == "victory" then
                require("src.ui.EndTransition").start(name,
                    function(dur, cb) CRTShader.powerOff(dur, cb) end,
                    function(finalName)
                        currentState = finalName
                        CRTShader.powerOn(1.1)
                    end)
            else
                require("src.ui.EndTransition").clear()
                currentState = name
            end
        end,
        onPhaseCleared  = function()
            if game:isInRunMode() then
                showRoundEval()
            else
                game:nextPhase()
            end
        end,
        onReturnToMenu = function() returnToMenu() end,
    })

    BootScene.init({
        onIntroStart = function()
            BootScene._crtWasEnabled = CRTShader.isEnabled()
            CRTShader.setEnabled(false)
        end,
        onTubeOn = function()
            if BootScene._crtWasEnabled then CRTShader.setEnabled(true) end
            CRTShader.setPower(0)
            CRTShader.powerOn(1.8)
        end,
        onComplete = function()
            currentState = "menu"
            menu:show()
            if menu.enterWithIntro then menu:enterWithIntro() end
        end,
    })

    if autoPlayClass then
        startGame(autoPlayClass)
    end

    if loveArgs and loveArgs[1] == "nav_flow" then
        _G.NAV_FLOW = require("tools.test_nav_flow").start()
    end

    if loveArgs and loveArgs[1] == "boss_rooms" then
        require("tools.boss_rooms").run(loveArgs[2])
    end
    if loveArgs and loveArgs[1] == "demo_worldroad" then
        require("tools.demo_worldroad").run(loveArgs[2])
    end
end

function love.update(dt)
    if _G.NAV_FLOW then _G.NAV_FLOW.step(dt) end
    do
        local js = love.joystick and love.joystick.getJoysticks()[1]
        if js then require("src.ui.NavCursor").updateStick(dt, js) end
    end
    require("src.ui.UiScale").reset()
    require("src.ui.UiScale").setChromeScaled(true)
    CRTShader.update(dt)

    CardFrame.update()

    require("src.systems.WeatherAudio").watchdog(dt)

    local IF = require("src.ui.InputFocus")
    IF.resetLayers()

    IF.push(IF.CHROME)
    if topBar and game then topBar:update(dt, game) end
    IF.pop()
    if game and game.tickRunClock then game:tickRunClock(dt, currentState) end
    local combatFrozen = IF.freezesCombat(currentState)
        and IF.activeName() ~= "bossCinematic"
    if not combatFrozen then
        require("src.ui.UiScale").begin()
        EventManager.update(dt)
        require("src.ui.UiScale").finish()
    end
    FloatingText.update(dt)
    require("src.ui.CoinBurst").update(dt)
    require("src.ui.AchievementToast").update(dt); require("src.systems.SteamBridge").update()
    require("src.systems.Tutorial").update(dt, currentState, game)
    if audioSystem then audioSystem:update(dt) end
    do
        local run = game and game.runManager and game.runManager.currentRun
        local node = run and run.currentNode
        local musicState = currentState
        if musicState == "rest" and restScreen and restScreen.pickerFrom then
            musicState = restScreen.pickerFrom
        end
        require("src.systems.MusicDirector").apply(musicState, run, node and node.type)
        local nt = node and node.type
        require("src.systems.PlaceAudio").apply(dt, currentState, {
            nodeType = nt,
            restMode = restScreen and restScreen.mode,
            forgeBusy = restScreen and restScreen.forge ~= nil,
            bossRoom = require("src.scenes.GameplayScene").inBossRoom(nt),
        })
    end
    CardParticles.update(dt)
    FlashShader.update(dt)
    ScreenShake.update(dt)

    IF.push(IF.SCENE)
    if currentState == "boot" then
        BootScene.update(dt)
    elseif currentState == "menu" then
        menu:update(dt)
    elseif currentState == "playing" then
        if not combatFrozen then GameplayScene.update(dt) end
    elseif currentState == "classSelection" then
        classSelectionScreen:update(dt)
        require("src.ui.WorldRoad").prewarmTick(nil, 1)
    elseif currentState == "cardReward" then
        if game and game.isRunMode then
            require("src.ui.WorldRoad").update(dt)
        end
        cardRewardScreen:update(dt)
        if packOpenScreen and packOpenScreen:isVisible() then
            IF.push("packOpen")
            packOpenScreen:update(dt)
            IF.pop()
        end
    elseif currentState == "roundEval" then
        IF.push("roundEval")
        roundEvalScreen:update(dt)
        IF.pop()
    elseif currentState == "mapSelection" then
        local WorldRoad = require("src.ui.WorldRoad")
        if WorldRoad.isForkActive() then
            WorldRoad.update(dt)
        else
            IF.push("map")
            mapScreen:update(dt)
            IF.pop()
        end
    elseif currentState == "rest" then
        IF.push("rest")
        restScreen:update(dt)
        IF.pop()
    elseif currentState == "event" then
        IF.push("event")
        eventScreen:update(dt)
        IF.pop()
    elseif currentState == "collection" then
        collectionScreen:update(dt)
    elseif currentState == "achievements" then
        achievementsScreen:update(dt)
    end
    IF.pop()

    if settingsMenu then
        IF.push("settings"); settingsMenu:update(dt); IF.pop()
    end
    if pauseMenu then
        IF.push("pause"); pauseMenu:update(dt); IF.pop()
    end
    IF.push("confirm"); require("src.ui.ConfirmDialog").update(dt); IF.pop()
    require("src.systems.CheatMode").update(dt)
end

function love.draw()
    require("src.ui.NavCursor").beginFrame()
    require("src.ui.UiScale").reset()
    require("src.ui.UiScale").setChromeScaled(true)
    CRTShader.beginScene()

    ScreenShake.push()

    local IF = require("src.ui.InputFocus")
    IF.resetLayers()
    IF.push(IF.SCENE)

    if currentState == "boot" then
        BootScene.draw()
    elseif currentState == "menu" then
        menu:draw()
    elseif currentState == "classSelection" then
        classSelectionScreen:draw()
    elseif currentState == "playing" then
        GameplayScene.draw()
    elseif currentState == "cardReward" then
        GameplayScene.drawWorldOnly()
        cardRewardScreen:draw()
        if packOpenScreen and packOpenScreen:isVisible() then
            IF.push("packOpen"); packOpenScreen:draw(); IF.pop()
        end
    elseif currentState == "roundEval" then
        GameplayScene.draw()
        IF.push("roundEval"); roundEvalScreen:draw(); IF.pop()
    elseif currentState == "mapSelection" then
        local WorldRoad = require("src.ui.WorldRoad")
        if WorldRoad.isForkActive() then
            GameplayScene.drawWorldOnly()
        else
            GameplayScene.draw()
            IF.push("map"); mapScreen:draw(); IF.pop()
        end
    elseif currentState == "rest" then
        GameplayScene.draw()
        IF.push("rest"); restScreen:draw(); IF.pop()
    elseif currentState == "event" then
        GameplayScene.draw()
        IF.push("event"); eventScreen:draw(); IF.pop()
    elseif currentState == "collection" then
        collectionScreen:draw()
    elseif currentState == "achievements" then
        achievementsScreen:draw()
    elseif currentState == "gameOver" then
        EndScreens.drawGameOver(game)
    elseif currentState == "victory" then
        EndScreens.drawVictory(game)
    end

    if topBar and (currentState == "playing"
                   or currentState == "cardReward"
                   or currentState == "roundEval"
                   or currentState == "mapSelection"
                   or currentState == "rest"
                   or currentState == "event") then
        IF.pop()
        IF.push(IF.CHROME)
        topBar:draw()
        IF.pop()
        IF.push(IF.SCENE)
    end

    require("src.ui.StatusTooltip").draw()

    local fxScaled = currentState ~= "boot"
    if fxScaled then require("src.ui.UiScale").begin() end
    CardParticles.draw()

    require("src.ui.CoinBurst").draw()
    FloatingText.draw()
    if fxScaled then require("src.ui.UiScale").finish() end

    FlashShader.draw()

    ScreenShake.pop()

    IF.pop()

    if deckViewerScreen and deckViewerScreen:isVisible() then
        IF.push("deckViewer"); deckViewerScreen:draw(); IF.pop()
    end

    if _G.scribeDiceScreen and _G.scribeDiceScreen:isVisible() then
        IF.push("scribeDice")
        _G.scribeDiceScreen:update(love.timer.getDelta())
        _G.scribeDiceScreen:draw()
        IF.pop()
    end

    if _G.endlessCurseScreen then
        local ECS = _G.endlessCurseScreen
        ECS.watch(ECS, game, currentState)
        if ECS:isVisible() then
            IF.push("endlessCurse")
            ECS:update(love.timer.getDelta())
            ECS:draw()
            IF.pop()
        end
    end

    if _G.jokerManagerScreen and _G.jokerManagerScreen:isVisible() then
        IF.push("jokerManager"); _G.jokerManagerScreen:draw(); IF.pop()
    end

    if _G.runJournalScreen and _G.runJournalScreen:isVisible() then
        IF.push("runJournal"); _G.runJournalScreen:draw(); IF.pop()
    end

    if pauseMenu then IF.push("pause"); pauseMenu:draw(); IF.pop() end
    if settingsMenu then IF.push("settings"); settingsMenu:draw(); IF.pop() end
    if _G.unlockShowcase then
        local US = _G.unlockShowcase
        US:watch(currentState, love.timer.getDelta())
        if US:isVisible() then
            IF.push("unlockShowcase")
            US:update(love.timer.getDelta())
            US:draw()
            IF.pop()
        end
    end
    IF.push("confirm"); require("src.ui.ConfirmDialog").draw(); IF.pop()
    if _G.guideScreen and _G.guideScreen:isVisible() then
        IF.push("guide"); _G.guideScreen:draw(); IF.pop()
    end
    IF.push("tutorialTip"); require("src.systems.Tutorial").draw(); IF.pop()

    require("src.ui.AchievementToast").draw()
    require("src.systems.CheatMode").draw()

    require("src.ui.NavCursor").draw()
    require("src.ui.CursorManager").draw()

    CRTShader.endScene()
end

function love.focus(focused)
    require("src.systems.FocusMute").onFocus(focused)
end

function love.resize(w, h)
    FontManager.clearCache()
    CardFrame.clearCache()
    require("src.ui.TurnBanner").clearCache()
    require("src.ui.ComboBanner").clearCache()
    if menu and menu.updatePositions then menu:updatePositions() end
    if classSelectionScreen and classSelectionScreen.updatePositions then
        classSelectionScreen:updatePositions()
    end
    if cardRewardScreen and cardRewardScreen.updateLayout then
        cardRewardScreen:updateLayout()
        if #(cardRewardScreen.shopOffers or {}) > 0 then
            if cardRewardScreen.createCardInstances then cardRewardScreen:createCardInstances() end
            if cardRewardScreen.createOfferButtons then cardRewardScreen:createOfferButtons() end
        end
    end
    if packOpenScreen and packOpenScreen.resize then packOpenScreen:resize() end
    if restScreen and restScreen.resize then restScreen:resize() end
    if eventScreen and eventScreen.resize then eventScreen:resize() end
    EndScreens.resize()
    if roundEvalScreen and roundEvalScreen.resize then roundEvalScreen:resize() end
    if collectionScreen and collectionScreen.resize then collectionScreen:resize() end
    if mapScreen and mapScreen.resize then mapScreen:resize() end
    if deckViewerScreen and deckViewerScreen.resize then deckViewerScreen:resize() end
    if _G.jokerManagerScreen and _G.jokerManagerScreen.resize then
        _G.jokerManagerScreen:resize()
    end
    if _G.runJournalScreen and _G.runJournalScreen.resize then
        _G.runJournalScreen:resize()
    end
    if topBar and topBar.resize then topBar:resize() end
    if settingsMenu and settingsMenu.rebuild and settingsMenu.visible then
        settingsMenu:rebuild()
    end
    if pauseMenu and pauseMenu.resize then pauseMenu:resize() end
    require("src.ui.ConfirmDialog").resize()
    GameplayScene.updatePlayButtonPosition()
end

function love.keypressed(key)
    if require("src.systems.CheatMode").keypressed(key) then return end
    if currentState == "boot" then
        BootScene.keypressed(key)
        return
    end

    do
        local NC = require("src.ui.NavCursor")
        local it = NC.KEYS[key]
        if it and NC.claimsInput(currentState,
                currentState == "collection" and collectionScreen:ownsNavigation()) then
            if NC.intent(it, "keyboard") then return end
        end
    end

    do
        local captor = require("src.ui.InputFocus").captor()
        if captor then
            if captor.keypressed then captor:keypressed(key) end
            return
        end
    end
    if require("src.systems.Tutorial").blocksKey(key) then return end

    local runScreen = currentState == "playing" or currentState == "cardReward"
        or currentState == "mapSelection" or currentState == "rest"
        or currentState == "event" or currentState == "roundEval"
    if key == "d" and runScreen and game and game.isRunMode then
        deckViewerScreen:toggle(game)
        return
    end

    if key == "j" and runScreen and game and game.isRunMode then
        _G.jokerManagerScreen:toggle(game)
        return
    end

    if key == "m" and runScreen and game and game.isRunMode then
        _G.toggleRunJournal()
        return
    end

    if key == "g" and runScreen and game and game.isRunMode and _G.toggleGuide then
        _G.toggleGuide()
        return
    end

    if key == "v" and currentState == "playing" then
        require("src.ui.DamagePreviewPanel").toggleDetails()
        return
    end

    if roundEvalScreen and roundEvalScreen:isVisible() then
        if roundEvalScreen:keypressed(key) then return end
    end

    if currentState == "achievements" then
        achievementsScreen:keypressed(key)
        return
    end
    if currentState == "collection" then
        local wasInspecting = collectionScreen:ownsNavigation()
        if collectionScreen.keypressed then collectionScreen:keypressed(key) end
        if key == "escape" and not wasInspecting then
            currentState = "menu"
            collectionScreen:hide()
            menu:show()
            if menu.enterWithIntro then menu:enterWithIntro() end
        end
        return
    end

    if currentState == "mapSelection" then
        local WorldRoad = require("src.ui.WorldRoad")
        if WorldRoad.isForkActive() then
            local n = tonumber(key)
            local f = WorldRoad._fork
            if n and f and f.markBoxes and f.markBoxes[n] then
                local b = f.markBoxes[n]
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
            end
            if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end
            return
        end
        if mapScreen:keypressed(key) then return end
        if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end
        return
    end

    if currentState == "cardReward" or currentState == "roundEval" then
        if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end
        if key == "h" and currentState == "cardReward" and cardRewardScreen.openDiceHelp then
            cardRewardScreen:openDiceHelp()
        end
        return
    end

    if currentState == "classSelection" then
        if classSelectionScreen.keypressed then
            classSelectionScreen:keypressed(key)
        elseif key == "escape" then
            classSelectionScreen:goBackToMenu()
        end
        return
    end

    if currentState == "event" then
        if eventScreen:keypressed(key) then return end
        if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end
        return
    end

    if currentState == "rest" then
        if restScreen:keypressed(key) then return end
        if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end
        return
    end

    if currentState == "menu" then
        if key == "escape" then
            menu:requestQuit()
        end
    elseif currentState == "playing" then
        if key == "escape" then
            if _G.togglePauseMenu then _G.togglePauseMenu() end
            return
        end
        GameplayScene.keypressed(key)
    elseif currentState == "gameOver" or currentState == "victory" then
        EndScreens.keypressed(key)
    end
end

function love.gamepadpressed(joystick, button)
    local NC = require("src.ui.NavCursor")
    if button == "start" or button == "back" then
        NC.noteDevice("pad")
        if require("src.ui.InputFocus").captor()
            or currentState == "gameOver" or currentState == "victory" then
            love.keypressed("escape")
        elseif _G.togglePauseMenu and (currentState == "playing"
            or currentState == "mapSelection" or currentState == "rest"
            or currentState == "event" or currentState == "cardReward"
            or currentState == "roundEval") then
            _G.togglePauseMenu()
        end
        return
    end
    local it = NC.PAD[button]
    if not it then return end
    NC.noteDevice("pad")
    if it == "back" then love.keypressed("escape") return end
    if NC.claimsInput(currentState,
            currentState == "collection" and collectionScreen:ownsNavigation()) then
        if require("src.systems.Tutorial").blocksKey(it) then return end
        NC.intent(it, "pad")
        return
    end
    local key = ({ up = "up", down = "down", left = "left", right = "right",
        confirm = "return", lb = "pageup", rb = "pagedown", x = "q", y = "e" })[it]
    if key then love.keypressed(key) end
end

function love.mousereleased(x, y, button)
    if not require("src.ui.NavCursor").synthesizing then
        x, y = CRTShader.screenToContent(x, y)
    end
    if require("src.systems.CheatMode").mousereleased(x, y, button) then return end

    do
        local captor = require("src.ui.InputFocus").captor()
        if captor then
            if captor.mousereleased then captor:mousereleased(x, y, button) end
            return
        end
    end
    if require("src.systems.Tutorial").blocksPointer(x, y, "released") then return end

    if currentState == "menu" then
        menu:mousereleased(x, y, button)
    elseif currentState == "classSelection" then
        classSelectionScreen:mousereleased(x, y, button)
    elseif currentState == "playing" then
        GameplayScene.mousereleased(x, y, button)
    elseif currentState == "cardReward" then
        cardRewardScreen:mousereleased(x, y, button)
    elseif currentState == "roundEval" then
        roundEvalScreen:mousereleased(x, y, button)
    elseif currentState == "mapSelection" then
        mapScreen:mousereleased(x, y, button)
    elseif currentState == "rest" then
        restScreen:mousereleased(x, y, button)
    elseif currentState == "event" then
        eventScreen:mousereleased(x, y, button)
    elseif currentState == "collection" then
        if collectionScreen.mousereleased then collectionScreen:mousereleased(x, y, button) end
    elseif currentState == "achievements" then
        achievementsScreen:mousereleased(x, y, button)
    elseif currentState == "gameOver" or currentState == "victory" then
        EndScreens.mousereleased(x, y, button)
    end
end

function love.mousepressed(x, y, button)
    if not require("src.ui.NavCursor").synthesizing then
        x, y = CRTShader.screenToContent(x, y)
    end
    if require("src.systems.CheatMode").mousepressed(x, y, button) then return end
    if currentState == "boot" then
        BootScene.mousepressed(x, y, button)
        return
    end

    do
        local captor = require("src.ui.InputFocus").captor()
        if captor then
            if captor.mousepressed then captor:mousepressed(x, y, button) end
            return
        end
    end
    if require("src.systems.Tutorial").blocksPointer(x, y, "pressed") then return end

    local topBarStates = {
        playing = true, cardReward = true, roundEval = true,
        mapSelection = true, rest = true, event = true,
    }
    if topBar and topBarStates[currentState]
        and y <= (topBar.height or 52) * require("src.ui.UiScale").chromeK() then
        if topBar:mousepressed(x, y, button) then return end
    end

    if currentState == "menu" then
        menu:mousepressed(x, y, button)
    elseif currentState == "classSelection" then
        classSelectionScreen:mousepressed(x, y, button)
    elseif currentState == "playing" then
        if require("src.ui.DamagePreviewPanel").mousepressed(x, y, button) then return end
        if not GameplayScene.mousepressed(x, y, button) and button == 1 then
            require("src.ui.WorldRoad").pokeSceneAt(x, y)
        end
    elseif currentState == "cardReward" then
        if not cardRewardScreen:mousepressed(x, y, button) and button == 1 then
            require("src.ui.WorldRoad").pokeSceneAt(x, y)
        end
    elseif currentState == "roundEval" then
        roundEvalScreen:mousepressed(x, y, button)
    elseif currentState == "mapSelection" then
        local WorldRoad = require("src.ui.WorldRoad")
        if WorldRoad.isForkActive() then
            WorldRoad.forkMousePressed(x, y)
        else
            mapScreen:mousepressed(x, y, button)
        end
    elseif currentState == "rest" then
        restScreen:mousepressed(x, y, button)
    elseif currentState == "event" then
        eventScreen:mousepressed(x, y, button)
    elseif currentState == "collection" then
        collectionScreen:mousepressed(x, y, button)
    elseif currentState == "achievements" then
        achievementsScreen:mousepressed(x, y, button)
    elseif currentState == "gameOver" or currentState == "victory" then
        EndScreens.mousepressed(x, y, button)
    end
end

function love.wheelmoved(dx, dy)
    do
        local captor = require("src.ui.InputFocus").captor()
        if captor then
            if captor.wheelmoved then captor:wheelmoved(dx, dy) end
            return
        end
    end
    if currentState == "collection" and collectionScreen.wheelmoved then
        collectionScreen:wheelmoved(dx, dy)
    end
end

function love.mousemoved(x, y, dx, dy)
    x, y = CRTShader.screenToContent(x, y)
    if math.abs(dx or 0) + math.abs(dy or 0) > 1 then
        require("src.ui.NavCursor").mouseMoved(x, y)
    end
    do
        local captor = require("src.ui.InputFocus").captor()
        if captor then
            if captor.mousemoved then captor:mousemoved(x, y, dx, dy) end
            return
        end
    end
    if currentState == "playing" then
        GameplayScene.mousemoved(x, y, dx, dy)
    elseif currentState == "collection" and collectionScreen.mousemoved then
        collectionScreen:mousemoved(x, y, dx, dy)
    end
end
