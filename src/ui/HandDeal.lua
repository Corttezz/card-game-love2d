local HandDeal = {}

HandDeal.STAGGER = 0.11
HandDeal.TAIL = 0.30

local curtain = false
local hudMode = false
local uiHidden = false
local closed = false
local deal = nil
local held = {}

local function hasEM()
    return _G.EventManager ~= nil and _G.Event ~= nil
end

function HandDeal.reset()
    curtain, hudMode, uiHidden, closed = false, false, false, false
    deal = nil
    held = {}
end

local function beginDeal(game)
    held = {}
    local cards = {}
    local alive = game and game.enemy and (not game.enemy.isAlive or game.enemy:isAlive())
    if not alive then
        deal = nil
        closed = true
        return
    end
    if game and game.hand then
        for _, c in ipairs(game.hand) do
            if c.cancelDissolveAnim then c:cancelDissolveAnim() end
            c.dissolve = 1
            c.isHovered = false
            c.dragPending = false
            c.isDragging = false
            held[c] = true
            cards[#cards + 1] = c
        end
    end
    if #cards == 0 then
        deal = nil
        uiHidden = false
        hudMode = false
        return
    end
    deal = { cards = cards, idx = 1, t = 0 }
    uiHidden = true
end

local function release(c, n)
    held[c] = nil
    if hasEM() and c.start_materialize then
        c:start_materialize(nil, true, 0.35)
    else
        c.dissolve = 0
    end
    local ok, Sfx = pcall(require, "src.systems.Sfx")
    if ok and Sfx.playWithVariation then
        pcall(Sfx.playWithVariation, "cardDraw", 1.0 + (n - 1) * 0.03, 0.06)
    end
end

function HandDeal.setCurtain(down, game, opts)
    down = down and true or false
    if down then
        hudMode = hudMode or (opts and opts.hud) or false
        if not curtain then
            curtain = true
            uiHidden = true
            closed = false
            deal = nil
        end
        return
    end
    if curtain then
        curtain = false
        beginDeal(game)
    end
end

function HandDeal.update(dt, game)
    if not deal then return end
    deal.t = deal.t + dt
    local hand = game and game.hand or {}
    local inHand = {}
    for _, c in ipairs(hand) do inHand[c] = true end
    while deal.idx <= #deal.cards and deal.t >= (deal.idx - 1) * HandDeal.STAGGER do
        local c = deal.cards[deal.idx]
        if inHand[c] then release(c, deal.idx) else held[c] = nil end
        deal.idx = deal.idx + 1
    end
    if deal.idx > #deal.cards and deal.t >= (#deal.cards - 1) * HandDeal.STAGGER + HandDeal.TAIL then
        deal = nil
        uiHidden = false
        hudMode = false
    end
end

function HandDeal.hidesHand() return curtain or closed end
function HandDeal.holds(card) return held[card] == true end
function HandDeal.hidesUI() return curtain or uiHidden or closed end
function HandDeal.hidesHud() return hudMode and (curtain or uiHidden or closed) end
function HandDeal.isBusy() return curtain or closed or deal ~= nil end
function HandDeal.isDealing() return deal ~= nil end
function HandDeal.isClosed() return closed end

function HandDeal.visibleCount(game)
    if curtain or closed or not game or not game.hand then return 0 end
    local n = 0
    for _, c in ipairs(game.hand) do
        if not held[c] then n = n + 1 end
    end
    return n
end

function HandDeal._debug()
    return { curtain = curtain, hudMode = hudMode, uiHidden = uiHidden,
             deal = deal and { idx = deal.idx, t = deal.t, n = #deal.cards } or nil }
end

return HandDeal
