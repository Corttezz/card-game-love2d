local Config           = require("src.core.Config")
local FontManager      = require("src.ui.FontManager")
local I18n             = require("src.i18n.I18n")
local SceneLayer       = require("src.ui.SceneLayer")
local SceneBackground  = require("src.ui.SceneBackground")
local SceneAnchors     = require("src.data.scene_anchors")
local InteriorFX       = require("src.ui.InteriorFX")
local WorldRoad        = require("src.ui.WorldRoad")
local EnemyRenderer    = require("src.ui.EnemyRenderer")
local EnemyHud         = require("src.ui.EnemyHud")
local TurnBanner       = require("src.ui.TurnBanner")
local ComboBanner      = require("src.ui.ComboBanner")
local DamagePreviewPanel = require("src.ui.DamagePreviewPanel")
local Sfx              = require("src.systems.Sfx")
local SmokeConfig      = require("src.config.SmokeConfig")
local InputFocus       = require("src.ui.InputFocus")
local UiScale          = require("src.ui.UiScale")
local BossCinematic    = require("src.ui.BossCinematic")
local HandDeal         = require("src.ui.HandDeal")

local GameplayScene = {}

GameplayScene.SCENE_MODE = "worldroad"

local game, playButton, endTurnButton, topBar, gameUI, smokeSystem
local setCurrentState, onPhaseCleared, onReturnToMenu
local hoverCard = nil
local lastFloorKey = nil
local pendingArrival = false
local lastInterior = nil
local interiorFade = 0
local bossEntered = false
local bossEnteredKey = nil
local corpseUnderHand = false

local function runFloorKey()
    local run = game and game.runManager and game.runManager.currentRun
    if not run then return nil end
    return (run.actNumber or 1) .. ":" .. (run.floorInAct or 1)
end

local turnStage = nil
local turnStageT = 0

function GameplayScene.init(deps)
    game           = deps.game
    playButton     = deps.playButton
    endTurnButton  = deps.endTurnButton
    topBar         = deps.topBar
    gameUI         = deps.gameUI
    smokeSystem    = deps.smokeSystem
    setCurrentState = deps.setCurrentState or function() end
    onPhaseCleared = deps.onPhaseCleared  or function() end
    onReturnToMenu = deps.onReturnToMenu  or function() end
end

function GameplayScene.isInteriorNode(nodeType, entered)
    return nodeType == "boss" and entered == true
end

function GameplayScene.inBossRoom(nodeType)
    return GameplayScene.isInteriorNode(nodeType,
        bossEntered and bossEnteredKey == runFloorKey())
end

function GameplayScene.isQuiet()
    if turnStage ~= nil or TurnBanner.isActive() then return false end
    if GameplayScene.SCENE_MODE == "worldroad"
        and (WorldRoad.isTraveling() or WorldRoad.isEntering()) then
        return false
    end
    local run = game and game.runManager and game.runManager.currentRun
    local nt = run and run.currentNode and run.currentNode.type
    if nt == "boss" and GameplayScene.SCENE_MODE == "worldroad" and not bossEntered then
        return false
    end
    if BossCinematic.isActive() then return false end
    if HandDeal.isBusy() then return false end
    if EnemyRenderer.isAttacking() then return false end
    if EnemyRenderer.getArrivalOffset and EnemyRenderer.getArrivalOffset() ~= 0 then
        return false
    end
    if EnemyRenderer.isArriving and EnemyRenderer.isArriving() then return false end
    return true
end

function GameplayScene._debugForceBossEntered()
    bossEntered = true
    bossEnteredKey = runFloorKey()
end

function GameplayScene._onBossEntered()
    bossEntered = true
    bossEnteredKey = runFloorKey()
    if game and game.noteBestiary then game:noteBestiary("seen") end
    BossCinematic.startIntro(game)
end

function GameplayScene._debugStartBossIntro()
    GameplayScene._onBossEntered()
end

function GameplayScene.setSmokeSystem(s) smokeSystem = s end

function GameplayScene.setGame(g)
    game = g
    GameplayScene.resetTurnState()
    WorldRoad.resetRun()
    EnemyRenderer.resetRun()
end

function GameplayScene.resetTurnState()
    turnStage = nil
    turnStageT = 0
    bossEntered = false
    BossCinematic.reset()
    HandDeal.reset()
    GameplayScene._endTurnCallout = false
    lastFloorKey = nil
end

