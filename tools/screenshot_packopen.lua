-- tools/screenshot_packopen.lua
-- Captura frames da cinemática de abertura de booster pack.
--
-- Roda:
--   love . screenshot_packopen            → TUDO: prateleira + sequencia
--                                           completa dos dois tipos opostos.
--                                           É o comando pra revisar o trabalho
--                                           inteiro sem decorar argumento.
--   love . screenshot_packopen sheet      → folha de contato: os 5 tipos no
--                                           MESMO instante, pra comparar
--                                           identidade lado a lado
--   love . screenshot_packopen 2          → folha de contato na fase 2
--   love . screenshot_packopen 2:arcana   → UM tipo, UMA fase (tela cheia)
--   love . screenshot_packopen arcana     → um tipo na fase padrão (1)
--   love . screenshot_packopen seq        → SEQUÊNCIA: Bufão e Espectral em
--                                           5 instantes cada (parado, wobble,
--                                           estouro, cartas, assentado) — é o
--                                           que mostra a cinemática inteira
--   love . screenshot_packopen states     → MATRIZ DE ESTADOS: um PNG por
--                                           estado da tela de escolha (hover,
--                                           selecao, 5 cartas, reducedMotion,
--                                           janelas baixa/larga...) + validacao
--                                           geometrica das zonas em cada um
--   love . screenshot_packopen hover      → HOVER: a faixa de info sobre uma
--                                           carta, em VARIAS alturas de janela
--                                           (e a unica captura que mostra a
--                                           faixa -- ela so existe no hover)
--   love . screenshot_packopen shelf      → PRATELEIRA: os 5 sleeves lacrados
--                                           lado a lado, linha de cima normal
--                                           e linha de baixo com hover forçado
--                                           (halo, cantoneiras, faíscas)
--
-- Fases (segundos de timeline):
--   0 = 0.4s  sleeve materializado, antes do wobble
--   1 = 0.9s  PICO DO ESTOURO — é aqui que a identidade por tipo aparece
--   2 = 1.6s  cartas materializando em cascata
--   3 = 2.4s  linha de cartas + banner
--   4 = 3.5s  estado de escolha (idle)
--
-- Sufixo @idioma em qualquer modo captura noutra lingua:
--   love . screenshot_packopen states@de    -> matriz de estados em alemao
--   love . screenshot_packopen @en          -> tudo em ingles
-- Sem sufixo e sempre pt_BR (idioma de referencia do projeto).
--
-- Saída: <save dir>/packopen_<kind>_phase<N>.png
-- (no Windows: %APPDATA%/LOVE/card-game/)

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
local FontManager      = require("src.ui.FontManager")
local PackOpenScreen   = require("components.PackOpenScreen")
local BoosterPackSystem = require("src.systems.BoosterPackSystem")
local I18n             = require("src.i18n.I18n")

local PHASE_TIMES = { [0] = 0.4, [1] = 0.9, [2] = 1.6, [3] = 2.4, [4] = 3.5 }

-- Sequência narrativa: os instantes que contam a cinemática. Nomeados porque
-- "phase3" não diz nada quando se abre a pasta de screenshots dias depois.
local SEQ = {
    { name = "1parado",   t = 0.35 },  -- sleeve lacrado, halo/faíscas ligados
    { name = "2wobble",   t = 0.62 },  -- tremor pré-estouro
    -- 0.80 → 0.95: cada tipo tem burstTime proprio (0.45 do Bufao ate 0.80 do
    -- Espectral), entao nenhum instante unico pega os dois no auge. 0.95 e o
    -- meio-termo: Bufao ja assentando, Espectral perto do maximo.
    { name = "3estouro",  t = 0.95 },  -- pico: flash + burst + onda
    { name = "4cartas",   t = 1.60 },  -- cartas materializando na cor do pacote
    { name = "5assentado", t = 2.60 }, -- banner entrou, cartas posicionadas
}
-- Dois tipos deliberadamente opostos (quente/rápido x frio/lento).
local SEQ_KINDS = { "Buffoon", "Spectral" }

-- Ordem da folha de contato = ordem de raridade/preço na loja.
local KINDS = { "Standard", "Buffoon", "Arcana", "Celestial", "Spectral" }
local PACK_ID = {
    Standard  = "pack_standard",
    Buffoon   = "pack_buffoon",
    Arcana    = "pack_arcana",
    Celestial = "pack_celestial",
    Spectral  = "pack_spectral",
}

