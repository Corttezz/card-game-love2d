-- components/CardRewardScreen.lua
-- Tela de recompensas de cartas após vitória em batalha.

local CardRewardScreen = {}
CardRewardScreen.__index = CardRewardScreen

-- FILA DEDICADA das animações desta tela (fix DEFINITIVO Jul/2026 do bug
-- "cartas invisíveis até o hover"): os helpers parallel/parallelEase são
-- blocking=false mas BLOCKABLE=true — na fila "base" eles ficavam PRESOS
-- atrás do rabo bloqueante da sequência de combate que acabou de terminar
-- (EM.after do Game/CombatSequence é blocking). A entrada das cartas só
-- rodava quando a base destravava, segundos depois. Fila própria = o combate
-- nunca trava as animações da loja/recompensa. Limpa a cada show().
local FXQ = "reward_fx"

-- ============ DEBUG (caça ao bug "cartas não renderizam") ============
-- Loga em print E em arquivo (save dir: reward_debug.log) — o arquivo é
-- sobrescrito a cada show(), então contém sempre a ÚLTIMA abertura.
-- Desligar depois: REWARD_DBG = false.
local REWARD_DBG = true
local _dbgStart = 0

local function dbg(fmt, ...)
    if not REWARD_DBG then return end
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = fmt .. " (fmt err)" end
    local t = love.timer.getTime() - _dbgStart
    line = string.format("[RDBG %+7.2fs] %s", t, line)
    print(line)
    pcall(love.filesystem.append, "reward_debug.log", line .. "\n")
end

