-- components/RestScreen.lua
-- Descanso: escolhe entre curar 30% maxHP ou forjar (upgrade) uma carta do deck.
-- Forge: marca card com `upgraded` na run (runManager.currentRun.upgraded[cardId]++).
--
-- F4 do UI Overhaul (docs/plan/ui-ux-overhaul-v1.md): cena REAL de fogueira
-- (assets/sprites/scenes/path_rest.png) + painel grimório (Panel9) + duas
-- ESCOLHAS-CARTÃO grandes com preview do resultado (HP atual → resultante),
-- no lugar dos 2 botões soltos no vazio (tela nota D no levantamento).
--
-- BIGORNA v2 (Set/2026 — pedido do dono: "a tela de forjar mostrar as cartas
-- visualmente, ao confirmar ter uma animação, na hora de visualizar conseguir
-- ver as cartas ter o hover"). O picker deixou de ser uma grade de BOTÕES DE
-- TEXTO e passou a ser uma grade de CARTAS REAIS:
--   (a) instâncias de verdade (CardDatabase:createCardInstance + os upgrades
--       já aplicados) — a carta na bigorna é a carta que você joga;
--   (b) hover 3D do padrão reward (Card:updateMouse + draw(..., isRewardCard
--       = true): a carta SOBE, tilta e ganha sombra) + painel de bigorna
--       ancorado nela com o preview "ATQ 8 -> 10". O preview antigo (única
--       forma de saber o que a forja faz) NÃO sumiu: virou parte do hover;
--   (c) confirmar dispara a CERIMÔNIA DA BIGORNA — ver a seção grande mais
--       abaixo. Resumo: a carta sobe pra pose herói, leva TRÊS marteladas e o
--       upgrade acontece VISÍVEL numa placa de delta ("ATQ 8 -> 10", com o
--       valor antigo cedendo lugar ao novo em pop dourado). Referência de
--       intenção: a forja do Slay the Spire;
--   (d) overflow resolvido por PAGINAÇÃO (uma grade com scissor cortaria
--       sombra, lift e painel das cartas — paginar preserva o 3D inteiro).
--
-- Acessibilidade: com _G.gameSettings.reducedMotion a MUDANÇA DE VALOR continua
-- acontecendo e legível (a placa mostra o antes/depois, o "+2 ATQ" aparece) —
-- só o exagero some (marteladas, faíscas, flash, jiggle, pop de escala).
-- Informação de jogo nunca depende de juice.

local RestScreen = {}
RestScreen.__index = RestScreen

local FontManager     = require("src.ui.FontManager")
local Palette         = require("src.ui.Palette")
local Button          = require("components.Button")
local Panel9          = require("src.ui.Panel9")
local SceneBackground = require("src.ui.SceneBackground")
local IconLoader      = require("src.ui.IconLoader")
local CardDatabase    = require("src.systems.CardDatabase")
local I18n            = require("src.i18n.I18n")
local HintBar         = require("src.ui.HintBar")
local Sfx             = require("src.systems.Sfx")
local FloatingText    = require("src.ui.FloatingText")
local EventManager    = require("engine.EventManager")
local DissolveShader  = require("src.ui.DissolveShader")
local FlashShader     = require("src.ui.FlashShader")
local ImageCache      = require("src.ui.ImageCache")
local ParticlesManager = require("engine.ParticlesManager")
local Moveable        = require("engine.Moveable")

-- Dimensões lógicas do canvas de carta (CardFrame.WIDTH/HEIGHT).
local CARD_W, CARD_H = 96, 144

-- Fila dedicada pros beats da bigorna. Os primitivos do Card (start_dissolve)
-- empilham eventos BLOQUEANTES na fila default; agendar os nossos beats lá
-- dentro os deixaria reféns desse bloqueio. Mesmo motivo pelo qual a
-- CardRewardScreen tem a fila própria dela.
local FORGE_Q = "forge"

function RestScreen:new()
    local instance = setmetatable({}, RestScreen)
    instance.visible = false
    instance.game = nil
    instance.onClose = nil
    instance.mode = "choose" -- "choose" | "forge" | "remove" | "duplicate"
    instance.buttons = {}
    instance.cardList = {}    -- ids elegíveis (grimório inteiro)
    instance.cardEntries = {} -- {id, inst, level, x, y, w, h} da PÁGINA atual
    instance.page = 1
    instance.pageCount = 1
    instance.busy = false     -- cerimônia da bigorna rodando: trava o input
    instance.forge = nil      -- estado da cerimônia (pose herói + placa de delta)
    instance.resultText = nil
    instance.resultTimer = 0
    instance.choiceCards = {} -- {x,y,w,h,btn,icon,title,detail}
    return instance
end

-- Textos por modo de picker (forge = fogueira/loja; remove/duplicate = eventos).
-- Só os PREFIXOS de chave moram aqui — o texto vem do i18n a cada draw, senão
-- uma troca de idioma com a tela aberta não pegaria. Ver src/i18n/locales/*.lua
-- na seção `rest`.
local PICKER_KEYS = {
    forge     = "rest.pick_forge_",
    remove    = "rest.pick_remove_",
    duplicate = "rest.pick_dup_",
}

-- Resolve title/sub/hint/empty do modo atual. Retorna nil no modo "choose"
-- (a fogueira tem os textos dela).
local function pickerText(mode, part)
    local prefix = PICKER_KEYS[mode]
    if not prefix then return nil end
    return I18n.t(prefix .. part)
end

-- Rotulo do stat na placa de delta e nos textos de resultado. Reusa
-- card_type.* de proposito: assim a placa diz a MESMA palavra que o rodape da
-- propria carta (em alemao, ANGRIFF nos dois lugares). A placa MEDE o rotulo,
-- entao rotulo longo nao quebra o layout.
local STAT_KEY = {
    atk    = "card_type.attack",
    def    = "card_type.defense",
    effect = "card_type.effect",
}
local function statLabel(which)
    return I18n.t(STAT_KEY[which] or "card_type.unknown")
end

-- mode opcional: "choose" (default — fogueira: descansar OU forjar) |
-- "forge" | "remove" | "duplicate" (vai DIRETO ao picker de cartas — usado
-- pela oferta Forja da loja e pelos eventos, via _G.openCardPicker).
function RestScreen:show(game, onClose, mode)
    self.visible = true
    self.game = game
    self.onClose = onClose
    self.mode = mode or "choose"
    -- Picker direto (loja/evento): o "Voltar" FECHA a tela em vez de cair no
    -- menu da fogueira (que não é o contexto de origem).
    self._directPicker = (self.mode ~= "choose")
    self.resultText = nil
    self.resultTimer = 0
    self.busy = false
    self.forge = nil
    self.page = 1
    self._hoverIdx = nil
    if self._directPicker then
        self:enterForgeMode()
    else
        self:buildChooseButtons()
    end
end

function RestScreen:hide()
    self.visible = false
    -- Beats da bigorna que ainda não venceram morrem com a tela (a fila é só
    -- nossa). Os eventos dos primitivos do Card vivem na fila default e se
    -- resolvem sozinhos — não é nosso papel limpá-los.
    EventManager.clear(FORGE_Q)
    self.buttons = {}
    self.cardList = {}
    self.cardEntries = {}
    self.choiceCards = {}
    self.busy = false
    self.forge = nil
    self._hoverIdx = nil
end

function RestScreen:isVisible() return self.visible end

-- Resize handler: rebuilda os botões usando sw/sh atuais (cada modo tem o seu).
-- (Antes checava self.buildForgeButtons, que nunca existiu — resize em pleno
-- modo forge caía nos botões de "choose". Com os modos novos de picker o
-- rebuild correto é re-entrar na grade de cartas.)
-- Resize handler. Cobre TODO o estado derivado da janela que esta tela cacheia
-- (memory/ui_layout_invariants.md §2): métricas da grade, posições+escala das
-- cartas, paginação, botões de rodapé E a geometria da cerimônia da bigorna
-- (pose herói, placa de delta, decalques das marteladas).
--
-- Armadilha que isto evita (a mesma do PackOpenScreen): resize NÃO pode
-- "reposicionar do zero" enquanto há animação em curso. Aqui ele RECALCULA O
-- DESTINO — `_layoutPage(false)` reposiciona as instâncias EXISTENTES em vez
-- de recriá-las, então o dissolve do "remover" e a cerimônia da forja
-- continuam de onde estavam, só que na geometria nova.
function RestScreen:resize()
    if not self.visible then return end
    if self.mode == "choose" then
        self:buildChooseButtons()
    else
        self:_layoutPage(false)
    end
end

-- Geometria do painel central (compartilhada entre build e draw).
function RestScreen:panelRect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw, ph
    if self.mode ~= "choose" then
        -- Picker de CARTAS: precisa de muito mais área que o menu da fogueira
        -- (10 cartas de ~140×210 não cabem nos 680×560 antigos).
        pw = math.min(1000, math.floor(sw * 0.92))
        ph = math.min(720, math.floor(sh * 0.90))
    else
        pw = math.min(680, math.floor(sw * 0.72))
        ph = 420
    end
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2) + 10
    return px, py, pw, ph
end

function RestScreen:buildChooseButtons()
    self.buttons = {}
    self.choiceCards = {}
    local px, py, pw, ph = self:panelRect()

    -- Duas escolhas-cartão grandes dentro do painel
    local cw, chh = 250, 200
    local gap = 36
    local cy = py + 150
    local leftX = math.floor(px + pw / 2 - cw - gap / 2)
    local rightX = math.floor(px + pw / 2 + gap / 2)

    local p = self.game and self.game.player
    local healAmt = p and math.floor(p.maxHealth * 0.30) or 0
    local healTo = p and math.min(p.health + healAmt, p.maxHealth) or 0
    local healDetail = p
        and (I18n.t("rest.hp_abbr") .. " " .. p.health .. "/" .. p.maxHealth
             .. "  ->  " .. healTo .. "/" .. p.maxHealth)
        or ""

    local heal = {
        x = leftX, y = cy, w = cw, h = chh,
        icon = "heart", title = I18n.t("rest.heal_title"),
        sub = I18n.t("rest.heal_sub"),
        detail = healDetail,
    }
    heal.btn = Button:new(leftX, cy, cw, chh, "",
        function() self:doHeal() end)
    heal.btn:setVariant("invisible")

    local forge = {
        x = rightX, y = cy, w = cw, h = chh,
        icon = "rune", title = I18n.t("rest.forge_title"),
        sub = I18n.t("rest.forge_sub"),
        detail = I18n.t("rest.forge_detail"),
    }
    forge.btn = Button:new(rightX, cy, cw, chh, "",
        function() self:enterForgeMode() end)
    forge.btn:setVariant("invisible")

    self.choiceCards = { heal, forge }
    table.insert(self.buttons, heal.btn)
    table.insert(self.buttons, forge.btn)
end

function RestScreen:doHeal()
    local amt = math.floor(self.game.player.maxHealth * 0.30)
    self.game.player:heal(amt)
    self.resultText = I18n.t("rest.heal_result", { n = amt })
    self.resultTimer = 1.5
    self.buttons = {}
    self.choiceCards = {}
    Sfx.play("restComplete")

    -- A cura era a ÚNICA das três ações da fogueira sem celebração: a forja
    -- tem cerimônia de bigorna inteira e a remoção queima a carta, mas
    -- descansar só trocava um texto. Reusa exatamente o vocabulário que o
    -- combate já usa pra cura — número verde subindo e faíscas no jogador —
    -- em dose menor, porque aqui não há impacto pra justificar mais.
    Sfx.play("healShimmer", { pitch = 0.95, volume = 0.55 })

    local cx = love.graphics.getWidth() * 0.5
    local cy = love.graphics.getHeight() * 0.42
    FloatingText.spawn("+" .. amt .. " " .. I18n.t("rest.hp_abbr"), cx, cy,
        { kind = "heal", lift = 34 })

    local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
    if okCF and CardFeel.burst then
        CardFeel.burst("heal", cx, cy, 1.2)
    end
end

-- ===========================================================================
-- PICKER DE CARTAS (forge / remove / duplicate)
-- ===========================================================================

-- createCardInstance aponta instance.effects pra MESMA tabela do CardDatabase
-- (src/systems/CardDatabase.lua) e applyUpgradesToInstance soma em eff.value —
-- sem esta cópia, abrir a bigorna com uma carta de EFEITO forjada envenenaria
-- o catálogo (o valor cresceria a cada abertura de tela).
local function cloneEffects(inst)
    if not inst.effects then return end
    local copy = {}
    for i, eff in ipairs(inst.effects) do
        local c = {}
        for k, v in pairs(eff) do c[k] = v end
        copy[i] = c
    end
    inst.effects = copy
end

-- Instância de exibição da carta, com o nível de forja JÁ aplicado (mesmo
-- caminho do DeckViewerScreen: createCardInstance + applyUpgradesToInstance,
-- que também re-renderiza a moldura com os números novos e o selo +N).
function RestScreen:_makeInstance(cardId, level)
    local cd = CardDatabase:getCard(cardId)
    if not cd then return nil end
    local ok, inst = pcall(function() return CardDatabase:createCardInstance(cd) end)
    if not ok or not inst then return nil end
    if level and level > 0 and self.game and self.game.runManager
        and self.game.runManager.applyUpgradesToInstance then
        cloneEffects(inst)
        self.game.runManager:applyUpgradesToInstance(inst, level)
    end
    return inst
end

-- Área útil da grade dentro do painel (header em cima; rodapé com paginação
-- + Voltar embaixo).
function RestScreen:_gridRect()
    local px, py, pw, ph = self:panelRect()
    local gx = px + 30
    local gy = py + 112
    local gw = pw - 60
    local gh = math.max(150, ph - 112 - 126)
    return gx, gy, gw, gh
end

-- Geometria da grade: colunas/linhas e a escala de carta que cabe nelas.
-- Tudo derivado das dimensões ATUAIS da janela (nada hard-coded).
function RestScreen:_gridMetrics()
    local gx, gy, gw, gh = self:_gridRect()
    local n = #self.cardList
    local gapX, gapY = 18, 28

    local cols = 5
    if n > 0 and n < cols then cols = n end
    -- Janela estreita: nunca espreme a carta abaixo de ~74px de largura.
    local maxCols = math.max(2, math.floor((gw + gapX) / (74 + gapX)))
    cols = math.max(1, math.min(cols, maxCols))

    local rows = 2
    if n > 0 and n <= cols then rows = 1 end
    -- Janela baixa: se 2 linhas não cabem com carta legível, cai pra 1.
    if rows == 2 and ((gh - gapY) / 2) < 120 then rows = 1 end

    local cellW = (gw - gapX * (cols - 1)) / cols
    local cellH = (gh - gapY * (rows - 1)) / rows
    -- 1.6 = teto de escala (carta ~154×230). Sem teto, uma tela larga com
    -- poucas cartas geraria cartas gigantes e sem respiro pro hover.
    local scale = math.min(cellW / CARD_W, cellH / CARD_H, 1.6)

    return {
        gx = gx, gy = gy, gw = gw, gh = gh,
        cols = cols, rows = rows, gapX = gapX, gapY = gapY,
        scale = scale,
        cw = CARD_W * scale, ch = CARD_H * scale,
        perPage = cols * rows,
    }
end

-- (Re)constrói a lista de ids elegíveis + as instâncias da página atual.
function RestScreen:enterForgeMode()
    -- Só a FOGUEIRA (modo "choose") promove pra "forge". Sobrescrever o modo
    -- aqui era um bug: _G.openCardPicker("remove"/"duplicate") dos eventos
    -- caía em enterForgeMode e virava FORJA — o evento prometia remover uma
    -- carta e forjava outra.
    if self.mode == "choose" then self.mode = "forge" end
    self.choiceCards = {}
    self.cardList = {}
    self.page = 1
    self._anchorIdx = 1
    self.cardEntries = {}
    self._hoverIdx = nil

    local run = self.game and self.game.runManager
        and self.game.runManager.currentRun
    if not run then
        self.cardEntries = {}
        self:_buildFooterButtons()
        return
    end

    local seen = {}
    for _, entry in ipairs(run.currentDeck) do
        -- currentDeck guarda id string OU {id, edition, seal} (cartas de
        -- booster com edition/seal — RunManager:addCardToDeck). Normaliza pro
        -- id: forja/upgrade e display trabalham por id string.
        local id = type(entry) == "table" and entry.id or entry
        if id and not seen[id] then
            seen[id] = true
            -- No modo FORJA, só lista carta que a forja consegue melhorar
            -- (canUpgrade também barra cartas sem stat/effect upgradável).
            if self.mode ~= "forge"
                or self.game.runManager:canUpgrade(id) then
                table.insert(self.cardList, id)
            end
        end
    end

    self:_layoutPage(true)
end


-- Posições da grade pra `count` cartas: cada linha centrada, bloco todo
-- centrado na área da grade. Puro (só depende das métricas) — é o que permite
-- reposicionar sem recriar nada.
local function gridPositions(m, count)
    local pos = {}
    local rowsOnPage = math.max(1, math.ceil(count / m.cols))
    local totalH = rowsOnPage * m.ch + (rowsOnPage - 1) * m.gapY
    local startY = m.gy + math.floor((m.gh - totalH) / 2)
    local idx = 0
    for r = 0, rowsOnPage - 1 do
        local inRow = math.min(m.cols, count - r * m.cols)
        local totalW = inRow * m.cw + (inRow - 1) * m.gapX
        local startX = m.gx + math.floor((m.gw - totalW) / 2)
        for c = 0, inRow - 1 do
            idx = idx + 1
            pos[idx] = {
                x = math.floor(startX + c * (m.cw + m.gapX)),
                y = math.floor(startY + r * (m.ch + m.gapY)),
            }
        end
    end
    return pos
end

-- Aplica posição + escala da grade numa entry JÁ EXISTENTE. Não recria a
-- instância: é isto que faz um resize preservar dissolve/juice/cerimônia.
local function placeEntry(e, p, m)
    e.x, e.y, e.w, e.h = p.x, p.y, m.cw, m.ch
    local inst = e.inst
    if not inst then return end
    inst.x, inst.y = p.x, p.y
    -- Âncoras IMUTÁVEIS: Card:draw grava self.x/y a cada frame; o layout parte
    -- SEMPRE daqui (lição do feedback loop y+=entryOy da CardRewardScreen, que
    -- mandava as cartas pra fora da tela).
    inst.homeX, inst.homeY = p.x, p.y
    inst.layoutX, inst.layoutY = p.x, p.y
    inst.baseScale = m.scale
    inst.currentScale = m.scale
    inst.targetScale = m.scale
    -- Padrão REWARD (e não shop): a carta SOBE no hover. É a linguagem certa
    -- pra uma tela de ESCOLHA.
    inst.isRewardCard = true
    inst.noHoverLift = false
end

-- Cria as entries da fatia [first, first+count) da cardList.
function RestScreen:_makeEntries(first, count)
    local entries = {}
    local run = self.game and self.game.runManager
        and self.game.runManager.currentRun
    for i = 1, count do
        local cardId = self.cardList[first + i - 1]
        local level = (run and run.upgraded and run.upgraded[cardId]) or 0
        local inst = cardId and self:_makeInstance(cardId, level) or nil
        if inst then
            table.insert(entries, {
                id = cardId, inst = inst, level = level,
                x = 0, y = 0, w = 0, h = 0,
            })
        end
    end
    return entries
end

-- Calcula métricas e posiciona a página atual.
--   rebuild = true  → cria instâncias novas (entrar na tela, trocar de página)
--   rebuild = false → RESIZE: reposiciona as instâncias existentes; só cai em
--                     rebuild se a composição da página mudou de verdade.
function RestScreen:_layoutPage(rebuild)
    local m = self:_gridMetrics()
    local n = #self.cardList

    -- Animação em curso (cerimônia da bigorna, dissolve do "remover"): a
    -- composição da página fica CONGELADA. Trocar as instâncias no meio
    -- mataria a animação — reposicionar é o suficiente e é o que o
    -- "recalcular destino ≠ reposicionar do zero" pede.
    if self.busy or self.forge then
        local pos = gridPositions(m, #self.cardEntries)
        for i, e in ipairs(self.cardEntries) do
            if pos[i] then placeEntry(e, pos[i], m) end
        end
        if self.forge then self:_layoutForge(self.forge) end
        self:_buildFooterButtons()
        return
    end

    self.pageCount = math.max(1, math.ceil(n / m.perPage))
    if rebuild then
        self.page = math.max(1, math.min(self.pageCount, self.page))
    else
        -- Resize: mantém visível a MESMA carta que abria a página. Sem esta
        -- âncora, mudar o nº de colunas jogaria o jogador pra outra página
        -- (ou pro clamp da última) sem ele ter pedido nada.
        local anchor = self._anchorIdx or 1
        self.page = math.max(1, math.min(self.pageCount,
            math.floor((anchor - 1) / m.perPage) + 1))
    end

    local first = (self.page - 1) * m.perPage + 1
    local count = math.max(0, math.min(n, self.page * m.perPage) - first + 1)
    self._anchorIdx = first

    -- Reposicionar só serve se a página mostra exatamente as mesmas cartas.
    if not rebuild then
        local sameCount = (#self.cardEntries == count)
        local sameFirst = (count == 0)
            or (self.cardEntries[1] ~= nil
                and self.cardEntries[1].id == self.cardList[first])
        rebuild = not (sameCount and sameFirst)
    end

    self._hoverIdx = nil
    if rebuild then
        self.cardEntries = self:_makeEntries(first, count)
    end

    local pos = gridPositions(m, #self.cardEntries)
    for i, e in ipairs(self.cardEntries) do
        if pos[i] then placeEntry(e, pos[i], m) end
    end

    self:_buildFooterButtons()
end

function RestScreen:_buildFooterButtons()
    self.buttons = {}
    local px, py, pw, ph = self:panelRect()

    -- Paginação: overflow resolvido por página, não por scroll (um scissor
    -- cortaria sombra/lift/painel de hover das cartas).
    if self.pageCount > 1 then
        local by = py + ph - 104
        local prev = Button:new(math.floor(px + pw / 2 - 150), by, 110, 34,
            I18n.t("rest.page_prev"), function() self:_changePage(-1) end, nil, 10)
        local nxt = Button:new(math.floor(px + pw / 2 + 40), by, 110, 34,
            I18n.t("rest.page_next"), function() self:_changePage(1) end, nil, 10)
        if self.page <= 1 then prev:setEnabled(false) end
        if self.page >= self.pageCount then nxt:setEnabled(false) end
        table.insert(self.buttons, prev)
        table.insert(self.buttons, nxt)
    end

    -- Botao voltar (dentro do painel, rodapé). No picker direto (loja/evento)
    -- fecha e devolve o controle; na fogueira volta pro menu descansar/forjar.
    local back = Button:new(
        math.floor(px + pw / 2 - 80), py + ph - 60, 160, 40,
        I18n.t("common.back"),
        function()
            if self._directPicker then
                local cb = self.onClose
                self:hide()
                if cb then cb() end
            else
                self:show(self.game, self.onClose)
            end
        end
    )
    back:setIcon("x_close")
    table.insert(self.buttons, back)
end

function RestScreen:_changePage(delta)
    if self.busy then return end
    local target = self.page + delta
    if target < 1 or target > self.pageCount then return end
    self.page = target
    Sfx.play("menuHover")
    self:_layoutPage(true)
end

-- Despacho do picker: a MESMA grade de cartas serve pra forjar (fogueira/
-- loja), remover (eventos) e duplicar (eventos) — o modo decide a ação.
function RestScreen:_onPickCard(cardId)
    if self.busy then return end
    if self.mode == "remove" then
        self:doRemove(cardId)
    elseif self.mode == "duplicate" then
        self:doDuplicate(cardId)
    else
        self:doForge(cardId)
    end
end

-- Entrada visível da carta na página (nil se ela não está na página atual).
function RestScreen:_entryFor(cardId)
    for _, e in ipairs(self.cardEntries) do
        if e.id == cardId then return e end
    end
    return nil
end

-- Mostra o resultado por `hold` segundos e então fecha (update cuida).
function RestScreen:_finishWith(text, hold)
    self.resultText = text
    self.resultTimer = hold or 1.5
    self.buttons = {}
    self.busy = false
    self._hoverIdx = nil
end

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

-- Jiggle da tela (mesmo vocabulário do PackOpenScreen — a cinemática de pack
-- que roda de verdade no jogo). Silencioso com reducedMotion.
local function jiggle(amount)
    if reducedMotion() then return end
    if _G.jiggleScreen then _G.jiggleScreen(amount) end
end

local function flash(intensity, duration)
    if reducedMotion() then return end
    if FlashShader and FlashShader.trigger then
        FlashShader.trigger(intensity, duration)
    end
end

-- Toca o primeiro som REGISTRADO da lista (mesmo contrato dos sons-assinatura
-- de joker: registro por SCAN + fallback via Sfx.has). Enquanto
-- audio/sfx/forge-strike.mp3 não existir, cai no genérico e nada quebra.
--   playFirst({ "forgeStrike", "restComplete" }, { pitch = 1.05 })
local function playFirst(codes, opts)
    for _, code in ipairs(codes) do
        if Sfx.has(code) then
            Sfx.play(code, opts)
            return code
        end
    end
    return nil
end

function RestScreen:doRemove(cardId)
    if not self.game or not self.game.runManager then return end
    local run = self.game.runManager.currentRun
    -- Guarda: nunca deixar o deck abaixo de 2 cartas (o jogo precisa de mão).
    if not run or #run.currentDeck <= 2 then
        self:_finishWith(I18n.t("rest.remove_too_thin"), 1.5)
        return
    end
    local cd = CardDatabase:getCard(cardId)
    -- I18n.cardName e nao cd.name: o nome da carta no texto de resultado
    -- tem que sair no idioma do jogador, igual ao da moldura e do tooltip.
    local displayName = I18n.cardName(cd or cardId)
    self.game.runManager:removeCardFromDeck(cardId)
    if self.game.synchronizeRunDeck then self.game:synchronizeRunDeck() end
    Sfx.play("restComplete")

    local text = I18n.t("rest.removed", { name = displayName })
    local entry = self:_entryFor(cardId)
    if entry and entry.inst.start_dissolve and not reducedMotion() then
        -- A página arde: mesma linguagem da forja, sem o retorno. Paleta
        -- "exhaust" (preto/cinza) — isto não volta.
        self.busy = true
        self.buttons = {}
        self._hoverIdx = nil
        jiggle(0.4)
        entry.inst:start_dissolve(DissolveShader.palette("exhaust"),
            false, 0.6, false, function()
                self:_finishWith(text, 1.0)
            end)
    else
        self:_finishWith(text, 1.5)
    end
end

function RestScreen:doDuplicate(cardId)
    if not self.game or not self.game.runManager then return end
    local cd = CardDatabase:getCard(cardId)
    -- I18n.cardName e nao cd.name: o nome da carta no texto de resultado
    -- tem que sair no idioma do jogador, igual ao da moldura e do tooltip.
    local displayName = I18n.cardName(cd or cardId)
    self.game.runManager:addCardToDeck(cardId)
    if self.game.synchronizeRunDeck then self.game:synchronizeRunDeck() end
    Sfx.play("restComplete")

    local entry = self:_entryFor(cardId)
    if entry then
        entry.inst:juice_up(0.35, 0.1)
        FloatingText.spawn(I18n.t("rest.dup_popup"),
            math.floor(entry.x + entry.w / 2), math.floor(entry.y + 12),
            { kind = "buff" })
    end
    self:_finishWith(I18n.t("rest.duplicated", { name = displayName }), 1.5)
end

-- ---------------------------------------------------------------------------
-- CERIMÔNIA DA BIGORNA
-- ---------------------------------------------------------------------------
-- Pedido do dono: "uma animação da carta sendo upgradada, para que o upgrade
-- tenha algo VISÍVEL". O que ele quer ver não é uma transição — é a MUDANÇA DE
-- VALOR. Dissolve→materialize provava que "algo aconteceu"; não dizia O QUÊ.
--
-- REFERÊNCIA (Slay the Spire, estudo de intenção — zero cópia de código/asset;
-- fonte descompilada em E:\dev\projects\slay-the-spire-source):
--   · UpgradeShineEffect      → TRÊS marteladas em posições distintas ao redor
--                               da carta, cada uma com shake curto e forte;
--                               o som toca na primeira.
--   · UpgradeHammerImprintEffect → cada martelada deixa um decalque em rotação
--                               aleatória, additive, que expande e some.
--   · UpgradeShineParticleEffect → ~30 faíscas por martelada, com GRAVIDADE e
--                               quique no chão, cor laranja/ouro sorteada.
--   · ShowCardBrieflyEffect   → depois de forjar, a carta RESULTANTE é exibida
--                               grande no centro (drawScale 0.01 → 1.0). É
--                               assim que o StS torna o upgrade legível.
--
-- REIMPLEMENTAÇÃO AQUI (com as ferramentas deste projeto, e resolvendo o que o
-- StS não resolve — lá você compara de memória; aqui o delta é escrito):
--   Fase A · ANTECIPAÇÃO (0 → 0.34s): a carta escolhida sobe pra POSE HERÓI no
--     centro da grade, crescendo (o "mostrar grande" do ShowCardBriefly, só que
--     antes do golpe), `swell_up` armando, véu escurecendo o resto da grade.
--     A PLACA DE DELTA entra já mostrando os valores ATUAIS — o jogador lê o
--     "antes" antes de o martelo cair.
--   Fase B · IMPACTO ×3 (0.46 / 0.74 / 1.00): decalque + faíscas com gravidade
--     + jiggle + `forgeStrike` em pitch crescente, em três pontos distintos.
--       martelada 1 → aquece (só faísca)
--       martelada 2 → A VIRADA: a instância da carta troca pela forjada (a
--                     moldura re-renderiza com os números novos) E na placa o
--                     valor antigo cede (esmaece + encolhe) enquanto o novo
--                     entra em pop dourado branco-quente
--       martelada 3 → o SELO "+N" carimba
--   Fase C · ASSENTAMENTO (1.22 → 2.57s): brilho decai, a carta e a placa
--     ficam paradas e legíveis. Só então a tela fecha.
--
-- Só entram na placa os campos que getForgeGains (RunManager, fonte única)
-- diz que mudam — o que não mudou não compete por atenção.
--
-- reducedMotion: sem véu animado, sem marteladas, sem faíscas/flash/jiggle. A
-- pose herói e a placa aparecem prontas e A VIRADA ACONTECE IGUAL (só sem o
-- pop de escala). A informação do delta nunca depende do juice.

-- Timeline (segundos a partir do clique).
local FORGE_T = {
    lift   = 0.34,
    clang1 = 0.46,
    clang2 = 0.74,   -- A VIRADA
    clang3 = 1.00,   -- o selo
    settle = 1.22,
    hold   = 1.35,   -- leitura do delta antes de fechar
}

-- Posições das marteladas, em fração do bbox da carta herói (o StS usa três
-- offsets distintos justamente pra não parecer o mesmo golpe repetido).
local CLANG_AT = {
    { 0.16, 0.32 },
    { 0.78, 0.58 },
    { 0.46, 0.12 },
}

local SPARK_COLOURS = {
    { 1.00, 0.82, 0.35, 1 },
    { 1.00, 0.55, 0.12, 1 },
    { 1.00, 0.93, 0.72, 1 },
}

local PLATE_PAD = 14

-- Zera o estado de HOVER da carta. Necessário porque a cerimônia deixa de
-- chamar Card:updateMouse (que brigaria com a escala da pose herói) — e é o
-- updateMouse quem normalmente desfaz lift/tilt/warp. Sem isto a carta subiria
-- pro palco congelada na pose de hover: torta, deslocada e com o warp ligado.
local function clearHoverPose(inst)
    if not inst then return end
    inst.isHovered = false
    inst.liftOffset = 0
    inst.hoverBob = 0
    inst.hoverStrength = 0
    inst.offsetHoverX, inst.offsetHoverY = 0, 0
    inst.tiltX, inst.tiltY = 0, 0
    inst._velTilt = 0
    inst.perspectiveRotation = 0
    inst.shadowOffsetX, inst.shadowOffsetY = 0, 0
    inst.shadowScale = 0.9
end

-- Monta as linhas da placa a partir de getForgeGains. label/old/new prontos
-- pra desenhar + os campos animáveis (eased pelo EventManager).
function RestScreen:_buildForgeLines(cd, gains, lvl)
    local lines = {}
    local function add(label, old, new, delta, kind)
        table.insert(lines, {
            label = label,
            old = tostring(old), new = tostring(new), delta = delta, kind = kind,
            oldA = 1, oldS = 1, newA = 0, newS = 1, hot = 0,
        })
    end
    if gains.atk then
        local cur = (cd.attack or 0) + gains.atk * lvl
        add(statLabel("atk"), cur, cur + gains.atk, "+" .. gains.atk, "damage")
    end
    if gains.def then
        local cur = (cd.defense or 0) + gains.def * lvl
        add(statLabel("def"), cur, cur + gains.def, "+" .. gains.def, "armor")
    end
    if gains.effectIndex and cd.effects and cd.effects[gains.effectIndex] then
        local base = cd.effects[gains.effectIndex].value or 0
        local cur = base + gains.effect * lvl
        add(statLabel("effect"), cur, cur + gains.effect, "+" .. gains.effect, "buff")
    end
    -- Defensivo: canUpgrade barra carta sem ganho, então isto não deve
    -- acontecer — mas a placa nunca sai vazia.
    if #lines == 0 then
        add(I18n.t("rest.forge_level"), "+" .. lvl, "+" .. (lvl + 1), "+1", "buff")
    end
    return lines
end

-- Geometria da cerimônia: pose herói + placa, centradas como UM bloco na área
-- da grade. Responsivo (tudo derivado de _gridRect e da escala da grade).
-- Pose da carta = LERP adimensional entre o berço (posição/escala dela na
-- grade) e o palco (pose herói). Quem o EventManager anima é `f.pose` (0→1),
-- um número SEM unidade — por isso um resize no meio da subida só precisa
-- reescrever os dois extremos e a animação continua, sem pulo e sem reinício.
-- (Animar cx/cy/scale direto prenderia a ease a coordenadas da janela antiga.)
local function applyPose(f)
    local p = f.pose or 0
    f.cx = f.startX + (f.heroX - f.startX) * p
    f.cy = f.startY + (f.heroY - f.startY) * p
    f.scale = f.startScale + (f.heroScale - f.startScale) * p
end

-- GEOMETRIA da cerimônia — e SÓ geometria. Recalculável a qualquer momento
-- (é o que o resize chama), nunca toca no conteúdo nem no estado animado das
-- linhas (oldA/newA/newS/hot) nem em pose/veil/glow/stamp.
function RestScreen:_layoutForge(f)
    local gx, gy, gw, gh = self:_gridRect()

    -- Fontes re-medidas: love.resize roda FontManager.clearCache() ANTES de
    -- chamar a gente, então largura/altura precisam ser lidas de novo.
    local labelFont = FontManager.getFont(11)
    local numFont = FontManager.getFont(18)
    local arrowFont = FontManager.getFont(13)
    local stampFont = FontManager.getFont(20)

    local lblW, numW = 0, 0
    for _, ln in ipairs(f.lines) do
        lblW = math.max(lblW, labelFont:getWidth(ln.label))
        numW = math.max(numW, numFont:getWidth(ln.old), numFont:getWidth(ln.new))
    end
    local arrowW = arrowFont:getWidth("->")
    local innerW = lblW + 16 + numW + 14 + arrowW + 14 + numW
    local lineH = math.floor(numFont:getHeight() * 1.5)
    local stampH = math.floor(stampFont:getHeight() * 1.35)
    local plateW = innerW + PLATE_PAD * 2
    local plateH = PLATE_PAD * 2 + #f.lines * lineH + stampH

    -- Escala herói: a carta cresce, mas o bloco (carta + placa) tem que caber
    -- na área da grade com folga.
    local gridScale = (f.entry.w > 0) and (f.entry.w / CARD_W)
        or (f.entry.inst and f.entry.inst.baseScale) or 1
    local heroScale = math.min(2.0, gridScale * 1.35)
    local maxBlockH = gh - 12
    local blockGap = 14
    while heroScale > 0.75
        and (CARD_H * heroScale + blockGap + plateH) > maxBlockH do
        heroScale = heroScale - 0.05
    end
    local hw, hh = CARD_W * heroScale, CARD_H * heroScale
    local blockH = hh + blockGap + plateH
    local topY = gy + math.floor((gh - blockH) / 2)
    -- Janela muito baixa: encosta o bloco no topo da grade em vez de deixar a
    -- carta subir por cima do título.
    if topY < gy then topY = gy end

    f.heroX = gx + math.floor((gw - hw) / 2)
    f.heroY = topY
    f.heroScale = heroScale
    f.heroW, f.heroH = hw, hh

    -- Berço: de onde a carta sai (a posição dela NA GRADE, já reposicionada
    -- pelo _layoutPage quando isto vem de um resize).
    f.startX, f.startY = f.entry.x, f.entry.y
    f.startScale = gridScale

    f.plate = {
        x = gx + math.floor((gw - plateW) / 2),
        y = topY + hh + blockGap,
        w = plateW, h = plateH,
        lineH = lineH, stampH = stampH,
        lblX = PLATE_PAD,
        oldCx = PLATE_PAD + lblW + 16 + numW / 2,
        arrowCx = PLATE_PAD + lblW + 16 + numW + 7 + arrowW / 2,
        newCx = PLATE_PAD + lblW + 16 + numW + 14 + arrowW + 14 + numW / 2,
    }

    applyPose(f)
end

-- CONTEÚDO + estado animado da cerimônia. A geometria sai toda do
-- _layoutForge, pra que o resize possa refazê-la sem tocar nisto aqui.
function RestScreen:_buildForge(entry, cardId, cd, gains, newLvl, resultText)
    local f = {
        entry = entry, cardId = cardId, newLvl = newLvl, gains = gains,
        resultText = resultText,
        lines = self:_buildForgeLines(cd, gains, newLvl - 1),
        pose = 0,
        veil = 0, glow = 0, plateA = 0,
        stampA = 0, stampS = 1, stampText = "+" .. newLvl,
        clangs = {},
    }
    self:_layoutForge(f)
    return f
end

-- Uma martelada: decalque em rotação aleatória + faíscas com gravidade + som
-- em pitch crescente + jiggle. (RNG global: é cosmético, não decisão de run.)
function RestScreen:_clang(n)
    local f = self.forge
    if not f then return end
    local at = CLANG_AT[n] or CLANG_AT[1]
    local x = f.heroX + f.heroW * at[1]
    local y = f.heroY + f.heroH * at[2]

    playFirst({ "forgeStrike", "restComplete" },
        { pitch = 0.92 + (n - 1) * 0.09 })
    jiggle(n == 2 and 1.3 or 0.85)

    -- O decalque guarda a FRAÇÃO do bbox da carta, não a coordenada absoluta:
    -- assim um resize no meio da martelada o leva junto (coordenada absoluta
    -- ficaria órfã na geometria antiga). O x/y acima serve só pras faíscas,
    -- que são físicas e transitórias.
    local decal = {
        fx = at[1], fy = at[2],
        rot = love.math.random() * math.pi * 2,
        a = 0.85, s = 0.30,
    }
    table.insert(f.clangs, decal)
    EventManager.parallelEase(decal, "a", 0, 0.55, "smooth", FORGE_Q)
    -- "easeout" em minúsculas de propósito: o lookup de engine/Easing.lua é
    -- case-sensitive (byName só tem easeout/ease_out) e qualquer nome não
    -- resolvido cai calado em `smooth`.
    EventManager.parallelEase(decal, "s", 1.45, 0.55, "easeout", FORGE_Q)

    -- Faíscas: one-shot (pulse_max) com gravidade positiva — caem e somem,
    -- como respingo de forja.
    ParticlesManager.spawn(x - 5, y - 5, 10, 10, {
        fill = true,
        timer = 0.004,
        lifespan = 0.55,
        scale = 0.32,
        speed = 250,
        vel_variation = 1,
        gravity = 950,
        colours = SPARK_COLOURS,
        pulse_max = 26,
        max = 32,
        layer = 9,
    })
end

-- A VIRADA: a carta vira a forjada e, na placa, o valor antigo cede lugar ao
-- novo. É O beat do pedido — tudo o mais é moldura pra isto ser lido.
function RestScreen:_forgeTurn()
    local f = self.forge
    if not f then return end
    local reduced = reducedMotion()

    -- Carta: instância no nível novo. applyUpgradesToInstance re-renderiza a
    -- moldura, então o rodapé de stats da própria carta vira no MESMO frame
    -- que a placa — dois canais, um beat.
    local upgraded = self:_makeInstance(f.cardId, f.newLvl)
    if upgraded then
        upgraded.x, upgraded.y = f.cx, f.cy
        upgraded.homeX, upgraded.homeY = f.entry.x, f.entry.y
        upgraded.layoutX, upgraded.layoutY = f.entry.x, f.entry.y
        upgraded.baseScale = f.scale
        upgraded.currentScale = f.scale
        upgraded.targetScale = f.scale
        upgraded.isRewardCard = true
        clearHoverPose(upgraded)
        f.entry.inst = upgraded
        f.entry.level = f.newLvl
        if not reduced then upgraded:juice_up(0.4, 0.10) end
    end

    if not reduced then
        flash(0.32, 0.22)
        f.glow = 1
        EventManager.parallel(0.12, function()
            EventManager.parallelEase(f, "glow", 0, 0.95, "smooth", FORGE_Q)
        end, FORGE_Q)
    end

    local plate = f.plate
    -- Popup do delta AO LADO da placa. FloatingText desenha CENTRADO em x
    -- (FloatingText.lua:127, `-w * 0.5`), então somar só uma margem à borda
    -- direita da placa joga METADE do texto de volta por cima dela — e o que
    -- ficava coberto era justamente o número novo, o payload da cerimônia.
    -- Por isso medimos a linha mais larga e deslocamos por metade dela, com
    -- fontSize explícito pra medir com a MESMA fonte que o draw vai usar.
    local POP_FONT = 15
    local POP_GAP  = 18
    local popFont = FontManager.getFont(POP_FONT)
    local popHalf = 0
    for _, ln in ipairs(f.lines) do
        popHalf = math.max(popHalf, popFont:getWidth(ln.delta .. " " .. ln.label) * 0.5)
    end
    local popX = math.floor(plate.x + plate.w + POP_GAP + popHalf)
    if popX + popHalf > love.graphics.getWidth() - 12 then
        popX = math.floor(plate.x - POP_GAP - popHalf)   -- espelha pra esquerda
    end
    popX = math.max(math.floor(popHalf + 12), popX)      -- nunca sai da tela
    for i, ln in ipairs(f.lines) do
        local delay = (i - 1) * 0.07
        local popY = math.floor(plate.y + PLATE_PAD
            + (i - 1) * plate.lineH + plate.lineH / 2)
        if reduced then
            -- Mesmo estado FINAL, sem o trajeto: o novo valor já está lá,
            -- dourado, e o antigo já cedeu.
            ln.oldA, ln.oldS, ln.newA, ln.newS, ln.hot = 0.30, 0.82, 1, 1, 0
            FloatingText.spawn(ln.delta .. " " .. ln.label, popX, popY,
                { kind = ln.kind, hold = 0.8, fontSize = POP_FONT })
        else
            EventManager.parallel(delay, function()
                EventManager.parallelEase(ln, "oldA", 0.30, 0.22, "smooth", FORGE_Q)
                EventManager.parallelEase(ln, "oldS", 0.82, 0.22, "smooth", FORGE_Q)
                ln.newA = 1
                ln.newS = 2.1
                ln.hot = 1
                EventManager.parallelEase(ln, "newS", 1, 0.30, "easeout", FORGE_Q)
                EventManager.parallelEase(ln, "hot", 0, 0.80, "smooth", FORGE_Q)
                FloatingText.spawn(ln.delta .. " " .. ln.label, popX, popY,
                    { kind = ln.kind, hold = 0.6, fontSize = POP_FONT })
            end, FORGE_Q)
        end
    end
end

-- O selo "+N" carimba (o mesmo "+N" que o resto do jogo usa no label da carta;
-- entra como parte da coreografia, não do nada no fim).
function RestScreen:_forgeStamp()
    local f = self.forge
    if not f then return end
    f.stampA = 1
    if reducedMotion() then
        f.stampS = 1
        return
    end
    -- "backout": a escala passa de 1 e volta — o selo BATE e assenta, em vez
    -- de só encolher. (Minúsculas: ver nota do lookup de Easing no _clang.)
    f.stampS = 2.4
    EventManager.parallelEase(f, "stampS", 1, 0.30, "backout", FORGE_Q)
end

function RestScreen:doForge(cardId)
    if not self.game or not self.game.runManager then return end
    local cd = CardDatabase:getCard(cardId)
    -- I18n.cardName e nao cd.name: o nome da carta no texto de resultado
    -- tem que sair no idioma do jogador, igual ao da moldura e do tooltip.
    local displayName = I18n.cardName(cd or cardId)

    local RunManager = require("src.systems.RunManager")
    local gains = RunManager.getForgeGains(cd)

    local newLvl = self.game.runManager:upgradeCard(cardId)
    if not newLvl then
        -- Cap atingido (só acontece se Config.Game.UPGRADE_LEVEL_CAP > 0) —
        -- feedback ao jogador, sem consumir o nó (caller decide).
        self:_finishWith(I18n.t("rest.forge_capped", { name = displayName }), 1.0)
        return
    end

    -- Texto de resultado com os ganhos REAIS (fonte única getForgeGains —
    -- carta de ataque puro não anuncia DEF fantasma). Fica de reserva: quando
    -- a cerimônia roda, quem comunica é a placa.
    local parts = {}
    if gains.atk then
        table.insert(parts, "+" .. (gains.atk * newLvl) .. " " .. statLabel("atk"))
    end
    if gains.def then
        table.insert(parts, "+" .. (gains.def * newLvl) .. " " .. statLabel("def"))
    end
    if gains.effect then
        table.insert(parts, "+" .. (gains.effect * newLvl) .. " " .. statLabel("effect"))
    end
    local suffix = #parts > 0
        and ("  " .. I18n.t("rest.forged_gains",
            { parts = table.concat(parts, ", ") }))
        or ""
    local resultText = I18n.t("rest.forged",
        { name = displayName, lvl = newLvl }) .. suffix

    -- F4: Ferreiro-Mor (25 forjas acumuladas entre runs).
    require("src.systems.AchievementSystem").onForge(self.game)

    local entry = self:_entryFor(cardId)

    -- Sem carta visível na página (não deveria acontecer): caminho curto. A
    -- forja NUNCA depende da animação — o upgrade já está aplicado acima.
    if not entry or not cd then
        playFirst({ "forgeStrike", "restComplete" })
        self:_finishWith(resultText, 1.5)
        return
    end

    self.busy = true
    self.buttons = {}
    self._hoverIdx = nil

    local f = self:_buildForge(entry, cardId, cd, gains, newLvl, resultText)
    self.forge = f
    clearHoverPose(entry.inst)

    local reduced = reducedMotion()

    if reduced then
        -- Pose herói e placa prontas; a virada acontece logo, sem marteladas.
        f.pose = 1
        applyPose(f)
        f.veil, f.plateA = 1, 1
        EventManager.parallel(0.18, function()
            self:_forgeTurn()
            self:_forgeStamp()
        end, FORGE_Q)
        EventManager.parallel(0.18 + FORGE_T.hold, function()
            self:_finishWith(resultText, 0.01)
        end, FORGE_Q)
        return
    end

    -- Fase A — ANTECIPAÇÃO: a carta sobe pra pose herói e se arma. Quem é
    -- animado é a POSE (0→1, adimensional) — ver applyPose: é o que deixa a
    -- subida sobreviver a um resize no meio dela.
    EventManager.parallelEase(f, "pose", 1, FORGE_T.lift, "smooth", FORGE_Q)
    EventManager.parallelEase(f, "veil", 1, FORGE_T.lift, "smooth", FORGE_Q)
    EventManager.parallelEase(f, "plateA", 1, FORGE_T.lift * 1.2, "smooth", FORGE_Q)
    if entry.inst.swell_up then entry.inst:swell_up(0.10, FORGE_T.lift) end

    -- Fase B — IMPACTO ×3. A segunda é A VIRADA; a terceira carimba o selo.
    EventManager.parallel(FORGE_T.clang1, function() self:_clang(1) end, FORGE_Q)
    EventManager.parallel(FORGE_T.clang2, function()
        self:_clang(2)
        self:_forgeTurn()
    end, FORGE_Q)
    EventManager.parallel(FORGE_T.clang3, function()
        self:_clang(3)
        self:_forgeStamp()
    end, FORGE_Q)

    -- Fase C — ASSENTAMENTO: brilho decai, tudo fica parado e legível.
    EventManager.parallel(FORGE_T.settle, function()
        playFirst({ "forgeReveal" })
        local inst = f.entry.inst
        if inst and inst.juice_up then inst:juice_up(0.18, 0.04) end
    end, FORGE_Q)
    EventManager.parallel(FORGE_T.settle + FORGE_T.hold, function()
        self:_finishWith(resultText, 0.01)
    end, FORGE_Q)
end

-- Desenho da cerimônia. Ordem: véu → halo → carta herói → decalques das
-- marteladas → placa de delta → selo. (As faíscas são partículas globais,
-- desenhadas pelo main.lua por cima de tudo.)
function RestScreen:_drawForge(px, py, pw, ph)
    local f = self.forge
    if not f then return end

    -- Véu: isola a carta do resto da grade (o StS escurece a tela inteira
    -- durante a forja; aqui basta o painel, que é o palco).
    if (f.veil or 0) > 0 then
        love.graphics.setColor(0.05, 0.035, 0.02, 0.60 * f.veil)
        love.graphics.rectangle("fill", px, py, pw, ph)
    end

    local inst = f.entry.inst
    local cw = CARD_W * f.scale
    local chh = CARD_H * f.scale

    -- Halo de brasa atrás da carta, aceso na virada e decaindo.
    if (f.glow or 0) > 0.01 then
        love.graphics.setBlendMode("add")
        for i = 1, 4 do
            local pad = 6 + i * 9
            love.graphics.setColor(0.55, 0.36, 0.10, 0.16 * f.glow / i)
            love.graphics.rectangle("fill",
                f.cx - pad, f.cy - pad, cw + pad * 2, chh + pad * 2, pad * 0.5)
        end
        love.graphics.setBlendMode("alpha")
    end

    -- Carta herói. A escala vem da pose (não do hover) — por isso o update
    -- pula o updateMouse enquanto a cerimônia roda.
    if inst then
        inst.baseScale = f.scale
        inst.targetScale = f.scale
        inst.currentScale = f.scale
        inst.isHovered = false
        inst:draw(math.floor(f.cx), math.floor(f.cy), false, true)
    end

    -- Decalques das marteladas (additive, rotação aleatória, expandindo).
    local decalImg = ImageCache.get("assets/sprites/packs/effects/burst.png")
    if decalImg and decalImg:getWidth() > 1 then
        love.graphics.setBlendMode("add")
        local dw, dh = decalImg:getWidth(), decalImg:getHeight()
        for _, d in ipairs(f.clangs) do
            if (d.a or 0) > 0.01 then
                -- Resolve a fração AGORA, na geometria corrente (sobrevive a
                -- resize no meio da martelada).
                local dx = f.heroX + f.heroW * d.fx
                local dy = f.heroY + f.heroH * d.fy
                local s = (d.s or 0.3) * (cw / dw) * 1.1
                love.graphics.setColor(1, 0.86, 0.55, d.a)
                love.graphics.draw(decalImg, dx, dy, d.rot, s, s, dw / 2, dh / 2)
            end
        end
        love.graphics.setBlendMode("alpha")
    end

    self:_drawForgePlate()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Texto centrado num ponto, com escala (pra o pop do valor novo).
local function printCentered(font, text, cx, cy, scale)
    love.graphics.setFont(font)
    love.graphics.print(text, math.floor(cx), math.floor(cy), 0,
        scale, scale, font:getWidth(text) / 2, font:getHeight() / 2)
end

-- A PLACA DE DELTA: o payload do pedido. Uma linha por campo que a forja
-- muda (e só por esses). O valor antigo esmaece e encolhe; o novo entra
-- grande, branco-quente, e assenta em ouro.
function RestScreen:_drawForgePlate()
    local f = self.forge
    local p = f.plate
    local a = f.plateA or 0
    if a <= 0.01 then return end

    Panel9.draw("panel_inner", p.x, p.y, p.w, p.h, {
        fill = { 0.10, 0.08, 0.06, 0.95 * a },
    })

    local labelFont = FontManager.getFont(11)
    local numFont = FontManager.getFont(18)
    local arrowFont = FontManager.getFont(13)

    for i, ln in ipairs(f.lines) do
        local cy = p.y + PLATE_PAD + (i - 1) * p.lineH + p.lineH / 2

        love.graphics.setFont(labelFont)
        Palette.set(Palette.RUST, a)
        love.graphics.print(ln.label, math.floor(p.x + p.lblX),
            math.floor(cy - labelFont:getHeight() / 2))

        -- Valor ANTIGO: cede espaço (esmaece + encolhe) na virada.
        Palette.set(Palette.PARCHMENT, a * (ln.oldA or 1))
        printCentered(numFont, ln.old, p.x + p.oldCx, cy, ln.oldS or 1)

        Palette.set(Palette.AGED_GOLD_DARK, a * 0.9)
        printCentered(arrowFont, "->", p.x + p.arrowCx, cy, 1)

        -- Valor NOVO: só existe depois da virada. Branco-quente (`hot`) por
        -- um instante, depois ouro.
        if (ln.newA or 0) > 0.01 then
            local s = ln.newS or 1
            if (ln.hot or 0) > 0.01 then
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 0.95, 0.80, a * ln.hot * 0.85)
                printCentered(numFont, ln.new, p.x + p.newCx, cy, s * 1.12)
                love.graphics.setBlendMode("alpha")
            end
            Palette.set(Palette.AGED_GOLD_LIGHT, a * ln.newA)
            printCentered(numFont, ln.new, p.x + p.newCx, cy, s)
        end
    end

    -- Selo "+N" carimbado na terceira martelada.
    if (f.stampA or 0) > 0.01 then
        local stampFont = FontManager.getFont(20)
        local cy = p.y + PLATE_PAD + #f.lines * p.lineH + p.stampH / 2
        local cx = p.x + p.w / 2
        local s = f.stampS or 1
        if s > 1.02 then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(1, 0.92, 0.70, a * 0.5 * (s - 1))
            printCentered(stampFont, f.stampText, cx, cy, s * 1.15)
            love.graphics.setBlendMode("alpha")
        end
        Palette.set(Palette.AGED_GOLD_LIGHT, a * f.stampA)
        printCentered(stampFont, f.stampText, cx, cy, s)
    end
end

-- ---------------------------------------------------------------------------
-- PAINEL DE BIGORNA (hover)
-- ---------------------------------------------------------------------------
-- O preview "ATQ 8 -> 10" era a ÚNICA forma de saber o que a forja faz — não
-- podia sumir na troca de botões por cartas. Virou este painel ancorado na
-- carta em hover: nome + nível, os ganhos REAIS (getForgeGains, fonte única)
-- e a descrição. Nos modos remove/duplicate o painel explica a consequência.
local PANEL_MAX_INNER = 230
local PANEL_PAD = 12

function RestScreen:_hoverPanelContent(entry)
    local cd = CardDatabase:getCard(entry.id)
    local inst = entry.inst
    local I18n = require("src.i18n.I18n")
    local name = (inst and I18n.cardName and I18n.cardName(inst))
        or (cd and cd.name) or tostring(entry.id)
    if (entry.level or 0) > 0 then
        name = name .. " +" .. entry.level
    end

    local gainLines = {}
    if self.mode == "forge" and cd then
        local RunManager = require("src.systems.RunManager")
        local gains = RunManager.getForgeGains(cd)
        local lvl = entry.level or 0
        if gains.atk then
            local cur = (cd.attack or 0) + gains.atk * lvl
            table.insert(gainLines, statLabel("atk")
                .. "  " .. cur .. "  ->  " .. (cur + gains.atk))
        end
        if gains.def then
            local cur = (cd.defense or 0) + gains.def * lvl
            table.insert(gainLines, statLabel("def")
                .. "  " .. cur .. "  ->  " .. (cur + gains.def))
        end
        if gains.effectIndex and cd.effects and cd.effects[gains.effectIndex] then
            local base = cd.effects[gains.effectIndex].value or 0
            local cur = base + gains.effect * lvl
            table.insert(gainLines, statLabel("effect")
                .. "  " .. cur .. "  ->  " .. (cur + gains.effect))
        end
        table.insert(gainLines, I18n.t("rest.forge_level")
            .. "  +" .. lvl .. "  ->  +" .. (lvl + 1))
    elseif self.mode == "remove" then
        table.insert(gainLines, I18n.t("rest.warn_remove"))
    elseif self.mode == "duplicate" then
        table.insert(gainLines, I18n.t("rest.warn_dup"))
    end

    local desc = nil
    if inst and I18n.cardDesc then desc = I18n.cardDesc(inst) end
    if (not desc or desc == "") and cd then desc = cd.description end
    if desc == "" then desc = nil end

    return name, gainLines, desc
end

function RestScreen:_drawHoverPanel(entry)
    local name, gainLines, desc = self:_hoverPanelContent(entry)

    local nameFont = FontManager.getFont(12)
    local gainFont = FontManager.getFont(12)
    local descFont = FontManager.getFont(9)
    local nameLH = math.floor(nameFont:getHeight() * 1.2)
    local gainLH = math.floor(gainFont:getHeight() * 1.45)
    local descLH = math.floor(descFont:getHeight() * 1.35)

    -- MEDE tudo antes: a maior linha define a largura (nada vaza do painel —
    -- mesma disciplina do CardInfoDisplay v2).
    --
    -- PANEL_MAX_INNER e largura de QUEBRA, e vale so pro que quebra (nome e
    -- descricao). As linhas de GANHO ("VERTEID.  7  ->  9") sao atomicas: nao
    -- ha onde quebrar sem mentir. Aplicar o cap sobre elas nao encurtava a
    -- linha, so estreitava o painel — e o fim dela era CORTADO. Aparecia em
    -- alemao/espanhol, onde o rotulo do stat e longo (ANGRIFF, DEFENSA);
    -- em pt_BR "ATQ" cabia e o defeito ficava invisivel.
    local _, nameLines = nameFont:getWrap(name, PANEL_MAX_INNER)
    local descLines = {}
    if desc then _, descLines = descFont:getWrap(desc, PANEL_MAX_INNER) end

    local innerW = 150
    for _, l in ipairs(nameLines) do innerW = math.max(innerW, nameFont:getWidth(l)) end
    for _, l in ipairs(descLines) do innerW = math.max(innerW, descFont:getWidth(l)) end
    innerW = math.min(innerW, PANEL_MAX_INNER)
    -- Ganhos EMPURRAM o painel, com teto relativo a tela (nunca vira tarja).
    for _, l in ipairs(gainLines) do innerW = math.max(innerW, gainFont:getWidth(l)) end
    innerW = math.min(innerW,
        math.max(PANEL_MAX_INNER, love.graphics.getWidth() * 0.34))

    local panelH = PANEL_PAD
        + #nameLines * nameLH
        + ((#gainLines > 0) and (8 + #gainLines * gainLH) or 0)
        + ((#descLines > 0) and (8 + #descLines * descLH) or 0)
        + PANEL_PAD
    local panelW = innerW + PANEL_PAD * 2

    -- Posição: ao LADO da carta (direita por padrão; esquerda se não couber),
    -- clampada na tela.
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local panelX = entry.x + entry.w + 14
    if panelX + panelW > sw - 10 then panelX = entry.x - panelW - 14 end
    if panelX < 10 then panelX = 10 end
    local panelY = entry.y
    if panelY + panelH > sh - 10 then panelY = sh - 10 - panelH end
    if panelY < 10 then panelY = 10 end

    Panel9.draw("panel_inner", panelX, panelY, panelW, panelH, {
        fill = { 0.12, 0.095, 0.075, 0.96 },
    })

    local tx = panelX + PANEL_PAD
    local ty = panelY + PANEL_PAD

    love.graphics.setFont(nameFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    for _, l in ipairs(nameLines) do
        love.graphics.print(l, tx, ty)
        ty = ty + nameLH
    end

    if #gainLines > 0 then
        ty = ty + 4
        Palette.set(Palette.AGED_GOLD_DARK, 0.8)
        love.graphics.rectangle("fill", tx, ty, innerW, 1)
        ty = ty + 4
        love.graphics.setFont(gainFont)
        for _, l in ipairs(gainLines) do
            Palette.set(self.mode == "remove" and Palette.BLOOD
                or Palette.AGED_GOLD_LIGHT)
            love.graphics.print(l, tx, ty)
            ty = ty + gainLH
        end
    end

    if #descLines > 0 then
        ty = ty + 4
        Palette.set(Palette.AGED_GOLD_DARK, 0.6)
        love.graphics.rectangle("fill", tx, ty, innerW, 1)
        ty = ty + 4
        love.graphics.setFont(descFont)
        Palette.set(Palette.PARCHMENT)
        for _, l in ipairs(descLines) do
            love.graphics.print(l, tx, ty)
            ty = ty + descLH
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------

function RestScreen:update(dt)
    if not self.visible then return end
    for _, b in ipairs(self.buttons) do b:update(dt) end

    if self.forge then
        -- A pose é recomposta TODO frame a partir dos extremos correntes: o
        -- EventManager mexe só em `pose`, e um resize reescreve berço/palco.
        applyPose(self.forge)
        -- Sem updateMouse na cerimônia, ninguém tickaria os timers de
        -- juice/swell da carta herói (Card:updateMouse é quem chama
        -- updateJuice) — a antecipação ficaria inchada pra sempre e o kick da
        -- virada, travado.
        if self.forge.entry.inst then
            Moveable.updateJuice(self.forge.entry.inst, dt)
        end
    end

    -- Hover das cartas: UM alvo por frame. Os bboxes de cartas vizinhas se
    -- tocam (Card:updateMouse infla o bbox com a margem do lift) — deixar cada
    -- Card decidir sozinho acenderia duas ao mesmo tempo.
    --
    -- Durante a cerimônia o updateMouse é PULADO de propósito: ele faz o ease
    -- de currentScale rumo a targetScale e brigaria com a escala da pose herói
    -- (que é o próprio `forge.scale`, controlado pelo EventManager).
    if self.mode ~= "choose" and not self.forge then
        local mx, my = love.mouse.getPosition()
        local hoverIdx = nil
        if not self.busy and not self.resultText then
            for i = #self.cardEntries, 1, -1 do
                local e = self.cardEntries[i]
                if mx >= e.x and mx <= e.x + e.w
                    and my >= e.y - 12 and my <= e.y + e.h then
                    hoverIdx = i
                    break
                end
            end
        end
        for i, e in ipairs(self.cardEntries) do
            if e.inst and e.inst.updateMouse then
                e.inst:updateMouse(mx, my, dt, i == hoverIdx)
            end
        end
        self._hoverIdx = hoverIdx
    end

    if self.resultTimer > 0 then
        self.resultTimer = self.resultTimer - dt
        if self.resultTimer <= 0 then
            local cb = self.onClose
            self:hide()
            if cb then cb() end
        end
    end
end

-- Escolha-cartão: painel interno com ícone grande + título + detalhe.
-- Hover (via botão invisível) = levanta 4px + moldura dourada.
local function drawChoiceCard(c)
    local hover = c.btn and c.btn.hover
    local lift = hover and -4 or 0
    local y = c.y + lift

    Panel9.draw("panel_inner", c.x, y, c.w, c.h, {
        fill = hover and { 0.20, 0.15, 0.10, 0.94 }
            or { 0.12, 0.095, 0.075, 0.94 },
        tint = hover and { 1.15, 1.1, 0.85, 1 } or nil,
    })

    local icon = IconLoader.get(c.icon)
    if icon and icon.size then
        local s = 56 / icon.size.w
        icon.draw(math.floor(c.x + c.w / 2 - icon.size.w * s / 2), y + 26, s)
    end

    local tf = FontManager.getFont(16)
    love.graphics.setFont(tf)
    Palette.set(hover and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT)
    love.graphics.print(c.title,
        math.floor(c.x + c.w / 2 - tf:getWidth(c.title) / 2), y + 96)

    -- sub e detail com FIT na largura da carta (design system Jul/2026 —
    -- o detail da forja "+2 ATQ / +2 DEF por nivel..." vazava dos 250px).
    local TextFit = require("src.ui.TextFit")
    Palette.set(Palette.AGED_GOLD)
    TextFit.print(c.sub, c.x + 12, y + 126,
        { size = 10, maxW = c.w - 24, align = "center" })

    Palette.set(Palette.PARCHMENT)
    TextFit.print(c.detail, c.x + 12, y + 154,
        { size = 10, maxW = c.w - 24, align = "center" })
end

function RestScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- CENA REAL de fogueira (cover-fit + véu leve) — a tela antiga era um
    -- fundo pontilhado chapado com o gameplay vazando atrás.
    local drawn = SceneBackground.draw("path_rest", sw, sh, 0.35)
    if not drawn then
        love.graphics.setColor(0.07, 0.05, 0.04, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
    love.graphics.setColor(1, 1, 1, 1)

    local px, py, pw, ph = self:panelRect()
    Panel9.draw("panel_main", px, py, pw, ph)

    -- Título em INK sobre o pergaminho do painel (linguagem das cartas)
    local titleFont = FontManager.getFont(24)
    love.graphics.setFont(titleFont)
    Palette.set(Palette.INK)
    local title = pickerText(self.mode, "title") or I18n.t("rest.camp_title")
    love.graphics.print(title,
        math.floor(px + pw / 2 - titleFont:getWidth(title) / 2), py + 44)

    local subFont = FontManager.getFont(10)
    love.graphics.setFont(subFont)
    Palette.set(Palette.RUST)
    local sub = pickerText(self.mode, "sub") or I18n.t("rest.camp_sub")
    love.graphics.print(sub,
        math.floor(px + pw / 2 - subFont:getWidth(sub) / 2), py + 84)

    for _, c in ipairs(self.choiceCards) do drawChoiceCard(c) end

    -- Grade de CARTAS REAIS. A carta em hover desenha por ÚLTIMO pra que o
    -- lift/sombra/tilt dela fiquem por cima das vizinhas.
    if self.mode ~= "choose" then
        -- A carta em cerimônia sai da grade: quem desenha ela é _drawForge,
        -- por cima do véu e na pose herói.
        local forgeInst = self.forge and self.forge.entry.inst
        for i, e in ipairs(self.cardEntries) do
            if i ~= self._hoverIdx and e.inst and e.inst ~= forgeInst then
                e.inst:draw(e.x, e.y, false, true)
            end
        end
        local hoverEntry = self._hoverIdx and self.cardEntries[self._hoverIdx]
        if hoverEntry and hoverEntry.inst and hoverEntry.inst ~= forgeInst then
            hoverEntry.inst:draw(hoverEntry.x, hoverEntry.y, false, true)
        end

        -- Grimório sem cartas elegíveis: diz isso em vez de deixar o vazio.
        if #self.cardList == 0 then
            local ef = FontManager.getFont(13)
            love.graphics.setFont(ef)
            Palette.set(Palette.RUST)
            local msg = pickerText(self.mode, "empty")
                or I18n.t("rest.pick_forge_empty")
            love.graphics.print(msg,
                math.floor(px + pw / 2 - ef:getWidth(msg) / 2),
                math.floor(py + ph / 2 - 20))
        end

        -- Contador de página (só quando pagina).
        if self.pageCount > 1 then
            local pf = FontManager.getFont(11)
            love.graphics.setFont(pf)
            Palette.set(Palette.PARCHMENT_LIGHT)
            local ptxt = self.page .. " / " .. self.pageCount
            love.graphics.print(ptxt,
                math.floor(px + pw / 2 - pf:getWidth(ptxt) / 2), py + ph - 96)
        end
    end

    -- CERIMÔNIA DA BIGORNA: véu + pose herói + marteladas + placa de delta.
    -- Desenha DEPOIS da grade (cobre as vizinhas) e ANTES dos botões/hint.
    if self.forge then self:_drawForge(px, py, pw, ph) end

    for _, b in ipairs(self.buttons) do b:draw() end

    -- Painel de bigorna da carta sob o mouse (preview de ganho + descrição).
    if self.mode ~= "choose" and not self.resultText and not self.busy
        and not self.forge then
        local e = self._hoverIdx and self.cardEntries[self._hoverIdx]
        if e then self:_drawHoverPanel(e) end
    end

    -- Texto de resultado no rodapé: é a voz de curar/remover/duplicar. Na
    -- forja quem comunica é a PLACA — repetir embaixo só divide a atenção.
    if self.resultText and not self.forge then
        local rf = FontManager.getFont(14)
        love.graphics.setFont(rf)
        Palette.set(Palette.MOSS)
        love.graphics.print(self.resultText,
            math.floor(px + pw / 2 - rf:getWidth(self.resultText) / 2),
            py + ph - 96)
    end

    HintBar.draw(pickerText(self.mode, "hint") or I18n.t("rest.camp_hint"))

    love.graphics.setColor(1, 1, 1, 1)
end

function RestScreen:mousepressed(x, y, button) return self.visible end

function RestScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.busy then return true end

    -- Carta em hover tem prioridade sobre os botões de rodapé (não se
    -- sobrepõem, mas a ordem deixa a intenção explícita).
    local e = self._hoverIdx and self.cardEntries[self._hoverIdx]
    if e and not self.resultText then
        self:_onPickCard(e.id)
        return true
    end

    for _, b in ipairs(self.buttons) do
        if b.hover and not b.disabled then
            b.onClick()
            return true
        end
    end
    return false
end

function RestScreen:keypressed(key)
    if not self.visible or self.mode == "choose" or self.busy then return false end
    -- Paginação por teclado (setas) — o mesmo overflow, sem mouse.
    if key == "left" or key == "pageup" then
        self:_changePage(-1)
        return true
    elseif key == "right" or key == "pagedown" then
        self:_changePage(1)
        return true
    end
    return false
end

return RestScreen
