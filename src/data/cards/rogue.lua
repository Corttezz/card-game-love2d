-- src/data/cards/rogue.lua
-- Classe Ladino. Fase 7: tags + effects. Arquetipos: poison / discard-cycle / exhaust.
-- Rebalance Jul/2026 (plano v2): WC Veneno destravada (2 commons novas + Mestre das
-- Toxinas legendary por-ataque), ciclo/burst afinado (bullet_time +2 mana) e
-- lifesteal in-class (Lamina Sanguessuga).

return {
    -- ========== COMMON ==========
    rogue_strike = {
        id = "rogue_strike", name = "Golpe Furtivo",
        type = "attack", subtype = "common",
        cost = 1, attack = 8, defense = 0,
        description = "Causa 8 de dano.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "common", class = "rogue",
        tags = { "strike" },
        effects = {},
    },
    rogue_defend = {
        id = "rogue_defend", name = "Esquiva",
        -- Rebalance Jul/2026: 6 -> 7 (era estritamente dominada por defense_001
        -- Iron Shield na mesma pool; rogue e quem mais morre no A2).
        type = "defense", subtype = "common",
        cost = 1, attack = 0, defense = 8,
        description = "Ganha 8 de Bloqueio.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "common", class = "rogue",
        tags = { "defend", "armor" },
        effects = {},
    },
    rogue_stiletto = {
        id = "rogue_stiletto", name = "Estilete",
        type = "attack", subtype = "common",
        cost = 1, attack = 5, defense = 0,
        description = "Causa 5 de dano. Conta em DOBRO para combos.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "common", class = "rogue",
        tags = { "strike", "combo" },
        effects = {},
    },
    rogue_survivor = {
        id = "rogue_survivor", name = "Sobrevivente",
        type = "defense", subtype = "skill",
        -- Rebalance Jul/2026: FIX DESC — o descarte e aleatorio (love.math.random
        -- na mao) e a desc omitia.
        cost = 1, attack = 0, defense = 9,
        description = "Ganha 9 de Bloqueio. Descarta 1 carta aleatória.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "common", class = "rogue",
        tags = { "defend", "armor", "discard", "cycle" },
        effects = {
            { type = "discard_cards", value = 1 },
        },
    },
    rogue_neutralize = {
        id = "rogue_neutralize", name = "Neutralizar",
        type = "attack", subtype = "skill",
        cost = 0, attack = 4, defense = 0,
        description = "Causa 4 de dano. Aplica Fraco por 1 turno.",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "rogue",
        tags = { "strike", "weak", "debuff", "zero_cost" },
        effects = {
            { type = "apply_debuff", value = "weak", stacks = 1, duration = 1 },
        },
    },
    rogue_backstab = {
        id = "rogue_backstab", name = "Punhalada pelas Costas",
        type = "attack", subtype = "skill",
        -- Out/2026 (balanceamento de classe): 11 -> 8. Gratis, inata e na
        -- abertura de TODA luta: era o pico do ladino no A1 e nada no A5 —
        -- o poder foi pra Toxinas, que cresce na luta.
        cost = 0, attack = 8, defense = 0,
        description = "Causa 8 de dano. Inato. Exaurir.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "common", class = "rogue",
        innate = true,
        tags = { "strike", "innate", "exhaust", "zero_cost", "finisher" },
        effects = {
            { type = "innate" },
            { type = "exhaust" },
        },
    },
    rogue_rake = {
        id = "rogue_rake", name = "Garra Rapida",
        type = "attack", subtype = "skill",
        cost = 1, attack = 7, defense = 0,
        description = "Causa 7 de dano. Aplica Fraco por 2 turnos.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "common", class = "rogue",
        tags = { "strike", "weak", "debuff" },
        effects = {
            { type = "apply_debuff", value = "weak", stacks = 1, duration = 2 },
        },
    },
    rogue_blue_elixir = {
        id = "rogue_blue_elixir", name = "Elixir Azul",
        -- Rebalance Jul/2026: FIX DOMINANCIA (era estritamente pior que adrenaline):
        -- +draw 1. C1: net +1 mana +1 carta — nicho distinto do C0 net +2 da Adrenalina.
        type = "effect", subtype = "potion",
        cost = 1, attack = 0, defense = 0,
        description = "Restaura 2 de mana e compra 1 carta. Exaurir.",
        image = "assets/cards/effect/manaCrystal.png",
        rarity = "common", class = "rogue",
        tags = { "mana", "potion", "utility" },
        effects = {
            { type = "restore_mana", value = 2 },
            { type = "draw_cards", value = 1 },
            { type = "exhaust" },
        },
    },

    -- Rebalance Jul/2026 (NOVA): primeira common de poison do jogo (70% dos rolls
    -- do A1 sao common e veneno tinha 0); C0 tambem alimenta triple_strike e o
    -- tempo zero-cost da classe.
    rogue_poison_dart = {
        id = "rogue_poison_dart", name = "Dardo Envenenado",
        type = "attack", subtype = "skill",
        cost = 0, attack = 2, defense = 0,
        description = "Causa 2 de dano. Aplica 3 de Veneno por 2 turnos.",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "rogue",
        tags = { "strike", "poison", "zero_cost" },
        effects = {
            { type = "apply_debuff", value = "poison", stacks = 3, duration = 2 },
        },
    },

    -- Rebalance Jul/2026 (NOVA): segunda common de poison — com 2 no tier common a
    -- afinidade (cap progressivo 0.9/1.2/1.5) tem o que puxar no A1; par com
    -- qualquer poison dispara poison_stack.
    rogue_dirty_blade = {
        id = "rogue_dirty_blade", name = "Lamina Suja",
        type = "attack", subtype = "skill",
        cost = 1, attack = 4, defense = 0,
        description = "Causa 4 de dano. Aplica 4 de Veneno por 2 turnos.",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "rogue",
        tags = { "strike", "poison", "debuff" },
        effects = {
            { type = "apply_debuff", value = "poison", stacks = 4, duration = 2 },
        },
    },

    -- ========== UNCOMMON ==========
    rogue_accuracy = {
        id = "rogue_accuracy", name = "Precisao",
        type = "joker", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        description = "+1 de dano em cartas de ataque.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "strike", "scaling" },
        effects = {
            { type = "damage_bonus", target = "attack", value = 1 },
        },
    },
    rogue_acrobatics = {
        id = "rogue_acrobatics", name = "Acrobacias",
        -- Rebalance Jul/2026: FIX DESC — descarte aleatorio nao declarado.
        type = "effect", subtype = "skill",
        cost = 1, attack = 0, defense = 0,
        description = "Compra 3 cartas. Descarta 1 carta aleatória.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "draw", "discard", "cycle" },
        effects = {
            { type = "draw_cards", value = 3 },
            { type = "discard_cards", value = 1 },
        },
    },
    rogue_adrenaline = {
        id = "rogue_adrenaline", name = "Adrenalina",
        type = "effect", subtype = "skill",
        -- Out/2026: custo 0 -> 1 (rende +1 de mana, nao +2, por luta).
        cost = 1, attack = 0, defense = 0,
        description = "Restaura 2 de mana. Exaurir.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "mana", "exhaust", "cycle" },
        effects = {
            { type = "restore_mana", value = 2 },
            { type = "exhaust" },
        },
    },
    rogue_blur = {
        id = "rogue_blur", name = "Borrao",
        type = "defense", subtype = "skill",
        cost = 1, attack = 0, defense = 8,
        description = "Ganha 8 de Bloqueio. Ganha 1 de Destreza.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "defend", "armor", "dexterity" },
        effects = {
            { type = "gain_dexterity", value = 1 },
        },
    },
    rogue_bouncing_flask = {
        id = "rogue_bouncing_flask", name = "Frasco Ricochete",
        -- Rebalance Jul/2026: BUFF (dominada em taxa por venom_fang): poison
        -- 3/2t -> 5/3t. Vira a opcao "mais veneno por carta" da build.
        type = "attack", subtype = "skill",
        cost = 2, attack = 6, defense = 0,
        description = "Causa 6 de dano. Aplica 6 de Veneno por 3 turnos.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "uncommon", class = "rogue",
        tags = { "strike", "poison", "debuff" },
        effects = {
            { type = "apply_debuff", value = "poison", stacks = 6, duration = 3 },
        },
    },
    rogue_calculated_gamble = {
        id = "rogue_calculated_gamble", name = "Aposta Calculada",
        type = "effect", subtype = "skill",
        cost = 0, attack = 0, defense = 0,
        description = "Descarta 3 cartas aleatórias. Compra 3.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "draw", "discard", "cycle", "zero_cost" },
        effects = {
            { type = "discard_cards", value = 3 },
            { type = "draw_cards", value = 3 },
        },
    },
    rogue_thorn_cloak = {
        id = "rogue_thorn_cloak", name = "Manto de Espinhos",
        type = "defense", subtype = "skill",
        cost = 1, attack = 0, defense = 6,
        description = "Ganha 6 de Bloqueio e arma 3 de Espinhos (o inimigo leva esse dano ao atacar).",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "defend", "thorn" },
        effects = {
            { type = "on_defend_damage", value = 3 },
        },
    },
    rogue_venom_coating = {
        id = "rogue_venom_coating", name = "Lamina Envenenada",
        type = "effect", subtype = "skill",
        cost = 1, attack = 0, defense = 0,
        description = "Aplica 5 de Veneno por 3 turnos.",
        image = "assets/cards/effect/potionOfHealing.png",
        rarity = "uncommon", class = "rogue",
        tags = { "poison", "debuff" },
        effects = {
            { type = "apply_debuff", value = "poison", stacks = 5, duration = 3 },
        },
    },
    rogue_twin_fangs = {
        id = "rogue_twin_fangs", name = "Presas Gemeas",
        -- Rebalance Jul/2026: FIX DESC — multi_hit e x2 no base (nao dispara
        -- Toxinas/Envenom 2x nem Forca por hit); desc deixa de prometer 2 golpes reais.
        type = "attack", subtype = "skill",
        cost = 2, attack = 5, defense = 0,
        description = "Causa 5 de dano 2 vezes. Aplica 2 de Veneno por 2 turnos.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "rogue",
        tags = { "strike", "poison" },
        effects = {
            { type = "multi_hit", value = 2 },
            { type = "apply_debuff", value = "poison", stacks = 2, duration = 2 },
        },
    },
    rogue_expose_weakness = {
        id = "rogue_expose_weakness", name = "Expor Fraqueza",
        type = "effect", subtype = "skill",
        cost = 1, attack = 0, defense = 0,
        description = "Aplica Vulnerável por 2 turnos. Compra 1 carta.",
        image = "assets/cards/effect/manaCrystal.png",
        rarity = "uncommon", class = "rogue",
        tags = { "vulnerable", "debuff", "draw" },
        effects = {
            { type = "apply_debuff", value = "vulnerable", stacks = 1, duration = 2 },
            { type = "draw_cards", value = 1 },
        },
    },
    rogue_shadow_dance = {
        id = "rogue_shadow_dance", name = "Danca das Sombras",
        type = "effect", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        description = "Ganha 2 de Destreza.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "dexterity", "scaling" },
        effects = {
            { type = "gain_dexterity", value = 2 },
        },
    },

    -- Rebalance Jul/2026 (NOVA): rogue tinha ZERO lifesteal no pool de classe —
    -- destrava lifesteal_burst e o arquetipo Vampiro (on_attack_heal em non-joker
    -- funciona via sourceCard, 1x por carta).
    rogue_leech_blade = {
        id = "rogue_leech_blade", name = "Lamina Sanguessuga",
        type = "attack", subtype = "skill",
        cost = 1, attack = 6, defense = 0,
        description = "Causa 6 de dano. Cura 2 de HP.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "rogue",
        tags = { "strike", "lifesteal" },
        effects = {
            { type = "on_attack_heal", value = 2, description = "Cura 2 ao atacar" },
        },
    },

    rogue_caltrops = {
        id = "rogue_caltrops", name = "Estrepes",
        type = "joker", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        description = "A primeira defesa de cada turno arma 3 de Espinhos.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "defend", "thorn" },
        effects = {
            { type = "on_defend_damage", value = 3 },
        },
    },
    rogue_catalyst = {
        id = "rogue_catalyst", name = "Catalisador",
        -- Auditoria Jul/2026: era type="attack" com attack=0 — ganhava a Forca
        -- do jogador como dano ESCONDIDO (0+str) e disparava a Toxina passiva.
        -- Carta de veneno puro e effect, e o texto volta a ser verdade.
        -- Rebalance Jul/2026: REDESIGN zero-engine (era trap dominada por
        -- venom_coating): stacks 3 -> 6. 18 de DoT 1x/batalha vs coating 12
        -- reciclavel — escolha real, o nuke que a build precisa cedo.
        type = "effect", subtype = "skill",
        cost = 1, attack = 0, defense = 0,
        description = "Aplica 7 de Veneno por 3 turnos. Exaurir.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "poison", "exhaust", "debuff" },
        effects = {
            { type = "apply_debuff", value = "poison", stacks = 7, duration = 3 },
            { type = "exhaust" },
        },
    },
    rogue_venom_fang = {
        id = "rogue_venom_fang", name = "Presa Venenosa",
        type = "attack", subtype = "skill",
        cost = 1, attack = 5, defense = 0,
        description = "Causa 5 de dano. Aplica 4 de Veneno por 3 turnos.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "uncommon", class = "rogue",
        tags = { "strike", "poison", "debuff" },
        effects = {
            { type = "apply_debuff", value = "poison", stacks = 4, duration = 3 },
        },
    },
    rogue_moonshadow = {
        id = "rogue_moonshadow", name = "Sombra da Lua",
        type = "defense", subtype = "skill",
        cost = 1, attack = 0, defense = 6,
        description = "Ganha 6 de Bloqueio. Compra 1 carta.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "rogue",
        tags = { "defend", "armor", "draw" },
        effects = {
            { type = "draw_cards", value = 1 },
        },
    },

    -- ========== RARE ==========
    rogue_executioner = {
        id = "rogue_executioner", name = "Carrasco",
        -- Rebalance Jul/2026: BUFF 22 -> 26 e movida pro bloco RARE (estava
        -- fisicamente no bloco UNCOMMON apesar de rarity="rare").
        type = "attack", subtype = "skill",
        cost = 3, attack = 30, defense = 0,
        description = "Causa 30 de dano.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "rogue",
        tags = { "strike", "finisher" },
        effects = {},
    },
    rogue_a_thousand_cuts = {
        id = "rogue_a_thousand_cuts", name = "Mil Cortes",
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "+3 de dano em cartas de ataque.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "rogue",
        tags = { "strike", "scaling", "combo" },
        effects = {
            { type = "damage_bonus", target = "attack", value = 3 },
        },
    },
    rogue_after_image = {
        id = "rogue_after_image", name = "Pos-imagem",
        type = "joker", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        description = "+4 de Bloqueio em cartas de defesa.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "rogue",
        tags = { "defend", "armor" },
        effects = {
            { type = "defense_bonus", target = "defense", value = 4 },
        },
    },
    rogue_bullet_time = {
        id = "rogue_bullet_time", name = "Tempo-bala",
        -- Rebalance Jul/2026: BUFF (fraca p/ rare vs acrobatics uncommon):
        -- +restore_mana 2; tag "finisher" removida (habilitava finisher_chain
        -- invisivel). O turno explosivo que o nome promete.
        type = "effect", subtype = "skill",
        cost = 2, attack = 0, defense = 0,
        description = "Compra 3 cartas. Restaura 2 de mana. Ganha 2 de Destreza. Exaurir.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "rogue",
        tags = { "draw", "dexterity", "exhaust", "cycle" },
        effects = {
            { type = "draw_cards", value = 3 },
            { type = "restore_mana", value = 2 },
            { type = "gain_dexterity", value = 2 },
            { type = "exhaust" },
        },
    },
    rogue_corpse_explosion = {
        id = "rogue_corpse_explosion", name = "Explosao de Cadaver",
        type = "attack", subtype = "skill",
        cost = 2, attack = 8, defense = 0,
        description = "Causa 8 de dano. Aplica 5 de Veneno por 3 turnos. Exaurir.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "rare", class = "rogue",
        tags = { "strike", "poison", "exhaust", "finisher" },
        effects = {
            { type = "apply_debuff", value = "poison", stacks = 5, duration = 3 },
            { type = "exhaust" },
        },
    },
    rogue_doppelganger = {
        id = "rogue_doppelganger", name = "Sosia",
        type = "effect", subtype = "skill",
        cost = 1, attack = 0, defense = 0,
        description = "Compra 2 cartas. Restaura 1 de mana.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "rogue",
        tags = { "draw", "mana", "cycle" },
        effects = {
            { type = "draw_cards", value = 2 },
            { type = "restore_mana", value = 1 },
        },
    },
    rogue_envenom = {
        id = "rogue_envenom", name = "Envenenar",
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "Cada carta de ataque aplica 1 de Veneno por 2 turnos.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "rogue",
        tags = { "poison", "debuff", "scaling" },
        effects = {
            { type = "on_attack_debuff", debuffName = "poison", stacks = 1, duration = 2,
              description = "Aplica 1 Veneno ao atacar" },
        },
    },
    rogue_storm_of_steel = {
        id = "rogue_storm_of_steel", name = "Tempestade de Aco",
        -- Rebalance Jul/2026: BUFF 8 -> 10. Unica strike-rare barata da classe
        -- merece o topo da banda.
        type = "attack", subtype = "skill",
        cost = 1, attack = 10, defense = 0,
        description = "Causa 10 de dano. Compra 1 carta.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "rare", class = "rogue",
        tags = { "strike", "draw", "cycle" },
        effects = {
            { type = "draw_cards", value = 1 },
        },
    },
    rogue_shooting_star = {
        id = "rogue_shooting_star", name = "Medalhao Estelar",
        -- Rebalance Jul/2026: REDESIGN — strength_scaling numa classe sem NENHUMA
        -- fonte de Forca era scaling morto; vira 8x2 (16 efetivo, topo da banda
        -- rare C2) com tag "combo" (peso 2x em countAllTags).
        type = "attack", subtype = "skill",
        cost = 2, attack = 8, defense = 0,
        description = "Causa 8 de dano 2 vezes.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "rare", class = "rogue",
        tags = { "strike", "combo", "finisher" },
        effects = {
            { type = "multi_hit", value = 2 },
        },
    },
    rogue_death_mark = {
        id = "rogue_death_mark", name = "Marca da Morte",
        -- NERF Set/2026 (dono: "carta coringa marca da morte e muito forte, no
        -- minimo ser considerada lendaria ou ter nerf"). Lifesteal 2 -> 1.
        --
        -- Ele estava certo, e a comparacao com os PARES mostra por que. Os dois
        -- efeitos disparam POR CARTA DE ATAQUE JOGADA (`damage_bonus` soma no
        -- pipeline de cada ataque; `on_attack_heal` e trigger chamado por carta
        -- em `processCardInCombat`) — nao 1x/turno. Com 3 ataques no turno a
        -- versao antiga dava +6 de dano E +6 de cura, sem condicao nenhuma.
        --
        --   Mil Cortes (ladino, RARA)        +3 dano
        --   Runa do Poder (mago, RARA)       +3 dano
        --   Porta-Estandarte (guerr., RARA)  +3 dano
        --   Senhor Vampiro (LENDARIA)        +3 de cura por ataque
        --   Marca da Morte (RARA)            +2 dano E +2 de cura   <- aqui
        --
        -- Ou seja: o dano de uma rara MAIS dois tercos de uma lendaria, na
        -- raridade das que entregam UMA coisa so. Nao era "uma rara forte", era
        -- duas raras numa.
        --
        -- ESCOLHI NERFAR EM VEZ DE PROMOVER A LENDARIA porque promover nao
        -- consertava a comparacao: mesmo como lendaria ela seguiria melhor que
        -- o Senhor Vampiro, que e lendario e so cura. E cortei a CURA, nao o
        -- dano, pra manter a identidade hibrida (strike + lifesteal) e deixar
        -- a troca explicita contra o par direto: contra Mil Cortes voce cede 1
        -- de dano por ataque e recebe 1 de HP. Isso e escolha; +2/+2 nao era.
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "+2 de dano em cartas de ataque. Cura 1 de HP ao atacar.",
        image = "assets/jokers/joker1.png",
        rarity = "rare", class = "rogue",
        tags = { "strike", "lifesteal", "scaling" },
        effects = {
            { type = "damage_bonus", target = "attack", value = 2 },
            { type = "on_attack_heal", value = 1 },
        },
    },

    -- ========== LEGENDARY ==========
    -- Rebalance Jul/2026 (NOVA): legendary de classe, capstone da WC Veneno —
    -- por-ataque MANTIDO (a regra 1x/turno do P2.3 e SO para on_defend_damage de
    -- joker); o quadratico ~7.5t^2 tem contra-jogo nativo: armor inimiga ABSORVE
    -- poison e o intent DEFEND congelado e o counter legivel.
    rogue_toxin_master = {
        id = "rogue_toxin_master", name = "Mestre das Toxinas",
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "Cada carta de ataque aplica 2 de Veneno por 2 turnos.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "legendary", class = "rogue",
        tags = { "poison", "debuff", "scaling", "passive" },
        effects = {
            { type = "on_attack_debuff", debuffName = "poison", stacks = 2, duration = 2,
              description = "Aplica 2 Veneno ao atacar" },
        },
    },
}