-- Radiografia da fila do EventManager (trigger/blocking/timer de cada evento).
-- ⚠️ require PRÓPRIO: este bloco vive ANTES dos requires do arquivo — o local
-- `EventManager` de baixo não está em escopo aqui (upvalue só existe abaixo
-- da declaração; o global não existe nos tools).
local function dbgQueue(name)
    if not REWARD_DBG then return end
    local okEM, EM = pcall(require, "engine.EventManager")
    if not okEM or not EM then dbg("dbgQueue: sem EventManager"); return end
    local q = EM.queues and EM.queues[name]
    if not q then dbg("queue '%s': (inexistente)", name); return end
    dbg("queue '%s': %d eventos | EM.paused=%s", name, #q, tostring(EM.paused))
    for i, ev in ipairs(q) do
        dbg("   [%d] trig=%s blocking=%s blockable=%s timer=%.2f delay=%.2f done=%s%s",
            i, tostring(ev.trigger), tostring(ev.blocking), tostring(ev.blockable),
            ev.timer or -1, ev.delay or -1, tostring(ev.completed),
            ev.ease and (" ease:" .. tostring(ev.ease.ref_value)) or "")
    end
end

-- Snapshot por carta: tudo que decide se ela aparece e onde.
local function dbgCards(self, tag)
    if not REWARD_DBG then return end
    for i, inst in ipairs(self.cardInstances or {}) do
        local offer = inst.shopOffer
        local slot = offer and offer._slot
        local anim = slot and self.cardAnimations and self.cardAnimations[slot]
        dbg("%s inst[%d] id=%s slot=%s x=%s y=%s entryOy=%s dissolve=%s curScale=%s animScale=%s animElapsed=%s hover=%s",
            tag, i, tostring(offer and offer.id), tostring(slot),
            tostring(inst.x), tostring(inst.y),
            tostring(inst._entryOy), tostring(inst.dissolve),
            tostring(inst.currentScale),
            tostring(anim and anim.scale), tostring(anim and anim.elapsed),
            tostring(inst.isHovered))
    end
end

local Config = require("src.core.Config")
local Debug = require("src.core.Debug")
local FontManager = require("src.ui.FontManager")
local HintBar = require("src.ui.HintBar")
local Panel9 = require("src.ui.Panel9")
local Theme = require("src.ui.Theme")
local Palette = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local Button = require("components.Button")
local CardDatabase = require("src.systems.CardDatabase")
local CardInfoDisplay = require("src.ui.CardInfoDisplay")
local CardDetailPanel = require("src.ui.CardDetailPanel")
local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")
local EventManager = require("engine.EventManager")
local DissolveShader = require("src.ui.DissolveShader")
local ImageCache = require("src.ui.ImageCache")

-- Acessibilidade: com reducedMotion ligado, transições da tela resolvem
-- instantaneamente (o conteúdo continua idêntico, só não desliza/piscando).
local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

-- Toca o PRIMEIRO código registrado da lista. Contrato do projeto pra som que
-- ainda não existe no disco (mesmo padrão de RestScreen:585 e dos sons-
-- assinatura de joker): o call site nasce pronto, o arquivo chega depois e
-- passa a tocar sozinho. Avisa uma única vez se NENHUM resolver — fallback
-- silencioso é proibido (memory/ui_layout_invariants §3).
local _sfxWarned = {}
local function playFirstSfx(codes, opts)
    for _, code in ipairs(codes) do
        if Sfx.has(code) then
            Sfx.play(code, opts)
            return code
        end
    end
    -- Só avisa se HÁ sistema de áudio: sem ele (headless, tools, WSL2 mudo)
    -- nenhum código resolve e o aviso seria ruído garantido a cada run — o
    -- que treina a ignorar exatamente o aviso que deveria pegar um código
    -- escrito errado.
    if _G.audioSystem then
        local key = table.concat(codes, "/")
        if not _sfxWarned[key] then
            _sfxWarned[key] = true
            Debug.warn("[CardRewardScreen] nenhum sfx registrado em: " .. key)
        end
    end
    return nil
end

-- Puladinha da carta em hover na grade da loja (px). Cresce do RODAPÉ do slot
-- pra cima e sobe mais um tanto — nunca invade o rótulo de raridade abaixo.
local SHOP_HOVER_LIFT = 12

-- offer.type → "kind" do painel de detalhe.
local function offerKind(offer)
    if not offer then return nil end
    if offer.type == "booster_pack" then return "pack" end
    if offer.type == "upgrade" then return "voucher" end
    return "card"
end

-- shopSystem: instância singleton injetada (ver Game:new). Param opcional pra
-- compatibilidade com chamadas antigas — fallback gera warning.
function CardRewardScreen:new(shopSystem)
    local instance = setmetatable({}, CardRewardScreen)

    instance.visible = false
    instance.shopOffers = {}
    instance.cardInstances = {}
    instance.cardButtons = {}
    instance.skipButton = nil
    instance.refreshButton = nil
    instance.onCardPurchased = nil
    instance.onSkipped = nil

    -- Confirmação de compra
    -- Selection (CLICK): mini-buttons Balatro-style (Buy + Cancel) attached
    -- compactos sob a carta clicada.
    instance.selectedOffer = nil
    instance.selectedIdx = nil
    instance._selectionAnim = 0
    instance._selectionButtons = {}
    -- Hover (mouse-over sem clicar): alimenta o painel de DETALHE FIXO do
    -- split-view (terceira coluna da loja). Vale pra carta, voucher e pack.
    instance.hoveredOffer = nil
    instance.hoveredIdx = nil
    instance.hoveredInst = nil
    instance.hoveredKind = nil
    -- Painel de detalhe: conteúdo atual + memória do último olhado (o painel
    -- nunca fica vazio depois do primeiro hover) + fade da troca de conteúdo.
    instance.detailPayload = nil
    instance._lastDetailPayload = nil
    instance._detailStale = false
    instance._detailAnim = 1
    -- LEGACY: showConfirmation/confirmButton/cancelButton removidos (modal antigo).

    if not shopSystem then
        Debug.warn("CardRewardScreen criado sem ShopSystem injetado — caindo em fallback (Game:new deve passar shopSystem)")
        local ShopSystem = require("src.systems.ShopSystem")
        shopSystem = ShopSystem:new()
    end
    instance.shopSystem = shopSystem

    instance.animationTime = 0
    instance.cardAnimations = {}

    instance.cardDatabase = CardDatabase:new()
    instance.cardInfoDisplay = CardInfoDisplay:new()

    instance:updateLayout()

    return instance
end

-- Layout fiel ao Balatro source (UI_definitions.lua:637-740):
--   ROOT
--   └─ COLUMN (BOSS_MAIN bg)
--      ├─ ROW1 — Buttons | Cards
--      │   ├─ COL: [Next Round] + [Reroll]
--      │   └─ COL: shop_jokers (4 slots)
--      ├─ spacer
--      └─ ROW2 — Voucher | Boosters
--          ├─ COL: voucher (label vertical "Ato X")
--          └─ COL: 2 boosters (cardW × 1.27)
--
-- ⚠️ O diagrama Balatro acima descreve o layout ANTIGO do modo "shop"
-- (row1 = botões | cartas, row2 = voucher | packs). Desde o redesign
-- split-view de Jul/2026 a loja é 3 COLUNAS (ações | grade | detalhe fixo) —
-- ver o bloco comentado dentro do branch `self.mode == "shop"` abaixo.
-- Modo "rewards": 3 cartas grandes flutuando, sem painel (StS-style).
function CardRewardScreen:updateLayout()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local cfg = self.modeConfig or { cards = 3, upgrades = 0, boosters = 0 }
    self.layoutMode = self.mode

    self.cardPositions = {}

    if self.mode == "shop" then
        -- ================= SPLIT-VIEW (Jul/2026) =================
        -- Feedback do dono: "não está muito boa a visualização das cartas".
        -- O layout antigo empilhava cartas grandes em fileiras e escondia a
        -- informação real em painéis FLUTUANTES fora da janela — pra entender
        -- uma oferta o jogador tinha que varrer o mouse e perseguir popups.
        --
        -- Agora são 2 COLUNAS + 1 RODAPÉ:
        --   [ GRADE COMPACTA DE OFERTAS ]   [ DETALHE FIXO ]
        --     4 cartas (fileira 1)            carta GRANDE
        --     voucher + 2 packs (fileira 2)   nome/custo/raridade/efeitos
        --   [ Novas ofertas ($N) ....... OURO $N ....... Continuar (+3g) ]
        --
        -- A grade decide, o painel explica. O painel NUNCA muda de lugar —
        -- só de conteúdo (ver _resolveDetailPayload).
        --
        -- ⚠️ A coluna vertical de ações (18% da largura) FOI EMBORA: com 128px
        -- úteis o Button truncava "Novas ofertas ($5)" em "Novas ofer..." —
        -- e o problema é estrutural, não de chute de largura (a fonte pixel é
        -- ~1px/char por tamanho: 18 chars não cabem nem no MIN_FONT=8). Numa
        -- faixa horizontal cada botão recebe a largura MEDIDA do seu rótulo,
        -- em qualquer locale (o alemão "Erneuern" é curto, o PT é o pior
        -- caso), e a grade ainda ganha ~150px de volta.
        local topBarH = 56  -- TopBar.height + padding folga
        local panelW = math.floor(math.min(sw * 0.94, 1200))
        local panelH = math.floor(math.min(sh * 0.90, 820))
        local panelX = math.floor((sw - panelW) * 0.5)
        local panelY = math.floor(math.max(topBarH + 4, (sh - panelH) * 0.5))
        -- Reclampa altura se ficou abaixo do topBar (telas pequenas).
        if panelY + panelH > sh - 4 then panelH = sh - panelY - 4 end
        self.panel = { x = panelX, y = panelY, w = panelW, h = panelH }

        local titleH = 50     -- altura do title bar
        local pad = 16        -- padding interno do painel
        local colGap = 12     -- respiro entre as 3 colunas

        local nCards = cfg.cards or 4
        local nVouchers = cfg.upgrades or 1
        local nPacks = cfg.boosters or 2

        local barH = 46       -- rodapé de ações
        local barGap = 10
        local contentY = panelY + titleH + pad
        local contentH = math.max(120, panelH - titleH - pad * 2 - barH - barGap)

        -- ===== Colunas (proporções responsivas, clampadas em px) =====
        local detailW  = math.floor(math.max(230, math.min(380, panelW * 0.29)))
        local gridX    = panelX + pad
        local detailX  = panelX + panelW - pad - detailW
        local gridW    = detailX - colGap - gridX
        -- Janela estreita: o detalhe cede espaço antes da grade ficar
        -- inutilizável (uma carta ilegível não ajuda ninguém a escolher).
        if gridW < 200 then
            detailW = math.max(150, detailW - (200 - gridW))
            detailX = panelX + panelW - pad - detailW
            gridW   = detailX - colGap - gridX
        end

        -- ===== Grade: 2 fileiras (cartas | voucher+packs) =====
        local gridGapX = 10
        -- 26 (era 16): com a puladinha pra cima, a carta da fileira 2 sobe
        -- ~12px de lift + ~13px de crescimento. Um respiro curto fazia ela
        -- entrar na faixa de rótulos da fileira 1.
        local rowGapMin = 26
        -- Faixa de rótulos SOB cada slot: raridade (sempre) + afinidade
        -- (quando existe). Antes esses marcadores só existiam em "rewards" —
        -- na loja o jogador não via a raridade do que estava comprando.
        -- 30px (não 26): a carta em hover cresce 6% A PARTIR DO CENTRO, ou
        -- seja avança ~7px pra baixo — com a faixa curta ela cobria o rótulo
        -- de raridade do próprio slot.
        local labelH = 30
        local cols = math.max(nCards, nVouchers + nPacks)
        local cellW = math.floor((gridW - gridGapX * (cols - 1)) / math.max(1, cols))
        local cellH = math.floor(cellW * 1.45)
        -- topReserve entra JÁ no cap de altura: quando a altura é o gargalo
        -- (ex. 1280×720), sem isso a célula cresce até zerar a margem e a
        -- carta em hover fura a borda do container.
        local topReserve = 26   -- lift (12) + crescimento pra cima (~13)
        local maxCellH = math.floor((contentH - topReserve - rowGapMin - labelH * 2) / 2)
        if cellH > maxCellH then
            cellH = math.max(60, maxCellH)
            cellW = math.floor(cellH / 1.45)
        end
        cellW = math.max(48, cellW)

        -- Sobra vertical: primeiro reserva a margem superior, DEPOIS vira
        -- respiro entre as fileiras (até um teto) — nesta ordem, senão o
        -- rowGap engole tudo e a fileira de cima cola na borda.
        -- A margem existe porque a carta LEVANTA ~15px no hover (DEPTH_OFFSET)
        -- e não pode furar o container.
        local slackRaw = math.max(0, contentH - (cellH * 2 + labelH * 2 + rowGapMin))
        local topMargin = math.min(topReserve, slackRaw)
        local rowGap = rowGapMin + math.max(0, math.min(54, slackRaw - topMargin))
        local blockH = cellH * 2 + labelH * 2 + rowGap
        local gridTop = contentY + topMargin
            + math.floor(math.max(0, contentH - blockH - topMargin) / 2)

        self.cardWidth  = cellW
        self.cardHeight = cellH
        self.slotLabelH = labelH

        local row1Y = gridTop
        local row2Y = gridTop + cellH + labelH + rowGap

        -- A fileira 1 define o VÃO da vitrine; a fileira 2 ocupa exatamente o
        -- mesmo vão. Antes ela era centralizada com a MESMA largura de célula
        -- das cartas e, sendo 3 contra 4, sobrava um vazio grande dos lados —
        -- as duas fileiras não conversavam ("a divisão está estranha").
        -- Agora as bordas externas das duas coincidem.
        local rowSpan = nCards * cellW + math.max(0, nCards - 1) * gridGapX
        local rowLeft = gridX + math.floor((gridW - rowSpan) / 2)

        for i = 1, nCards do
            self.cardPositions[i] = {
                x = rowLeft + (i - 1) * (cellW + gridGapX), y = row1Y,
                w = cellW, h = cellH, row = 1, kind = "card",
            }
        end

        -- ORDEM DOS SLOTS preservada (cartas → vouchers → packs): offer._slot
        -- vem do índice em shopOffers, que o ShopSystem gera nessa ordem.
        local nRow2 = nVouchers + nPacks
        local cellW2 = cellW
        if nRow2 > 0 then
            cellW2 = math.floor((rowSpan - gridGapX * (nRow2 - 1)) / nRow2)
        end
        for k = 1, nRow2 do
            local isVoucher = k <= nVouchers
            self.cardPositions[nCards + k] = {
                x = rowLeft + (k - 1) * (cellW2 + gridGapX), y = row2Y,
                w = cellW2, h = cellH, row = 2,
                kind = isVoucher and "voucher" or "pack",
            }
        end

        -- Containers. A grade virou UM container só (antes eram três — cards,
        -- voucher e packs — que fragmentavam a leitura).
        self.gridArea = { x = gridX, y = contentY, w = gridW, h = contentH }
        self.detailPanel = { x = detailX, y = contentY, w = detailW, h = contentH }
        self.detailFooterH = 58   -- rodapé reservado pros botões Comprar/Cancelar
        self.actionBar = { x = panelX + pad, y = contentY + contentH + barGap,
                           w = panelW - pad * 2, h = barH }
        self.cardsContainer = nil
        self.voucherContainer = nil
        self.packsContainer = nil
        self.buttonsContainer = nil   -- a coluna vertical de ações não existe mais
        self.buttonsColX = nil
        self.buttonsColY = nil

        self.slotCount = nCards + nVouchers + nPacks

        -- Skip button no rodapé do painel (fallback; em shop ele vive na coluna).
        self.skipButtonX = panelX + panelW * 0.5 - 90
        self.skipButtonY = panelY + panelH - 50

    else
        -- ========== Modo rewards v3 "StS FLUTUANTE" (Jul/2026) ==========
        -- Feedback do dono: o painel parecia descentralizado, pills eram "só
        -- um quadrado com texto", tudo apertado. Como no Slay the Spire: SEM
        -- painel — o mundo (limpo) escurece atrás, um BANNER ornamental no
        -- topo, 3 cartas GRANDES flutuando centralizadas, marcadores sem
        -- caixa e o botão Seguir embaixo. Centralização é na TELA inteira.
        self.panel = nil
        self.cardsContainer = nil
        self.buttonsContainer = nil
        self.voucherContainer = nil
        self.packsContainer = nil
        self.gridArea = nil
        self.detailPanel = nil   -- split-view é EXCLUSIVO da loja
        self.actionBar = nil
        self.buttonsColX = nil
        self.buttonsColY = nil

        local nCards = cfg.cards or 3
        local spacing = 30
        local wByWidth = math.floor((sw * 0.76 - spacing * (nCards - 1)) / nCards)
        local wByHeight = math.floor((sh * 0.46) / 1.4)
        self.cardWidth = math.min(wByWidth, wByHeight)
        self.cardHeight = math.floor(self.cardWidth * 1.4)

        local cardsTotalW = nCards * self.cardWidth + (nCards - 1) * spacing
        local cardsStartX = math.floor((sw - cardsTotalW) / 2)
        local cardsY = math.floor(sh * 0.28)
        for i = 1, nCards do
            self.cardPositions[i] = {
                x = math.floor(cardsStartX + (i - 1) * (self.cardWidth + spacing)),
                y = cardsY,
                row = 1, kind = "card",
            }
        end

        self.bannerY = math.floor(sh * 0.105)
        self.slotCount = nCards

        self.skipButtonX = math.floor(sw * 0.5) - 100   -- recentrado na criação
        self.skipButtonY = sh - 96
    end

    -- Rodapé de ações reposicionado AQUI, não só no detector de resize do
    -- update(): main.lua:love.resize chama updateLayout() direto (sem passar
    -- pelo detector), e sem isto os botões ficavam um frame nas coordenadas
    -- do tamanho ANTIGO. Regra de memory/ui_layout_invariants.md — "resize
    -- tem que cobrir o estado NOVO": o rodapé é estado novo desta sessão.
    -- No-op quando os botões ainda não existem (chamada vinda do show()).
    self:_layoutActionButtons()
    -- Botões de compra: largura depende do painel de detalhe, que acabou de
    -- mudar. Reconstrói (rótulo + largura) em vez de só reposicionar.
    if self.selectedOffer then
        self:_buildSelectionButtons(self.selectedOffer, self.selectedIdx)
    end

    Debug.trace("[CardRewardScreen] Layout", self.mode, sw, "x", sh,
                "slots", self.slotCount, "card", self.cardWidth, "x", self.cardHeight)
end

-- ============================================================================
-- VALIDAÇÃO GEOMÉTRICA — o teste que layout por acumulação nunca tem
-- ============================================================================
-- Devolve uma lista de violações (vazia = layout íntegro). Roda em qualquer
-- tamanho de janela, então os tools conseguem exercitar o caminho que os
-- screenshots não pegam: NASCER grande ≠ CRESCER (ver
-- memory/ui_layout_invariants.md). Barato o bastante pra rodar por frame se
-- precisar, mas o uso previsto é em ferramenta.
function CardRewardScreen:validateLayout()
    local bad = {}
    local function contains(outer, inner, label)
        if not (outer and inner) then return end
        if inner.x < outer.x - 1 or inner.y < outer.y - 1
            or inner.x + inner.w > outer.x + outer.w + 1
            or inner.y + inner.h > outer.y + outer.h + 1 then
            bad[#bad + 1] = string.format(
                "%s (%d,%d %dx%d) escapa do container (%d,%d %dx%d)", label,
                inner.x, inner.y, inner.w, inner.h,
                outer.x, outer.y, outer.w, outer.h)
        end
    end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local screen = { x = 0, y = 0, w = sw, h = sh }
    contains(screen, self.panel, "painel")

    if self.mode == "shop" then
        contains(self.panel, self.gridArea, "grade")
        contains(self.panel, self.detailPanel, "painel de detalhe")
        contains(self.panel, self.actionBar, "rodape de acoes")

        -- Slots + faixa de rótulos + reserva do lift cabem na grade?
        local labelH = self.slotLabelH or 0
        for i = 1, (self.slotCount or 0) do
            local p = self.cardPositions[i]
            if p then
                contains(self.gridArea, {
                    x = p.x, y = p.y - SHOP_HOVER_LIFT,
                    w = p.w or self.cardWidth,
                    h = (p.h or self.cardHeight) + labelH + SHOP_HOVER_LIFT,
                }, "slot " .. i)
            end
        end

        -- Fileira 1 (com rótulos) não pode encostar na fileira 2 levantada.
        local r1, r2
        for i = 1, (self.slotCount or 0) do
            local p = self.cardPositions[i]
            if p and p.row == 1 then r1 = p elseif p and p.row == 2 and not r2 then r2 = p end
        end
        if r1 and r2 then
            local r1Bottom = r1.y + (r1.h or self.cardHeight) + labelH
            local r2Top = r2.y - SHOP_HOVER_LIFT
            if r2Top < r1Bottom then
                bad[#bad + 1] = string.format(
                    "fileira 2 levantada (y=%d) invade os rotulos da fileira 1 (y=%d)",
                    r2Top, r1Bottom)
            end
        end

        for _, b in ipairs({ self.skipButton, self.refreshButton }) do
            if b then
                contains(self.actionBar,
                    { x = b.x, y = b.y, w = b.width, h = b.height },
                    "botao '" .. tostring(b.text) .. "'")
            end
        end
        if self.selectedOffer then
            for i, b in ipairs(self._selectionButtons or {}) do
                contains(self.detailPanel,
                    { x = b.x, y = b.y, w = b.width, h = b.height },
                    "botao de compra " .. i)
            end
        end
    else
        for i = 1, (self.slotCount or 0) do
            local p = self.cardPositions[i]
            if p then
                contains(screen, {
                    x = p.x, y = p.y, w = p.w or self.cardWidth,
                    h = p.h or self.cardHeight,
                }, "carta " .. i)
            end
        end
    end

    -- Slots da mesma fileira nunca se sobrepõem.
    for i = 1, (self.slotCount or 0) - 1 do
        local a, b = self.cardPositions[i], self.cardPositions[i + 1]
        if a and b and a.row == b.row then
            local aRight = a.x + (a.w or self.cardWidth)
            if b.x < aRight then
                bad[#bad + 1] = string.format("slots %d e %d se sobrepoem (%d > %d)",
                    i, i + 1, aRight, b.x)
            end
        end
    end

    return bad
end

-- mode: "rewards" | "shop"   (default "rewards" pra back-compat com chamadas antigas).
--   "rewards" = pós-batalha, 3 cartas, sem reroll. Skip = continuar sem bônus.
--   "shop"    = SHOP node, 4 cartas + 1 voucher + 2 packs, reroll exponencial,
--               Skip dá +3 ouro de bônus.
function CardRewardScreen:show(game, onCardPurchased, onSkipped, mode)
    self.visible = true
    self.game = game
    self.onCardPurchased = onCardPurchased
    self.onSkipped = onSkipped
    self.animationTime = 0
    self.mode = mode or "rewards"

    -- Contexto da run pro cérebro de ofertas (classe filtra pool; deck liga
    -- afinidade e anti-duplicata — "as escolhas anteriores importam").
    local run = game.runManager and game.runManager.currentRun
    local actNumber = (run and run.actNumber) or 1

    -- P0.7 (rebalance Jul/2026): elites/bosses pisam a raridade da recompensa
    -- — o mapa promete risco, a vitrine paga. Só em modo rewards (a loja do
    -- SHOP node não é recompensa de combate).
    local minRarity = nil
    if self.mode == "rewards" and run and run.currentNode then
        local nt = run.currentNode.type
        if nt == "elite" then
            minRarity = "uncommon"
        elseif nt == "boss" then
            minRarity = "rare"
        end
    end

    -- P0.3/P0.4: pesos de raridade POR ATO (Config.Acts via ActSystem — antes
    -- era o fixo 70/25/5 da loja; a tabela por ato era código morto).
    local ActSystem = require("src.systems.ActSystem")
    self.shopSystem:setContext({
        classId = (run and run.classId) or game.selectedClass,
        deckIds = (game.runManager and game.runManager.getDeckCardIds)
            and game.runManager:getDeckCardIds() or nil,
        runManager = game.runManager, -- forja (custo crescente) + dedup de joker (P0.10)
        actNumber = actNumber,        -- P0.5: cap de afinidade progressivo por ato
        rarityWeights = ActSystem.getRarityWeights(actNumber),
        minRarity = minRarity,
    })

    self.shopSystem:setMode(self.mode)
    self.shopSystem:generateOffers()
    self.shopOffers = self.shopSystem:getCurrentOffers()
    self.modeConfig = self.shopSystem:getModeConfig()

    -- Slot FIXO por oferta (F2): comprada uma carta, as demais NÃO trocam de
    -- lugar. Antes, draw/hover/selection indexavam shopOffers[i] contra
    -- cardInstances compactado — hover mostrava info da carta errada e os
    -- botões de compra apareciam no slot errado após a 1ª compra.
    for i, o in ipairs(self.shopOffers) do o._slot = i end

    -- FX de compra (carta voando pro deck + popups de ouro).
    self._flyCards = {}
    self._goldPopups = {}
    -- Regra "escolha 1" (rewards): flag zera a cada abertura — sem isto a
    -- SEGUNDA recompensa da run nasceria travada.
    self._rewardTaken = false

    Debug.log("[CardRewardScreen] Aberta em modo", self.mode, "com", #self.shopOffers, "ofertas")

    self:updateLayout()
    self:createCardInstances()
    self:createOfferButtons()
    self:_resetDetail()

    -- ===== DEBUG: arquivo novo por abertura + radiografia do momento =====
    if REWARD_DBG then
        _dbgStart = love.timer.getTime()
        self._dbgNext = 0
        self._dbgDrawNext = 0
        pcall(love.filesystem.write, "reward_debug.log", "")
        dbg("======== SHOW mode=%s tela=%dx%d state-time ========",
            tostring(self.mode), love.graphics.getWidth(), love.graphics.getHeight())
        dbg("ofertas=%d | lastScreenW=%s lastScreenH=%s",
            #self.shopOffers, tostring(self.lastScreenWidth), tostring(self.lastScreenHeight))
        dbgQueue("base")
        dbgQueue(FXQ)
    end

    -- Zera as filas dedicadas: eventos zumbis de uma abertura anterior morrem
    -- aqui (o close atrasado do "escolha 1" já é guardado por self.visible).
    -- A de SAÍDA entra junto: um fechamento pendente de uma abertura passada
    -- fecharia esta tela recém-aberta. Nenhum callback legítimo se perde —
    -- a saída sempre termina ANTES de qualquer caminho que reabra a loja.
    EventManager.clear(FXQ)
    EventManager.clear("reward_exit")
    self._closing = false

    -- Slide-in animation (Fase 4.4): painel desce do topo da tela em 0.43s.
    -- Padrão Balatro: easing 'smooth' (cubic in-out) chega "encaixando".
    self.slideOffsetY = -love.graphics.getHeight()
    EventManager.ease(self, "slideOffsetY", 0, 0.43, "smooth", FXQ)

    -- A LOJA abria em silêncio absoluto. `shopOpen` (chime quente) já existia
    -- registrado e só era usado pelo pack e pelo cash out — é o som da porta
    -- da loja, e é aqui que ele pertence. Rewards NÃO ganha som próprio de
    -- abertura: o battleVictory ainda está soando quando esta tela entra.
    if self.mode == "shop" then
        Sfx.play("shopOpen")
    end

    -- ENTRADA v3 (rewards): cada carta CAI de cima com back_out (stagger) +
    -- tick sonoro em pitch crescente + juice ao pousar — fluidez pedida no
    -- feedback ("animações, coisas legais, jogo satisfatório").
    if self.mode == "rewards" then
        local Moveable = require("engine.Moveable")
        for i, inst in ipairs(self.cardInstances) do
            inst._entryOy = -70   -- de CIMA pra baixo (negativo = acima do lugar)
            local d = 0.15 + (i - 1) * 0.13
            dbg("entry AGENDADA carta %d: ease em t=+%.2fs (fila %s)", i, d, FXQ)
            EventManager.parallel(d, function()
                dbg("entry ease DISPAROU carta %d (entryOy=%s)", i, tostring(inst._entryOy))
                EventManager.parallelEase(inst, "_entryOy", 0, 0.45, "back_out", FXQ)
                Sfx.play("cardDraw", { pitch = 0.95 + i * 0.06, volume = 0.55 })
            end, FXQ)
            EventManager.parallel(d + 0.45, function()
                Moveable.juice_up(inst, 0.22, 0.05)
            end, FXQ)
        end
        dbgCards(self, "pos-show")
    end

    -- Materialize cascade nas cartas: cada cardInstance arranca em dissolve=1
    -- e tweena pra 0 com stagger de 80ms — Balatro pack-opening style.
    -- ⚠️ SÓ NA LOJA (fix Jul/2026): em rewards, deixar dissolve=1 esperando o
    -- start_materialize agendado deixou as cartas INVISÍVEIS no jogo real
    -- (print do dono: só banner+marcadores). A entrada do rewards é a QUEDA
    -- (_entryOy) — dissolve fica 0 desde o início, visibilidade garantida
    -- sem corrida com o EventManager.
    if self.mode ~= "rewards" then
        local stagger = 0.08
        for i, cardInstance in ipairs(self.cardInstances) do
            cardInstance.dissolve = 1
            cardInstance.dissolve_colours = DissolveShader.palette("booster")
            EventManager.parallel(0.43 + (i - 1) * stagger, function()
                if cardInstance.start_materialize then
                    cardInstance:start_materialize(DissolveShader.palette("booster"), true, 0.9)
                else
                    cardInstance.dissolve = 0
                end
                -- A cascata materializava MUDA (queixa do dono: "falta um som
                -- suave de cada carta entrando"). Uma carta pousando na
                -- prateleira, pitch subindo pela fileira — mesmo padrão do
                -- modo rewards acima. `cardShelfPlace` é o som dedicado; até
                -- ele existir, cai no cardDraw baixinho (contrato Sfx.has).
                -- Sem `volume` de propósito: cada código já é registrado no
                -- seu volume calibrado (main.lua) e um número aqui valeria
                -- pros DOIS, que têm picos de amostra bem diferentes. A
                -- calibração mora num lugar só.
                playFirstSfx({ "cardShelfPlace", "cardDraw" },
                    { pitch = 0.94 + (i - 1) * 0.05 })
            end, FXQ)
        end
    end

    -- Skip/Continue. Em modo shop dá +N ouro de bônus (configurado em MODE_CONFIG).
    -- F2: em modo shop vira o botão PRINCIPAL da coluna esquerda (Balatro:
    -- "Next Round" vermelho grande no topo da column), não um botãozinho no
    -- rodapé. Em rewards continua compacto no rodapé.
    local skipBonus = (self.modeConfig and self.modeConfig.skipBonus) or 0
    local skipLabel = I18n.t("reward.continue")
    if self.mode == "rewards" then
        -- Clareza: "Continuar" não dizia O QUE acontecia (perder a carta).
        skipLabel = I18n.t("reward.skip_no_card")
    end
    if self.mode == "shop" and skipBonus > 0 then
        skipLabel = skipLabel .. " (+" .. skipBonus .. "g)"
    end
    -- Reforma Jul/2026 (feedback "Seguir ..."): 130px NÃO cabia "Seguir sem
    -- carta" (~190px em Press Start 2P 12) e o TextFit truncava com "...".
    -- Largura agora é MEDIDA pelo texto (+ícone/padding) e o botão recentra.
    local skipFont = 12
    local skipW = FontManager.getFont(skipFont):getWidth(skipLabel) + 64
    skipW = math.max(200, skipW)
    local skipX = (self.panel and (self.panel.x + self.panel.w / 2) or (love.graphics.getWidth() / 2)) - skipW / 2
    local skipY, skipH = self.skipButtonY, 40
    -- Em shop a geometria definitiva vem de _layoutActionButtons() (medida);
    -- estes valores são só provisórios até lá.
    self.skipButton = Button:new(
        skipX, skipY, skipW, skipH,
        skipLabel,
        function()
            if self.mode == "shop" and skipBonus > 0 and self.game.economySystem then
                self.game.economySystem:earnGold(skipBonus, "shop_skip")
                self.game:addMessage("+" .. skipBonus .. "g (pulou loja)", "info")
            end
            -- Saída pela porta da frente: cartas queimam, painel desliza,
            -- som anuncia. _exitWithFlourish chama hide + onSkipped no fim.
            self:_exitWithFlourish()
        end, nil, skipFont
    )
    self.skipButton:setIcon("arrow_right")
    if self.mode == "shop" then self.skipButton:setColorScheme("red") end

    -- Refresh button só existe se o modo permitir (rewards = false).
    if self.modeConfig and self.modeConfig.canReroll then
    local refreshCost = self.shopSystem:getRefreshCost()
    -- Em modo shop a posição/largura vem de _layoutActionButtons() (rodapé,
    -- largura medida pelo rótulo). Em rewards fica ao lado do Skip (legacy).
    local rerollX = self.skipButtonX + 145
    local rerollY = self.skipButtonY
    local rerollW = 130
    local rerollH = 32
    self.refreshButton = Button:new(
        rerollX, rerollY, rerollW, rerollH,
        I18n.t("reward.refresh", { n = refreshCost }),
        function()
            local currentRefreshCost = self.shopSystem:getRefreshCost()
            if self.game.economySystem:canAfford(currentRefreshCost) then
                self.game.economySystem:spendGold(currentRefreshCost, "refresh", "shop")
                Sfx.play("shopReroll")  -- F11.5: dedicado pra reroll (riffle paper).
                self:_spawnGoldPopup(self.refreshButton.x + self.refreshButton.width / 2,
                    self.refreshButton.y, "-$" .. currentRefreshCost)
                self.shopSystem:refreshOffers()
                self.shopOffers = self.shopSystem:getCurrentOffers()
                for i, o in ipairs(self.shopOffers) do o._slot = i end

                self:createCardInstances()
                self:createOfferButtons()
                self:clearSelection()
                self:_resetDetail()

                self.cardAnimations = {}
                for i = 1, #self.shopOffers do
                    self.cardAnimations[i] = {
                        scale = 0,
                        targetScale = 1,
                        delay = (i - 1) * 0.1,
                        elapsed = 0
                    }
                end

                local newCost = self.shopSystem:getRefreshCost()
                self.refreshButton.text = I18n.t("reward.refresh", { n = newCost })
                -- Custo novo = rótulo novo = largura nova (o "($12)" é mais
                -- largo que "($5)"). Re-mede antes que o fitText trunque.
                self:_layoutActionButtons()

                self.game:addMessage(I18n.t("reward.shop_refreshed"), "info")
            else
                self.game:addMessage(I18n.t("reward.refresh_fail"), "error")
                Sfx.play("purchaseDeny")
            end
        end
    )
    end  -- end if canReroll

    -- Geometria definitiva do rodapé de ações (larguras medidas pelos rótulos
    -- já finais, incluindo o custo do reroll e o bônus do skip).
    self:_layoutActionButtons()

    for i = 1, #self.shopOffers do
        self.cardAnimations[i] = {
            scale = 0,
            targetScale = 1,
            delay = (i - 1) * 0.1,
            elapsed = 0
        }
    end
end

function CardRewardScreen:createCardInstances()
    self.cardInstances = {}

    -- F2: itera pelas ofertas usando o _slot FIXO de cada uma — depois de uma
    -- compra as cartas restantes ficam onde estavam (slot comprado vira vazio
    -- com stamp VENDIDO, desenhado em draw()).
    local maxSlots = self.slotCount or 3
    for _, offer in ipairs(self.shopOffers) do
        if offer.type == "card" and not offer.purchased
            and (offer._slot or math.huge) <= maxSlots then
        local cardData = self.cardDatabase:getCard(offer.id)
        if not cardData then
            Debug.err("[CardRewardScreen] Card data not found for", offer.id)
            goto continue
        end

        local cardInstance = self.cardDatabase:createCardInstance(cardData)

        if cardInstance then
            local pos = self.cardPositions[offer._slot] or { x = 0, y = 0 }

            -- Fill do slot: em "rewards" a carta é a estrela e sobra folga
            -- pros marcadores (86%). No split-view da loja o slot já é
            -- pequeno e os rótulos moram na faixa DE FORA (slotLabelH) — aqui
            -- a carta usa quase tudo, senão vira uma miniatura ilegível.
            local imgW = cardInstance.image and cardInstance.image:getWidth() or 96
            local imgH = cardInstance.image and cardInstance.image:getHeight() or 144
            local slotW = pos.w or self.cardWidth
            local slotH = pos.h or self.cardHeight
            local fill = (self.mode == "shop") and 0.97 or 0.86
            local fitScale = math.min(slotW / imgW, slotH / imgH) * fill
            local renderW = imgW * fitScale
            local renderH = imgH * fitScale
            -- Centraliza a carta DENTRO do slot. Slot continua sendo a área
            -- clicável (cardButton); o sprite visualmente ocupa apenas o centro.
            cardInstance.x = math.floor(pos.x + (slotW - renderW) / 2)
            cardInstance.y = math.floor(pos.y + (slotH - renderH) / 2)
            -- ÂNCORA IMUTÁVEL do layout (fix Jul/2026 do feedback loop):
            -- Card:draw grava self.y = y a cada frame; desenhar a partir de
            -- self.y + entryOy fazia y ACUMULAR o offset (70px/frame — as
            -- cartas estabilizavam em y≈-1900, fora da tela; era o bug
            -- "não renderizam até o hover"). O draw parte SEMPRE daqui.
            cardInstance.homeX = cardInstance.x
            cardInstance.homeY = cardInstance.y

            cardInstance.baseScale = fitScale
            cardInstance.currentScale = fitScale
            -- targetScale começa = baseScale; Card:updateMouse aplica hover bump
            -- proporcional (HOVER_SCALE_MULT) automaticamente.
            cardInstance.targetScale = fitScale
            -- SEM deslocamento vertical no hover — nos dois modos.
            -- Tentei ligar o lift na grade (o feedback fica mais vivo), mas na
            -- captura ficou evidente o porquê de ele estar desligado: tudo que
            -- decora o slot é ancorado no RETÂNGULO DO SLOT, não na carta —
            -- medalhão de preço, marcador de raridade, halo de seleção. Com a
            -- carta deslocada, o preço descola e o marcador some atrás dela.
            -- O hover continua legível por SCALE (+6%) e, principalmente, pelo
            -- painel de detalhe inteiro trocando de conteúdo.
            cardInstance.noHoverLift = true

            -- Rarity border pulsante removida em F10.1 (poluía visualmente).
            -- offer.rarity ainda existe pra ordenar/filtrar; só não desenhamos halo.

            if not cardInstance.description and offer.description then
                cardInstance.description = offer.description
            end

            cardInstance.isRewardCard = false
            cardInstance.shopOffer = offer

            if cardInstance.cardInfoDisplay then
                cardInstance.cardInfoDisplay:configure({
                    showRarity = true,
                    showStats = true,
                    showDescription = true
                })
            end

            -- Link bidirecional: purchaseOffer usa offer.cardInstance pro FX
            -- de compra (antes NUNCA era atribuído — o feedback não disparava).
            offer.cardInstance = cardInstance
            table.insert(self.cardInstances, cardInstance)
        else
            Debug.err("[CardRewardScreen] Could not create card instance for", offer.id)
        end
        ::continue::
        end
    end
end

function CardRewardScreen:createOfferButtons()
    self.cardButtons = {}

    -- F2: botão invisível ancorado no _slot fixo da oferta.
    local maxSlots = self.slotCount or 3
    for _, offer in ipairs(self.shopOffers) do
        if not offer.purchased and (offer._slot or math.huge) <= maxSlots then
            local pos = self.cardPositions[offer._slot] or { x = 0, y = 0 }
            -- Voucher/pack podem ter w/h custom no layout (pos.w/pos.h).
            local btnW = pos.w or self.cardWidth
            local btnH = pos.h or self.cardHeight
            local capturedOffer = offer  -- closure capture
            local button = Button:new(
                pos.x, pos.y, btnW, btnH,
                "",
                function()
                    self:setSelectedOffer(capturedOffer, capturedOffer._slot)
                end
            )
            button:setVariant("invisible")
            table.insert(self.cardButtons, button)
        end
    end
end

function CardRewardScreen:purchaseOffer(offer, offerId)
    Debug.log("[CardRewardScreen] Purchasing", offer.name, "($" .. offer.cost .. ")")

    -- REGRA "ESCOLHA 1" (fix Jul/2026 — dava pra pegar as 3): depois da
    -- primeira carta, cliques atrasados durante o fade/close são ignorados.
    if self.mode == "rewards" and self._rewardTaken then return end

    if not self.game.economySystem:canAfford(offer.cost) then
        self.game:addMessage(I18n.t("reward.insufficient_gold"), "error")
        Sfx.play("purchaseDeny")
        return
    end

    -- Pre-check: joker com slots cheios não pode ser comprado (evita gold drain).
    if offer.type == "card" then
        local cd = self.game.deckManager.cardDatabase:getCard(offer.id)
        if cd and cd.type == "joker" and not self.game:canAcceptJoker() then
            -- O texto falava em "slots cheios", mas quem barra aqui é
            -- `canAcceptJoker`, que hoje só testa `isRunMode` (Game.lua:383)
            -- — a rejeição por slots morreu no refactor coleção+bancada de
            -- Jul/2026 e é anti-pattern documentado no CLAUDE.md. A mensagem
            -- tinha ficado pra trás e mentia sobre a causa; agora diz o que a
            -- condição de fato verifica.
            self.game:addMessage(
                I18n.t("reward.joker_run_only", nil,
                    "Coringas so podem ser adquiridos durante uma corrida"),
                "warning")
            Sfx.play("purchaseDeny")
            return
        end
    end

    if self.game.economySystem:spendGold(offer.cost, offer.type, offer.id) then
        -- Marca purchased ANTES de qualquer side-effect (pack open, addCardToRun)
        -- pra evitar duplo-buy caso input leak durante overlay/animação.
        offer.purchased = true

        -- F4 (Voto de Pobreza): qualquer compra em LOJA marca a run.
        if self.mode == "shop" and self.game.runManager
            and self.game.runManager.currentRun then
            self.game.runManager.currentRun._usedShop = true
        end

        local offerName = offer.type == "card" and I18n.cardName({ id = offer.id, name = offer.name }) or offer.name
        -- Screen jiggle no momento da compra (Fase 6.4) — feedback tátil leve.
        if _G.jiggleScreen then _G.jiggleScreen(0.25) end

        -- Popup de ouro "-$N" flutuando do slot comprado (todo tipo de oferta).
        do
            local pos = self.cardPositions[offer._slot or 0]
            if pos then
                local pw = pos.w or self.cardWidth
                self:_spawnGoldPopup(pos.x + pw - 14, pos.y + 10, "-$" .. offer.cost)
            end
        end

        if offer.type == "card" then
            -- Feedback visual F2 (Balatro): a carta VOA até o ícone de deck na
            -- TopBar, encolhendo — comunica "foi pro seu deck" sem texto.
            self:_startFlyToDeck(offer)
            self.game:addCardToRun(offer.id)
            self.game:addMessage(I18n.t("reward.bought", { name = offerName }), "success")
        elseif offer.type == "upgrade" then
            self:applyUpgrade(offer)
            self.game:addMessage(I18n.t("reward.bought", { name = offerName }), "success")
        elseif offer.type == "booster_pack" then
            -- Fase 5: abre o pack imediatamente via PackOpenScreen overlay.
            -- main.lua expõe _G.openBoosterPack(packData, onComplete) que orquestra.
            local BoosterPackSystem = require("src.systems.BoosterPackSystem")
            local run = self.game.runManager and self.game.runManager.currentRun
            local classId = run and run.classId
            -- P0.6/P0.10: runManager liga o dedup de joker possuído (Buffoon)
            -- e actNumber os pesos de raridade por ato (Arcana/Celestial/Spectral).
            local pack = BoosterPackSystem.expandPackRecord({
                id = offer.id, kind = offer.kind,
                size = offer.size, choose = offer.choose,
            }, classId, {
                runManager = self.game.runManager,
                actNumber = (run and run.actNumber) or 1,
            })

            if _G.openBoosterPack then
                _G.openBoosterPack(pack, function(selected)
                    -- Cards escolhidas vão pro deck — passa edition/seal via meta
                    -- pra que essa cópia específica preserve o modifier (Fase 5.4).
                    for _, card in ipairs(selected or {}) do
                        if card.id then
                            self.game:addCardToRun(card.id, {
                                edition = card.edition,
                                seal = card.seal,
                            })
                        end
                    end
                    self.game:addMessage("+" .. #(selected or {}) .. " carta(s) ao deck", "success")
                end)
            else
                Debug.warn("[CardRewardScreen] _G.openBoosterPack não setado — pack ignorado")
            end
            self.game:addMessage(offerName .. " aberto", "info")
        end
        Sfx.play("purchaseConfirm")

        -- offer.purchased já foi setado antes do side-effect

        self:createCardInstances()
        self:createOfferButtons()

        if self.onCardPurchased then
            self.onCardPurchased(offer)
        end

        -- REGRA "ESCOLHA 1" (rewards, StS): pegar UMA carta ENCERRA os
        -- espólios — os botões morrem na hora, as cartas restantes DISSOLVEM
        -- (queima Balatro) e a tela fecha sozinha seguindo o fluxo (mesmo
        -- caminho do Seguir). Antes dava pra pegar as 3.
        if self.mode == "rewards" and offer.type == "card" then
            self._rewardTaken = true
            self.cardButtons = {}
            self:clearSelection()
            self.hoveredOffer, self.hoveredInst = nil, nil
            -- A queima das não-escolhidas + o fechamento agora moram no
            -- mesmo gesto de saída da loja (_exitWithFlourish): as cartas
            -- queimam, o painel desliza e o som anuncia. A carta PEGA não
            -- queima — ela já voou pro deck.
            self:_exitWithFlourish(offer.cardInstance)
        end
    end
end

-- Marca uma oferta como "selecionada" — dispara o overlay 3-zone (info-left,
-- carta-com-buttons-attached, preview-right). Substitui o modal centralizado
-- antigo (showPurchaseConfirmation + drawPurchaseConfirmation, removidos).
-- Pattern Balatro: create_shop_card_ui (UI_definitions.lua:802-880) cria
-- buy_button como CHILD da carta, popup info side-anchored via align_h_popup.
function CardRewardScreen:setSelectedOffer(offer, idx)
    if not offer then return end
    -- Re-clicar na mesma → toggle off (Balatro card.lua:4610-4623).
    if self.selectedOffer == offer then
        self:clearSelection()
        return
    end

    self.selectedOffer = offer
    self.selectedIdx = idx
    self:_buildSelectionButtons(offer, idx)

    -- Slide-in dos painéis laterais (anim 0→1 em 0.18s smooth).
    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 1, 0.18, "smooth", "shop_select")
    else
        self._selectionAnim = 1
    end

    -- Sfx leve (cardSelect com pitch alto). hoverCard com +0.2 também serve.
    if Sfx.playWithVariation then
        Sfx.playWithVariation("hoverCard", 1.1, 0.08, 0.5, 0.05)
    end
end

-- Mini-buttons Balatro-style (UI_definitions.lua:382 card_focus_button) attached
-- compactos sob a carta. Sem texto verbal — apenas cor semântica:
--   Buy: verde-grimório com "$N" (custo é a única info necessária)
--   Cancel: vermelho-crimson com ícone X
-- Largura ~50% da carta dividida em 2; altura 32px.
function CardRewardScreen:_buildSelectionButtons(offer, idx)
    self._selectionButtons = {}
    if self.mode ~= "shop" and not self.cardPositions[idx] then return end

    -- Reforma Jul/2026 (feedback "aquele P e aquele X"): 90px + fonte 12 NÃO
    -- cabia "PEGAR" e o TextFit degradava até virar UMA LETRA. Largura agora
    -- é MEDIDA pelo texto (rewards) ou ocupa o rodapé do painel (loja).
    local bx0, by0, buyW, cancelW, btnH, gap = self:_selectionButtonsRect(idx)
    if not bx0 then return end
    local buyLabel = (offer.cost or 0) > 0 and ("$" .. tostring(offer.cost))
        or I18n.t("common.take"):upper()
    -- Na loja o botão é largo: cabe o verbo + o preço ("COMPRAR $12").
    if self.mode == "shop" and (offer.cost or 0) > 0 then
        local verb = I18n.t("reward.detail_buy", nil, "COMPRAR")
        if FontManager.getFont(12):getWidth(verb .. " " .. buyLabel) + 24 <= buyW then
            buyLabel = verb .. " " .. buyLabel
        end
    end

    -- Buy button: "$N" (loja) ou "PEGAR" (recompensa grátis). Verde-grimório.
    local buyBtn = Button:new(bx0, by0, buyW, btnH, buyLabel, function()
        local toBuy = self.selectedOffer
        self:clearSelection()
        if toBuy then self:purchaseOffer(toBuy, toBuy.id) end
    end, nil, 12)
    buyBtn:setColorScheme("green")
    if self.game and not self.game.economySystem:canAfford(offer.cost) then
        buyBtn:setEnabled(false)
    end
    table.insert(self._selectionButtons, buyBtn)

    -- Cancel button: QUADRADO só com o ícone X (nada de texto pra truncar).
    local cancelBtn = Button:new(bx0 + buyW + gap, by0, cancelW, btnH, "", function()
        self:clearSelection()
    end, nil, 14)
    cancelBtn:setColorScheme("red")
    cancelBtn:setIcon("x_close")
    table.insert(self._selectionButtons, cancelBtn)
end

-- ============================================================================
-- RETÂNGULO REAL DA CARTA — a âncora de TUDO que decora o slot
-- ============================================================================
-- O problema que fez o hover ficar feio não era o lift: era a ÂNCORA.
-- Card:draw(x, y) desenha o topo-esquerda em (x, y) e escala a partir DALI —
-- então a carta em hover crescia pra BAIXO e pra DIREITA, invadindo o rótulo
-- de raridade (que fica em Y fixo sob o slot) enquanto o medalhão de preço,
-- preso ao retângulo estático do slot, ficava pra trás.
--
-- Aqui a carta é ancorada no CENTRO-X e no RODAPÉ do seu retângulo de repouso:
-- crescer só empurra o topo pra cima. Somado ao lift, vira a "puladinha pra
-- cima" pedida. Este método devolve o retângulo EFETIVAMENTE desenhado no
-- frame — medalhão de preço e halo de seleção leem daqui, então acompanham a
-- carta em vez de descolar.
--
-- Os offsets internos do Card:draw (BASE_LIFT constante, ondulação idle,
-- parallax horizontal) são recompostos aqui pra o retângulo bater pixel a
-- pixel. Na carta em HOVER a ondulação é zero por definição, que é justamente
-- o caso em que o alinhamento tem que ser exato.
-- Devolve { drawX, drawY, x, y, w, h }:
--   drawX/drawY — o que passar pro Card:draw (ele soma os offsets internos)
--   x/y/w/h     — o retângulo VISÍVEL resultante (âncora das decorações)
function CardRewardScreen:_cardDrawRect(inst)
    local img = inst.image
    if not img then
        local fx, fy = inst.x or 0, inst.y or 0
        return { drawX = fx, drawY = fy, x = fx, y = fy, w = 0, h = 0 }
    end

    local Moveable = require("engine.Moveable")
    local baseS = inst.baseScale or inst.currentScale or 1
    local s = (inst.currentScale or baseS)
        * Moveable.scaleFactor(inst) * Moveable.swellFactor(inst)

    local iw, ih = img:getWidth(), img:getHeight()
    local w, h = iw * s, ih * s
    local homeX = inst.homeX or inst.x or 0
    local homeY = inst.homeY or inst.y or 0
    local baseW, baseH = iw * baseS, ih * baseS

    -- Âncora nova (centro-X + rodapé) é EXCLUSIVA da loja. Em "rewards" o
    -- marcador de raridade fica ACIMA da carta (pos.y - 15): crescer pra cima
    -- bateria nele. Lá a âncora segue sendo o topo-esquerda de sempre.
    local x, y = homeX, homeY
    if self.mode == "shop" then
        x = homeX + (baseW - w) / 2
        y = homeY + baseH - h
        if not reducedMotion() then
            y = y - SHOP_HOVER_LIFT * (inst.hoverStrength or 0)
        end
    end

    -- Entrada animada do modo rewards.
    y = y + (inst._entryOy or 0)

    -- Offsets que o Card:draw soma por dentro — entram só no retângulo
    -- visível, NUNCA na posição passada pro draw (senão contam duas vezes).
    local baseFloat = Config.Cards.BASE_LIFT or 0
    local ambientY = 0
    if not inst.isHovered and not inst.isDragging then
        ambientY = math.sin(love.timer.getTime() * 0.666 + (inst._ambientSeed or 0)) * 3
    end
    return {
        drawX = x, drawY = y,
        x = x + (inst.offsetHoverX or 0),
        y = y + ambientY - baseFloat,
        w = w, h = h,
    }
end

-- ============================================================================
-- RODAPÉ DE AÇÕES (loja) — larguras MEDIDAS, nunca chutadas
-- ============================================================================
-- Largura que um Button precisa pro rótulo inteiro caber sem o fitText
-- degradar pra "...": texto + ícone + padding interno (12 de cada lado no
-- variante clean) + folga. Medida no locale ATUAL, então "Novas ofertas ($5)"
-- e "Erneuern ($5)" recebem cada um o que precisam.
local function measuredButtonWidth(btn, minW)
    if not btn then return 0 end
    local font = FontManager.getFont(btn.fontSize or 12)
    local textW = (btn.text and btn.text ~= "") and font:getWidth(btn.text) or 0
    local iconW = btn.iconHandle and 30 or 0
    return math.max(minW or 130, math.ceil(textW + iconW + 34))
end

-- Reroll à esquerda, ouro no meio, Continuar à direita. Se a soma não couber
-- (janela minúscula / locale gigante), as larguras encolhem proporcionalmente
-- e o fitText do Button reduz a fonte — degradação suave, sem estourar a faixa.
function CardRewardScreen:_layoutActionButtons()
    local bar = self.actionBar
    if not bar then return end

    local h = math.min(40, bar.h - 6)
    local y = bar.y + math.floor((bar.h - h) / 2)
    local edge = 10
    local gap = 14

    local rerollW = measuredButtonWidth(self.refreshButton)
    local skipW = measuredButtonWidth(self.skipButton)
    local avail = bar.w - edge * 2
    if rerollW + skipW + gap > avail then
        local factor = avail / (rerollW + skipW + gap)
        rerollW = math.floor(rerollW * factor)
        skipW = math.floor(skipW * factor)
    end

    if self.refreshButton then
        self.refreshButton.x = bar.x + edge
        self.refreshButton.y = y
        self.refreshButton.width = rerollW
        self.refreshButton.height = h
    end
    if self.skipButton then
        self.skipButton.x = bar.x + bar.w - edge - skipW
        self.skipButton.y = y
        self.skipButton.width = skipW
        self.skipButton.height = h
    end

end

-- Faixa de ações. SEM leitor de ouro: o número vive no title bar e repetir o
-- mesmo "$30" colado nos botões poluía (incômodo apontado pelo dono).
function CardRewardScreen:_drawActionBar()
    local bar = self.actionBar
    if not bar then return end
    self:_drawPanel(bar.x, bar.y, bar.w, bar.h, "inner")
end

-- Pré-foca a primeira oferta de carta ao abrir a loja.
--
-- Defeito reportado: sem hover, ~29% da tela ficava preta com 3 linhas de
-- texto no meio — a loja parecia inacabada em repouso. Das três saídas
-- possíveis (brasão decorativo / resumo do estoque / pré-focar), pré-focar é
-- a única que não inventa conteúdo novo: o painel já nasce mostrando uma
-- oferta REAL e, ao fazer isso, ensina sozinho pra que ele serve. Brasão
-- seria enfeite ocupando o lugar da informação; resumo do estoque duplicaria
-- o que a grade ao lado já mostra.
--
-- É PRÉ-FOCO, não pré-seleção: nada de halo nem de botão de compra armado —
-- o jogador continua tendo que clicar pra comprar.
function CardRewardScreen:_prefocusDetail()
    if self.mode ~= "shop" then return end
    for _, offer in ipairs(self.shopOffers or {}) do
        if not offer.purchased and (offer._slot or math.huge) <= (self.slotCount or 0) then
            self._lastDetailPayload = {
                kind = offerKind(offer), offer = offer, instance = offer.cardInstance,
            }
            self._detailPrefocus = true
            self._detailShownOffer = offer
            return
        end
    end
end

-- Zera a memória do painel de detalhe. Obrigatório sempre que o CONJUNTO de
-- ofertas muda (abertura, reroll): segurar a "última olhada" apontando pra uma
-- oferta que não existe mais mostraria uma carta fantasma.
function CardRewardScreen:_resetDetail()
    self.detailPayload = nil
    self._lastDetailPayload = nil
    self._detailShownOffer = nil
    self._detailStale = false
    self._detailPrefocus = false
    self._detailAnim = 1
    self.hoveredOffer, self.hoveredInst, self.hoveredKind = nil, nil, nil
    self:_prefocusDetail()
end

-- Limpa estado de seleção e anima fade-out dos painéis laterais.
function CardRewardScreen:clearSelection()
    self.selectedOffer = nil
    self.selectedIdx = nil
    self._selectionButtons = {}
    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 0, 0.12, "smooth", "shop_select")
    else
        self._selectionAnim = 0
    end
end

-- Aliases legacy mantidos pra eventual call site externo. Internamente apenas
-- delegam pra setSelectedOffer/clearSelection.
function CardRewardScreen:showPurchaseConfirmation(offer)
    -- Encontra idx da offer pra build dos buttons.
    local idx = nil
    for i, o in ipairs(self.shopOffers or {}) do
        if o == offer then idx = i; break end
    end
    self:setSelectedOffer(offer, idx)
end

function CardRewardScreen:confirmPurchase()
    if not self.selectedOffer then return end
    local toBuy = self.selectedOffer
    self:clearSelection()
    self:purchaseOffer(toBuy, toBuy.id)
end

-- Legacy alias: agora apenas delega pra clearSelection.
function CardRewardScreen:cancelPurchase()
    self:clearSelection()
end

-- ============================================================================
-- FX DE COMPRA (F2) — carta voa pro deck + popups de ouro + stamp VENDIDO
-- ============================================================================

-- Carta comprada voa até o ícone de deck da TopBar (x≈200), encolhendo com
-- ease_in (sucção). Entry vive em self._flyCards; desenhada em screen-space
-- (fora do slide do painel) no fim do draw().
function CardRewardScreen:_startFlyToDeck(offer)
    local inst = offer.cardInstance
    if not inst or not inst.image then return end
    self._flyCards = self._flyCards or {}

    local fly = {
        img = inst.image,
        x = inst.x, y = inst.y,
        scale = inst.currentScale or inst.baseScale or 1,
        alpha = 1,
        rot = 0,
    }
    table.insert(self._flyCards, fly)

    -- Alvo: ícone de deck da TopBar (padding 20 + 180 — ver TopBar.lua).
    local targetX, targetY = 205, 6
    local dur = 0.45
    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(fly, "x", targetX, dur, "ease_in", "shop_fly")
        EventManager.parallelEase(fly, "y", targetY, dur, "ease_in", "shop_fly")
        EventManager.parallelEase(fly, "scale", 0.12, dur, "ease_in", "shop_fly")
        EventManager.parallelEase(fly, "rot", 0.35, dur, "smooth", "shop_fly")
        EventManager.parallel(dur, function()
            fly._done = true
            Sfx.play("cardDraw", { pitch = 1.15, volume = 0.7 })
        end, "shop_fly")
    else
        fly._done = true
    end
end

-- Popup "-$N" que flutua pra cima e some (age controlada em update()).
function CardRewardScreen:_spawnGoldPopup(x, y, text)
    self._goldPopups = self._goldPopups or {}
    table.insert(self._goldPopups, { text = text, x = x, y = y, age = 0 })
end

local POPUP_LIFE = 0.9

function CardRewardScreen:_updatePurchaseFx(dt)
    if self._flyCards then
        for i = #self._flyCards, 1, -1 do
            if self._flyCards[i]._done then table.remove(self._flyCards, i) end
        end
    end
    if self._goldPopups then
        for i = #self._goldPopups, 1, -1 do
            local p = self._goldPopups[i]
            p.age = p.age + dt
            if p.age >= POPUP_LIFE then table.remove(self._goldPopups, i) end
        end
    end
end

-- Desenhados em SCREEN-SPACE (após o pop do slide) — voam por cima de tudo.
function CardRewardScreen:_drawPurchaseFx()
    for _, fly in ipairs(self._flyCards or {}) do
        love.graphics.setColor(1, 1, 1, fly.alpha)
        love.graphics.draw(fly.img, fly.x, fly.y, fly.rot, fly.scale, fly.scale)
    end
    local font = FontManager.getFont(13)
    love.graphics.setFont(font)
    for _, p in ipairs(self._goldPopups or {}) do
        local t = p.age / POPUP_LIFE
        local a = 1 - t * t
        local y = p.y - 36 * t
        love.graphics.setColor(0, 0, 0, 0.7 * a)
        love.graphics.print(p.text, p.x + 1, y + 1)
        love.graphics.setColor(0.95, 0.78, 0.25, a)
        love.graphics.print(p.text, p.x, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Slot de carta comprada: moldura vazia esmaecida + stamp "VENDIDO" diagonal
-- (Balatro deixa o buraco no shelf — comunicar "você JÁ comprou isto aqui").
function CardRewardScreen:_drawSoldSlot(pos)
    local w = pos.w or self.cardWidth
    local h = pos.h or self.cardHeight
    love.graphics.setColor(0, 0, 0, 0.30)
    love.graphics.rectangle("fill", pos.x + 4, pos.y + 4, w - 8, h - 8, 4, 4)
    love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2],
        Palette.AGED_GOLD_DARK[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", pos.x + 4, pos.y + 4, w - 8, h - 8, 4, 4)

    local font = FontManager.getFont(14)
    love.graphics.setFont(font)
    local txt = I18n.t("reward.sold")
    local tw = font:getWidth(txt)
    love.graphics.push()
    love.graphics.translate(pos.x + w / 2, pos.y + h / 2)
    love.graphics.rotate(-0.28)
    love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], 0.75)
    love.graphics.rectangle("line", -tw / 2 - 8, -14, tw + 16, 28)
    love.graphics.print(txt, -tw / 2, -font:getHeight() / 2)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function CardRewardScreen:applyUpgrade(upgrade)
    if upgrade.effect == "forge_card" then
        -- Forja comprada: registra (o custo da PRÓXIMA cresce) e abre o picker
        -- de carta por cima da loja. O pagamento já aconteceu em purchaseOffer.
        if self.game.runManager and self.game.runManager.registerPaidForge then
            self.game.runManager:registerPaidForge()
        end
        if _G.openForgeScreen then
            _G.openForgeScreen()
        else
            Debug.warn("[CardRewardScreen] _G.openForgeScreen não registrado — forja ignorada")
        end
        return
    end
    -- P3.2 (rebalance Jul/2026): os branches toast-only (increase_card_draw /
    -- increase_attack_damage / increase_defense) foram REMOVIDOS junto com as
    -- ofertas correspondentes (ShopSystem:initializeShopPools) — upgrade
    -- comprado tem que aplicar efeito real, nunca só mensagem.
    if upgrade.effect == "increase_max_health" then
        self.game.player.maxHealth = self.game.player.maxHealth + upgrade.value
        self.game.player.health = self.game.player.health + upgrade.value
    elseif upgrade.effect == "increase_base_mana" then
        self.game.player.baseMaxMana = self.game.player.baseMaxMana + upgrade.value
        self.game.player.maxMana = self.game.player.maxMana + upgrade.value
        self.game.player.mana = self.game.player.mana + upgrade.value
    else
        Debug.warn("[CardRewardScreen] upgrade sem efeito implementado: "
            .. tostring(upgrade.effect) .. " — não deveria estar na vitrine (P3.2)")
    end
end

-- ============================================================================
-- SAÍDA COM CERIMÔNIA (queixa do dono: "sair da loja e voltar pro mapa não tem
-- transição nenhuma ... queria as cartas voltando, com som que indique isso")
-- ============================================================================
--
-- Antes, TODO caminho de saída era `self:hide()` seco — a tela simplesmente
-- deixava de existir no frame seguinte. Agora a saída é um gesto em 3 tempos,
-- todo ele com peças que já existiam na tela:
--
--   1. as cartas QUEIMAM em cascata (`start_dissolve`, o mesmo efeito que o
--      modo rewards já usava ao pegar uma carta) — "as cartas voltando";
--   2. o painel desliza pra fora (`slideOut`, escrito na Fase 7.4 e até hoje
--      só chamado pelo pack opening);
--   3. som de saída + o callback do fluxo, DEPOIS da animação.
--
-- `keepInst` é a carta comprada: ela não queima junto (já voou pro deck).
-- Com reducedMotion resolve na hora — mas o SOM toca igual: a flag remove
-- movimento, nunca informação (CLAUDE.md / ui_layout_invariants §3).
--
-- ⚠️ FILA PRÓPRIA, e não a `base` (memory/eventmanager_queues.md, regra de
-- ouro): na base os eventos de tela ficam presos atrás do rabo BLOQUEANTE do
-- combate — e `parallel` não salva, porque é blockable também. Foi assim que
-- nasceu o bug das "cartas invisíveis até o hover". Primeira versão deste
-- código caiu exatamente nessa armadilha e o test_shop_exit pegou: com a base
-- suja, o callback de continuar a run simplesmente não vinha.
--
-- Fila SEPARADA da FXQ de propósito: a FXQ é limpa a cada `show()` (é a fila
-- da ENTRADA) e a saída tem ciclo de vida próprio. Limpamos a nossa no início
-- da saída (mata zumbi de uma saída anterior) e o callback ainda guarda em
-- `self.visible`, como a regra manda pra evento com efeito de fluxo.
local EXITQ = "reward_exit"
local EXIT_DISSOLVE_STAGGER = 0.07
local EXIT_HOLD = 0.55

function CardRewardScreen:_exitWithFlourish(keepInst)
    if self._closing then return end
    self._closing = true
    EventManager.clear(EXITQ)

    local cb = self.onSkipped

    if reducedMotion() then
        playFirstSfx({ "shopLeaveWhoosh", "menuClose" })
        self:hide()
        if cb then cb() end
        return
    end

    for i, inst in ipairs(self.cardInstances) do
        if inst ~= keepInst and inst.start_dissolve and not inst._removed then
            EventManager.parallel((i - 1) * EXIT_DISSOLVE_STAGGER, function()
                inst:start_dissolve(nil, true, 0.55, true)
            end, EXITQ)
        end
    end

    -- O whoosh e o slide são UM gesto: o som sobe durante os 0,45s do
    -- deslize e o riffle assenta em 0,48s — medido, é quando o painel acabou
    -- de sair. Disparar junto é o que faz os dois lerem como a mesma coisa.
    self:slideOut()
    playFirstSfx({ "shopLeaveWhoosh", "menuClose" })

    EventManager.parallel(EXIT_HOLD, function()
        if not self.visible then return end
        self:hide()
        if cb then cb() end
    end, EXITQ)
end

function CardRewardScreen:hide()
    self.visible = false
    self._closing = false
    self.shopOffers = {}
    self.cardInstances = {}
    self.cardButtons = {}
    self.skipButton = nil
    self.refreshButton = nil
    self._flyCards = {}
    self._goldPopups = {}

    self:cancelPurchase()
    self:_resetDetail()
end

function CardRewardScreen:update(dt)
    if not self.visible then return end

    local currentWidth = love.graphics.getWidth()
    local currentHeight = love.graphics.getHeight()
    if not self.lastScreenWidth or self.lastScreenWidth ~= currentWidth or self.lastScreenHeight ~= currentHeight then
        dbg("RESIZE branch! %sx%s -> %dx%d (recria instancias/botoes)",
            tostring(self.lastScreenWidth), tostring(self.lastScreenHeight),
            currentWidth, currentHeight)
        self.lastScreenWidth = currentWidth
        self.lastScreenHeight = currentHeight
        self:updateLayout()
        if #self.shopOffers > 0 then
            self:createCardInstances()
            self:createOfferButtons()
            if self.mode == "shop" then
                -- updateLayout() já remediu o rodapé e reconstruiu os botões
                -- de compra; aqui não sobra nada de shop pra fazer.
            else
                if self.skipButton then
                    -- rewards: recentra pela LARGURA MEDIDA (não o -90 fixo)
                    self.skipButton.x = math.floor(love.graphics.getWidth() / 2
                        - self.skipButton.width / 2)
                    self.skipButton.y = self.skipButtonY
                end
                if self.refreshButton then
                    self.refreshButton.x = self.skipButtonX + 180
                    self.refreshButton.y = self.skipButtonY
                end
            end
        end
    end

    self.animationTime = self.animationTime + dt

    -- DEBUG: snapshot a cada 0.5s nos primeiros 6s da tela (o suficiente
    -- pra pegar a entrada travada sem inundar o log).
    if REWARD_DBG and self.animationTime < 6 then
        self._dbgNext = self._dbgNext or 0
        if self.animationTime >= self._dbgNext then
            self._dbgNext = self._dbgNext + 0.5
            dbg("UPDATE t=%.2f slideY=%.1f paused=%s pend(base)=%d pend(%s)=%d",
                self.animationTime, self.slideOffsetY or 0,
                tostring(EventManager.paused),
                EventManager.pendingCount("base"), FXQ,
                EventManager.pendingCount(FXQ))
            dbgCards(self, "  upd")
        end
    end

    local slotCount = self.slotCount or 3
    for i = 1, slotCount do
        local anim = self.cardAnimations[i]
        if anim then
            anim.elapsed = anim.elapsed + dt

            if anim.elapsed >= anim.delay then
                local progress = math.min(1, (anim.elapsed - anim.delay) / 0.3)
                anim.scale = anim.targetScale * self:easeOutBack(progress)
            end
        end
    end

    -- Hover/click nas cartas e seus invisible-buttons sempre rodam
    -- (sem modal bloqueando entrada). Selection overlay coexiste com hover.
    do
        -- Cartas são desenhadas DENTRO do translate do slide — o mouse vai
        -- pro espaço local antes do hit-test (em repouso o offset é 0, então
        -- isso só muda o comportamento durante o slide-in/slideOut).
        local mx, my = love.mouse.getPosition()
        my = my - (self.slideOffsetY or 0)
        for _, cardInstance in ipairs(self.cardInstances) do
            if cardInstance and cardInstance.updateMouse then
                cardInstance:updateMouse(mx, my, dt, true)
            end
        end
    end

    -- Hover → alimenta o painel de detalhe fixo do split-view.
    self:_updateHoverState()
    self:_resolveDetailPayload()
    self._detailAnim = math.min(1, (self._detailAnim or 1) + dt * 7)

    for _, button in ipairs(self.cardButtons) do
        button:update(dt)
    end

    if self.skipButton then
        self.skipButton:update(dt)
    end

    if self.refreshButton then
        self.refreshButton:update(dt)
    end

    -- Buttons attached da carta selecionada (Balatro pattern: filhos da carta).
    if self._selectionButtons then
        for _, b in ipairs(self._selectionButtons) do b:update(dt) end
    end

    self:_updatePurchaseFx(dt)
end

function CardRewardScreen:easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

function CardRewardScreen:draw()
    if not self.visible then return end

    local w, h = love.graphics.getDimensions()
    -- Backdrop FIXO (não desliza com o painel) — fica sempre cobrindo o gameplay
    -- atrás. Só o conteúdo (título + slots + botões) entra pelo topo.
    -- Background: cena DEDICADA do interior da loja (shop_interior). Não usa
    -- mais path_shop porque esse é o ícone do node de loja no mapa — repetir
    -- o mesmo visual entre map node e shop interior cria sensação de pobreza.
    -- Ver tools/pixellab_generate_shop_interior.py + memory/balatro_fidelity_directive.md.
    -- Fallback: se shop_interior não existe (ex: PixelLab ainda não gerou), usa
    -- path_shop temporariamente. Fallback final: backdrop preto.
    if self.mode == "rewards" then
        -- IMERSÃO (feedback Jul/2026): espólios de batalha acontecem NO LUGAR
        -- da batalha — main.lua já desenha o mundo vivo atrás (GameplayScene
        -- antes deste draw; WorldRoad continua tickando). Só um véu escuro
        -- pra dar foco ao painel — nada de interior de loja aqui.
        love.graphics.setColor(0.02, 0.015, 0.01, 0.60)
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(1, 1, 1, 1)
    elseif not SceneBackground.draw("shop_interior", w, h, 0.55) then
        if not SceneBackground.draw("path_shop", w, h, 0.55) then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end

    -- Slide-in: tudo dentro deste push é translado pelo offset animado em show().
    love.graphics.push()
    love.graphics.translate(0, self.slideOffsetY or 0)

    -- ========== F10.3: Containers Balatro-style ==========
    -- Painel principal (BOSS_MAIN bg + dual-border dourado). Modo rewards v3
    -- NÃO tem painel — banner flutuante estilo StS.
    if self.panel then
        self:_drawPanel(self.panel.x, self.panel.y, self.panel.w, self.panel.h, "main")
        -- Title bar dourado dentro do painel.
        self:_drawTitleBar(self.panel.x, self.panel.y, self.panel.w)
    elseif self.mode == "rewards" then
        self:_drawRewardsBanner()
    end

    -- Subcontainer da GRADE (split-view: cartas + voucher + packs vivem na
    -- mesma vitrine, não em três caixas separadas como antes).
    if self.gridArea then
        self:_drawPanel(self.gridArea.x, self.gridArea.y,
                        self.gridArea.w, self.gridArea.h, "inner")
    end
    -- Rodapé de ações (reroll | OURO | continuar). O dinheiro continua ao lado
    -- das ações de gastar, como na coluna antiga — só mudou de orientação.
    if self.actionBar then
        self:_drawActionBar()
    end

    -- DEBUG: por 6s, loga o GATE de draw de cada carta a cada 0.5s.
    local dbgDrawTick = false
    if REWARD_DBG and self.animationTime < 6 then
        if self.animationTime >= (self._dbgDrawNext or 0) then
            self._dbgDrawNext = (self._dbgDrawNext or 0) + 0.5
            dbgDrawTick = true
        end
    end

    for _, cardInstance in ipairs(self.cardInstances) do
        if cardInstance and cardInstance.draw then
            -- F2: anim e affordability vêm da OFERTA da própria instância
            -- (indexar shopOffers[i] quebrava após a 1ª compra).
            local offer = cardInstance.shopOffer
            local slot = offer and offer._slot
            local anim = slot and self.cardAnimations[slot]
            local scale = anim and anim.scale or 1

            if dbgDrawTick then
                dbg("DRAW gate slot=%s scale=%.2f -> %s | x=%s y=%s+%s dissolve=%s slideY=%.1f",
                    tostring(slot), scale, (scale > 0) and "DESENHA" or "PULA",
                    tostring(cardInstance.x), tostring(cardInstance.y),
                    tostring(cardInstance._entryOy), tostring(cardInstance.dissolve),
                    self.slideOffsetY or 0)
            end
            if REWARD_DBG and scale > 0 and not cardInstance._dbgDrawn then
                cardInstance._dbgDrawn = true
                dbg("PRIMEIRO draw da carta slot=%s (t=%.2f)", tostring(slot), self.animationTime)
            end

            if scale > 0 then
                -- Impagável = carta escurecida (2º canal além do preço
                -- vermelho; pesquisa: nunca comunicar só por cor do número)
                cardInstance.saleDim = (self.mode == "shop") and offer
                    and offer.cost and self.game
                    and not self.game.economySystem:canAfford(offer.cost)
                    or false
                -- _cardDrawRect parte de homeX/homeY (âncora IMUTÁVEL) — nunca
                -- de self.x/y, que o Card:draw sobrescreve a cada frame (o
                -- feedback loop y+=entryOy mandava as cartas pra y≈-1900; era
                -- o bug "não renderizam") — e já aplica a puladinha do hover.
                local r = self:_cardDrawRect(cardInstance)
                cardInstance._drawRect = r   -- lido pelo halo de seleção
                cardInstance:draw(r.drawX, r.drawY, false, true)
                -- Medalhão ancorado no retângulo REAL: acompanha a carta.
                self:drawPriceOverlay(cardInstance, r)
            end
        end
    end

    local slotCount = self.slotCount or 3
    for _, offer in ipairs(self.shopOffers) do
        local slot = offer._slot or math.huge
        if offer.type ~= "card" and slot <= slotCount and not offer.purchased then
            local anim = self.cardAnimations[slot]
            local scale = anim and anim.scale or 1

            if scale > 0 then
                local pos = self.cardPositions[slot] or {x = 0, y = 0}
                self:drawOffer(offer, pos.x, pos.y, slot, pos.w, pos.h)
            end
        end
        -- Slot já comprado: buraco com stamp VENDIDO (posições estáveis).
        if offer.purchased and slot <= slotCount and self.cardPositions[slot] then
            self:_drawSoldSlot(self.cardPositions[slot])
        end
    end

    -- Marcadores (raridade + afinidade) em PASSE PRÓPRIO, depois de todas as
    -- cartas: assim a carta vizinha em hover nunca passa por cima deles. Eles
    -- ficam na faixa FIXA sob o slot — a carta é que pula pra cima, liberando
    -- o rótulo (pedido do dono).
    for _, cardInstance in ipairs(self.cardInstances) do
        local offer = cardInstance and cardInstance.shopOffer
        local slot = offer and offer._slot
        local anim = slot and self.cardAnimations[slot]
        if slot and (anim and anim.scale or 1) > 0 then
            self:drawOfferBadges(cardInstance, slot)
        end
    end

    -- ===== Painel de DETALHE FIXO (3ª coluna, só na loja) =====
    -- Desenhado DENTRO do slide, junto com o resto do painel: ele é parte da
    -- janela da loja, não um popup por cima dela.
    if self.detailPanel then
        self:_drawDetailPanel()
    end

    if self.skipButton then
        self.skipButton:draw()
    end

    if self.refreshButton then
        self.refreshButton:draw()
    end

    self:drawInstructions()

    -- Fecha o push do slide.
    love.graphics.pop()

    -- ========== SEGUNDA PASS: overlays acima de tudo ==========
    -- LOJA: nenhum tooltip/popup flutuante. Toda a informação da oferta vive
    -- no painel de detalhe FIXO da terceira coluna, desenhado junto com o
    -- resto do painel (dentro do slide) — leitura em posição estável.

    -- REWARDS: tooltip canônico do jogo (o mesmo da mão/deck viewer) acima
    -- da carta em hover — some quando há seleção ativa (os botões mandam).
    if self.mode == "rewards" and self.hoveredInst and not self.selectedOffer then
        local inst = self.hoveredInst
        self.cardInfoDisplay:draw(inst, inst.x or 0, inst.y or 0, {
            showRarity = false,   -- o pill de raridade já está acima da carta
            showStats = true,
            showDescription = true,
        })
    end

    -- Selection overlay (CLICK): halo pulsante + mini-buttons Balatro-style
    -- (UI_definitions.lua:382 card_focus_button) attached compactos sob a carta.
    self:_drawSelectionOverlay()

    -- FX de compra por cima de tudo (carta voando pro deck + popups -$N).
    self:_drawPurchaseFx()

    -- Inspeção completa (clique DIREITO numa oferta): mesma visão da Coleção
    -- — carta grande + painel de detalhes. Por cima de tudo.
    if self.inspectModal then
        self.inspectModal:update(love.timer.getDelta())
        self.inspectModal:draw()
    end
end

-- F10.3 + F11.2 → design system Jul/2026: o painel Balatro-style virou o
-- CANÔNICO do jogo e mora em src/ui/UiPanel.lua (fonte única com PauseMenu
-- e futuras telas). Este método é só o adapter do call site legado.
function CardRewardScreen:_drawPanel(x, y, w, h, depth)
    local UiPanel = require("src.ui.UiPanel")
    UiPanel.draw(x, y, w, h, { depth = depth or "main" })
end

-- F10.3: Title bar dourado no topo do painel principal com nome da loja +
-- ouro à direita. Fica DENTRO do painel principal (não solto na cena).
function CardRewardScreen:_drawTitleBar(panelX, panelY, panelW)
    local h = 36
    local x = panelX + 8
    local y = panelY + 6
    local w = panelW - 16

    PixelCanvas.rect(x, y, w, h, Palette.PANEL_FILL or {0.18, 0.12, 0.08, 1})
    PixelCanvas.rectOutline(x, y, w, h, Palette.AGED_GOLD or {0.78, 0.65, 0.20, 1})
    PixelCanvas.rectOutline(x + 2, y + 2, w - 4, h - 4, Palette.AGED_GOLD_DARK or {0.45, 0.32, 0.10, 1})

    -- Texto principal centralizado. Modo rewards ganha título próprio +
    -- subtítulo que diz a REGRA ("escolha 1") — a tela antiga não contava.
    local isRewards = self.mode == "rewards"
    Palette.set(Palette.AGED_GOLD_LIGHT or {1, 0.92, 0.55, 1})
    love.graphics.setFont(FontManager.getFont(14))
    local title = isRewards and I18n.t("reward.rewards_title")
        or (I18n.t("reward.shop_title") or "LOJA DE RELIQUIAS")
    love.graphics.printf(title, x, y + (isRewards and 5 or 10), w, "center")

    if isRewards then
        Palette.set(Palette.PARCHMENT or {0.85, 0.78, 0.62, 1})
        love.graphics.setFont(FontManager.getFont(8))
        love.graphics.printf(I18n.t("reward.rewards_subtitle"), x, y + 23, w, "center")
    end

    -- Ouro à direita — SÓ na loja (em recompensas as ofertas são grátis).
    -- UM ÚNICO leitor de ouro na tela, e é este: o rodapé de ações chegou a
    -- ter outro, mas duplicar o mesmo número em dois cantos incomodava o dono.
    -- Ficou o do header por ser onde a informação sempre esteve (padrão HUD).
    if self.mode == "shop" and self.game and self.game.economySystem then
        local goldText = I18n.t("reward.gold_label",
            { n = self.game.economySystem.currentGold })
        love.graphics.setFont(FontManager.getFont(10))
        Palette.set(Palette.PARCHMENT_LIGHT or {0.92, 0.85, 0.70, 1})
        love.graphics.printf(goldText, x, y + 12, w - 12, "right")
    end

    -- "?" no canto esquerdo do title bar: explica as REGRAS de oferta (pity,
    -- afinidade, raridade por ato) em linguagem de jogador — hover abre tooltip.
    local hx, hy, hr = x + 18, y + math.floor(h / 2), 10
    love.graphics.setColor(0.10, 0.08, 0.05, 1)
    love.graphics.circle("fill", hx, hy, hr)
    Palette.set(Palette.AGED_GOLD or {0.78, 0.65, 0.20, 1})
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", hx, hy, hr)
    Palette.set(Palette.AGED_GOLD_LIGHT or {1, 0.92, 0.55, 1})
    love.graphics.setFont(FontManager.getFont(11))
    love.graphics.print("?", hx - 3, hy - 8)

    -- Hitbox em coordenadas de tela: o painel desenha dentro do translate do
    -- slide — converte o mouse pro espaço local antes de comparar.
    local mx, my = love.mouse.getPosition()
    local myLocal = my - (self.slideOffsetY or 0)
    if mx >= hx - hr - 3 and mx <= hx + hr + 3
        and myLocal >= hy - hr - 3 and myLocal <= hy + hr + 3 then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            StatusTooltip.show("reward_rules", mx, my)
        end
    end
end

-- Banner flutuante do modo rewards (v3 StS): título grande com outline ink,
-- filetes ornamentais com losango dos dois lados, subtítulo com respiro e o
-- "?" das regras (pity/afinidade/raridade) à direita do título.
function CardRewardScreen:_drawRewardsBanner()
    local sw = love.graphics.getWidth()
    local y = self.bannerY or 80
    local cx = math.floor(sw / 2)

    local title = I18n.t("reward.rewards_title")
    local tf = FontManager.getFont(20)
    love.graphics.setFont(tf)
    local tw = tf:getWidth(title)
    local th = tf:getHeight()

    -- filetes ornamentais: linha dupla desvanecendo pra fora + losango interno
    local lineY = y + math.floor(th / 2)
    local gap = math.floor(tw / 2) + 26
    local lineW = math.min(190, math.floor(sw * 0.17))
    local g = Palette.AGED_GOLD
    for _, side in ipairs({ -1, 1 }) do
        local x0 = cx + side * gap
        local x1 = cx + side * (gap + lineW)
        for seg = 0, 7 do
            local a = 0.85 * (1 - seg / 8)
            local sx0 = x0 + side * (lineW / 8) * seg
            love.graphics.setColor(g[1], g[2], g[3], a)
            love.graphics.rectangle("fill", math.min(sx0, sx0 + side * (lineW / 8)),
                lineY - 1, lineW / 8, 2)
        end
        -- losango na ponta interna
        local px = x0 - side * 4
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.polygon("fill", px, lineY - 5 + 1, px + 5, lineY + 1,
            px, lineY + 5 + 1, px - 5, lineY + 1)
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.polygon("fill", px, lineY - 5, px + 5, lineY,
            px, lineY + 5, px - 5, lineY)
    end

    -- título: outline ink 4-direções + face dourada (mesma linguagem do boot)
    local tx = cx - math.floor(tw / 2)
    love.graphics.setColor(0, 0, 0, 0.85)
    for _, o in ipairs({ {2, 0}, {-2, 0}, {0, 2}, {0, -2}, {2, 2} }) do
        love.graphics.print(title, tx + o[1], y + o[2])
    end
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, tx, y)

    -- subtítulo com RESPIRO (feedback: "texto meio apertado")
    local sub = I18n.t("reward.rewards_subtitle")
    local sf = FontManager.getFont(9)
    love.graphics.setFont(sf)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(sub, cx - math.floor(sf:getWidth(sub) / 2) + 1, y + th + 15)
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.print(sub, cx - math.floor(sf:getWidth(sub) / 2), y + th + 14)

    -- "?" das regras à direita do filete (tooltip de pity/afinidade)
    local hx = cx + gap + lineW + 22
    local hy = lineY
    local hr = 10
    love.graphics.setColor(0.10, 0.08, 0.05, 0.9)
    love.graphics.circle("fill", hx, hy, hr)
    Palette.set(Palette.AGED_GOLD)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", hx, hy, hr)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.setFont(FontManager.getFont(11))
    love.graphics.print("?", hx - 3, hy - 8)
    local mx, my = love.mouse.getPosition()
    local myLocal = my - (self.slideOffsetY or 0)
    if mx >= hx - hr - 3 and mx <= hx + hr + 3
        and myLocal >= hy - hr - 3 and myLocal <= hy + hr + 3 then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            StatusTooltip.show("reward_rules", mx, my)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Marcadores de clareza da oferta: raridade NOMEADA + "AFINIDADE" quando a
-- carta foi puxada pelas tags fortes do deck. Clareza: raridade não é só uma
-- borda colorida; afinidade não é mágica.
--
-- Posicionamento por modo:
--   rewards → folgas do slot (a carta ocupa 86%, sobra espaço real)
--   shop    → faixa de rótulos SOB o slot (slotLabelH), em escala menor:
--             linha 1 = raridade, linha 2 = afinidade.
function CardRewardScreen:drawOfferBadges(cardInstance, slot)
    local offer = cardInstance.shopOffer
    if not offer or offer.purchased then return end
    -- Carta ainda caindo (entrada animada): marcadores esperam ela pousar.
    if (cardInstance._entryOy or 0) > 1 then return end
    local pos = self.cardPositions[slot]
    if not pos then return end
    local w = pos.w or self.cardWidth
    local h = pos.h or self.cardHeight

    -- Reforma v3 (feedback: "só um quadrado com texto, feio"): marcador SEM
    -- caixa — texto colorido com outline ink e LOSANGOS dos dois lados
    -- (◆ RARA ◆), mesma linguagem ornamental do banner.
    local function marker(cx, cy, text, color, fontSize, dia)
        local f = FontManager.getFont(fontSize)
        love.graphics.setFont(f)
        local tw = f:getWidth(text)
        local fh = f:getHeight()
        -- losangos
        local dx = math.floor(tw / 2) + 12
        for _, sx in ipairs({ -1, 1 }) do
            local px = cx + sx * dx
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.polygon("fill", px, cy - dia + 1, px + dia, cy + 1,
                px, cy + dia + 1, px - dia, cy + 1)
            love.graphics.setColor(color[1], color[2], color[3], 1)
            love.graphics.polygon("fill", px, cy - dia, px + dia, cy,
                px, cy + dia, px - dia, cy)
        end
        -- texto com outline ink
        local tx = cx - math.floor(tw / 2)
        local ty = cy - math.floor(fh / 2)
        love.graphics.setColor(0, 0, 0, 0.85)
        for _, o in ipairs({ {1, 0}, {-1, 0}, {0, 1}, {0, -1} }) do
            love.graphics.print(text, tx + o[1], ty + o[2])
        end
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.print(text, tx, ty)
    end

    local cx = pos.x + math.floor(w / 2)
    if self.mode == "shop" then
        -- Faixa de rótulos abaixo do slot (slotLabelH reservado no layout).
        if offer.rarity then
            local label = (I18n.t("rarity." .. offer.rarity, nil, offer.rarity)):upper()
            marker(cx, pos.y + h + 13, label, Palette.forRarity(offer.rarity), 8, 3)
        end
        if offer.affinity then
            marker(cx, pos.y + h + 24, I18n.t("reward.affinity_badge"),
                Palette.AGED_GOLD_LIGHT, 7, 2)
        end
    else
        if offer.rarity then
            local label = (I18n.t("rarity." .. offer.rarity, nil, offer.rarity)):upper()
            marker(cx, pos.y - 15, label, Palette.forRarity(offer.rarity), 9, 4)
        end
        if offer.affinity then
            marker(cx, pos.y + h + 15,
                I18n.t("reward.affinity_badge"), Palette.AGED_GOLD_LIGHT, 8, 3)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- PAINEL DE DETALHE FIXO — a coluna que explica a oferta em foco
-- ============================================================================
function CardRewardScreen:_drawDetailPanel()
    local dp = self.detailPanel
    if not dp then return end

    local payload = self.detailPayload
    local offer = payload and payload.offer
    local canAfford = true
    if offer and (offer.cost or 0) > 0 and self.game and self.game.economySystem then
        canAfford = self.game.economySystem:canAfford(offer.cost)
    end

    -- Rodapé reservado só quando há seleção ativa (os botões moram lá).
    local footerH = self.selectedOffer and (self.detailFooterH or 58) or 0

    -- Rodapé de contexto: no pré-foco ENSINA (o painel nasce cheio, mas o
    -- jogador ainda não sabe que ele responde ao mouse); depois só avisa que
    -- está segurando a última oferta observada.
    local hint = nil
    if self._detailPrefocus then
        -- Curto DE PROPÓSITO: cabe numa linha só na coluna mais estreita
        -- (230px), então não há wrap nem risco de entrelinha apertada.
        hint = I18n.t("reward.detail_prefocus", nil, "Passe o mouse pra comparar")
    elseif self._detailStale then
        hint = I18n.t("reward.detail_stale", nil, "ultima oferta observada")
    end

    CardDetailPanel.draw(dp, payload, {
        alpha     = math.max(0, math.min(1, self._detailAnim or 1)),
        stale     = hint ~= nil,
        canAfford = canAfford,
        footerH   = footerH,
        emptyHint = I18n.t("reward.detail_empty", nil,
            "Passe o mouse sobre uma oferta para ver os detalhes"),
        staleHint = hint,
    })
end

-- Tooltip de carta em pass separado pra ficar acima de tudo (F10.2). Calcula
-- posição relativa à carta, idêntico ao que Card:draw fazia inline.
function CardRewardScreen:_drawCardTooltipOverlay(cardInstance)
    if not cardInstance.cardInfoDisplay then return end

    -- Posição: ABAIXO da carta (smart positioning fará fallback acima se
    -- ultrapassar bottom da tela). Usa renderX/Y se Card tem interpolação,
    -- senão x/y direto.
    local px = cardInstance.renderX or cardInstance.x or 0
    local py = cardInstance.renderY or cardInstance.y or 0

    cardInstance.cardInfoDisplay:draw(cardInstance, px, py, {
        showRarity = false,
        showStats = true,
        showDescription = true,
    })
end

function CardRewardScreen:drawTitle()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local titleFont = FontManager.getFont(16)
    love.graphics.setFont(titleFont)

    local title = I18n.t("reward.shop_title")
    local titleWidth = titleFont:getWidth(title)
    local titleX = math.floor((screenWidth - titleWidth) / 2)
    local titleY = math.floor(screenHeight * 0.1)

    local padX, padY = 20, 8
    local bx, by = titleX - padX, titleY - padY
    local bw, bh = titleWidth + padX * 2, titleFont:getHeight() + padY * 2
    PixelCanvas.rect(bx, by, bw, bh, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(bx, by, bw, bh, Palette.PANEL_OUTLINE)
    PixelCanvas.rectOutline(bx + 2, by + 2, bw - 4, bh - 4, Palette.PANEL_OUTLINE_INNER)

    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, titleX, titleY)

    if self.game and self.game.economySystem then
        local goldText = I18n.t("reward.gold_label", { n = self.game.economySystem.currentGold })
        local goldFont = FontManager.getFont(10)
        love.graphics.setFont(goldFont)
        local goldWidth = goldFont:getWidth(goldText)
        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.print(goldText,
            math.floor((screenWidth - goldWidth) / 2),
            titleY + bh)
    end
end

function CardRewardScreen:drawOffer(offer, x, y, index, customW, customH)
    local canAfford = self.game and self.game.economySystem:canAfford(offer.cost)
    local w = customW or self.cardWidth
    local h = customH or self.cardHeight
    -- Slot pequeno = tile do split-view: o texto longo sai (o painel de
    -- detalhe carrega a descrição) e as faixas encolhem pra sobrar arte.
    local compact = h < 250

    -- Booster pack: usa o sleeve PixelLab via PackSleeve em vez de retângulo plano.
    -- Sleeve preenche o slot inteiro, preço fica overlaid embaixo.
    if offer.type == "booster_pack" then
        local PackSleeve = require("src.ui.PackSleeve")
        local sleeveW, sleeveH = PackSleeve.getDimensions()

        -- Header (nome) ocupa o topo; price banner ocupa o rodapé.
        -- Sleeve preenche o resto centralizado.
        local headerH = compact and 13 or 16
        local priceH = compact and 18 or 22
        local availH = h - headerH - priceH - 8
        local availW = w - 8
        local scale = math.min(availW / sleeveW, availH / sleeveH)

        local cx = math.floor(x + w * 0.5)
        local cy = math.floor(y + headerH + 4 + (sleeveH * scale) * 0.5)
        PackSleeve.drawAt(offer.id, offer.kind, cx, cy, scale, 1)

        -- Nome do pack no topo do slot (dentro).
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.setFont(FontManager.getFont(compact and 8 or 9))
        love.graphics.printf(offer.name, x + 4, y + 3, w - 8, "center")

        -- Preço banner no rodapé — largura casada com o SLEEVE, não com o
        -- slot: na fileira larga do split-view uma barra de 206px sob um
        -- pacote de 120px ficava solta, sem parecer do mesmo objeto.
        local pricecolor = canAfford and Palette.AGED_GOLD or Palette.BLOOD
        local bannerW = math.floor(math.min(w - 8, math.max(70, sleeveW * scale + 16)))
        local bx = math.floor(x + (w - bannerW) / 2)
        local by = math.floor(y + h - priceH - 4)
        PixelCanvas.rect(bx, by, bannerW, priceH, Palette.PANEL_FILL)
        PixelCanvas.rectOutline(bx, by, bannerW, priceH, pricecolor)
        Palette.set(canAfford and Palette.AGED_GOLD_LIGHT or Palette.BLOOD)
        -- Fonte 11/9: no tamanho 10 o glifo "6" da fonte pixel rasteriza como "G".
        love.graphics.setFont(FontManager.getFont(compact and 9 or 11))
        love.graphics.printf("$" .. offer.cost, bx, by + (compact and 4 or 5),
            bannerW, "center")
        return
    end

    -- Upgrade (voucher) ou outro: card-style frame.
    PixelCanvas.rect(math.floor(x), math.floor(y), math.floor(w), math.floor(h), Palette.PANEL_FILL)
    PixelCanvas.rectOutline(math.floor(x), math.floor(y), math.floor(w), math.floor(h),
        canAfford and Palette.AGED_GOLD or Palette.BLOOD)

    local displayName = offer.type == "card" and I18n.cardName({ id = offer.id, name = offer.name }) or offer.name
    local displayDesc = offer.type == "card" and I18n.cardDesc({ id = offer.id, description = offer.description }) or offer.description
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.setFont(FontManager.getFont(compact and 8 or 10))
    love.graphics.printf(displayName, x + 6, y + (compact and 6 or 12), w - 12, "center")

    -- Voucher: sprite PixelLab específico do offer.id ocupa o centro.
    -- Fallback: texto "✦ VOUCHER ✦" se o PNG não foi gerado pra esse id.
    if offer.type == "upgrade" then
        local spritePath = "assets/sprites/vouchers/" .. tostring(offer.id) .. ".png"
        -- tryGet: miss = nil (o get() devolvia o FALLBACK theRock e o
        -- voucher sem arte mostrava a carta placeholder antiga na loja)
        local sprite = ImageCache.tryGet(spritePath)
        local hasSprite = sprite ~= nil
        -- Layout: nome no topo, sprite centralizado vertical+horizontal, desc+preço no rodapé.
        -- Slots de Y: nameTop(28) → spriteArea(meio) → descBottom(38) → priceBottom(24).
        -- No tile compacto do split-view a DESCRIÇÃO sai (ela vive no painel
        -- de detalhe) e sobra espaço pra arte do voucher respirar.
        local nameTopH   = compact and 20 or 28   -- reserva pro nome
        local descBottomH = compact and 0 or 38   -- desc fica acima do preço
        local priceBottomH = compact and 20 or 24 -- preço no rodapé
        local spriteAreaY = y + nameTopH
        local spriteAreaH = h - nameTopH - descBottomH - priceBottomH
        if hasSprite and spriteAreaH > 16 then
            local sw, sh = sprite:getWidth(), sprite:getHeight()
            -- Aproveita melhor o espaço: padding lateral 12px, vertical 4px.
            local areaW = w - 24
            local areaH = spriteAreaH - 8
            local rawScale = math.min(areaW / sw, areaH / sh)
            -- Pixel art prefere integer scale, mas se area < sprite usa float pra caber.
            local scale = rawScale >= 1 and math.floor(rawScale) or rawScale
            local drawW = sw * scale
            local drawH = sh * scale
            local dx = math.floor(x + (w - drawW) / 2)
            local dy = math.floor(spriteAreaY + 4 + (areaH - drawH) / 2)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sprite, dx, dy, 0, scale, scale)
        end

        -- Descrição compacta acima do preço (não no meio como antes).
        if descBottomH > 0 then
            Palette.set(Palette.PARCHMENT)
            love.graphics.setFont(FontManager.getFont(8))
            love.graphics.printf(displayDesc, x + 6, y + h - descBottomH, w - 12, "center")
        end
    else
        Palette.set(Palette.PARCHMENT)
        love.graphics.setFont(FontManager.getFont(8))
        love.graphics.printf(displayDesc, x + 8, y + 36, w - 16, "center")
    end

    -- Tag visual no header: rarity p/ cards, BOOSTER p/ packs, UPGRADE p/ vouchers.
    if offer.type == "card" and offer.rarity then
        Palette.set(Palette.forRarity(offer.rarity))
        love.graphics.rectangle("fill", math.floor(x + 6), math.floor(y + 4), math.floor(w - 12), 3)
    elseif offer.type == "upgrade" then
        Palette.set(Palette.MOSS or {0.4, 0.65, 0.35, 1})
        love.graphics.rectangle("fill", math.floor(x + 6), math.floor(y + 4), math.floor(w - 12), 3)
    end

    Palette.set(canAfford and Palette.AGED_GOLD_LIGHT or Palette.BLOOD)
    -- Fonte 11/9: no tamanho 10 o glifo "6" da fonte pixel rasteriza como "G".
    love.graphics.setFont(FontManager.getFont(compact and 9 or 11))
    love.graphics.printf("$" .. offer.cost, x + 8, y + h - (compact and 18 or 24),
        w - 16, "center")
end

-- Medalhão dourado canto superior-direito da carta. Inspirado em Balatro
-- create_shop_card_ui (UI_definitions.lua:802-880) que usa UIBox flutuante
-- com DynaText `$<cost>`. Aqui simplificamos com disco + texto centrado.
-- Tem halo glow externo, disco principal, outline preto, $N centralizado.
-- Estado: dourado se canAfford, blood-red se não.
-- rect: retângulo REAL da carta neste frame (_cardDrawRect). O medalhão é
-- parte da carta — tem que subir junto com ela no hover, não ficar preso ao
-- retângulo estático do slot.
function CardRewardScreen:drawPriceOverlay(cardInstance, rect)
    local offer = cardInstance.shopOffer
    if not offer or offer.purchased then return end
    -- Recompensa grátis (rewards mode): sem medalhão de preço.
    if (offer.cost or 0) <= 0 then return end

    local canAfford = self.game and self.game.economySystem:canAfford(offer.cost)

    -- Posição: canto superior-direito da carta DESENHADA.
    -- Raio proporcional à carta: no grid compacto do split-view um disco de
    -- 14px fixo comia a ilustração inteira.
    local r = math.max(9, math.min(14, math.floor(rect.w * 0.13)))
    local cx = math.floor(rect.x + rect.w - r)
    local cy = math.floor(rect.y + r)

    -- Sombra atrás do disco (offset 2,2).
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("fill", cx + 2, cy + 2, r + 1)

    -- Halo externo glow (cor combina com afford).
    if canAfford then
        love.graphics.setColor(1.0, 0.85, 0.30, 0.45)
    else
        love.graphics.setColor(0.85, 0.18, 0.18, 0.45)
    end
    love.graphics.circle("fill", cx, cy, r + 3)

    -- Disco principal.
    if canAfford then
        love.graphics.setColor(0.95, 0.78, 0.25, 1)
    else
        love.graphics.setColor(0.55, 0.14, 0.10, 1)
    end
    love.graphics.circle("fill", cx, cy, r)

    -- Borda interna mais clara (highlight).
    love.graphics.setColor(canAfford and {1, 0.92, 0.55, 0.6} or {0.85, 0.30, 0.20, 0.6})
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, r - 1)

    -- Outline externo escuro pra contrastar com fundo claro.
    love.graphics.setColor(0.05, 0.04, 0.02, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, r)

    -- Texto $N centralizado. Cor escura sobre dourado, clara sobre vermelho.
    -- Fonte 11 no disco grande, 9 no compacto — 10 é proibido (o glifo "6"
    -- da fonte pixel rasteriza como "G" nesse tamanho).
    local font = FontManager.getFont(r >= 12 and 11 or 9)
    love.graphics.setFont(font)
    local txt = "$" .. tostring(offer.cost)
    local tw = font:getWidth(txt)
    local th = font:getHeight()
    if canAfford then
        love.graphics.setColor(0.10, 0.06, 0.02, 1)
    else
        love.graphics.setColor(1, 0.95, 0.85, 1)
    end
    love.graphics.print(txt, cx - tw * 0.5, cy - th * 0.5)
    love.graphics.setColor(1, 1, 1, 1)
