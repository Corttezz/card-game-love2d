-- tools/screenshot_shop.lua
-- Captura screenshots da CardRewardScreen em modo "shop" pra validação visual.
--
--   love . screenshot_shop        → CONTACT SHEET, 5 PNGs num run só:
--       shop_1_repouso.png        sem hover (painel em pré-foco)
--       shop_2_hover_carta.png    mouse sobre uma CARTA do grid
--       shop_3_hover_pack.png     mouse sobre um BOOSTER PACK
--       shop_4_selecionada.png    oferta selecionada (botões no rodapé do painel)
--       shop_5_comprada.png       pós-compra (slot VENDIDO + carta voando)
--
--   love . screenshot_shop <n>    → fase única, pra iterar rápido
--
-- Saída: save dir do LÖVE (~/AppData/Roaming/LOVE/card-game/ no Windows).

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
local CardRewardScreen = require("components.CardRewardScreen")
local I18n             = require("src.i18n.I18n")

-- phase 2 = compra a 1ª carta e captura 0.25s depois (valida F2: slot VENDIDO,
--           carta voando pro deck, popup -$N, demais cartas paradas no lugar).
-- phase 3 = SPLIT-VIEW com HOVER no grid (mouse sobre a 2ª carta): valida o
--           painel de detalhe fixo populado + lift/scale da carta + marcadores
--           de raridade/afinidade na faixa de rótulos.
-- phase 4 = SPLIT-VIEW com oferta SELECIONADA: valida o halo no slot e os
--           botões Comprar/Cancelar ancorados no RODAPÉ do painel de detalhe.
local PHASE_TIMES = { [0] = 0.20, [1] = 1.20, [2] = 1.20, [3] = 1.20, [4] = 1.20 }

