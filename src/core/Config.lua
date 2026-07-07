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
    -- Cartas iniciais (Fase 5: hand maior pra compensar deck pequeno de 2 cartas)
    INITIAL_HAND_SIZE = 4,
    MAX_JOKER_SLOTS = 3,

    -- Fases: Fase 5 trocou o cap de 10 por estrutura de atos (ver Config.Acts).
    -- VICTORY_PHASES mantido por retrocompatibilidade (usado no modo classic sem run).
    VICTORY_PHASES = 24, -- 3 atos x 8 andares
    HEALTH_RESTORE_INTERVAL = 3,

    -- Fallback de inimigos (modo classic sem run). Run mode usa Config.Acts.
    ENEMY_BASE_HEALTH = 18,
    ENEMY_BASE_DAMAGE = 5,
    ENEMY_HEALTH_SCALING = 15,
    ENEMY_DAMAGE_SCALING = 3,

    -- Jogador: Fase 5 reduziu HP inicial (60 vs 100). Deck pequeno + curva mais
    -- apertada cria pressao pra tomar decisoes boas nas escolhas de nos.
    PLAYER_MAX_HEALTH = 60,
    PLAYER_MAX_ARMOR = 50,
    PLAYER_MAX_MANA = 3,
    PLAYER_HEALTH_RESTORE = 20,

    -- Pontuação
    BASE_SCORE_PER_PHASE = 100,

    -- Sistema de mensagens
    MAX_MESSAGES = 5,
    MESSAGE_DURATION = 3.0,
}

-- ===== Fase 5: Atos, curvas de dificuldade e endless =====
--
-- Cada ato tem floors (qtd de andares), fórmulas de HP/dano por andar, boss
-- com stats especificos, pesos de raridade na geracao de ofertas, e cura inter-ato.
--
-- As fórmulas recebem `f` = floorInAct (1..floors). Boss e evaluado com f=floors.
-- Scaling e rate de cura documentados em memory/balance_curves.md.

-- Curvas calibradas para deck pequeno (starter=2, cresce ~1 por andar).
-- Meta: floor normal ato 1 cai em 2-3 turnos; boss ato 1 em 6-10 turnos;
-- floor normal ato 3 em 4-5 turnos; boss ato 3 em 8-12 turnos.
Config.Acts = {
    {
        number = 1, name = "Catacumbas", floors = 8,
        enemyHP    = function(f) return 8 + f * 6 end,    -- f=1: 14, f=8: 56
        enemyDmg   = function(f) return 3 + f * 1.2 end,  -- f=1: 4, f=8: 12
        bossHP = 140, bossDmg = 14,
        eliteHPMul = 1.6, eliteDmgMul = 1.3,
        rarityWeights = { common = 70, uncommon = 25, rare = 5,  legendary = 0 },
        interActHeal = 0.30,
    },
    {
        number = 2, name = "Torre de Pedra", floors = 8,
        enemyHP    = function(f) return 60 + f * 10 end,  -- f=1: 70, f=8: 140
        enemyDmg   = function(f) return 9 + f * 1.5 end,  -- f=1: 10, f=8: 21
        bossHP = 300, bossDmg = 22,
        eliteHPMul = 1.6, eliteDmgMul = 1.3,
        rarityWeights = { common = 40, uncommon = 45, rare = 14, legendary = 1 },
        interActHeal = 0.40,
    },
    {
        number = 3, name = "Abismo", floors = 8,
        enemyHP    = function(f) return 150 + f * 15 end, -- f=1: 165, f=8: 270
        enemyDmg   = function(f) return 18 + f * 2.5 end, -- f=1: 20, f=8: 38
        bossHP = 500, bossDmg = 32,
        eliteHPMul = 1.7, eliteDmgMul = 1.4,
        rarityWeights = { common = 15, uncommon = 45, rare = 32, legendary = 8 },
        interActHeal = 0.40,
    },
}

Config.Endless = {
    -- HP e dano crescem exponencial apos o ato 3. O contador de endless comeca
    -- em floorInAct=1 com actNumber=4 (ver RunManager:advanceFloorInAct).
    scalingMultiplier = 1.18, -- HP e dmg *= 1.18 por andar
    -- Raridades favorecem o alto-nivel mas comum ainda aparece (sem tirar o "floor" de oferta).
    rarityWeights = { common = 10, uncommon = 35, rare = 45, legendary = 10 },
    -- Interactos virtuais: endless nao tem "atos", mas cura simbolica a cada 5 andares.
    healEveryNFloors = 5, healPercent = 0.20,
}

-- Total de atos (excluindo endless). Usado por RunManager:advanceFloorInAct.
Config.TotalActs = 3