end

-- LEGACY: drawPurchaseConfirmation (modal centralizado) removido. Substituído
-- pelo _drawSelectionOverlay (3-zone Balatro pattern). Mantido como stub no-op
-- caso algum call site externo ainda chame.
function CardRewardScreen:drawPurchaseConfirmation() end

-- ============================================================================
-- SELECTION (CLICK) — mini-buttons Balatro-style sob a carta
-- ============================================================================
-- Quando uma carta é clicada (setSelectedOffer), desenha:
--   1) Halo dourado pulsante na carta (feedback visual de selecionada).
--   2) Mini-buttons compactos (COMPRAR $N + X). Na LOJA eles ancoram no
--      rodapé do painel de detalhe; em "rewards", sob a carta.
-- A descrição da oferta NÃO é parte deste overlay — mora no painel fixo.
function CardRewardScreen:_drawSelectionOverlay()
    local anim = self._selectionAnim or 0
    if anim < 0.01 and not self.selectedOffer then return end
    if not self.selectedOffer or not self.selectedIdx then return end

    local pos = self.cardPositions[self.selectedIdx]
    if not pos then return end
    local anchorW = pos.w or self.cardWidth
    local anchorH = pos.h or self.cardHeight
    local anchorX = pos.x
    local anchorY = pos.y
    -- Se a oferta selecionada é uma CARTA, o halo abraça o retângulo REAL
    -- dela (com a puladinha do hover) em vez do retângulo estático do slot.
    local selInst = self.selectedOffer and self.selectedOffer.cardInstance
    local selRect = selInst and selInst._drawRect
    if selRect and selRect.w > 0 then
        anchorX, anchorY = selRect.x, selRect.y
        anchorW, anchorH = selRect.w, selRect.h
    end

    -- Halo dourado pulsante na carta selecionada.
    local haloAlpha = 0.55 * anim * (0.7 + 0.3 * math.sin(love.timer.getTime() * 3.5))
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], haloAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", anchorX - 3, anchorY - 3, anchorW + 6, anchorH + 6)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], haloAlpha * 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", anchorX - 1, anchorY - 1, anchorW + 2, anchorH + 2)

    -- Buttons attached (criados em _buildSelectionButtons). Reposiciona a cada
    -- frame pra acompanhar mudanças de layout. Na LOJA eles moram no rodapé do
    -- painel de detalhe (é lá que a oferta está sendo lida — confirmar do lado
    -- do que se lê); em "rewards" continuam colados sob a carta.
    if self._selectionButtons and #self._selectionButtons > 0 then
        local bx0, by0, _, _, _, gap = self:_selectionButtonsRect(self.selectedIdx)
        if bx0 then
            local cursorX = bx0
            for _, b in ipairs(self._selectionButtons) do
                b.x = cursorX
                b.y = by0
                b:draw()
                cursorX = cursorX + b.width + (gap or 8)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- LEGACY: _drawHoverInfoPanels (2 painéis FLUTUANTES fora da janela da loja)
