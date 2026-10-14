local TK = {}

local function fmt(v)
    if type(v) == "number" then
        if v ~= v then return "nan" end
        if v == math.floor(v) then return tostring(math.floor(v)) end
        return string.format("%.4g", v)
    end
    if type(v) == "string" then return '"' .. v .. '"' end
    return tostring(v)
end

local Tester = {}
Tester.__index = Tester

function TK.new(section)
    print("---- " .. tostring(section) .. " ----")
    return setmetatable({ pass = 0, fail = 0, section = section }, Tester)
end

function Tester:check(name, cond)
    if cond then
        self.pass = self.pass + 1
        print("  [ok] " .. name)
    else
        self.fail = self.fail + 1
        print("  [FAIL] " .. name)
    end
    return cond and true or false
end

function Tester:eq(name, got, want)
    return self:check(name .. "  (esperado " .. fmt(want) .. ", obtido " .. fmt(got) .. ")",
        got == want)
end

function Tester:near(name, got, want, eps)
    eps = eps or 1e-6
    local ok = type(got) == "number" and math.abs(got - want) <= eps
    return self:check(name .. "  (~" .. fmt(want) .. ", obtido " .. fmt(got) .. ")", ok)
end

function Tester:truthy(name, v) return self:check(name, v and true or false) end
function Tester:falsy(name, v) return self:check(name, not v) end

function Tester:throws(name, fn)
    local ok = pcall(fn)
    return self:check(name .. "  (esperava erro)", not ok)
end

function Tester:noerror(name, fn)
    local ok, err = pcall(fn)
    return self:check(name .. (ok and "" or ("  ERRO: " .. tostring(err))), ok)
end

function TK.verdict(ok)
    print(ok and "\n== ALL GREEN ==" or "\n== SOME FAILED ==")
    return ok
end

function Tester:done()
    print(string.format("\n  TOTAL: %d pass / %d fail", self.pass, self.fail))
    return self.fail == 0
end

function TK.seedRng(seed)
    local Rng = require("src.systems.Rng")
    local r = Rng.new(seed or 12345)
    Rng.setActive(r)
    return r
end

function TK.bootstrap()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.ui.UiScale").force(1)
    local I18n = require("src.i18n.I18n")
    if I18n.init and not TK._i18nDone then
        I18n.init()
        TK._i18nDone = true
    end
end

function TK.newRunGame(class)
    TK.bootstrap()
    local Game = require("src.core.Game")
    local g = Game:new()
    g:startNewRun(class or "warrior")
    g:startGame()
    return g
end

function TK.pump(game, secs)
    local dt = 1 / 30
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    for _ = 1, math.floor((secs or 0) * 30) do
        _G.EventManager.update(dt)
        if EnemyRenderer.update then EnemyRenderer.update(dt) end
        if game and game.enemy and game.enemy.update then game.enemy:update(dt) end
        if game and game.combatAnimationSystem then game.combatAnimationSystem:update(dt) end
    end
end

function TK.mockGame(opts)
    opts = opts or {}
    local Player = require("src.entities.Player")
    local Enemy = require("src.entities.Enemy")
    local EffectSystem = require("src.systems.EffectSystem")
    local g = {
        player = Player:new(),
        enemy = Enemy:new(opts.enemyHp or 100, opts.enemyDmg or 5),
        hand = {},
        deck = {},
        discard = {},
        jokerSlots = {},
        score = 0,
        messages = {},
        selectedClass = opts.class,
    }
    function g:addMessage(text, level)
        self.messages[#self.messages + 1] = { text = text, level = level }
    end
    function g:drawCard(_delay)
        self.hand[#self.hand + 1] = { id = "stub_draw", type = "attack", attack = 1, cost = 0 }
        return true
    end
    g.effectSystem = EffectSystem:new()
    return g
end

function TK.count(list, pred)
    local n = 0
    for _, v in ipairs(list) do if pred(v) then n = n + 1 end end
    return n
end

return TK
