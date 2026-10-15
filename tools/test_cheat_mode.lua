local TK = require("tools.testkit")

local M = {}

local DT = 1 / 30

local function api() return _G.__cheatApi end
local function state() return api() and api().state() end
local function game() return api() and api().game() end
local function run()
    local g = game()
    return g and g.runManager and g.runManager.currentRun
end

local frame = 0
local function pump(secs, pred)
    local t = 0
    while t < secs do
        love.update(DT)
        frame = frame + 1
        if frame % 2 == 0 then
            love.graphics.origin()
            love.draw()
        end
        t = t + DT
        if pred and pred() then return true end
    end
    return pred and pred() or false
end

local function checkArgs(t, CheatMode)
    local out = CheatMode.claimArgs({ "cheat" }, { isDev = true, isolate = false })
    t:eq("arg cheat em DEV: sobra nenhum arg de ferramenta (HEADLESS_TOOL nao liga)",
        out and out[1], nil)
    t:truthy("arg cheat em DEV liga o modo cheat", CheatMode.active)
    t:truthy("arg cheat em DEV marca _G.CHEAT_MODE (Steam fica de fora)", _G.CHEAT_MODE)
    CheatMode.deactivate()

    out = CheatMode.claimArgs({ "cheat", "lixo" }, { isDev = true, isolate = false })
    t:eq("arg extra depois do cheat nao vira ferramenta", out and out[1], nil)
    CheatMode.deactivate()

    out = CheatMode.claimArgs({ "cheat" }, { isDev = false })
    t:eq("RELEASE ignora o arg cheat (jogo abre normal)", out and out[1], nil)
    t:falsy("RELEASE nao liga o modo cheat", CheatMode.active)

    local other = { "test_one", "x" }
    t:truthy("arg de ferramenta passa intacto", CheatMode.claimArgs(other) == other)

    local src = love.filesystem.read("main.lua") or ""
    local iClaim = src:find('require("src.systems.CheatMode").claimArgs(loveArgs)', 1, true)
    local iTool = src:find("local toolArg = loveArgs and loveArgs[1]", 1, true)
    t:truthy("main.lua: o cheat consome o arg ANTES de decidir se e ferramenta",
        iClaim and iTool and iClaim < iTool)
    local iFilter = src:find('require("src.core.Release").filterArgs(loveArgs)', 1, true)
    t:truthy("main.lua: o filtro de release roda antes (release nunca ve o cheat)",
        iFilter and iClaim and iFilter < iClaim)

    local rel = love.filesystem.read("src/core/Release.lua") or ""
    t:truthy("erro no modo cheat mostra a tela de erro do jogo (nao sai como ferramenta)",
        rel:find('gameArgs[1] ~= "cheat"', 1, true) ~= nil)
end

local function fileStamp(name)
    local info = love.filesystem.getInfo(name, "file")
    if not info then return "ausente" end
    return tostring(info.size) .. "@" .. tostring(info.modtime)
end

