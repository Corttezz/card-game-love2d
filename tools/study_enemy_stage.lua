-- tools/study_enemy_stage.lua
-- ESTUDO do palco da batalha: onde o inimigo para na estrada e o quanto ele
-- colide com a mão (carta em hover + tooltip da carta) em 3 tamanhos.
--
--   love . test_one study_enemy_stage            -> distâncias 9,10,11,12,13
--   love . test_one study_enemy_stage 9,11,13    -> lista própria
--   love . test_one study_enemy_stage auto,shots -> + PNG de toda cena
--
-- Pra cada (tamanho × distância × ato × tipo de nó) desenha o GameplayScene
-- REAL num canvas com a janela FALSIFICADA (setMode repetido trava tool —
-- CLAUDE.md), com o mouse falso sobre a carta do meio, e mede:
--   enemy  = sprite + cluster do EnemyHud (EnemyHud.layout().rect)
--   card   = Card.lastDrawRect da carta em hover
--   tip    = CardInfoDisplay.lastRect (descrição da carta)
-- Saída: tabela no console + stage_<W>x<H>_rel<R>_<ato>_<no>.png no save dir
-- (só as cenas da prancha, ou todas com "shots").
--
-- Distância 'rel' é a WorldRoad.BATTLE_REL candidata; o tamanho do inimigo
-- segue a perspectiva do mundo (WorldRoad.battleSizeK). Chefe luta no salão:
-- lá a distância não se aplica, só entra pra medir.

local M = {}

local SIZES = { { 1024, 768 }, { 1280, 720 }, { 1920, 1080 } }
local NODES = { "battle", "elite", "boss" }
-- cenas que vão pra prancha mesmo sem "shots"
local PRANCHA = { ["1_battle"] = true, ["3_elite"] = true, ["2_boss"] = true }

local function inter(a, b)
    if not a or not b then return 0 end
    local x0, y0 = math.max(a.x, b.x), math.max(a.y, b.y)
    local x1 = math.min(a.x + a.w, b.x + b.w)
    local y1 = math.min(a.y + a.h, b.y + b.h)
    if x1 <= x0 or y1 <= y0 then return 0, 0 end
    return (x1 - x0) * (y1 - y0), y1 - y0
end

