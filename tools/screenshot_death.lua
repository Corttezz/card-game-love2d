-- tools/screenshot_death.lua
-- Captura 4 momentos da animação de morte pra validar VISUALMENTE que ela
-- acontece na tela.
--
-- Dois modos, e o segundo é o que importa (Set/2026):
--   love . screenshot_death        -> dispara triggerDeath NA MÃO. Valida o
--                                     CLIPE (o monstro cai?), não o pipeline.
--   love . screenshot_death orb    -> mata pelo PIPELINE DE VERDADE, com um
--                                     pulso de orbe no fim do turno. Era essa
--                                     a fonte que zerava a vida sem encenar
--                                     morte nenhuma; aqui ninguém chama
--                                     triggerDeath, o jogo é que tem que
--                                     chamar. Se a correção sumir, as capturas
--                                     mostram o monstro EM PÉ.

local M = {}

local Game = require("src.core.Game")
local CRTShader = require("src.ui.CRTShader")
local SceneLayer = require("src.ui.SceneLayer")
local EnemyRenderer = require("src.ui.EnemyRenderer")

function M.run(mode)
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load()

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    _G.topBar = TopBar:new()
    _G.topBar:setGame(game)
    _G.gameUI = GameUI:new()

    local SmokeSystem = require("src.systems.SmokeSystem")
    local SmokeConfig = require("src.config.SmokeConfig")
    _G.smokeSystem = SmokeSystem:new()
    SmokeConfig.applyToSystem(_G.smokeSystem, "act1")

    -- Avança 1s pra entrar em regime
    SceneLayer._currentAct = 1
    for _ = 1, 30 do
        SceneLayer.update(1/30)
        EnemyRenderer.update(1/30)
        _G.smokeSystem:update(1/30)
    end

    local byPipeline = (mode == "orb")
    if byPipeline then
        -- MATA DE VERDADE: orbe de raio pulsando no fim do turno do jogador.
        -- Ninguém aqui chama triggerDeath — quem tem que chamar é o jogo.
        print("[death-screenshot] matando pelo PIPELINE (pulso de orbe)")
        game.player.orbs = {}
        game.player:addOrb({ type = "lightning", value = 99 })
        game.enemy.health = 5
        game:endTurn()
        -- Drena a fila de beats até a morte ser encenada (ou desistir).
        local waited = 0
        while waited < 3.0 and not game._deathHandled do
            _G.EventManager.update(1 / 60)
            EnemyRenderer.update(1 / 60)
            waited = waited + 1 / 60
        end
        print("[death-screenshot] _deathHandled=" .. tostring(game._deathHandled)
            .. " clip=" .. tostring(EnemyRenderer.debugState().animName)
            .. " (vida do inimigo: " .. tostring(game.enemy.health) .. ")")
    else
        -- Dispara death. health=0 é OBRIGATÓRIO: com inimigo "vivo" o draw
        -- interpreta death terminada como próxima batalha e volta pro idle
        -- (o 4º frame capturava o monstro ressuscitado em pé).
        print("[death-screenshot] disparando triggerDeath na mao")
        game.enemy.health = 0
        EnemyRenderer.triggerDeath(game.enemy.spriteId)
    end

    -- Captura SEQUENCIAL (padrão screenshot_crt — o encadeamento de
    -- callbacks aninhados só entregava o 1º frame): 4 momentos cobrindo
    -- início, meio, fim do clip e a pose final congelada ("cadáver").
    local frameTime = 1/30
    local moments = { 0.05, 0.30, 0.65, 1.05 }
    local prefix = byPipeline and "death_orb_" or "death_"
    local outFiles = { prefix .. "early.png", prefix .. "mid.png",
                       prefix .. "late.png", prefix .. "corpse.png" }

    local function renderFrame()
        local width, height = love.graphics.getDimensions()
        local topBarHeight = _G.topBar.height or 80
        love.graphics.clear(0, 0, 0, 1)
        SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, 1)
        _G.topBar:draw()
        local cx = math.floor(width / 2)
        local cy = math.floor(height * 0.74)
        EnemyRenderer.draw(game, cx, cy)
        _G.gameUI:draw(game)
        _G.smokeSystem:draw()
    end

    local totalElapsed = 0
    for i, target in ipairs(moments) do
        while totalElapsed < target do
            EnemyRenderer.update(frameTime)
            SceneLayer.update(frameTime)
            totalElapsed = totalElapsed + frameTime
        end
        renderFrame()
        local outName = outFiles[i]
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", outName)
            print("[death-screenshot] " .. outName .. " salvo (t=" .. target .. "s)")
        end)
        love.graphics.present()
    end
    print("[death-screenshot] OK - " .. #moments .. " frames capturados")
    love.event.quit()
end

return M