-- "2:arcana" / "arcana" / "2" / "seq" / "shelf" / nil → mode, phase, kind|nil
-- Idioma da captura. main.lua ja forca pt_BR nos tools visuais, MAS o
-- bootSystems daqui chama I18n.init(), que reaplica o idioma PERSISTIDO e
-- desfaz o force -- era por isso que as capturas saiam em alemao sem
-- ninguem pedir. Agora o idioma e explicito: pt_BR por padrao, e sufixo
-- `@xx` no argumento pra testar outro ("states@de").
local captureLocale = "pt_BR"

local function parseArg(raw)
    -- Sem argumento = TUDO. Antes o default era so a folha de contato no
    -- instante do estouro, e quem rodava o comando nu nunca via nem o pacote
    -- parado nem as cartas reveladas — justamente o que precisava de revisao.
    if not raw then return "all", nil, nil end
    raw = tostring(raw)
    -- Tira o @idioma ANTES de qualquer comparacao de modo, senao
    -- "states@de" nao casa com nenhum modo e cai no default.
    local base, loc = raw:match("^(.-)@(%a[%w_]*)$")
    if base then raw, captureLocale = base, loc end
    if raw == "" then return "all", nil, nil end
    if raw == "all" then return "all", nil, nil end
    if raw == "sheet" then return "sheet", 1, nil end
    if raw == "seq" then return "seq", nil, nil end
    if raw == "shelf" then return "shelf", nil, nil end
    if raw == "sheen" then return "sheen", nil, nil end
    if raw == "hover" then return "hover", nil, nil end
    if raw == "states" then return "states", nil, nil end
    if raw == "grow" then return "grow", nil, nil end
    if raw == "resizeflow" then return "resizeflow", nil, nil end
    local p, k = raw:match("^(%d+):(%a+)$")
    if p then return "single", tonumber(p), k end
    if raw:match("^%d+$") then return "sheet", tonumber(raw), nil end
    return "single", 1, raw
end

-- "arcana" / "Arcana" / "ARCANA" → "Arcana" (nil se não existir).
local function normalizeKind(k)
    if not k then return nil end
    local lower = k:lower()
    for _, name in ipairs(KINDS) do
        if name:lower() == lower then return name end
    end
    return nil
end

local function bootSystems()
    I18n.init()
    -- DEPOIS do init: init() aplica o idioma salvo no disco por cima.
    if I18n.current ~= captureLocale then
        if I18n.setLocale(captureLocale) then
            print("[screenshot_packopen] locale da captura: " .. captureLocale)
        else
            print("[screenshot_packopen] locale desconhecido: "
                .. tostring(captureLocale) .. " -- seguindo em "
                .. tostring(I18n.current))
        end
    end
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
end

-- Abre um pacote do tipo pedido e avança a simulação até `targetT`.
-- Limpa o EventManager antes — sem isso a timeline do pacote anterior
-- continuaria disparando em cima deste (a folha de contato reusa o processo).
local function simulate(kind, targetT, size)
    EventManager.clear()
    -- CardParticles/ParticlesManager sao GLOBAIS e sobrevivem entre pacotes.
    -- Sem este clear, as particulas do pacote anterior (emitidas pelo
    -- materialize das cartas dele, na COR dele) continuam vivas e aparecem no
    -- frame do proximo — o Espectral saia com pontinhos ambar do Bufao
    -- espalhados pela tela. Contaminacao do tool, nao do jogo: numa partida
    -- real so existe um pacote aberto por vez.
    CardParticles.clear()
    FloatingText.clear()

    local pack = BoosterPackSystem.expandPackRecord({
        id = PACK_ID[kind] or "pack_standard", kind = kind,
        size = size or 3, choose = 1,
    }, "warrior")

    -- Forçando edition pra screenshot mostrar shader.
    if pack.instances[1] then pack.instances[1].edition = "foil" end
    if pack.instances[2] then pack.instances[2].edition = "holo"; pack.instances[2].seal = "Red" end
    if pack.instances[3] then pack.instances[3].edition = "polychrome"; pack.instances[3].seal = "Gold" end

    local screen = PackOpenScreen:new()
    screen:show(pack, function(_) end)

    local stepDt = 1 / 60
    local elapsed = 0
    while elapsed < targetT do
        EventManager.update(stepDt)
        FloatingText.update(stepDt)
        FlashShader.update(stepDt)
        ScreenShake.update(stepDt)
        CardParticles.update(stepDt)
        screen:update(stepDt)
        elapsed = elapsed + stepDt
    end

    return screen
