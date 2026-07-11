-- components/RestScreen.lua
-- Descanso: escolhe entre curar 30% maxHP ou forjar (upgrade) uma carta do deck.
-- Forge: marca card com `upgraded` na run (runManager.currentRun.upgraded[cardId]++).
--
-- F4 do UI Overhaul (docs/plan/ui-ux-overhaul-v1.md): cena REAL de fogueira
-- (assets/sprites/scenes/path_rest.png) + painel grimório (Panel9) + duas
-- ESCOLHAS-CARTÃO grandes com preview do resultado (HP atual → resultante),
-- no lugar dos 2 botões soltos no vazio (tela nota D no levantamento).

local RestScreen = {}
RestScreen.__index = RestScreen

local FontManager      = require("src.ui.FontManager")
local Palette          = require("src.ui.Palette")
local Button           = require("components.Button")
local Panel9           = require("src.ui.Panel9")
local SceneBackground  = require("src.ui.SceneBackground")
local IconLoader       = require("src.ui.IconLoader")
local CardDatabase     = require("src.systems.CardDatabase")
local HintBar          = require("src.ui.HintBar")
local Sfx              = require("src.systems.Sfx")

function RestScreen:new()
    local instance = setmetatable({}, RestScreen)
    instance.visible = false
    instance.game = nil
    instance.onClose = nil
    instance.mode = "choose" -- "choose" | "forge"
    instance.buttons = {}
    instance.cardList = {}
    instance.resultText = nil
    instance.resultTimer = 0
    instance.choiceCards = {}   -- {x,y,w,h,btn,icon,title,detail}
    return instance
end

-- Textos por modo de picker (forge = fogueira/loja; remove/duplicate = eventos).
local PICKER_TEXTS = {
    forge = {
        title = "Forjar",
        sub = "Escolha uma carta para aprimorar.",
        hint = "Clique numa carta para forjar · Voltar cancela",
    },
    remove = {
        title = "Remover carta",
        sub = "Escolha uma carta para REMOVER do grimorio (permanente).",
        hint = "Clique numa carta para remover · Voltar cancela",
    },
    duplicate = {
        title = "Duplicar carta",
        sub = "Escolha uma carta para ganhar uma COPIA dela.",
        hint = "Clique numa carta para duplicar · Voltar cancela",
    },
}

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
    if self._directPicker then
        self:enterForgeMode()
    else
        self:buildChooseButtons()
    end
end

function RestScreen:hide()
    self.visible = false
    self.buttons = {}
    self.cardList = {}
    self.choiceCards = {}
end

function RestScreen:isVisible() return self.visible end

-- Resize handler: rebuilda os botões usando sw/sh atuais (cada modo tem o seu).
-- (Antes checava self.buildForgeButtons, que nunca existiu — resize em pleno
-- modo forge caía nos botões de "choose". Com os modos novos de picker o
-- rebuild correto é re-entrar na grade de cartas.)
function RestScreen:resize()
    if not self.visible then return end
    if self.mode ~= "choose" then
        self:enterForgeMode()
    else
        self:buildChooseButtons()
    end
end