function M.run(phase)
    -- SEM argumento = contact sheet (todos os frames num run só).
    -- "resize" = tortura de redimensionamento (ver bloco no fim).
    local resizeRun = (phase == "resize")
    phase = not resizeRun and tonumber(phase) or nil
    local targetT = (phase and PHASE_TIMES[phase]) or 1.20

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
    game:startGame()
    -- Dá uns 30 ouro pra aparecer "afford" verde nos preços.
    if game.economySystem then
        game.economySystem.currentGold = 30
    end
    _G.game = game

    local screen = CardRewardScreen:new(game.shopSystem)
    screen:show(game,
        function(_) end,
        function() end,
        "shop"  -- modo shop (4 cards + 1 voucher + 2 packs)
    )

    -- Debug: dump positions e sizes pra validar layout aplicado.
    print("=== Layout debug ===")
    print(("mode=%s slotCount=%s cardW=%s cardH=%s"):format(tostring(screen.mode), tostring(screen.slotCount), tostring(screen.cardWidth), tostring(screen.cardHeight)))
    print(("buttonsColX=%s buttonsColY=%s"):format(tostring(screen.buttonsColX), tostring(screen.buttonsColY)))
    print(("skipButtonX=%s skipButtonY=%s"):format(tostring(screen.skipButtonX), tostring(screen.skipButtonY)))
    if screen.refreshButton then
        print(("refreshButton x=%s y=%s w=%s h=%s"):format(tostring(screen.refreshButton.x), tostring(screen.refreshButton.y), tostring(screen.refreshButton.width), tostring(screen.refreshButton.height)))
    end
    for i, p in ipairs(screen.cardPositions or {}) do
        print(("  pos[%d] x=%d y=%d row=%s kind=%s w=%s"):format(i, p.x, p.y, tostring(p.row), tostring(p.kind), tostring(p.w)))
    end
    for i, o in ipairs(screen.shopOffers or {}) do
        print(("  offer[%d] type=%s name=%s cost=%s"):format(i, o.type, o.name, tostring(o.cost)))
    end

    -- Avança simulação (slide-in + materialize cascade dos cards).
    local stepDt = 1/60
    local function simulate(secs)
        local elapsed = 0
        while elapsed < secs do
            EventManager.update(stepDt)
            FloatingText.update(stepDt)
            FlashShader.update(stepDt)
            ScreenShake.update(stepDt)
            CardParticles.update(stepDt)
            screen:update(stepDt)
            elapsed = elapsed + stepDt
        end
    end
    -- ===================== CAPTURA =====================
    local function snap(name, quitAfter)
        love.graphics.clear(0.05, 0.04, 0.08, 1)
        -- Backdrop sépia (simula gameplay por trás).
        local sw, sh = love.graphics.getDimensions()
        love.graphics.setColor(0.18, 0.13, 0.09, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setColor(1, 1, 1, 1)

        screen:draw()
        CardParticles.draw()
        FloatingText.draw()
        FlashShader.draw()

        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", name)
            print("[screenshot_shop] " .. name)
            if quitAfter then love.event.quit() end
        end)
        love.graphics.present()
    end

    -- Zoom 2× numa região da tela — pra INSPECIONAR detalhe fino (moldura da
    -- carta expandida, entrelinha de texto pequeno) sem depender de abrir a
    -- imagem num editor. Renderiza a cena num canvas e reamostra o recorte.
    local function snapZoom(name, rect, zoom, quitAfter)
        zoom = zoom or 2
        local sw, sh = love.graphics.getDimensions()
        local canvas = love.graphics.newCanvas(sw, sh)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0.18, 0.13, 0.09, 1)
        screen:draw()
        CardParticles.draw()
        FloatingText.draw()
        love.graphics.setCanvas()

        love.graphics.clear(0.05, 0.04, 0.08, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.push()
        love.graphics.scale(zoom, zoom)
        love.graphics.translate(-rect.x, -rect.y)
        love.graphics.draw(canvas)
        love.graphics.pop()

        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", name)
            print("[screenshot_shop] " .. name .. " (zoom " .. zoom .. "x)")
            if quitAfter then love.event.quit() end
        end)
        love.graphics.present()
    end

    -- Move o mouse pro centro de um slot e deixa o hover assentar. O hover é
    -- REAL (Card:updateMouse faz o hit-test), não um estado forçado na mão.
    local function hoverSlot(slot)
        local pos = screen.cardPositions and screen.cardPositions[slot]
        if not pos then print("[screenshot_shop] slot " .. slot .. " inexistente"); return end
        local cx = math.floor(pos.x + (pos.w or screen.cardWidth) / 2)
        local cy = math.floor(pos.y + (pos.h or screen.cardHeight) / 2)
        love.mouse.setPosition(cx, cy)
        simulate(0.35)
        print(("  hover slot %d (%d,%d) -> oferta=%s kind=%s"):format(slot, cx, cy,
            tostring(screen.hoveredOffer and screen.hoveredOffer.id),
            tostring(screen.hoveredKind)))
        -- Prova numérica da puladinha: retângulo REAL da carta em hover vs
        -- uma vizinha em repouso (topo mais alto = subiu; rodapé mais alto
        -- = não invadiu o rótulo de raridade, que fica em Y fixo).
        for _, inst in ipairs(screen.cardInstances or {}) do
            local o = inst.shopOffer
            if o and (o._slot == slot or o._slot == slot + 1) then
                local r = screen:_cardDrawRect(inst)
                print(("    slot %d %s: topo=%.1f rodape=%.1f alt=%.1f (repouso topo=%.1f rodape=%.1f)")
                    :format(o._slot, inst.isHovered and "HOVER " or "repouso",
                        r.y, r.y + r.h, r.h,
                        inst.homeY, inst.homeY + inst.image:getHeight() * inst.baseScale))
            end
        end
    end

    local function dumpActions()
        if screen.skipButton then
            print(("  skipButton   x=%d y=%d w=%d texto=%q"):format(screen.skipButton.x,
                screen.skipButton.y, screen.skipButton.width, screen.skipButton.text))
        end
        if screen.refreshButton then
            print(("  refreshButton x=%d y=%d w=%d texto=%q"):format(screen.refreshButton.x,
                screen.refreshButton.y, screen.refreshButton.width, screen.refreshButton.text))
        end
        if screen.actionBar then
            print(("  actionBar x=%d y=%d w=%d h=%d"):format(screen.actionBar.x,
                screen.actionBar.y, screen.actionBar.w, screen.actionBar.h))
        end
    end

    -- ===================== TORTURA DE RESIZE =====================
    -- O caminho que screenshot nenhum exercitava: a loja NASCE num tamanho e
    -- a janela MUDA com ela aberta (memory/ui_layout_invariants.md — "nascer
    -- grande != crescer"). Percorre pequeno -> fullscreen-ish -> médio ->
    -- pequeno de novo, COM uma oferta selecionada (o estado com mais
    -- geometria derivada), e valida a geometria em cada parada.
    if resizeRun then
        local steps = {
            { 800, 600, "resize_1_pequena" },
            { 1920, 1080, "resize_2_cresceu" },
            { 1280, 720, "resize_3_medio" },
            { 1024, 768, "resize_4_voltou" },
        }
        local failures = 0
        for i, st in ipairs(steps) do
            local w, h, name = st[1], st[2], st[3]
            love.window.setMode(w, h, { resizable = true })
            -- O jogo real passa por love.resize; reproduzimos o que ELE faz
            -- pra nao validar num caminho mais facil nem num mais dificil.
            -- CardFrame junto com FontManager: setMode invalida o CONTEUDO dos
            -- canvases de carta, e desde Set/2026 o love.resize limpa os dois
            -- (sem isso o teste acusaria um bug que o jogo real ja nao tem).
            require("src.ui.FontManager").clearCache()
            require("src.ui.CardFrame").clearCache()
            simulate(0.40)

            -- Seleciona uma carta na PRIMEIRA parada e mantém pelo resto:
            -- os botões de compra dependem do painel de detalhe, que muda de
            -- largura a cada passo.
            if i == 1 then
                hoverSlot(2)
                local sel = screen.hoveredOffer
                if sel then screen:setSelectedOffer(sel, sel._slot) end
                simulate(0.25)
            end

            local bad = screen:validateLayout()
            print(("=== %dx%d (%s) — cartas %dx%d, %d violacao(oes)")
                :format(w, h, name, screen.cardWidth, screen.cardHeight, #bad))
            for _, msg in ipairs(bad) do
                failures = failures + 1
                print("    VIOLACAO: " .. msg)
            end
            for _, b in ipairs({ screen.skipButton, screen.refreshButton }) do
                if b then
                    print(("    botao %-22s x=%4d y=%4d w=%3d"):format(
                        '"' .. tostring(b.text) .. '"', b.x, b.y, b.width))
                end
            end
            for bi, b in ipairs(screen._selectionButtons or {}) do
                print(("    compra[%d] x=%4d y=%4d w=%3d texto=%q")
                    :format(bi, b.x, b.y, b.width, b.text))
            end
            snap(name .. ".png", i == #steps)

            -- SONDA DE REGRESSÃO (Set/2026): na 2ª parada captura de novo,
            -- agora depois de limpar o cache de canvas do CardFrame e
            -- reconstruir as instâncias. Se as DUAS imagens forem iguais, o
            -- cache sobreviveu à recriação da janela. Se só a segunda tiver
            -- arte, as cartas estão saindo em branco depois de alternar
            -- fullscreen — o defeito é de canvas, não de layout.
            if i == 2 then
                local CardFrame = require("src.ui.CardFrame")
                CardFrame.clearCache()
                screen:createCardInstances()
                simulate(0.10)
                snap(name .. "_apos_clearcache.png", false)
            end
        end
        print(failures == 0 and "=== RESIZE OK: nenhuma violacao ==="
            or ("=== RESIZE FALHOU: " .. failures .. " violacao(oes) ==="))
        return
    end

    -- ===== Modo CONTACT SHEET (sem argumento): todos os frames num run =====
    if phase == nil then
        love.mouse.setPosition(6, 6)   -- fora de qualquer slot
        simulate(1.20)
        dumpActions()
        print("[frame 1] repouso (pré-foco): detail=" .. tostring(screen.detailPayload
            and screen.detailPayload.offer and screen.detailPayload.offer.id)
            .. " prefocus=" .. tostring(screen._detailPrefocus))
        snap("shop_1_repouso.png")

        hoverSlot(2)
        snap("shop_2_hover_carta.png")

        -- Primeiro pack da fileira 2 (cartas → voucher → packs).
        local packSlot = (screen.modeConfig.cards or 4) + (screen.modeConfig.upgrades or 1) + 1
        hoverSlot(packSlot)
        snap("shop_3_hover_pack.png")

        hoverSlot(2)
        local sel = screen.hoveredOffer
        if sel then screen:setSelectedOffer(sel, sel._slot) end
        simulate(0.30)
        for i, b in ipairs(screen._selectionButtons or {}) do
            print(("  selBtn[%d] x=%d y=%d w=%d texto=%q"):format(i, b.x, b.y, b.width, b.text))
        end
        snap("shop_4_selecionada.png")

        -- Compra: slot VENDIDO + carta voando pro deck.
        if sel then
            screen:clearSelection()
            screen:purchaseOffer(sel, sel.id)
            simulate(0.25)
        end
        snap("shop_5_comprada.png")

        -- Zooms de inspeção: painel de detalhe (moldura + entrelinha) e a
        -- fileira 1 em hover (medalhão/rótulo acompanhando a carta).
        love.mouse.setPosition(6, 6)
        simulate(0.30)
        if screen.detailPanel then
            local dp = screen.detailPanel
            snapZoom("shop_6_zoom_painel.png", dp, 2)
            -- Pé do painel: valida entrelinha do texto pequeno (descrição,
            -- efeitos, rodapé de contexto) — o zoom de cima não alcança.
            local vis = love.graphics.getHeight() / 2
            snapZoom("shop_6b_zoom_painel_pe.png",
                { x = dp.x, y = math.max(dp.y, dp.y + dp.h - vis) }, 2)
        end
        hoverSlot(3)
        local p3 = screen.cardPositions[3]
        snapZoom("shop_7_zoom_hover.png", {
            x = math.max(0, p3.x - 70), y = math.max(0, p3.y - 60),
        }, 2, true)
        return
    end

    -- ===== Modo FASE ÚNICA (com argumento): iteração rápida =====
    if phase == 3 or phase == 4 then hoverSlot(2) end
    simulate(targetT)
    dumpActions()

    if phase == 4 then
        local offer = screen.hoveredOffer or screen.shopOffers[1]
        if offer then screen:setSelectedOffer(offer, offer._slot) end
        simulate(0.30)
    end

    if phase == 2 then
        for _, offer in ipairs(screen.shopOffers) do
            if offer.type == "card" then
                screen:purchaseOffer(offer, offer.id)
                break
            end
        end
        simulate(0.25)
    end

    snap(string.format("shop_phase_%d.png", phase), true)
end

return M
