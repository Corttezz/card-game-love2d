local Sfx = require("src.systems.Sfx")
local Debug = require("src.core.Debug")
local Data = require("src.data.enemy_sfx")

local EnemySfx = {}

local index = nil
local loaded = {}
local lastCode = {}
local lastT = {}
local warned = {}
local loadedFor = nil

function EnemySfx.now()
    return love.timer.getTime()
end

function EnemySfx.reset()
    lastCode, lastT, warned = {}, {}, {}
end

function EnemySfx.rescan()
    index, loaded, loadedFor = nil, {}, nil
    EnemySfx.reset()
end

function EnemySfx.idOf(enemy)
    if not enemy then return nil end
    local id = enemy.spriteId
    if not id or id == "" then
        id = enemy.kitId ~= "generic" and enemy.kitId or nil
    end
    return id and (Data.ALIAS[id] or id) or nil
end

function EnemySfx.scan()
    local out = {}
    local fs = love.filesystem
    for _, id in ipairs(fs.getDirectoryItems(Data.DIR) or {}) do
        local dir = Data.DIR .. "/" .. id
        local info = fs.getInfo(dir)
        if info and info.type == "directory" then
            local items = fs.getDirectoryItems(dir) or {}
            table.sort(items)
            for _, name in ipairs(items) do
                local event, n = name:match("^(%a+)_(%d+)%.mp3$")
                if event and Data.EVENTS[event] then
                    out[id] = out[id] or {}
                    out[id][event] = out[id][event] or {}
                    local list = out[id][event]
                    list[#list + 1] = { code = "enemyVoice_" .. id .. "_" .. event .. n,
                                        path = dir .. "/" .. name }
                end
            end
        end
    end
    return out
end

function EnemySfx.files(id, event)
    if not index then index = EnemySfx.scan() end
    local byId = id and index[Data.ALIAS[id] or id]
    return byId and byId[event] or {}
end

local function ensure(id)
    local a = _G.audioSystem
    if not a or not a.loadSound then return nil end
    if loadedFor ~= a then loadedFor, loaded = a, {} end
    if loaded[id] then return loaded[id] end
    local pools = {}
    for event, spec in pairs(Data.EVENTS) do
        pools[event] = {}
        for _, f in ipairs(EnemySfx.files(id, event)) do
            if not Sfx.has(f.code) then a:loadSound(f.code, f.path, { volume = spec.volume }) end
            if Sfx.has(f.code) then pools[event][#pools[event] + 1] = f.code end
        end
    end
    loaded[id] = pools
    return pools
end

local function cooled(last, now, cd)
    if not last or cd <= 0 then return true end
    local dt = now - last
    return dt < 0 or dt >= cd
end

local function pick(key, pool)
    if #pool == 1 then return pool[1] end
    local choices = {}
    for _, code in ipairs(pool) do
        if code ~= lastCode[key] then choices[#choices + 1] = code end
    end
    return choices[love.math.random(1, #choices)]
end

function EnemySfx.play(enemy, event)
    local spec = Data.EVENTS[event]
    if not spec or not _G.audioSystem then return nil end
    local id = EnemySfx.idOf(enemy)
    local pools = id and ensure(id)
    if not pools then return nil end
    local pool = pools[event] or {}
    if #pool == 0 then
        local key = tostring(id) .. ":" .. event
        if spec.warn and not warned[key] then
            warned[key] = true
            Debug.warn("[EnemySfx] sem voz propria:", id, event)
        end
        return nil
    end
    local now = EnemySfx.now()
    if not cooled(lastT[event], now, spec.cooldown or 0) then return false end
    local code = pick(id .. ":" .. event, pool)
    lastT[event] = now
    lastCode[id .. ":" .. event] = code
    Sfx.playWithVariation(code, 1.0, spec.pitchVar or 0)
    return code
end

function EnemySfx.hurt(enemy, lost, level)
    if level == "immune" or (lost or 0) <= 0 then return nil end
    if not enemy or (enemy.health or 0) <= 0 then return nil end
    return EnemySfx.play(enemy, "hurt")
end

function EnemySfx.death(enemy)
    local code = EnemySfx.play(enemy, "death")
    if code ~= nil then return code end
    local fb = Data.EVENTS.death.fallback
    Sfx.play(fb)
    return fb
end

function EnemySfx.attack(enemy)
    return EnemySfx.play(enemy, "attack")
end

function EnemySfx.roar(enemy)
    return EnemySfx.play(enemy, "roar")
end

return EnemySfx
