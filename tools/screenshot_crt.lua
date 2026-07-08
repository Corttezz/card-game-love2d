-- tools/screenshot_crt.lua
-- Valida a identidade CRT v2: renderiza o MENU dentro do tubo com power
-- em 4 estágios (linha quente, abertura, assentando, ligado) + strength
-- cheio. As demais capturas do projeto continuam SEM CRT (doutrina).
--   love . screenshot_crt

local M = {}

function M.run()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load()
    CRTShader.setEnabled(true)
    CRTShader.setStrength(0.85)

    local Menu = require("components.Menu")
    local menu = Menu:new()
    for _ = 1, 60 do menu:update(1 / 30) end

    -- v3.6: as DUAS coreografias — ligar (ponto → linha → abre → rolo de
    -- sync → assenta) e desligar (colapso → linha → ponto de fósforo).
    local stages = {
        { 0.06, 1,  "crt_on_dot.png" },      -- ponto azulado do canhão
        { 0.20, 1,  "crt_on_line.png" },     -- linha quente crescendo
        { 0.45, 1,  "crt_on_opening.png" },  -- abrindo (lavado + estática)
        { 0.70, 1,  "crt_on_roll.png" },     -- v-hold rolando + blanking
        { 0.86, 1,  "crt_on_settle.png" },   -- cores assentando
        { 1.00, 1,  "crt_on.png" },          -- ligado estável
        { 0.80, -1, "crt_off_collapse.png" },-- colapso vertical + surto
        { 0.45, -1, "crt_off_line.png" },    -- linha encolhendo
        { 0.15, -1, "crt_off_dot.png" },     -- ponto laranja apagando
    }

    -- REVISÃO DE TELAS: HUD de batalha (mana canto inf-dir, vida inf-esq,
    -- TopBar) através do tubo — nada pode ser escondido pela máscara.
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game
    game.player.health = 48
    game.player.armor = 7
    local TopBar = require("components.TopBar")
    local topBar = TopBar:new()
    topBar:setGame(game)
    local HudManager = require("src.ui.HudManager")
    local hud = HudManager:new()
    hud:update(1 / 30, game)

    CRTShader.setPower(1)
    CRTShader.beginScene()
    love.graphics.clear(0.12, 0.09, 0.07, 1)
    topBar:draw()
    hud:draw(game)
    local HintBar = require("src.ui.HintBar")
    HintBar.draw("Canto a canto: nada pode sumir atras da mascara")
    CRTShader.endScene()
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "crt_hud_review.png")
        print("[crt] crt_hud_review.png salvo")
    end)
    love.graphics.present()

    for _, st in ipairs(stages) do
        local p, dir, name = st[1], st[2], st[3]
        CRTShader.setPower(p, dir)
        CRTShader.beginScene()
        love.graphics.clear(0, 0, 0, 1)
        menu:draw()
        CRTShader.endScene()
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", name)
            print(string.format("[crt] %s salvo (power=%.2f dir=%d)",
                name, p, dir))
        end)
        love.graphics.present()
    end
    love.event.quit()
end

return M
