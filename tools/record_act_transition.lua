local TK = require("tools.testkit")
local FA = require("tools.fake_audio")

local M = {}

local FPS = 30
local DT = 1 / FPS

local function api() return _G.__cheatApi end
local function state() return api() and api().state() end
local function game() return api() and api().game() end
local function run()
    local g = game()
    return g and g.runManager and g.runManager.currentRun
end
local function CM() return require("src.systems.CheatMode") end

local rec = { on = false, n = 0, dir = nil, audio = {}, states = {}, canvas = nil }

local function audioFrame()
    local out = {}
    for _, s in ipairs(FA.playing()) do
        if s.path and (s.vol or 0) > 0 then
            out[#out + 1] = string.format('["%s",%.4f,%.4f,%.3f,%s]', s.path, s.pos or 0, s.vol or 0,
                s.pitch or 1, rawget(s, "filter") and "1" or "0")
        end
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function shot()
    local CRT = require("src.ui.CRTShader")
    local cv = rec.canvas
    local orig = CRT.endScene
    CRT.endScene = function(target) return orig(target or cv) end
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.origin()
    local ok, err = pcall(love.draw)
    love.graphics.setCanvas()
    CRT.endScene = orig
    if not ok then require("src.core.Debug").warn("[record_act_transition] draw: " .. tostring(err)) end
    cv:newImageData():encode("png", string.format("%s/frames/%05d.png", rec.dir, rec.n))
end

local function step()
    love.update(DT)
    FA.advance(DT)
    if rec.on then
        shot()
        rec.audio[#rec.audio + 1] = audioFrame()
        rec.states[#rec.states + 1] = '"' .. tostring(state()) .. '"'
        rec.n = rec.n + 1
    else
        love.graphics.origin()
        pcall(love.draw)
    end
end

local function pump(secs, pred)
    local el = 0
    while el < secs do
        step()
        el = el + DT
        if pred and pred() then return true end
    end
    return pred and pred() or false
end

local function waitState(want, secs)
    return pump(secs or 20, function() return state() == want end)
end

local function startRec(tag)
    rec.dir = "act_trans_rec/" .. tag
    love.filesystem.createDirectory(rec.dir .. "/frames")
    for _, f in ipairs(love.filesystem.getDirectoryItems(rec.dir .. "/frames")) do
        love.filesystem.remove(rec.dir .. "/frames/" .. f)
    end
    local W, H = love.graphics.getDimensions()
    rec.canvas = love.graphics.newCanvas(W, H)
    rec.on, rec.n, rec.audio, rec.states = true, 0, {}, {}
end

local function stopRec(notes)
    rec.on = false
    local parts = {}
    for k, v in pairs(notes or {}) do parts[#parts + 1] = string.format('"%s":"%s"', k, tostring(v)) end
    love.filesystem.write(rec.dir .. "/audio.json", string.format(
        '{"fps":%d,"frames":%d,"notes":{%s},"states":[%s],"audio":[%s]}',
        FPS, rec.n, table.concat(parts, ","), table.concat(rec.states, ","), table.concat(rec.audio, ",")))
end

local function newRun()
    require("src.ui.InputFocus").hideAll()
    api().startGame("warrior", 0)
end

local function toBossFight(act)
    CM().goToAct(act, false)
    pump(0.5)
    local MapManager = require("src.systems.MapManager")
    local r = run()
    CM().leaveCurrent()
    r.floorInAct = MapManager.FLOORS_PER_ACT - 1
    r.currentFloor = (r.actNumber - 1) * MapManager.FLOORS_PER_ACT + r.floorInAct
    r.pendingNodes = nil
    api().showMapSelection()
    pump(1.0)
    CM().pending().forkPick = 1
    local BC = require("src.ui.BossCinematic")
    local GS = require("src.scenes.GameplayScene")
    local ok = pump(90, function()
        local rr = run()
        return state() == "playing" and BC.phase() == nil and GS.inBossRoom("boss")
            and rr.currentNode and rr.currentNode.type == "boss"
    end)
    return ok and pump(40, function() return CM().combatReady(true) end)
end

local function transition(act, tag)
    local notes = { act = act }
    if not toBossFight(act) then notes.erro = "nao chegou na luta do chefe"; return notes end
    pump(1.0)
    startRec(tag)
    pump(1.2)
    notes.kill = rec.n
    CM().kill()
    local final = act == require("src.core.Config").TotalActs
    if final then
        waitState("victory", 40)
        notes.victory = rec.n
        pump(8.0)
        notes.fim = tostring(state())
        stopRec(notes)
        return notes
    end
    waitState("roundEval", 40)
    notes.roundEval = rec.n
    local re = api().screens().roundEval
    pump(10, function() return re.cashOutReady end)
    pump(1.2)
    re:_onCashOutClick()
    waitState("cardReward", 10)
    notes.cardReward = rec.n
    pump(1.5)
    local rw = api().screens().reward
    notes.click = rec.n
    if rw.skipButton and rw.skipButton.onClick then rw.skipButton.onClick() end
    pump(0.1)
    notes.afterClick = tostring(state())
    waitState("actIntro", 5)
    notes.actIntro = rec.n
    waitState("mapSelection", 20)
    notes.mapSelection = rec.n
    notes.newAct = run() and run().actNumber
    pump(3.5)
    stopRec(notes)
    return notes
end

local function opening(tag)
    local notes = { act = 1 }
    waitState("menu", 30)
    local menu = api().screens().menu
    if menu.skipIntro then pcall(menu.skipIntro, menu) end
    pump(2.0)
    startRec(tag)
    pump(1.5)
    notes.start = rec.n
    newRun()
    notes.afterStart = tostring(state())
    waitState("playing", 20)
    notes.playing = rec.n
    pump(5.0)
    stopRec(notes)
    return notes
end

function M.run(arg)
    TK.bootstrap()
    local a, tag = tostring(arg or "0"):match("^(%d+):?(.*)$")
    a = tonumber(a) or 0
    tag = (tag and tag ~= "") and tag or ("t" .. a)
    local CheatMode = require("src.systems.CheatMode")
    FA.install()
    _G.ACT_INTRO_FORCE = true
    local okLoad, errLoad = pcall(love.load, {})
    if not okLoad then print("[record_act_transition] boot falhou: " .. tostring(errLoad)); return false end
    CheatMode.activate({ isolate = false })
    CheatMode.panelOpen = false
    if _G.gameSettings then _G.gameSettings.tipsEnabled = false end
    local notes
    local ok, err = pcall(function()
        if a == 0 then
            notes = opening(tag)
        else
            waitState("menu", 30)
            newRun()
            waitState("playing", 30)
            notes = transition(a, tag)
        end
    end)
    if not ok then print("[record_act_transition] erro: " .. tostring(err)) end
    if rec.on then stopRec(notes or { erro = tostring(err) }) end
    _G.ACT_INTRO_FORCE = nil
    FA.uninstall()
    local parts = {}
    for k, v in pairs(notes or {}) do parts[#parts + 1] = k .. "=" .. tostring(v) end
    table.sort(parts)
    print(string.format("[record_act_transition] %s: %d quadros em %s/%s | %s", tag, rec.n,
        love.filesystem.getSaveDirectory(), rec.dir or "-", table.concat(parts, " ")))
    return ok
end

return M
