local M = {}

local OUT_REL = "tools/preview_out/imunidade/"

local vcanvas, fakeMouse
local saved = {}

local function outPath(name)
    return love.filesystem.getSource() .. "/" .. OUT_REL .. name .. ".png"
end

local function shot(name)
    love.graphics.setCanvas()
    local data = vcanvas:newImageData()
    local fd = data:encode("png")
    local f = io.open(outPath(name), "wb")
    if f then
        f:write(fd:getString())
        f:close()
        saved[#saved + 1] = OUT_REL .. name .. ".png"
    else
        print("[FAIL] nao gravou " .. outPath(name))
    end
    fd:release()
    data:release()
end

local function mouseTo(x, y)
    fakeMouse.x, fakeMouse.y = x, y
end

local function spawn(id, hp, dmg, act)
    local Enemy = require("src.entities.Enemy")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local e = EnemyRoster.spawn(Enemy, id, { health = hp, damage = dmg, kind = "battle" }, act)
    e.spriteId = id
    return e
end

local function buildScene(class, act, enemyId, seed)
    local TK = require("tools.testkit")
    TK.bootstrap()
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
    I18n.setLocale(os.getenv("PREVIEW_LOCALE") or "pt_BR")

    TK.seedRng(seed or 777)
    local game = TK.newRunGame(class)
    local run = game.runManager and game.runManager.currentRun
    if run then run.actNumber = act end
    game.actNumber = act
    game.enemy = spawn(enemyId, 220, 8, act)
    _G.game = game

    local bw = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local bh = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({
        game = game,
        playButton = Button:new(0, 0, bw, bh,
            I18n.t("play_button.label"), function() end, Theme.Colors.SUCCESS, 18),
        endTurnButton = Button:new(0, 0, bw, math.floor(bh * 0.72),
            I18n.t("play_button.end_turn"), function() end, Theme.Colors.WARNING, 14),
        topBar = topBar,
        gameUI = GameUI:new(),
        smokeSystem = SmokeSystem:new(),
    })
    GameplayScene.setGame(game)
    if GameplayScene.updatePlayButtonPosition then GameplayScene.updatePlayButtonPosition() end
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.clearCache()
    WorldRoad._camZ = 6
    return game, GameplayScene
end

local function frame(GS, dt)
    _G.EventManager.update(dt)
    GS.update(dt)
    require("src.ui.FloatingText").update(dt)
end

local function render(GS)
    love.graphics.setCanvas(vcanvas)
    love.graphics.clear(0, 0, 0, 1)
    GS.draw()
    require("src.ui.FloatingText").draw()
    require("src.ui.StatusTooltip").draw()
    love.graphics.setCanvas()
    love.graphics.present()
end

local function settle(GS, secs)
    for _ = 1, math.floor((secs or 0.5) * 60) do
        frame(GS, 1 / 60)
        render(GS)
    end
end

local function setHand(game, ids, nSel)
    local db = require("src.systems.CardDatabase"):new()
    db:loadData()
    game.hand = {}
    for _, id in ipairs(ids) do
        game.hand[#game.hand + 1] = db:createCardInstance(db:getCard(id))
    end
    game.player.mana, game.player.maxMana = 10, 10
    game.selectedCards = {}
    game.turn = "player"
    for i = 1, nSel or 0 do game:selectCard(game.hand[i]) end
end

local function waitFor(GS, pred, maxSecs)
    for _ = 1, math.floor((maxSecs or 4) * 60) do
        frame(GS, 1 / 60)
        render(GS)
        if pred() then return true end
    end
    return false
end

local function hoverResist(GS, idx)
    local RB = require("src.ui.ResistBadges")
    local r = RB.lastRects[idx or 1]
    if not r then return false end
    mouseTo(r.x + r.w / 2, r.y + r.h / 2)
    settle(GS, 0.3)
    return true
end

local function sceneHud(name, id, act, idx)
    local game, GS = buildScene("warrior", act, id, 900 + act)
    setHand(game, { "warrior_strike", "warrior_defend", "warrior_bash", "warrior_strike" }, 0)
    mouseTo(5, 5)
    settle(GS, 1.2)
    hoverResist(GS, idx)
    render(GS)
    shot(name)
end

local function sceneTick(name, id, act, stacks, class)
    local game, GS = buildScene(class or "rogue", act, id, 950 + act)
    setHand(game, { "rogue_strike", "rogue_defend" }, 0)
    mouseTo(5, 5)
    settle(GS, 1.0)
    game.enemy:addStatusEffect({ name = "poison", stacks = stacks, duration = stacks })
    settle(GS, 0.6)
    game.turn = "enemy"
    local ResistFx = require("src.ui.ResistFx")
    local n0 = #ResistFx.log
    game:enemyTurn()
    local ok = waitFor(GS, function()
        for i = n0 + 1, #ResistFx.log do
            if ResistFx.log[i].dot == "poison" then return true end
        end
        return false
    end, 8)
    settle(GS, 0.18)
    shot(name)
    return ok
end

local function scenePreview(name)
    local game, GS = buildScene("mage", 3, "ember_imp", 991)
    game.player.orbs = {}
    setHand(game, { "mage_fireball", "mage_zap", "mage_frost_nova", "mage_mind_spike",
        "mage_magic_barrier" }, 3)
    require("src.ui.DamagePreviewPanel").setDetails(true)
    mouseTo(5, 5)
    settle(GS, 1.2)
    render(GS)
    shot(name)
    require("src.ui.DamagePreviewPanel").setDetails(false)
end

local function sceneHitImmune(name)
    local game, GS = buildScene("mage", 3, "ember_imp", 992)
    game.player.orbs = {}
    setHand(game, { "mage_fireball", "mage_magic_barrier" }, 1)
    mouseTo(5, 5)
    settle(GS, 1.0)
    local ResistFx = require("src.ui.ResistFx")
    local n0 = #ResistFx.log
    game:playSelectedCards()
    local ok = waitFor(GS, function() return #ResistFx.log > n0 end, 6)
    settle(GS, 0.15)
    shot(name)
    return ok
end

function M.run()
    local W, H = 1920, 1080
    vcanvas = love.graphics.newCanvas(W, H)
    fakeMouse = { x = 5, y = 5 }
    require("src.ui.InputFocus").installMouseGate(nil, function() return fakeMouse.x, fakeMouse.y end)
    love.mouse.getPosition = function() return fakeMouse.x, fakeMouse.y end
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end

    local only = os.getenv("IMUNIDADE_SCENE")
    local function want(n) return not only or only == n end
    local okAll = true
    if want("hud") then
        sceneHud("hud_rainha_tooltip", "eclipse_queen", 6, 1)
        sceneHud("hud_lich_tooltip", "tower_lich", 2, 3)
    end
    if want("tick") then
        okAll = sceneTick("tique_imune_esqueleto", "grave_thrall", 6, 6) and okAll
        okAll = sceneTick("tique_resiste_ratos", "plague_rats", 1, 6) and okAll
    end
    if want("preview") then scenePreview("previa_carta_imune") end
    if want("hit") then okAll = sceneHitImmune("golpe_imune_diabrete") and okAll end
    vcanvas:release()
    for _, p in ipairs(saved) do print("[ok] " .. p) end
    print(okAll and "[ok] cenas completas" or "[FAIL] alguma cena nao chegou ao retorno")
    return okAll
end

return M
