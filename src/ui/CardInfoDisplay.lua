-- src/ui/CardInfoDisplay.lua
-- Componente reutilizável para exibir informações de cartas

local CardInfoDisplay = {}
CardInfoDisplay.__index = CardInfoDisplay

local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local I18n = require("src.i18n.I18n")

function CardInfoDisplay:new()
    local instance = setmetatable({}, CardInfoDisplay)
    
    -- Configurações padrão
    instance.showRarity = true
    instance.showStats = true
    instance.showDescription = false
    instance.textColor = {1, 1, 1, 1}
    instance.rarityColor = {1, 1, 1, 1}
    
    -- Cores de raridade padrão
    instance.rarityColors = {
        common = {0.7, 0.7, 0.7},
        uncommon = {0.2, 0.8, 0.2},
        rare = {0.8, 0.2, 0.8},
        legendary = {0.8, 0.6, 0.2},
        basic = {0.5, 0.5, 0.5}
    }
    
    return instance
end

-- Configura as opções de exibição
function CardInfoDisplay:configure(options)
    if options.showRarity ~= nil then
        self.showRarity = options.showRarity
    end
    if options.showStats ~= nil then
        self.showStats = options.showStats
    end
    if options.showDescription ~= nil then
        self.showDescription = options.showDescription
    end
    if options.textColor then
        self.textColor = options.textColor
    end
    if options.rarityColors then
        self.rarityColors = options.rarityColors
    end
end

