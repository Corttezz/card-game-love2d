-- tools/boss_rooms.lua
-- Galeria INTERATIVA das salas de chefe: cada ato com o chefe dele dentro,
-- pelo caminho real de desenho (GameplayScene.draw), já depois da cerimônia
-- da porta. Mesma montagem do screenshot_enemy_scene, mas ao vivo.
--
--   love . boss_rooms [ato|shots]
--   BOSS_ROOMS_SIZE=1920x1080 love . boss_rooms shots   (tamanho da janela:
--   o cover-fit corta a arte diferente em 4:3 e em 16:9 — confira os dois)
--   BOSS_ROOMS_VIRTUAL=2560x1440 ... shots  (tela maior que o monitor)
--   BOSS_ROOMS_SEQ=6 ... shots   (+6 quadros seguidos por sala: animação)
--
--   1-6 / ← →  troca de ato (sala + chefe)
--   H          animação de dano     K  animação de morte (J reaparece)
--   ESC        sai

local M = {}

function M.run(startAct)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local InteriorFX = require("src.ui.InteriorFX")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local Config = require("src.core.Config")
    local FontManager = require("src.ui.FontManager")

    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")

    -- UM setMode só, antes de montar (setMode repetido dentro de tool trava)
    local sw, sh = (os.getenv("BOSS_ROOMS_SIZE") or ""):match("^(%d+)x(%d+)$")
    if sw then love.window.setMode(tonumber(sw), tonumber(sh)) end

    -- BOSS_ROOMS_VIRTUAL=2560x1440: tela FALSIFICADA maior que o monitor
    -- (setMode acima do desktop trava). Desenha num canvas desse tamanho com
    -- getWidth/getHeight mentindo e a captura sai do canvas.
    local vw, vh = (os.getenv("BOSS_ROOMS_VIRTUAL") or ""):match("^(%d+)x(%d+)$")
    local vcanvas, pendingCap
    if vw then
        vw, vh = tonumber(vw), tonumber(vh)
        vcanvas = love.graphics.newCanvas(vw, vh)
        vcanvas:setFilter("nearest", "nearest")
        love.graphics.getWidth = function() return vw end
        love.graphics.getHeight = function() return vh end
        love.graphics.getDimensions = function() return vw, vh end
        love.graphics.captureScreenshot = function(cb) pendingCap = cb end
    end

    local total = Config.TotalActs or 6
    local shots = (startAct == "shots")   -- verificação: captura os 6 e sai
    local act = math.max(1, math.min(total, tonumber(startAct) or 1))
    local frames = 0
    local pendingKey = nil
    local seqN = tonumber(os.getenv("BOSS_ROOMS_SEQ") or "") or 0
    local seqLeft = 0

    local function mount(a)
        act = a
        -- Linha do tempo NOVA pra cada sala. A fila de eventos é global e
        -- sobrevive ao Game antigo: trocar de ato antes da mão terminar de
        -- materializar (ou depois de H/K) deixava eventos órfãos da sala
        -- anterior na frente, e as cartas da mão nova nasciam invisíveis
        -- (dissolve=1) — "a mão só aparece no ato 1".
        _G.EventManager.clear()
        require("src.ui.InteriorDepth").reset()
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        local run = game.runManager.currentRun
        run.actNumber = a
        run.floorInAct = 8
        run.currentNode = { type = "boss" }
        -- vida/dano reais do chefe do ato (o startGame montou um inimigo comum)
        local stats = require("src.systems.ActSystem").getEnemyStats(a, 8, "boss")
        game.enemy = require("src.entities.Enemy"):new(stats.health, stats.damage)
        if game.enemy.rollNextIntent then pcall(game.enemy.rollNextIntent, game.enemy) end
        game.messageSystem = nil   -- sem os toasts de início de run por cima da sala
        game.enemy.spriteId = EnemyRenderer.resolveSpriteId(a, "boss")
        game.enemy.isBoss = true
        EnemyRenderer.clearCache()

        _G.game = game
        local topBar = TopBar:new()
        topBar:setGame(game)
        local w, h = love.graphics.getDimensions()
        GameplayScene.init({
            game = game, topBar = topBar, gameUI = GameUI:new(),
            playButton = Button:new(w * 0.80, h * 0.80, 150, 46, "Jogar"),
        })
        GameplayScene.setGame(game)   -- zera cinemática/turno da sala anterior
        GameplayScene._debugForceBossEntered()
        WorldRoad.setBiome(a)
        WorldRoad.setTimeOfDay(1, true)
        print(string.format("[boss_rooms] ato %d  chefe=%s", a,
            tostring(game.enemy.spriteId)))
    end

    require("src.systems.ScreenShake").install()
    mount(act)

    love.update = function(dt)
        dt = math.min(dt, 1 / 20)
        if pendingKey then
            local k = pendingKey
            pendingKey = nil
            love.keypressed(k)
            frames = 0
        end
        if _G.EventManager.update then _G.EventManager.update(dt) end
        -- cinemática do chefe (I = entrada, K = morte): relógio dela ANTES do
        -- EnemyRenderer (câmera lenta = escala do dt dele)
        require("src.ui.BossCinematic").update(dt, _G.game, { inHall = true })
        require("src.systems.ScreenShake").update(dt)
        WorldRoad.update(dt)
        EnemyRenderer.update(dt)
        InteriorFX.update(dt, InteriorFX.hallFor(act))
        if _G.game and _G.game.update then pcall(_G.game.update, _G.game, dt) end
        frames = frames + 1
    end

    local drawFrame
    love.draw = function()
        if not vcanvas then return drawFrame() end
        love.graphics.setCanvas(vcanvas)
        drawFrame()
        love.graphics.setCanvas()
        if pendingCap then
            local cb = pendingCap
            pendingCap = nil
            cb(vcanvas:newImageData())
        end
        love.graphics.setColor(1, 1, 1, 1)
        local ww, wh = love.window.getMode()
        local k = math.min(ww / vw, wh / vh)
        love.graphics.draw(vcanvas, 0, 0, 0, k, k)
    end
    drawFrame = function()
        love.graphics.clear(0, 0, 0, 1)
        local Shake = require("src.systems.ScreenShake")
        Shake.push()
        GameplayScene.draw()
        Shake.pop()
        local label = string.format("ATO %d/%d  %s   |  1-6 / <- -> troca  I entrada  K morte  ENTER pula  H dano  J volta  ESC sai",
            act, total, tostring(_G.game and _G.game.enemy and _G.game.enemy.spriteId))
        local font = FontManager.getFont(10)
        love.graphics.setFont(font)
        local y = love.graphics.getHeight() - font:getHeight() - 8
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, y - 6, font:getWidth(label) + 24, font:getHeight() + 12)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(label, 12, y)
        -- BOSS_ROOMS_SEQ=n: além do quadro principal, n quadros seguidos
        -- (a cada 4 frames) pra conferir animação — boss_room_<ato>_<k>.png
        if shots and seqLeft > 0 and frames >= 4 then
            frames = -1e9
            local a, k = act, seqN - seqLeft + 1
            love.graphics.captureScreenshot(function(img)
                img:encode("png", ("boss_room_%d_%d.png"):format(a, k))
                seqLeft = seqLeft - 1
                if seqLeft > 0 then frames = 0
                elseif a >= total then love.event.quit() else pendingKey = tostring(a + 1) end
            end)
        elseif shots and seqLeft == 0 and frames >= 120 then
            frames = -1e9
            local a = act
            love.graphics.captureScreenshot(function(img)
                img:encode("png", "boss_room_" .. a .. ".png")
                print("[boss_rooms] salvo boss_room_" .. a .. ".png")
                if seqN > 0 then seqLeft = seqN; frames = 0; return end
                -- troca pelo MESMO caminho da tecla (é ele que o dono usa)
                if a >= total then love.event.quit() else pendingKey = tostring(a + 1) end
            end)
        end
    end

    love.keypressed = function(key)
        local n = tonumber(key)
        if key == "escape" then
            love.event.quit()
        elseif n and n >= 1 and n <= total then
            mount(n)
        elseif key == "right" or key == "d" then
            mount(act % total + 1)
        elseif key == "left" or key == "a" then
            mount((act - 2) % total + 1)
        elseif key == "h" then
            EnemyRenderer.triggerHurt()
        elseif key == "i" then
            -- ENTRADA do chefe a partir do salão VAZIO (sala remontada)
            mount(act)
            GameplayScene._debugStartBossIntro()
        elseif key == "k" then
            -- MORTE pelo pipeline real (beat enemy.death → _onEnemyDeath →
            -- clip + cinemática de morte no salão)
            local g = _G.game
            if g.enemy:isAlive() then
                g.enemy.armor = 0
                g.enemy:takeDamage(g.enemy.health + 1)
                g:settleEnemyDamage(nil)
            end
        elseif key == "return" or key == "space" then
            require("src.ui.BossCinematic").skip()
        elseif key == "j" then
            mount(act)
        end
    end
    love.mousepressed = function() end
    love.mousereleased = function() end
    love.mousemoved = function() end
    love.resize = function() end
end

return M