-- foi REMOVIDO no split-view de Jul/2026. Era a causa raiz da reclamação do
-- dono: a informação da oferta vivia num popup que saltava de posição e
-- cobria as cartas vizinhas. Substituído pelo painel de detalhe FIXO
-- (src/ui/CardDetailPanel.lua) na terceira coluna. Em "rewards" esses painéis
-- já estavam desligados — lá o hover usa o tooltip canônico (CardInfoDisplay).

-- Atualiza estado de hover lendo cardInstance.isHovered. Chamado em :update.
-- Split-view: voucher e booster pack TAMBÉM entram no hover (antes só cartas
-- tinham instância com isHovered) — o painel de detalhe explica qualquer
-- oferta, não só as cartas.
function CardRewardScreen:_updateHoverState()
    local newHovered, newInst, newKind = nil, nil, nil

    for _, inst in ipairs(self.cardInstances or {}) do
        if inst and inst.isHovered then
            -- F2: a oferta vem da própria instância (shopOffers[i] mostrava
            -- a info da carta ERRADA depois de uma compra).
            local offer = inst.shopOffer
            if offer and not offer.purchased then
                newHovered, newInst, newKind = offer, inst, "card"
                break
            end
        end
    end

    if not newHovered and self.mode == "shop" then
        -- Hit-test por retângulo do slot. O layout vive dentro do translate do
        -- slide, então o mouse precisa ir pro espaço local antes de comparar.
        local mx, my = love.mouse.getPosition()
        my = my - (self.slideOffsetY or 0)
        for _, offer in ipairs(self.shopOffers or {}) do
            local pos = offer._slot and self.cardPositions[offer._slot]
            if pos and offer.type ~= "card" and not offer.purchased then
                local pw = pos.w or self.cardWidth
                local ph = pos.h or self.cardHeight
                if mx >= pos.x and mx <= pos.x + pw
                    and my >= pos.y and my <= pos.y + ph then
                    newHovered = offer
                    newKind = offerKind(offer)
                    break
                end
            end
        end
    end

    if newHovered ~= self.hoveredOffer then
        self.hoveredOffer = newHovered
        self.hoveredInst = newInst
        self.hoveredKind = newKind
    end
