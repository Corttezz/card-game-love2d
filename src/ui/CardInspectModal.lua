-- src/ui/CardInspectModal.lua
-- Modal de INSPEÇÃO de carta (carta grande com warp 3D + painel lateral com
-- nome/tipo/classe/raridade/stats/descrição/efeitos), navegável por setas.
-- Extraído do drawInspectModal da CollectionScreen (Jul/2026) pra ser
-- COMPARTILHADO — o Deck Viewer da run abre a MESMA visão ao clicar numa carta,
-- ficando idêntico à aba de Coleção do menu (pedido do Daniel).
--
-- Uso:
--   modal = CardInspectModal:new()
--   modal:show(instance, list, index)   -- list/index opcionais (setas navegam)
--   modal:update(dt); modal:draw()
--   modal:mousepressed(x,y,b) / :keypressed(key)   -- consomem enquanto aberto
--
-- Instância deve ter .image (canvas do CardFrame). Se vier com forja aplicada,
-- os stats/gemas já refletem isso (o Deck Viewer passa instâncias upgradadas).

local CardInspectModal = {}
CardInspectModal.__index = CardInspectModal

local FontManager         = require("src.ui.FontManager")
local Palette             = require("src.ui.Palette")
local CardMesh            = require("src.ui.CardMesh")
local CardArt             = require("src.ui.CardArt")
local CardAnimationLayer  = require("src.ui.card.CardAnimationLayer")
local I18n                = require("src.i18n.I18n")
local Sfx                 = require("src.systems.Sfx")

function CardInspectModal:new()
    local self = setmetatable({}, CardInspectModal)
    self.card = nil      -- instância inspecionada (nil = fechado)
    self.list = nil      -- lista pra navegar com setas (opcional)
    self.index = nil     -- índice atual em list
    self.anim = 0        -- 0..1 (fade/zoom in)
    self.last = nil      -- última carta (pra desenhar durante o fade-out)
    return self
end

function CardInspectModal:show(card, list, index)
    self.card = card
    self.list = list
    self.index = index
    self.anim = 0
    Sfx.play("collectionFlip")
end

function CardInspectModal:hide()
    if self.card then Sfx.play("menuClose") end
    self.card = nil
end

function CardInspectModal:isVisible() return self.card ~= nil end

function CardInspectModal:_neighbor(delta)
    if not self.list or not self.index then return end
    local n = #self.list
    if n <= 1 then return end
    self.index = ((self.index - 1 + delta) % n) + 1
    self.card = self.list[self.index]
    self.anim = 0.3   -- leve "pop" ao trocar
end

function CardInspectModal:update(dt)
    if self.card then
        self.anim = math.min(1, self.anim + dt * 6)
    else
        self.anim = math.max(0, self.anim - dt * 8)
    end
end

function CardInspectModal:keypressed(key)
    if not self.card then return false end
    if key == "escape" or key == "space" or key == "return" then
        self:hide()
    elseif key == "left" or key == "a" then
        Sfx.play("collectionFlip"); self:_neighbor(-1)
    elseif key == "right" or key == "d" then
        Sfx.play("collectionFlip"); self:_neighbor(1)
    end
    return true
end

-- Mesma geometria da CollectionScreen pra clique nas setas / fora fechar.
function CardInspectModal:mousepressed(x, y, button)
    if not self.card then return false end
    if button ~= 1 then return true end
    local w, h = love.graphics.getDimensions()
    local cardW, cardH = 384, 576
    local cardX = (w - cardW) / 2 - 140
    local cardY = (h - cardH) / 2
    local arrowY = h / 2 - 30
    -- seta esquerda
    if x >= 20 and x <= 100 and y >= arrowY and y <= arrowY + 60 then
        Sfx.play("collectionFlip"); self:_neighbor(-1); return true
    end
    -- seta direita
    if x >= w - 100 and x <= w - 20 and y >= arrowY and y <= arrowY + 60 then
        Sfx.play("collectionFlip"); self:_neighbor(1); return true
    end
    -- clique em qualquer outro lugar fecha
    if x < cardX or x > cardX + cardW + 320 or y < cardY - 20 or y > cardY + cardH + 20 then
        self:hide()
    end
    return true
end

