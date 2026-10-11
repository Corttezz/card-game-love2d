-- tools/shot_boss_aura.lua
-- Prancha dos CHEFES vivos: cada sala com o chefe dela, pelo caminho real de
-- desenho (GameplayScene.draw), em 4 instantes seguidos — prova que o idle
-- assado mexe, que a aura (src/data/boss_auras.lua) aparece e em que
-- profundidade. Sem janela própria: desenha num Canvas e salva.
--
--   love . test_one shot_boss_aura [ato|all][:hurt|:death]
--   (ex.: `1:death` — o test_one só repassa UM argumento)
--
-- Saída no save dir: boss_aura_<ato>.png (4 recortes lado a lado) e
-- boss_full_<ato>.png (tela inteira do 1º instante).

local M = {}

local function mountAndShoot(act, mode)
    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = 8
    run.currentNode = { type = "boss" }
    game.messageSystem = nil
    game.enemy.spriteId = EnemyRenderer.resolveSpriteId(act, "boss")
    game.enemy.isBoss = true
    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()

    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    local w, h = love.graphics.getDimensions()
    GameplayScene.init({
        game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(w * 0.80, h * 0.80, 150, 46, "Jogar"),
    })
    GameplayScene._debugForceBossEntered()
    WorldRoad.setBiome(act)
    WorldRoad.setTimeOfDay(1, true)

    local canvas = love.graphics.newCanvas(w, h)
    local function step(secs)
        local n = math.floor(secs * 30 + 0.5)
        for _ = 1, n do
            love.timer.step()
            WorldRoad.update(1 / 30)
            EnemyRenderer.update(1 / 30)
            pcall(function() require("src.ui.InteriorFX").update(1 / 30, act) end)
        end
    end
    local function render()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
        return canvas:newImageData()
    end

    -- assenta: aura cheia de partículas e idle no meio do ciclo. Um draw
    -- ANTES: é o draw que diz ao EnemyRenderer quem é o chefe da aura.
    render()
    step(3.0)
    if mode == "hurt" then EnemyRenderer.triggerHurt() end
    if mode == "death" then
        game.enemy.health = 0
        EnemyRenderer.triggerDeath(game.enemy.spriteId)
    end
    local shots = {}
    for i = 1, 4 do
        shots[i] = render()
        step((mode == "death") and 0.25 or 0.33)
    end
    shots[1]:encode("png", "boss_full_" .. act .. ".png")

    -- recorte em volta do chefe (centro horizontal, faixa do palco)
    local cw, ch = math.floor(w * 0.46), math.floor(h * 0.62)
    local x0 = math.floor((w - cw) / 2)
    local y0 = math.floor(h * 0.16)
    local strip = love.image.newImageData(cw * 4 + 12, ch)
    for i, img in ipairs(shots) do
        strip:paste(img, (i - 1) * (cw + 4), 0, x0, y0, cw, ch)
    end
    strip:encode("png", "boss_aura_" .. act .. (mode and ("_" .. mode) or "") .. ".png")
    print(string.format("[shot_boss_aura] ato %d %s ok", act, tostring(game.enemy.spriteId)))
end

function M.run(which, mode)
    if which and which:find(":") then
        which, mode = which:match("^([^:]*):(.*)$")
    end
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local acts = {}
    if not which or which == "all" then
        acts = { 1, 2, 3, 4, 5, 6 }
    else
        acts = { tonumber(which) or 1 }
    end
    for _, a in ipairs(acts) do
        local ok, err = pcall(mountAndShoot, a, mode)
        if not ok then
            print("[shot_boss_aura] ERRO ato " .. a .. ": " .. tostring(err))
            return false
        end
    end
    return true
end

return M