end

-- ============================================================================
-- PAINEL DE DETALHE FIXO (split-view da loja)
-- ============================================================================
-- Decide O QUE o painel da direita mostra, por prioridade:
--   1) a oferta SELECIONADA — trava enquanto o jogador confirma a compra
--      (o que ele vai pagar não pode sumir porque o mouse escorregou);
--   2) a oferta sob o mouse;
--   3) a ÚLTIMA que ele olhou, marcada como "stale".
-- Escolha de design pro estado "sem hover" (pedido explícito): o painel NÃO
-- pisca vazio. Ele segura a última carta olhada com um rodapé discreto; o
-- estado neutro com instrução só aparece na ABERTURA, antes do 1º hover —
-- ali ele ensina em vez de mostrar um buraco.
function CardRewardScreen:_resolveDetailPayload()
    if self.mode ~= "shop" then
        self.detailPayload, self._lastDetailPayload = nil, nil
        return
    end

    local offer, inst, kind
    if self.selectedOffer then
        offer = self.selectedOffer
        kind = offerKind(offer)
        inst = offer.cardInstance
    elseif self.hoveredOffer then
        offer, inst, kind = self.hoveredOffer, self.hoveredInst, self.hoveredKind
    end

    if offer then
        self.detailPayload = { kind = kind or "card", offer = offer, instance = inst }
        self._lastDetailPayload = self.detailPayload
        self._detailStale = false
        self._detailPrefocus = false   -- o jogador assumiu o controle
    else
        self.detailPayload = self._lastDetailPayload
        self._detailStale = self._lastDetailPayload ~= nil
        -- Re-amarra a instância: createCardInstances() reconstrói tudo a cada
        -- compra, e a referência guardada viraria um objeto órfão.
        if self.detailPayload and self.detailPayload.offer then
            self.detailPayload.instance = self.detailPayload.offer.cardInstance
                or self.detailPayload.instance
        end
    end

    -- Oferta comprada não fica presa no painel (o slot dela virou VENDIDO) —
    -- mas o painel TAMBÉM não pode virar buraco preto depois de uma compra:
    -- re-foca a próxima oferta disponível. Só fica neutro se acabou o estoque.
    if self.detailPayload and self.detailPayload.offer
        and self.detailPayload.offer.purchased then
        self.detailPayload, self._lastDetailPayload = nil, nil
        self._detailStale = false
        self:_prefocusDetail()
        self.detailPayload = self._lastDetailPayload
        self._detailStale = self._lastDetailPayload ~= nil
    end

    -- Cross-fade curto quando o conteúdo troca (evita "corte seco" ao varrer
    -- o mouse pela grade). Instantâneo com reducedMotion. Deliberadamente NÃO
    -- usa EventManager: se a fila estiver pausada o painel ficaria parado em
    -- meio-fade — a legibilidade da loja não pode depender disso.
    local shown = self.detailPayload and self.detailPayload.offer or nil
    if shown ~= self._detailShownOffer then
        self._detailShownOffer = shown
        self._detailAnim = reducedMotion() and 1 or 0.5
    end
