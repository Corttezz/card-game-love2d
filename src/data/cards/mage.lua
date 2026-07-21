-- src/data/cards/mage.lua
-- Classe Mago. Fase 7: tags + effects baseados em channel/evoke/magic/heal.

return {
    -- ========== COMMON ==========
    mage_zap = {
        id = "mage_zap", name = "Descarga",
        type = "attack", subtype = "common",
        cost = 1, attack = 7, defense = 0,
        description = "7 de dano. Canaliza 1 Raio (3 pot).",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "mage",
        tags = { "strike", "channel", "lightning" },
        effects = {
            { type = "channel_orb", orbType = "lightning", value = 3 },
        },
    },
    mage_dualcast = {
        id = "mage_dualcast", name = "Conjuracao Dupla",
        -- Rebalance v2 Jul/2026: era trap no meta pos-pulso (evocar cedo
        -- destruia pulsos futuros). Agora evoca E repoe o slot — tempo
        -- neutro com burst, sem engine nova.
        type = "effect", subtype = "common",
        cost = 1, attack = 0, defense = 0,
        description = "Evoca o orbe mais antigo e canaliza 1 Raio (pot 3).",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "mage",
        tags = { "evoke", "channel", "lightning", "magic" },
        effects = {
            { type = "evoke_orb" },
            { type = "channel_orb", orbType = "lightning", value = 3 },
        },
    },
    mage_ball_lightning = {
        id = "mage_ball_lightning", name = "Raio Esferico",
        -- Rebalance v2 Jul/2026: nao superava as commons zap/lightning.
        -- attack 7->8, pot 4->5 pra valer o slot uncommon.
        type = "attack", subtype = "skill",
        cost = 1, attack = 8, defense = 0,
        description = "Causa 8 de dano. Canaliza 1 Raio (pot 5).",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        tags = { "strike", "channel", "lightning" },
        effects = {
            { type = "channel_orb", orbType = "lightning", value = 5 },
        },
    },
    mage_lightning = {
        id = "mage_lightning", name = "Relampago",
        type = "attack", subtype = "common",
        cost = 1, attack = 8, defense = 0,
        description = "8 de dano. Canaliza Raio (2 pot).",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "mage",
        tags = { "strike", "channel", "lightning" },
        effects = {
            { type = "channel_orb", orbType = "lightning", value = 2 },
        },
    },
    mage_fireball = {
        id = "mage_fireball", name = "Bola de Fogo",
        type = "attack", subtype = "common",
        -- Rebalance v2 Jul/2026: fix de desc apenas — e type=attack (escala
        -- com Forca/jokers), "dano magico" mentia; declara a potencia do orbe.
        cost = 2, attack = 11, defense = 0,
        description = "Causa 11 de dano. Canaliza 1 Fogo (pot 3).",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "mage",
        tags = { "strike", "channel", "fire", "magic" },
        effects = {
            { type = "channel_orb", orbType = "fire", value = 3 },
        },
    },
    mage_flame_tongue = {
        id = "mage_flame_tongue", name = "Lingua de Chamas",
        -- Rebalance v2 Jul/2026: vulnerable 1t morria no onTurnEnd antes de
        -- pagar; duration 1->2 abre a janela real.
        type = "attack", subtype = "common",
        cost = 1, attack = 6, defense = 0,
        description = "Causa 6 de dano. Aplica Vulneravel por 2 turnos.",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "mage",
        tags = { "strike", "fire", "debuff" },
        effects = {
            { type = "apply_debuff", value = "vulnerable", stacks = 1, duration = 2 },
        },
    },
    mage_magic_barrier = {
        id = "mage_magic_barrier", name = "Amuleto Arcano",
        type = "defense", subtype = "skill",
        cost = 1, attack = 0, defense = 8,
        description = "8 de Bloqueio magico.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "common", class = "mage",
        tags = { "defend", "armor", "magic" },
        effects = {},
    },
    mage_arcane_orb = {
        id = "mage_arcane_orb", name = "Orbe Arcano",
        type = "effect", subtype = "orb",
        cost = 1, attack = 0, defense = 0,
        description = "Canaliza 1 orb escuro (pot 3).",
        image = "assets/cards/effect/manaCrystal.png",
        rarity = "common", class = "mage",
        tags = { "channel", "dark", "magic" },
        effects = {
            { type = "channel_orb", orbType = "dark", value = 3 },
        },
    },
    mage_healing_drop = {
        id = "mage_healing_drop", name = "Gota Curativa",
        -- Rebalance v2 Jul/2026: era dominada por effect_healing_potion
        -- (15 HP pelo mesmo custo). Vira a porta de entrada do orbe HOLY
        -- (engine completa, 0 cartas usavam): cura menor mas RECICLAVEL
        -- (sem exhaust) + pulso de cura/3 por turno via orbPassiveTick.
        type = "effect", subtype = "skill",
        cost = 1, attack = 0, defense = 0,
        description = "Cura 6 de HP. Canaliza 1 orbe Sagrado (pot 3).",
        image = "assets/cards/effect/potionOfHealing.png",
        rarity = "common", class = "mage",
        tags = { "heal", "channel", "holy", "magic" },
        effects = {
            { type = "instant_heal", value = 6 },
            { type = "channel_orb", orbType = "holy", value = 3 },
        },
    },

    -- ========== UNCOMMON ==========
    mage_torn_pages = {
        id = "mage_torn_pages", name = "Paginas Rasgadas",
        type = "effect", subtype = "skill",
        cost = 0, attack = 0, defense = 0,
        description = "Descarta 1 carta aleatoria. Compre 2.",
        image = "assets/cards/effect/manaCrystal.png",
        rarity = "uncommon", class = "mage",
        tags = { "discard", "draw", "cycle", "zero_cost" },
        effects = {
            { type = "discard_cards", value = 1 },
            { type = "draw_cards", value = 2 },
        },
    },
    mage_aggregate = {
        id = "mage_aggregate", name = "Agregar",
        type = "effect", subtype = "skill",
        cost = 1, attack = 0, defense = 0,
        description = "Compra 2 cartas. Canaliza 1 orbe arcano (pot 2).",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        tags = { "draw", "channel", "dark", "utility" },
        effects = {
            { type = "draw_cards", value = 2 },
            { type = "channel_orb", orbType = "dark", value = 2 },
        },
    },
    mage_auto_shields = {
        id = "mage_auto_shields", name = "Escudos Automaticos",
        type = "defense", subtype = "power",
        cost = 1, attack = 0, defense = 11,
        description = "11 de Bloqueio. +1 Destreza.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "mage",
        tags = { "defend", "armor", "dexterity" },
        effects = {
            { type = "gain_dexterity", value = 1 },
        },
    },
    mage_blizzard = {
        id = "mage_blizzard", name = "Nevasca",
        -- Auditoria Jul/2026: era type="attack" com attack=0 (ganhava Forca
        -- escondida). Dano magico e effect — nao escala com Forca (identidade).
        -- Rebalance v2 Jul/2026: dano flat que nao escala com nada precisa de
        -- numero honesto pro A3 (10->14); tag 'aoe' removida (jogo single-enemy).
        type = "effect", subtype = "skill",
        cost = 2, attack = 0, defense = 0,
        description = "Causa 14 de dano magico (fixo). Canaliza 1 Gelo (pot 4).",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        tags = { "magic", "ice", "channel" },
        effects = {
            { type = "aoe_magic_damage", value = 14 },
            { type = "channel_orb", orbType = "ice", value = 4 },
        },
    },
    mage_boot_sequence = {
        id = "mage_boot_sequence", name = "Sequencia de Boot",
        type = "effect", subtype = "skill",
        cost = 0, attack = 0, defense = 0,
        description = "Inato. Canaliza 1 orbe de Raio.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        innate = true,
        tags = { "innate", "channel", "lightning", "zero_cost" },
        effects = {
            { type = "channel_orb", orbType = "lightning", value = 3 },
            { type = "innate" },
        },
    },
    mage_chill = {
        id = "mage_chill", name = "Congelar",
        type = "effect", subtype = "skill",
        cost = 0, attack = 0, defense = 0,
        description = "Inato. Canaliza 1 orbe de Gelo.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        innate = true,
        tags = { "innate", "channel", "ice", "zero_cost" },
        effects = {
            { type = "channel_orb", orbType = "ice", value = 3 },
            { type = "innate" },
        },
    },
    mage_overcharge = {
        id = "mage_overcharge", name = "Sobrecarga",
        -- Auditoria Jul/2026: era estritamente pior que Descarga (2 mana:
        -- 9+pot3 vs 1 mana: 7+pot3). Pot 3->6 da identidade de "carga
        -- pesada" e paga o custo 2.
        type = "attack", subtype = "skill",
        cost = 2, attack = 9, defense = 0,
        description = "9 de dano. Canaliza 1 Raio (pot 6).",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        tags = { "strike", "magic", "lightning", "channel" },
        effects = {
            { type = "channel_orb", orbType = "lightning", value = 6 },
        },
    },
    mage_arcane_focus = {
        id = "mage_arcane_focus", name = "Foco Arcano",
        -- Auditoria Jul/2026: era clone do Grito de Guerra (+2 Forca). Agora
        -- concede FOCO (+1 potencia por orbe evocado) — o eixo de scaling do
        -- mago que o nome sempre prometeu. Ver _evokeOrbEffect.
        type = "effect", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        description = "Ganhe 2 de Foco nesta batalha.",
        image = "assets/cards/effect/manaCrystal.png",
        rarity = "uncommon", class = "mage",
        tags = { "magic", "scaling" },
        effects = {
            { type = "apply_buff", value = "focus", stacks = 2, duration = 99 },
        },
    },
    mage_mind_spike = {
        id = "mage_mind_spike", name = "Estaca Mental",
        -- Rebalance v2 Jul/2026: attack 10->12, sobe ao meio da banda
        -- uncommon C2.
        type = "attack", subtype = "skill",
        cost = 2, attack = 12, defense = 0,
        description = "Causa 12 de dano. Compre 1 carta.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        tags = { "magic", "draw" },
        effects = {
            { type = "draw_cards", value = 1 },
        },
    },
    mage_twin_bolts = {
        id = "mage_twin_bolts", name = "Raios Gemeos",
        -- Rebalance v2 Jul/2026: attack 7->9, pot 2->3 (18 efetivo + orbe =
        -- banda rare C2). Desc corrigida: multi_hit e x2 no base, nao 2
        -- golpes reais — deixa de prometer multihit que nao existe.
        type = "attack", subtype = "skill",
        cost = 2, attack = 9, defense = 0,
        description = "Causa 18 de dano em 2 raios. Canaliza 1 Raio (pot 3).",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "mage",
        tags = { "magic", "lightning", "channel" },
        effects = {
            { type = "multi_hit", value = 2 },
            { type = "channel_orb", orbType = "lightning", value = 3 },
        },
    },
    mage_arcane_torrent = {
        id = "mage_arcane_torrent", name = "Torrente Arcana",
        -- Rebalance v2 Jul/2026: rare vanilla no piso, attack 22->26. Pico
        -- pos-largest-wins: 26 x1.5 (magic_focus) x1.5 (MAIOR joker) = 58;
        -- x1.5 vulnerable = 87. Tripwire: mage >65% vitoria -> reverter 22.
        type = "attack", subtype = "skill",
        cost = 3, attack = 26, defense = 0,
        description = "Causa 26 de dano.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "mage",
        tags = { "magic", "finisher" },
        effects = {},
    },

    mage_consume = {
        id = "mage_consume", name = "Consumir",
        -- Auditoria Jul/2026: gain_strength -> Foco (mago escala orbe, nao
        -- musculo). Ordem: Foco ANTES do evoke pra ja valer nesta evocacao.
        type = "effect", subtype = "skill",
        cost = 2, attack = 0, defense = 0,
        description = "Ganhe 2 de Foco. Evoca TODOS os orbes.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        tags = { "evoke", "magic", "scaling" },
        effects = {
            { type = "apply_buff", value = "focus", stacks = 2, duration = 99 },
            { type = "evoke_all_orbs" },
        },
    },
    mage_doom_and_gloom = {
        id = "mage_doom_and_gloom", name = "Perdicao e Melancolia",
        -- Rebalance v2 Jul/2026: fix desc/tags — tag 'aoe' removida (jogo
        -- single-enemy); desc declara a potencia da Sombra. Numeros ficam.
        type = "attack", subtype = "skill",
        cost = 2, attack = 10, defense = 0,
        description = "Causa 10 de dano. Canaliza 1 Sombra (pot 5).",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        tags = { "strike", "channel", "dark" },
        effects = {
            { type = "channel_orb", orbType = "dark", value = 5 },
        },
    },
    mage_force_field = {
        id = "mage_force_field", name = "Campo de Forca",
        -- Rebalance v2 Jul/2026: era dominada por auto_shields. defense
        -- 14->16 e vira o PRIMEIRO payoff de Destreza do jogo: dexterity_
        -- scaling (Destreza conta em DOBRO via scaledStat, effect que tinha
        -- 0 usos) no lugar do gain_dexterity +1.
        type = "defense", subtype = "skill",
        cost = 2, attack = 0, defense = 16,
        description = "Ganha 16 de Bloqueio. Destreza conta em DOBRO.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "mage",
        tags = { "defend", "armor", "magic", "dexterity" },
        effects = {
            { type = "dexterity_scaling" },
        },
    },
    mage_crystal_shard = {
        id = "mage_crystal_shard", name = "Cristal de Sangue",
        type = "attack", subtype = "skill",
        cost = 1, attack = 7, defense = 0,
        description = "7 de dano. Cura 3 HP ao atacar.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        tags = { "strike", "lifesteal", "magic" },
        effects = {
            { type = "instant_heal", value = 3 },
        },
    },
    mage_frost_nova = {
        id = "mage_frost_nova", name = "Nova de Gelo",
        type = "attack", subtype = "skill",
        cost = 2, attack = 9, defense = 0,
        description = "9 de dano. Canaliza 1 Gelo (pot 4).",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "mage",
        tags = { "strike", "aoe", "channel", "ice" },
        effects = {
            { type = "channel_orb", orbType = "ice", value = 4 },
        },
    },
    mage_arcane_sight = {
        id = "mage_arcane_sight", name = "Visao Arcana",
        -- Rebalance v2 Jul/2026 (critica A3): cost 1->0 + Exaurir. Sem
        -- exhaust, C0 "Compre 2" + reshuffle automatico de Game:drawCard =
        -- mao contem o deck inteiro de graca. 1x/batalha vira cantrip de
        -- tempo — nicho distinto de torn_pages (C0 draw2 discard1 reciclavel).
        type = "effect", subtype = "skill",
        cost = 0, attack = 0, defense = 0,
        description = "Compre 2 cartas. Exaurir.",
        image = "assets/cards/effect/manaCrystal.png",
        rarity = "uncommon", class = "mage",
        tags = { "draw", "cycle", "utility", "zero_cost", "exhaust" },
        effects = {
            { type = "draw_cards", value = 2 },
            { type = "exhaust" },
        },
    },

    -- Rebalance v2 Jul/2026 (nova): segunda fonte de holy — fecha o Clerigo
    -- Arcano com healing_drop + Calice (pulso = cura/3 por turno, evoke =
    -- cura cheia).
    mage_radiant_prayer = {
        id = "mage_radiant_prayer", name = "Prece Radiante",
        type = "effect", subtype = "skill",
        cost = 2, attack = 0, defense = 0,
        description = "Cura 5 de HP. Canaliza 1 orbe Sagrado (pot 5).",
        image = "assets/cards/effect/potionOfHealing.png",
        rarity = "uncommon", class = "mage",
        tags = { "heal", "channel", "holy", "magic" },
        effects = {
            { type = "instant_heal", value = 5 },
            { type = "channel_orb", orbType = "holy", value = 5 },
        },
    },
    -- Rebalance v2 Jul/2026 (nova): payoff do dark (cresce +2/turno, evoca
    -- x2) sem esvaziar o tabuleiro; evoke_orb tinha 1 so carta. Tag 'evoke'
    -- e NAO 'channel' (critica B3: a carta nao canaliza).
    mage_dark_harvest = {
        id = "mage_dark_harvest", name = "Colheita Sombria",
        type = "effect", subtype = "skill",
        cost = 1, attack = 0, defense = 0,
        description = "Evoca o orbe mais antigo. Compre 1 carta.",
        image = "assets/cards/effect/manaCrystal.png",
        rarity = "uncommon", class = "mage",
        tags = { "evoke", "dark", "draw", "magic" },
        effects = {
            { type = "evoke_orb" },
            { type = "draw_cards", value = 1 },
        },
    },

    -- ========== RARE ==========
    mage_buffer = {
        id = "mage_buffer", name = "Buffer",
        type = "defense", subtype = "power",
        cost = 2, attack = 0, defense = 15,
        description = "15 Bloqueio. +2 Destreza.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "mage",
        tags = { "defend", "armor", "dexterity" },
        effects = {
            { type = "gain_dexterity", value = 2 },
        },
    },
    mage_creative_ai = {
        id = "mage_creative_ai", name = "IA Criativa",
        -- Rebalance v2 Jul/2026: era dominada por sages_gem. regen 1->2.
        type = "joker", subtype = "power",
        cost = 3, attack = 0, defense = 0,
        description = "Compra 1 carta extra e regenera 2 de HP por turno.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "mage",
        tags = { "draw", "cycle", "magic" },
        effects = {
            { type = "on_turn_start_draw", value = 1 },
            { type = "regen_per_turn", value = 2 },
        },
    },
    mage_echo_form = {
        id = "mage_echo_form", name = "Forma de Eco",
        -- Rebalance v2 Jul/2026: era o fundo da cadeia de dominancia dos
        -- jokers (+2 flat por 3 mana). Vira o UNICO multiplicador do mago =
        -- win-condition A3. Seguro pos-largest-wins: com joker_001 tambem
        -- ativo vale max(1.5,1.5)=1.5, nunca x2.25.
        type = "joker", subtype = "power",
        cost = 3, attack = 0, defense = 0,
        description = "Suas cartas de ataque causam +50% de dano.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "mage",
        tags = { "magic", "scaling", "passive" },
        effects = {
            { type = "damage_multiplier", target = "attack", value = 1.5 },
        },
    },
    mage_electrodynamics = {
        id = "mage_electrodynamics", name = "Eletrodinamica",
        -- Rebalance v2 Jul/2026: era clone pior de rune_of_power. Vira o
        -- motor infinito de orbes da WC Canalizador. DEPENDE do trigger
        -- channel_per_turn (engine flagada P2.1 em EffectSystem, turn_start).
        -- Fallback zero-engine se o trigger for vetado: damage_bonus 2 +
        -- on_turn_start_draw 1.
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "Canaliza 1 Raio (pot 2) no inicio de cada turno.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "mage",
        tags = { "channel", "lightning", "scaling", "passive" },
        effects = {
            { type = "channel_per_turn", orbType = "lightning", value = 2 },
        },
    },
    mage_fission = {
        id = "mage_fission", name = "Fissao",
        type = "effect", subtype = "skill",
        cost = 0, attack = 0, defense = 0,
        description = "Evoca TODOS os orbes. Ganhe +1 mana.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "mage",
        tags = { "evoke", "magic", "zero_cost", "finisher" },
        effects = {
            { type = "evoke_all_orbs" },
            { type = "restore_mana", value = 1 },
        },
    },
    mage_machine_learning = {
        id = "mage_machine_learning", name = "Aprendizado de Maquina",
        -- Rebalance v2 Jul/2026: era estritamente pior que sages_gem (C1
        -- draw1 vs C1 draw1+dano). Agora motor de draw pesado: draw 2, C3.
        type = "joker", subtype = "power",
        cost = 3, attack = 0, defense = 0,
        description = "Compra 2 cartas extras no inicio de cada turno.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "mage",
        tags = { "draw", "cycle" },
        effects = {
            { type = "on_turn_start_draw", value = 2 },
        },
    },
    mage_meteor_strike = {
        id = "mage_meteor_strike", name = "Chuva de Meteoros",
        type = "attack", subtype = "skill",
        cost = 3, attack = 18, defense = 0,
        description = "18 de dano. Canaliza 3 orbes de Fogo (pot 4).",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "mage",
        tags = { "strike", "aoe", "fire", "channel", "finisher" },
        effects = {
            { type = "channel_orb", orbType = "fire", value = 4 },
            { type = "channel_orb", orbType = "fire", value = 4 },
            { type = "channel_orb", orbType = "fire", value = 4 },
        },
    },
    mage_rainbow = {
        id = "mage_rainbow", name = "Arco-iris",
        type = "effect", subtype = "skill",
        cost = 2, attack = 0, defense = 0,
        description = "Canaliza Raio + Gelo + Escuridao.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "rare", class = "mage",
        tags = { "channel", "magic", "lightning", "ice", "dark" },
        effects = {
            { type = "channel_orb", orbType = "lightning", value = 3 },
            { type = "channel_orb", orbType = "ice", value = 3 },
            { type = "channel_orb", orbType = "dark", value = 3 },
        },
    },
    mage_rune_of_power = {
        id = "mage_rune_of_power", name = "Runa do Poder",
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "+3 de dano em cartas de ataque.",
        image = "assets/jokers/joker1.png",
        rarity = "rare", class = "mage",
        tags = { "strike", "magic", "scaling" },
        effects = {
            { type = "damage_bonus", target = "attack", value = 3 },
        },
    },
    mage_sages_gem = {
        id = "mage_sages_gem", name = "Gema do Sabio",
        type = "joker", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        description = "+1 dano por ataque. +1 carta por turno.",
        image = "assets/jokers/joker1.png",
        rarity = "rare", class = "mage",
        tags = { "strike", "draw", "magic" },
        effects = {
            { type = "damage_bonus", target = "attack", value = 1 },
            { type = "on_turn_start_draw", value = 1 },
        },
    },

    -- Rebalance v2 Jul/2026 (nova): amplificador do Clerigo Arcano —
    -- heal_multiplier plumbado em todo caminho de cura (com floor via P2.4
    -- e combo lifesteal_burst roteado via P2.5).
    mage_sacred_chalice = {
        id = "mage_sacred_chalice", name = "Calice do Sabio",
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "Todas as curas recebidas sao aumentadas em 50%.",
        image = "assets/jokers/joker1.png",
        rarity = "rare", class = "mage",
        tags = { "heal", "holy", "passive" },
        effects = {
            { type = "heal_multiplier", value = 1.5 },
        },
    },

    -- ========== LEGENDARY ==========
    -- Rebalance v2 Jul/2026 (nova): LEGENDARY de classe, capstone do
    -- Canalizador. Desc diz "nesta batalha" (duration=99 e idioma interno,
    -- cf. mage_arcane_focus — critica B7). VIGIADO (B6): se Foco total >= 5
    -- antes do A3 no autoplay, remove o +1 Foco.
    mage_primordial_storm = {
        id = "mage_primordial_storm", name = "Tempestade Primordial",
        type = "effect", subtype = "skill",
        cost = 3, attack = 0, defense = 0,
        description = "Canaliza Raio (pot 6), Gelo (pot 6) e Sombra (pot 4) e ganha +1 de Foco nesta batalha.",
        image = "assets/cards/effect/manaCrystal.png",
        rarity = "legendary", class = "mage",
        tags = { "channel", "lightning", "ice", "dark", "magic", "scaling" },
        effects = {
            { type = "channel_orb", orbType = "lightning", value = 6 },
            { type = "channel_orb", orbType = "ice", value = 6 },
            { type = "channel_orb", orbType = "dark", value = 4 },
            { type = "apply_buff", value = "focus", stacks = 1, duration = 99 },
        },
    },

    -- ========== EFFECT CARDS (potions) ==========
    effect_healing_potion = {
        id = "effect_healing_potion", name = "Pocao de Cura",
        type = "effect", subtype = "potion",
        cost = 1, attack = 0, defense = 0,
        description = "Cura 15 HP. Exaurir.",
        image = "assets/cards/effect/potionOfHealing.png",
        rarity = "common", class = "mage",
        tags = { "heal", "potion", "exhaust" },
        effects = {
            { type = "instant_heal", value = 15 },
            { type = "exhaust" },
        },
    },
    effect_mana_crystal = {
        id = "effect_mana_crystal", name = "Cristal de Mana",
        type = "effect", subtype = "crystal",
        cost = 1, attack = 0, defense = 0,
        description = "Mana maxima +1 (batalha).",
        image = "assets/cards/effect/manaCrystal.png",
        rarity = "common", class = "mage",
        tags = { "mana", "utility" },
        effects = {
            { type = "increase_max_mana", value = 1 },
        },
    },
}