-- Configurações das Cartas
Config.Cards = {
    -- Escalas (alvo: cartas procedurais são 96×144 → base 1.33 ≈ 128×192 na tela,
    -- preservando o mesmo espaço ocupado pelo layout legado de 64×96×2.0).
    BASE_SCALE = 1.333,
    HOVER_SCALE = 1.466,
    
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

    -- ===== Polish (Balatro-like) =====
    CORNER_CUT = 3,              -- stepped cut dos cantos no canvas lógico (96×144)
    HOVER_BOB_AMOUNT = 1.5,      -- ±px vertical da micro-oscilação ao hover
    HOVER_BOB_SPEED = 2.5,       -- freq em rad/s
    SCALE_EASE_K = 12,           -- exp decay pro scale (antes era lerp linear 10*dt)
    VEL_TILT_GAIN = 0.0003,      -- quanto a velocidade X converte em tilt (clamped)
    VEL_TILT_MAX = 0.15,
    VEL_TILT_DAMP = 8,           -- exp decay do tilt quando a carta pára
    DRAG_THRESHOLD_PX = 6,       -- distância que promove mouse-down a drag
    DRAG_SCALE_BOOST = 0.08,     -- +8% scale na carta enquanto arrastada

    -- ===== Ambient tilt (cartas ociosas respiram — Balatro) =====
    -- Só aplica quando NÃO hovered. Senóide defasada por seed aleatório
    -- pra cartas da mão não oscilarem em sync.
    AMBIENT_TILT_SPEED = 1.4,    -- freq em rad/s (devagar, orgânico)
    AMBIENT_TILT_AMOUNT = 0.02,  -- amplitude em radianos (~1.1°, sutil)

    -- ===== Floating / Shadow (Balatro-accurate) =====
    BASE_LIFT = 3,               -- carta flutua sempre ~3px acima da mesa (idle)
    SHADOW_MAX_HORIZ_OFFSET = 20,-- deslocamento máx horizontal da sombra (carta nas bordas)
    SHADOW_BASE_OFFSET_Y = 6,    -- deslocamento vertical base da sombra
    SHADOW_PRESS_SHIFT = 14,     -- deslocamento extra baseado em tilt (press): press direita → sombra esquerda
    SHADOW_ALPHA = 0.50,         -- opacidade da sombra (não preta pura)

    -- ===== Press-hover (shear 3D fake, só usado como fallback se shader falhar) =====
    PRESS_SHEAR_STRENGTH = 0.10, -- intensidade do shear baseado em tilt

    -- ===== Perspective warp (Balatro-accurate via vertex shader) =====
    MESH_COLS = 8,               -- tessellation horizontal
    MESH_ROWS = 12,              -- tessellation vertical
    PRESS_WARP_STRENGTH = 0.25,  -- amplitude do warp (tunável pelo shader)
    HOVER_STRENGTH_EASE_K = 14,  -- ease-out exp pra hoverStrength (0..1)
}

-- Configurações de Áudio
Config.Audio = {
    HOVER_VOLUME = 0.03,
    DECK_START_VOLUME = 0.1,
    CLICK_SELECT_VOLUME = 0.2,

    -- SFX gerados via ElevenLabs (audio/sfx/)
    CARD_PLAY_ATTACK_VOLUME = 0.55,
    CARD_PLAY_DEFENSE_VOLUME = 0.55,
    CARD_DRAW_VOLUME = 0.35,
    CARD_EXHAUST_VOLUME = 0.5,
    COMBO_TRIGGER_VOLUME = 0.65,
    JOKER_ACTIVATE_VOLUME = 0.55,
    ORB_CHANNEL_VOLUME = 0.5,
    ORB_EVOKE_VOLUME = 0.6,
    DEBUFF_APPLIED_VOLUME = 0.5,
    STRENGTH_GAIN_VOLUME = 0.55,
    POISON_TICK_VOLUME = 0.45,
    ENEMY_ATTACK_VOLUME = 0.6,
    ENEMY_DEATH_VOLUME = 0.65,
    BUTTON_CLICK_VOLUME = 0.4,
    MENU_OPEN_VOLUME = 0.45,
    MENU_CLOSE_VOLUME = 0.4,
    MENU_HOVER_VOLUME = 0.15,
    COLLECTION_FLIP_VOLUME = 0.5,
    PURCHASE_CONFIRM_VOLUME = 0.6,
    PURCHASE_DENY_VOLUME = 0.4,
    BATTLE_VICTORY_VOLUME = 0.6,
    GOLD_GAIN_VOLUME = 0.55,
    NODE_SELECT_VOLUME = 0.45,
    REST_COMPLETE_VOLUME = 0.55,
    ACT_COMPLETE_VOLUME = 0.7,
    RUN_VICTORY_VOLUME = 0.75,
    RUN_DEFEAT_VOLUME = 0.65,
}

-- LightEngine v1 (docs/plan/lighting-engine-v1.md) — tuning das fontes de luz
-- do WorldRoad. O motor em si vive em engine/LightEngine.lua; a cor ambiente
-- por bioma vive em src/data/biomes.lua (campo lightAmbient).
Config.Lighting = {
    -- v9: LANTERN/BRAZIER/POOL_MIN_T migraram pro LuminaireEngine
    -- (engine/LuminaireEngine.lua) — luz de prop decorativo agora é
    -- catálogo POR BIOMA com 2-3 tipos cada.
    -- janelas do castelo: micro-luzes POR janela (raio ∝ largura do castelo);
    -- âncoras default {xr, yr} relativas ao sprite — biomes.lua pode
    -- sobrescrever com lightWindows
    WINDOW  = { radiusK = 0.16, color = { 1.00, 0.72, 0.35 }, intensity = 0.55,
                anchors = { { 0.36, 0.52 }, { 0.64, 0.52 }, { 0.50, 0.82 } } },
    -- tímido: vagalume é detalhe, não farol (feedback Jul/2026)
    FIREFLY = { radius = 6, intensity = 0.45 },
    EMBER   = { radius = 6, intensity = 0.45 },
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

