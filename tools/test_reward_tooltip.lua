-- tools/test_reward_tooltip.lua
-- Trava do tooltip da carta nos ESPÓLIOS (dono, 13/Out/2026: "não pode ficar
-- o tooltip assim" — o painel subia por cima da barra superior e o nome da
-- carta ficava escondido atrás dela).
--
-- O que garante, em 4 tamanhos de janela (janela falsificada, UiScale=1):
--   • hover numa carta de espólio abre o tooltip canônico (CardInfoDisplay)
--     no passe final da tela, AO LADO da carta;
--   • o painel nunca sobe acima da barra superior (TopBar.height + 6);
--   • o painel não cobre a carta em hover e fica inteiro dentro da janela;
--   • só UM tooltip por quadro (o da carta em hover);
--   • com uma oferta SELECIONADA o tooltip some e a pendência não atravessa
--     quadros.
--
--   love . test_one test_reward_tooltip

local TK = require("tools.testkit")
local FontManager = require("src.ui.FontManager")

local M = {}

local SIZES = { { 1024, 768 }, { 1280, 720 }, { 1366, 768 }, { 1920, 1080 } }

local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local realMouse = love.mouse.getPosition
local fakeW, fakeH, mx, my
local function installFake()
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
    love.mouse.getPosition = function() return mx or 1, my or 1 end
end
local function restore()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    love.mouse.getPosition = realMouse
end

local function overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function M.run()
    TK.bootstrap()
    local t = TK.new("test_reward_tooltip")
    local CardRewardScreen = require("components.CardRewardScreen")
    local topH = (_G.topBar and _G.topBar.height) or 52

    installFake()
    local wasPaused = _G.EventManager.paused
    _G.EventManager.paused = false
    local okRun, err = pcall(function()
        for _, sz in ipairs(SIZES) do
            fakeW, fakeH = sz[1], sz[2]
            mx, my = 1, 1
            FontManager.clearCache()
            local tag = ("%dx%d"):format(sz[1], sz[2])

            local game = TK.newRunGame("warrior")
            local screen = CardRewardScreen:new(game.shopSystem)
            screen.lastScreenWidth, screen.lastScreenHeight = fakeW, fakeH
            screen:show(game, function() end, function() end, "rewards")

            local canvas = love.graphics.newCanvas(fakeW, fakeH)
            local function frame()
                love.graphics.setCanvas(canvas)
                local okF, errF = pcall(function()
                    _G.EventManager.update(1 / 60)
                    screen:update(1 / 60)
                    screen:draw()
                end)
                love.graphics.setCanvas()
                if not okF then error(errF, 0) end
            end
            for _ = 1, 90 do frame() end   -- entrada das cartas (1,5 s)

            local insts = {}
            for _, inst in ipairs(screen.cardInstances or {}) do insts[#insts + 1] = inst end
            t:truthy(tag .. ": há cartas de espólio", #insts >= 2)

            -- espião: quantos tooltips cada quadro desenha (qualquer
            -- CardInfoDisplay — o da tela ou o da instância)
            local CardInfoDisplay = require("src.ui.CardInfoDisplay")
            local drawn = 0
            local realDraw = CardInfoDisplay.draw
            CardInfoDisplay.draw = function(...)
                drawn = drawn + 1
                return realDraw(...)
            end
            local function unspy() CardInfoDisplay.draw = realDraw end

            for i, inst in ipairs(insts) do
                local r = inst._drawRect
                t:truthy(tag .. ": carta " .. i .. " tem retângulo desenhado", r ~= nil)
                if r then
                    mx, my = r.x + r.w / 2, r.y + r.h * 0.6
                    for _ = 1, 10 do frame() end
                    drawn = 0
                    frame()
                    t:truthy(tag .. ": carta " .. i .. " em hover", inst.isHovered)
                    t:eq(tag .. ": carta " .. i .. ": UM tooltip no quadro", drawn, 1)
                    local tip = inst.cardInfoDisplay and inst.cardInfoDisplay.lastRect
                    t:truthy(tag .. ": carta " .. i .. ": tooltip medido (lastRect)", tip ~= nil)
                    if tip then
                        local card = inst._drawRect
                        t:check(("%s: carta %d: tooltip abaixo da barra superior (y=%d ≥ %d)")
                            :format(tag, i, tip.y, topH), tip.y >= topH)
                        t:check(("%s: carta %d: tooltip dentro da janela (y+h=%d ≤ %d)")
                            :format(tag, i, tip.y + tip.h, fakeH), tip.y + tip.h <= fakeH)
                        t:check(("%s: carta %d: tooltip dentro da janela (x=%d, x+w=%d)")
                            :format(tag, i, tip.x, tip.x + tip.w), tip.x >= 0 and tip.x + tip.w <= fakeW)
                        t:falsy(("%s: carta %d: tooltip não cobre a própria carta"):format(tag, i),
                            overlaps(tip, card))
                    end
                end
            end

            -- seleção ativa: tooltip some e nada fica pendente
            local first = insts[1]
            if first and first.shopOffer and first._drawRect then
                screen:setSelectedOffer(first.shopOffer, first.shopOffer._slot)
                local r = first._drawRect
                mx, my = r.x + r.w / 2, r.y + r.h * 0.6
                for _ = 1, 5 do frame() end
                drawn = 0
                frame()
                t:eq(tag .. ": com seleção ativa nenhum tooltip é desenhado", drawn, 0)
            end
            unspy()
            canvas:release()
        end
    end)
    _G.EventManager.paused = wasPaused
    restore()
    FontManager.clearCache()
    if not okRun then error(err, 0) end
    return t:done()
end

return M
