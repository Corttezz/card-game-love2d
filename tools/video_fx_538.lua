local M = {}

local W, H = 1280, 720
local DT = 1 / 60
local STEP = 2
local DIR = "fx564v"

local clock = { t = 1000 }
local sounds = {}
local seg = nil
local segFrame = 0
local log

local function patchClock()
    love.timer.getTime = function() return clock.t end
    love.timer.getDelta = function() return DT end
end

local function note(name, opts)
    if not seg or type(name) ~= "string" then return end
    local o = type(opts) == "table" and opts or {}
    sounds[#sounds + 1] = ("snd %s %.4f %s %.3f %.3f"):format(seg, segFrame / 60,
        name, o.gain or o.volume or 1, o.pitch or 1)
end

local function hookAudio()
    local a = _G.audioSystem
    if not a then
        local entry = { baseVolume = 1, instGain = {} }
        local noop = function() end
        a = setmetatable({ sources = setmetatable({}, { __index = function() return entry end }) },
            { __index = function() return noop end })
        function a:play(name, opts) note(name, opts) return nil end
        function a:playSound(name) note(name) end
        _G.audioSystem = a
        return
    end
    local play, playSound = a.play, a.playSound
    a.play = function(self, name, opts) note(name, opts) return play(self, name, opts) end
    a.playSound = function(self, name, ...) note(name) return playSound(self, name, ...) end
end

local function writer(cv, drawFn, updateFn)
    local R = {}
    function R.tick(n)
        for _ = 1, n do
            clock.t = clock.t + DT
            updateFn(DT)
        end
    end
    function R.frame()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.origin()
        drawFn()
        love.graphics.setCanvas()
        love.graphics.present()
        local d = cv:newImageData()
        d:encode("png", ("%s/%s/f%04d.png"):format(DIR, seg, math.floor(segFrame / STEP) + 1))
        d:release()
    end
    function R.record(name, seconds, trigger, during)
        seg = name
        segFrame = 0
        love.filesystem.createDirectory(DIR .. "/" .. name)
        local total = math.floor(seconds * 60)
        local fired = false
        for i = 0, total - 1 do
            if not fired and i >= 18 then
                fired = true
                trigger()
            end
            if during then during(i) end
            if i % STEP == 0 then R.frame() end
            R.tick(1)
            segFrame = segFrame + 1
        end
        log:write(("seg %s %d\n"):format(name, math.floor(total / STEP)))
        seg = nil
        print("  video " .. name)
    end
    return R
end

local function patchDims()
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end
end

local function buildScene()
    local TK = require("tools.testkit")
    TK.bootstrap()
    require("src.ui.DissolveShader").load()
    require("src.ui.CardFxShader").load()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()
    local Config = require("src.core.Config")
    local Theme = require("src.ui.Theme")
    local Button = require("components.Button")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local SmokeSystem = require("src.systems.SmokeSystem")
    local GameplayScene = require("src.scenes.GameplayScene")
    local I18n = require("src.i18n.I18n")
    I18n.setLocale("pt_BR")
    local game = TK.newRunGame("warrior")
    game.enemy.spriteId = "cursed_scarecrow"
    _G.game = game
    local bw = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local bh = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local bx = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_X_RATIO, W) - bw / 2
    local by = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_Y_RATIO, H) - bh / 2
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({
        game = game,
        playButton = Button:new(bx, by, bw, bh, I18n.t("play_button.label"), function() end,
            Theme.Colors.SUCCESS, 18),
        endTurnButton = Button:new(bx, by + bh + 10, bw, math.floor(bh * 0.72),
            I18n.t("play_button.end_turn"), function() end, Theme.Colors.WARNING, 14),
        topBar = topBar,
        gameUI = GameUI:new(),
        smokeSystem = SmokeSystem:new(),
    })
    GameplayScene.setGame(game)
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.clearCache()
    WorldRoad._camZ = 6
    return game, GameplayScene
end

