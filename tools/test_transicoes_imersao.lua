local TK = require("tools.testkit")
local FA = require("tools.fake_audio")

local M = {}
local DT = 1 / 30

local function unit(t)
    local FS = require("src.ui.FlashShader")
    FS.update(5)
    FS.trigger(0.6, 0.3, 0.1)
    t:near("flash com subida: nao estoura no quadro do gatilho", FS.intensity(), 0, 1e-6)
    FS.update(0.05)
    local mid = FS.intensity()
    t:truthy(("flash com subida: no meio da subida fica entre 0 e o alvo (%.2f)"):format(mid), mid > 0 and mid < 0.6)
    FS.update(0.06)
    t:near("flash com subida: chega no alvo", FS.intensity(), 0.6, 0.02)
    FS.update(1)
    t:near("flash com subida: depois some", FS.intensity(), 0, 1e-3)
    FS.trigger(0.5, 0.3)
    t:near("flash sem subida continua instantaneo (outros usos)", FS.intensity(), 0.5, 1e-6)
    FS.update(5)

    local MM = require("src.systems.MusicMoments")
    t:truthy("sinceSting sem sting e infinito", MM.sinceSting("nao_existe") == math.huge)
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
    local function pump(secs, pred)
        local el = 0
        while el < secs do
            step(1); el = el + DT
            if pred and pred() then return true end
        end
        return pred and pred() or false
    end
    local WR = require("src.ui.WorldRoad")
    local AI = require("src.scenes.ActIntroScene")
    local SF = require("src.ui.StateFade")
    local FS = require("src.ui.FlashShader")
    local MapManager = require("src.systems.MapManager")

    _G.ACT_INTRO_FORCE = true
    require("src.ui.InputFocus").hideAll()
    api.startGame("warrior", 0)
    pump(12, function() return api.state() == "playing" end)
    pump(3)
    local run = api.game().runManager.currentRun

    for act = 1, 5 do
        CheatMode.leaveCurrent()
        run.floorInAct = MapManager.FLOORS_PER_ACT
        run.currentFloor = (run.actNumber - 1) * MapManager.FLOORS_PER_ACT + run.floorInAct
        run.pendingNodes = nil
        pump(0.3)
        AI._resetCache()
        api.showMapSelection()
        local n = act + 1
        t:eq(("ato %d->%d: cena abriu"):format(act, n), api.state(), "actIntro")
        t:eq(("ato %d->%d: o bioma ja e o do ato novo quando a cena abre"):format(act, n), WR._biomeIndex, n)
        t:falsy(("ato %d->%d: sem mistura com o bioma antigo"):format(act, n), WR._blend ~= nil)
        local ghosts = 0
        for _, p in ipairs(WR._props or {}) do if p.ghost or p.swapT then ghosts = ghosts + 1 end end
        t:eq(("ato %d->%d: nenhum prop do bioma antigo sumindo"):format(act, n), ghosts, 0)
        pump(15, function() return api.state() == "mapSelection" end)
        t:eq(("ato %d->%d: encruzilhada depois da cena"):format(act, n), api.state(), "mapSelection")
        t:eq(("ato %d->%d: a encruzilhada esta no bioma novo"):format(act, n), WR._biomeIndex, n)
        t:falsy(("ato %d->%d: e sem mistura (nao volta ao bioma antigo)"):format(act, n), WR._blend ~= nil)
    end

    local actNow = run.actNumber
    api.returnToMenu()
    pump(2)
    local menu = api.screens().menu
    if menu.rebuild then pcall(menu.rebuild, menu) end
    local b = menu.buttons and menu.buttons.continueRun
    if b then b.onClick() elseif menu.onContinueCallback then menu.onContinueCallback() end
    pump(10, function() return api.state() == "mapSelection" end)
    local run2 = api.game().runManager.currentRun
    t:eq("Continuar na encruzilhada depois da troca: volta na encruzilhada", api.state(), "mapSelection")
    t:eq("Continuar: mesmo ato", run2 and run2.actNumber, actNow)
    pump(0.2)
    t:eq("Continuar: carrega o bioma do ato novo", WR._biomeIndex, actNow)
    t:falsy("Continuar: sem mistura de biomas", WR._blend ~= nil)

    _G.ACT_INTRO_FORCE = nil
    CheatMode.jumpTo("battle")
    pump(30, function() return api.state() == "playing" and CheatMode.combatReady(true) end)
    pump(0.5)
    FS.update(5)
    api.showRoundEval()
    t:eq("cash out: entra na hora (sem espera a mais)", api.state(), "roundEval")
    t:truthy("cash out: funde a partir do ultimo quadro", SF.isActive())
    t:near("cash out: sem estouro branco", FS.intensity(), 0, 1e-6)
    pump(0.25)
    local a1 = SF.alpha()
    t:truthy(("cash out: a fusao vai sumindo (%.2f)"):format(a1), a1 > 0 and a1 < 1)
    pump(0.3)
    t:falsy("cash out: fusao termina em ate 0,6 s", SF.isActive())
    local re = api.screens().roundEval
    pump(12, function() return re.cashOutReady end)
    t:truthy("cash out: botao pronto", re.cashOutReady)
    t:truthy(("botao do cash out: o brilho sobe sem estourar (%.2f)"):format(FS.intensity()), FS.intensity() < 0.45)
    re:_onCashOutClick()
    t:truthy(("clique do cash out: o brilho sobe sem estourar (%.2f)"):format(FS.intensity()), FS.intensity() < 0.5)
    pump(10, function() return api.state() == "cardReward" end)
    t:eq("espolios: chegou", api.state(), "cardReward")
    t:truthy("espolios: funde a partir do ultimo quadro", SF.isActive() or SF.alpha() == 0)
    pump(0.6)
    t:falsy("espolios: fusao termina em ate 0,6 s", SF.isActive())

    local MM = require("src.systems.MusicMoments")
    MM.sting("run_victory", "runVictory")
    pump(0.5)
    local since = MM.sinceSting("run_victory")
    t:truthy(("sting da vitoria: relogio marcado (%.2f s)"):format(since), since >= 0.4 and since < 1.0)

    api.returnToMenu(); pump(0.3)
    CheatMode.deactivate()
    if _G.audioSystem and _G.audioSystem.stopAll then pcall(_G.audioSystem.stopAll, _G.audioSystem) end
    FA.uninstall()
end

function M.run()
    TK.bootstrap()
    local t = TK.new("transicoes: bioma novo, fusoes do chefe, sting do fim")
    local ok, err = pcall(unit, t)
    t:truthy("unidade sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    ok, err = pcall(flow, t)
    t:truthy("fluxo sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    _G.ACT_INTRO_FORCE = nil
    return t:done()
end

return M
