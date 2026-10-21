local Debug = require("src.core.Debug")
local I18n = require("src.i18n.I18n")

local CheatMode = {}

CheatMode.ARG = "cheat"
CheatMode.IDENTITY_SUFFIX = "-cheat"
CheatMode.COPY_FILES = { "settings.lua", "i18n_settings.lua" }
CheatMode.RUSH_GAP = 0.9
CheatMode.RARE_WAIT = 2.6
CheatMode.STATUS_HOLD = 3.5
CheatMode.GOLD_STEP = 100

CheatMode.active = false
CheatMode.god = false
CheatMode.infiniteMana = false
CheatMode.rush = false
CheatMode.panelOpen = true
CheatMode.identity = nil

local pending = { kill = false, win = false, forkPick = nil }
local rushT, rushKey = 0, nil
local statusT = 0
local playerPatched = false
local settingsApplied = false
local apiOverride = nil
local pressInside = false

CheatMode.RUN_STATES = {
    playing = true, mapSelection = true, cardReward = true,
    roundEval = true, rest = true, event = true,
}

function CheatMode.setApi(a) apiOverride = a end
local function api() return apiOverride or _G.__cheatApi end

local function game()
    local a = api()
    return a and a.game and a.game() or nil
end

local function state()
    local a = api()
    return a and a.state and a.state() or nil
end

function CheatMode.currentState() return state() end

local function run()
    local g = game()
    return g and g.runManager and g.runManager.currentRun or nil
end

local function screens()
    local a = api()
    return (a and a.screens and a.screens()) or {}
end

local function nodeType()
    local r = run()
    return r and r.currentNode and r.currentNode.type or nil
end

local function say(key, vars)
    CheatMode.status = I18n.t("cheat.msg." .. key, vars)
    statusT = CheatMode.STATUS_HOLD
end

function CheatMode.statusText()
    if statusT > 0 then return CheatMode.status end
    return nil
end

