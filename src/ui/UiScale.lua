local Debug = require("src.core.Debug")

local UiScale = {}

UiScale.BASE_W, UiScale.BASE_H = 1280, 720
UiScale.MIN_AUTO, UiScale.MAX_AUTO = 1, 2.5
UiScale.OPTIONS = { 0.8, 0.9, 1, 1.25, 1.5 }

local userMul = 1
local deviceMul = (os.getenv("SteamDeck") == "1") and 1.25 or 1
function UiScale.setDeviceMultiplier(m) deviceMul = tonumber(m) or 1 end
function UiScale.deviceMultiplier() return deviceMul end
local forcedK = nil
local depth = 0
local saved = nil
local activeK = 1
local vw, vh = 0, 0
local chromeScaled = true
local suspended = 0

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function UiScale.setUserMultiplier(m)
    m = tonumber(m) or 1
    if m <= 0 then
        Debug.warn("[UiScale] multiplicador invalido (" .. tostring(m) .. "), usando 1")
        m = 1
    end
    userMul = m
end
function UiScale.userMultiplier() return userMul end

function UiScale.force(k) forcedK = k end

function UiScale.auto(w, h)
    return clamp(math.min(w / UiScale.BASE_W, h / UiScale.BASE_H),
        UiScale.MIN_AUTO, UiScale.MAX_AUTO)
end

function UiScale.k(w, h)
    if forcedK then return forcedK end
    if not w then
        if depth > 0 then return activeK end
        w, h = love.graphics.getWidth(), love.graphics.getHeight()
    end
    local k = math.floor(UiScale.auto(w, h) * deviceMul * userMul * 4 + 0.001) / 4
    return clamp(k, 0.75, 3)
end

function UiScale.activeK() return depth > 0 and activeK or 1 end
function UiScale.isActive() return depth > 0 end

function UiScale.setChromeScaled(b) chromeScaled = b and true or false end
function UiScale.chromeScaled() return chromeScaled end
function UiScale.chromeK() return chromeScaled and UiScale.k() or 1 end

function UiScale.toVirtual(x, y)
    local k = UiScale.k()
    return x / k, y / k
end

local function patch(k)
    local g, m = love.graphics, love.mouse
    saved = {
        gw = g.getWidth, gh = g.getHeight, gd = g.getDimensions,
        ss = g.setScissor, is = g.intersectScissor, gs = g.getScissor,
        mp = m.getPosition, mx = m.getX, my = m.getY, msp = m.setPosition,
    }
    local W, H = saved.gw(), saved.gh()
    vw, vh = math.floor(W / k + 0.5), math.floor(H / k + 0.5)
    local s = saved
    g.getWidth = function() return vw end
    g.getHeight = function() return vh end
    g.getDimensions = function() return vw, vh end
    g.setScissor = function(x, y, w, h)
        if x == nil then return s.ss() end
        return s.ss(math.floor(x * k), math.floor(y * k), math.ceil(w * k), math.ceil(h * k))
    end
    g.intersectScissor = function(x, y, w, h)
        return s.is(math.floor(x * k), math.floor(y * k), math.ceil(w * k), math.ceil(h * k))
    end
    g.getScissor = function()
        local x, y, w, h = s.gs()
        if not x then return nil end
        return x / k, y / k, w / k, h / k
    end
    local function rawMouse()
        local cw, ch, cd = g.getWidth, g.getHeight, g.getDimensions
        g.getWidth, g.getHeight, g.getDimensions = s.gw, s.gh, s.gd
        local ok, x, y = pcall(s.mp)
        g.getWidth, g.getHeight, g.getDimensions = cw, ch, cd
        if not ok then error(x, 0) end
        return x, y
    end
    m.getPosition = function()
        local x, y = rawMouse()
        return x / k, y / k
    end
    m.getX = function() local x = rawMouse(); return x / k end
    m.getY = function() local _, y = rawMouse(); return y / k end
    m.setPosition = function(x, y) return s.msp(x * k, y * k) end
end

local function unpatch()
    local g, m, s = love.graphics, love.mouse, saved
    g.getWidth, g.getHeight, g.getDimensions = s.gw, s.gh, s.gd
    g.setScissor, g.intersectScissor, g.getScissor = s.ss, s.is, s.gs
    m.getPosition, m.getX, m.getY, m.setPosition = s.mp, s.mx, s.my, s.msp
    saved = nil
end

