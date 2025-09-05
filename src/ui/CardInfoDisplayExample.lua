-- src/ui/CardInfoDisplayExample.lua
-- Exemplos de uso do componente CardInfoDisplay

local CardInfoDisplay = require("src.ui.CardInfoDisplay")

-- Exemplo 1: Uso básico
local function basicUsage()
    local cardInfo = CardInfoDisplay:new()
    
    -- Configuração padrão
    cardInfo:configure({
        showRarity = true,
        showStats = true,
        showDescription = false
    })
    
    -- Desenha todas as informações
    cardInfo:draw(cardInstance, x, y)
end

-- Exemplo 2: Uso customizado para diferentes tipos de tela
local function customUsage()
    local cardInfo = CardInfoDisplay:new()
    
    -- Para tela de seleção de cartas (sem descrição)
    cardInfo:draw(cardInstance, x, y, {
        showRarity = true,
        showStats = true,
        showDescription = false
    })
    
    -- Para tela de detalhes da carta (com descrição)
    cardInfo:draw(cardInstance, x, y, {
        showRarity = true,
        showStats = true,
        showDescription = true
    })
    
    -- Para tooltip simples (apenas nome e raridade)
    cardInfo:draw(cardInstance, x, y, {
        showRarity = true,
        showStats = false,
        showDescription = false
    })
end

-- Exemplo 3: Uso em componentes específicos
local function componentUsage()
    local cardInfo = CardInfoDisplay:new()
    
    -- Configuração para cartas da mão
    cardInfo:configure({
        showRarity = false,  -- Não mostra raridade na mão
        showStats = true,    -- Mostra ataque/defesa/custo
        showDescription = false
    })
    
    -- Configuração para tela de recompensas
    local rewardCardInfo = CardInfoDisplay:new()
    rewardCardInfo:configure({
        showRarity = true,   -- Mostra raridade para escolha
        showStats = true,    -- Mostra estatísticas
        showDescription = false
    })
    
    -- Configuração para tela de detalhes
    local detailCardInfo = CardInfoDisplay:new()
    detailCardInfo:configure({
        showRarity = true,
        showStats = true,
        showDescription = true  -- Mostra descrição completa
    })
end

-- Exemplo 4: Uso com cores customizadas
local function customColorsUsage()
    local cardInfo = CardInfoDisplay:new()
    
    -- Cores customizadas para raridade
    cardInfo:configure({
        rarityColors = {
            common = {0.8, 0.8, 0.8},
            uncommon = {0.3, 0.9, 0.3},
            rare = {0.9, 0.3, 0.9},
            legendary = {0.9, 0.7, 0.3},
            basic = {0.6, 0.6, 0.6}
        }
    })
    
    -- Cores customizadas para texto
    cardInfo:configure({
        textColor = {0.9, 0.9, 0.9, 1}
    })
end

-- Exemplo 5: Uso em diferentes posições
local function positioningUsage()
    local cardInfo = CardInfoDisplay:new()
    
    -- Posicionamento padrão (acima da carta)
    cardInfo:draw(cardInstance, x, y)
    
    -- Posicionamento customizado (à direita da carta)
    local rightX = x + cardWidth + 20
    cardInfo:draw(cardInstance, rightX, y)
    
    -- Posicionamento customizado (abaixo da carta)
    local belowY = y + cardHeight + 20
    cardInfo:draw(cardInstance, x, belowY)
end

-- Exemplo 6: Uso com diferentes fontes (se implementado)
local function fontUsage()
    local cardInfo = CardInfoDisplay:new()
    
    -- Configuração para tela pequena
    cardInfo:configure({
        showRarity = true,
        showStats = true,
        showDescription = false
    })
    
    -- Configuração para tela grande
    cardInfo:configure({
        showRarity = true,
        showStats = true,
        showDescription = true
    })
end

return {
    basicUsage = basicUsage,
    customUsage = customUsage,
    componentUsage = componentUsage,
    customColorsUsage = customColorsUsage,
    positioningUsage = positioningUsage,
    fontUsage = fontUsage
}