end

-- Retângulo onde os botões Comprar/Cancelar moram na LOJA: o rodapé do painel
-- de detalhe. Em "rewards" eles continuam colados embaixo da carta (aquele
-- modo não foi alvo da reclamação e não tem painel).
function CardRewardScreen:_selectionButtonsRect(idx)
    local btnH = 40
    local gap = 8
    if self.mode == "shop" and self.detailPanel then
        local dp = self.detailPanel
        local pad = 14
        local cancelW = btnH
        local buyW = math.max(70, dp.w - pad * 2 - cancelW - gap)
        return dp.x + pad, dp.y + dp.h - pad - btnH, buyW, cancelW, btnH, gap
    end

    local pos = self.cardPositions[idx or 0]
    if not pos then return nil end
    local pw = pos.w or self.cardWidth
    local ph = pos.h or self.cardHeight
    local offer = self.selectedOffer
    btnH = 38
    local buyLabel = (offer and (offer.cost or 0) > 0) and ("$" .. tostring(offer.cost))
        or I18n.t("common.take"):upper()
    local buyW = math.max(110, FontManager.getFont(12):getWidth(buyLabel) + 56)
    local cancelW = btnH
    local totalW = buyW + cancelW + gap
    return math.floor(pos.x + (pw - totalW) / 2),
           math.floor(pos.y + ph + (self.mode == "rewards" and 24 or 8)),
           buyW, cancelW, btnH, gap