end

-- Desenha a cena completa (backdrop sépia simulando a loja por trás + overlay).
local function drawScene(screen)
    local sw, sh = love.graphics.getDimensions()
    love.graphics.clear(0.05, 0.04, 0.08, 1)
    love.graphics.setColor(0.20, 0.16, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1, 1)

    screen:draw()
    CardParticles.draw()
    FloatingText.draw()
    FlashShader.draw()
end

-- Renderiza a cena num canvas e grava. Canvas em vez de captureScreenshot
-- porque este ultimo so entrega UM frame por execucao — com canvas dá pra
-- gerar a sequência inteira numa rodada só.
local function shoot(screen, path)
    local sw, sh = love.graphics.getDimensions()
    local canvas = love.graphics.newCanvas(sw, sh)
    love.graphics.setCanvas(canvas)
    drawScene(screen)
    love.graphics.setCanvas()
    canvas:newImageData():encode("png", path)
    print("[screenshot_packopen] " .. path)
    return canvas
end

-- PRATELEIRA: os 5 sleeves lacrados, linha de cima em repouso e linha de
-- baixo com hover forcado. É a única captura que mostra a melhoria do item
-- parado na loja (halo, cantoneiras, faíscas, respiração).
local function runShelf(keepGoing)
    local PackSleeve = require("src.ui.PackSleeve")
    local sw, sh = love.graphics.getDimensions()
    local sleeveW = select(1, PackSleeve.getDimensions())
    local scale = 0.92
    local step = sw / (#KINDS + 1)

    local canvas = love.graphics.newCanvas(sw, sh)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.05, 0.04, 0.08, 1)
    -- Fundo sépia da loja (o sleeve tem que se destacar DISSO).
    love.graphics.setColor(0.20, 0.16, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1, 1)

    -- 3 linhas de comparacao. A ultima existe pra decidir NO OLHO se o booster
    -- shader (efeito pre-existente, que tinge e passa um sweep por cima da
    -- ilustracao) ajuda ou atrapalha — a doutrina desta rodada e parar de
    -- cobrir a arte, e o shader tambem e uma camada sobre ela.
    -- Duas linhas. A comparacao "com shader" saiu daqui depois que o default
    -- virou arte pura: o shader foi REESCRITO apos aquela decisao (faixa
    -- estreita no lugar do filme), entao a linha nao demonstrava mais o que
    -- levou a descarta-lo -- so confundiria quem abrisse o PNG. Quem quiser
    -- reavaliar usa `love . screenshot_packopen sheen`, que forca shader=true.
    local ROWS = {
        { label = "EM REPOUSO (padrao)", hover = 0 },
        { label = "COM HOVER",           hover = 1 },
    }
    local font = require("src.ui.FontManager").getFont(12)
    love.graphics.setFont(font)
    for row, cfg in ipairs(ROWS) do
        local cy = sh * (0.30 + (row - 1) * 0.40)
        love.graphics.setColor(0.85, 0.80, 0.70, 0.9)
        love.graphics.print(cfg.label, 16, cy - 108)
        for i, k in ipairs(KINDS) do
            local cx = step * i
            PackSleeve.drawAt(PACK_ID[k], k, cx, cy, scale, 1, {
                hover = cfg.hover,
                shader = cfg.shader,
                key = k .. tostring(row),   -- estado de hover proprio por linha
            })
            love.graphics.setColor(0.85, 0.80, 0.70, 0.85)
            love.graphics.print(k, cx - font:getWidth(k) * 0.5, cy + 94)
        end
    end
    love.graphics.setCanvas()
    canvas:newImageData():encode("png", "packopen_prateleira.png")
    print("[screenshot_packopen] packopen_prateleira.png")

    if keepGoing then return end   -- no modo "all" a sequencia ainda vem depois
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.present()
    love.event.quit()
end