function UiScale.begin(k)
    if depth > 0 then depth = depth + 1 return end
    activeK = k or UiScale.k()
    depth = 1
    if activeK == 1 then return end
    patch(activeK)
    love.graphics.push()
    love.graphics.scale(activeK)
end

function UiScale.finish()
    if depth <= 0 then return end
    depth = depth - 1
    if depth > 0 then return end
    if saved then
        love.graphics.pop()
        unpatch()
    end
    activeK = 1
end

function UiScale.reset()
    if depth > 0 then
        Debug.warn("[UiScale] contexto vazou (profundidade " .. depth .. ") — restaurando")
        if saved then
            pcall(love.graphics.pop)
            unpatch()
        end
        depth, activeK, suspended = 0, 1, 0
    end
end

function UiScale.outside(fn, ...)
    if depth == 0 then return fn(...) end
    local d, k = depth, activeK
    if saved then
        love.graphics.pop()
        unpatch()
    end
    depth, activeK = 0, 1
    suspended = suspended + 1
    local res = { pcall(fn, ...) }
    suspended = suspended - 1
    depth, activeK = d, k
    if k ~= 1 then
        patch(k)
        love.graphics.push()
        love.graphics.scale(k)
    end
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, table.maxn(res))
end

function UiScale.realDimensions()
    if saved then return saved.gw(), saved.gh() end
    return love.graphics.getWidth(), love.graphics.getHeight()
end

function UiScale.run(fn, ...)
    UiScale.begin()
    local res = { pcall(fn, ...) }
    UiScale.finish()
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2)
end

local MOUSE = { mousepressed = true, mousereleased = true, mousemoved = true }

function UiScale.adopt(tbl, opts)
    if type(tbl) ~= "table" or rawget(tbl, "__uiScaleAdopted") then return tbl end
    opts = opts or {}
    local method = opts.method ~= false
    local pred = opts.predicate
    local names = {}
    for name, fn in pairs(tbl) do
        if type(fn) == "function" and name ~= "__index" then names[#names + 1] = name end
    end
    for _, name in ipairs(names) do
        local fn = tbl[name]
        local isMouse = MOUSE[name]
        tbl[name] = function(...)
            if depth > 0 or suspended > 0 or (pred and not pred()) then return fn(...) end
            UiScale.begin()
            local args, n = { ... }, select("#", ...)
            if isMouse and activeK ~= 1 then
                local i = method and 2 or 1
                if type(args[i]) == "number" then args[i] = args[i] / activeK end
                if type(args[i + 1]) == "number" then args[i + 1] = args[i + 1] / activeK end
            end
            local res = { xpcall(fn, debug.traceback, unpack(args, 1, n)) }
            if not res[1] then
                UiScale.reset()
                error(res[2], 0)
            end
            UiScale.finish()
            return unpack(res, 2, table.maxn(res))
        end
    end
    rawset(tbl, "__uiScaleAdopted", true)
    return tbl
end

UiScale.SCREENS = {
    "components.Menu", "components.ClassSelectionScreen",
    "components.CardRewardScreen", "components.CollectionScreen",
    "components.AchievementsScreen", "components.CreditsScreen",
    "components.DeckViewerScreen", "components.JokerManagerScreen",
    "components.RunJournalScreen", "components.ScribeDiceScreen",
    "components.MapScreen", "components.RestScreen",
    "components.EventScreen", "components.PackOpenScreen",
    "components.RoundEvalScreen", "components.PauseMenu",
    "components.SettingsMenu", "components.EndlessCurseScreen",
}
UiScale.MODULES = { "src.scenes.EndScreens", "src.ui.ConfirmDialog", "src.ui.AchievementToast",
    "src.scenes.GameplayScene" }

function UiScale.adoptDefaults()
    for _, mod in ipairs(UiScale.SCREENS) do
        local ok, m = pcall(require, mod)
        if ok then UiScale.adopt(m)
        else Debug.warn("[UiScale] tela nao carregou, fica sem escala: " .. mod .. " (" .. tostring(m) .. ")") end
    end
    for _, mod in ipairs(UiScale.MODULES) do
        UiScale.adopt(require(mod), { method = false })
    end
    UiScale.adopt(require("components.TopBar"), { predicate = UiScale.chromeScaled })
end

function UiScale.fontDpi()
    if depth == 0 or activeK == 1 then return 1 end
    local x0 = love.graphics.transformPoint(0, 0)
    local x1 = love.graphics.transformPoint(1, 0)
    local s = math.abs(x1 - x0)
    return math.max(1, math.min(3, math.floor(s * 4 + 0.5) / 4))
end

return UiScale
