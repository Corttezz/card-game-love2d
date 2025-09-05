-- src/Config.lua
-- Sistema de configuração centralizado para o jogo

local Config = {}

-- Configurações da Interface
Config.UI = {
    BUTTON_WIDTH_RATIO = 0.25,
    BUTTON_HEIGHT_RATIO = 0.08,
    BUTTON_SPACING_RATIO = 0.1,
    CARD_SPACING_RATIO = 0.15,
    CARD_START_X_RATIO = 0.1,
    CARD_Y_RATIO = 0.65, -- Cartas mais abaixo
    CARD_HOVER_OFFSET_RATIO = 0.12,
    CARD_SELECTED_OFFSET_RATIO = 0.1,
    PLAY_BUTTON_WIDTH_RATIO = 0.2,
    PLAY_BUTTON_HEIGHT_RATIO = 0.08,
    PLAY_BUTTON_X_RATIO = 0.5, -- Centralizado
    PLAY_BUTTON_Y_RATIO = 0.8, -- Abaixo das cartas
    BAR_WIDTH_RATIO = 0.25,
    BAR_HEIGHT_RATIO = 0.03,
    JOKER_SLOT_SIZE_RATIO = 0.13,
    JOKER_SLOT_SPACING_RATIO = 0.01,
    TITLE_FONT_RATIO = 0.08,
    SUBTITLE_FONT_RATIO = 0.03,
    INSTRUCTION_FONT_RATIO = 0.025,
    SCORE_FONT_RATIO = 0.04,
    TURN_FONT_RATIO = 0.03,
    JOKER_NAME_FONT_RATIO = 0.015,
}

-- Configurações do Jogo
Config.Game = {
    -- Cartas iniciais
    INITIAL_HAND_SIZE = 3,
    MAX_JOKER_SLOTS = 3,
    
    -- Fases
    VICTORY_PHASES = 10,
    HEALTH_RESTORE_INTERVAL = 3, -- Restaura vida a cada 3 fases
    
    -- Inimigos
    ENEMY_BASE_HEALTH = 18,
    ENEMY_BASE_DAMAGE = 5,
    ENEMY_HEALTH_SCALING = 15,  -- +15 HP por fase
    ENEMY_DAMAGE_SCALING = 3,   -- +3 dano por fase
    
    -- Jogador
    PLAYER_MAX_HEALTH = 100,
    PLAYER_MAX_ARMOR = 50,
    PLAYER_MAX_MANA = 3,
    PLAYER_HEALTH_RESTORE = 20,
    
    -- Pontuação
    BASE_SCORE_PER_PHASE = 100,
    
    -- Sistema de mensagens
    MAX_MESSAGES = 5,
    MESSAGE_DURATION = 3.0,
}

-- Configurações das Cartas
Config.Cards = {
    -- Escalas
    BASE_SCALE = 0.20,
    HOVER_SCALE = 0.22,
    
    -- Animações
    SCALE_ANIMATION_SPEED = 10,
    MOVE_RANGE = 8,           -- Aumentado para mais movimento
    TILT_RANGE = 0.15,        -- Aumentado para mais inclinação
    
    -- Efeitos 3D Balatro-style
    PERSPECTIVE_STRENGTH = 0.25,    -- Força do efeito de perspectiva
    DEPTH_OFFSET = 15,              -- Deslocamento vertical para profundidade
    ROTATION_SPEED = 8,             -- Velocidade da rotação
    SHADOW_INTENSITY = 0.8,         -- Intensidade da sombra
    
    -- Sombras dinâmicas
    SHADOW_OFFSET_BASE_X = -20,     -- Sombra base mais para esquerda
    SHADOW_OFFSET_BASE_Y = 30,      -- Sombra base mais para baixo
    SHADOW_STRETCH_X = 8,           -- Estiramento horizontal da sombra
    SHADOW_STRETCH_Y = 8,           -- Estiramento vertical da sombra
    SHADOW_SCALE_BASE = 0.9,        -- Escala base da sombra
    SHADOW_SCALE_VARIATION = 0.15,  -- Variação da escala da sombra
    
    -- Efeitos de profundidade
    DEPTH_TILT_X = 0.12,            -- Inclinação X baseada na profundidade
    DEPTH_TILT_Y = 0.08,            -- Inclinação Y baseada na profundidade
    LIFT_AMOUNT = 25,                -- Quanto a carta "levanta" no hover
    
    -- Borda azul para cartas jogáveis (Slay the Spire style)
    PLAYABLE_BORDER_COLOR = {0.3, 0.6, 0.9, 0.8}, -- Azul semi-transparente
    PLAYABLE_BORDER_THICKNESS = 4,                  -- Espessura da borda
    
    -- Animação da borda
    BORDER_ANIMATION_SPEED = 2.0,                   -- Velocidade da animação
    BORDER_PULSE_RANGE = 0.3,                       -- Variação da opacidade (0.3 = 30%)
    BORDER_INNER_OFFSET = 4,                        -- Borda vem menos para dentro da carta
    
    -- Tamanho dos jokers nos slots ativos
    JOKER_SLOT_SCALE = 0.7,                          -- Jokers são 30% menores nos slots
    
    -- Cores de raridade para bordas
    RARITY_COLORS = {
        common = {0.7, 0.7, 0.7, 0.8},      -- Cinza
        uncommon = {0.2, 0.8, 0.2, 0.8},   -- Verde
        rare = {0.8, 0.2, 0.8, 0.8},       -- Roxo
        legendary = {0.8, 0.6, 0.2, 0.8},  -- Dourado
        basic = {0.5, 0.5, 0.5, 0.8}       -- Cinza escuro
    },
    
    -- Configurações de borda de raridade
    RARITY_BORDER_THICKNESS = 3,
    RARITY_BORDER_PULSE_RANGE = 0.4,
    RARITY_BORDER_ANIMATION_SPEED = 1.5,
}

-- Configurações de Áudio
Config.Audio = {
    HOVER_VOLUME = 0.03,
    DECK_START_VOLUME = 0.1,
    CLICK_SELECT_VOLUME = 0.2,
}

-- Configurações de Performance
Config.Performance = {
    -- Cache de recursos
    ENABLE_AUDIO_CACHE = true,
    ENABLE_FONT_CACHE = true,
}

-- Funções utilitárias para cálculos responsivos
Config.Utils = {
    -- Calcula tamanho responsivo com limite máximo
    getResponsiveSize = function(ratio, maxSize, dimension)
        local screenSize = dimension == "width" and love.graphics.getWidth() or love.graphics.getHeight()
        return math.min(maxSize, screenSize * ratio)
    end,
    
    -- Calcula posição centralizada
    getCenteredPosition = function(width, screenWidth)
        return (screenWidth - width) / 2
    end,
    
    -- Calcula posição relativa
    getRelativePosition = function(ratio, screenSize)
        return screenSize * ratio
    end
}

return Config

