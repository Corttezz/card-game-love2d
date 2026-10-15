local TK = require("tools.testkit")
local FA = require("tools.fake_audio")

local M = {}

local DT = 1 / 30
local SILENCE = "<silencio>"

local t
local frame, clock = 0, 0
local scene = "boot"
local violations = {}
local violationOrder = {}
local timeline = {}
local lastSig = nil

local function api() return _G.__cheatApi end
local function state() return api() and api().state() end
local function game() return api() and api().game() end
local function run()
    local g = game()
    return g and g.runManager and g.runManager.currentRun
end
local function audio() return _G.audioSystem end
local function CM() return require("src.systems.CheatMode") end
local function MD() return require("src.systems.MusicDirector") end

local function codeIndex()
    local idx = {}
    local a = audio()
    if not a then return idx end
    for code, e in pairs(a.sources) do
        for _, inst in ipairs(e.instances) do idx[inst] = code end
    end
    return idx
end

local function finalVolume(code)
    local a = audio()
    local e = a.sources[code]
    return (e.baseVolume or 1) * (a.groups[e.group] or 1) * (a.groups.master or 1)
end

local function snapshot()
    local a = audio()
    local idx = codeIndex()
    local snap = { music = {}, musicList = {}, ambient = {}, loops = {}, all = {} }
    for _, s in ipairs(FA.playing()) do
        local code = idx[s]
        if code then
            local e = a.sources[code]
            snap.all[#snap.all + 1] = { code = code, src = s }
            if e.group == "music" then
                if s.vol > 0.002 then
                    snap.musicList[#snap.musicList + 1] = { code = code, vol = s.vol, src = s }
                    snap.music[code] = s
                end
            elseif e.group == "ambient" then
                snap.ambient[#snap.ambient + 1] = code
            end
            if s.looping and e.group ~= "music" then snap.loops[#snap.loops + 1] = code end
        end
    end
    table.sort(snap.musicList, function(x, y) return x.code < y.code end)
    return snap
end

local function violate(msg)
    local key = scene .. " :: " .. msg
    if not violations[key] then
        violations[key] = { n = 0, first = clock, state = tostring(state()) }
        violationOrder[#violationOrder + 1] = key
    end
    violations[key].n = violations[key].n + 1
end

local function checkFrame()
    local a = audio()
    if not a then return end
    local snap = snapshot()
    local list = snap.musicList
    local seen = {}
    for _, m in ipairs(list) do
        if seen[m.code] then violate("duas instancias da mesma faixa: " .. m.code) end
        seen[m.code] = true
        if m.vol > finalVolume(m.code) * 1.01 + 1e-6 then
            violate(("faixa acima do volume das configuracoes: %s %.3f > %.3f"):format(
                m.code, m.vol, finalVolume(m.code)))
        end
    end
    if #list > 2 then
        local names = {}
        for _, m in ipairs(list) do names[#names + 1] = m.code end
        violate("tres ou mais faixas audiveis: " .. table.concat(names, "+"))
    elseif #list == 2 then
        local cf = a.musicCrossfade
        local ok = cf and ((cf.from == list[1].code and cf.to == list[2].code)
            or (cf.from == list[2].code and cf.to == list[1].code))
        if not ok then
            violate("duas faixas audiveis fora de um crossfade: " .. list[1].code .. "+" .. list[2].code)
        end
    end
    local parts = {}
    for _, m in ipairs(list) do parts[#parts + 1] = m.code end
    local sig = tostring(state()) .. " | " .. (#parts > 0 and table.concat(parts, "+") or SILENCE)
    if sig ~= lastSig then
        lastSig = sig
        timeline[#timeline + 1] = ("%7.2fs [%s] %s"):format(clock, scene, sig)
    end
end

local function step()
    love.update(DT)
    FA.advance(DT)
    frame = frame + 1
    clock = clock + DT
    if frame % 3 == 0 then
        love.graphics.origin()
        love.draw()
    end
    checkFrame()
end

local function pump(secs, pred, each)
    local el = 0
    while el < secs do
        step()
        el = el + DT
        if each then each() end
        if pred and pred() then return true end
    end
    return pred and pred() or false
end

local function trackOf(code)
    return require("src.systems.MusicSections").trackOf(code)
end

local function audibleCodes()
    local out = {}
    for _, m in ipairs(snapshot().musicList) do out[#out + 1] = trackOf(m.code) end
    return out
end

local function audibleOf(track)
    for _, m in ipairs(snapshot().musicList) do
        if trackOf(m.code) == track then return m end
    end
    return nil
end

local function sectioned(track)
    return require("src.systems.MusicSections").has(track)
end

local function describe(list)
    return #list > 0 and table.concat(list, "+") or SILENCE
end

local function expectTrack(label, want, settle)
    pump(settle or 3.2)
    local got = audibleCodes()
    local wantS = want or SILENCE
    t:eq(scene .. ": " .. label .. " toca " .. wantS, describe(got), wantS)
    if want then
        local m = audibleOf(want)
        t:truthy(scene .. ": " .. label .. " em volume cheio (fade terminou)",
            m and (math.abs(m.vol - finalVolume(m.code)) < 0.005
                or (sectioned(want) and audio().musicCrossfade ~= nil)))
    end
    t:falsy(scene .. ": " .. label .. " sem crossfade pendurado", audio().musicCrossfade ~= nil
        and (audio().musicCrossfade.t or 0) > (audio().musicCrossfade.duration or 0) + 0.5)
end

local function trackSource(code)
    local e = audio().sources[code]
    return e and e.template
end

local function expectContinuous(label, code, secs, action)
    if sectioned(code) then
        local okAud = true
        if action then action() end
        pump(secs, nil, function()
            if not audibleOf(code) then okAud = false end
        end)
        t:truthy(scene .. ": " .. label .. ": " .. code .. " (secoes) segue audivel o tempo todo", okAud)
        t:eq(scene .. ": " .. label .. ": no fim so ela soa", describe(audibleCodes()), code)
        return
    end
    local src = trackSource(code)
    local stops0 = src and src.stops or 0
    local lastPos = src and src.pos or 0
    local okPos, okAud = true, true
    if action then action() end
    pump(secs, nil, function()
        if not (src and src.playing) then okAud = false return end
        if src.pos + 1e-6 < lastPos and lastPos < src.dur - 1 then okPos = false end
        lastPos = src.pos
        if not snapshot().music[code] then okAud = false end
    end)
    t:truthy(scene .. ": " .. label .. ": " .. code .. " segue audivel o tempo todo", okAud)
    t:truthy(scene .. ": " .. label .. ": " .. code .. " nao reinicia do zero",
        okPos and src and src.stops == stops0)
    t:eq(scene .. ": " .. label .. ": no fim so ela soa", describe(audibleCodes()), code)
end

local function bossCode(id)
    local c = MD().BOSS_TRACKS[id]
    if c and (audio().sources[c] or sectioned(c)) then return c end
    return MD().GENERIC_BOSS
end

local function waitState(want, secs)
    return pump(secs or 20, function() return state() == want end)
end

local function waitReady(secs)
    return pump(secs or 40, function() return CM().combatReady(true) end)
end

local function noRunSoundsInMenu(label)
    local snap = snapshot()
    t:eq(scene .. ": " .. label .. ": nenhum ambiente/clima tocando (" .. table.concat(snap.ambient, ",") .. ")",
        #snap.ambient, 0)
    t:eq(scene .. ": " .. label .. ": nenhum loop de SFX tocando (" .. table.concat(snap.loops, ",") .. ")",
        #snap.loops, 0)
    local music = {}
    for _, x in ipairs(snap.all) do
        if audio().sources[x.code].group == "music" then music[#music + 1] = x.code end
    end
    t:eq(scene .. ": " .. label .. ": so a faixa do menu existe tocando (orfas)",
        table.concat(music, "+"), "menuMusic")
end

local function setScene(name) scene = name end

local function newRun(class)
    require("src.ui.InputFocus").hideAll()
    api().startGame(class, 0)
end

local function toMenu()
    api().returnToMenu()
    waitState("menu", 2)
end

local function continueRun()
    local menu = api().screens().menu
    if menu.rebuild then pcall(menu.rebuild, menu) end
    local b = menu.buttons and menu.buttons.continueRun
    if b then b.onClick() else menu.onContinueCallback() end
end

local function ensureRun(class)
    if CM().inRun() then return end
    if state() ~= "menu" then toMenu() end
    newRun(class or "warrior")
    waitReady(30)
end

local function forkWithBoss()
    local r = run()
    local MapManager = require("src.systems.MapManager")
    CM().leaveCurrent()
    r.floorInAct = MapManager.FLOORS_PER_ACT - 1
    r.currentFloor = (r.actNumber - 1) * MapManager.FLOORS_PER_ACT + r.floorInAct
    r.pendingNodes = nil
    api().showMapSelection()
end

local function pickFork(i)
    CM().pending().forkPick = i or 1
end

local function scenarioBootMenu()
    setScene("boot")
    if state() == "boot" then
        pump(1.0)
        t:eq("abertura (IntroTube/CRT) sem musica", describe(audibleCodes()), SILENCE)
    end
    pump(1, function() return state() ~= "boot" end)
    love.keypressed("return")
    waitState("menu", 8)
    if state() ~= "menu" then
        love.keypressed("return")
        waitState("menu", 8)
    end
    setScene("menu")
    t:eq("abertura termina no menu", state(), "menu")
    expectTrack("menu", "menuMusic", 2.5)
    noRunSoundsInMenu("menu na abertura")

    setScene("menu->selecao")
    local menu = api().screens().menu
    menu._newRunConfirmed = true
    expectContinuous("Jogar abre a selecao de classe", "menuMusic", 3, function() menu:onPlayClick() end)
    menu._newRunConfirmed = false
    t:eq("estado da selecao", state(), "classSelection")
    setScene("selecao->menu")
    expectContinuous("voltar da selecao ao menu", "menuMusic", 2, function()
        local cs = api().screens().classSelect
        local back = cs.onBackToMenu
        cs:hide()
        if back then back() end
    end)
    setScene("menu->colecao")
    expectContinuous("abrir a colecao", "menuMusic", 2, function() menu:onCollectionClick() end)
    t:eq("estado da colecao", state(), "collection")
    setScene("colecao->menu")
    expectContinuous("voltar da colecao", "menuMusic", 1.5, function() toMenu() end)
    setScene("idioma")
    local I18n = require("src.i18n.I18n")
    local loc = I18n.getLocale()
    expectContinuous("trocar idioma no menu", "menuMusic", 1, function()
        I18n.setLocale(loc == "en" and "pt_BR" or "en")
        require("src.ui.FontManager").clearCache()
    end)
    I18n.setLocale(loc)
end

local function scenarioRunAct1()
    setScene("inicio de run")
    newRun("warrior")
    t:eq("run comeca jogando", state(), "playing")
    expectTrack("viagem de chegada no ato 1", "musicAct1", 2.5)
    local menuSrc = trackSource("menuMusic")
    t:falsy("a faixa do menu parou de vez", menuSrc and menuSrc.playing)
    t:truthy("chegada pronta", waitReady(30))
    t:truthy("clima do bioma toca na estrada", #snapshot().ambient > 0)

    setScene("batalha->cash out->espolios")
    expectContinuous("matar e ir ao cash out", "musicAct1", 6, function() CM().kill() end)
    if state() ~= "roundEval" then
        local g = game()
        print(("  [diag] estado=%s pronto=%s quieto=%s kill=%s hp=%s turno=%s fila=%s"):format(
            tostring(state()), tostring(CM().combatReady(false)),
            tostring(require("src.scenes.GameplayScene").isQuiet()), tostring(CM().pending().kill),
            tostring(g.enemy and g.enemy.health), tostring(g.turn),
            tostring(g.combatAnimationSystem and g.combatAnimationSystem:isBlocking())))
        local CB = require("src.systems.CombatBeats")
        local q = _G.EventManager.queues[CB.QUEUE] or {}
        print(("  [diag] seq.active=%s beats=%d foco=%s congela=%s"):format(tostring(g.combatAnimationSystem.active), #q, tostring(require("src.ui.InputFocus").activeName()), tostring(require("src.ui.InputFocus").freezesCombat("playing"))))
        for i, ev in ipairs(q) do
            if i > 4 then break end
            print(("  [diag] ev %d trigger=%s timer=%s delay=%s blocking=%s"):format(i, tostring(ev.trigger),
                tostring(ev.timer), tostring(ev.delay), tostring(ev.blocking)))
        end
    end
    t:eq("cash out", state(), "roundEval")
    local re = api().screens().roundEval
    pump(8, function() return re.cashOutReady end)
    expectContinuous("cash out -> espolios", "musicAct1", 2, function() re:_onCashOutClick() end)
    t:eq("espolios", state(), "cardReward")
    setScene("espolios->encruzilhada")
    expectContinuous("espolios -> encruzilhada", "musicAct1", 2, function() CM().advanceFloor() end)
    t:eq("encruzilhada", state(), "mapSelection")

    setScene("loja")
    CM().jumpTo("shop")
    waitState("cardReward", 20)
    expectTrack("loja", "musicShop", 3.2)
    setScene("forja aberta da loja")
    expectContinuous("abrir a forja dentro da loja", "musicShop", 2.5, function()
        _G.openCardPicker("forge")
    end)
    expectContinuous("fechar a forja e voltar a loja", "musicShop", 2.5, function()
        local rs = api().screens().rest
        local cb = rs.onClose
        rs:hide()
        if cb then cb() end
    end)
    t:eq("de volta a loja", state(), "cardReward")

    setScene("descanso")
    CM().jumpTo("rest")
    waitState("rest", 20)
    expectTrack("descanso", "musicRest", 3.2)
    setScene("evento")
    CM().jumpTo("event")
    waitState("event", 20)
    expectTrack("evento", "musicAct1", 3.2)
    setScene("forja aberta pelo evento")
    expectContinuous("evento abre o seletor de cartas", "musicAct1", 2.5, function()
        _G.openCardPicker("remove")
    end)
    local rs = api().screens().rest
    local cb = rs.onClose
    rs:hide()
    if cb then cb() end
    for _, nt in ipairs({ "elite", "mini_boss", "battle" }) do
        setScene(nt)
        CM().jumpTo(nt)
        waitState("playing", 20)
        expectTrack(nt, "musicAct1", 3.2)
    end
    waitReady(30)
    for _, key in ipairs({ "d", "j", "m", "g", "escape" }) do
        setScene("overlay [" .. key .. "] na batalha")
        expectContinuous("abrir", "musicAct1", 1.2, function() love.keypressed(key) end)
        expectContinuous("fechar", "musicAct1", 1.2, function()
            if require("src.ui.InputFocus").activeName() then love.keypressed("escape") end
        end)
    end
    pump(2.5)
    t:truthy("overlays fechados: clima volta a tocar na estrada", #snapshot().ambient > 0)
end

local function scenarioRapid()
    setScene("loja/batalha em segundos")
    for _ = 1, 3 do
        CM().jumpTo("shop")
        pump(0.6)
        CM().jumpTo("rest")
        pump(0.4)
        CM().jumpTo("battle")
        pump(0.5)
    end
    waitState("playing", 20)
    expectTrack("assentou depois das idas e voltas", "musicAct1", 3.5)

    setScene("pausa durante crossfade")
    CM().jumpTo("shop")
    waitState("cardReward", 20)
    pump(0.4)
    love.keypressed("escape")
    pump(1.5)
    t:truthy("pausa abriu", require("src.ui.InputFocus").activeName() ~= nil)
    expectTrack("crossfade termina com a pausa aberta", "musicShop", 2.5)
    love.keypressed("escape")
    pump(0.3)

    setScene("cheat: ato no meio do fade")
    CM().goToAct(3, false)
    pump(0.5)
    CM().goToAct(5, false)
    pump(0.3)
    CM().goToAct(2, false)
    expectTrack("encruzilhada do ato 2 depois de 3 pulos", "musicAct2", 3.5)
    for n = 1, 6 do
        setScene("ato " .. n)
        CM().goToAct(n, false)
        expectTrack("encruzilhada do ato " .. n, "musicAct" .. n, 3.2)
        CM().jumpTo("battle")
        waitState("playing", 20)
        expectTrack("batalha do ato " .. n, "musicAct" .. n, 1.0)
    end
end

local function scenarioBoss(act)
    setScene("bandeira do chefe A" .. act)
    CM().goToAct(act, false)
    pump(0.5)
    forkWithBoss()
    pump(1.0)
    t:truthy(scene .. ": a encruzilhada tem a bandeira do chefe", MD().forkOffersBoss(run()))
    t:truthy(scene .. ": a musica do ato some DEVAGAR (ainda soa 1 s depois)",
        snapshot().music["musicAct" .. act] ~= nil)
    expectTrack("encruzilhada com a bandeira do chefe", nil, MD().FADE_SILENCE + 0.5)

    setScene("viagem/porta/entrada A" .. act)
    pickFork(1)
    local id
    local loud = false
    local BC = require("src.ui.BossCinematic")
    local GS = require("src.scenes.GameplayScene")
    local reached = pump(60, function()
        local r = run()
        return state() == "playing" and BC.phase() == nil and GS.inBossRoom("boss")
            and r.currentNode and r.currentNode.type == "boss"
    end, function()
        local r = run()
        if state() == "playing" and r.currentNode and r.currentNode.type == "boss"
            and (not GS.inBossRoom("boss") or BC.phase() == "intro") then
            if #audibleCodes() > 0 then loud = true end
        end
    end)
    t:truthy(scene .. ": chegou na luta do chefe", reached)
    t:falsy(scene .. ": viagem, porta, salao vazio e entrada em silencio", loud)
    id = run().currentNode.enemyId
    setScene("luta do chefe A" .. act .. " (" .. tostring(id) .. ")")
    expectTrack("faixa do chefe", bossCode(id), 2.0)
    waitReady(20)
    if act == 1 and sectioned(bossCode(id)) then
        setScene("secoes do chefe A1")
        local MS = require("src.systems.MusicSections")
        local heard, order = {}, {}
        pump(45, nil, function()
            for _, m in ipairs(snapshot().musicList) do
                local sec = MS.sectionOf(m.code)
                if sec and not heard[sec] then heard[sec] = true; order[#order + 1] = sec end
            end
        end)
        t:truthy(scene .. ": a luta passa por mais de uma secao (" .. table.concat(order, ",") .. ")", #order >= 2)
        t:eq(scene .. ": abre pelo tema", order[1], MS.OPENING)
        expectTrack("depois de 45 s de luta", bossCode(id), 0.1)
        local g = game()
        g.enemy.health = math.floor(g.enemy.maxHealth * 0.4)
        local final = pump(30, function()
            local m = audibleOf(bossCode(id))
            return m and MS.isFinal(MS.sectionOf(m.code)) and not audio().musicCrossfade
        end)
        t:truthy(scene .. ": abaixo da metade da vida sobe para a final", final)
    end
    setScene("morte do chefe A" .. act)
    local code = bossCode(id)
    expectContinuous("cinematica de morte e trofeu", code, 3, function() CM().kill() end)
    if act == require("src.core.Config").TotalActs then
        waitState("victory", 30)
        t:eq(scene .. ": o ultimo chefe leva a vitoria", state(), "victory")
        expectTrack("vitoria depois do ultimo chefe", "menuMusic", 3.0)
        local loops = snapshot().loops
        t:eq(scene .. ": nenhum loop de SFX do chefe na vitoria (" .. table.concat(loops, ",") .. ")",
            #loops, 0)
        return id
    end
    waitState("roundEval", 30)
    t:eq(scene .. ": cash out depois do chefe", state(), "roundEval")
    expectContinuous("cash out do chefe", code, 1.5)
    local loops = snapshot().loops
    t:eq(scene .. ": nenhum loop de SFX do chefe depois da luta (" .. table.concat(loops, ",") .. ")",
        #loops, 0)
    return id
end

local function scenarioBossFlow()
    ensureRun()
    scenarioBoss(1)
    setScene("chefe -> ato 2")
    local re = api().screens().roundEval
    pump(8, function() return re.cashOutReady end)
    re:_onCashOutClick()
    waitState("cardReward", 10)
    pump(1)
    CM().leaveCurrent()
    api().showMapSelection()
    waitState("mapSelection", 10)
    t:eq(scene .. ": virou o ato", run().actNumber, 2)
    expectTrack("encruzilhada do ato seguinte", "musicAct2", 3.5)
    for act = 2, 6 do scenarioBoss(act) end
end

local function scenarioBossEdge()
    setScene("pausa na entrada do chefe")
    ensureRun()
    CM().goToAct(1, true)
    local BC = require("src.ui.BossCinematic")
    pump(60, function() return BC.phase() == "intro" end)
    pump(0.5)
    love.keypressed("escape")
    pump(1.5)
    t:eq(scene .. ": silencio na pausa durante a entrada", describe(audibleCodes()), SILENCE)
    love.keypressed("escape")
    waitReady(40)
    expectTrack("luta depois da pausa", bossCode(run().currentNode.enemyId), 2.0)

    setScene("matar o chefe durante a entrada")
    CM().goToAct(2, true)
    pump(60, function() return BC.phase() == "intro" end)
    pump(0.3)
    CM().winInstant()
    pump(0.2)
    CM().leaveCurrent()
    CM().jumpTo("battle")
    waitState("playing", 20)
    expectTrack("batalha seguinte", "musicAct" .. run().actNumber, 3.5)
    local loops = snapshot().loops
    t:eq(scene .. ": loops da entrada parados", #loops, 0)
end

local function scenarioSettings()
    setScene("volume")
    local a = audio()
    local m0, mu0 = a.groups.master, a.groups.music
    a:setMusicVolume(0.1)
    pump(0.2)
    local s = snapshot().musicList[1]
    t:truthy(scene .. ": volume de musica 10% chega na faixa",
        s and math.abs(s.vol - finalVolume(s.code)) < 0.002 and s.vol < 0.07)
    a:setMusicVolume(0)
    pump(0.2)
    t:eq(scene .. ": musica 0% = nada audivel", describe(audibleCodes()), SILENCE)
    a:setMusicVolume(mu0)
    a:setMasterVolume(0)
    pump(0.2)
    t:eq(scene .. ": master 0% = nada audivel", describe(audibleCodes()), SILENCE)
    local amb = 0
    for _, x in ipairs(snapshot().all) do
        if x.src.vol > 0.0001 then amb = amb + 1 end
    end
    t:eq(scene .. ": master 0% = nenhuma fonte com volume", amb, 0)
    a:setMasterVolume(m0)
    pump(0.2)
    t:eq(scene .. ": volume restaurado", a.groups.music, mu0)
end

local function scenarioContinue()
    local cases = {
        { name = "batalha", setup = function()
            CM().goToAct(2, false); CM().jumpTo("battle"); waitState("playing", 20); waitReady(30)
          end, want = function() return "musicAct2" end, st = "playing" },
        { name = "cash out", setup = function()
            CM().goToAct(3, false); CM().jumpTo("battle"); waitState("playing", 20); waitReady(30)
            CM().kill(); waitState("roundEval", 20)
          end, want = function() return "musicAct3" end, st = "roundEval" },
        { name = "espolios", setup = function()
            CM().goToAct(3, false); CM().jumpTo("battle"); waitState("playing", 20); waitReady(30)
            CM().kill(); waitState("roundEval", 20)
            local re = api().screens().roundEval
            pump(8, function() return re.cashOutReady end)
            re:_onCashOutClick(); waitState("cardReward", 10)
          end, want = function() return "musicAct3" end, st = "cardReward" },
        { name = "loja", setup = function()
            CM().goToAct(2, false); CM().jumpTo("shop"); waitState("cardReward", 20)
          end, want = function() return "musicShop" end, st = "cardReward" },
        { name = "descanso", setup = function()
            CM().goToAct(2, false); CM().jumpTo("rest"); waitState("rest", 20)
          end, want = function() return "musicRest" end, st = "rest" },
        { name = "evento", setup = function()
            CM().goToAct(4, false); CM().jumpTo("event"); waitState("event", 20)
          end, want = function() return "musicAct4" end, st = "event" },
        { name = "encruzilhada", setup = function()
            CM().goToAct(5, false); waitState("mapSelection", 10)
          end, want = function() return "musicAct5" end, st = "mapSelection" },
        { name = "encruzilhada com a bandeira do chefe", setup = function()
            CM().goToAct(2, false); pump(0.3); forkWithBoss(); waitState("mapSelection", 10)
          end, want = function() return nil end, st = "mapSelection", settle = MD().FADE_SILENCE + 0.6 },
        { name = "luta do chefe", setup = function()
            CM().goToAct(3, true); waitReady(60)
          end, want = function() return bossCode(run().currentNode.enemyId) end, st = "playing" },
    }
    for _, c in ipairs(cases) do
        setScene("Continuar: " .. c.name)
        ensureRun()
        c.setup()
        pump(0.5)
        local stage = run() and run().stage
        setScene("Continuar: " .. c.name .. " -> menu")
        toMenu()
        expectTrack("volta ao menu", "menuMusic", 3.0)
        noRunSoundsInMenu("menu depois de sair da run")
        setScene("Continuar: " .. c.name .. " (stage " .. tostring(stage) .. ")")
        continueRun()
        pump(4, function() return state() == c.st end)
        t:eq(scene .. ": retoma no estado certo", state(), c.st)
        local want = c.want()
        expectTrack("depois do Continuar", want, c.settle or 3.5)
        local menuSrc = trackSource("menuMusic")
        t:falsy(scene .. ": a faixa do menu nao sobra", menuSrc and menuSrc.playing)
    end
end

local function scenarioEnd()
    setScene("game over")
    ensureRun()
    CM().goToAct(2, false)
    CM().jumpTo("battle")
    waitState("playing", 20)
    waitReady(30)
    CM().die()
    waitState("gameOver", 20)
    t:eq(scene .. ": chegou ao game over", state(), "gameOver")
    expectTrack("game over", "menuMusic", 3.0)
    setScene("game over -> menu")
    expectContinuous("game over volta ao menu", "menuMusic", 1.5, function() toMenu() end)
    noRunSoundsInMenu("menu depois do game over")

    setScene("vitoria")
    newRun("mage")
    waitReady(30)
    CM().winCampaign()
    waitState("victory", 120)
    t:eq(scene .. ": chegou a vitoria", state(), "victory")
    expectTrack("vitoria", "menuMusic", 3.0)
    setScene("endless")
    local EndScreens = require("src.scenes.EndScreens")
    local cbs = EndScreens._callbacks and EndScreens._callbacks() or nil
    local onEndless = cbs and cbs.onEndless
    if onEndless then
        onEndless()
        waitState("roundEval", 5)
        expectTrack("cash out ao entrar no endless", "musicAct" .. require("src.core.Config").TotalActs, 3.5)
    else
        t:truthy("EndScreens expoe os callbacks para o teste", false)
    end
    setScene("endless -> menu")
    toMenu()
    expectTrack("menu", "menuMusic", 3.0)
    noRunSoundsInMenu("menu depois do endless")
end

local function scenarioCheatKeys()
    setScene("cheat: teclas")
    if state() ~= "menu" then toMenu() end
    newRun("rogue")
    waitReady(30)
    local CheatActions = require("src.ui.CheatActions")
    local keys = {
        { "b", true }, { "e", true }, { "m", true }, { "l", true }, { "d", true }, { "v", true },
        { "c", true }, { "1", true }, { "4", true }, { "2", true, true }, { "6", true }, { "f9" },
        { "f10" }, { "3", true },
    }
    for _, k in ipairs(keys) do
        local action = CheatActions.forKey(k[1], k[2] or false, k[3] or false)
        if action and CheatActions.isAvailable(action) then action.run() end
        pump(1.2)
    end
    pump(8)
    local r = run()
    local nt = r and r.currentNode and r.currentNode.type
    local want
    if state() == "mapSelection" then
        want = MD().forkOffersBoss(r) and nil or ("musicAct" .. r.actNumber)
    elseif state() == "cardReward" then want = (nt == "shop") and "musicShop" or ("musicAct" .. r.actNumber)
    elseif state() == "rest" then want = "musicRest"
    else want = "musicAct" .. r.actNumber end
    expectTrack("assentou depois das teclas do cheat", want, 3.5)

    setScene("cheat: rush")
    CM().goToAct(1, false)
    CM().jumpTo("battle")
    waitReady(30)
    CM().toggleRush()
    pump(40)
    if CM().rush then CM().toggleRush() end
    pump(1)
    setScene("cheat: rush -> menu")
    toMenu()
    expectTrack("menu depois do rush", "menuMusic", 3.0)
    noRunSoundsInMenu("menu depois do rush")
end

local function scenarioMenuRunMenu()
    setScene("menu -> run -> menu -> run")
    for i = 1, 3 do
        newRun("warrior")
        pump(0.4 + 0.3 * i)
        toMenu()
        pump(0.3 * i)
    end
    expectTrack("menu depois das idas e voltas", "menuMusic", 3.0)
    noRunSoundsInMenu("menu depois das idas e voltas")
    newRun("warrior")
    expectTrack("run depois das idas e voltas", "musicAct1", 3.0)
    toMenu()
    expectTrack("menu", "menuMusic", 3.0)
end

local function report()
    print("\n  -- linha do tempo (estado | faixas audiveis) --")
    local from = math.max(1, #timeline - 400)
    for i = from, #timeline do print("  " .. timeline[i]) end
    print("\n  -- violacoes por quadro --")
    for _, k in ipairs(violationOrder) do
        local v = violations[k]
        print(("  %s  (x%d, primeira em %.2fs, estado %s)"):format(k, v.n, v.first, v.state))
    end
end

function M.run()
    TK.bootstrap()
    t = TK.new("musica: fluxo real do jogo (love.load + fontes falsas)")
    local CheatMode = require("src.systems.CheatMode")
    local mouse = { love.mouse.getPosition, love.mouse.getX, love.mouse.getY }
    FA.install()
    if _G.EventManager and _G.EventManager.clear then _G.EventManager.clear() end
    pcall(function() require("src.systems.CombatBeats").clear() end)
    pcall(function() require("src.systems.MusicSections")._reset() end)
    local MDm = require("src.systems.MusicDirector")
    MDm._current, MDm._lastWanted = nil, nil
    local ok, err = pcall(function()
        local okLoad, errLoad = pcall(love.load, {})
        t:truthy("boot completo" .. (okLoad and "" or (": " .. tostring(errLoad))), okLoad)
        if not okLoad then return end
        CheatMode.activate({ isolate = false })
        if _G.gameSettings then _G.gameSettings.tipsEnabled = false end
        require("src.systems.WeatherAudio")._reset()
        require("src.systems.PlaceAudio")._reset()
        local only = os.getenv("MUSIC_FLOW_ONLY")
        local steps = {
            { "boot", scenarioBootMenu }, { "act1", scenarioRunAct1 }, { "rapid", scenarioRapid },
            { "settings", scenarioSettings }, { "boss", scenarioBossFlow }, { "bossedge", scenarioBossEdge },
            { "continue", scenarioContinue }, { "end", scenarioEnd }, { "cheat", scenarioCheatKeys },
            { "menurun", scenarioMenuRunMenu },
        }
        for i, s in ipairs(steps) do
            if i == 1 or not only or only:find(s[1], 1, true) then
                local okS, errS = pcall(s[2])
                t:truthy("cenario " .. s[1] .. " rodou sem erro" .. (okS and "" or (": " .. tostring(errS))), okS)
                if not okS and api() then pcall(toMenu) end
            end
        end
    end)
    CheatMode.deactivate()
    t:eq("nenhuma violacao por quadro (duas faixas, volume acima do ajuste)", #violationOrder, 0)
    if #violationOrder > 0 or t.fail > 0 or os.getenv("MUSIC_FLOW_VERBOSE") then report() end
    love.mouse.getPosition, love.mouse.getX, love.mouse.getY = mouse[1], mouse[2], mouse[3]
    if _G.audioSystem and _G.audioSystem.stopAll then pcall(_G.audioSystem.stopAll, _G.audioSystem) end
    FA.uninstall()
    t:truthy("suite sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    return t:done()
end

return M
