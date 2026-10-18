local Sfx = require("src.systems.Sfx")

local CrowSfx = {}

CrowSfx.DIR = "audio/sfx/boss/crow"
CrowSfx.GROUP_MIN = 3
CrowSfx.ATTACK_COOLDOWN = 1.2
CrowSfx.DIVE_DELAY = 0.18

CrowSfx.MOMENTS = {
    crowAppear = { file = "appear", volume = 0.55, pitchVar = 0.06, cooldown = 1.2 },
    crowDive   = { file = "dive",   volume = 0.45, pitchVar = 0.07, cooldown = 1.2 },
    crowFlock  = { file = "flock",  volume = 0.50, pitchVar = 0.05, cooldown = 1.2 },
    crowCine   = { file = "cine",   volume = 0.60, pitchVar = 0.04, cooldown = 0.6 },
}

local variants = {}
local lastCode = {}
local lastT = {}
local lastAttackT = nil
local volleyGrouped = false
local loadedFor = nil

function CrowSfx.now()
    return love.timer.getTime()
end

function CrowSfx.reset()
    lastCode, lastT, lastAttackT, volleyGrouped = {}, {}, nil, false
end

function CrowSfx.handles(code)
    return code ~= nil and CrowSfx.MOMENTS[code] ~= nil
end

function CrowSfx.scan()
    local out = {}
    for moment in pairs(CrowSfx.MOMENTS) do out[moment] = {} end
    local items = love.filesystem.getDirectoryItems(CrowSfx.DIR) or {}
    table.sort(items)
    for _, name in ipairs(items) do
        local file, n = name:match("^(%a+)_(%d+)%.mp3$")
        if file then
            for moment, spec in pairs(CrowSfx.MOMENTS) do
                if spec.file == file then
                    out[moment][#out[moment] + 1] = {
                        code = moment .. n, path = CrowSfx.DIR .. "/" .. name,
                    }
                end
            end
        end
    end
    return out
end

function CrowSfx.load()
    local a = _G.audioSystem
    if not a or not a.loadSound then return false end
    if loadedFor == a then return true end
    loadedFor = a
    variants = {}
    for moment, list in pairs(CrowSfx.scan()) do
        local spec = CrowSfx.MOMENTS[moment]
        variants[moment] = {}
        for _, v in ipairs(list) do
            if not Sfx.has(v.code) then
                a:loadSound(v.code, v.path, { volume = spec.volume })
            end
            if Sfx.has(v.code) then
                variants[moment][#variants[moment] + 1] = v.code
            end
        end
    end
    return true
end

function CrowSfx.variants(moment)
    CrowSfx.load()
    return variants[moment] or {}
end

local function pick(moment)
    local pool = variants[moment]
    if not pool or #pool == 0 then return nil end
    if #pool == 1 then return pool[1] end
    local choices = {}
    for _, code in ipairs(pool) do
        if code ~= lastCode[moment] then choices[#choices + 1] = code end
    end
    return choices[love.math.random(1, #choices)]
end

local function cooled(last, now, cd)
    if not last or cd <= 0 then return true end
    local dt = now - last
    return dt < 0 or dt >= cd
end

function CrowSfx.play(moment, opts)
    local spec = CrowSfx.MOMENTS[moment]
    if not spec or not CrowSfx.load() then return nil end
    local now = CrowSfx.now()
    if not cooled(lastT[moment], now, spec.cooldown or 0) then return nil end
    local code = pick(moment)
    if not code then return nil end
    lastT[moment] = now
    lastCode[moment] = code
    local delay = opts and opts.delay or 0
    local function fire()
        Sfx.playWithVariation(code, 1.0, spec.pitchVar or 0)
    end
    if delay > 0 and _G.EventManager and _G.EventManager.after then
        _G.EventManager.after(delay, fire)
    else
        fire()
    end
    return code
end

function CrowSfx.attack(hitIndex, hits)
    hitIndex, hits = hitIndex or 1, hits or 1
    local now = CrowSfx.now()
    if hitIndex == 1 then volleyGrouped = false end
    if not cooled(lastAttackT, now, CrowSfx.ATTACK_COOLDOWN) then return nil end
    local moment
    if hitIndex == 1 then
        moment = "crowDive"
    elseif hits >= CrowSfx.GROUP_MIN and not volleyGrouped then
        moment = "crowFlock"
    else
        return nil
    end
    local code = CrowSfx.play(moment, { delay = CrowSfx.DIVE_DELAY })
    if code then
        lastAttackT = now
        if moment == "crowFlock" then volleyGrouped = true end
    end
    return code
end

return CrowSfx