-- Desenha as informações da carta
function CardInfoDisplay:draw(cardInstance, x, y, options)
    if not cardInstance then return end
    
    -- Mescla opções locais com configurações globais
    local localOptions = options or {}
    local showRarity = localOptions.showRarity ~= nil and localOptions.showRarity or self.showRarity
    local showStats = localOptions.showStats ~= nil and localOptions.showStats or self.showStats
    local showDescription = localOptions.showDescription ~= nil and localOptions.showDescription or self.showDescription
    
    -- Calcula dimensões do painel baseado no conteúdo e tamanho da tela
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Painel responsivo baseado no tamanho da tela
    local panelWidth = math.min(320, math.max(250, screenWidth * 0.25))
    local panelHeight = 0
    local padding = math.max(10, math.min(20, screenWidth * 0.01))
    
    -- Usa fonte fixa para consistência
    local displayFont = FontManager.getFont(16)
    love.graphics.setFont(displayFont)
    local lineHeight = displayFont:getHeight()
    local maxTextWidth = panelWidth - padding * 2
    
    -- Função para calcular altura do texto com quebra de linha
    local function calculateTextHeight(text, maxWidth)
        if not text then return 0 end
        
        local words = {}
        for word in text:gmatch("%S+") do
            table.insert(words, word)
        end
        
        local currentLine = ""
        local lines = 1
        
        for i, word in ipairs(words) do
            local testLine = currentLine .. (currentLine == "" and "" or " ") .. word
            if displayFont:getWidth(testLine) > maxWidth then
                if currentLine == "" then
                    -- Palavra muito longa, força quebra
                    lines = lines + 1
                else
                    -- Quebra a linha
                    currentLine = word
                    lines = lines + 1
                end
            else
                currentLine = testLine
            end
        end
        
        return lines * lineHeight
    end
    
    -- Glossário de keywords (F5): detecta termos na descrição e explica.
    local kwFont = FontManager.getFont(11)
    local kwLineH = kwFont:getHeight()
    local kwHits = {}
    local _descForKw = I18n.cardDesc(cardInstance)
    if showDescription and _descForKw and _descForKw ~= "" then
        local lower = _descForKw:lower()
        local Keywords = require("src.data.keywords")
        for _, kw in ipairs(Keywords) do
            for _, mword in ipairs(kw.match) do
                if lower:find(mword, 1, true) then
                    table.insert(kwHits, kw)
                    break
                end
            end
            if #kwHits >= 3 then break end
        end
    end
    -- Altura de um item do glossário (nome + texto com wrap na fonte menor).
    local function kwItemHeight(kw, maxWidth)
        local full = kw.name .. ": " .. kw.text
        local line = ""
        local lines = 1
        for word in full:gmatch("%S+") do
            local test = line .. (line == "" and "" or " ") .. word
            if kwFont:getWidth(test) > maxWidth then
                line = word
                lines = lines + 1
            else
                line = test
            end
        end
        return lines * kwLineH + 4
    end

    -- Calcula altura necessária com quebra de linha (usa descrição localizada)
    local _localizedDescForHeight = I18n.cardDesc(cardInstance)
    if showDescription and _localizedDescForHeight and _localizedDescForHeight ~= "" then
        panelHeight = panelHeight + lineHeight + 10 -- Nome
        local descHeight = calculateTextHeight(_localizedDescForHeight, maxTextWidth)
        panelHeight = panelHeight + descHeight + 10 -- Descrição com quebra de linha
        if #kwHits > 0 then
            panelHeight = panelHeight + 8
            for _, kw in ipairs(kwHits) do
                panelHeight = panelHeight + kwItemHeight(kw, maxTextWidth)
            end
        end
        if showRarity and cardInstance.rarity then
            panelHeight = panelHeight + lineHeight + 10 -- Raridade
        end
        if showStats then
            panelHeight = panelHeight + lineHeight + 10 -- Stats
        end
    else
        -- Layout compacto sem descrição
        panelHeight = lineHeight + 10 -- Nome
        if showRarity and cardInstance.rarity then
            panelHeight = panelHeight + lineHeight + 10
        end
        if showStats then
            panelHeight = panelHeight + lineHeight + 10
        end
    end
    
    panelHeight = panelHeight + padding * 2
    
    -- Smart positioning: tooltip ABAIXO da carta por default (Balatro-style),
    -- com fallback ACIMA se cair fora da tela. Considera altura do price
    -- medalhão (32px halo) pra não colidir.
    --
    -- Cardheight estimado pelas dimensões da carta (instância sabe).
    local approxCardH = 0
    if cardInstance.image then
        approxCardH = cardInstance.image:getHeight() * (cardInstance.currentScale or 1)
    end
    local priceMedalSafezone = 8  -- spacing após bottom da carta
    local panelX = x - panelWidth / 2 + 70  -- offset legado pra direita
    local panelY = y + approxCardH + priceMedalSafezone

    -- Ajusta posição horizontal se o painel sair da tela
    if panelX < 10 then
        panelX = 10
    elseif panelX + panelWidth > screenWidth - 10 then
        panelX = screenWidth - panelWidth - 10
    end

    -- Se não cabe abaixo (passa do bottom da tela), tenta acima.
    local screenHeight = love.graphics.getHeight()
    if panelY + panelHeight > screenHeight - 10 then
        panelY = y - panelHeight - priceMedalSafezone
        -- Se também não cabe acima, força no bottom da tela.
        if panelY < 10 then
            panelY = screenHeight - panelHeight - 10
        end
    end
    
    -- Desenha o painel de fundo (estilo Balatro)
    love.graphics.setColor(0.2, 0.2, 0.25, 0.95) -- Fundo escuro semi-transparente
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8, 8)
    
    -- Borda do painel
    love.graphics.setColor(0.4, 0.4, 0.5, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8, 8)
    
    -- Posição inicial para o texto
    local currentY = panelY + padding
    local textX = panelX + padding
    
    -- Nome da carta (sempre visível)
    local localizedName = I18n.cardName(cardInstance)
    local localizedDesc = I18n.cardDesc(cardInstance)
    love.graphics.setColor(1, 1, 1, 1) -- Nome em branco
    love.graphics.print(localizedName, textX, currentY)
    currentY = currentY + lineHeight + 10

    -- Descrição (se habilitado)
    if showDescription and localizedDesc and localizedDesc ~= "" then
        -- Calcula altura da descrição com quebra de linha
        local descHeight = calculateTextHeight(localizedDesc, maxTextWidth)

        -- Área de descrição com fundo mais claro
        love.graphics.setColor(0.3, 0.3, 0.35, 0.9)
        love.graphics.rectangle("fill", textX - 5, currentY - 5, panelWidth - padding * 2 + 10, descHeight + 10, 5, 5)

        -- Texto da descrição com quebra de linha
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        self:drawWrappedText(localizedDesc, textX, currentY, maxTextWidth, lineHeight)
        currentY = currentY + descHeight + 15

        -- Glossário (F5): keywords da descrição explicadas em fonte menor,
        -- nome em dourado + texto em pergaminho (padrão Balatro de tooltip
        -- secundário anexado).
        if #kwHits > 0 then
            love.graphics.setColor(0.78, 0.65, 0.20, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.line(textX, currentY - 6, textX + maxTextWidth, currentY - 6)
            love.graphics.setFont(kwFont)
            for _, kw in ipairs(kwHits) do
                -- nome dourado inline + resto do texto com wrap manual
                local full = kw.name .. ": " .. kw.text
                local nameW = kwFont:getWidth(kw.name .. ": ")
                love.graphics.setColor(1, 0.85, 0.35, 1)
                love.graphics.print(kw.name .. ":", textX, currentY)
                love.graphics.setColor(0.82, 0.78, 0.70, 1)
                -- wrap do texto começando após o nome
                local line = ""
                local yy = currentY
                local xx = textX + nameW
                local avail = maxTextWidth - nameW
                for word in kw.text:gmatch("%S+") do
                    local test = line .. (line == "" and "" or " ") .. word
                    if kwFont:getWidth(test) > avail then
                        love.graphics.print(line, xx, yy)
                        line = word
                        yy = yy + kwLineH
                        xx = textX
                        avail = maxTextWidth
                    else
                        line = test
                    end
                end
                if line ~= "" then love.graphics.print(line, xx, yy) end
                currentY = yy + kwLineH + 4
            end
            love.graphics.setFont(displayFont)
        end
    end

    -- Raridade (se habilitado)
    if showRarity and cardInstance.rarity then
        local rarityColor = self.rarityColors[cardInstance.rarity] or {1, 1, 1}

        -- Calcula largura necessária para o texto da raridade (traduzido + caps)
        local rarityText = (I18n.t("rarity." .. cardInstance.rarity, nil, cardInstance.rarity)):upper()
        local textWidth = love.graphics.getFont():getWidth(rarityText)
        
        -- Largura responsiva baseada no texto + padding
        local rarityWidth = math.max(80, textWidth + 20) -- Mínimo 80px, máximo baseado no texto
        local rarityHeight = 25
        local rarityX = textX
        local rarityY = currentY
        
        -- Verifica se o botão cabe na tela e ajusta se necessário
        local screenWidth = love.graphics.getWidth()
        if rarityX + rarityWidth > screenWidth - 10 then
            -- Se não cabe, reduz a largura ou ajusta a posição
            rarityWidth = math.min(rarityWidth, screenWidth - rarityX - 10)
            if rarityWidth < textWidth + 10 then
                -- Se ainda não cabe, ajusta a posição
                rarityX = screenWidth - rarityWidth - 10
            end
        end
        
        -- Fundo do botão de raridade
        love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], 0.8)
        love.graphics.rectangle("fill", rarityX, rarityY, rarityWidth, rarityHeight, 5, 5)
        
        -- Borda do botão
        love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rarityX, rarityY, rarityWidth, rarityHeight, 5, 5)
        
        -- Texto da raridade (centralizado no botão)
        love.graphics.setColor(1, 1, 1, 1)
        local textX = rarityX + (rarityWidth - textWidth) / 2
        local textY = rarityY + (rarityHeight - lineHeight) / 2
        love.graphics.print(rarityText, textX, textY)
        
        currentY = currentY + rarityHeight + 10
    end
    
    -- Estatísticas da carta (se habilitado)
    if showStats then
        love.graphics.setColor(1, 1, 1, 1)
        
        if cardInstance.attack and cardInstance.attack > 0 then
            -- Carta de ataque
            if cardInstance.attackIcon then
                love.graphics.draw(cardInstance.attackIcon, textX, currentY - 5, 0, 0.025, 0.025)
            end
            love.graphics.print(cardInstance.attack, textX + 25, currentY)
            
            -- Ícone de mana + valor
            if cardInstance.manaIcon then
                love.graphics.draw(cardInstance.manaIcon, textX + 60, currentY - 5, 0, 0.025, 0.025)
            end
            love.graphics.print(cardInstance.cost, textX + 85, currentY)
            
        elseif cardInstance.defense and cardInstance.defense > 0 then
            -- Carta de defesa
            if cardInstance.armorIcon then
                love.graphics.draw(cardInstance.armorIcon, textX, currentY - 5, 0, 0.025, 0.025)
            end
            
            -- Ajusta posição do texto baseado no número de dígitos
            if cardInstance.defense > 9 then
                love.graphics.print(cardInstance.defense, textX + 3.3, currentY - 0.5)
            else
                love.graphics.print(cardInstance.defense, textX + 8.3, currentY - 0.5)
            end
            
            -- Ícone de mana + valor
            if cardInstance.manaIcon then
                love.graphics.draw(cardInstance.manaIcon, textX + 60, currentY - 5, 0, 0.025, 0.025)
            end
            love.graphics.print(cardInstance.cost, textX + 85, currentY)
            
        else
            -- Carta sem ataque/defesa (como jokers)
            if cardInstance.manaIcon then
                love.graphics.draw(cardInstance.manaIcon, textX, currentY - 5, 0, 0.025, 0.025)
            end
            love.graphics.print(cardInstance.cost, textX + 25, currentY)
        end
    end
