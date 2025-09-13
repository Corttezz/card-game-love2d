-- src/ui/CardInfoDisplay.lua
-- Componente reutilizável para exibir informações de cartas

local CardInfoDisplay = {}
CardInfoDisplay.__index = CardInfoDisplay

local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")

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
    
    -- Calcula altura necessária com quebra de linha
    if showDescription and cardInstance.description then
        panelHeight = panelHeight + lineHeight + 10 -- Nome
        local descHeight = calculateTextHeight(cardInstance.description, maxTextWidth)
        panelHeight = panelHeight + descHeight + 10 -- Descrição com quebra de linha
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
    
    -- Posiciona o painel ACIMA da carta (centralizado horizontalmente com offset para direita)
    local panelX = x - panelWidth / 2 + 70  -- Offset de 30px para a direita
    local panelY = y - panelHeight + 20
    
    -- Verifica se o painel cabe na tela e ajusta se necessário
    
    -- Ajusta posição horizontal se o painel sair da tela
    if panelX < 10 then
        panelX = 10
    elseif panelX + panelWidth > screenWidth - 10 then
        panelX = screenWidth - panelWidth - 10
    end
    
    -- Ajusta posição vertical se o painel sair da tela
    if panelY < 10 then
        -- Se não cabe acima, coloca abaixo da carta
        panelY = y + 100
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
    love.graphics.setColor(1, 1, 1, 1) -- Nome em branco
    love.graphics.print(cardInstance.name, textX, currentY)
    currentY = currentY + lineHeight + 10
    
    -- Descrição (se habilitado)
    if showDescription and cardInstance.description then
        -- Calcula altura da descrição com quebra de linha
        local descHeight = calculateTextHeight(cardInstance.description, maxTextWidth)
        
        -- Área de descrição com fundo mais claro
        love.graphics.setColor(0.3, 0.3, 0.35, 0.9)
        love.graphics.rectangle("fill", textX - 5, currentY - 5, panelWidth - padding * 2 + 10, descHeight + 10, 5, 5)
        
        -- Texto da descrição com quebra de linha
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        self:drawWrappedText(cardInstance.description, textX, currentY, maxTextWidth, lineHeight)
        currentY = currentY + descHeight + 15
    end
    
    -- Raridade (se habilitado)
    if showRarity and cardInstance.rarity then
        local rarityColor = self.rarityColors[cardInstance.rarity] or {1, 1, 1}
        
        -- Calcula largura necessária para o texto da raridade
        local rarityText = cardInstance.rarity:upper()
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
    love.graphics.print("RARIDADE: " .. cardInstance.rarity:upper(), x + 10, y)
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
    love.graphics.print(cardInstance.name, x + 10, y)
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