function CardInspectModal:mousereleased(x, y, button)
    return self.card ~= nil   -- consome enquanto aberto
end

local function drawArrows(self, width, height)
    if not self.list or #self.list <= 1 then return end
    local arrowY = height / 2 - 30
    local t = love.timer.getTime()
    local pulse = 0.7 + math.sin(t * 3) * 0.2
    local arrowFont = FontManager.getFont(48)
    love.graphics.setFont(arrowFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2],
        Palette.AGED_GOLD_LIGHT[3], pulse)
    love.graphics.print("‹", 40, arrowY)
    love.graphics.print("›", width - 80, arrowY)
end

function CardInspectModal:draw()
    if not self.card and self.anim <= 0 then return end
    local inst = self.card or self.last
    if not inst then return end
    self.last = inst

    local width, height = love.graphics.getDimensions()
    local anim = self.anim

    -- Backdrop escurecido
    love.graphics.setColor(0, 0, 0, 0.82 * anim)
    love.graphics.rectangle("fill", 0, 0, width, height)

    -- Carta em escala grande (4x = 384×576)
    local scale = 4 * (0.85 + 0.15 * anim)
    local cardW = 96 * scale
    local cardH = 144 * scale
    local cardX = (width - cardW) / 2 - 140  -- desloca pra esquerda pra caber painel
    local cardY = (height - cardH) / 2

    if inst.image then
        local mx, my = love.mouse.getPosition()
        local cx = cardX + cardW / 2
        local cy = cardY + cardH / 2
        local uvx = (mx - cx) / (cardW / 2)
        local uvy = (my - cy) / (cardH / 2)
        if uvx > 1 then uvx = 1 elseif uvx < -1 then uvx = -1 end
        if uvy > 1 then uvy = 1 elseif uvy < -1 then uvy = -1 end
        local uvInside = math.abs(uvx) < 1.05 and math.abs(uvy) < 1.05
        local mouseUV = uvInside and { uvx, uvy } or { 0, 0 }
        local hoverStrength = uvInside and anim or 0

        local shadowPressShift = 40
        local dirX = (cx - width / 2) / (width / 2)
        if dirX > 1 then dirX = 1 elseif dirX < -1 then dirX = -1 end
        local shDx = -dirX * 30 - uvx * shadowPressShift * hoverStrength
        local shDy = 16 - uvy * shadowPressShift * hoverStrength * 0.7

        local shader = CardMesh.getShader()
        local timeNow = love.timer.getTime()
        if shader then
            local mesh = CardMesh.getMesh(inst.image:getWidth(), inst.image:getHeight())
            mesh:setTexture(inst.image)
            love.graphics.setShader(shader)
            CardMesh.setUniforms(shader, mouseUV, hoverStrength, timeNow, inst.image)
            love.graphics.setColor(0, 0, 0, 0.55 * anim)
            love.graphics.draw(mesh, cardX + shDx, cardY + shDy, 0, scale, scale)
            love.graphics.setColor(1, 1, 1, anim)
            love.graphics.draw(mesh, cardX, cardY, 0, scale, scale)
            love.graphics.setShader()
        else
            love.graphics.setColor(0, 0, 0, 0.55 * anim)
            love.graphics.draw(inst.image, cardX + shDx, cardY + shDy, 0, scale, scale)
            love.graphics.setColor(1, 1, 1, anim)
            love.graphics.draw(inst.image, cardX, cardY, 0, scale, scale)
        end

        if not inst._cachedArt then
            local ok, a = pcall(CardArt.resolve, inst)
            inst._cachedArt = ok and a or { bgPattern = nil }
        end
        CardAnimationLayer.draw(inst, inst._cachedArt, cardX, cardY, scale, scale)
    end

    -- Painel lateral com info detalhada
    local panelX = cardX + cardW + 30
    local panelY = cardY
    local panelW = 340
    local panelH = cardH
    local PAD = 16
    local TEXT_W = panelW - PAD * 2

    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.92 * anim)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], anim)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH)
    love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2], Palette.AGED_GOLD_DARK[3], anim)
    love.graphics.rectangle("line", panelX + 2, panelY + 2, panelW - 4, panelH - 4)

    local nameFont = FontManager.getFont(16)
    love.graphics.setFont(nameFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], anim)
    love.graphics.printf(I18n.cardName(inst), panelX + PAD, panelY + 18, TEXT_W)

    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6 * anim)
    love.graphics.rectangle("fill", panelX + PAD, panelY + 72, TEXT_W, 1)

    local metaFont = FontManager.getFont(10)
    love.graphics.setFont(metaFont)
    local typeColor = Palette.forCardType(inst.type) or Palette.PARCHMENT
    local rarityColor = Palette.forRarity(inst.rarity) or Palette.PARCHMENT
    local typeLabel = I18n.t("card_type." .. (inst.type or "unknown"), nil, I18n.t("card_type.unknown"))
    local classLabel = inst.class and I18n.t("classes." .. inst.class .. ".name", nil, inst.class)
                                   or I18n.t("collection.class_basic")
    local rarityLabel = I18n.t("rarity." .. (inst.rarity or "common"), nil, inst.rarity or "")

    local metaY = panelY + 84
    local lineH = metaFont:getHeight() + 4
    love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], anim)
    love.graphics.print(typeLabel, panelX + PAD, metaY)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], anim)
    love.graphics.print(classLabel, panelX + PAD, metaY + lineH)
    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], anim)
    love.graphics.print(rarityLabel, panelX + PAD, metaY + lineH * 2)

    local statFont = FontManager.getFont(12)
    love.graphics.setFont(statFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
    local statY = metaY + lineH * 3 + 12
    love.graphics.print(I18n.t("card_info.cost") .. tostring(inst.cost or 0), panelX + PAD, statY)
    statY = statY + 20
    -- destaque VERDE se forjada (padrão StS de stat aumentado)
    local upgraded = (inst.upgrades or 0) > 0
    if inst.type == "attack" then
        if upgraded then love.graphics.setColor(0.55, 0.92, 0.45, anim)
        else love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], anim) end
        love.graphics.print(I18n.t("card_info.damage") .. tostring(inst.attack or 0), panelX + PAD, statY)
        statY = statY + 20
    elseif inst.type == "defense" then
        if upgraded then love.graphics.setColor(0.55, 0.92, 0.45, anim)
        else love.graphics.setColor(Palette.STEEL_LIGHT[1], Palette.STEEL_LIGHT[2], Palette.STEEL_LIGHT[3], anim) end
        love.graphics.print(I18n.t("card_info.defense") .. tostring(inst.defense or 0), panelX + PAD, statY)
        statY = statY + 20
    end
    if upgraded then
        love.graphics.setColor(0.55, 0.92, 0.45, anim)
        love.graphics.print("+" .. tostring(inst.upgrades) .. " forja", panelX + PAD, statY)
        statY = statY + 20
    end

    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6 * anim)
    love.graphics.rectangle("fill", panelX + PAD, statY + 4, TEXT_W, 1)
    statY = statY + 14
    local descFont = FontManager.getFont(10)
    love.graphics.setFont(descFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
    local fullDesc = I18n.cardDesc(inst)
    if not fullDesc or fullDesc == "" then fullDesc = I18n.t("card_info.no_desc") end
    love.graphics.printf(fullDesc, panelX + PAD, statY, TEXT_W)

    if inst.effects and #inst.effects > 0 then
        local effY = statY + 80
        love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], anim)
        love.graphics.print(I18n.t("card_info.effects"), panelX + PAD, effY)
        love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
        love.graphics.setFont(descFont)
        for i, e in ipairs(inst.effects) do
            local desc = I18n.effectDesc(e)
            love.graphics.printf("- " .. desc, panelX + PAD + 8, effY + 16 * i, TEXT_W - 8)
            if i >= 4 then break end
        end
    end

    local idFont = FontManager.getFont(8)
    love.graphics.setFont(idFont)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], 0.4 * anim)
    love.graphics.printf(inst.id or "", panelX + PAD, panelY + panelH - 16, TEXT_W)

    drawArrows(self, width, height)

    local closeFont = FontManager.getFont(13)
    love.graphics.setFont(closeFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], anim)
    local closeMsg = I18n.t("collection.inspect_help")
    love.graphics.print(closeMsg, (width - closeFont:getWidth(closeMsg)) / 2, height - 30)

    love.graphics.setColor(1, 1, 1, 1)
end

return CardInspectModal