function GameplayScene.resumeWorld(g)
    local run = g and g.runManager and g.runManager.currentRun
    local act = (run and run.actNumber) or 1
    local floor = (run and run.floorInAct) or 1
    local pending = run and run.pendingNodes
    local atFork = (pending ~= nil and #pending > 0)
    WorldRoad.restoreProgress(act, atFork and math.max(1, floor - 1) or floor)
    lastFloorKey = act .. ":" .. (atFork and (floor - 1) or floor)
    pendingArrival = false
end

function GameplayScene.requestArrival() pendingArrival = true end

function GameplayScene.travelPending()
    if GameplayScene.SCENE_MODE ~= "worldroad" or not game or WorldRoad.isTraveling() then return false end
    local run = game.runManager and game.runManager.currentRun
    local key
    if run then
        key = (run.actNumber or 1) .. ":" .. (run.floorInAct or 1)
    else
        key = "classic:" .. (game.currentPhase or 1)
    end
    if lastFloorKey == nil then return pendingArrival end
    return key ~= lastFloorKey
end
function GameplayScene.hasPendingArrival() return pendingArrival end

function GameplayScene.getGame() return game end
function GameplayScene.getFloorAnchor() return lastFloorKey end

local function updatePlayButtonPosition()
    if not playButton then return end
    local buttonWidth  = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local buttonX = (love.graphics.getWidth() - buttonWidth) / 1.05
    local buttonY = love.graphics.getHeight() * 0.62
    playButton:setPosition(buttonX, buttonY)
    playButton.width = buttonWidth
    playButton.height = buttonHeight
    if endTurnButton then
        endTurnButton:setPosition(buttonX, buttonY + buttonHeight + 8)
        endTurnButton.width = buttonWidth
        endTurnButton.height = math.floor(buttonHeight * 0.72)
    end
end
GameplayScene.updatePlayButtonPosition = updatePlayButtonPosition

local ENEMY_HAND_CLEARANCE = 12

GameplayScene.HAND_GROWTH = 0.5
local function handScale()
    local k = UiScale.activeK()
    if k <= 1 then return 1 end
    return (1 + (k - 1) * GameplayScene.HAND_GROWTH) / k
end
GameplayScene.handScale = handScale

local function handLayout()
    local width  = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local n = #game.hand
    local hs = handScale()
    local cardY = height - height * 0.2 * hs

    local cardW = 96 * (Config.Cards.BASE_SCALE or 1.333) * hs
    local maxSpacing = Config.Utils.getResponsiveSize(Config.UI.CARD_SPACING_RATIO, 120, "width") * hs

    local areaLeft  = 30
    local areaRight = (playButton and playButton.x or width * 0.80) - 16
    if areaRight < areaLeft + cardW then areaRight = areaLeft + cardW end
    local center = width / 2
    local halfW = math.max(cardW / 2,
        math.min(center - areaLeft, areaRight - center))
    local areaW = halfW * 2

    local spacing
    if n > 1 then
        spacing = math.min(maxSpacing, (areaW - cardW) / (n - 1))
    else
        spacing = 0
    end

    local totalW = spacing * math.max(0, n - 1)
    local startX = center - (totalW + cardW) / 2
    return startX, spacing, cardY, n
end
GameplayScene.handLayout = handLayout

local HOVER_LIFT = 130
local STAGE_CLEARANCE = 18
local function stageFootLimit()
    local _, _, cardY = handLayout()
    return math.floor(cardY - HOVER_LIFT * handScale() - STAGE_CLEARANCE)
end
GameplayScene.stageFootLimit = stageFootLimit

local function syncBattleStage()
    local k = UiScale.activeK()
    local limit = stageFootLimit() * k
    local tb = ((topBar and topBar.height) or 80) * k
    UiScale.outside(function()
        local width, height = love.graphics.getWidth(), love.graphics.getHeight()
        WorldRoad.setBattleRel(WorldRoad.battleRelFor(0, tb, width, height - tb, limit))
    end)
    local hs = handScale()
    local vw, vh = love.graphics.getWidth(), love.graphics.getHeight()
    local half = (96 * (Config.Cards.BASE_SCALE or 1.333) * hs
        + Config.Utils.getResponsiveSize(Config.UI.CARD_SPACING_RATIO, 120, "width") * hs * ((Config.Game.INITIAL_HAND_SIZE or 5) - 1)) / 2
    WorldRoad.setHandZone((vw / 2 - half) * k, (vw / 2 + half) * k, (vh - vh * 0.2 * hs) * k)
end
GameplayScene.syncBattleStage = syncBattleStage

local function updateCardPositions()
    local cardStartX, cardSpacing, cardY = handLayout()
    local base = (Config.Cards.BASE_SCALE or 1.333) * handScale()

    for i, card in ipairs(game.hand) do
        if card.baseScale ~= base then
            local wasBase = card.targetScale == card.baseScale
            card.baseScale = base
            if wasBase or not card.isHovered then card.targetScale = base end
            if card.image then
                card.width = card.image:getWidth() * base
                card.height = card.image:getHeight() * base
            end
        end
        local layoutX = cardStartX + (i - 1) * cardSpacing
        card.layoutX = layoutX
        card.layoutY = cardY
        card.x = card.renderX ~= 0 and card.renderX or layoutX
        card.y = card.renderY ~= 0 and card.renderY or cardY
    end
end

local function jokerFrameGeometry()
    local topBarHeight = (topBar and topBar.height) or 80
    local base = 96 * (Config.Cards.BASE_SCALE or 1.333)
    local slotScale = Config.Cards.JOKER_SLOT_SCALE or 0.7
    local cardW = base * slotScale
    local cardH = 144 * (Config.Cards.BASE_SCALE or 1.333) * slotScale
    local pad, gap, labelH = 8, 8, 18
    local maxSlots = (game and game.maxJokerSlots) or 3
    local frameX = 14
    local frameY = topBarHeight + 8
    local frameW = pad * 2 + maxSlots * cardW + (maxSlots - 1) * gap
    local frameH = pad * 2 + labelH + cardH
    return {
        x = frameX, y = frameY, w = frameW, h = frameH,
        cardW = cardW, cardH = cardH, pad = pad, gap = gap,
        labelH = labelH, maxSlots = maxSlots,
    }
end

function GameplayScene.jokerFrameRect()
    local g = jokerFrameGeometry()
    return g.x, g.y, g.w, g.h
end

function GameplayScene.jokerSlotCenter(i)
    local g = jokerFrameGeometry()
    i = math.max(1, math.min(i or 1, g.maxSlots))
    local slotX = g.x + g.pad + (i - 1) * (g.cardW + g.gap)
    local slotY = g.y + g.pad + g.labelH
    return slotX + g.cardW / 2, slotY + g.cardH / 2
end

local function drawJokersAsCards()
    local g = jokerFrameGeometry()
    require("src.ui.NavCursor").target("jokerFrame", g.x, g.y, g.w, g.h)
    local mx, my = love.mouse.getPosition()
    local frameHot = mx >= g.x and mx <= g.x + g.w and my >= g.y and my <= g.y + g.h

    local Palette = require("src.ui.Palette")
    love.graphics.setColor(0.06, 0.05, 0.04, 0.55)
    love.graphics.rectangle("fill", g.x, g.y, g.w, g.h, 6, 6)
    love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2],
        Palette.AGED_GOLD_DARK[3], frameHot and 0.95 or 0.6)
    love.graphics.setLineWidth(frameHot and 2 or 1)
    love.graphics.rectangle("line", g.x, g.y, g.w, g.h, 6, 6)
    love.graphics.setLineWidth(1)

    local ownedN = 0
    if game.runManager and game.runManager.currentRun
        and game.runManager.currentRun.jokers then
        ownedN = #game.runManager.currentRun.jokers
    end
    local activeN = #game.jokerSlots
    local benched = math.max(0, ownedN - activeN)
    local lf = FontManager.getFont(8)
    love.graphics.setFont(lf)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    local label = I18n.t("hud.jokers_frame", { n = activeN, max = g.maxSlots })
    love.graphics.print(label, g.x + g.pad, g.y + 5)
    if benched > 0 then
        Palette.set(Palette.RUST)
        local bl = I18n.t("hud.jokers_bench", { n = benched })
        love.graphics.print(bl, g.x + g.w - g.pad - lf:getWidth(bl), g.y + 5)
    end

    local slotY = g.y + g.pad + g.labelH
    for i = 1, g.maxSlots do
        local slotX = g.x + g.pad + (i - 1) * (g.cardW + g.gap)
        local joker = game.jokerSlots[i]
        if joker then
            local isHovered = mx >= slotX and mx <= slotX + g.cardW
                and my >= slotY and my <= slotY + g.cardH
            joker.tooltipBelow = true
            joker:updateMouse(mx, my, love.timer.getDelta(), isHovered)
            local originalScale = joker.currentScale
            joker.currentScale = originalScale * Config.Cards.JOKER_SLOT_SCALE
            joker:draw(slotX, slotY)
            joker.currentScale = originalScale
        else
            love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],
                Palette.PARCHMENT_DARK[3], 0.35)
            love.graphics.rectangle("line", slotX, slotY, g.cardW, g.cardH, 4, 4)
            local pf = FontManager.getFont(18)
            love.graphics.setFont(pf)
            love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],
                Palette.PARCHMENT_DARK[3], 0.5)
            love.graphics.print("+", slotX + (g.cardW - pf:getWidth("+")) / 2,
                slotY + (g.cardH - pf:getHeight()) / 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

    game.combatAnimationSystem:draw()

    require("src.ui.StatusTooltip").draw()
end

function GameplayScene.worldOnlyMode()
    local run = game and game.runManager and game.runManager.currentRun
    local nt = run and run.currentNode and run.currentNode.type
    if GameplayScene.SCENE_MODE ~= "worldroad" then return "road" end
    if WorldRoad.isForkActive() then return "road" end
    if GameplayScene.inBossRoom(nt) and not WorldRoad.isEntering() then
        return "hall"
    end
    return "road"
end

function GameplayScene.drawWorldOnly()
    if GameplayScene.worldOnlyMode() == "hall" then
        local saved = GameplayScene.WORLD_ONLY
        GameplayScene.WORLD_ONLY = true
        local ok, err = pcall(GameplayScene.draw)
        GameplayScene.WORLD_ONLY = saved
        if not ok then error(err, 0) end
        return
    end
    local tbReal = (topBar.height or 80) * UiScale.activeK()
    return UiScale.outside(GameplayScene._drawWorldOnlyReal, tbReal)
end

function GameplayScene._drawWorldOnlyReal(topBarHeight)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local currentAct = 1
    local run = game and game.runManager and game.runManager.currentRun
    if run then currentAct = run.actNumber or 1 end
    local biomeIdx = currentAct
    if run and run.endlessMode then
        biomeIdx = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
    end
    WorldRoad.draw(0, topBarHeight, width, height - topBarHeight, biomeIdx)
    WorldRoad.drawOverlays(0, topBarHeight, width, height - topBarHeight)
    local f = WorldRoad._fork
    if f and f.markBoxes then
        for i = 1, (f.n or 3) do
            local b = f.markBoxes[i]
            if b then
                require("src.ui.NavCursor").target("fork:" .. i, b.x1, b.y1,
                    b.x2 - b.x1, b.y2 - b.y1)
            end
        end
    end
end

GameplayScene.HALL_REF_SCALE = 3.7
GameplayScene.HALL_MAX_K = 3
function GameplayScene.hallScreenK(sceneKey, w, h)
    if not sceneKey or not sceneKey:find("^castle_hall_") then return 1 end
    local tr = SceneBackground.getCoverTransform(sceneKey, w, h)
    if not tr then return 1 end
    return math.max(1, math.min(GameplayScene.HALL_MAX_K,
        tr.scale / GameplayScene.HALL_REF_SCALE))
end

GameplayScene.HALL_SHADOW = { tod = 0.55, luma = 0.85, alphaK = 1.6, tint = { 0.22, 0.18, 0.24 } }
function GameplayScene.hallShadowFrame(anchor, width)
    local SE = require("engine.ShadowEngine")
    local H = GameplayScene.HALL_SHADOW
    SE.setFrame(width * ((anchor and anchor.lightXr) or 0.5), width, H.tod, H.luma)
    SE.setTint(H.tint[1], H.tint[2], H.tint[3])
    SE.setAlphaK(H.alphaK)
end

GameplayScene.BOSS_OVER_COMMON = 1.15
function GameplayScene.bossSizeK(k, worldAreaH)
    local floorK = GameplayScene.BOSS_OVER_COMMON * (250 / 330)
        * WorldRoad.enemyScreenK(worldAreaH)
    return math.max(k, floorK)
end

function GameplayScene.draw()
    corpseUnderHand = false
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local topBarHeight = topBar.height or 80

    local currentAct = 1
    local run = game and game.runManager and game.runManager.currentRun
    if run then currentAct = run.actNumber or 1 end

    local nodeType = run and run.currentNode and run.currentNode.type
    local entering = GameplayScene.SCENE_MODE == "worldroad"
        and WorldRoad.isEntering()
    local interior = GameplayScene.SCENE_MODE == "worldroad" and not entering
        and GameplayScene.isInteriorNode(nodeType, bossEntered)

    local traveling = GameplayScene.SCENE_MODE == "worldroad"
        and not interior and (WorldRoad.isTraveling() or GameplayScene.travelPending())
    local worldBattle = GameplayScene.SCENE_MODE == "worldroad"
        and not interior and not traveling and not entering
    local enemyBbox, enemyCx, enemyCy
    if GameplayScene.SCENE_MODE == "worldroad" then syncBattleStage() end
    local uiK = UiScale.activeK()
    local stageYReal = stageFootLimit() * uiK
    local _, _, handTopV = handLayout()
    local handTopReal = handTopV * uiK
    local uiTopBarH = topBarHeight
    local interiorHall = nil
    UiScale.outside(function()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local worldPass = BossCinematic.beginWorldPass()
    local zk, zcx, zcy = BossCinematic.worldZoom()
    if not zk then zk, zcx, zcy = require("src.ui.EnemyEntrance").worldZoom() end
    if zk then
        love.graphics.push()
        love.graphics.translate(math.floor(zcx - zcx * zk), math.floor(zcy - zcy * zk))
        love.graphics.scale(zk)
    end
    local topBarHeight = GameplayScene.WORLD_ONLY and 0 or uiTopBarH * uiK
    local hallShake = false
    if interior then
        local mdx, mdy = require("src.systems.MusicReact").shakeOffset()
        if mdx ~= 0 or mdy ~= 0 then
            local m = math.ceil(math.max(math.abs(mdx), math.abs(mdy)))
            local zk = 1 + 2 * m / math.max(1, math.min(width, height))
            hallShake = true
            love.graphics.push()
            love.graphics.translate(math.floor(width / 2 + mdx + 0.5), math.floor(height / 2 + mdy + 0.5))
            love.graphics.scale(zk)
            love.graphics.translate(-math.floor(width / 2), -math.floor(height / 2))
        end
    end
    if worldBattle then
        enemyCx, enemyCy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,
            0, topBarHeight, width, height - topBarHeight)
        local sizeK = (WorldRoad.battleSizeK and WorldRoad.battleSizeK() or 1)
            * WorldRoad.enemyScreenK(height - topBarHeight)
        WorldRoad.setBattleEnemyDraw(function()
            enemyBbox = EnemyRenderer.draw(game, enemyCx, enemyCy,
                { sizeK = sizeK, shadowMaxY = handTopReal,
                  groundR = WorldRoad.groundRadius(WorldRoad.BATTLE_REL, width, height - topBarHeight) })
        end, enemyCy)
    end

    local sceneKey, sceneH = nil, height
    if interior then
        local hallAct = InteriorFX.hallFor(currentAct)
        local drawn = SceneBackground.draw("castle_hall_" .. hallAct,
            width, height, 0.15)
        sceneKey = "castle_hall_" .. hallAct
        if not drawn then
            sceneKey = SceneLayer.sceneKeyForAct(currentAct)
            sceneH = height - topBarHeight
            SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, currentAct)
        else
            InteriorFX.draw(hallAct)
            require("src.systems.MusicReact").draw(
                SceneBackground.getCoverTransform("castle_hall_" .. hallAct, width, height))
            interiorHall = hallAct
            BossCinematic.drawBack()
        end
    elseif GameplayScene.SCENE_MODE == "worldroad" then
        local biomeIdx = currentAct
        if run and run.endlessMode then
            biomeIdx = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
        end
        WorldRoad.draw(0, topBarHeight, width, height - topBarHeight, biomeIdx)
    else
        sceneKey = SceneLayer.sceneKeyForAct(currentAct)
        sceneH = height - topBarHeight
        SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, currentAct)
    end

    if not traveling and not worldBattle and not entering then
        local anchor = SceneAnchors.get(sceneKey)
        enemyCx, enemyCy = SceneAnchors.groundAnchor(sceneKey, width, sceneH)
        local artCy = enemyCy

        local _, backY = SceneAnchors.groundAnchor(sceneKey, width, sceneH,
            anchor.backYr or anchor.yr)
        local stageY = stageYReal
        if enemyCy > stageY then enemyCy = math.max(backY, stageY) end

        local tetoY = math.floor(handTopReal - ENEMY_HAND_CLEARANCE * uiK)
        if enemyCy > tetoY then enemyCy = tetoY end
        local InteriorDepth = interiorHall and require("src.ui.InteriorDepth")
        local cineHidden = BossCinematic.hidesBoss()
        if interiorHall then GameplayScene.hallShadowFrame(anchor, width) end
        if InteriorDepth and not cineHidden then
            InteriorDepth.drawContact(interiorHall, game.enemy and game.enemy.spriteId,
                enemyCx, enemyCy, BossCinematic.bossAlpha())
        end
        local deathCy = nil
        if anchor.deathYr then
            local _, dy = SceneAnchors.groundAnchor(sceneKey, width, sceneH,
                anchor.deathYr)
            deathCy = math.max(enemyCy, dy)
        end
        corpseUnderHand = deathCy ~= nil and deathCy > tetoY
        local function drawEnemy()
            return EnemyRenderer.draw(game, enemyCx, enemyCy, {
                deathCy = deathCy,
                alpha = interiorHall and BossCinematic.bossAlpha() or nil,
                hallTr = interiorHall and SceneBackground.getCoverTransform(sceneKey, width, sceneH) or nil,
                shadowA = anchor.shadowA,
                lightXr = anchor.lightXr,
                shadowMaxY = handTopReal,
                sizeK = GameplayScene.bossSizeK(
                    SceneAnchors.depthSizeK(sceneKey, width, sceneH, artCy,
                        enemyCy, WorldRoad.ENEMY_SIZE_PERSP) * GameplayScene.hallScreenK(sceneKey, width, sceneH),
                    height - topBarHeight),
            })
        end
        if cineHidden then
            enemyBbox = BossCinematic.measure(drawEnemy)
        else
            enemyBbox = drawEnemy()
        end
        if InteriorDepth then InteriorDepth.noteBbox(enemyBbox) end
        if interiorHall then
            BossCinematic.setStage({
                cx = enemyCx, cy = enemyCy, bbox = enemyBbox or nil,
                foot = EnemyRenderer.getLastFoot(), hall = interiorHall,
                w = width, h = height, backY = backY, artCy = artCy,
                tr = SceneBackground.getCoverTransform(sceneKey, width, sceneH),
            })
            BossCinematic.drawFront()
        end
        if interiorHall then InteriorFX.drawFront(interiorHall, topBarHeight) end
    end
    if hallShake then love.graphics.pop() end

    if GameplayScene.SCENE_MODE == "worldroad" and not interior then
        WorldRoad.drawOverlays(0, topBarHeight, width, height - topBarHeight)
    end
    if zk then love.graphics.pop() end
    require("src.ui.EnemyEntrance").drawFlash(width, height)
    if worldPass then BossCinematic.endWorldPass() end
    end)
    if GameplayScene.WORLD_ONLY then return end
    local cineHide = BossCinematic.hidesHud() or HandDeal.hidesHud()
    local cineHand = BossCinematic.hidesHand() or HandDeal.hidesHand()
    local uiWait = cineHand or HandDeal.hidesUI()
    local deckX, deckY = game:getDeckOrigin()
    if enemyBbox and uiK ~= 1 then
        enemyBbox = { cx = enemyBbox.cx / uiK, topY = enemyBbox.topY / uiK,
            bottomY = enemyBbox.bottomY / uiK, width = enemyBbox.width / uiK,
            height = enemyBbox.height / uiK }
    end
    if enemyCx then enemyCx, enemyCy = enemyCx / uiK, enemyCy / uiK end
    topBar:draw()

    local hoverLift = HOVER_LIFT * handScale()
    if enemyBbox and not traveling and not entering
        and game.enemy and not game.enemy:isDefeated() then
        local _, _, cardY0 = handLayout()
        local cardH = 144 * (Config.Cards.BASE_SCALE or 1.333) * handScale()
        local minLift = math.max(0, cardY0 + cardH * 1.08 - height) + 6
        local footCap = cardY0 - enemyBbox.bottomY - 6
        hoverLift = math.max(minLift, math.min(hoverLift, footCap))
    end

    if not traveling and not entering and not cineHide then
        EnemyHud.draw(game, enemyBbox, enemyCx, enemyCy)
        if enemyBbox and game.enemy and not game.enemy:isDefeated() then
            local T = require("src.systems.Tutorial")
            T.anchor("enemy", enemyBbox.cx - enemyBbox.width / 2, enemyBbox.topY,
                enemyBbox.width, enemyBbox.bottomY - enemyBbox.topY)
            local hp = EnemyHud.hpBarRect(EnemyHud.layout(game, enemyBbox, enemyCx, enemyCy))
            if hp then T.anchor("enemy_hp", hp.x, hp.y, hp.w, hp.h) end
        end
        if game.enemy and not game.enemy:isDefeated() then
            DamagePreviewPanel.drawEnemyGhost(game,
                EnemyHud.hpBarRect(EnemyHud.layout(game, enemyBbox, enemyCx, enemyCy)))
        end
    end

    if not traveling and not entering then
        require("src.ui.BossTokens").drawScreen(game)
    end
    if not cineHide then gameUI:draw(game) end

    TurnBanner.draw()

    local cardStartX, cardSpacing, cardY, currentHandSize = handLayout()

    local draggingCard, draggingIdx
    for i, card in ipairs(game.hand) do
        if card.isDragging then
            draggingCard = card
            draggingIdx = i
            break
        end
    end

    local dropIdx = draggingCard and (function()
        local mx = love.mouse.getX()
        if currentHandSize <= 1 then return 1 end
        local rawIdx = 1 + math.floor((mx - cardStartX + cardSpacing / 2) / cardSpacing)
        return math.max(1, math.min(currentHandSize, rawIdx))
    end)() or nil

    local function renderIdxFor(i)
        if not draggingCard then return i end
        if i == draggingIdx then return i end
        if draggingIdx < dropIdx then
            if i > draggingIdx and i <= dropIdx then return i - 1 end
        else
            if i >= dropIdx and i < draggingIdx then return i + 1 end
        end
        return i
    end

    local dt = love.timer.getDelta()
    for i, card in ipairs(game.hand) do
        local offsetY = 0
        card.isSelected = game:isCardSelected(card)
        card.tooltipSide = true
        card.deferTooltip = true
        card.navGroup = "hand"
        if card.isSelected then offsetY = -100 * handScale() end
        local rIdx = renderIdxFor(i)
        local tx = cardStartX + (rIdx - 1) * cardSpacing
        local ty = cardY + offsetY
        if corpseUnderHand and game.enemy and not game.enemy:isAlive() then
            ty = ty + height * 0.5
        end
        if card == hoverCard and not draggingCard then
            ty = cardY - hoverLift
        end
        if HandDeal.holds(card) then
            card:setRenderPos(deckX, deckY)
        elseif card.isDragging then
            local mx, my = love.mouse.getPosition()
            card:setRenderPos(mx + card.dragOffsetX, my + card.dragOffsetY)
        else
            card:setTargetPos(tx, ty)
            card:updateRender(dt)
        end
    end

    if not entering and not cineHand then
        for _, card in ipairs(game.hand) do
            if not card.isDragging and card ~= hoverCard and not HandDeal.holds(card) then
                local canPlay = game:canPlayCard(card)
                card:draw(card.renderX, card.renderY, canPlay)
            end
        end
        if hoverCard and not hoverCard.isDragging then
            love.graphics.setColor(1, 1, 1, 1)
            local canPlay = game:canPlayCard(hoverCard)
            hoverCard:draw(hoverCard.renderX, hoverCard.renderY, canPlay)
        end
        if draggingCard then
            love.graphics.setColor(1, 1, 1, 1)
            local savedScale = draggingCard.targetScale
            draggingCard.targetScale = draggingCard.baseScale + Config.Cards.DRAG_SCALE_BOOST
            local canPlay = game:canPlayCard(draggingCard)
            draggingCard:draw(draggingCard.renderX, draggingCard.renderY, canPlay)
            draggingCard.targetScale = savedScale
        end
    end

    local roadOutdoor = GameplayScene.SCENE_MODE == "worldroad"
        and not lastInterior
    if smokeSystem and not roadOutdoor then smokeSystem:draw() end
    if not uiWait then
        playButton:draw()
        if endTurnButton then endTurnButton:draw() end
    end
    if not uiWait then
        local NavCursor = require("src.ui.NavCursor")
        local function press(btn)
            return function()
                if btn and btn.visible ~= false and not btn.disabled and btn.onClick then
                    btn.onClick()
                end
            end
        end
        NavCursor.action("y", press(playButton), playButton.x, playButton.y,
            playButton.width, playButton.height)
        if endTurnButton then
            NavCursor.action("x", press(endTurnButton), endTurnButton.x, endTurnButton.y,
                endTurnButton.width, endTurnButton.height)
        end
    end

    if not entering and not uiWait then
        DamagePreviewPanel.drawHandBadges(game)
        DamagePreviewPanel.draw(game,
            { x = playButton.x, y = playButton.y, w = playButton.width },
            topBarHeight + 8)
    end

    if GameplayScene._endTurnCallout and endTurnButton and not uiWait then
        local t = love.timer.getTime()
        local pulse = 0.5 + 0.5 * math.sin(t * 4.2)
        love.graphics.setColor(1, 0.85, 0.30, 0.35 + 0.45 * pulse)
        love.graphics.setLineWidth(2 + pulse * 2)
        love.graphics.rectangle("line", endTurnButton.x - 4, endTurnButton.y - 4,
            endTurnButton.width + 8, endTurnButton.height + 8, 8, 8)
        local ax = endTurnButton.x - 18 - pulse * 6
        local ay = endTurnButton.y + endTurnButton.height / 2
        love.graphics.setColor(1, 0.85, 0.30, 0.9)
        love.graphics.polygon("fill", ax, ay - 8, ax, ay + 8, ax + 12, ay)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
    if game.messageSystem and not uiWait then game.messageSystem:draw() end

    if not uiWait then drawJokersAsCards() end
    GameplayScene._reportTutorialAnchors()

    ComboBanner.draw(topBarHeight)

    for _, card in ipairs(game.hand) do
        if card.drawDeferredTooltip then card:drawDeferredTooltip() end
    end

    BossCinematic.drawUI()
    require("src.ui.EnemyEntrance").drawCard()

    if interiorFade > 0 then
        local a = interiorFade * interiorFade
        love.graphics.setColor(0, 0, 0, a)
        love.graphics.rectangle("fill", 0, 0, width, height)
        love.graphics.setColor(1, 1, 1, 1)
    end
    local ef = WorldRoad.entryFade and WorldRoad.entryFade() or 0
    if ef > 0 then
        love.graphics.setColor(0, 0, 0, ef * ef)
        love.graphics.rectangle("fill", 0, 0, width, height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function GameplayScene.update(dt)
    if not InputFocus.allows(InputFocus.SCENE) then
        for _, card in ipairs((game and game.hand) or {}) do
            card.dragPending = false
            card.isDragging = false
        end
    end

    updatePlayButtonPosition()
    TurnBanner.update(dt)
    ComboBanner.update(dt)

    game.combatAnimationSystem:update(dt)

    if game._endTurnQueued and game.turn == "player"
        and not game.combatAnimationSystem:isBlocking() then
        game._endTurnQueued = false
        game:endTurn()
    end

    do
        local runC = game.runManager and game.runManager.currentRun
        local ntC = runC and runC.currentNode and runC.currentNode.type
        BossCinematic.update(dt, game, { inHall = GameplayScene.inBossRoom(ntC) })
    end
    UiScale.outside(EnemyRenderer.update, dt)
    do
        local runU = game.runManager and game.runManager.currentRun
        local ntU = runU and runU.currentNode and runU.currentNode.type
        local isInt = GameplayScene.isInteriorNode(ntU, bossEntered)
            and not (GameplayScene.SCENE_MODE == "worldroad"
                     and WorldRoad.isEntering())
        if isInt then
            UiScale.outside(InteriorFX.update, dt, InteriorFX.hallFor((runU and runU.actNumber) or 1))
        end
        do
            local enemyM = game.enemy
            local fighting = isInt and ntU == "boss" and GameplayScene.inBossRoom(ntU)
                and not BossCinematic.phase() and enemyM ~= nil and not enemyM:isDefeated()
            require("src.systems.MusicReact").update(dt, {
                fighting = fighting,
                bossId = (runU and runU.currentNode and runU.currentNode.enemyId)
                    or (enemyM and enemyM.spriteId),
                hall = InteriorFX.hallFor((runU and runU.actNumber) or 1),
            })
        end
        if lastInterior ~= nil and isInt ~= lastInterior then
            interiorFade = 1
            require("src.systems.MusicReact").reset()
            if isInt then
                InteriorFX.clear()
                require("src.ui.InteriorDepth").reset()
            end
        end
        lastInterior = isInt
        if interiorFade > 0 then
            interiorFade = math.max(0, interiorFade - dt / 0.9)
        end
    end
    if GameplayScene.SCENE_MODE == "worldroad" then
        do
            local runT = game.runManager and game.runManager.currentRun
            local floorIn
            if runT then
                floorIn = runT.floorInAct or 1
            else
                floorIn = ((game.currentPhase or 1) - 1) % 8 + 1
            end
            local prog = math.min(1, math.max(0, (floorIn - 1) / 7)) ^ 1.35
            WorldRoad.setTimeOfDay(0.62 + 0.38 * prog)
        end
        UiScale.outside(WorldRoad.update, dt)
        syncBattleStage()
        local floorKey
        if game.runManager and game.runManager.currentRun then
            local run = game.runManager.currentRun
            floorKey = (run.actNumber or 1) .. ":" .. (run.floorInAct or 1)
        else
            floorKey = "classic:" .. (game.currentPhase or 1)
        end
        local firstArrival = pendingArrival and lastFloorKey == nil
        if ((lastFloorKey ~= nil and floorKey ~= lastFloorKey) or firstArrival)
           and not WorldRoad.isTraveling() then
            pendingArrival = false
            local run2 = game.runManager and game.runManager.currentRun
            local nt = run2 and run2.currentNode and run2.currentNode.type
            if nt == "boss" then
                bossEntered = false
                WorldRoad.travel({
                    onComplete = function()
                        WorldRoad.enterCastle({
                            onComplete = GameplayScene._onBossEntered,
                        })
                    end,
                })
            else
                WorldRoad.travel({
                    encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
                    onComplete = function()
                        EnemyRenderer.triggerArrival(nil,
                            { still = not require("src.ui.EnemyEntrance").endsWithLanding() })
                    end,
                })
            end
        end
        lastFloorKey = floorKey
    else
        UiScale.outside(SceneLayer.update, dt)
    end

    do
        local runH = game.runManager and game.runManager.currentRun
        local ntH = runH and runH.currentNode and runH.currentNode.type
        local wr = GameplayScene.SCENE_MODE == "worldroad"
        local entering = wr and WorldRoad.isEntering()
        local bossWait = wr and ntH == "boss" and not bossEntered
        local arriving = (EnemyRenderer.getArrivalOffset
            and EnemyRenderer.getArrivalOffset() ~= 0)
            or (EnemyRenderer.isArriving and EnemyRenderer.isArriving())
        local down = (wr and WorldRoad.isTraveling()) or entering or bossWait
            or BossCinematic.isActive() or arriving or false
        HandDeal.setCurtain(down, game,
            { hud = entering or GameplayScene.inBossRoom(ntH) })
        HandDeal.update(dt, game)
    end

    game:announceDeathIfPending(nil)

    if game._deathPauseTimer and game._deathPauseTimer > 0 then
        game._deathPauseTimer = math.max(0, game._deathPauseTimer - dt)
    end

    if game:checkGameOver() and not game.combatAnimationSystem:isBlocking() then
        Sfx.play("runDefeat")
        setCurrentState("gameOver")
        return
    end

    if game:checkVictory() and game:isReadyForEndScreen()
        and not BossCinematic.holdsEnd() then
        Sfx.play("runVictory")
        setCurrentState("victory")
        return
    end

    if game:isPhaseCleared() and game:isReadyForEndScreen()
        and not BossCinematic.holdsEnd() then
        onPhaseCleared()
        return
    end

    if game.turn == "enemy" and not game.combatAnimationSystem:isBlocking()
       and game.enemy:isAlive() then
        if turnStage == nil then
            turnStage = "banner"
            turnStageT = 0.75
            TurnBanner.show("enemy")
        elseif turnStage == "banner" then
            turnStageT = turnStageT - dt
            if turnStageT <= 0 then
                game:enemyTurn()
                turnStage = "acting"
            end
        end
    elseif turnStage == "acting" then
        local attacking = EnemyRenderer.isAttacking and EnemyRenderer.isAttacking()
        if not attacking and not game._enemyActing then
            turnStage = nil
            if game.enemy:isAlive() and game.player:isAlive() then
                TurnBanner.show("player")
            end
        end
    end

    if smokeSystem and not (GameplayScene.SCENE_MODE == "worldroad"
        and not lastInterior) then
        smokeSystem:update(dt)
    end

    updateCardPositions()

    local mx, my = love.mouse.getPosition()
    hoverCard = nil
    local anyDragging = false
    for _, card in ipairs(game.hand) do
        if card.isDragging then anyDragging = true; break end
    end
    local handClosed = HandDeal.isBusy()
    for i, card in ipairs(game.hand) do
        card.index = i
        local allowHover = (not anyDragging) and (hoverCard == nil) and not handClosed
        card:updateMouse(mx, my, dt, allowHover)
        if card.isHovered then hoverCard = card end
    end

    playButton:update(dt)
    if endTurnButton then endTurnButton:update(dt) end

    DamagePreviewPanel.update(game, hoverCard, dt)

    do
        local blocking = game.combatAnimationSystem:isBlocking()
        local hasSelection = #game.selectedCards > 0
        local anyPlayable = false
        for _, c in ipairs(game.hand) do
            if (c.cost or 0) <= game.player.mana then
                anyPlayable = true
                break
            end
        end
        local myTurn = game.turn == "player" and not blocking and not handClosed
        if playButton.setEnabled then
            playButton:setEnabled(myTurn and (hasSelection or anyPlayable))
        end
        if endTurnButton and endTurnButton.setEnabled then
            endTurnButton:setEnabled(myTurn)
        end
        GameplayScene._endTurnCallout = myTurn and not hasSelection
            and not anyPlayable and #game.hand >= 0

        if GameplayScene._endTurnCallout and turnStage == nil
            and not TurnBanner.isActive()
            and not require("src.systems.Tutorial").holdsTurn() then
            GameplayScene._autoEndT = (GameplayScene._autoEndT or 0) + dt
            if GameplayScene._autoEndT >= 0.2 then
                GameplayScene._autoEndT = 0
                game:endTurn()
            end
        else
            GameplayScene._autoEndT = 0
        end
    end
    gameUI:update(dt, game)

    if game.messageSystem and not BossCinematic.isActive() then
        game.messageSystem:update(dt)
    end
    if game.enemy then game.enemy:update(dt) end
end

function GameplayScene.mousepressed(x, y, button)
    if GameplayScene.SCENE_MODE == "worldroad" and WorldRoad.isEntering() then
        return true
    end
    if BossCinematic.lockInput() then
        if button == 1 then BossCinematic.skip() end
        return true
    end
    if button == 1 and require("src.ui.EnemyEntrance").cardVisible() then
        require("src.ui.EnemyEntrance").skipCard()
        return true
    end
    if topBar:mousepressed(x, y, button) then return true end

    if HandDeal.isBusy() then return false end

    if button == 1 then
        local jx, jy, jw, jh = GameplayScene.jokerFrameRect()
        if x >= jx and x <= jx + jw and y >= jy and y <= jy + jh then
            if _G.toggleJokerManager then _G.toggleJokerManager() end
            return true
        end
    end

    if button == 1 then
        if playButton:mousepressed(x, y, button) then return true end
        if endTurnButton and endTurnButton:mousepressed(x, y, button) then
            return true
        end

        local armed = false
        for _, card in ipairs(game.hand) do
            if card.isHovered then
                card.dragPending = true
                card.dragStartMX = x
                card.dragStartMY = y
                card.dragOffsetX = card.x - x
                card.dragOffsetY = card.y - y
                armed = true
            end
        end
        if armed then return true end
    end
    return false
end

local function computeHandDropIndex(mx, handSize)
    if handSize <= 1 then return 1 end
    local cardStartX, cardSpacing = handLayout()
    if cardSpacing <= 0 then return 1 end
    local rawIdx = 1 + math.floor((mx - cardStartX + cardSpacing / 2) / cardSpacing)
    return math.max(1, math.min(handSize, rawIdx))
end

function GameplayScene.mousereleased(x, y, button)
    if topBar:mousereleased(x, y, button) then return end

    if button == 1 then
        playButton:mousereleased(x, y, button)
        if endTurnButton then endTurnButton:mousereleased(x, y, button) end

        local reorderedCard, fromIdx
        for i, card in ipairs(game.hand) do
            if card.isDragging then
                reorderedCard = card
                fromIdx = i
                break
            end
        end

        if reorderedCard then
            local dropIdx = computeHandDropIndex(x, #game.hand)
            if dropIdx ~= fromIdx then
                table.remove(game.hand, fromIdx)
                table.insert(game.hand, dropIdx, reorderedCard)
                Sfx.play("cardSelect")
            end
        else
            for _, card in ipairs(game.hand) do
                if card.dragPending and card.isHovered then
                    game:selectCard(card)
                end
            end
        end

        for _, card in ipairs(game.hand) do
            card.dragPending = false
            card.isDragging = false
        end
    end
end

function GameplayScene.mousemoved(x, y, dx, dy)
    local threshold = Config.Cards.DRAG_THRESHOLD_PX
    for _, card in ipairs(game.hand) do
        if card.dragPending and not card.isDragging then
            local distX = x - card.dragStartMX
            local distY = y - card.dragStartMY
            if (distX * distX + distY * distY) > (threshold * threshold) then
                card.isDragging = true
            end
        end
    end
end

function GameplayScene.keypressed(key)
    if key == "escape" then
        onReturnToMenu()
        return
    end
    if BossCinematic.lockInput() then
        if key == "return" or key == "kpenter" or key == "space" then
            BossCinematic.skip()
        end
        return
    end
    if (key == "return" or key == "kpenter" or key == "space")
        and require("src.ui.EnemyEntrance").cardVisible() then
        require("src.ui.EnemyEntrance").skipCard()
        return
    end
    if game and game.isRunMode then return end
    local dev = require("src.core.Release").isDev()
    if not dev and (key == "r" or key == "0" or key == "1" or key == "2"
                    or key == "3" or key == "4") then
        return
    end
    if key == "r" then
        game:startGame()
    elseif key == "1" then
        SmokeConfig.applyToSystem(smokeSystem, "subtle")
    elseif key == "2" then
        SmokeConfig.applyToSystem(smokeSystem, "default")
    elseif key == "3" then
        SmokeConfig.applyToSystem(smokeSystem, "atmospheric")
    elseif key == "4" then
        SmokeConfig.applyToSystem(smokeSystem, "intense")
    elseif key == "0" then
        if smokeSystem then smokeSystem:clear() end
    end
end

function GameplayScene._reportTutorialAnchors()
    if not game then return end
    local Tutorial = require("src.systems.Tutorial")
    local x1, y1, x2, y2
    local channelCards, evokeCards = {}, {}
    for _, c in ipairs(game.hand or {}) do
        if c.renderX and c.renderY then
            local cw = (c.image and c.image.getWidth and c.image:getWidth() or 96)
                * (c.scale or c.baseScale or 1.333)
            local ch = (c.image and c.image.getHeight and c.image:getHeight() or 144)
                * (c.scale or c.baseScale or 1.333)
            x1 = math.min(x1 or c.renderX, c.renderX)
            y1 = math.min(y1 or c.renderY, c.renderY)
            x2 = math.max(x2 or (c.renderX + cw), c.renderX + cw)
            y2 = math.max(y2 or (c.renderY + ch), c.renderY + ch)
            local box = { x = c.renderX, y = c.renderY, w = cw, h = ch }
            for _, e in ipairs(c.effects or {}) do
                if e.type == "channel_orb" then channelCards[#channelCards + 1] = box end
                if e.type == "evoke_orb" or e.type == "evoke_all_orbs" then
                    evokeCards[#evokeCards + 1] = box
                end
            end
        end
    end
    if x1 then Tutorial.anchor("hand", x1, y1, x2 - x1, y2 - y1) end
    if #channelCards > 0 then Tutorial.anchorList("hand_channel", channelCards) end
    if #evokeCards > 0 then Tutorial.anchorList("hand_evoke", evokeCards) end
    if playButton then
        Tutorial.anchor("play", playButton.x, playButton.y, playButton.width, playButton.height)
    end
    if endTurnButton then
        Tutorial.anchor("end_turn", endTurnButton.x, endTurnButton.y,
            endTurnButton.width, endTurnButton.height)
    end
    local g = jokerFrameGeometry()
    if g and g.w and g.w > 0 then Tutorial.anchor("jokers", g.x, g.y, g.w, g.h) end
end

return GameplayScene