end

function CardRewardScreen:drawInstructions()
    -- F1 do UI Overhaul: HintBar padronizada — SEMPRE cabe na tela (o texto
    -- antigo estourava dos dois lados e atropelava o botão Pular)
    local text = I18n.t("reward.instructions")
    if self.mode == "shop" then
        -- Split-view: o hint ensina a gramática nova (passar o mouse LÊ, o
        -- clique SELECIONA e a compra é confirmada no painel).
        text = I18n.t("reward.instructions_shop", nil,
            "Passe o mouse pra ler · CLIQUE seleciona · confirme no painel · DIREITO inspeciona")
    end
    HintBar.draw(text)
end

function CardRewardScreen:mousepressed(x, y, button)
    if not self.visible then return false end

    -- Inspeção aberta consome tudo (clique nas setas/fora fecha — igual Coleção).
    if self.inspectModal and self.inspectModal:isVisible() then
        self.inspectModal:mousepressed(x, y, button)
        return true
    end

    -- Clique DIREITO numa oferta → inspeção completa (mesma da Coleção).
    if button == 2 then
        for _, inst in ipairs(self.cardInstances or {}) do
            if inst and inst.isHovered and inst.shopOffer
                and not inst.shopOffer.purchased then
                self.inspectModal = self.inspectModal
                    or require("src.ui.CardInspectModal"):new()
                self.inspectModal:show(inst)
                return true
            end
        end
    end

    -- Selection buttons attached na carta selecionada têm prioridade —
    -- consomem o click antes dos cardButtons (que ficariam re-selecionando).
    if self._selectionButtons then
        for _, b in ipairs(self._selectionButtons) do
            if b:mousepressed(x, y, button) then return true end
        end
    end

    for _, cardButton in ipairs(self.cardButtons) do
        if cardButton:mousepressed(x, y, button) then
            return true
        end
    end

    if self.skipButton and self.skipButton:mousepressed(x, y, button) then
        return true
    end

    if self.refreshButton and self.refreshButton:mousepressed(x, y, button) then
        return true
    end

    -- Click fora de qualquer card/button enquanto há seleção → desselleciona
    -- (Balatro: re-clicar na mesma carta também alterna; aqui aceitamos ambos).
    if self.selectedOffer then
        self:clearSelection()
        return true
    end

    return false
