-- tools/screenshot_packopen.lua
-- Captura UM screenshot da tela de pack opening em momento específico.
-- Roda: love . screenshot_packopen [phase]
-- phase: 0..4 (default 4 = idle ready). Tempos: 0=0.4s, 1=0.9s, 2=1.6s, 3=2.4s, 4=3.5s
-- Saída: ~/.local/share/love/card-game/packopen_<phase>.png

local M = {}

local Game             = require("src.core.Game")
local CRTShader        = require("src.ui.CRTShader")
local DissolveShader   = require("src.ui.DissolveShader")
local FlashShader      = require("src.ui.FlashShader")
local BoosterShader    = require("src.ui.BoosterShader")
local FoilShader       = require("src.ui.FoilShader")
local PolychromeShader = require("src.ui.PolychromeShader")
local NegativeShader   = require("src.ui.NegativeShader")
local ScreenShake      = require("src.systems.ScreenShake")
local EventManager     = require("engine.EventManager")
local FloatingText     = require("src.ui.FloatingText")
local CardParticles    = require("src.systems.CardParticles")
local PackOpenScreen   = require("components.PackOpenScreen")
local BoosterPackSystem = require("src.systems.BoosterPackSystem")
local I18n             = require("src.i18n.I18n")

local PHASE_TIMES = { [0]=0.4, [1]=0.9, [2]=1.6, [3]=2.4, [4]=3.5 }

function M.run(phase)
    phase = tonumber(phase or 4) or 4
    local targetT = PHASE_TIMES[phase] or 3.5

    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load()
    DissolveShader.load()
    FlashShader.load()
    BoosterShader.load()
    FoilShader.load()
    PolychromeShader.load()
    NegativeShader.load()
    ScreenShake.install()

    local game = Game:new()
    game:startNewRun("warrior")
    _G.game = game

    local pack = BoosterPackSystem.expandPackRecord({
        id = "pack_standard", kind = "Standard",
        size = 3, choose = 1,
    }, "warrior")

    -- Forçando edition pra screenshot mostrar shader.
    if pack.instances[1] then pack.instances[1].edition = "foil" end
    if pack.instances[2] then pack.instances[2].edition = "holo"; pack.instances[2].seal = "Red" end
    if pack.instances[3] then pack.instances[3].edition = "polychrome"; pack.instances[3].seal = "Gold" end

    local packScreen = PackOpenScreen:new()
    packScreen:show(pack, function(_) end)

    -- Avança simulação até o tempo alvo.
    local stepDt = 1/60
    local elapsed = 0
    while elapsed < targetT do
        EventManager.update(stepDt)
        FloatingText.update(stepDt)
        FlashShader.update(stepDt)
        ScreenShake.update(stepDt)
        CardParticles.update(stepDt)
        packScreen:update(stepDt)
        elapsed = elapsed + stepDt
    end

    -- Render frame.
    love.graphics.clear(0.05, 0.04, 0.08, 1)

    -- Backdrop sépia (simula loja por trás).
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0.20, 0.16, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1, 1)

    packScreen:draw()
    CardParticles.draw()
    FloatingText.draw()
    FlashShader.draw()

    love.graphics.captureScreenshot(function(imageData)
        local path = string.format("packopen_phase_%d_t%.1f.png", phase, targetT)
        imageData:encode("png", path)
        print("[screenshot_packopen] " .. path)
        love.event.quit()
    end)
    love.graphics.present()
end

return M
