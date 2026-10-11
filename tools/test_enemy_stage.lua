-- tools/test_enemy_stage.lua
-- Regressões do PALCO da batalha (pedidos do dono, Out/2026):
--
--   1. "quando ele fica o corpo inteiro pra fora, ainda fica meio que
--      flutuando alguns milímetros do chão" — todo inimigo APOIADO, em TODO
--      quadro da idle, tem o pé entre 0 e 3px DENTRO do chão (gap ∈ [-3, 0];
--      gap = linha do chão − base do pé). Quem flutua por design continua no
--      ar. A margem do pé é medida AQUI, de forma independente do renderer.
--   2. "os inimigos param muito na frente da tela; a carta em hover e a
--      descrição ficam à frente do inimigo" — na estrada, inimigo + HUD não
--      encostam na carta levantada NEM no tooltip dela, em 1024x768, 1280x720
--      e 1920x1080 (janela falsificada; caminho REAL da cena com mouse falso).
--      No salão do chefe o recuo é limitado pela borda do piso: cobra-se que
--      ele recue sem sair da laje e continue MAIOR que o inimigo comum.
--
--   love . test_one test_enemy_stage

local TK = require("tools.testkit")

local M = {}

local SIZES = { { 1024, 768 }, { 1280, 720 }, { 1920, 1080 } }
local ROOT = "assets/sprites/characters/enemies/"

