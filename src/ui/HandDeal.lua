-- src/ui/HandDeal.lua
-- CORTINA DA MÃO + DISTRIBUIÇÃO das cartas (Out/2026, bug do dono: "a mão,
-- os botões e o HUD aparecem no meio da porta do castelo e da entrada do
-- chefe").
--
-- Regra: enquanto a cena está em CUTSCENE (viagem na estrada, cerimônia da
-- porta, salão à espera do chefe, entrada/morte do chefe, quicada de chegada)
-- a mão, os botões, o quadro de coringas e a prévia NÃO existem na tela. No
-- salão o HUD (painel do herói, mana, HUD do inimigo) também espera. Quando
-- a cortina sobe, as cartas são DISTRIBUÍDAS uma a uma a partir da pilha do
-- deck (materialize + som, escalonadas), e SÓ DEPOIS da última carta entram
-- botões e HUD. É a ordem de um jogo de mesa: o oponente senta, as cartas
-- são dadas, aí você joga.
--
-- Quem decide se a cortina está abaixada é o GameplayScene (ele conhece a
-- viagem, a porta e a cinemática); este módulo só guarda o estado, toca a
-- distribuição e responde às perguntas do draw/input:
--   setCurtain(down, game, { hud = bool })  todo frame, antes do update
--   update(dt, game)                        toca a distribuição
--   hidesHand()   mão inteira some (cortina)
--   holds(card)   a carta ainda não foi dada (fica na pilha, invisível)
--   hidesUI()     botões/coringas/prévia esperam (cortina OU distribuindo)
--   hidesHud()    HUD espera (só no modo hud — salão)
--   isBusy()      cortina ou distribuição em curso (input da mão fechado,
--                 narrador do tutorial espera)
--
-- Linha do tempo própria (dt acumulado): sem EventManager a carta aparece
-- de uma vez no instante dela (testes/autoplay); com ele, materializa.

local HandDeal = {}

-- intervalo entre cartas e respiro depois da última antes dos botões
HandDeal.STAGGER = 0.11
HandDeal.TAIL = 0.30

local curtain = false      -- cortina abaixada
local hudMode = false      -- HUD também espera (latched enquanto a cortina está abaixada)
local uiHidden = false     -- botões/HUD esperam (da cortina até o fim da distribuição)
local deal = nil           -- { cards, idx, t }
local held = {}            -- card -> true (ainda na pilha)

local function hasEM()
    return _G.EventManager ~= nil and _G.Event ~= nil
end

function HandDeal.reset()
    curtain, hudMode, uiHidden = false, false, false
    deal = nil
    held = {}
end

-- Começa a distribuição: toda carta da mão volta pra pilha (invisível) e
-- sai de lá uma por vez no update. Sem carta ou sem luta (inimigo morto,
-- espólios a caminho) não há o que dar: a UI volta direto.
local function beginDeal(game)
    held = {}
    local cards = {}
    local alive = game and game.enemy and (not game.enemy.isAlive or game.enemy:isAlive())
    if game and game.hand and alive then
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

-- Dá a carta `c`: sai da pilha, materializa (ou aparece, sem EventManager),
-- som de compra com pitch subindo a cada carta.
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
            deal = nil   -- distribuição interrompida: as cartas que faltavam ficam na pilha
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

function HandDeal.hidesHand() return curtain end
function HandDeal.holds(card) return held[card] == true end
function HandDeal.hidesUI() return curtain or uiHidden end
function HandDeal.hidesHud() return hudMode and (curtain or uiHidden) end
function HandDeal.isBusy() return curtain or deal ~= nil end
function HandDeal.isDealing() return deal ~= nil end

-- Quantas cartas da mão estão VISÍVEIS (nem cortina, nem na pilha). Pros
-- testes e pras ferramentas de captura.
function HandDeal.visibleCount(game)
    if curtain or not game or not game.hand then return 0 end
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
