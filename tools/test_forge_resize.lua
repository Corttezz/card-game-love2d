-- tools/test_forge_resize.lua
-- Auditoria de RESIZE da tela de forja (components/RestScreen.lua, modo picker).
--
-- POR QUE ESTE TESTE EXISTE
-- memory/ui_layout_invariants.md §2: "NASCER grande ≠ CRESCER". Criar a tela já
-- no tamanho final não exercita o bug — ele mora em "layout calculado num
-- tamanho, janela muda, layout reaproveitado". A mesma memória registra que
-- `love.window.setMode` repetido dentro de um tool TRAVA, então aqui a janela
-- é FALSIFICADA: monkey-patch em love.graphics.getWidth/getHeight. Isso
-- exercita exatamente o caminho do defeito (todo o layout desta tela deriva
-- dessas duas funções) sem tocar na janela de verdade.
--
-- A validação VISUAL continua sendo manual, pelo roteiro da memória.
--
--   love . test_one test_forge_resize
--   love . test_all               (registrado em tools/run_all_tests.lua)

local TK = require("tools.testkit")
local M = {}

local RestScreen   = require("components.RestScreen")
local CardDatabase = require("src.systems.CardDatabase")
local EventManager = require("engine.EventManager")
local FontManager  = require("src.ui.FontManager")

-- ===== Janela falsa =====
local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local fakeW, fakeH = nil, nil
local function installFakeWindow()
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
end

-- Simula o que love.resize faz de verdade (main.lua:1479): limpa o cache de
-- fontes ANTES de avisar as telas. Sem isso o teste seria mais leniente que o
-- jogo — larguras medidas ficariam cacheadas do tamanho anterior.
local function resizeTo(screen, w, h)
    fakeW, fakeH = w, h
    FontManager.clearCache()
    screen:resize()
end

local function pump(screen, secs)
    local dt = 1 / 60
    local t = 0
    while t < secs do
        EventManager.update(dt)
        screen:update(dt)
        t = t + dt
    end
end

-- Todas as entries cabem dentro do retângulo da grade?
local function entriesInsideGrid(screen)
    local gx, gy, gw, gh = screen:_gridRect()
    for _, e in ipairs(screen.cardEntries) do
        if e.x < gx - 1 or e.y < gy - 1
            or e.x + e.w > gx + gw + 1
            or e.y + e.h > gy + gh + 1 then
            return false, e
        end
    end
    return true
end

local function makeScreen(game, mode)
    local screen = RestScreen:new()
    screen:show(game, function() end, mode or "forge")
    return screen
end

-- Enche o deck com cartas forjáveis do catálogo (determinístico: ordenado por
-- id). `want` = quantas cartas distintas queremos na bigorna.
local function stockDeck(game, want)
    local pool = {}
    for id in pairs(CardDatabase:getAllCards()) do table.insert(pool, id) end
    table.sort(pool)
    local added = 0
    for _, id in ipairs(pool) do
        if added >= want then break end
        local cd = CardDatabase:getCard(id)
        -- Joker nunca entra em currentDeck (invariante do projeto).
        if cd and cd.type ~= "joker" and game.runManager:canUpgrade(id) then
            game.runManager:addCardToDeck(id)
            added = added + 1
        end
    end
    return added
end