local function runHand()
    patchDims()
    local game, Scene = buildScene()
    hookAudio()
    local EffectFeedback = require("src.systems.EffectFeedback")
    local FloatingText = require("src.ui.FloatingText")
    local CardParticles = require("src.systems.CardParticles")
    local cv = love.graphics.newCanvas(W, H)
    local R = writer(cv, function()
        Scene.draw()
        CardParticles.draw()
        FloatingText.draw()
    end, function(dt)
        _G.EventManager.update(dt)
        Scene.update(dt)
        FloatingText.update(dt)
        CardParticles.update(dt)
    end)

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    db:loadData()
    local IDS = { "warrior_strike", "warrior_defend", "warrior_rage", "warrior_seeing_red",
        "warrior_second_wind" }
    local function hand(ids)
        game.hand = {}
        for _, id in ipairs(ids) do
            local cd = db:getCard(id)
            if cd then game.hand[#game.hand + 1] = db:createCardInstance(cd) end
        end
        game.selectedCards = {}
        game.turn = "player"
        game.player.mana = 10
        game.player.maxMana = 10
        game._currentTurnContext = nil
        R.tick(60)
    end
    local function fill(n)
        local ids = {}
        for i = 1, n do ids[i] = IDS[(i - 1) % #IDS + 1] end
        hand(ids)
    end
    local function play(ids, n)
        hand(ids)
        return function()
            for i = 1, n do game.selectedCards[#game.selectedCards + 1] = game.hand[i] end
            game:playSelectedCards()
        end
    end
    local function settle()
        for _ = 1, 60 * 10 do
            if not game.combatAnimationSystem:isBlocking() then break end
            R.tick(1)
        end
        R.tick(30)
    end
    local fx = function(e) return function() game.effectSystem:processEffectCard(game, e) end end

    R.tick(120)
    local plan = {
        { "01_exaurir", 5.0, function() return play({ "warrior_ghostly_armor", "warrior_strike", "warrior_defend" }, 2) end },
        { "02_duplicar", 5.0, function() return play({ "warrior_strike", "effect_mystery_card", "warrior_defend" }, 2) end },
        { "03_reter", 2.6, function()
            fill(5)
            return function()
                game.hand[2].retain = true
                game:discardHandEndOfTurn()
            end
        end },
        { "04_descartar", 2.4, function() fill(5) return fx({ type = "discard_cards", value = 2 }) end },
        { "05_inata", 2.4, function()
            fill(4)
            return function()
                local c = game.hand[#game.hand]
                if c then
                    c._fxInnate = true
                    EffectFeedback.onCardArrives(c, 1)
                end
            end
        end },
        { "06_embaralhar", 2.6, function() fill(5) return function() EffectFeedback.reshuffle(game, 12) end end },
        { "07_recuperar_mana", 2.2, function()
            fill(5)
            game.player.mana = 0
            return fx({ type = "restore_mana", value = 2 })
        end },
        { "08_mana_maxima", 2.4, function() fill(5) return fx({ type = "increase_max_mana", value = 1 }) end },
        { "09_auto_dano", 2.2, function() fill(5) return fx({ type = "self_damage", value = 4 }) end },
        { "10_buff", 2.2, function() fill(5) return fx({ type = "apply_buff", value = "thorn", stacks = 2 }) end },
        { "11_revelar_intencao", 2.2, function() fill(5) return function() EffectFeedback.reveal() end end },
    }
    for _, p in ipairs(plan) do
        local trigger = p[3]()
        R.record(p[1], p[2], trigger)
        settle()
    end
    cv:release()
    return true
end

local function bootMap()
    local Flow = require("tools.estrada_fluxo")
    local ok, err = Flow.boot(W, H)
    if not ok then print("[FAIL] boot: " .. tostring(err)) return false end
    hookAudio()
    require("engine.WeatherEngine").disabled = true
    local CheatMode = require("src.systems.CheatMode")
    local WorldRoad = require("src.ui.WorldRoad")
    local function st() return _G.__cheatApi and _G.__cheatApi.state() end
    local cv = love.graphics.newCanvas(W, H)
    local R = writer(cv, function() love.draw() end, function(dt) love.update(dt) end)
    CheatMode.rush = false
    CheatMode.goToAct(1, false)
    for _ = 1, 900 do
        R.tick(1)
        if st() == "mapSelection" then
            CheatMode.rush = false
            CheatMode.pending().forkPick = nil
        end
        local f = WorldRoad._fork
        if st() == "mapSelection" and f and (f.animIn or 0) >= 1 then break end
    end
    R.tick(30)
    return Flow, R, cv
end

local function runMap()
    local Flow, R, cv = bootMap()
    if not Flow then return false end
    local scr = _G.actMapScreen
    R.record("12_abrir_mapa", 2.2, function() if not scr:isVisible() then _G.toggleActMap() end end)
    R.record("13_passar_mouse_no_mapa", 2.0, function() scr:hoverDemo() end, function(i)
        if i == 60 then
            scr._forceHover = nil
        elseif i == 78 then
            local map, run = scr:map()
            local reach, floorNow, start = scr.reach(map, run)
            local best
            for k in pairs(start) do if not best or k > best then best = k end end
            if best then scr._forceHover = { f = floorNow, i = best } end
        end
    end)
    scr._forceHover = nil
    R.record("14_fechar_mapa", 2.0, function() if scr:isVisible() then _G.toggleActMap() end end)
    cv:release()
    Flow.shutdown()
    return true
end

local function hoverLane(scr, pick)
    local map, run = scr:map()
    local _, floorNow, start = scr.reach(map, run)
    local best
    for k in pairs(start) do if not best or pick(k, best) then best = k end end
    if best then scr._forceHover = { f = floorNow, i = best } end
end

local function runMapScroll()
    local Flow, R, cv = bootMap()
    if not Flow then return false end
    local scr = _G.actMapScreen
    local plan = {
        [80] = function() scr:wheelmoved(0, 3) end,
        [110] = function() scr:wheelmoved(0, 4) end,
        [150] = function() scr:wheelmoved(0, 6) end,
        [250] = function() scr:wheelmoved(0, -6) end,
        [290] = function() scr:wheelmoved(0, -8) end,
        [380] = function() hoverLane(scr, function(a, b) return a < b end) end,
        [450] = function() scr._forceHover = nil end,
        [470] = function() hoverLane(scr, function(a, b) return a > b end) end,
        [540] = function() scr._forceHover = nil end,
        [570] = function() if scr:isVisible() then _G.toggleActMap() end end,
    }
    R.record("mapa_rolar_hover_fechar", 11.0, function() if not scr:isVisible() then _G.toggleActMap() end end,
        function(i) if plan[i] then plan[i]() end end)
    scr._forceHover = nil
    cv:release()
    Flow.shutdown()
    return true
end

local PARTS = { map = runMap, mapscroll = runMapScroll }

function M.run(part)
    patchClock()
    if part == "mapscroll" then DIR = "map538v5" end
    love.filesystem.createDirectory(DIR)
    log = love.filesystem.newFile(DIR .. "/" .. (part or "hand") .. ".txt", "w")
    local okRun, res = pcall(PARTS[part] or runHand)
    for _, s in ipairs(sounds) do log:write(s .. "\n") end
    log:close()
    if not okRun then print("[FAIL] " .. tostring(res)) end
    print(((okRun and res) and "[ok] " or "[FAIL] ") .. love.filesystem.getSaveDirectory() .. "/" .. DIR)
    return okRun and res
end

return M