-- DIAGNOSTICO DE SHEEN: desenha os 5 sleeves em ESCALA 1:1, em posicoes fixas
-- e conhecidas, com o shader ligado. Como 1:1 + nearest nao reamostra nada, da
-- pra recortar o retangulo exato e comparar PIXEL A PIXEL com o PNG de origem
-- -- que e o teste objetivo de "o foil esta lavando a arte?". As coordenadas
-- estao no print pra ferramenta externa recortar sem adivinhar.
-- Duas fases CONGELADAS do ciclo de foil (ver shaders/booster.glsl):
--   repouso  = 70% do tempo, quando nao ha faixa nenhuma -> tem que sair
--              IDENTICO ao PNG de origem;
--   passagem = o instante em que o reflexo cruza o meio -> e o pico permitido.
local SHEEN_PHASES = { { name = "repouso", y = 80, phase = 5.0 },
                       { name = "passagem", y = 330, phase = 1.36 } }
local function runSheen()
    local PackSleeve = require("src.ui.PackSleeve")
    -- Congela a respiracao idle: ela reescala o sleeve em +-1.2%, o que
    -- REAMOSTRA a arte e desalinha os pixels em ~1.5px. Sem isso a medicao
    -- "quanto o shader desviou da arte" mede interpolacao, nao shader.
    -- (Diagnostico historico: o shader esta DESLIGADO por padrao desde Set/2026,
    -- entao este modo so serve pra reavaliar a decisao com shader = true.)
    _G.gameSettings = _G.gameSettings or {}
    local prevRM = _G.gameSettings.reducedMotion
    _G.gameSettings.reducedMotion = true
    local W, H = PackSleeve.getDimensions()
    local canvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    for _, ph in ipairs(SHEEN_PHASES) do
        for i, k in ipairs(KINDS) do
            local x = 40 + (i - 1) * (W + 30)
            -- escala 1, sem hover, sem faiscas: so arte + shader
            PackSleeve.drawAt(PACK_ID[k], k, x + W / 2, ph.y + H / 2, 1, 1,
                { interactive = false, sparkles = false, phase = ph.phase,
                  shader = true, key = "sheen" .. k .. ph.name })
            print(string.format("[sheen] %s %s x=%d y=%d w=%d h=%d",
                ph.name, k, x, ph.y, W, H))
        end
    end
    love.graphics.setCanvas()
    _G.gameSettings.reducedMotion = prevRM
    canvas:newImageData():encode("png", "packopen_sheen_1to1.png")
    print("[screenshot_packopen] packopen_sheen_1to1.png")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.present()
    love.event.quit()
end

-- Forca o estado de hover numa carta. O tool nao move o mouse do SO, entao
-- marca a flag que Card:updateMouse marcaria e replica o crescimento do hover.
local function forceHover(screen, idx)
    local card = screen.pack.instances[idx]
    if not card then return end
    card.isHovered = true
    card.currentScale = card.targetScale or card.currentScale
end

-- HOVER: o unico modo que mostra a faixa de info. Varre alturas de janela
-- porque o defeito relatado pelo dono ("tooltip muito em cima") so aparecia em
-- tela baixa -- validar so em 1024x768 nao provaria nada.
local WINDOW_SWEEP = { {1024, 768}, {1024, 600}, {1280, 540} }
local function runHover()
    local ow, oh = love.graphics.getDimensions()
    for _, dim in ipairs(WINDOW_SWEEP) do
        love.window.setMode(dim[1], dim[2])
        for _, k in ipairs(SEQ_KINDS) do
            local screen = simulate(k, 2.60)   -- estado assentado
            forceHover(screen, 2)              -- carta do MEIO: pior caso de sobreposicao
            shoot(screen, string.format("packopen_%s_6hover_%dx%d.png",
                k:lower(), dim[1], dim[2]))
        end
    end
    -- Pacote de 5 cartas: packCardScale encolhe a fileira, entao rowTop muda e
    -- a faixa de info tem que continuar bem posicionada. E o caso de borda mais
    -- facil de esquecer, porque o pacote padrao tem 3.
    for _, dim in ipairs({ {1024, 768}, {1280, 540} }) do
        love.window.setMode(dim[1], dim[2])
        local screen = simulate("Celestial", 2.90, 5)
        forceHover(screen, 3)
        shoot(screen, string.format("packopen_5cartas_6hover_%dx%d.png", dim[1], dim[2]))
    end
    love.window.setMode(ow, oh)
    print("[screenshot_packopen] hover: " .. #SEQ_KINDS .. " tipos x " .. #WINDOW_SWEEP
        .. " janelas + pacote de 5 cartas")
    love.event.quit()
end