end

-- Desenha apenas a raridade da carta
function CardInfoDisplay:drawRarity(cardInstance, x, y, options)
    if not cardInstance or not cardInstance.rarity then return end
    
    local rarityColor = self.rarityColors[cardInstance.rarity] or {1, 1, 1}
    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], 1)
    local rarityWord = (I18n.t("rarity." .. cardInstance.rarity, nil, cardInstance.rarity)):upper()
    love.graphics.print(I18n.t("card_info.rarity_label") .. rarityWord, x + 10, y)
end

-- Desenha apenas as estatísticas da carta
function CardInfoDisplay:drawStats(cardInstance, x, y, options)
    if not cardInstance then return end
    
    love.graphics.setColor(1, 1, 1, 1)
    
    if cardInstance.attack and cardInstance.attack > 0 then
        if cardInstance.attackIcon then
            love.graphics.draw(cardInstance.attackIcon, x + 5, y - 5, 0, 0.03, 0.03)
        end
        love.graphics.print(cardInstance.attack, x + 20, y + 5)
        
        if cardInstance.manaIcon then
            love.graphics.draw(cardInstance.manaIcon, x + 40, y - 5, 0, 0.03, 0.03)
        end
        love.graphics.print(cardInstance.cost, x + 60, y + 5)
        
    elseif cardInstance.defense and cardInstance.defense > 0 then
        if cardInstance.armorIcon then
            love.graphics.draw(cardInstance.armorIcon, x + 5, y - 5, 0, 0.03, 0.03)
        end
        
        if cardInstance.defense > 9 then
            love.graphics.print(cardInstance.defense, x + 10.5, y)
        else
            love.graphics.print(cardInstance.defense, x + 15, y)
        end
        
        if cardInstance.manaIcon then
            love.graphics.draw(cardInstance.manaIcon, x + 40, y - 5, 0, 0.03, 0.03)
        end
        love.graphics.print(cardInstance.cost, x + 60, y + 5)
        
    else
        if cardInstance.manaIcon then
            love.graphics.draw(cardInstance.manaIcon, x + 5, y - 5, 0, 0.03, 0.03)
        end
        love.graphics.print(cardInstance.cost, x + 20, y + 5)
    end