end

function CardRewardScreen:mousereleased(x, y, button)
    if not self.visible then return false end

    -- Inspeção aberta: engole releases (nada atrás pode reagir).
    if self.inspectModal and self.inspectModal:isVisible() then
        return true
    end

    if self._selectionButtons then
        for _, b in ipairs(self._selectionButtons) do
            if b:mousereleased(x, y, button) then return true end
        end
    end

    for _, cardButton in ipairs(self.cardButtons) do
        if cardButton:mousereleased(x, y, button) then
            return true
        end
    end

    if self.skipButton and self.skipButton:mousereleased(x, y, button) then
        return true
    end

    if self.refreshButton and self.refreshButton:mousereleased(x, y, button) then
        return true
    end

    return false
end

-- drawRarityBorder removida em F10.1 (poluição visual). Cards agora não têm
-- halo pulsante de raridade. Se voltar a precisar, recriar dentro do CardFrame
-- como acabamento sutil de borda (não animação fullscreen).

function CardRewardScreen:isVisible()
    return self.visible
end

-- Desliza loja pra fora da tela (Fase 7.4 do refactor Balatro). Chamado quando
-- pack opening assume o foco. Padrão Balatro: shop fica off-screen embaixo
-- (não usa backdrop preto sobre ela).
function CardRewardScreen:slideOut()
    if not self.visible then return end
    local h = love.graphics.getHeight()
    EventManager.parallelEase(self, "slideOffsetY", h, 0.45, "smooth", FXQ)
end

-- Volta a loja pro lugar quando pack fecha.
function CardRewardScreen:slideIn()
    if not self.visible then return end
    EventManager.parallelEase(self, "slideOffsetY", 0, 0.45, "smooth", FXQ)
end

return CardRewardScreen
