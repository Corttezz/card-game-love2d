local BossJokers = {}

local byBoss = nil

local function index()
    if byBoss then return byBoss end
    byBoss = {}
    local CardDatabase = require("src.systems.CardDatabase")
    for id, cd in pairs(CardDatabase:getAllCards()) do
        if cd.bossId then byBoss[cd.bossId] = id end
    end
    return byBoss
end

function BossJokers.cardFor(bossId)
    if not bossId then return nil end
    return index()[bossId]
end

function BossJokers.isBossJoker(cardId)
    if not cardId then return false end
    local CardDatabase = require("src.systems.CardDatabase")
    local cd = CardDatabase:getCard(cardId)
    return cd ~= nil and cd.bossId ~= nil
end

function BossJokers.all()
    local out = {}
    for bossId, id in pairs(index()) do out[#out + 1] = { bossId = bossId, cardId = id } end
    table.sort(out, function(a, b) return a.cardId < b.cardId end)
    return out
end

local function owns(run, cardId)
    for _, e in ipairs((run and run.jokers) or {}) do
        if (type(e) == "table" and e.id or e) == cardId then return true end
    end
    return false
end

function BossJokers.currentBossId(run)
    local node = run and run.currentNode
    if not node or node.type ~= "boss" then return nil end
    return node.enemyId
end

function BossJokers.offerForBoss(run, bossId)
    local cardId = BossJokers.cardFor(bossId)
    if not cardId or owns(run, cardId) then return nil end
    return cardId
end

function BossJokers.offerFor(run)
    return BossJokers.offerForBoss(run, BossJokers.currentBossId(run))
end

return BossJokers
