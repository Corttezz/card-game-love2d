local TK = require("tools.testkit")
local FA = require("tools.fake_audio")

local M = {}
local DT = 1 / 30

local function fakeAudio()
    local A = { sources = {}, plays = {}, groups = { ambient = 1, sfx = 1, music = 1 } }
    function A:loadSound(code, path, opts) self.sources[code] = { path = path, opts = opts or {} } end
    function A:play(code, opts)
        self.plays[#self.plays + 1] = { code = code, loop = opts and opts.loop }
        return { stop = function() self.stopped = (self.stopped or 0) + 1 end }
    end
    function A:setInstanceGain(code, src, g) self.lastGain = self.lastGain or {}; self.lastGain[code] = g end
    function A:count(code)
        local n = 0
        for _, p in ipairs(self.plays) do if p.code == code then n = n + 1 end end
        return n
    end
    return A
end

local function unit(t)
    local AI = require("src.scenes.ActIntroScene")
    local real = _G.audioSystem
    local settings0 = _G.gameSettings
    _G.gameSettings = {}
    _G.ACT_INTRO_FORCE = true
    AI._resetCache()

    t:truthy("ato 1 tem cena", AI.available(1))
    t:falsy("ato sem dados nao tem cena (7)", AI.available(7))
    for n = 2, 6 do
        t:truthy("ato " .. n .. " tem cena", AI.available(n))
        local Dn = require("src.data.act_intros")[n]
        t:eq("ato " .. n .. ": 2 SFX", Dn and #Dn.sfx, 2)
        _G.audioSystem = fakeAudio()
        local ok = AI.start(n, function() end)
        t:truthy("ato " .. n .. ": abre", ok)
        local okd = true
        for _ = 1, 20 do AI.update(DT) end
        local cv = love.graphics.newCanvas(love.graphics.getDimensions())
        love.graphics.setCanvas(cv); okd = pcall(AI.draw); love.graphics.setCanvas()
        t:truthy("ato " .. n .. ": desenha", okd)
        t:eq("ato " .. n .. ": nome do bioma no titulo", AI._state().name,
            require("src.systems.ActSystem").getActName(n))
        AI.finish()
    end
    t:falsy("ato nil nao tem cena", AI.available(nil))
    _G.gameSettings.actIntros = false
    t:falsy("opcao desligada: sem cena", AI.available(1))
    local called = false
    t:falsy("opcao desligada: start devolve false e nao chama o fim", AI.start(1, function() called = true end))
    t:falsy("opcao desligada: o fim nao e chamado (quem chama segue direto)", called)
    _G.gameSettings.actIntros = nil
    _G.ACT_INTRO_FORCE = nil
    t:falsy("ferramenta sem janela pula a cena sem a forca", AI.available(1))
    _G.ACT_INTRO_FORCE = true

    local D = require("src.data.act_intros")
    local saveDir = D[1].dir
    D[1].dir = "assets/sprites/act_intro/nao_existe/"
    AI._resetCache()
    t:falsy("arte faltando: sem cena", AI.available(1))
    t:falsy("arte faltando: start devolve false", AI.start(1, function() end))
    D[1].dir = saveDir
    AI._resetCache()

    local A = fakeAudio(); _G.audioSystem = A
    local done = 0
    t:truthy("start abre a cena", AI.start(1, function() done = done + 1 end))
    t:truthy("cena ativa", AI.isActive())
    t:truthy("SFX registrados (vento, corvos, sino)",
        A.sources.actIntro1Wind and A.sources.actIntro1Crows and A.sources.actIntroChime and true or false)
    t:eq("vento no grupo ambiente", A.sources.actIntro1Wind and A.sources.actIntro1Wind.opts.group, "ambient")
    t:falsy("clique logo na abertura e ignorado (nao pula sem querer)", AI.skip())
    local W, H = love.graphics.getDimensions()
    local canvas = love.graphics.newCanvas(W, H)
    local okDraw = true
    local secs = 0
    while AI.isActive() and secs < 20 do
        AI.update(DT); secs = secs + DT
        if math.floor(secs / DT) % 15 == 0 then
            love.graphics.setCanvas(canvas)
            okDraw = pcall(AI.draw) and okDraw
            love.graphics.setCanvas()
        end
    end
    t:truthy("desenha sem erro durante a cena", okDraw)
    t:near("termina sozinha na duracao", secs, AI.DURATION, 0.1)
    t:eq("fim chamado uma vez", done, 1)
    t:eq("vento tocou uma vez, em loop", A:count("actIntro1Wind"), 1)
    t:eq("corvos tocaram uma vez", A:count("actIntro1Crows"), 1)
    t:eq("sino tocou uma vez (fim do nome)", A:count("actIntroChime"), 1)
    t:truthy("o loop do vento e parado no fim", (A.stopped or 0) >= 1)
    t:truthy("o vento sai com o fade (ganho ~0 no fim)", A.lastGain and A.lastGain.actIntro1Wind ~= nil
        and A.lastGain.actIntro1Wind < 0.1)

    A = fakeAudio(); _G.audioSystem = A
    done = 0
    AI.start(1, function() done = done + 1 end)
    for _ = 1, 30 do AI.update(DT) end
    t:truthy("pular depois de 1 s funciona", AI.skip())
    local s2 = 0
    while AI.isActive() and s2 < 2 do AI.update(DT); s2 = s2 + DT end
    t:truthy("pular encerra em ate 0,4 s (fade curto)", s2 <= 0.4 + 1e-6)
    t:eq("pular chama o fim uma vez", done, 1)
    t:falsy("tecla depois do fim nao faz nada", AI.keypressed("space"))

    _G.gameSettings.reducedMotion = true
    AI.start(1, function() end)
    t:truthy("movimento reduzido: cena parada", AI._state().still)
    AI.finish()
    _G.gameSettings.reducedMotion = nil

    local under = love.graphics.newCanvas(W, H)
    local afterCalls = 0
    A = fakeAudio(); _G.audioSystem = A
    done = 0
    t:truthy("com a tela anterior: abre", AI.start(2, function() done = done + 1 end,
        { under = under, after = function() afterCalls = afterCalls + 1 end }))
    t:truthy("entrada: comeca escurecendo a tela anterior (tempo negativo)", AI.time() < 0)
    t:truthy("entrada: segura a musica", AI.holdsMusic())
    t:falsy("entrada: o clique que fechou as recompensas nao pula a cena", AI.mousepressed(10, 10, 1))
    t:falsy("entrada: tecla segurada nao pula", AI.keypressed("return"))
    t:falsy("entrada: botao do controle nao pula", AI.gamepadpressed(nil, "a"))
    love.graphics.setCanvas(canvas)
    local okLead = pcall(AI.draw)
    love.graphics.setCanvas()
    t:truthy("entrada: desenha a tela anterior", okLead)
    for _ = 1, math.floor(AI.LEAD / DT) - 1 do AI.update(DT) end
    t:eq("entrada: nenhum som antes da cena", #A.plays, 0)
    while AI.isActive() and AI.time() < AI.MUSIC_AT - 0.1 do AI.update(DT) end
    t:truthy("o ambiente vem antes: a musica ainda espera", AI.holdsMusic())
    t:truthy("o ambiente vem antes: o vento ja toca", A:count("actIntro2Wind") == 1)
    while AI.isActive() and AI.time() < AI.MUSIC_AT + 0.1 do AI.update(DT) end
    t:falsy("depois de 1 s a musica do ato entra", AI.holdsMusic())
    local okOut = true
    local total = AI.LEAD + AI.MUSIC_AT + 0.1
    while AI.isActive() and total < 20 do
        AI.update(DT); total = total + DT
        if AI.isActive() and AI.time() > AI.DURATION - AI.FADE_OUT then
            love.graphics.setCanvas(canvas)
            okOut = pcall(AI.draw) and okOut
            love.graphics.setCanvas()
        end
    end
    t:truthy("saida: desenha sem erro", okOut)
    t:truthy("saida: cruza com a encruzilhada (desenha o destino)", afterCalls > 0)
    t:near("com a entrada, a cena dura a entrada + a duracao", total, AI.LEAD + AI.DURATION, 0.1)
    t:eq("com a entrada: fim chamado uma vez", done, 1)

    local I18n = require("src.i18n.I18n")
    local loc0 = I18n.current
    local Dall = require("src.data.act_intros")
    for _, loc in ipairs({ "en", "pt_BR", "es", "fr", "de" }) do
        I18n.setLocale(loc, true)
        for n = 1, 6 do
            local name = require("src.systems.ActSystem").getActName(n)
            local chime = AI.TITLE_AT + (require("utf8").len(name) or #name) / AI.CPS
            for _, sx in ipairs(Dall[n].sfx) do
                if not sx.loop then
                    t:truthy(("%s ato %d: %s longe do sino do titulo (%.1f s x %.1f s)"):format(loc, n, sx.code,
                        sx.at, chime), math.abs(sx.at - chime) >= 1.0)
                end
            end
        end
    end
    if loc0 then I18n.setLocale(loc0, true) end

    _G.audioSystem = real
    _G.gameSettings = settings0
    _G.ACT_INTRO_FORCE = nil
end

local function flow(t)
    local CheatMode = require("src.systems.CheatMode")
    FA.install()
    local okLoad, errLoad = pcall(love.load, {})
    t:truthy("boot completo" .. (okLoad and "" or (": " .. tostring(errLoad))), okLoad)
    if not okLoad then FA.uninstall(); return end
    CheatMode.activate({ isolate = false })
    if _G.gameSettings then _G.gameSettings.tipsEnabled = false end
    local api = _G.__cheatApi
    local function step(n)
        for _ = 1, n or 1 do
            love.update(DT); FA.advance(DT)
            love.graphics.origin(); pcall(love.draw)
        end
    end
    local AI = require("src.scenes.ActIntroScene")
    AI._resetCache()

    _G.ACT_INTRO_FORCE = nil
    require("src.ui.InputFocus").hideAll()
    api.startGame("warrior", 0)
    t:eq("sem cena: startGame vai direto para a run", api.state(), "playing")
    api.returnToMenu(); step(30)

    _G.ACT_INTRO_FORCE = true
    require("src.ui.InputFocus").hideAll()
    api.startGame("warrior", 0)
    t:eq("run nova abre a cena do ato 1", api.state(), "actIntro")
    step(20)
    t:eq("a run fica parada atras da cena", api.state(), "actIntro")
    love.keypressed("space")
    step(1)
    t:falsy("tecla durante a entrada (tela anterior escurecendo) nao pula", AI._state().skipAt ~= nil)
    step(20)
    love.keypressed("space")
    step(20)
    t:eq("pular leva para a run", api.state(), "playing")
    step(30)

    local D = require("src.data.act_intros")
    AI._resetCache()
    local run = api.game().runManager.currentRun
    run.floorInAct = require("src.systems.MapManager").FLOORS_PER_ACT
    run.pendingNodes = nil
    api.showMapSelection()
    t:eq("chefe morto: o ato avancou para 2", run.actNumber, 2)
    t:eq("chefe morto: cena do ato 2 antes da encruzilhada", api.state(), "actIntro")
    love.mousepressed(200, 200, 1)
    love.mousereleased(200, 200, 1)
    love.keypressed("return")
    step(1)
    t:eq("o clique que fechou as recompensas nao vaza para a cena", api.state(), "actIntro")
    t:falsy("nem marca o pulo", AI._state().skipAt ~= nil)
    t:truthy("entrada pela tela das recompensas (com retrato)", AI._state().under ~= nil)
    local MDir = require("src.systems.MusicDirector")
    t:eq("musica: silencio no comeco da cena", MDir.pick("actIntro", run), MDir.SILENCE)
    while api.state() == "actIntro" and AI.time() < AI.MUSIC_AT + 0.2 do step(1) end
    t:eq("musica: o ato 2 entra depois do ambiente", MDir.pick("actIntro", run), "musicAct2")
    t:eq("o estagio salvo e a encruzilhada (Continuar nunca reabre a cena)", run.stage, "fork")
    local secs = 0
    while api.state() == "actIntro" and secs < 15 do step(1); secs = secs + DT end
    t:eq("a cena termina sozinha na encruzilhada", api.state(), "mapSelection")
    t:truthy("caminhos do ato 2 prontos", api.game().runManager:getPendingNodes() ~= nil)

    local save3 = D[3]
    D[3] = nil
    run.floorInAct = require("src.systems.MapManager").FLOORS_PER_ACT
    run.pendingNodes = nil
    AI._resetCache()
    api.showMapSelection()
    t:eq("ato sem arte: direto na encruzilhada", api.state(), "mapSelection")
    D[3] = save3
    AI._resetCache()

    api.returnToMenu(); step(10)
    _G.ACT_INTRO_FORCE = nil
    CheatMode.deactivate()
    if _G.audioSystem and _G.audioSystem.stopAll then pcall(_G.audioSystem.stopAll, _G.audioSystem) end
    FA.uninstall()
end

function M.run()
    TK.bootstrap()
    local t = TK.new("cena de abertura de ato")
    local ok, err = pcall(unit, t)
    t:truthy("unidade sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    ok, err = pcall(flow, t)
    t:truthy("fluxo sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    _G.ACT_INTRO_FORCE = nil
    return t:done()
end

return M