local function checkIsolation(t, CheatMode)
    local fs = love.filesystem
    local SaveManager = require("engine.SaveManager")
    local base = fs.getIdentity()
    local baseDir = fs.getSaveDirectory()
    local runPath = SaveManager.PATHS.run
    local before = { fileStamp(runPath), fileStamp("run.save.lua"), fileStamp("profile.lua") }
    local ok, err = pcall(function()
        local id = CheatMode.isolateSaves()
        t:eq("save do cheat mora numa identidade propria", fs.getIdentity(), base .. "-cheat")
        t:truthy("pasta de save do cheat e outra", fs.getSaveDirectory() ~= baseDir)
        t:eq("isolar de novo nao empilha sufixo", CheatMode.identityFor(id), id)
        local g = TK.newRunGame("warrior")
        g:checkpointRun()
        t:truthy("o checkpoint da corrida cheat grava na pasta isolada",
            fs.getInfo(runPath, "file") ~= nil)
        fs.remove(runPath)
    end)
    fs.setIdentity(base)
    t:truthy("isolamento rodou sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    t:eq("identidade real restaurada", fs.getIdentity(), base)
    local after = { fileStamp(runPath), fileStamp("run.save.lua"), fileStamp("profile.lua") }
    t:eq("save da corrida real intacto", after[1], before[1])
    t:eq("run.save.lua real intacto", after[2], before[2])
    t:eq("perfil real intacto", after[3], before[3])
end

local function checkGodMode(t, CheatMode)
    CheatMode.activate({ isolate = false })
    local g = TK.newRunGame("warrior")
    local hp = g.player.health
    CheatMode.god = true
    g.player.armor = 0
    g.player:takeDamage(40)
    g.player:loseHealth(15)
    g.player:takeDamage(30, true)
    t:eq("modo deus: golpe, perda de vida e perfurante nao tiram vida", g.player.health, hp)
    g.enemy.damage, g.enemy.nextIntentDamage = 25, 25
    g.turn = "enemy"
    g:enemyTurn()
    TK.pump(g, 4)
    t:eq("modo deus: turno inteiro do inimigo nao tira vida", g.player.health, hp)
    CheatMode.god = false
    g.player:takeDamage(10)
    t:eq("modo deus desligado: dano volta", g.player.health, hp - 10)
    CheatMode.deactivate()
end

local function checkPanel(t, label)
    local CheatPanel = require("components.CheatPanel")
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local L = CheatPanel.currentLayout()
    local errs = CheatPanel.validate(L, sw, sh)
    t:eq("painel (" .. label .. "): cabe na tela sem botao sobreposto ("
        .. table.concat(errs, "; ") .. ")", #errs, 0)
    t:truthy("painel (" .. label .. "): tem botoes", #L.buttons > 0)
    if label == "combate" then
        t:truthy("painel (combate): acaba acima do botao de jogar cartas",
            L.y + L.h < sh * 0.62)
    end
end

local function waitReady(CheatMode, secs)
    return pump(secs or 30, function() return CheatMode.combatReady(true) end)
end

local EXPECT = {
    battle = "playing", elite = "playing", mini_boss = "playing", boss = "playing",
    shop = "cardReward", rest = "rest", event = "event",
}

local function checkFullFlow(t, CheatMode)
    local okLoad, errLoad = pcall(love.load, {})
    t:truthy("boot completo do jogo" .. (okLoad and "" or (": " .. tostring(errLoad))), okLoad)
    if not okLoad then return end
    if _G.audioSystem and _G.audioSystem.setMasterVolume then _G.audioSystem:setMasterVolume(0) end
    CheatMode.activate({ isolate = false })
    t:truthy("main.lua expoe a ponte do cheat", api() ~= nil and api().showMapSelection ~= nil)
    pump(2, function() return state() ~= "boot" end)
    love.keypressed("return")
    pump(6, function() return state() == "menu" end)
    t:eq("boot chega ao menu", state(), "menu")

    api().startGame("warrior", 0)
    t:eq("corrida comecou", state(), "playing")
    t:truthy("mao dada e inimigo parado (chegada pela estrada)", waitReady(CheatMode, 30))

    checkPanel(t, "combate")
    CheatMode.forceRareJoker()
    CheatMode.kill()
    local cash = pump(20, function() return state() == "roundEval" end)
    t:truthy("MATAR: a morte passa pelo fluxo real e abre o cash out", cash)
    t:truthy("MATAR: o inimigo morreu de verdade", game().enemy.health <= 0)
    t:truthy("MATAR: a morte foi tratada pelo jogo (pontos, conquistas)", game()._deathHandled)

    local re = api().screens().roundEval
    pump(8, function() return re.cashOutReady end)
    re:_onCashOutClick()
    local rewards = pump(10, function()
        local rw = api().screens().reward
        return state() == "cardReward" and rw:isVisible() and rw.mode == "rewards"
    end)
    t:truthy("cash out leva a recompensa de verdade", rewards)
    local rw = api().screens().reward
    local joker
    for _, o in ipairs(rw.shopOffers or {}) do
        local cd = require("src.systems.CardDatabase"):getCard(o.id)
        if o.type == "card" and cd and cd.type == "joker" then joker = o end
    end
    t:truthy("FORCAR CORINGA: a recompensa da batalha comum trouxe um coringa", joker ~= nil)
    t:truthy("FORCAR CORINGA: ele entra pela revelacao rara", joker and joker._rareReveal ~= nil)
    t:falsy("FORCAR CORINGA: vale uma vez so",
        require("src.systems.ShopSystem").forceNextRewardJoker)

    CheatMode.advanceFloor()
    pump(4, function()
        local f = require("src.ui.WorldRoad")._fork
        return f and (f.animIn or 0) >= 1 and f.markBoxes and f.markBoxes[1] ~= nil
    end)
    pump(0.2)
    checkPanel(t, "encruzilhada")
    local L = require("components.CheatPanel").currentLayout()
    local f = require("src.ui.WorldRoad")._fork
    local clear = true
    for i = 1, (f and f.n or 0) do
        local b = f.markBoxes[i]
        if b and b.x2 > L.x and b.x1 < L.x + L.w and b.y2 > L.y and b.y1 < L.y + L.h then
            clear = false
        end
    end
    t:truthy("painel nao cobre os caminhos da encruzilhada", clear)

    for _, nt in ipairs({ "battle", "elite", "mini_boss", "shop", "rest", "event", "boss" }) do
        CheatMode.jumpTo(nt)
        local want = EXPECT[nt]
        local got = pump(25, function()
            local r = run()
            return state() == want and r and r.currentNode and r.currentNode.type == nt
        end)
        t:truthy(("PULAR para %s: a encruzilhada leva a %s (estado=%s)"):format(
            nt, want, tostring(state())), got)
        local sc = api().screens()
        if nt == "shop" then
            t:truthy("PULAR para loja: tela da loja aberta",
                sc.reward:isVisible() and sc.reward.mode == "shop")
        elseif nt == "rest" then
            t:truthy("PULAR para descanso: fogueira aberta", sc.rest:isVisible())
        elseif nt == "event" then
            t:truthy("PULAR para evento: evento aberto", sc.event:isVisible())
        elseif want == "playing" then
            local EnemyRoster = require("src.systems.EnemyRoster")
            local pool = EnemyRoster.poolFor(EnemyRoster.biomeAct(run()), nt)
            local id = run().currentNode.enemyId
            local inPool = false
            for _, p in ipairs(pool) do if p == id then inPool = true end end
            t:truthy(("PULAR para %s: inimigo do bioma do ato (%s)"):format(nt, tostring(id)),
                inPool)
        end
    end

    local bossReady = waitReady(CheatMode, 40)
    t:truthy("chefe: porta, salao e entrada terminam antes do golpe", bossReady)
    CheatMode.kill()
    local BossCinematic = require("src.ui.BossCinematic")
    local sawDeath = false
    local bossDone = pump(40, function()
        if BossCinematic.phase() == "death" then sawDeath = true end
        return state() == "roundEval"
    end)
    t:truthy("MATAR o chefe: cash out depois da luta", bossDone)
    t:truthy("MATAR o chefe: a cinematica de morte tocou antes", sawDeath)

    CheatMode.goToAct(3, false)
    pump(1)
    local r = run()
    t:eq("IR PARA ATO 3: ato ajustado", r.actNumber, 3)
    t:eq("IR PARA ATO 3: andar 1", r.floorInAct, 1)
    t:eq("IR PARA ATO 3: abre a encruzilhada", state(), "mapSelection")
    CheatMode.jumpTo("battle")
    pump(25, function() return state() == "playing" and CheatMode.combatReady(false) end)
    local EnemyRoster = require("src.systems.EnemyRoster")
    local id = game().enemy and game().enemy.spriteId
    local inPool = false
    for _, p in ipairs(EnemyRoster.poolFor(3, "battle")) do
        if p == run().currentNode.enemyId then inPool = true end
    end
    t:truthy("ATO 3: o inimigo e do bioma do ato 3 (" .. tostring(id) .. ")", inPool)

    CheatMode.goToAct(4, true)
    local bossNode = pump(30, function()
        local rr = run()
        return state() == "playing" and rr.currentNode and rr.currentNode.type == "boss"
    end)
    t:truthy("IR PARA ATO 4 CHEFE: chega na luta do chefe", bossNode)
    t:eq("ATO 4 CHEFE: ato 4", run().actNumber, 4)
    t:eq("ATO 4 CHEFE: andar 8", run().floorInAct, 8)
    t:eq("ATO 4 CHEFE: e o chefe do bioma", run().currentNode.enemyId,
        EnemyRoster.poolFor(4, "boss")[1])

    waitReady(CheatMode, 40)
    CheatMode.winInstant()
    local sawDeath4 = false
    local quick = pump(10, function()
        if BossCinematic.phase() == "death" then sawDeath4 = true end
        return state() == "roundEval"
    end)
    t:truthy("VENCER SEM ANIMACAO: cash out direto", quick)
    t:falsy("VENCER SEM ANIMACAO: sem cinematica de morte", sawDeath4)

    CheatMode.winCampaign()
    local won = pump(90, function() return state() == "victory" end)
    t:truthy("VENCER CAMPANHA: tela de vitoria real", won)
    t:truthy("VENCER CAMPANHA: a corrida ficou marcada como vencida (endless liberado)",
        run() and run().campaignWon)

    api().startGame("rogue", 0)
    waitReady(CheatMode, 30)
    CheatMode.toggleRush()
    local floor0 = run().floorInAct
    local seen = {}
    pump(70, function() seen[state()] = true return false end)
    t:truthy(("RUSH: avancou sozinho pelos andares (%d -> %d)"):format(floor0, run().floorInAct),
        run().floorInAct >= floor0 + 2)
    t:truthy("RUSH: passou pelo cash out, recompensa e encruzilhada",
        seen.roundEval and seen.cardReward and seen.mapSelection)
    CheatMode.goToActBoss()
    pump(40, function() return not CheatMode.rush end)
    t:falsy("RUSH: para sozinho no chefe", CheatMode.rush)
    t:eq("RUSH: parou com o chefe vivo", run().currentNode.type, "boss")

    CheatMode.die()
    local over = pump(15, function() return state() == "gameOver" end)
    t:truthy("MORRER: game over real", over)

    CheatMode.deactivate()
    if api() and api().returnToMenu then pcall(api().returnToMenu) end
end

function M.run()
    TK.bootstrap()
    local t = TK.new("modo cheat (love . cheat)")
    local CheatMode = require("src.systems.CheatMode")
    local mouse = { love.mouse.getPosition, love.mouse.getX, love.mouse.getY }
    local ok, err = pcall(function()
        checkArgs(t, CheatMode)
        checkIsolation(t, CheatMode)
        checkGodMode(t, CheatMode)
        checkFullFlow(t, CheatMode)
    end)
    CheatMode.deactivate()
    love.mouse.getPosition, love.mouse.getX, love.mouse.getY = mouse[1], mouse[2], mouse[3]
    if _G.audioSystem and _G.audioSystem.stopAll then pcall(_G.audioSystem.stopAll, _G.audioSystem) end
    t:truthy("suite sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    return t:done()
end

return M