-- ===========================================================================
-- MATRIZ DE ESTADOS da tela de escolha
-- ===========================================================================
-- A tela tem MUITO mais estados do que "aberto". Cada combinacao de hover,
-- selecao, quantidade de escolhas restantes, numero de cartas, reducedMotion e
-- tamanho de janela e um estado que pode quebrar sozinho. Capturar todos e o
-- que faz defeito aparecer sem precisar de sorte -- foi assim que apareceram a
-- etiqueta ilegivel e o nome em idioma trocado.
--
-- Cada entrada: { nome, fn(screen) que prepara o estado, [janela], [size] }
local Layout = require("src.ui.PackChoiceLayout")

local function hoverCard(screen, i)
    local c = screen.pack.instances[i]
    if not c then return end
    c.isHovered = true
    c.currentScale = c.targetScale or c.currentScale
end

local function selectCard(screen, i)
    local c = screen.pack.instances[i]
    if not c then return end
    screen:_setCardSelection(i, c)
    screen._selectionAnim = 1
end

local STATES = {
    { "01_assentado_sem_hover", function() end },
    { "02_hover",               function(sc) hoverCard(sc, 2) end },
    { "03_selecionada",         function(sc) selectCard(sc, 2) end },
    { "04_selecionada_e_hover_em_outra",
                                function(sc) selectCard(sc, 2); hoverCard(sc, 3) end },
    { "05_confirmada_saindo",   function(sc)
          sc:selectCard(sc.pack.instances[2])
      end },
    { "06_falta_escolher",      function(sc)
          -- choose > 1: uma ja escolhida, ainda falta escolher outra
          sc.choicesRemaining = 2
          sc:selectCard(sc.pack.instances[1])
          hoverCard(sc, 3)
      end },
    { "07_cinco_cartas",        function(sc) hoverCard(sc, 3) end, nil, 5 },
    { "08_reduced_motion",      function(sc) hoverCard(sc, 2) end },
    { "09_janela_baixa",        function(sc) hoverCard(sc, 2) end, { 1024, 600 } },
    { "10_janela_larga",        function(sc) selectCard(sc, 2) end, { 1920, 1080 } },
    { "11_janela_muito_baixa",  function(sc) selectCard(sc, 2) end, { 1280, 540 } },
    { "12_selecionada_5_cartas", function(sc) selectCard(sc, 4) end, { 1280, 540 }, 5 },
}

