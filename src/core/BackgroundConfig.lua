-- src/core/BackgroundConfig.lua
-- Configuração de backgrounds do jogo

local BackgroundConfig = {}

-- Configurações de backgrounds
BackgroundConfig.BACKGROUNDS = {
    GAMEPLAY = {
        path = "assets/backgrounds/step1.png",
        fallback = "gradient", -- "gradient" ou "solid"
        scaleMode = "cover", -- "cover", "contain", "stretch"
        opacity = 1.0,
        tint = {1, 1, 1, 1} -- RGBA para tint da imagem
    },
    MENU = {
        path = "assets/backgrounds/menu_bg.png",
        fallback = "gradient",
        scaleMode = "cover",
        opacity = 1.0,
        tint = {1, 1, 1, 1}
    },
    CARD_REWARD = {
        path = "assets/backgrounds/reward_bg.png",
        fallback = "gradient",
        scaleMode = "cover",
        opacity = 0.8, -- Mais transparente para não interferir
        tint = {1, 1, 1, 1}
    }
}

-- Função para carregar um background
function BackgroundConfig.loadBackground(backgroundKey)
    local config = BackgroundConfig.BACKGROUNDS[backgroundKey]
    if not config then
        print("ERRO: Background não encontrado:", backgroundKey)
        return nil
    end
    
    local success, image = pcall(love.graphics.newImage, config.path)
    if success then
        print("Background carregado com sucesso:", config.path)
        return image
    else
        print("ERRO: Não foi possível carregar o background:", config.path)
        print("Erro:", image)
        return nil
    end
end

-- Função para desenhar um background
function BackgroundConfig.drawBackground(background, config, width, height, offsetX, offsetY)
    if not background or not config then
        return false
    end
    
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    
    local bgWidth = background:getWidth()
    local bgHeight = background:getHeight()
    local scale = 1
    local drawX = offsetX
    local drawY = offsetY
    
    -- Calcula escala baseada no modo
    if config.scaleMode == "cover" then
        local scaleX = width / bgWidth
        local scaleY = height / bgHeight
        scale = math.max(scaleX, scaleY) -- Cobre toda a tela
        drawX = offsetX + (width - bgWidth * scale) / 2
        drawY = offsetY + (height - bgHeight * scale) / 2
    elseif config.scaleMode == "contain" then
        local scaleX = width / bgWidth
        local scaleY = height / bgHeight
        scale = math.min(scaleX, scaleY) -- Contém na tela
        drawX = offsetX + (width - bgWidth * scale) / 2
        drawY = offsetY + (height - bgHeight * scale) / 2
    elseif config.scaleMode == "stretch" then
        scale = 1
        drawX = offsetX
        drawY = offsetY
        love.graphics.draw(background, offsetX, offsetY, 0, width / bgWidth, height / bgHeight)
        return true
    end
    
    -- Aplica opacidade e tint
    local tint = config.tint
    love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] * config.opacity)
    
    -- Desenha o background
    love.graphics.draw(background, drawX, drawY, 0, scale, scale)
    
    return true
end

-- Função para obter configuração de um background
function BackgroundConfig.getConfig(backgroundKey)
    return BackgroundConfig.BACKGROUNDS[backgroundKey]
end

-- Função para listar todos os backgrounds disponíveis
function BackgroundConfig.listBackgrounds()
    local list = {}
    for key, config in pairs(BackgroundConfig.BACKGROUNDS) do
        table.insert(list, {
            key = key,
            path = config.path,
            scaleMode = config.scaleMode
        })
    end
    return list
end

return BackgroundConfig

