-- components/MapScreen.lua
-- Tela imersiva de escolha de caminho. Tela inteira dividida em N painéis
-- verticais (N = #nodes). Cada painel mostra uma scene full-height ilustrada
-- (assets/sprites/scenes/path_<type>.png) com overlay de número, nome e descrição.
--
-- Hover: painel ganha brilho + leve zoom. Outros painéis ficam dim.
-- Atalhos: 1/2/3 escolhem painel correspondente.

local MapScreen = {}
MapScreen.__index = MapScreen

local FontManager   = require("src.ui.FontManager")
local Palette       = require("src.ui.Palette")
local IconLoader    = require("src.ui.IconLoader")
local EnemyRenderer = require("src.ui.EnemyRenderer")
local Sfx           = require("src.systems.Sfx")

-- Cache de sprites estáticos do inimigo (south.png) reaproveitando os assets
-- já gerados pelo enemy pipeline. Mostrados como preview no MapScreen pra
-- jogador antecipar qual inimigo vai enfrentar — uso real das rotações que
-- antes eram só geradas e nunca renderizadas.
local enemyPreviewCache = {}
local enemyPreviewMiss = {}
local function loadEnemySouthSprite(spriteId)
    if not spriteId then return nil end
    if enemyPreviewCache[spriteId] then return enemyPreviewCache[spriteId] end
    if enemyPreviewMiss[spriteId] then return nil end
    local path = "assets/sprites/characters/enemies/" .. spriteId .. "/south.png"
    if not love.filesystem.getInfo(path) then
        enemyPreviewMiss[spriteId] = true
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then enemyPreviewMiss[spriteId] = true; return nil end
    img:setFilter("nearest", "nearest")
    enemyPreviewCache[spriteId] = img
    return img
end

-- Cache local de scenes path_*.png pra não recarregar a cada draw
local sceneCache = {}
local sceneMiss = {}

local function loadPathScene(nodeType)
    local key = "path_" .. nodeType
    if sceneCache[key] then return sceneCache[key] end
    if sceneMiss[key] then return nil end
    local path = "assets/sprites/scenes/" .. key .. ".png"
    if not love.filesystem.getInfo(path) then
        sceneMiss[key] = true
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then
        sceneMiss[key] = true
        return nil
    end
    img:setFilter("nearest", "nearest")
    sceneCache[key] = img
    return img
end

function MapScreen:new()
    local instance = setmetatable({}, MapScreen)
    instance.visible = false
    instance.nodes = {}
    instance.onNodeChosen = nil
    instance.hoverIndex = nil
    instance.panelRects = {}
    instance.title = "Escolha o proximo caminho"
    -- Fade-out animation: ao escolher node, outros ease alpha → 0.25 em 0.28s
    -- antes do callback disparar (Balatro decision-feedback pattern).
    instance.chosenIdx = nil
    instance.dimOthers = 0  -- 0 (todos full) → 1 (não-escolhidos a 25%)
    return instance
end

function MapScreen:show(nodes, onNodeChosen, titleOverride)
    self.visible = true
    self.nodes = nodes or {}
    self.onNodeChosen = onNodeChosen
    self.title = titleOverride or self.title
    self.chosenIdx = nil
    self.dimOthers = 0
    self:updateLayout()
end

function MapScreen:hide()
    self.visible = false
    self.nodes = {}
    self.hoverIndex = nil
end

function MapScreen:isVisible() return self.visible end

function MapScreen:updateLayout()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local n = math.max(1, #self.nodes)

    -- Cada painel ocupa toda a altura e (sw / n) da largura.
    -- Reservar topo pra título (~10%) e bottom pra hint (~5%).
    local titleH = math.floor(sh * 0.10)
    local hintH = math.floor(sh * 0.05)
    local panelTop = titleH
    local panelH = sh - titleH - hintH

    self.panelRects = {}
    local panelW = math.floor(sw / n)
    for i = 1, n do
        local x = (i - 1) * panelW
        table.insert(self.panelRects, {
            x = x,
            y = panelTop,
            w = panelW,
            h = panelH,
        })
    end
end

function MapScreen:update(dt)
    if not self.visible then return end
    local mx, my = love.mouse.getPosition()
    self.hoverIndex = nil
    for i, r in ipairs(self.panelRects) do
        if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
            self.hoverIndex = i
            break
        end
    end
end

-- Desenha bg da scene cobrindo o painel (cover-fit), com tint dim quando não-hover.
local function drawPanelBackground(node, r, isHover)
    local img = loadPathScene(node.type)
    if not img then
        -- Fallback: gradient escuro no painel
        love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],
                               Palette.PARCHMENT_DARK[3], 1)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
        return
    end

    -- Cover-fit: maior fator preenche painel inteiro, sobra é cortada
    local iw, ih = img:getWidth(), img:getHeight()
    local sx = r.w / iw
    local sy = r.h / ih
    local s = math.max(sx, sy)
    local dw = iw * s
    local dh = ih * s
    local ox = r.x + (r.w - dw) / 2
    local oy = r.y + (r.h - dh) / 2

    -- Scissor pra clipar dentro do painel (mais simples que stencil + funciona
    -- com Canvas do CRTShader sem precisar de stencil enabled).
    love.graphics.setScissor(r.x, r.y, r.w, r.h)

    -- Tint: hover = full brightness, outros = 60% pra criar contraste
    if isHover then
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(0.6, 0.55, 0.50, 1)
    end
    love.graphics.draw(img, ox, oy, 0, s, s)

    love.graphics.setScissor() -- reseta clip

    -- Borda lateral entre painéis (linha vertical sutil)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
