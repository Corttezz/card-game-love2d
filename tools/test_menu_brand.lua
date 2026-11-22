local TK = require("tools.testkit")
local M = {}

local OLD_P = { ["1280x720"] = 1, ["1920x1080"] = 2, ["2560x1440"] = 2, ["3840x2160"] = 4 }

local SIZES = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 }, { 1024, 768 } }

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

local function step(menu, secs)
    for _ = 1, math.floor(secs * 60 + 0.5) do
        if _G.EventManager then _G.EventManager.update(1 / 60) end
        menu:update(1 / 60)
    end
end

local function shotTitle(menu, w, h)
    local cv = love.graphics.newCanvas(w, h)
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    menu:drawTitle()
    love.graphics.pop()
    local d = cv:newImageData()
    cv:release()
    return d
end

local function diff(a, b)
    local n = 0
    local w, h = a:getDimensions()
    for y = 0, h - 1, 2 do
        for x = 0, w - 1, 2 do
            local r1, g1, b1 = a:getPixel(x, y)
            local r2, g2, b2 = b:getPixel(x, y)
            if r1 ~= r2 or g1 ~= g2 or b1 ~= b2 then n = n + 1 end
        end
    end
    return n
end

local function fakeAudio(codes)
    local a = { sources = {}, log = {}, clock = function() return 0 end }
    for _, code in ipairs(codes) do
        a.sources[code] = { baseVolume = 0.5, instGain = {} }
    end
    function a:play(code, opts)
        local entry = self.sources[code]
        if not entry then return nil end
        local src = { playing = true }
        function src:isPlaying() return self.playing end
        function src:stop() self.playing = false end
        entry.instGain[src] = opts and opts.gain
        src.vol = entry.baseVolume * (opts and opts.gain or 1)
        self.log[#self.log + 1] = { code = code, src = src, t = self.clock(), vol = src.vol, pitch = opts and opts.pitch }
        return src
    end
    function a:playSound(code) return self:play(code) ~= nil end
    function a:playMusic() end
    function a:stopMusic() end
    function a:fadeOutMusic() end
    function a:setInstanceGain(code, src, g)
        self.sources[code].instGain[src] = g
        src.vol = self.sources[code].baseVolume * (g or 1)
    end
    function a:sounding()
        local n = 0
        for _, r in ipairs(self.log) do
            if r.src.playing then n = n + 1 end
        end
        return n
    end
    return a
end

local function stingSfx(t, Menu, MenuBrand)
    local cues = MenuBrand.stingSfx()
    local T = MenuBrand.T
    local codes, seen = {}, {}
    for _, c in ipairs(cues) do
        if not seen[c.code] then seen[c.code] = true; codes[#codes + 1] = c.code end
    end
    local function count(code)
        local n = 0
        for _, c in ipairs(cues) do if c.code == code then n = n + 1 end end
        return n
    end
    t:eq("sons do logo: 26 sons como no trailer v7", #cues, 26)
    t:eq("sons do logo: 8 tiques dos raios", count("jokerTick"), 8)
    t:eq("sons do logo: 1 nota por letra", count("menuHover"), #require("src.data.menu_brand").cuts - 1)
    t:eq("sons do logo: 4 brilhos no fim", count("effectChime"), 4)
    t:eq("sons do logo: abre com o vortice em 0,60 s", cues[1].code .. "@" .. cues[1].t, "bootVortex@0.6")
    local maxVol, at = 0, {}
    for _, c in ipairs(cues) do
        maxVol = math.max(maxVol, c.volume)
        at[c.code] = at[c.code] or c.t
    end
    t:eq("sons do logo: impacto no clarao", at.bootImpact, T.FLASH)
    t:truthy("sons do logo: primeiro tique junto do 1o raio", math.abs(at.jokerTick - (T.RAY0 + 0.1)) < 1e-9)
    t:eq("sons do logo: 1a letra no pouso da palavra", at.menuHover, T.WORD0)
    t:eq("sons do logo: varredura dourada", at.forgeReveal, T.SWEEP0)
    t:truthy("sons do logo: impacto e o mais alto (0,6)", math.abs(maxVol - 0.6) < 1e-9)
    t:truthy(("sons do logo: comeco suave (vortice %.3f <= 0,2)"):format(cues[1].volume), cues[1].volume <= 0.2)
    local mainSrc = love.filesystem.read("main.lua") or ""
    for _, code in ipairs(codes) do
        t:truthy("sons do logo: " .. code .. " carregado no main", mainSrc:find(code, 1, true) ~= nil)
    end

    local realAudio = _G.audioSystem
    local ok, err = pcall(function()
        local function run(prep, secs)
            local a = fakeAudio(codes)
            _G.audioSystem = a
            Menu._resetSting()
            local m = Menu:new()
            a.clock = function() return m.brand:stingTime() end
            m:enterWithIntro()
            if prep then prep(m, a) end
            if secs then step(m, secs) end
            return m, a
        end

        local m, a = run(nil, MenuBrand.T.END + 0.1)
        t:eq("vinheta inteira: todos os sons tocam", #a.log, #cues)
        local okOrder, okTime, okVol, okPitch = true, true, true, true
        for i, r in ipairs(a.log) do
            local c = cues[i]
            if not c or r.code ~= c.code then okOrder = false
            else
                if r.t < c.t or r.t > c.t + 1 / 60 + 1e-6 then okTime = false end
                if math.abs(r.vol - c.volume) > 1e-9 then okVol = false end
                if math.abs((r.pitch or 1) - c.pitch) > 1e-9 then okPitch = false end
            end
        end
        t:truthy("vinheta inteira: mesma ordem do trailer", okOrder)
        t:truthy("vinheta inteira: cada som no seu quadro (atraso < 1 quadro)", okTime)
        t:truthy("vinheta inteira: volume de cada som = tabela", okVol)
        t:truthy("vinheta inteira: tom de cada som = tabela", okPitch)
        t:truthy("vinheta inteira: fim natural nao corta o ultimo brilho", a:sounding() > 0)

        m, a = run(nil, MenuBrand.T.FLASH + 0.2)
        local before = #a.log
        t:truthy("pulo: havia som tocando", a:sounding() > 0)
        m:skipIntro()
        step(m, 0.04)
        local fading = true
        for _, r in ipairs(a.log) do
            if r.src.playing and r.src.vol > 0.75 * r.vol then fading = false end
        end
        t:truthy("pulo: sons baixando em fade curto", a:sounding() > 0 and fading)
        step(m, 0.1)
        t:eq("pulo: nenhum som pendurado depois de 0,14 s", a:sounding(), 0)
        step(m, 4.0)
        t:eq("pulo: nenhum som novo depois do pulo", #a.log, before)

        m, a = run(nil, 0.5)
        m:mousepressed(960, 600, 1)
        step(m, 0.2)
        t:eq("clique antes do vortice: silencio", #a.log, 0)

        m, a = run(function(mm) mm:update(1.0) end, 0.1)
        t:eq("engasgo de 1 s: vortice atrasado nao toca", #a.log, 0)
        step(m, 1.5)
        t:truthy("engasgo: sons seguintes voltam no tempo", #a.log > 0)

        m, a = run(nil, 2.0)
        _G.gameSettings.reducedMotion = true
        step(m, 0.2)
        _G.gameSettings.reducedMotion = false
        t:eq("movimento reduzido no meio: corta os sons", a:sounding(), 0)

        _G.gameSettings.reducedMotion = true
        m, a = run(nil, MenuBrand.T.END + 0.1)
        _G.gameSettings.reducedMotion = false
        t:eq("movimento reduzido: sem vinheta, sem sons", #a.log, 0)
    end)
    _G.audioSystem = realAudio
    _G.gameSettings.reducedMotion = false
    t:check("sons do logo sem excecao" .. (ok and "" or (": " .. tostring(err))), ok)
end

local function blocksUniform(img, x0, y0, bw, bh, P)
    local broken = 0
    for by = 0, bh - 1 do
        for bx = 0, bw - 1 do
            local px, py = x0 + bx * P, y0 + by * P
            local r, g, b = img:getPixel(px, py)
            for dy = 0, P - 1 do
                for dx = 0, P - 1 do
                    local r2, g2, b2 = img:getPixel(px + dx, py + dy)
                    if r2 ~= r or g2 ~= g or b2 ~= b then broken = broken + 1 end
                end
            end
        end
    end
    return broken
end

function M.run()
    TK.bootstrap()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local t = TK.new("menu: logotipo do trailer + entrada + vida parada")
    _G.gameSettings = _G.gameSettings or {}
    local prevReduced = _G.gameSettings.reducedMotion
    _G.gameSettings.reducedMotion = false
    local UiScale = require("src.ui.UiScale")
    UiScale.force(nil)
    UiScale.adoptDefaults()
    local MenuBrand = require("src.ui.MenuBrand")
    local Menu = require("components.Menu")
    local restore = fakeWindow(1920, 1080)

    local ok, err = pcall(function()
        t:truthy("arte do logotipo carrega", MenuBrand.available())
        t:truthy("shaders da entrada compilam", MenuBrand.canSting())

        Menu._resetSting()
        local menu = Menu:new()
        menu:enterWithIntro()
        t:truthy("primeira entrada toca a vinheta", menu:isIntroPlaying())
        step(menu, 1.0)
        t:eq("botoes escondidos no meio da vinheta", menu.intro.alphaButtons.play, 0)
        t:truthy("fundo ainda escuro antes do clarao", (menu.intro.alphaBg or 1) < 0.01)
        t:truthy("tecla pula a vinheta", menu:skipIntro())
        t:truthy("depois de pular nao toca mais", not menu:isIntroPlaying())
        t:eq("botoes no estado final", menu.intro.alphaButtons.play, 1)
        t:eq("botoes sem deslocamento", menu.intro.buttonOffsetY.quit, 0)
        t:eq("fundo no estado final", menu.intro.alphaBg, 1)
        t:truthy("segundo pulo nao consome a tecla", not menu:skipIntro())

        menu.brand.sweeps, menu.brand.twinkles, menu.brand.emberT0 = {}, {}, math.huge
        local a = shotTitle(menu, 1920, 1080)
        Menu._resetSting()
        local ref = Menu:new()
        ref:enterWithIntro()
        step(ref, MenuBrand.T.END + 0.1)
        t:truthy("vinheta termina sozinha", not ref:isIntroPlaying())
        menu.brand.sweeps, ref.brand.sweeps = {}, {}
        menu.brand.twinkles, ref.brand.twinkles = {}, {}
        menu.brand.emberT0, ref.brand.emberT0 = math.huge, math.huge
        local b = shotTitle(ref, 1920, 1080)
        t:eq("pular cai no mesmo quadro final da vinheta inteira", diff(a, b), 0)
        a:release(); b:release()

        menu:enterWithIntro()
        t:truthy("voltar ao menu nao repete a vinheta", not menu:isIntroPlaying())

        Menu._resetSting()
        local clicked = Menu:new()
        clicked:enterWithIntro()
        step(clicked, 0.5)
        clicked:mousepressed(960, 600, 1)
        t:truthy("clique pula a vinheta", not clicked:isIntroPlaying())
        t:eq("clique de pulo nao aciona botao", clicked.visible, true)

        Menu._resetSting()
        local mid = Menu:new()
        mid:enterWithIntro()
        step(mid, 0.8)
        _G.gameSettings.reducedMotion = true
        step(mid, 1 / 60)
        t:truthy("movimento reduzido no meio encerra a vinheta", not mid:isIntroPlaying())

        Menu._resetSting()
        local calm = Menu:new()
        calm:enterWithIntro()
        t:truthy("movimento reduzido: sem vinheta", not calm:isIntroPlaying())
        t:eq("movimento reduzido: botoes ja visiveis ou em fade curto", type(calm.intro.alphaButtons.play), "number")
        step(calm, 1.0)
        local s1 = shotTitle(calm, 1920, 1080)
        step(calm, 13.0)
        local s2 = shotTitle(calm, 1920, 1080)
        t:eq("movimento reduzido: logotipo parado (13 s depois, mesmo quadro)", diff(s1, s2), 0)
        s1:release(); s2:release()
        _G.gameSettings.reducedMotion = false

        local live = Menu:new()
        live:enterWithIntro()
        step(live, 0.2)
        local sawSweep = false
        for _ = 1, 60 * 14 do
            step(live, 1 / 60)
            if live.brand:sweepP() then sawSweep = true end
        end
        t:truthy("parado: varredura dourada aparece em ate 14 s", sawSweep)
        local nSweeps = 0
        local was = false
        for _ = 1, 60 * 40 do
            step(live, 1 / 60)
            local on = live.brand:sweepP() ~= nil
            if on and not was then nSweeps = nSweeps + 1 end
            was = on
        end
        t:truthy(("parado: varredura a cada 8 a 12 s (%d em 40 s)"):format(nSweeps), nSweeps >= 3 and nSweeps <= 5)
        local BootScene = require("src.scenes.BootScene")
        local function splashTitle()
            local done = false
            BootScene.init({ onComplete = function() done = true end })
            for _ = 1, 60 * 12 do
                _G.EventManager.update(1 / 60)
                BootScene.update(1 / 60)
                if BootScene.phase() == "splash" and BootScene.splashTime() > 0.2 then break end
            end
            local n = BootScene.titleCount()
            BootScene.skip()
            return n, done
        end
        MenuBrand.resetSting()
        t:truthy("vinheta pendente antes do 1o menu", MenuBrand.stingPending())
        t:eq("boot nao carimba o titulo quando a vinheta vem", (splashTitle()), 0)
        MenuBrand.markStingPlayed()
        t:truthy("boot carimba o titulo quando a vinheta ja passou", (splashTitle()) > 0)
        MenuBrand.resetSting()
    end)
    stingSfx(t, Menu, MenuBrand)
    restore()
    t:check("sem excecao na entrada" .. (ok and "" or (": " .. tostring(err))), ok)

    for _, sz in ipairs(SIZES) do
        local w, h = sz[1], sz[2]
        local rs = fakeWindow(w, h)
        local ok2, err2 = pcall(function()
            local k = UiScale.k(w, h)
            local vw, vh = math.floor(w / k + 0.5), math.floor(h / k + 0.5)
            local L = MenuBrand.layout(vw, vh, k)
            local tag = ("%dx%d"):format(w, h)
            t:truthy(tag .. ": escala inteira >= 1 (P=" .. L.P .. ")", L.P >= 1 and L.P == math.floor(L.P))
            t:truthy(tag .. ": origem no pixel fisico", L.ox == math.floor(L.ox) and L.oy == math.floor(L.oy))
            local D = require("src.data.menu_brand")
            t:truthy(tag .. ": palavra dentro de wordMaxW da largura", D.word.w * L.P <= w * MenuBrand.ZONE.wordMaxW + 0.5)
            local want = OLD_P[tag] and math.ceil(OLD_P[tag] * 1.5) or 1
            t:truthy(("%s: palavra >= 1,5x o tamanho antigo (P=%d, antes %s)"):format(tag, L.P, tostring(OLD_P[tag])),
                L.P >= want)
            t:truthy(tag .. ": selo no maximo 2 degraus menor que a palavra (Ps=" .. L.Ps .. ")",
                L.Ps >= 1 and L.Ps <= L.P and L.Ps >= L.P - MenuBrand.ZONE.sealDrop)
            local bottomV = (L.top + L.total) / k
            local SaveManager = require("engine.SaveManager")
            local realHasRun = SaveManager.hasRun
            for _, withSave in ipairs({ false, true }) do
                SaveManager.hasRun = function() return withSave end
                local m = Menu:new()
                local minY, n = math.huge, 0
                for _, b in pairs(m.buttons) do
                    n = n + 1
                    minY = math.min(minY, b.y)
                    t:truthy(("%s %s: botao dentro da tela (%.0f <= %d)"):format(tag, withSave and "com save" or "sem save",
                        b.y + b.height, vh), b.y + b.height <= vh + 0.5)
                end
                t:eq(("%s %s: numero de botoes"):format(tag, withSave and "com save" or "sem save"), n, withSave and 6 or 5)
                t:truthy(("%s %s: logo acima do 1o botao (%.0f <= %.0f)"):format(tag, withSave and "com save" or "sem save",
                    bottomV, minY), bottomV <= minY)
            end
            SaveManager.hasRun = realHasRun
            local menu = Menu:new()
            step(menu, 0.1)
            menu.brand.sweeps, menu.brand.twinkles, menu.brand.emberT0 = {}, {}, math.huge
            local img = shotTitle(menu, w, h)
            local x, y, ww, hh, P = menu.brand:wordRect()
            local px0, py0 = math.floor(x * k + 0.5), math.floor(y * k + 0.5)
            t:eq(tag .. ": P do desenho = P do layout", P, L.P)
            t:eq(tag .. ": palavra em blocos PxP uniformes (nearest, inteiro)",
                blocksUniform(img, px0, py0, 64, 12, P), 0)
            img:release()
        end)
        rs()
        t:check(("%dx%d sem excecao"):format(w, h) .. (ok2 and "" or (": " .. tostring(err2))), ok2)
    end

    _G.gameSettings.reducedMotion = prevReduced
    Menu._resetSting()
    UiScale.force(1)
    return t:done()
end

return M