function CheatMode.identityFor(base)
    base = tostring(base or "")
    if base:sub(-#CheatMode.IDENTITY_SUFFIX) == CheatMode.IDENTITY_SUFFIX then return base end
    return base .. CheatMode.IDENTITY_SUFFIX
end

function CheatMode.isolateSaves(setIdentity)
    local fs = love.filesystem
    setIdentity = setIdentity or fs.setIdentity
    local base = fs.getIdentity()
    local id = CheatMode.identityFor(base)
    local carry = {}
    if id ~= base then
        for _, name in ipairs(CheatMode.COPY_FILES) do
            if fs.getInfo(name, "file") then carry[name] = fs.read(name) end
        end
        setIdentity(id)
    end
    for name, data in pairs(carry) do
        if data and not fs.getInfo(name, "file") then fs.write(name, data) end
    end
    CheatMode.identity = id
    return id
end

function CheatMode.patchPlayer()
    if playerPatched then return end
    playerPatched = true
    local Player = require("src.entities.Player")
    local take, lose = Player.takeDamage, Player.loseHealth
    Player.takeDamage = function(self, ...)
        if CheatMode.active and CheatMode.god then return end
        return take(self, ...)
    end
    Player.loseHealth = function(self, ...)
        if CheatMode.active and CheatMode.god then return end
        return lose(self, ...)
    end
end

function CheatMode.activate(opts)
    opts = opts or {}
    CheatMode.active = true
    _G.CHEAT_MODE = true
    if opts.isolate ~= false then CheatMode.isolateSaves(opts.setIdentity) end
    require("src.systems.UnlockSystem").setOverrideAll(true)
    CheatMode.patchPlayer()
    require("src.ui.WorldRoad").avoidUI = CheatMode.panelRect
    settingsApplied = false
    Debug.log("[cheat] modo cheat ativo, saves em " .. tostring(CheatMode.identity))
end

function CheatMode.panelRect()
    if not CheatMode.active or not CheatMode.panelOpen then return nil end
    local ok, L = pcall(require("components.CheatPanel").currentLayout)
    return ok and L or nil
end

function CheatMode.deactivate()
    CheatMode.active = false
    require("src.ui.WorldRoad").avoidUI = nil
    _G.CHEAT_MODE = nil
    CheatMode.god, CheatMode.infiniteMana, CheatMode.rush = false, false, false
    pending.kill, pending.win, pending.forkPick = false, false, nil
    apiOverride = nil
end

function CheatMode.claimArgs(args, opts)
    if type(args) ~= "table" or args[1] ~= CheatMode.ARG then return args end
    opts = opts or {}
    local isDev = opts.isDev
    if isDev == nil then isDev = require("src.core.Release").isDev() end
    if isDev then CheatMode.activate(opts) end
    return {}
end

function CheatMode.inRun()
    return run() ~= nil and CheatMode.RUN_STATES[state() or ""] == true
end

function CheatMode.inBattle()
    local g = game()
    return state() == "playing" and g ~= nil and g.enemy ~= nil and g.enemy:isAlive()
        and not g._deathHandled
end

local function worldBusy()
    local WorldRoad = require("src.ui.WorldRoad")
    return WorldRoad.isTraveling() or WorldRoad.isEntering()
end

function CheatMode.combatReady(strict)
    local g = game()
    if not CheatMode.inBattle() then return false end
    if g.turn ~= "player" or worldBusy() then return false end
    local GS = require("src.scenes.GameplayScene")
    local nt = nodeType()
    if nt == "boss" and not GS.inBossRoom(nt) then return false end
    if strict then
        if g.combatAnimationSystem and g.combatAnimationSystem:isBlocking() then return false end
        return GS.isQuiet()
    end
    return true
end

local function doKill(g)
    local e = g.enemy
    e.armor = 0
    e:takeDamage(e.health + 1)
    if e.health > 0 then
        e.health = 0
        e._pendingDeath = true
    end
    require("src.systems.Sfx").play("swordSound")
    if _G.triggerShake then _G.triggerShake(10, 0.2) end
    g:settleEnemyDamage()
end

local function doWinInstant(g)
    local BossCinematic = require("src.ui.BossCinematic")
    require("src.systems.CombatBeats").clear()
    BossCinematic.reset()
    local e = g.enemy
    e.health = 0
    e._pendingDeath = false
    g._deathStaged = true
    g:_onEnemyDeath()
    g._deathPauseTimer = 0
    BossCinematic.markDeathSeen(g)
end

function CheatMode.kill()
    if not CheatMode.inBattle() then say("not_now") return false end
    pending.kill = true
    if not CheatMode.combatReady(true) then say("kill_armed") end
    return true
end

function CheatMode.winInstant()
    if not CheatMode.inBattle() then say("not_now") return false end
    pending.win = true
    return true
end

function CheatMode.die()
    local g = game()
    if state() ~= "playing" or not (g and g.player and g.player:isAlive()) then
        say("not_now") return false
    end
    pending.kill, pending.win = false, false
    CheatMode.rush = false
    g.player.health = 0
    return true
end

function CheatMode.fullHeal()
    local g = game()
    if not (CheatMode.inRun() and g.player) then say("not_now") return false end
    g.player.health = g.player.maxHealth
    say("healed")
    return true
end

function CheatMode.toggleGod()
    CheatMode.god = not CheatMode.god
    say(CheatMode.god and "god_on" or "god_off")
    return CheatMode.god
end

function CheatMode.toggleMana()
    CheatMode.infiniteMana = not CheatMode.infiniteMana
    say(CheatMode.infiniteMana and "mana_on" or "mana_off")
    return CheatMode.infiniteMana
end

function CheatMode.newHand()
    local g = game()
    if not CheatMode.inBattle() or g.turn ~= "player"
        or (g.combatAnimationSystem and g.combatAnimationSystem:isBlocking())
        or require("src.ui.HandDeal").isBusy() then
        say("not_now") return false
    end
    for i = #g.selectedCards, 1, -1 do g:selectCard(g.selectedCards[i]) end
    for _, c in ipairs(g.hand) do g.discard[#g.discard + 1] = c end
    g.hand = {}
    local Config = require("src.core.Config")
    local n = (Config.Game.CARDS_PER_TURN or 5) + g:getShopServiceCount("card_draw_upgrade")
    for i = 1, n do g:drawCard((i - 1) * 0.08) end
    say("new_hand")
    return true
end

function CheatMode.leaveCurrent()
    local g = game()
    if not g then return end
    pending.kill, pending.win, pending.forkPick = false, false, nil
    local BossCinematic = require("src.ui.BossCinematic")
    BossCinematic.reset()
    require("src.systems.CombatBeats").clear()
    require("src.ui.InputFocus").hideAll()
    local reward = screens().reward
    if reward and reward:isVisible() then reward:hide() end
    local e = g.enemy
    if e and e.health > 0 then
        e.health = 0
        e._pendingDeath = false
        require("src.ui.EnemyRenderer").triggerDeath(e.spriteId)
    end
    g._deathHandled, g._deathStaged = true, true
    g._deathPauseTimer = 0
    BossCinematic.markDeathSeen(g)
    for i = #(g.selectedCards or {}), 1, -1 do g:selectCard(g.selectedCards[i]) end
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad._travel, WorldRoad._entry, WorldRoad._encounter = nil, nil, nil
end

function CheatMode.jumpTo(nodeTypeId)
    if not CheatMode.inRun() then say("not_now") return false end
    local a, r = api(), run()
    CheatMode.leaveCurrent()
    if not r.pendingNodes then a.showMapSelection() end
    local MapManager = require("src.systems.MapManager")
    local node = MapManager._makeNode(nodeTypeId, r.floorInAct, r.actNumber)
    require("src.systems.EnemyRoster").assignNodes(r, { node })
    r.pendingNodes = { node }
    a.showMapSelection()
    pending.forkPick = 1
    say("jumped", { node = MapManager.labelFor(nodeTypeId) })
    return true
end

function CheatMode.advanceFloor()
    if not CheatMode.inRun() then say("not_now") return false end
    local a, r = api(), run()
    CheatMode.leaveCurrent()
    r.pendingNodes = nil
    a.showMapSelection()
    say("advanced", { floor = r.floorInAct })
    return true
end

local function placeAt(r, act, floorInAct)
    local MapManager = require("src.systems.MapManager")
    r.actNumber = act
    r.floorInAct = floorInAct
    r.currentFloor = (act - 1) * MapManager.FLOORS_PER_ACT + floorInAct
    r.pendingNodes = nil
end

function CheatMode.goToActBoss()
    if not CheatMode.inRun() then say("not_now") return false end
    local a, r = api(), run()
    CheatMode.leaveCurrent()
    local MapManager = require("src.systems.MapManager")
    local act = r.actNumber or 1
    r.floorInAct = MapManager.FLOORS_PER_ACT - 1
    r.currentFloor = (act - 1) * MapManager.FLOORS_PER_ACT + r.floorInAct
    r.pendingNodes = nil
    a.showMapSelection()
    pending.forkPick = 1
    say("to_boss")
    return true
end

function CheatMode.goToAct(act, boss)
    if not CheatMode.inRun() then say("not_now") return false end
    local Config = require("src.core.Config")
    local MapManager = require("src.systems.MapManager")
    local a, r, g = api(), run(), game()
    act = math.max(1, math.min(Config.TotalActs or 6, math.floor(tonumber(act) or 1)))
    CheatMode.leaveCurrent()
    r.endlessMode = false
    r.floorsInEndless = nil
    placeAt(r, act, boss and (MapManager.FLOORS_PER_ACT - 1) or 0)
    require("src.scenes.GameplayScene").resumeWorld(g)
    a.showMapSelection()
    if boss then pending.forkPick = 1 end
    say(boss and "to_act_boss" or "to_act", { act = act })
    return true
end

function CheatMode.winCampaign()
    if not CheatMode.inRun() then say("not_now") return false end
    local Config = require("src.core.Config")
    CheatMode.goToAct(Config.TotalActs or 6, true)
    pending.kill = true
    say("campaign")
    return true
end

function CheatMode.addGold()
    local g = game()
    if not (CheatMode.inRun() and g.economySystem) then say("not_now") return false end
    g.economySystem:earnGold(CheatMode.GOLD_STEP, "cheat")
    say("gold", { n = CheatMode.GOLD_STEP })
    return true
end

local function owns(r, cardId)
    for _, e in ipairs((r and r.jokers) or {}) do
        if (type(e) == "table" and e.id or e) == cardId then return true end
    end
    return false
end

local function cardName(id)
    local cd = require("src.systems.CardDatabase"):getCard(id)
    return cd and I18n.cardName(cd) or tostring(id)
end

function CheatMode.rareJokerPool(r)
    local list = {}
    for id, cd in pairs(require("src.systems.CardDatabase"):getAllCards()) do
        if cd.type == "joker" and not cd.bossId
            and (cd.rarity == "rare" or cd.rarity == "legendary")
            and not owns(r, id) then
            list[#list + 1] = id
        end
    end
    table.sort(list)
    return list
end

function CheatMode.giveRareJoker()
    local g, r = game(), run()
    if not CheatMode.inRun() then say("not_now") return false end
    local list = CheatMode.rareJokerPool(r)
    if #list == 0 then say("joker_owned") return false end
    local id = require("src.systems.Rng").get():pick("misc", list)
    g:addJokerToRun(id)
    say("joker", { name = cardName(id) })
    return id
end

function CheatMode.actBossId(r)
    local EnemyRoster = require("src.systems.EnemyRoster")
    local pool = EnemyRoster.poolFor(EnemyRoster.biomeAct(r), "boss")
    return pool and pool[1]
end

function CheatMode.giveBossJoker()
    local g, r = game(), run()
    if not CheatMode.inRun() then say("not_now") return false end
    local id = require("src.systems.BossJokers").cardFor(CheatMode.actBossId(r))
    if not id or owns(r, id) then say("joker_owned") return false end
    g:addJokerToRun(id)
    say("joker", { name = cardName(id) })
    return id
end

function CheatMode.forceRareJoker()
    require("src.systems.ShopSystem").forceNextRewardJoker = true
    say("forced_joker")
    return true
end

function CheatMode.toggleRush()
    CheatMode.rush = not CheatMode.rush
    rushT, rushKey = 0, nil
    say(CheatMode.rush and "rush_on" or "rush_off")
    return CheatMode.rush
end

function CheatMode.pending() return pending end

local function pressFork(idx)
    local WorldRoad = require("src.ui.WorldRoad")
    local f = WorldRoad._fork
    if not f then
        local r = run()
        local nodes = r and r.pendingNodes
        if nodes and nodes[idx] then api().onNodeChosen(nodes[idx], idx) end
        return true
    end
    if f.converge then return true end
    local b = f.markBoxes and f.markBoxes[idx]
    if not b or (f.animIn or 0) < 1 then return false end
    WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
    return true
end

local function runPending()
    local g = game()
    if pending.forkPick and state() == "mapSelection" then
        if pressFork(pending.forkPick) then pending.forkPick = nil end
    end
    if pending.win and CheatMode.combatReady(false) then
        pending.win, pending.kill = false, false
        doWinInstant(g)
    elseif pending.kill and CheatMode.combatReady(true) then
        pending.kill = false
        doKill(g)
    end
    if (pending.kill or pending.win) and not CheatMode.RUN_STATES[state() or ""] then
        pending.kill, pending.win = false, false
    end
end

local function captorName()
    local _, name = require("src.ui.InputFocus").captor()
    return name
end

function CheatMode.rushSignature()
    local st = state()
    local sc = screens()
    local sig = tostring(st)
    if st == "cardReward" and sc.reward then sig = sig .. ":" .. tostring(sc.reward.mode) end
    return sig .. ":" .. tostring(captorName())
end

local function firstCardOffer(rw)
    for _, o in ipairs(rw.shopOffers or {}) do
        if o.type == "card" and not o.purchased then return o end
    end
    return nil
end

local function rareStillHidden(rw)
    for _, o in ipairs(rw.shopOffers or {}) do
        if o.type == "card" and rw:_isRareHidden(o) then return true end
    end
    return false
end

local function rushAct()
    local st, g, sc = state(), game(), screens()
    local cap = captorName()
    if cap == "endlessCurse" then
        _G.endlessCurseScreen:choose(1)
        return true
    end
    if cap and cap ~= "roundEval" then return false end
    if st == "playing" then
        if nodeType() == "boss" and g.enemy and g.enemy:isAlive() then
            CheatMode.rush = false
            say("rush_boss")
            return true
        end
        if CheatMode.inBattle() and not pending.kill then pending.kill = true end
        return false
    elseif st == "roundEval" then
        local re = sc.roundEval
        if re and re:isVisible() and re.cashOutReady and not re._closing then
            re:_onCashOutClick()
            return true
        end
    elseif st == "cardReward" then
        local rw = sc.reward
        if not (rw and rw:isVisible()) or rw._closing then return false end
        if sc.packOpen and sc.packOpen:isVisible() then return false end
        if rw.mode == "rewards" then
            if rw._rewardTaken then return false end
            local offer = firstCardOffer(rw)
            if offer then
                if rareStillHidden(rw) then return false end
                rw:purchaseOffer(offer, offer.id)
                return true
            end
        end
        if rw.skipButton and rw.skipButton.onClick then
            rw.skipButton.onClick()
            return true
        end
    elseif st == "mapSelection" then
        if pending.forkPick == nil then
            pending.forkPick = 1
            return true
        end
    elseif st == "rest" then
        local rs = sc.rest
        if not (rs and rs:isVisible()) or rs.busy or rs.forge or rs.resultText then return false end
        if rs.mode == "choose" and #(rs.choiceCards or {}) > 0 then
            rs:doHeal()
            return true
        end
        local back = rs.buttons and rs.buttons[#rs.buttons]
        if back and back.onClick then back.onClick() return true end
    elseif st == "event" then
        local ev = sc.event
        if not (ev and ev:isVisible()) or ev._closing or ev.resultText then return false end
        for _, b in ipairs(ev.buttons or {}) do
            if not b.disabled and b.onClick then
                b.onClick()
                return true
            end
        end
    end
    return false
end

local function rushStep(dt)
    local st = state()
    if st == "victory" or st == "gameOver" then
        CheatMode.rush = false
        say("rush_off")
        return
    end
    if not CheatMode.inRun() then return end
    local sig = CheatMode.rushSignature()
    if sig ~= rushKey then rushKey, rushT = sig, 0 end
    rushT = rushT + dt
    local gap = CheatMode.RUSH_GAP
    if rushT < gap then return end
    if rushAct() then rushT = 0 end
end

local function applySettingsOnce()
    if settingsApplied then return end
    local gs = _G.gameSettings
    if not gs then return end
    settingsApplied = true
    gs.tipsEnabled = false
end

function CheatMode.update(dt)
    if not CheatMode.active then return end
    applySettingsOnce()
    if statusT > 0 then statusT = math.max(0, statusT - dt) end
    local g = game()
    if CheatMode.infiniteMana and g and g.player and g.player.mana < g.player.maxMana then
        g.player.mana = g.player.maxMana
    end
    if CheatMode.rush then rushStep(dt) end
    runPending()
end

function CheatMode.actions()
    return require("src.ui.CheatActions").list()
end

function CheatMode.keypressed(key)
    if not CheatMode.active then return false end
    if key == "f1" then
        CheatMode.panelOpen = not CheatMode.panelOpen
        return true
    end
    if key == "pageup" or key == "pagedown" then
        local id = require("src.ui.CRTShader").cycleVariant(key == "pageup" and 1 or -1)
        local g = game()
        if g and g.addMessage then
            g:addMessage(require("src.i18n.I18n").t("cheat.crt_variant", { name = id }, "CRT: {name}"), "info")
        end
        return true
    end
    local CheatActions = require("src.ui.CheatActions")
    local ctrl = love.keyboard.isDown("lctrl", "rctrl")
    local shift = love.keyboard.isDown("lshift", "rshift")
    local action = CheatActions.forKey(key, ctrl, shift)
    if not action then return false end
    if CheatActions.isAvailable(action) then action.run() end
    return true
end

function CheatMode.mousepressed(x, y, button)
    if not CheatMode.active or state() == "boot" then return false end
    pressInside = require("components.CheatPanel").mousepressed(x, y, button) == true
    return pressInside
end

function CheatMode.mousereleased(x, y, button)
    if not CheatMode.active then return false end
    local was = pressInside
    pressInside = false
    return was
end

function CheatMode.draw()
    if not CheatMode.active or state() == "boot" then return end
    require("components.CheatPanel").draw()
end

return CheatMode
