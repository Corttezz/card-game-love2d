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

local rec = { on = false, n = 0, dir = nil, audio = {}, states = {}, canvas = nil, marks = {} }

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
    if not ok then require("src.core.Debug").warn("[record_maiden_fight] draw: " .. tostring(err)) end
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

local function mark(name) rec.marks[name] = rec.n end

local function startRec(tag)
    rec.dir = "maiden_rec/" .. tag
    love.filesystem.createDirectory(rec.dir .. "/frames")
    for _, f in ipairs(love.filesystem.getDirectoryItems(rec.dir .. "/frames")) do
        love.filesystem.remove(rec.dir .. "/frames/" .. f)
    end
    local W, H = love.graphics.getDimensions()
    rec.canvas = love.graphics.newCanvas(W, H)
    rec.on, rec.n, rec.audio, rec.states, rec.marks = true, 0, {}, {}, {}
end

local function stopRec(notes)
    rec.on = false
    local parts = {}
    for k, v in pairs(notes or {}) do parts[#parts + 1] = string.format('"%s":"%s"', k, tostring(v)) end
    for k, v in pairs(rec.marks) do parts[#parts + 1] = string.format('"m_%s":"%s"', k, tostring(v)) end
    love.filesystem.write(rec.dir .. "/audio.json", string.format(
        '{"fps":%d,"frames":%d,"notes":{%s},"states":[%s],"audio":[%s]}',
        FPS, rec.n, table.concat(parts, ","), table.concat(rec.states, ","), table.concat(rec.audio, ",")))
end

local function ready()
    return CM().combatReady(true)
end

local function hit(frac)
    local g = game()
    local e = g.enemy
    local want = math.max(1, math.floor(e.maxHealth * frac))
    local dmg = math.max(1, e.health - want)
    e.armor = 0
    e:takeDamage(dmg)
    require("src.systems.Sfx").play("swordSound")
    if _G.triggerShake then _G.triggerShake(8, 0.2) end
    g:settleEnemyDamage()
end

local function enemyTurn()
    local g = game()
    g.player.health = g.player.maxHealth
    g:endTurn()
    pump(12, function() return game().turn == "player" and ready() end)
    pump(0.6)
end

local function toBossRoom(act, tag)
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
    local ok = pump(90, function() return BC.isActive() and BC.phase() == "intro" end)
    if not ok then return false end
    startRec(tag)
    mark("intro")
    return pump(60, function()
        return state() == "playing" and BC.phase() == nil and ready()
    end)
end

local function fight(tag, condensed)
    local notes = { act = 6 }
    if not toBossRoom(6, tag) then notes.erro = "nao chegou na luta"; return notes end
    local g = game()
    notes.enemy = g.enemy and g.enemy.spriteId
    notes.hp = g.enemy and g.enemy.maxHealth
    mark("fase1")
    pump(1.0)
    enemyTurn()
    hit(0.86)
    pump(1.6)
    if not condensed then enemyTurn() end
    hit(0.74)
    mark("fase2")
    pump(4.0)
    enemyTurn()
    enemyTurn()
    enemyTurn()
    hit(0.62)
    pump(1.4)
    hit(0.49)
    mark("fase3")
    pump(4.0)
    enemyTurn()
    enemyTurn()
    hit(0.36)
    pump(1.2)
    hit(0.24)
    mark("fase4")
    pump(4.0)
    enemyTurn()
    enemyTurn()
    hit(0.12)
    pump(1.4)
    notes.phaseIdx = g.enemy._phaseIdx
    mark("kill")
    CM().kill()
    pump(40, function() return state() == "victory" end)
    mark("victory")
    pump(9.0)
    notes.fim = tostring(state())
    stopRec(notes)
    return notes
end

function M.run(arg)
    TK.bootstrap()
    local tag = tostring(arg or "")
    tag = tag ~= "" and tag or "luta"
    local CheatMode = require("src.systems.CheatMode")
    FA.install()
    local okLoad, errLoad = pcall(love.load, {})
    if not okLoad then print("[record_maiden_fight] boot falhou: " .. tostring(errLoad)); return false end
    CheatMode.activate({ isolate = false })
    CheatMode.panelOpen = false
    require("src.ui.UnlockReveal").dtOverride = DT
    if _G.gameSettings then _G.gameSettings.tipsEnabled = false end
    require("src.i18n.I18n").setLocale("pt_BR", true)
    local notes
    local ok, err = pcall(function()
        local st = function() return state() end
        pump(30, function() return st() == "menu" end)
        require("src.ui.InputFocus").hideAll()
        api().startGame("warrior", 0)
        pump(30, function() return st() == "playing" end)
        notes = fight(tag, true)
    end)
    if not ok then print("[record_maiden_fight] erro: " .. tostring(err)) end
    if rec.on then stopRec(notes or { erro = tostring(err) }) end
    FA.uninstall()
    local parts = {}
    for k, v in pairs(notes or {}) do parts[#parts + 1] = k .. "=" .. tostring(v) end
    for k, v in pairs(rec.marks) do parts[#parts + 1] = "m_" .. k .. "=" .. tostring(v) end
    table.sort(parts)
    print(string.format("[record_maiden_fight] %s: %d quadros em %s/%s | %s", tag, rec.n,
        love.filesystem.getSaveDirectory(), rec.dir or "-", table.concat(parts, " ")))
    return ok
end

return M