end

-- Desenha apenas o nome da carta
function CardInfoDisplay:drawName(cardInstance, x, y, options)
    if not cardInstance or not cardInstance.name then return end

    local textColor = options and options.textColor or self.textColor
    love.graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4])
    love.graphics.print(I18n.cardName(cardInstance), x + 10, y)
end

-- Função para desenhar texto com quebra de linha
function CardInfoDisplay:drawWrappedText(text, x, y, maxWidth, lineHeight)
    if not text then return end
    
    -- Garante que a fonte está configurada
    local displayFont = FontManager.getFont(16)
    love.graphics.setFont(displayFont)
    
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local currentLine = ""
    local currentY = y
    
    for i, word in ipairs(words) do
        local testLine = currentLine .. (currentLine == "" and "" or " ") .. word
        if displayFont:getWidth(testLine) > maxWidth then
            if currentLine == "" then
                -- Palavra muito longa, força quebra
                love.graphics.print(word, x, currentY)
                currentY = currentY + lineHeight
            else
                -- Quebra a linha
                love.graphics.print(currentLine, x, currentY)
                currentY = currentY + lineHeight
                currentLine = word
            end
        else
            currentLine = testLine
        end
    end
    
    -- Desenha a última linha
    if currentLine ~= "" then
        love.graphics.print(currentLine, x, currentY)
    end
end

return CardInfoDisplay