-- margem de cada quadro da idle, varrida aqui (não pelo renderer)
local function framePadsOf(id)
    local dir = ROOT .. id .. "/animations/idle/south"
    if not love.filesystem.getInfo(dir) then return nil end
    local files = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
        if f:match("^%d+%.png$") then files[#files + 1] = f end
    end
    table.sort(files, function(a, b)
        return tonumber(a:match("%d+")) < tonumber(b:match("%d+"))
    end)
    local pads = {}
    for _, f in ipairs(files) do
        local data = love.image.newImageData(dir .. "/" .. f)
        local w, h = data:getWidth(), data:getHeight()
        local pad = h
        for y = h - 1, 0, -1 do
            local hit = false
            for x = 0, w - 1 do
                local _, _, _, a = data:getPixel(x, y)
                if a > 0.1 then hit = true; break end
            end
            if hit then pad = (h - 1) - y; break end
        end
        pads[#pads + 1] = pad
    end
    return pads
end

local function inter(a, b)
    if not a or not b then return false end
    return math.max(a.x, b.x) < math.min(a.x + a.w, b.x + b.w)
        and math.max(a.y, b.y) < math.min(a.y + a.h, b.y + b.h)
end

local function withSize(W, H, fn)
    local gw, gh, gd = love.graphics.getWidth, love.graphics.getHeight,
        love.graphics.getDimensions
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end
    require("src.ui.FontManager").clearCache()
    local ok, err = pcall(fn)
    love.graphics.getWidth, love.graphics.getHeight = gw, gh
    love.graphics.getDimensions = gd
    require("src.ui.FontManager").clearCache()
    if not ok then error(err, 0) end
end

function M.run()
    local t = TK.new("Palco da batalha: pé no chão e distância de parada")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()

    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local EnemyPoses    = require("src.data.enemy_poses")
    local EnemyHud      = require("src.ui.EnemyHud")
    local WorldRoad     = require("src.ui.WorldRoad")
    local SceneAnchors  = require("src.data.scene_anchors")
    local GameplayScene = require("src.scenes.GameplayScene")

    local game = TK.newRunGame("warrior")
    local canvas = love.graphics.newCanvas(640, 480)

    -- ===================================================================
    -- 1. PÉ NO CHÃO — todo inimigo, todo quadro da idle
    -- ===================================================================
    local ids = {}
    for _, id in ipairs(love.filesystem.getDirectoryItems(ROOT)) do
        if love.filesystem.getInfo(ROOT .. id .. "/animations/idle/south") then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    t:truthy("ha inimigos com idle no disco (" .. #ids .. ")", #ids >= 15)

    print("  inimigo            pose      quadros  pads(arte)        "
        .. "gap antes(pior)  gap agora [min,max]")
    for _, id in ipairs(ids) do
        local pads = framePadsOf(id)
        local floating = EnemyPoses.isFloating(id)
        EnemyRenderer.resetRun()
        game.enemy.spriteId = id
        local gmin, gmax, worstBefore = 1e9, -1e9, -1e9
        for _, boss in ipairs({ false, true }) do
            game.enemy.isBoss = boss
            love.graphics.setCanvas(canvas)
            EnemyRenderer.draw(game, 320, 400)   -- carrega a idle deste id
            local n = EnemyRenderer._debugFrameCount()
            for i = 1, n do
                EnemyRenderer._debugSetFrame(i)
                EnemyRenderer.draw(game, 320, 400, { sizeK = 0.8 })
                local lf = EnemyRenderer.getLastFoot()
                -- base do pé recalculada com a margem INDEPENDENTE
                local foot = math.floor(lf.drawY) + (lf.ih - pads[i]) * lf.scale
                local gap = lf.groundY - foot
                gmin = math.min(gmin, gap); gmax = math.max(gmax, gap)
                -- antes (Set/2026): margem só do 1º quadro, truncada, e o
                -- respiro {-1,0} — o pior quadro descolava isto:
                local before = (pads[i] - pads[1]) * lf.scale + 1
                worstBefore = math.max(worstBefore, before)
            end
            love.graphics.setCanvas()
        end
        print(string.format("  %-18s %-9s %7d  %-17s %+6.1fpx         [%+.1f, %+.1f]",
            id, floating and "flutua" or "apoiado", #pads,
            table.concat(pads, ","), worstBefore, gmin, gmax))
        if floating then
            t:truthy(id .. " (flutua por design) continua NO AR em todo quadro",
                gmin > 3)
        else
            t:truthy(string.format("%s: pé afundado 0-3px em todo quadro (gap %.1f..%.1f)",
                id, gmin, gmax), gmin >= -3 and gmax <= 0)
        end

        -- a VIAGEM (billboard que vem lá de trás) usa a mesma régua
        local bb = EnemyRenderer.getEncounterBillboard(game.enemy)
        if floating then
            t:truthy(id .. ": billboard de quem flutua não afunda",
                bb and (bb.footSink or 0) == 0)
        else
            local same = bb and bb.framePads and #bb.framePads == #pads
            for i = 1, (same and #pads or 0) do
                if bb.framePads[i] ~= pads[i] then same = false end
            end
            t:truthy(id .. ": billboard da viagem crava o pé por quadro e afunda",
                same and bb.footSink == EnemyRenderer.FOOT_SINK)
        end
    end

    -- ===================================================================
    -- 2. DISTÂNCIA DE PARADA — caminho real da cena, 3 tamanhos
    -- ===================================================================
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local db = game.deckManager.cardDatabase
    local hand = {}
    for _, cd in pairs(db:getAllCards()) do
        if #hand >= 5 then break end
        if cd.class == "warrior" and cd.type ~= "joker" then
            hand[#hand + 1] = db:createCardInstance(cd)
        end
    end
    game.hand = hand
    game.player.mana = 9
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(800, 600, 150, 46, "Jogar"),
        endTurnButton = Button:new(800, 660, 150, 34, "Fim") })

    local realDraw = EnemyRenderer.draw
    local lastBbox
    EnemyRenderer.draw = function(...)
        local b = realDraw(...)
        lastBbox = b
        return b
    end
    local realMouse = love.mouse.getPosition

    local function scene(W, H, act, nodeType)
        local run = game.runManager.currentRun
        run.actNumber = act
        run.floorInAct = (nodeType == "boss") and 8 or 3
        run.currentNode = { type = nodeType }
        game.enemy.spriteId = EnemyRenderer.resolveSpriteId(act, nodeType)
        game.enemy.isBoss = (nodeType == "boss")
        GameplayScene.resetTurnState()
        if nodeType == "boss" then GameplayScene._debugForceBossEntered() end
        WorldRoad.setBiome(act)
        local sx, sp, cy = GameplayScene.handLayout()
        local mid = math.ceil(#hand / 2)
        local mx, my = sx + (mid - 1) * sp + 60, cy + 60
        love.mouse.getPosition = function() return mx, my end
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas({ cv, stencil = true })
        for _ = 1, 20 do GameplayScene.update(1 / 30) end
        lastBbox = nil
        GameplayScene.draw()
        love.graphics.setCanvas()
        love.mouse.getPosition = realMouse
        local hc = hand[mid]
        local L = type(lastBbox) == "table" and EnemyHud.layout(game, lastBbox)
        return {
            rect = L and L.rect, bbox = lastBbox,
            card = hc.isHovered and hc.lastDrawRect or nil,
            tip = hc.isHovered and hc.cardInfoDisplay.lastRect or nil,
            rel = WorldRoad.BATTLE_REL,
        }
    end

    for _, sz in ipairs(SIZES) do
        local W, H = sz[1], sz[2]
        withSize(W, H, function()
            local tag = W .. "x" .. H
            local maxRoadH = 0
            for act = 1, 6 do
                for _, nodeType in ipairs({ "battle", "elite" }) do
                    local r = scene(W, H, act, nodeType)
                    local name = string.format("%s %d_%s", tag, act, nodeType)
                    t:truthy(name .. ": carta do meio em hover com tooltip medido",
                        r.card and r.tip and r.rect)
                    t:falsy(name .. ": inimigo+HUD não encosta na carta em hover",
                        inter(r.rect, r.card))
                    t:falsy(name .. ": inimigo+HUD não encosta no tooltip da carta",
                        inter(r.rect, r.tip))
                    if r.bbox then
                        local h = r.bbox.bottomY - r.bbox.topY
                        maxRoadH = math.max(maxRoadH, h)
                        -- legível: nunca menor que a própria carta da mão
                        t:truthy(string.format("%s: inimigo ainda grande (%.0fpx >= 140)",
                            name, h), h >= 140)
                        t:truthy(name .. ": HUD inteiro dentro da tela",
                            r.rect.y >= 0)
                    end
                end
            end
            print(string.format("  %s: palco da estrada em rel %.2f", tag,
                WorldRoad.BATTLE_REL))
            t:truthy(tag .. ": palco nunca mais perto que o histórico (rel 9)",
                WorldRoad.BATTLE_REL >= WorldRoad.BATTLE_REL_NEAR)

            -- salão do chefe: recua sem sair da laje e segue o maior da tela
            for act = 1, 6 do
                local r = scene(W, H, act, "boss")
                local key = "castle_hall_" .. act
                local a = SceneAnchors.get(key)
                local _, artY = SceneAnchors.groundAnchor(key, W, H)
                local _, backY = SceneAnchors.groundAnchor(key, W, H, a.backYr or a.yr)
                local foot = r.bbox and r.bbox.bottomY or 1e9
                local name = string.format("%s chefe %d", tag, act)
                t:truthy(string.format("%s: não avança além da arte (pé %d <= %d)",
                    name, foot, artY), foot <= artY)
                -- O TETO DA MÃO (pé nunca abaixo do topo da mão em repouso,
                -- GameplayScene ENEMY_HAND_CLEARANCE=12) pode erguer o pé
                -- acima da borda nos salões de laje baixa (2 e 5) — é a
                -- limitação de enquadramento já registrada em
                -- memory/enemy_pose_and_scene_anchor.md, não recuo do palco.
                local _, _, cardY = GameplayScene.handLayout()
                local floorY = math.min(backY, math.floor(cardY - 12))
                t:truthy(string.format("%s: não sai da laje (pé %d >= borda %d)",
                    name, foot, floorY), foot >= floorY)
                local h = r.bbox and (r.bbox.bottomY - r.bbox.topY) or 0
                t:truthy(string.format("%s: maior que o comum (%.0f > %.0f)",
                    name, h, maxRoadH), h > maxRoadH)
            end
        end)
    end
    EnemyRenderer.draw = realDraw
    EnemyRenderer.resetRun()

    -- a inversão pura da geometria: o pé cai EXATAMENTE no limite pedido
    local x, y, w, h = 0, 60, 1280, 660
    local rel = WorldRoad.battleRelFor(x, y, w, h, 430)
    local _, fy = WorldRoad.getRoadAnchor(rel, x, y, w, h)
    t:truthy(string.format("battleRelFor inverte getRoadAnchor (pé %d ~ 430)", fy),
        math.abs(fy - 430) <= 1)
    t:eq("limite folgado não traz o inimigo mais perto que rel 9",
        WorldRoad.battleRelFor(x, y, w, h, 5000), WorldRoad.BATTLE_REL_NEAR)
    t:near("tamanho no palco histórico é 1.0",
        WorldRoad.battleSizeK(WorldRoad.ENEMY_SIZE_REF_REL), 1, 1e-9)
    -- tela grande (Out/2026): o inimigo acompanha o mundo acima de 1080p;
    -- 4:3 e 1080p (área = altura − TopBar 52) ficam exatamente como eram
    t:eq("1024x768: escala de tela 1", WorldRoad.enemyScreenK(768 - 52), 1)
    t:eq("1920x1080: escala de tela 1", WorldRoad.enemyScreenK(1080 - 52), 1)
    local k1440 = WorldRoad.enemyScreenK(1440 - 52)
    t:truthy(string.format("2560x1440: inimigo cresce com o mundo (%.2f)", k1440),
        k1440 > 1.3 and k1440 <= 1.4)
    t:eq("teto 1.4 em telas enormes", WorldRoad.enemyScreenK(4000), 1.4)
    local gp = love.filesystem.read("src/scenes/GameplayScene.lua") or ""
    t:truthy("GameplayScene aplica enemyScreenK no inimigo da estrada",
        gp:find("WorldRoad.enemyScreenK(height - topBarHeight)", 1, true) ~= nil)

    return t:done()
end

return M