function M.run()
    local t = TK.new("forge resize (RestScreen picker)")
    installFakeWindow()

    local okAll = pcall(function()
        local game = TK.newRunGame("warrior")
        stockDeck(game, 14)

        -- ================================================================
        -- 1. GRADE: nasce pequena, cresce. A escala e as posições têm que
        --    acompanhar — este é o caminho do defeito.
        -- ================================================================
        fakeW, fakeH = 800, 600
        local screen = makeScreen(game, "forge")
        t:truthy("grade pequena tem cartas", #screen.cardEntries > 0)
        local smallW = screen.cardEntries[1].w
        local smallX = screen.cardEntries[1].x
        t:truthy("cartas dentro da grade em 800x600", (entriesInsideGrid(screen)))

        resizeTo(screen, 1600, 900)
        t:truthy("cartas dentro da grade após crescer p/ 1600x900",
            (entriesInsideGrid(screen)))
        t:truthy("escala da carta MUDOU ao crescer (não ficou presa)",
            screen.cardEntries[1].w ~= smallW)
        t:truthy("posição X da carta MUDOU ao crescer",
            screen.cardEntries[1].x ~= smallX)

        -- E de volta pra pequena (o caminho de "apertar f duas vezes").
        resizeTo(screen, 800, 600)
        t:truthy("cartas dentro da grade ao voltar p/ 800x600",
            (entriesInsideGrid(screen)))
        t:near("escala volta ao valor da janela pequena",
            screen.cardEntries[1].w, smallW, 0.001)

        -- Botões de rodapé acompanham o painel.
        local px, py, pw, ph = screen:panelRect()
        local backOk = false
        for _, b in ipairs(screen.buttons) do
            if b.y >= py and b.y + (b.height or 0) <= py + ph + 1
                and b.x >= px - 1 then
                backOk = true
            end
        end
        t:truthy("botões de rodapé dentro do painel após resize", backOk)

        -- ================================================================
        -- 2. PAGINAÇÃO: a página atual continua válida e ancorada.
        -- ================================================================
        fakeW, fakeH = 640, 480
        local paged = makeScreen(game, "forge")
        t:truthy("janela pequena pagina o grimório", paged.pageCount >= 1)
        if paged.pageCount > 1 then
            paged:_changePage(1)
            local anchorId = paged.cardEntries[1] and paged.cardEntries[1].id
            resizeTo(paged, 1920, 1080)
            t:truthy("página continua dentro de 1..pageCount após crescer",
                paged.page >= 1 and paged.page <= paged.pageCount)
            t:truthy("página não aponta pra vazio após crescer",
                #paged.cardEntries > 0)
            -- A âncora garante que a carta que abria a página continua na tela.
            local stillThere = false
            for _, e in ipairs(paged.cardEntries) do
                if e.id == anchorId then stillThere = true break end
            end
            t:truthy("a carta que abria a página continua visível (âncora)",
                stillThere)
            t:truthy("cartas dentro da grade após crescer (paginado)",
                (entriesInsideGrid(paged)))
        else
            t:check("pageCount==1 nesta janela — paginação não exercitada", true)
        end

        -- ================================================================
        -- 3. CERIMÔNIA: resize NO MEIO da subida pra pose herói.
        --    Armadilha do PackOpenScreen: resize que "reposiciona do zero"
        --    teleporta a animação. Aqui tem que RECALCULAR O DESTINO.
        -- ================================================================
        fakeW, fakeH = 800, 600
        local cer = makeScreen(game, "forge")
        local target = cer.cardEntries[1]
        local instBefore = target.inst
        cer:_onPickCard(target.id)
        t:truthy("cerimônia iniciou (busy)", cer.busy)
        t:truthy("estado da cerimônia existe", cer.forge ~= nil)

        pump(cer, 0.18)  -- meio da Fase A (lift = 0.34s)
        local f = cer.forge
        local poseMid = f.pose
        t:truthy("pose em progresso antes do resize (0<pose<1)",
            poseMid > 0 and poseMid < 1)

        resizeTo(cer, 1600, 900)
        local gx, gy, gw, gh = cer:_gridRect()
        t:near("pose PRESERVADA no resize (animação não reiniciou)",
            cer.forge.pose, poseMid, 1e-9)
        t:truthy("instância da carta NÃO foi recriada (animação sobreviveu)",
            cer.forge.entry.inst == instBefore)
        t:truthy("pose herói dentro da grade nova",
            f.heroX >= gx - 1 and f.heroX + f.heroW <= gx + gw + 1
            and f.heroY >= gy - 1)
        t:truthy("placa de delta dentro da grade nova",
            f.plate.x >= gx - 1 and f.plate.x + f.plate.w <= gx + gw + 1)
        t:truthy("placa abaixo da carta (não sobrepõe)",
            f.plate.y >= f.heroY + f.heroH)
        -- cx tem que estar ENTRE berço e palco, coerente com a pose.
        local lo = math.min(f.startX, f.heroX)
        local hi = math.max(f.startX, f.heroX)
        t:truthy("posição atual coerente com a pose após resize",
            f.cx >= lo - 1 and f.cx <= hi + 1)
        t:truthy("berço = posição da carta na grade NOVA",
            math.abs(f.startX - f.entry.x) < 0.001)

        -- Termina a cerimônia na janela nova: tem que virar o valor e fechar.
        pump(cer, 1.2)
        t:truthy("a virada aconteceu mesmo com resize no meio",
            cer.forge.lines[1].newA > 0.9)
        t:truthy("nível da carta subiu", cer.forge.entry.level >= 1)

        -- ================================================================
        -- 4. CERIMÔNIA: resize DEPOIS da virada preserva o estado animado.
        -- ================================================================
        local plateXBefore = cer.forge.plate.x
        local plateWBefore = cer.forge.plate.w
        resizeTo(cer, 1024, 768)
        t:truthy("valor novo continua visível após resize pós-virada",
            cer.forge.lines[1].newA > 0.9)
        t:truthy("valor antigo continua cedido após resize pós-virada",
            cer.forge.lines[1].oldA < 0.9)
        -- A LARGURA da placa depende só do conteúdo e das fontes (tamanhos
        -- fixos, como no resto desta tela) — ela deve ser ESTÁVEL. O que tem
        -- que acompanhar a janela é a POSIÇÃO: re-centrada na grade nova.
        t:eq("largura da placa estável p/ o mesmo conteúdo",
            cer.forge.plate.w, plateWBefore)
        t:truthy("placa RE-CENTRADA na janela nova", cer.forge.plate.x ~= plateXBefore)
        local gx2, gy2, gw2, gh2 = cer:_gridRect()
        t:truthy("placa dentro da grade após resize pós-virada",
            cer.forge.plate.x >= gx2 - 1
            and cer.forge.plate.x + cer.forge.plate.w <= gx2 + gw2 + 1)
        t:truthy("decalques guardam fração, não coordenada",
            #cer.forge.clangs == 0 or cer.forge.clangs[1].fx ~= nil)

        -- ================================================================
        -- 5. Painel de hover: ancorado na carta, com flip/clamp na tela nova.
        -- ================================================================
        fakeW, fakeH = 1280, 720
        local hov = makeScreen(game, "forge")
        resizeTo(hov, 700, 560)
        local last = hov.cardEntries[#hov.cardEntries]
        t:truthy("carta mais à direita ainda cabe na tela após encolher",
            last ~= nil and last.x + last.w <= love.graphics.getWidth())
        t:noerror("painel de hover desenha sem erro na janela nova", function()
            hov._hoverIdx = #hov.cardEntries
            hov:_drawHoverPanel(last)
        end)

        -- ================================================================
        -- 6. Modo "choose" (fogueira) também tem que acompanhar.
        -- ================================================================
        fakeW, fakeH = 800, 600
        local fire = RestScreen:new()
        fire:show(game, function() end)   -- sem mode = "choose"
        local cardX = fire.choiceCards[1] and fire.choiceCards[1].x
        resizeTo(fire, 1600, 900)
        t:truthy("escolhas da fogueira reposicionadas no resize",
            fire.choiceCards[1] and fire.choiceCards[1].x ~= cardX)
    end)

    restoreWindow()
    FontManager.clearCache()
    EventManager.clear("forge")

    if not okAll then
        t:check("suite rodou sem crash", false)
    end
    return t:done()
end

return M
