local M = {}

local DT = 1 / 30
local OUT = "coringas_contra"

local function api() return _G.__cheatApi end
local function game() return api() and api().game() end
local function state() return api() and api().state() end

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

local function pump(secs, pred)
    local t = 0
    while t < secs do
        love.update(DT)
        love.graphics.origin()
        love.draw()
        love.graphics.present()
        t = t + DT
        if pred and pred() then return true end
    end
    return pred and pred() or false
end

local function shoot(name, w, h)
    local CRTShader = require("src.ui.CRTShader")
    local canvas = love.graphics.newCanvas(w, h)
    local realEnd = CRTShader.endScene
    CRTShader.endScene = function() return realEnd(canvas) end
    local realSet = love.graphics.setCanvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.update(DT)
    love.graphics.origin()
    local ok, err = pcall(love.draw)
    CRTShader.endScene = realEnd
    realSet()
    love.graphics.present()
    if not ok then canvas:release() error(err, 0) end
    love.filesystem.createDirectory(OUT)
    local file = ("%s/%s.png"):format(OUT, name)
    local data = canvas:newImageData()
    data:encode("png", file)
    data:release()
    canvas:release()
    print(love.filesystem.getSaveDirectory() .. "/" .. file)
end

local function enterBattle(act, boss)
    local CheatMode = require("src.systems.CheatMode")
    CheatMode.goToAct(act, boss)
    if not boss then
        pump(1)
        CheatMode.jumpTo("battle")
    end
    local ok = false
    for _ = 1, 40 do
        pump(boss and 60 or 30, function() return CheatMode.combatReady(true) end)
        pump(1.5)
        if CheatMode.combatReady(true) then ok = true break end
    end
    if not ok then
        error(("combate nao ficou pronto: ato %d, estado %s, inBattle %s"):format(
            act, tostring(state()), tostring(CheatMode.inBattle())), 0)
    end
    pump(0.8)
    local g = game()
    local WR = require("src.ui.WorldRoad")
    print(("[contra] ato %d estado %s mao %d turno %s viagem %s entrada %s no %s"):format(act,
        tostring(state()), #(g.hand or {}), tostring(g.turn), tostring(WR.isTraveling()),
        tostring(WR.isEntering()), tostring(g.runManager.currentRun.currentNode and g.runManager.currentRun.currentNode.type)))
end

local function equipOnly(id)
    local g = game()
    local run = g.runManager.currentRun
    run.jokers, run.jokerActive = {}, {}
    g:addJokerToRun(id)
    g:rebuildJokerSlots()
    g._counterProcs = 0
end

local function waitProc(secs)
    local g = game()
    local start = g._counterProcs or 0
    pump(secs or 12, function() return (g._counterProcs or 0) > start end)
    pump(0.35)
end

local function debuffScene(name, id, act, w, h)
    enterBattle(act)
    equipOnly(id)
    local g = game()
    g.enemy:forceIntent(g.enemy:getIntent().id, g.player)
    g.enemy.intent.debuffs = { { name = name, duration = 2, stacks = 3 } }
    g.player.armor = 99
    pump(0.5)
    shoot(id .. "_antes", w, h)
    g:endTurn()
    waitProc(14)
    shoot(id .. "_proc", w, h)
end

function M.run(arg)
    local w, h = 1920, 1080
    local sw, sh = tostring(arg or ""):match("^(%d+)x(%d+)$")
    if sw then w, h = tonumber(sw), tonumber(sh) end
    local only = os.getenv("CONTRA_ONLY")
    local restore = fakeWindow(w, h)
    local CheatMode = require("src.systems.CheatMode")
    local ok, err = pcall(function()
        love.load({})
        require("src.i18n.I18n").setLocale(os.getenv("TOOL_LOCALE") or "pt_BR")
        if _G.audioSystem and _G.audioSystem.setMasterVolume then _G.audioSystem:setMasterVolume(0) end
        require("src.ui.UiScale").force(nil)
        love.resize(w, h)
        CheatMode.activate({ isolate = false })
        CheatMode.panelOpen = false
        pump(2, function() return state() ~= "boot" end)
        love.keypressed("return")
        pump(6, function() return state() == "menu" end)
        api().startGame("warrior", 0)
        pump(30, function() return CheatMode.combatReady(true) end)
        CheatMode.toggleGod()

        local function want(k) return not only or only:find(k, 1, true) end

        if want("lantern") then
            enterBattle(4)
            local g = game()
            g.runManager.currentRun.jokers, g.runManager.currentRun.jokerActive = {}, {}
            g:rebuildJokerSlots()
            g.enemy.fogContext = { biomeId = "frost", progress = 1, hall = false, density = 1 }
            g.enemy:refreshIntentVisibility()
            pump(1.2)
            shoot("joker_counter_lantern_antes", w, h)
            equipOnly("joker_counter_lantern")
            g.enemy:refreshIntentVisibility()
            pump(0.4)
            shoot("joker_counter_lantern_proc", w, h)
            pump(1.5)
            shoot("joker_counter_lantern_depois", w, h)
        end

        if want("brazier") then
            enterBattle(4, true)
            equipOnly("joker_counter_brazier")
            local g = game()
            g.player.frost = 3
            g.enemy:forceIntent("royal_blizzard", g.player)
            g.player.armor = 99
            pump(0.5)
            shoot("joker_counter_brazier_antes", w, h)
            g:endTurn()
            waitProc(16)
            shoot("joker_counter_brazier_proc", w, h)
        end

        local debuffs = {
            { "poison", "joker_counter_antidote", 5 },
            { "burn", "joker_counter_salamander", 3 },
            { "weak", "joker_counter_weak", 1 },
            { "frail", "joker_counter_frail", 2 },
            { "vulnerable", "joker_counter_vulnerable", 6 },
        }
        for _, d in ipairs(debuffs) do
            if want(d[1]) or want(d[2]) then debuffScene(d[1], d[2], d[3], w, h) end
        end

        if want("manager") then
            local g = game()
            local run = g.runManager.currentRun
            run.jokers, run.jokerActive = {}, {}
            for _, id in ipairs(require("tools.test_counter_jokers").IDS) do
                g:addJokerToRun(id)
            end
            g:addJokerToRun("joker_combo_volley")
            g:rebuildJokerSlots()
            pump(0.5)
            if _G.toggleJokerManager then _G.toggleJokerManager() end
            pump(1.2)
            shoot("gerenciador_coringas", w, h)
            if _G.toggleJokerManager then _G.toggleJokerManager() end
            pump(0.3)
        end
    end)
    CheatMode.deactivate()
    restore()
    if not ok then
        print("[screenshot_coringas_contra] FALHOU: " .. tostring(err))
        return false
    end
    return true
end

return M