function M.run(relArg, shotsArg)
    local rels = {}
    for r in tostring(relArg or "9,11,13,15,auto"):gmatch("[%w%.]+") do
        if r ~= "shots" then rels[#rels + 1] = tonumber(r) or r end
    end
    -- test_one só repassa UM argumento: "auto,shots" liga as capturas
    local allShots = (shotsArg == "shots")
        or tostring(relArg or ""):find("shots", 1, true) ~= nil

    _G.EventManager = _G.EventManager or require("engine.EventManager")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    -- outras suites do sandbox deixam o idioma trocado no settings.tool
    if I18n.setLocale then I18n.setLocale("pt_BR") end
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local EnemyHud = require("src.ui.EnemyHud")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local FontManager = require("src.ui.FontManager")

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    -- mão de 5 cartas com descrição de verdade (tooltip de tamanho real)
    local db = game.deckManager.cardDatabase
    local ids = { "warrior_cleave", "warrior_shield_wall", "warrior_bash",
        "warrior_iron_skin", "warrior_rampage" }
    local hand = {}
    for _, id in ipairs(ids) do
        local cd = db:getCard(id)
        if cd then hand[#hand + 1] = db:createCardInstance(cd) end
    end
    if #hand < 5 then
        for _, cd in pairs(db:getAllCards()) do
            if #hand >= 5 then break end
            if cd.class == "warrior" and cd.type ~= "joker" then
                hand[#hand + 1] = db:createCardInstance(cd)
            end
        end
    end
    game.hand = hand
    game.player.mana = 9
    game.enemy.statusEffects = {
        { name = "poison", stacks = 3, duration = 2 },
        { name = "weak", stacks = 1, duration = 2 },
    }

    local topBar = TopBar:new()
    topBar:setGame(game)
    local gameUI = GameUI:new()
    local playButton = Button:new(800, 600, 150, 46, "Jogar")
    local endTurnButton = Button:new(800, 660, 150, 34, "Fim")
    GameplayScene.init({ game = game, topBar = topBar, gameUI = gameUI,
        playButton = playButton, endTurnButton = endTurnButton })

    -- captura o bbox que a cena entrega ao HUD
    local realDraw = EnemyRenderer.draw
    local lastBbox
    EnemyRenderer.draw = function(...)
        local b = realDraw(...)
        lastBbox = b
        return b
    end

    local gw, gh, gd = love.graphics.getWidth, love.graphics.getHeight,
        love.graphics.getDimensions
    local realMouse, realMX, realMY = love.mouse.getPosition, love.mouse.getX,
        love.mouse.getY
    local rows = {}

    local origRel = WorldRoad.BATTLE_REL
    local origNear, origFar = WorldRoad.BATTLE_REL_NEAR, WorldRoad.BATTLE_REL_FAR
    local origExp = WorldRoad.ENEMY_SIZE_PERSP
    -- STAGE_PERSP=0.5 → o monstro encolhe com a raiz da perspectiva
    if os.getenv("STAGE_PERSP") then
        WorldRoad.ENEMY_SIZE_PERSP = tonumber(os.getenv("STAGE_PERSP"))
    end
    for _, sz in ipairs(SIZES) do
        local W, H = sz[1], sz[2]
        love.graphics.getWidth = function() return W end
        love.graphics.getHeight = function() return H end
        love.graphics.getDimensions = function() return W, H end
        FontManager.clearCache()
        if topBar.resize then topBar:resize(W, H) end
        local canvas = love.graphics.newCanvas(W, H)

        for _, rel in ipairs(rels) do
            -- número = palco FIXO (near = far = rel); "auto" = o palco real
            -- (battleRelFor pela zona da mão em hover)
            if type(rel) == "number" then
                WorldRoad.BATTLE_REL_NEAR, WorldRoad.BATTLE_REL_FAR = rel, rel
            else
                WorldRoad.BATTLE_REL_NEAR, WorldRoad.BATTLE_REL_FAR = origNear, origFar
            end
            for act = 1, 6 do
                for _, nodeType in ipairs(NODES) do
                    local run = game.runManager.currentRun
                    run.actNumber = act
                    run.floorInAct = (nodeType == "boss") and 8 or 3
                    run.currentNode = { type = nodeType }
                    game.enemy.spriteId = EnemyRenderer.resolveSpriteId(act, nodeType)
                    game.enemy.isBoss = (nodeType == "boss")
                    game.enemy.health = game.enemy.maxHealth
                    GameplayScene.resetTurnState()
                    if nodeType == "boss" then GameplayScene._debugForceBossEntered() end
                    WorldRoad.setBiome(act)

                    -- mouse sobre a carta do MEIO, em repouso
                    local sx, sp, cy = GameplayScene.handLayout()
                    local mid = math.ceil(#hand / 2)
                    local mx = sx + (mid - 1) * sp + 60
                    local my = cy + 60
                    love.mouse.getPosition = function() return mx, my end
                    love.mouse.getX = function() return mx end
                    love.mouse.getY = function() return my end

                    love.graphics.setCanvas({ canvas, stencil = true })
                    for _ = 1, 40 do
                        GameplayScene.update(1 / 30)
                        if WorldRoad.isTraveling() then
                            print("[estudo] AVISO: viagem disparou", act, nodeType)
                        end
                    end
                    love.graphics.clear(0, 0, 0, 1)
                    lastBbox = nil
                    GameplayScene.draw()
                    love.graphics.setCanvas()

                    local lf = EnemyRenderer.getLastFoot()
                    if lf then
                        print(string.format("[pe] %dx%d %d_%s %s quadro=%d pad=%d escala=%.2f gap=%.2f",
                            W, H, act, nodeType, game.enemy.spriteId, lf.frame, lf.pad,
                            lf.scale, lf.groundY - lf.footBottom))
                    end
                    local hc = hand[mid]
                    local card = hc.isHovered and hc.lastDrawRect or nil
                    local tip = hc.isHovered and hc.cardInfoDisplay.lastRect or nil
                    local L = type(lastBbox) == "table"
                        and EnemyHud.layout(game, lastBbox) or nil
                    local er = L and L.rect
                    local sprite = lastBbox and { x = lastBbox.cx - lastBbox.width / 2,
                        y = lastBbox.topY, w = lastBbox.width, h = lastBbox.bottomY - lastBbox.topY }
                    local aC, hC = inter(er, card)
                    local aT, hT = inter(er, tip)
                    local aS = inter(sprite, tip)
                    local row = {
                        W = W, H = H, rel = rel, act = act, node = nodeType,
                        relEff = WorldRoad.BATTLE_REL,
                        id = game.enemy.spriteId,
                        foot = lastBbox and lastBbox.bottomY or -1,
                        spriteH = lastBbox and math.floor(lastBbox.bottomY - lastBbox.topY) or -1,
                        hudTop = er and math.floor(er.y) or -1,
                        cardTop = card and math.floor(card.y) or -1,
                        tipTop = tip and math.floor(tip.y) or -1,
                        tipBot = tip and math.floor(tip.y + tip.h) or -1,
                        ovCardPx = math.floor(hC or 0),
                        ovTipArea = math.floor(aT or 0),
                        ovTipH = math.floor(hT or 0),
                        ovSpriteTip = math.floor(aS or 0),
                        hovered = hc.isHovered,
                    }
                    rows[#rows + 1] = row
                    print(string.format(
                        "[estudo] %4dx%-4d rel=%-4s(%.1f) %d_%-6s %-17s pe=%4d alt=%3d hudTop=%4d carta=%4d tip=%4d-%4d | sobrepoe carta=%3dpx tip=%6dpx2 (h%3d) spriteXtip=%6d%s",
                        W, H, tostring(rel), row.relEff, act, nodeType, row.id, row.foot, row.spriteH,
                        row.hudTop, row.cardTop, row.tipTop, row.tipBot, row.ovCardPx,
                        row.ovTipArea, row.ovTipH, row.ovSpriteTip,
                        hc.isHovered and "" or "  (SEM HOVER)"))

                    local key = act .. "_" .. nodeType
                    if allShots or PRANCHA[key] then
                        -- debug: contorno das três réguas
                        love.graphics.setCanvas(canvas)
                        love.graphics.setLineWidth(2)
                        -- STAGE_NORECT=1: sem as réguas (pra olhar o pé)
                        if os.getenv("STAGE_NORECT") then er, card, tip = nil, nil, nil end
                        if er then love.graphics.setColor(1, 0.2, 0.2, 1)
                            love.graphics.rectangle("line", er.x, er.y, er.w, er.h) end
                        if card then love.graphics.setColor(0.2, 1, 0.3, 1)
                            love.graphics.rectangle("line", card.x, card.y, card.w, card.h) end
                        if tip then love.graphics.setColor(0.3, 0.6, 1, 1)
                            love.graphics.rectangle("line", tip.x, tip.y, tip.w, tip.h) end
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.setCanvas()
                        canvas:newImageData():encode("png",
                            ("stage_%dx%d_rel%s_p%s_%s.png"):format(W, H, tostring(rel), tostring(WorldRoad.ENEMY_SIZE_PERSP), key))
                    end
                end
            end
        end
    end
    WorldRoad.BATTLE_REL = origRel
    WorldRoad.BATTLE_REL_NEAR, WorldRoad.BATTLE_REL_FAR = origNear, origFar
    WorldRoad.ENEMY_SIZE_PERSP = origExp
    love.graphics.getWidth, love.graphics.getHeight = gw, gh
    love.graphics.getDimensions = gd
    love.mouse.getPosition, love.mouse.getX, love.mouse.getY = realMouse, realMX, realMY
    EnemyRenderer.draw = realDraw

    -- resumo por (tamanho, rel), separando estrada (battle/elite) de salão
    print("\n[estudo] RESUMO — estrada (battle+elite, 12 cenas por linha)")
    for _, sz in ipairs(SIZES) do
        for _, rel in ipairs(rels) do
            local nC, nT, nS, n, hmin, hmax = 0, 0, 0, 0, 1e9, 0
            for _, r in ipairs(rows) do
                if r.W == sz[1] and r.rel == rel and r.node ~= "boss" then
                    n = n + 1
                    if r.ovCardPx > 0 then nC = nC + 1 end
                    if r.ovTipArea > 0 then nT = nT + 1 end
                    if r.ovSpriteTip > 0 then nS = nS + 1 end
                    hmin = math.min(hmin, r.spriteH); hmax = math.max(hmax, r.spriteH)
                end
            end
            print(string.format("  %4dx%-4d rel=%-4s colide carta %2d/%d  colide tip(hud) %2d/%d  sprite x tip %2d/%d  altura %d-%dpx",
                sz[1], sz[2], tostring(rel), nC, n, nT, n, nS, n, hmin, hmax))
        end
    end
    return true
end

return M