-- Geometria do painel central (compartilhada entre build e draw).
function RestScreen:panelRect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw = math.min(680, math.floor(sw * 0.72))
    local ph = (self.mode ~= "choose")
        and math.min(560, math.floor(sh * 0.78))
        or 420
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
        and ("HP " .. p.health .. "/" .. p.maxHealth
             .. "  ->  " .. healTo .. "/" .. p.maxHealth)
        or ""

    local heal = {
        x = leftX, y = cy, w = cw, h = chh,
        icon = "heart", title = "Descansar",
        sub = "+30% HP",
        detail = healDetail,
    }
    heal.btn = Button:new(leftX, cy, cw, chh, "",
        function() self:doHeal() end)
    heal.btn:setVariant("invisible")

    local forge = {
        x = rightX, y = cy, w = cw, h = chh,
        icon = "rune", title = "Forjar",
        sub = "+1 nivel em uma carta",
        detail = "Melhora o que a carta TEM (sem limite)",
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
    self.resultText = "Curou " .. amt .. " HP."
    self.resultTimer = 1.5
    self.buttons = {}
    self.choiceCards = {}
    Sfx.play("restComplete")
end

function RestScreen:enterForgeMode()
    self.mode = "forge"
    self.buttons = {}
    self.choiceCards = {}
    self.cardList = {}
    local run = self.game.runManager.currentRun
    if not run then return end
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

    local px, py, pw, ph = self:panelRect()
    local perRow = 3
    local gutter = 10
    local innerX = px + 36
    local innerW = pw - 72
    local btnW = math.floor((innerW - gutter * (perRow - 1)) / perRow)
    local btnH = 42
    local startY = py + 130

    for i, cardId in ipairs(self.cardList) do
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local x = innerX + col * (btnW + gutter)
        local y = startY + row * (btnH + 8)
        local upgraded = run.upgraded and run.upgraded[cardId] or 0
        -- nome de exibição da carta (o id cru era ilegível — F4)
        local cd = CardDatabase:getCard(cardId)
        local label = (cd and cd.name or cardId)
            .. (upgraded > 0 and (" +" .. upgraded) or "")
        local btn = Button:new(x, y, btnW, btnH, label, function()
            self:_onPickCard(cardId)
        end, nil, 9)
        -- Preview de forja no hover (drawForgePreview lê _cardId do botão).
        btn._cardId = cardId
        table.insert(self.buttons, btn)
    end

    -- Botao voltar (dentro do painel, rodapé). No picker direto (loja/evento)
    -- fecha e devolve o controle; na fogueira volta pro menu descansar/forjar.
    local back = Button:new(
        math.floor(px + pw / 2 - 80), py + ph - 60, 160, 40,
        require("src.i18n.I18n").t("common.back"),
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

-- Despacho do picker: a MESMA grade de cartas serve pra forjar (fogueira/
-- loja), remover (eventos) e duplicar (eventos) — o modo decide a ação.
function RestScreen:_onPickCard(cardId)
    if self.mode == "remove" then
        self:doRemove(cardId)
    elseif self.mode == "duplicate" then
        self:doDuplicate(cardId)
    else
        self:doForge(cardId)
    end
end

function RestScreen:doRemove(cardId)
    if not self.game or not self.game.runManager then return end
    local run = self.game.runManager.currentRun
    -- Guarda: nunca deixar o deck abaixo de 2 cartas (o jogo precisa de mão).
    if not run or #run.currentDeck <= 2 then
        self.resultText = "O grimorio esta magro demais para perder paginas."
        self.resultTimer = 1.5
        self.buttons = {}
        return
    end
    local cd = CardDatabase:getCard(cardId)
    local displayName = (cd and cd.name) or cardId
    self.game.runManager:removeCardFromDeck(cardId)
    if self.game.synchronizeRunDeck then self.game:synchronizeRunDeck() end
    self.resultText = "Removida do grimorio: " .. displayName
    self.resultTimer = 1.5
    self.buttons = {}
    Sfx.play("restComplete")
end

function RestScreen:doDuplicate(cardId)
    if not self.game or not self.game.runManager then return end
    local cd = CardDatabase:getCard(cardId)
    local displayName = (cd and cd.name) or cardId
    self.game.runManager:addCardToDeck(cardId)
    if self.game.synchronizeRunDeck then self.game:synchronizeRunDeck() end
    self.resultText = "Copia criada: " .. displayName
    self.resultTimer = 1.5
    self.buttons = {}
    Sfx.play("restComplete")
end

function RestScreen:doForge(cardId)
    if not self.game or not self.game.runManager then return end
    local cd = CardDatabase:getCard(cardId)
    local displayName = (cd and cd.name) or cardId
    local newLvl = self.game.runManager:upgradeCard(cardId)
    if not newLvl then
        -- Cap atingido (só acontece se Config.Game.UPGRADE_LEVEL_CAP > 0) —
        -- feedback ao jogador, sem consumir o nó (caller decide).
        self.resultText = "Já no nível máximo: " .. displayName
        self.resultTimer = 1.0
        self.buttons = {}
        return
    end
    -- Resultado com os ganhos REAIS da carta (fonte única getForgeGains —
    -- carta de ataque puro não anuncia mais DEF fantasma).
    local RunManager = require("src.systems.RunManager")
    local gains = RunManager.getForgeGains(cd)
    local parts = {}
    if gains.atk then table.insert(parts, "+" .. (gains.atk * newLvl) .. " ATQ") end
    if gains.def then table.insert(parts, "+" .. (gains.def * newLvl) .. " DEF") end
    if gains.effect then table.insert(parts, "+" .. (gains.effect * newLvl) .. " efeito") end
    local suffix = #parts > 0 and ("  (" .. table.concat(parts, ", ") .. " no total)") or ""
    self.resultText = "Forjou: " .. displayName .. " +" .. newLvl .. suffix
    self.resultTimer = 1.5
    self.buttons = {}
    Sfx.play("restComplete")
    -- F4: Ferreiro-Mor (25 forjas acumuladas entre runs).
    require("src.systems.AchievementSystem").onForge(self.game)
end

-- Linha de preview da forja: aparece quando um botão de carta está em hover.
-- "ATQ 8 → 10 · DEF 4 → 6" com os valores REAIS da carta (base + nível atual
-- → base + nível+1), a mesma matemática do applyUpgradesToInstance.
function RestScreen:drawForgePreview(px, py, pw, ph)
    local hovered = nil
    for _, b in ipairs(self.buttons) do
        if b.hover and b._cardId then hovered = b._cardId; break end
    end
    if not hovered then return end

    local cd = CardDatabase:getCard(hovered)
    if not cd then return end
    local RunManager = require("src.systems.RunManager")
    local gains = RunManager.getForgeGains(cd)
    local run = self.game.runManager.currentRun
    local lvl = (run and run.upgraded and run.upgraded[hovered]) or 0

    local parts = {}
    if gains.atk then
        local cur = cd.attack + gains.atk * lvl
        table.insert(parts, "ATQ " .. cur .. " -> " .. (cur + gains.atk))
    end
    if gains.def then
        local cur = cd.defense + gains.def * lvl
        table.insert(parts, "DEF " .. cur .. " -> " .. (cur + gains.def))
    end
    if gains.effectIndex and cd.effects and cd.effects[gains.effectIndex] then
        local base = cd.effects[gains.effectIndex].value or 0
        local cur = base + gains.effect * lvl
        table.insert(parts, "EFEITO " .. cur .. " -> " .. (cur + gains.effect))
    end
    if #parts == 0 then
        table.insert(parts, "+1 nivel de forja")
    end
    local text = table.concat(parts, "  ·  ")

    local f = FontManager.getFont(12)
    love.graphics.setFont(f)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(text,
        math.floor(px + pw / 2 - f:getWidth(text) / 2), py + ph - 92)
end

function RestScreen:update(dt)
    if not self.visible then return end
    for _, b in ipairs(self.buttons) do b:update(dt) end
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
    local texts = PICKER_TEXTS[self.mode]
    local title = (texts and texts.title) or "Acampamento"
    love.graphics.print(title,
        math.floor(px + pw / 2 - titleFont:getWidth(title) / 2), py + 44)

    local subFont = FontManager.getFont(10)
    love.graphics.setFont(subFont)
    Palette.set(Palette.RUST)
    local sub = (texts and texts.sub)
        or "A fogueira crepita. Recupere o folego ou trabalhe o aco."
    love.graphics.print(sub,
        math.floor(px + pw / 2 - subFont:getWidth(sub) / 2), py + 84)

    for _, c in ipairs(self.choiceCards) do drawChoiceCard(c) end
    for _, b in ipairs(self.buttons) do b:draw() end

    -- Preview "ATQ 8 → 10" da carta sob o mouse (modo forge).
    if self.mode == "forge" and not self.resultText then
        self:drawForgePreview(px, py, pw, ph)
    end

    if self.resultText then
        local rf = FontManager.getFont(14)
        love.graphics.setFont(rf)
        Palette.set(Palette.MOSS)
        love.graphics.print(self.resultText,
            math.floor(px + pw / 2 - rf:getWidth(self.resultText) / 2),
            py + ph - 96)
    end

    local hintTexts = PICKER_TEXTS[self.mode]
    HintBar.draw((hintTexts and hintTexts.hint)
        or "Escolha: descansar OU forjar (uma vez por acampamento)")

    love.graphics.setColor(1, 1, 1, 1)
end

function RestScreen:mousepressed(x, y, button) return self.visible end

function RestScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    for _, b in ipairs(self.buttons) do
        if b.hover and not b.disabled then
            b.onClick()
            return true
        end
    end
    return false
end

function RestScreen:keypressed(key)
    return false
end

return RestScreen
