-- tools/screenshot_rewards.lua
-- Valida a reforma do modo REWARDS da CardRewardScreen (Jul/2026): véu sobre
-- o mundo (sem interior de loja), pills fora das cartas, Seguir com texto
-- inteiro, botões Pegar/X largos, sem ouro no title bar.
--   love . screenshot_rewards → rewards_idle + rewards_selected + 3 de RESIZE
--
-- A tortura existe porque NASCER grande != CRESCER: capturar a tela já criada
-- no tamanho final não exercita o caminho "layout calculado num tamanho, janela
-- muda, layout reaproveitado" (memory/ui_layout_invariants.md).
local M = {}

local Game             = require("src.core.Game")
local CardRewardScreen = require("components.CardRewardScreen")
local CRTShader        = require("src.ui.CRTShader")
local DissolveShader   = require("src.ui.DissolveShader")
local ScreenShake      = require("src.systems.ScreenShake")
local EventManager     = require("engine.EventManager")
local FloatingText     = require("src.ui.FloatingText")
local CardParticles    = require("src.systems.CardParticles")
local I18n             = require("src.i18n.I18n")

function M.run()
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load(); DissolveShader.load(); ScreenShake.install()

    local game = Game:new()
    game:startNewRun("mage")
    game:startGame()
    _G.game = game

    local screen = CardRewardScreen:new(game.shopSystem)
    -- REPRO fiel ao jogo real: pré-seta lastScreenWidth/Height pra NÃO cair
    -- no branch de resize do update() (que recria as instâncias e mascarava
    -- o bug das cartas invisíveis).
    screen.lastScreenWidth = love.graphics.getWidth()
    screen.lastScreenHeight = love.graphics.getHeight()
    screen:show(game, function() end, function() end, "rewards")

    local stepDt = 1 / 60
    local function simulate(secs)
        local t = 0
        while t < secs do
            EventManager.update(stepDt)
            FloatingText.update(stepDt)
            ScreenShake.update(stepDt)
            CardParticles.update(stepDt)
            screen:update(stepDt)
            -- CRÍTICO (lição do bug y+=entryOy): o DRAW muta estado das cartas
            -- (Card:draw grava self.x/y). Sem desenhar por frame, o simulador
            -- NÃO reproduz feedback loops de draw — foi assim que o bug das
            -- cartas fora da tela passou batido duas vezes.
            love.graphics.clear(0, 0, 0, 1)
            screen:draw()
            t = t + stepDt
        end
    end
    simulate(1.2)

    -- Diagnóstico: estado real das instâncias após 1.2s
    for i, inst in ipairs(screen.cardInstances or {}) do
        print(("  inst[%d] dissolve=%.2f entryOy=%.1f x=%s y=%s scaleAnim=%s"):format(
            i, inst.dissolve or -1, inst._entryOy or -1,
            tostring(inst.x), tostring(inst.y),
            tostring(screen.cardAnimations[i] and screen.cardAnimations[i].scale)))
    end

    local function capture(name)
        CRTShader.setEnabled(true); CRTShader.setStrength(0.85); CRTShader.setPower(1)
        CRTShader.beginScene()
        -- simula o mundo vivo por trás (gameplay renderiza antes no jogo real)
        local sw, sh = love.graphics.getDimensions()
        love.graphics.setColor(0.16, 0.12, 0.08, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setColor(0.30, 0.22, 0.12, 1)
        love.graphics.rectangle("fill", 0, sh * 0.6, sw, sh * 0.4)
        screen:draw()
        CRTShader.endScene()
        love.graphics.captureScreenshot(function(id)
            id:encode("png", name)
            print("[rewards] " .. name .. " salvo")
        end)
        love.graphics.present()
    end

    capture("rewards_idle.png")

    -- Seleciona a 1ª oferta de carta → aparecem os botões Pegar/X novos.
    for _, offer in ipairs(screen.shopOffers) do
        if offer.type == "card" then
            screen:setSelectedOffer(offer, offer._slot)
            break
        end
    end
    simulate(0.3)
    capture("rewards_selected.png")

    -- ===================== TORTURA DE RESIZE =====================
    -- Roda SEMPRE (main.lua chama este tool sem argumentos). Mantém a carta
    -- SELECIONADA — é o estado com mais geometria derivada (botões Pegar/X
    -- ancorados na carta). NASCER grande != CRESCER: só capturar a tela já
    -- criada no tamanho final não exercita este caminho.
    local steps = {
        { 800, 600, "rewards_resize_1_pequena" },
        { 1920, 1080, "rewards_resize_2_cresceu" },
        { 1280, 720, "rewards_resize_3_medio" },
    }
    local failures = 0
    for _, st in ipairs(steps) do
        love.window.setMode(st[1], st[2], { resizable = true })
        require("src.ui.FontManager").clearCache()
        simulate(0.40)
        local bad = screen:validateLayout()
        print(("=== %dx%d (%s) — cartas %dx%d, %d violacao(oes)"):format(
            st[1], st[2], st[3], screen.cardWidth, screen.cardHeight, #bad))
        for _, msg in ipairs(bad) do
            failures = failures + 1
            print("    VIOLACAO: " .. msg)
        end
        if screen.skipButton then
            print(("    botao %q x=%d y=%d w=%d"):format(screen.skipButton.text,
                screen.skipButton.x, screen.skipButton.y, screen.skipButton.width))
        end
        for bi, b in ipairs(screen._selectionButtons or {}) do
            print(("    escolha[%d] x=%d y=%d w=%d"):format(bi, b.x, b.y, b.width))
        end
        capture(st[3] .. ".png")
    end
    print(failures == 0 and "=== RESIZE OK: nenhuma violacao ==="
        or ("=== RESIZE FALHOU: " .. failures .. " violacao(oes) ==="))

    love.event.quit()
end

return M
