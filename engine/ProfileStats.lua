local Debug = require("src.core.Debug")

local SaveManager = require("engine.SaveManager")

local ProfileStats = {}

local PATH = "profile.lua"

local recoveryMode = false
local recoveryWarned = false
local testPath = nil

local DEFAULTS = {
    runs      = 0,
    wins      = 0,
    losses    = 0,
    bestAct   = 0,
    bestFloor = 0,
    bestScore = 0,
    lastClass = nil,
    achievements = {},
    counters = {},
    cardsSeen = {},
    winsByClass = {},
    tipsSeen = {},
}

local cache = nil

local function load()
    if cache then return cache end
    cache = {}
    for k, v in pairs(DEFAULTS) do cache[k] = v end
    cache.achievements = {}
    cache.counters = {}
    cache.cardsSeen = {}
    cache.winsByClass = {}
    cache.tipsSeen = {}
    local data, info = SaveManager.readDataFile(testPath or PATH)
    if data then
        for k, v in pairs(data) do cache[k] = v end
        if info.source ~= "main" then
            Debug.warn("[ProfileStats] !!! perfil RECUPERADO de " .. tostring(info.source)
                .. " (principal ilegivel" .. (info.corruptCopy
                    and (", copia em " .. info.corruptCopy) or "") .. ")")
        end
    elseif info.existed then
        recoveryMode = true
        Debug.err("[ProfileStats] !!!!!! PERFIL ILEGIVEL E SEM BACKUP VALIDO — modo"
            .. " recuperacao: o jogo NAO vai gravar o perfil nesta sessao para"
            .. " nao apagar o progresso. Copia: " .. tostring(info.corruptCopy))
    end
    return cache
end

local function save()
    if not cache then return end
    if _G.HEADLESS_TOOL and not testPath then return end
    if recoveryMode then
        if not recoveryWarned then
            recoveryWarned = true
            Debug.warn("[ProfileStats] modo recuperacao: gravacao do perfil RECUSADA")
        end
        return
    end
    local ok, err = SaveManager.writeFile(testPath or PATH,
        "return " .. SaveManager.serialize(cache))
    if not ok then Debug.err("[ProfileStats] falha ao salvar perfil: " .. tostring(err)) end
end

function ProfileStats.isRecoveryMode()
    load()
    return recoveryMode
end

function ProfileStats._setPathForTests(path)
    testPath = path
    cache = nil
    recoveryMode = false
    recoveryWarned = false
end

function ProfileStats.get()
    return load()
end

function ProfileStats.recordRunStart(classId)
    local s = load()
    s.runs = s.runs + 1
    s.lastClass = classId
    save()
end

local function bumpBest(actNumber, floorInAct)
    local s = load()
    actNumber = actNumber or 0
    floorInAct = floorInAct or 0
    if actNumber > s.bestAct
        or (actNumber == s.bestAct and floorInAct > s.bestFloor) then
        s.bestAct = actNumber
        s.bestFloor = floorInAct
    end
end

function ProfileStats.recordVictory(actNumber, floorInAct, classId)
    local s = load()
    s.wins = s.wins + 1
    if classId then
        s.winsByClass = s.winsByClass or {}
        s.winsByClass[classId] = true
    end
    bumpBest(actNumber, floorInAct)
    save()
end

function ProfileStats.recordDefeat(actNumber, floorInAct)
    local s = load()
    s.losses = s.losses + 1
    bumpBest(actNumber, floorInAct)
    save()
end

function ProfileStats.updateBestScore(score)
    if not score or score <= 0 then return end
    local s = load()
    if score > (s.bestScore or 0) then
        s.bestScore = score
        save()
    end
end

function ProfileStats.bump(key, n)
    local s = load()
    s.counters = s.counters or {}
    s.counters[key] = (s.counters[key] or 0) + (n or 1)
end

function ProfileStats.markSeen(cardId)
    if not cardId then return end
    local s = load()
    s.cardsSeen = s.cardsSeen or {}
    s.cardsSeen[cardId] = true
end

function ProfileStats.isTipSeen(id)
    local s = load()
    return s.tipsSeen ~= nil and s.tipsSeen[id] == true
end

function ProfileStats.markTipSeen(id)
    if not id then return end
    local s = load()
    s.tipsSeen = s.tipsSeen or {}
    if s.tipsSeen[id] then return end
    s.tipsSeen[id] = true
    save()
end

function ProfileStats.resetTips()
    local s = load()
    local n = 0
    for _ in pairs(s.tipsSeen or {}) do n = n + 1 end
    s.tipsSeen = {}
    save()
    return n
end

function ProfileStats.tipsSeenCount()
    local n = 0
    for _ in pairs(load().tipsSeen or {}) do n = n + 1 end
    return n
end

function ProfileStats.flush()
    save()
end

function ProfileStats._swapForTests(tbl)
    local prev = cache
    cache = tbl
    if tbl then
        tbl.achievements = tbl.achievements or {}
        tbl.counters = tbl.counters or {}
        tbl.cardsSeen = tbl.cardsSeen or {}
        tbl.winsByClass = tbl.winsByClass or {}
        tbl.tipsSeen = tbl.tipsSeen or {}
        for k, v in pairs(DEFAULTS) do
            if tbl[k] == nil and type(v) ~= "table" then tbl[k] = v end
        end
    end
    return prev
end

function ProfileStats.hasHistory()
    return load().runs > 0
end

return ProfileStats