end

-- Overlay com gradient bottom (escurece pra texto ficar legível) + número + label + desc
local function drawPanelOverlay(node, index, r, isHover)
    -- Gradient bottom (escuro pra texto legível)
    local gradH = math.floor(r.h * 0.40)
    for i = 0, gradH do
        local alpha = (i / gradH) * 0.85
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", r.x, r.y + r.h - gradH + i, r.w, 1)
    end

    -- Top: número grande "1" "2" "3" em círculo
    local circleSize = math.floor(r.w * 0.12)
    local circleX = r.x + math.floor(r.w / 2)
    local circleY = r.y + math.floor(r.h * 0.08) + circleSize
    if isHover then
        love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2],
                               Palette.AGED_GOLD[3], 0.95)
    else
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.85)
    end
    love.graphics.circle("fill", circleX, circleY, circleSize)
    love.graphics.setColor(isHover and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", circleX, circleY, circleSize)

    local numFont = FontManager.getResponsiveFont(0.05, 36)
    love.graphics.setFont(numFont)
    local numStr = tostring(index)
    local nw = numFont:getWidth(numStr)
    local nh = numFont:getHeight()
    love.graphics.setColor(isHover and Palette.INK or Palette.PARCHMENT_LIGHT)
    love.graphics.print(numStr, circleX - nw / 2, circleY - nh / 2)

    -- Bottom: label grande + descrição
    local labelFont = FontManager.getResponsiveFont(0.038, 28)
    local descFont  = FontManager.getResponsiveFont(0.020, 14)

    local labelY = r.y + r.h - math.floor(r.h * 0.22)
    local descY  = r.y + r.h - math.floor(r.h * 0.12)

    local isBoss = (node.type == "boss" or node.type == "mini_boss")
    local labelColor = isBoss and Palette.BLOOD or
                       (isHover and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT)
    love.graphics.setFont(labelFont)
    love.graphics.setColor(labelColor)
    love.graphics.printf(node.label or node.type, r.x + 8, labelY, r.w - 16, "center")

    love.graphics.setFont(descFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2],
                           Palette.PARCHMENT_LIGHT[3], 0.92)
    love.graphics.printf(node.desc or "", r.x + 12, descY, r.w - 24, "center")

    -- Hover: borda dourada brilhante destacando o painel selecionado
    if isHover then
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2],
                               Palette.AGED_GOLD_LIGHT[3], 0.85)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", r.x + 2, r.y + 2, r.w - 4, r.h - 4)
    end
end

function MapScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Fundo geral preto (caso scenes não cubram)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Título no topo
    local titleFont = FontManager.getResponsiveFont(0.042, 32)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
    local tw = titleFont:getWidth(self.title)
    love.graphics.print(self.title, math.floor((sw - tw) / 2), math.floor(sh * 0.025))

    -- Painéis (com dim ease nos não-escolhidos quando dimOthers > 0)
    for i, r in ipairs(self.panelRects) do
        local node = self.nodes[i]
        if node then
            local isHover = (self.hoverIndex == i)
            drawPanelBackground(node, r, isHover)

            -- PREVIEW DO INIMIGO: pra nodes de combate, sobrepor sprite south
            -- do inimigo que será enfrentado (usa os assets já gerados).
            local isCombat = (node.type == "battle" or node.type == "elite"
                or node.type == "mini_boss" or node.type == "boss")
            if isCombat then
                local spriteId = EnemyRenderer.resolveSpriteId(node.actNumber, node.type)
                local img = loadEnemySouthSprite(spriteId)
                if img then
                    local iw, ih = img:getWidth(), img:getHeight()
                    local targetH = math.floor(r.h * 0.45)
                    local scale = math.max(2, math.floor(targetH / ih))
                    local px = r.x + math.floor((r.w - iw * scale) / 2)
                    local py = r.y + math.floor(r.h * 0.32)

                    -- Sombra elíptica no chão pra grudar no painel
                    love.graphics.setColor(0, 0, 0, 0.55)
                    love.graphics.ellipse("fill", r.x + r.w / 2,
                        py + ih * scale + 4, iw * scale * 0.35, 5)

                    -- Sprite com tint segundo hover state
                    if isHover then
                        love.graphics.setColor(1, 1, 1, 1)
                    else
                        love.graphics.setColor(0.7, 0.65, 0.60, 0.95)
                    end
                    love.graphics.draw(img, px, py, 0, scale, scale)
                    love.graphics.setColor(1, 1, 1, 1)
                end
            end

            drawPanelOverlay(node, i, r, isHover)

            -- Dim overlay sobre nodes NÃO-escolhidos enquanto a transição roda.
            -- Desenhado por cima de tudo que esse panel pintou, simulando "o
            -- jogador escolheu, esses caminhos ficam pra trás" (Balatro feel).
            if self.chosenIdx and self.chosenIdx ~= i and (self.dimOthers or 0) > 0 then
                love.graphics.setColor(0, 0, 0, 0.65 * self.dimOthers)
                love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    end

    -- Hint no rodapé
    local hintFont = FontManager.getResponsiveFont(0.022, 14)
    love.graphics.setFont(hintFont)
    love.graphics.setColor(0.85, 0.85, 0.85, 0.7)
    local hint = "Clique numa opcao OU pressione 1 / 2 / 3.  ESC volta ao menu."
    local hw = hintFont:getWidth(hint)
    love.graphics.print(hint, math.floor((sw - hw) / 2), math.floor(sh * 0.97) - hintFont:getHeight())

    love.graphics.setColor(1, 1, 1, 1)
end

function MapScreen:mousepressed(x, y, button)
    if not self.visible or button ~= 1 then return end
    -- Bloqueia segundo clique enquanto a transição de saída roda.
    if self.chosenIdx then return true end
    for i, r in ipairs(self.panelRects) do
        if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
            local node = self.nodes[i]
            if node and self.onNodeChosen then
                Sfx.play("nodeSelect")
                self:_chooseNode(node, i)
            end
            return true
        end
    end
    return false
end

-- Marca o node escolhido, ease alpha dos outros pra 0.25, e dispara callback
-- após 0.28s. Replica decision-feedback Balatro: o jogador VÊ a escolha "afundar"
-- antes do flow seguir, em vez de cortar abrupto.
function MapScreen:_chooseNode(node, idx)
    self.chosenIdx = idx
    local EM = _G.EventManager
    if EM and EM.parallelEase then
        EM.parallelEase(self, "dimOthers", 1, 0.28, "smooth", "map_choose")
        EM.parallel(0.30, function()
            if self.onNodeChosen then self.onNodeChosen(node, idx) end
        end, "map_choose")
    else
        if self.onNodeChosen then self.onNodeChosen(node, idx) end
    end
end

function MapScreen:mousereleased(x, y, button) return false end

function MapScreen:keypressed(key)
    if self.chosenIdx then return end -- bloqueia keyboard durante transição
    if key == "1" or key == "2" or key == "3" or key == "4" then
        local i = tonumber(key)
        local node = self.nodes[i]
        if node and self.onNodeChosen then
            Sfx.play("nodeSelect")
            self:_chooseNode(node, i)
            return true
        end
    end
    return false
end

function MapScreen:resize() self:updateLayout() end

return MapScreen
