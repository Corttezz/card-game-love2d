local Config = {}

Config.VERSION = "0.9.3"

Config.UI = {
    BUTTON_WIDTH_RATIO = 0.25,
    BUTTON_HEIGHT_RATIO = 0.08,
    BUTTON_SPACING_RATIO = 0.1,
    CARD_SPACING_RATIO = 0.15,
    CARD_START_X_RATIO = 0.1,
    CARD_Y_RATIO = 0.65,
    CARD_HOVER_OFFSET_RATIO = 0.12,
    CARD_SELECTED_OFFSET_RATIO = 0.1,
    PLAY_BUTTON_WIDTH_RATIO = 0.2,
    PLAY_BUTTON_HEIGHT_RATIO = 0.08,
    PLAY_BUTTON_X_RATIO = 0.5,
    PLAY_BUTTON_Y_RATIO = 0.8,
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

Config.Game = {
    INITIAL_HAND_SIZE = 5,
    CARDS_PER_TURN = 5,
    MAX_JOKER_SLOTS = 3,

    VICTORY_PHASES = 24,
    HEALTH_RESTORE_INTERVAL = 3,

    ENEMY_BASE_HEALTH = 18,
    ENEMY_BASE_DAMAGE = 5,
    ENEMY_HEALTH_SCALING = 15,
    ENEMY_DAMAGE_SCALING = 3,

    ENEMY_POWER = { damage = 1.0, health = 1.0 },
    ENEMY_POWER_BY_ACT = {
        [1] = { damage = 1.0, health = 2.0 },
        [2] = { damage = 0.95, health = 1.8 },
        [3] = { damage = 0.9, health = 1.45 },
        [4] = { damage = 0.9, health = 1.15 },
        [5] = { damage = 0.85, health = 0.95 },
        [6] = { damage = 0.85, health = 0.85 },
    },

    PLAYER_MAX_HEALTH = 60,
    CLASS_MAX_HEALTH = { warrior = 70 },
    PLAYER_MAX_ARMOR = 30,
    PLAYER_MAX_ARMOR_PER_ACT = 10,
    PLAYER_MAX_MANA = 3,
    PLAYER_HEALTH_RESTORE = 20,

    REST_HEAL_PCT = 0.30,
    POTIONS = false,
    POTION_SLOTS = 1,
    POTION_HEAL_PCT = 0.20,
    ELITE_RAMP = false,
    ELITE_RAMP_START = 1.4,

    UPGRADE_LEVEL_CAP = 0,

    BASE_SCORE_PER_PHASE = 100,

    MAX_MESSAGES = 3,
    MESSAGE_DURATION = 2.4,
}

Config.Acts = {
    {
        number = 1, name = "Catacumbas", floors = 8,
        enemyHP    = function(f) return 8 + f * 6 end,
        enemyDmg   = function(f) return 3 + f * 1.2 end,
        bossHP = 110, bossDmg = 12,
        eliteHPMul = 1.4, eliteDmgMul = 1.25,
        rarityWeights = { common = 70, uncommon = 25, rare = 5,  legendary = 0 },
        interActHeal = 0.30,
    },
    {
        number = 2, name = "Torre de Pedra", floors = 8,
        enemyHP    = function(f) return 60 + f * 10 end,
        enemyDmg   = function(f) return 9 + f * 1.5 end,
        bossHP = 220, bossDmg = 18,
        eliteHPMul = 1.6, eliteDmgMul = 1.3,
        rarityWeights = { common = 40, uncommon = 45, rare = 14, legendary = 1 },
        interActHeal = 0.40,
    },
    {
        number = 3, name = "Abismo", floors = 8,
        enemyHP    = function(f) return 150 + f * 15 end,
        enemyDmg   = function(f) return 18 + f * 2.5 end,
        bossHP = 420, bossDmg = 26,
        eliteHPMul = 1.7, eliteDmgMul = 1.4,
        rarityWeights = { common = 15, uncommon = 45, rare = 32, legendary = 8 },
        interActHeal = 0.40,
    },

    {
        number = 4, name = "Cidadela Gelada", floors = 8,
        enemyHP    = function(f) return 250 + f * 22 end,
        enemyDmg   = function(f) return 22 + f * 3.0 end,
        bossHP = 600, bossDmg = 33,
        eliteHPMul = 1.75, eliteDmgMul = 1.45,
        rarityWeights = { common = 10, uncommon = 40, rare = 38, legendary = 12 },
        interActHeal = 0.40,
    },
    {
        number = 5, name = "Coracao Putrido", floors = 8,
        enemyHP    = function(f) return 380 + f * 32 end,
        enemyDmg   = function(f) return 27 + f * 3.5 end,
        bossHP = 880, bossDmg = 38,
        eliteHPMul = 1.80, eliteDmgMul = 1.50,
        rarityWeights = { common = 5,  uncommon = 35, rare = 44, legendary = 16 },
        interActHeal = 0.40,
    },
    {
        number = 6, name = "Corte do Eclipse", floors = 8,
        enemyHP    = function(f) return 560 + f * 45 end,
        enemyDmg   = function(f) return 32 + f * 4.0 end,
        bossHP = 1200, bossDmg = 46,
        eliteHPMul = 1.85, eliteDmgMul = 1.50,
        rarityWeights = { common = 0,  uncommon = 28, rare = 50, legendary = 22 },
        interActHeal = 0.40,
    },
}

Config.Endless = {
    HP_LIN = 0.05, HP_QUAD = 0.0015,
    DMG_LIN = 0.03, DMG_QUAD = 0.0006,
    scalingMultiplier = 1.18,
    rarityWeights = { common = 10, uncommon = 35, rare = 45, legendary = 10 },
    healPercent = 0.30,
}

Config.TotalActs = 6

Config.Economy = {
    VICTORY_GOLD_BASE    = 5,
    VICTORY_GOLD_PER_ACT = 2,
    FULL_HP_BONUS        = 3,

    ELITE_BONUS_MULT    = 1,
    MINIBOSS_BONUS_MULT = 0,
    BOSS_BONUS_MULT     = 1,

    DICE = {
        PAYOUT = { low = 2.5, seven = 6, high = 2.5 },
        STAKES = { 4, 8, 16 },
        STAKE_PER_ACT = 0.3,
    },
}

function Config.Economy.victoryGold(act)
    act = math.max(1, math.floor(tonumber(act) or 1))
    return Config.Economy.VICTORY_GOLD_BASE
        + Config.Economy.VICTORY_GOLD_PER_ACT * (act - 1)
end

function Config.Economy.nodeBonus(nodeType, act)
    local mult = 0
    if nodeType == "elite" then
        mult = Config.Economy.ELITE_BONUS_MULT or 0
    elseif nodeType == "mini_boss" then
        mult = Config.Economy.MINIBOSS_BONUS_MULT or 0
    elseif nodeType == "boss" then
        mult = Config.Economy.BOSS_BONUS_MULT or 0
    end
    return math.floor(mult * Config.Economy.victoryGold(act))
end

Config.Offers = {
    PITY_STEP = 0.35,
    HARD_PITY = 25,

    AFFINITY_PER_TAG   = 0.20,
    AFFINITY_CAP       = 0.60,
    AFFINITY_MIN_COUNT = 2,

    DUPE_PENALTY   = 0.5,
    DUPE_THRESHOLD = 2,

    SUSTAIN_GUARANTEE   = true,
    SUSTAIN_WEIGHT_BONUS = 1.0,
    SUSTAIN_MIN_SOURCES = 2,

    DAILY_SALE     = true,
    DAILY_SALE_PCT = 0.25,

    FORGE_COST_BASE = 5,
    FORGE_COST_MULT = 1.35,
    FORGE_COST_MAX  = 60,

    FORGE_ATK_PER_LVL    = 2,
    FORGE_DEF_PER_LVL    = 2,
    FORGE_EFFECT_PER_LVL = 1,

    SERVICES = {
        remove_card    = { base = 8,  mult = 1.45, max = 45, maxPerRun = 0, minDeck = 3 },
        duplicate_card = { base = 12, mult = 1.55, max = 60, maxPerRun = 0 },
        joker_slot     = { base = 20, mult = 1.75, max = 60, maxPerRun = 2 },
        card_draw_upgrade   = { base = 22, mult = 2.0,  max = 60, maxPerRun = 2 },
        interest_cap        = { base = 25, mult = 1.65, max = 150, maxPerRun = 0 },
    },

    INTEREST_CAP_PER_BUY = 2,
    INTEREST_CAP_MAX = 25,
}

Config.Cards = {
    BASE_SCALE = 1.333,
    HOVER_SCALE = 1.466,

    SCALE_ANIMATION_SPEED = 10,
    MOVE_RANGE = 8,
    TILT_RANGE = 0.15,

    PERSPECTIVE_STRENGTH = 0.25,
    DEPTH_OFFSET = 15,
    ROTATION_SPEED = 8,
    SHADOW_INTENSITY = 0.8,

    SHADOW_OFFSET_BASE_X = -20,
    SHADOW_OFFSET_BASE_Y = 30,
    SHADOW_STRETCH_X = 8,
    SHADOW_STRETCH_Y = 8,
    SHADOW_SCALE_BASE = 0.9,
    SHADOW_SCALE_VARIATION = 0.15,

    DEPTH_TILT_X = 0.12,
    DEPTH_TILT_Y = 0.08,
    LIFT_AMOUNT = 25,

    PLAYABLE_BORDER_COLOR = {0.3, 0.6, 0.9, 0.8},
    PLAYABLE_BORDER_THICKNESS = 4,

    BORDER_ANIMATION_SPEED = 2.0,
    BORDER_PULSE_RANGE = 0.3,
    BORDER_INNER_OFFSET = 4,

    JOKER_SLOT_SCALE = 0.7,

    RARITY_COLORS = {
        common = {0.7, 0.7, 0.7, 0.8},
        uncommon = {0.2, 0.8, 0.2, 0.8},
        rare = {0.8, 0.2, 0.8, 0.8},
        legendary = {0.8, 0.6, 0.2, 0.8},
        basic = {0.5, 0.5, 0.5, 0.8}
    },

    RARITY_BORDER_THICKNESS = 3,
    RARITY_BORDER_PULSE_RANGE = 0.4,
    RARITY_BORDER_ANIMATION_SPEED = 1.5,

    CORNER_CUT = 3,
    HOVER_BOB_AMOUNT = 1.5,
    HOVER_BOB_SPEED = 2.5,
    SCALE_EASE_K = 12,
    VEL_TILT_GAIN = 0.0003,
    VEL_TILT_MAX = 0.15,
    VEL_TILT_DAMP = 8,
    DRAG_THRESHOLD_PX = 6,
    DRAG_SCALE_BOOST = 0.08,

    AMBIENT_TILT_SPEED = 1.4,
    AMBIENT_TILT_AMOUNT = 0.02,

    BASE_LIFT = 3,
    SHADOW_MAX_HORIZ_OFFSET = 20,
    SHADOW_BASE_OFFSET_Y = 6,
    SHADOW_PRESS_SHIFT = 14,
    SHADOW_ALPHA = 0.50,

    PRESS_SHEAR_STRENGTH = 0.10,

    MESH_COLS = 8,
    MESH_ROWS = 12,
    PRESS_WARP_STRENGTH = 0.25,
    HOVER_STRENGTH_EASE_K = 14,
}

Config.Audio = {
    HOVER_VOLUME = 0.03,
    DECK_START_VOLUME = 0.1,
    CLICK_SELECT_VOLUME = 0.2,

    CARD_PLAY_ATTACK_VOLUME = 0.55,
    CARD_PLAY_DEFENSE_VOLUME = 0.55,
    CARD_DRAW_VOLUME = 0.35,
    CARD_EXHAUST_VOLUME = 0.5,
    COMBO_TRIGGER_VOLUME = 0.5,
    JOKER_ACTIVATE_VOLUME = 0.55,
    ORB_CHANNEL_VOLUME = 0.5,
    ORB_EVOKE_VOLUME = 0.6,
    DEBUFF_APPLIED_VOLUME = 0.5,
    STRENGTH_GAIN_VOLUME = 0.55,
    POISON_TICK_VOLUME = 0.45,
    ENEMY_ATTACK_VOLUME = 0.6,
    ENEMY_DEATH_VOLUME = 0.48,
    CARD_EXPLODE_VOLUME = 0.45,
    BUTTON_CLICK_VOLUME = 0.4,
    MENU_OPEN_VOLUME = 0.45,
    MENU_CLOSE_VOLUME = 0.4,
    MENU_HOVER_VOLUME = 0.15,
    COLLECTION_FLIP_VOLUME = 0.5,
    PURCHASE_CONFIRM_VOLUME = 0.6,
    CARD_DISCOVERED_VOLUME = 0.55,
    AMBIENT_VOLUME = 0.09,
    PLACE_VOLUME = 0.75,
    WEATHER_VOLUME = 0.8,
    PURCHASE_DENY_VOLUME = 0.4,
    BATTLE_VICTORY_VOLUME = 0.45,
    GOLD_GAIN_VOLUME = 0.55,
    NODE_SELECT_VOLUME = 0.45,
    REST_COMPLETE_VOLUME = 0.55,
    ACT_COMPLETE_VOLUME = 0.7,
    RUN_VICTORY_VOLUME = 0.75,
    RUN_DEFEAT_VOLUME = 0.65,
}

Config.Lighting = {
    WINDOW  = { radiusK = 0.16, color = { 1.00, 0.72, 0.35 }, intensity = 0.55,
                anchors = { { 0.36, 0.52 }, { 0.64, 0.52 }, { 0.50, 0.82 } } },
    FIREFLY = { radius = 6, intensity = 0.45 },
    EMBER   = { radius = 6, intensity = 0.45 },
}

Config.Performance = {
    ENABLE_AUDIO_CACHE = true,
    ENABLE_FONT_CACHE = true,
}

Config.Utils = {
    getResponsiveSize = function(ratio, maxSize, dimension)
        local screenSize = dimension == "width" and love.graphics.getWidth() or love.graphics.getHeight()
        return math.min(maxSize, screenSize * ratio)
    end,

    getCenteredPosition = function(width, screenWidth)
        return (screenWidth - width) / 2
    end,

    getRelativePosition = function(ratio, screenSize)
        return screenSize * ratio
    end,

    tamanhoJanelaInicial = function(desktopW, desktopH, larguraAtual, fracao)
        if not desktopW or not desktopH then return nil end
        if desktopW <= 0 or desktopH <= 0 then return nil end
        local f = fracao or 0.85
        local w = math.floor(desktopW * f)
        local h = math.floor(desktopH * f)
        if w < 800 or h < 600 then return nil end
        if larguraAtual and larguraAtual >= w then return nil end
        return w, h
    end
}

return Config
