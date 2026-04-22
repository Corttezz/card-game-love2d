-- tools/screenshot_gameplay.lua
-- Captura screenshot de uma batalha do ato 1 (warrior floor 1) pra análise
-- visual. Roda via: love . screenshot_gameplay
-- Saída: /tmp/card-game-screenshot.png

local M = {}

local Game = require("src.core.Game")
local CRTShader = require("src.ui.CRTShader")

function M.run()
    -- Setup minimo pra renderizar drawGame
    local I18n = require("src.i18n.I18n")
    I18n.init()

    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load()

    -- Cria um game em estado "playing" com warrior no ato 1
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()

    -- Exporta globalmente pro main.lua:drawGame() conseguir acessar
    _G.game = game

    -- Inicializa components mínimos que drawGame usa
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    _G.topBar = TopBar:new()
    _G.topBar:setGame(game)
    _G.gameUI = GameUI:new()

    -- Força a SceneLayer, SmokeSystem atualizem algumas iterações
    local SceneLayer = require("src.ui.SceneLayer")
    local SmokeSystem = require("src.systems.SmokeSystem")
    local SmokeConfig = require("src.config.SmokeConfig")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local ParticleSystem = require("src.systems.ParticleSystem")

    _G.smokeSystem = SmokeSystem:new()
    SmokeConfig.applyToSystem(_G.smokeSystem, "act1")

    -- Avança ~2s de simulação pra anims idle entrarem em regime + partículas
    -- spawn + smoke denser
    local simDt = 1 / 30
    for _ = 1, 60 do
        SceneLayer.update(simDt)
        EnemyRenderer.update(simDt)
        _G.smokeSystem:update(simDt)
        if ParticleSystem.Manager then ParticleSystem.Manager:update(simDt) end
    end

    -- DEBUG
    SceneLayer._debugLog = true
    SceneLayer._currentAct = 1
    local stats = _G.smokeSystem:getStats()
    print(string.format("[debug] smoke active=%d", stats.activeParticles))
    -- Tick extra 30 frames com debug log
    for _ = 1, 30 do SceneLayer.update(simDt) end
    print(string.format("[debug] fire embers ativos: %d", SceneLayer.getFireEmberCount()))
    SceneLayer._debugLog = false

    -- Render frame: chama drawGame diretamente
    love.graphics.clear(0, 0, 0, 1)

    -- Não podemos chamar main.drawGame() direto pq é local. Vamos replicar
    -- o essencial inline:
    local width, height = love.graphics.getDimensions()
    local topBarHeight = _G.topBar.height or 80

    -- SceneLayer (cenário)
    SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, 1)

    -- TopBar
    _G.topBar:draw()

    -- Enemy sprite (cy=0.74 pousa pés no piso da scene, não flutua no arco)
    local cx = math.floor(width / 2)
    local cy = math.floor(height * 0.74)
    EnemyRenderer.draw(game, cx, cy)

    -- GameUI (HUD)
    _G.gameUI:draw(game)

    -- Smoke
    _G.smokeSystem:draw()

    -- Particles
    if ParticleSystem.Manager then ParticleSystem.Manager:draw() end

    -- Captura
    love.graphics.captureScreenshot(function(imageData)
        local path = "gameplay_screenshot.png"
        imageData:encode("png", path)
        -- imageData:encode salva no save dir (~/.local/share/love/card-game/)
        print("[screenshot] salvo em save-dir: " .. path)
        love.event.quit()
    end)

    -- Renderiza o frame pra captura pegar
    love.graphics.present()
end

return M