local function runStates()
    local ow, oh = love.graphics.getDimensions()
    local failures = 0
    for _, st in ipairs(STATES) do
        local name, prep, win, size = st[1], st[2], st[3], st[4]
        -- setMode SO quando o tamanho muda de fato, e limpando o cache de
        -- canvas das cartas: trocar o modo de video invalida o CONTEUDO dos
        -- canvases, e CardFrame devolveria o canvas vazio do cache (a carta
        -- some e sobram so selo e moldura).
        local tw, th2 = (win and win[1] or ow), (win and win[2] or oh)
        local cw, ch = love.graphics.getDimensions()
        if tw ~= cw or th2 ~= ch then
            love.window.setMode(tw, th2)
            require("src.ui.CardFrame").clearCache()
        end

        _G.gameSettings = _G.gameSettings or {}
        local prevRM = _G.gameSettings.reducedMotion
        if name:find("reduced") then _G.gameSettings.reducedMotion = true end

        local screen = simulate("Buffoon", 2.90, size)
        -- ORDEM IMPORTA: assentar PRIMEIRO, preparar o estado DEPOIS.
        -- screen:update() chama card:updateMouse() com o mouse REAL do SO, que
        -- zera o isHovered forcado -- fazer o prep antes dos ticks apagava
        -- justamente o hover que o estado queria capturar.
        for _ = 1, 10 do
            EventManager.update(1 / 60); screen:update(1 / 60)
        end
        prep(screen)
        -- Um tick extra so pros eases do prep (selecao) saírem do zero.
        EventManager.update(1 / 30)

        -- VALIDACAO GEOMETRICA: prova que nenhuma zona invade outra, em vez de
        -- confiar no olho. E o teste que o layout por acumulacao nunca teve.
        local sw, sh = love.graphics.getDimensions()
        local ok, problems = Layout.validate(screen:_z(), sw, sh)
        if not ok then
            failures = failures + 1
            print(("[states] %-34s FALHA GEOMETRICA: %s"):format(name, table.concat(problems, "; ")))
        end

        shoot(screen, ("packstate_%s.png"):format(name))
        _G.gameSettings.reducedMotion = prevRM
    end
    love.window.setMode(ow, oh)
    print(("[screenshot_packopen] matriz: %d estados, %d falhas geometricas")
        :format(#STATES, failures))
    love.event.quit()
end

-- ===========================================================================
-- NASCER GRANDE != CRESCER
-- ===========================================================================
-- Toda validacao anterior criou a tela JA no tamanho final, o que nunca
-- exercita o caminho do bug do dono (abrir numa janela pequena e dar
-- fullscreen). Este modo faz a tela CRESCER de verdade e compara o resultado
-- com uma tela NASCIDA no tamanho grande: se o resize estiver completo, as
-- duas imagens sao praticamente identicas. Qualquer diferenca e layout que
-- ficou para tras.
local function runGrow()
    local dw, dh = love.window.getDesktopDimensions()
    -- Nunca pedir janela maior que o desktop: setMode trava.
    local SMALL = { 800, 600 }
    local BIG   = { math.min(1440, dw - 80), math.min(900, dh - 120) }
    print(("[grow] desktop %dx%d | pequena %dx%d | grande %dx%d")
        :format(dw, dh, SMALL[1], SMALL[2], BIG[1], BIG[2]))

    local function setSize(w, h)
        local cw, ch = love.graphics.getDimensions()
        if w ~= cw or h ~= ch then
            love.window.setMode(w, h)
            -- NAO limpa cache de proposito: o objetivo aqui e REPRODUZIR o que
            -- o jogo faz de verdade no love.resize.
        end
    end

    local function settle(screen, ticks)
        for _ = 1, (ticks or 8) do
            EventManager.update(1 / 60); screen:update(1 / 60)
        end
    end

    -- (A) nasce pequena, e fica pequena
    setSize(SMALL[1], SMALL[2])
    local grown = simulate("Buffoon", 2.90)
    settle(grown)
    shoot(grown, "packgrow_1_pequena.png")

    -- (B) MESMA tela, agora cresce -- e o caminho do dono (tecla f)
    setSize(BIG[1], BIG[2])
    if grown.resize then grown:resize() end
    settle(grown)
    shoot(grown, "packgrow_2_cresceu.png")

    -- (C) tela NOVA ja nascida grande -- a referencia do que deveria aparecer
    local born = simulate("Buffoon", 2.90)
    settle(born)
    shoot(born, "packgrow_3_nascida_grande.png")

    -- (D) e o caminho inverso: encolher
    setSize(SMALL[1], SMALL[2])
    if grown.resize then grown:resize() end
    settle(grown)
    shoot(grown, "packgrow_4_encolheu.png")

    print("[screenshot_packopen] grow: compare 2_cresceu com 3_nascida_grande")
    love.event.quit()
end

function M.run(rawArg)
    local mode, phase, rawKind = parseArg(rawArg)
    local targetT = PHASE_TIMES[phase or 1] or PHASE_TIMES[1]
    local kind = normalizeKind(rawKind)
    if rawKind and not kind then
        print("[screenshot_packopen] tipo desconhecido: " .. tostring(rawKind)
            .. " (use Standard/Buffoon/Arcana/Celestial/Spectral)")
    end

    bootSystems()

    -- ── Prateleira: nem abre pacote, so desenha os sleeves lacrados. ──
    if mode == "shelf" then
        runShelf()
        return
    end

    if mode == "sheen" then
        runSheen()
        return
    end

    if mode == "hover" then
        runHover()
        return
    end

    if mode == "states" then
        runStates()
        return
    end

    if mode == "grow" then
        runGrow()
        return
    end
    -- ── RESIZEFLOW: o teste que faltava. NASCER grande != CRESCER. ──
    -- O dono: "quando o jogo esta aberto numa janela pequena e eu dou full
    -- screen, essa tela e toda desconfigurada". Todas as validacoes anteriores
    -- criavam a tela JA no tamanho final, o que nunca exercita o caminho do
    -- bug: layout cacheado no :show() de um tamanho e reaproveitado noutro.
    -- Aqui abrimos pequeno, avancamos ate assentar, e SO ENTAO mudamos o
    -- tamanho e chamamos resize() -- exatamente o que love.resize faz.
    if mode == "resizeflow" then
        local ow, oh = love.graphics.getDimensions()
        -- Tamanhos deliberadamente ABAIXO da area util do desktop: pedir uma
        -- janela maior que a tela trava o setMode em algumas configuracoes de
        -- Windows (foi o que aconteceu na 1a versao deste modo, com 1920x1080).
        local FLOW = {
            { from = { 800, 480 },  to = { 1280, 720 }, name = "pequena_para_grande" },
            { from = { 1280, 720 }, to = { 800, 480 },  name = "grande_para_pequena" },
            { from = { 1024, 576 }, to = { 640, 480 },  name = "baixa_para_menor" },
        }
        for _, f in ipairs(FLOW) do
            print(string.format("[resizeflow] -> abrindo em %dx%d", f.from[1], f.from[2]))
            love.window.setMode(f.from[1], f.from[2])
            FontManager.clearCache()
            local screen = simulate("Buffoon", 2.60)
            print("[resizeflow]    pacote assentado")
            forceHover(screen, 2)
            shoot(screen, string.format("packresize_%s_1antes_%dx%d.png",
                f.name, f.from[1], f.from[2]))

            -- O SALTO: muda o tamanho e avisa a tela, como love.resize faria.
            print(string.format("[resizeflow]    SALTO para %dx%d", f.to[1], f.to[2]))
            love.window.setMode(f.to[1], f.to[2])
            FontManager.clearCache()
            if screen.resize then screen:resize() end
            for _ = 1, 12 do
                EventManager.update(1 / 60)
                screen:update(1 / 60)
            end
            shoot(screen, string.format("packresize_%s_2depois_%dx%d.png",
                f.name, f.to[1], f.to[2]))

            -- Validacao geometrica no tamanho NOVO, se o layout expuser.
            local okv, err = true, nil
            if screen._validateLayout then okv, err = screen:_validateLayout() end
            print(string.format("[resizeflow] %s  %dx%d -> %dx%d  %s",
                f.name, f.from[1], f.from[2], f.to[1], f.to[2],
                okv and "GEOMETRIA OK" or ("FALHA: " .. tostring(err))))
        end
        love.window.setMode(ow, oh)
        FontManager.clearCache()
        print("[screenshot_packopen] resizeflow: 3 saltos capturados")
        return
    end


    -- ── Sequência: 2 tipos x 5 instantes, tudo numa rodada. ──
    if mode == "seq" or mode == "all" then
        if mode == "all" then runShelf(true) end
        local last
        for _, k in ipairs(SEQ_KINDS) do
            for _, step in ipairs(SEQ) do
                local screen = simulate(k, step.t)
                last = shoot(screen, string.format("packopen_%s_%s.png", k:lower(), step.name))
            end
            -- 6hover: mesmo estado assentado, mas com a faixa de info aberta.
            local hov = simulate(k, 2.60)
            forceHover(hov, 2)
            last = shoot(hov, string.format("packopen_%s_6hover.png", k:lower()))
        end
        print(string.format("[screenshot_packopen] sequencia: %d tipos x %d instantes",
            #SEQ_KINDS, #SEQ))
        if last then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(last, 0, 0)
        end
        love.graphics.present()
        love.event.quit()
        return
    end

    -- ── Modo 1 tipo: captura a tela de verdade (com CRT/pós do love.draw). ──
    if kind then
        local screen = simulate(kind, targetT)
        drawScene(screen)
        love.graphics.captureScreenshot(function(imageData)
            local path = string.format("packopen_%s_phase%d.png", kind:lower(), phase)
            imageData:encode("png", path)
            print("[screenshot_packopen] " .. path)
            love.event.quit()
        end)
        love.graphics.present()
        return
    end

    -- ── Folha de contato: 5 tipos, mesma fase, um PNG cada. ──
    -- Renderiza num canvas por tipo (em vez de captureScreenshot, que só
    -- captura UM frame por execução) — assim os 5 saem de uma rodada só e
    -- dá pra abrir os arquivos lado a lado.
    local last
    for _, k in ipairs(KINDS) do
        local screen = simulate(k, targetT)
        last = shoot(screen, string.format("packopen_%s_phase%d.png", k:lower(), phase))
    end

    print(string.format("[screenshot_packopen] folha de contato: %d tipos na fase %d (t=%.1fs)",
        #KINDS, phase, targetT))

    -- Mostra o último na janela só pra não piscar em preto antes de sair.
    if last then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(last, 0, 0)
    end
    love.graphics.present()
    love.event.quit()
end

return M
