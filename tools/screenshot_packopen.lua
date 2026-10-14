local M = {}

local Game             = require("src.core.Game")
local CRTShader        = require("src.ui.CRTShader")
local DissolveShader   = require("src.ui.DissolveShader")
local FlashShader      = require("src.ui.FlashShader")
local BoosterShader    = require("src.ui.BoosterShader")
local FoilShader       = require("src.ui.FoilShader")
local PolychromeShader = require("src.ui.PolychromeShader")
local ScreenShake      = require("src.systems.ScreenShake")
local EventManager     = require("engine.EventManager")
local FloatingText     = require("src.ui.FloatingText")
local CardParticles    = require("src.systems.CardParticles")
local FontManager      = require("src.ui.FontManager")
local PackOpenScreen   = require("components.PackOpenScreen")
local BoosterPackSystem = require("src.systems.BoosterPackSystem")
local I18n             = require("src.i18n.I18n")

local PHASE_TIMES = { [0] = 0.4, [1] = 0.9, [2] = 1.6, [3] = 2.4, [4] = 3.5 }

local SEQ = {
    { name = "1parado",   t = 0.35 },
    { name = "2wobble",   t = 0.62 },
    { name = "3estouro",  t = 0.95 },
    { name = "4cartas",   t = 1.60 },
    { name = "5assentado", t = 2.60 },
}
local SEQ_KINDS = { "Buffoon", "Spectral" }

local KINDS = { "Standard", "Buffoon", "Arcana", "Celestial", "Spectral" }
local PACK_ID = {
    Standard  = "pack_standard",
    Buffoon   = "pack_buffoon",
    Arcana    = "pack_arcana",
    Celestial = "pack_celestial",
    Spectral  = "pack_spectral",
}

local captureLocale = "pt_BR"

local function parseArg(raw)
    if not raw then return "all", nil, nil end
    raw = tostring(raw)
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
    if I18n.current ~= captureLocale then
        if not I18n.setLocale(captureLocale) then
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
    ScreenShake.install()

    local game = Game:new()
    game:startNewRun("warrior")
    _G.game = game
end

local function simulate(kind, targetT, size)
    EventManager.clear()
    CardParticles.clear()
    FloatingText.clear()

    local pack = BoosterPackSystem.expandPackRecord({
        id = PACK_ID[kind] or "pack_standard", kind = kind,
        size = size or 3, choose = 1,
    }, "warrior")

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

local function runShelf(keepGoing)
    local PackSleeve = require("src.ui.PackSleeve")
    local sw, sh = love.graphics.getDimensions()
    local sleeveW = select(1, PackSleeve.getDimensions())
    local scale = 0.92
    local step = sw / (#KINDS + 1)

    local canvas = love.graphics.newCanvas(sw, sh)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.05, 0.04, 0.08, 1)
    love.graphics.setColor(0.20, 0.16, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1, 1)

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
                key = k .. tostring(row),
            })
            love.graphics.setColor(0.85, 0.80, 0.70, 0.85)
            love.graphics.print(k, cx - font:getWidth(k) * 0.5, cy + 94)
        end
    end
    love.graphics.setCanvas()
    canvas:newImageData():encode("png", "packopen_prateleira.png")
    print("[screenshot_packopen] packopen_prateleira.png")

    if keepGoing then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.present()
    love.event.quit()
end

local SHEEN_PHASES = { { name = "repouso", y = 80, phase = 5.0 },
                       { name = "passagem", y = 330, phase = 1.36 } }
local function runSheen()
    local PackSleeve = require("src.ui.PackSleeve")
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

local function forceHover(screen, idx)
    local card = screen.pack.instances[idx]
    if not card then return end
    card.isHovered = true
    card.currentScale = card.targetScale or card.currentScale
end

local WINDOW_SWEEP = { {1024, 768}, {1024, 600}, {1280, 540} }
local function runHover()
    local ow, oh = love.graphics.getDimensions()
    for _, dim in ipairs(WINDOW_SWEEP) do
        love.window.setMode(dim[1], dim[2])
        for _, k in ipairs(SEQ_KINDS) do
            local screen = simulate(k, 2.60)
            forceHover(screen, 2)
            shoot(screen, string.format("packopen_%s_6hover_%dx%d.png",
                k:lower(), dim[1], dim[2]))
        end
    end
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
        for _ = 1, 10 do
            EventManager.update(1 / 60); screen:update(1 / 60)
        end
        prep(screen)
        EventManager.update(1 / 30)

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

local function runGrow()
    local dw, dh = love.window.getDesktopDimensions()
    local SMALL = { 800, 600 }
    local BIG   = { math.min(1440, dw - 80), math.min(900, dh - 120) }
    print(("[grow] desktop %dx%d | pequena %dx%d | grande %dx%d")
        :format(dw, dh, SMALL[1], SMALL[2], BIG[1], BIG[2]))

    local function setSize(w, h)
        local cw, ch = love.graphics.getDimensions()
        if w ~= cw or h ~= ch then
            love.window.setMode(w, h)
        end
    end

    local function settle(screen, ticks)
        for _ = 1, (ticks or 8) do
            EventManager.update(1 / 60); screen:update(1 / 60)
        end
    end

    setSize(SMALL[1], SMALL[2])
    local grown = simulate("Buffoon", 2.90)
    settle(grown)
    shoot(grown, "packgrow_1_pequena.png")

    setSize(BIG[1], BIG[2])
    if grown.resize then grown:resize() end
    settle(grown)
    shoot(grown, "packgrow_2_cresceu.png")

    local born = simulate("Buffoon", 2.90)
    settle(born)
    shoot(born, "packgrow_3_nascida_grande.png")

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
    if mode == "resizeflow" then
        local ow, oh = love.graphics.getDimensions()
        local FLOW = {
            { from = { 800, 480 },  to = { 1280, 720 }, name = "pequena_para_grande" },
            { from = { 1280, 720 }, to = { 800, 480 },  name = "grande_para_pequena" },
            { from = { 1024, 576 }, to = { 640, 480 },  name = "baixa_para_menor" },
        }
        for _, f in ipairs(FLOW) do
            love.window.setMode(f.from[1], f.from[2])
            FontManager.clearCache()
            local screen = simulate("Buffoon", 2.60)
            forceHover(screen, 2)
            shoot(screen, string.format("packresize_%s_1antes_%dx%d.png",
                f.name, f.from[1], f.from[2]))

            love.window.setMode(f.to[1], f.to[2])
            FontManager.clearCache()
            if screen.resize then screen:resize() end
            for _ = 1, 12 do
                EventManager.update(1 / 60)
                screen:update(1 / 60)
            end
            shoot(screen, string.format("packresize_%s_2depois_%dx%d.png",
                f.name, f.to[1], f.to[2]))

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

    if mode == "seq" or mode == "all" then
        if mode == "all" then runShelf(true) end
        local last
        for _, k in ipairs(SEQ_KINDS) do
            for _, step in ipairs(SEQ) do
                local screen = simulate(k, step.t)
                last = shoot(screen, string.format("packopen_%s_%s.png", k:lower(), step.name))
            end
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

    local last
    for _, k in ipairs(KINDS) do
        local screen = simulate(k, targetT)
        last = shoot(screen, string.format("packopen_%s_phase%d.png", k:lower(), phase))
    end

    print(string.format("[screenshot_packopen] folha de contato: %d tipos na fase %d (t=%.1fs)",
        #KINDS, phase, targetT))

    if last then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(last, 0, 0)
    end
    love.graphics.present()
    love.event.quit()
end

return M
