local Debug = require("src.core.Debug")

local InputFocus = {}

InputFocus.SCENE  = "scene"
InputFocus.CHROME = "chrome"

InputFocus.OFFSCREEN = -32000

local overlays = {}
local stack    = {}

local rawGetPosition, mapToContent, wrapper
local positionOverride

function InputFocus.setPositionOverride(fn) positionOverride = fn end

function InputFocus.clear()
    overlays = {}
    stack = {}
end

function InputFocus.register(name, obj, opts)
    opts = opts or {}
    if type(name) ~= "string" or obj == nil then
        Debug.warn("[InputFocus] registro invalido (name=" .. tostring(name)
            .. ", obj=" .. tostring(obj) .. ") — overlay IGNORADO")
        return nil
    end
    if type(obj.isVisible) ~= "function" then
        Debug.warn("[InputFocus] '" .. name .. "' nao expoe isVisible() — ele NAO vai "
            .. "bloquear o hover de tras. Adicione isVisible() na tela.")
        return nil
    end
    local keepChrome = opts.keepChrome and true or false
    local entry = {
        name = name,
        obj = obj,
        keepChrome = keepChrome,
        capturesEvents = not keepChrome,
    }
    for i, e in ipairs(overlays) do
        if e.name == name then overlays[i] = entry; return entry end
    end
    overlays[#overlays + 1] = entry
    return entry
end

function InputFocus.count() return #overlays end

function InputFocus.freezesCombat(state)
    if state ~= "playing" then return false end
    return InputFocus.captor() ~= nil
end

function InputFocus.hideAll()
    local n = 0
    for i = #overlays, 1, -1 do
        local e = overlays[i]
        local ok, vis = pcall(e.obj.isVisible, e.obj)
        if ok and vis then
            if type(e.obj.hide) == "function" then
                e.obj:hide()
                n = n + 1
            else
                Debug.warn("[InputFocus] '" .. e.name .. "' visivel sem hide() — "
                    .. "nao da pra fechar ao voltar pro menu")
            end
        end
    end
    return n
end

function InputFocus.names()
    local t = {}
    for i, e in ipairs(overlays) do t[i] = e.name end
    return t
end

local function topVisible()
    for i = #overlays, 1, -1 do
        local e = overlays[i]
        local ok, vis = pcall(e.obj.isVisible, e.obj)
        if not ok then
            Debug.warn("[InputFocus] isVisible() de '" .. e.name .. "' falhou: "
                .. tostring(vis))
        elseif vis then
            return e
        end
    end
    return nil
end

function InputFocus.active() return topVisible() end

function InputFocus.activeName()
    local e = topVisible()
    return e and e.name or nil
end

function InputFocus.captor()
    local e = topVisible()
    if e and e.capturesEvents then return e.obj, e.name end
    return nil
end

function InputFocus.push(layer) stack[#stack + 1] = layer end
function InputFocus.pop() stack[#stack] = nil end
function InputFocus.current() return stack[#stack] end

local warnedLeak = false
function InputFocus.resetLayers()
    if #stack > 0 and not warnedLeak then
        warnedLeak = true
        Debug.warn("[InputFocus] camada VAZOU entre frames: '"
            .. tostring(stack[#stack]) .. "' (push sem pop no dispatch). "
            .. "Hover de tras pode ficar apagado ate reiniciar.")
    end
    for i = #stack, 1, -1 do stack[i] = nil end
end

local function entryNamed(name)
    for _, e in ipairs(overlays) do
        if e.name == name then return e end
    end
    return nil
end

function InputFocus.allows(layer)
    if layer == nil then layer = stack[#stack] end
    local e = topVisible()
    if not e then return true end
    if layer == nil then return true end
    if layer == e.name then return true end
    if layer == InputFocus.CHROME and e.keepChrome then return true end

    if not e.capturesEvents then
        local mine = entryNamed(layer)
        if mine and not mine.capturesEvents then
            local ok, vis = pcall(mine.obj.isVisible, mine.obj)
            if ok and vis then return true end
        end
    end

    return false
end

function InputFocus.gate(x, y)
    if InputFocus.allows() then return x, y end
    return InputFocus.OFFSCREEN, InputFocus.OFFSCREEN
end

function InputFocus.installMouseGate(screenToContent, rawFn)
    if rawFn then
        rawGetPosition = rawFn
    elseif not (rawGetPosition and love.mouse.getPosition == wrapper) then
        rawGetPosition = love.mouse.getPosition
    end
    mapToContent = screenToContent

    wrapper = function()
        local x, y = rawGetPosition()
        if mapToContent then x, y = mapToContent(x, y) end
        if positionOverride then
            local ox, oy = positionOverride()
            if ox then x, y = ox, oy end
        end
        return InputFocus.gate(x, y)
    end

    love.mouse.getPosition = wrapper
    love.mouse.getX = function() local x = wrapper(); return x end
    love.mouse.getY = function() local _, y = wrapper(); return y end
    return wrapper
end

return InputFocus
