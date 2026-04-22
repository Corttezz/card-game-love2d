---
name: Archetypes
description: 10 arquétipos viáveis de build, com tags-chave e cartas-âncora
type: project
---

# Arquétipos de Build

**Plano Fase 7.** Cada arquétipo é validado por:
1. Tags compartilhadas entre ≥3 cartas
2. Regra de combo ou joker que amplifica
3. Pelo menos uma carta common acessível já no starter pool da classe

| # | Arquétipo | Classe | Tags-âncora | Cartas-âncora | Combo/joker chave |
|---|-----------|--------|-------------|---------------|-------------------|
| 1 | Muralha (Armor Stack) | Warrior | `armor` `defend` | warrior_defend, warrior_plate_mail, warrior_kite_guard | `defend_wall` + `armor_tower` + joker_002 |
| 2 | Berserker (Strength) | Warrior | `strike` `strength` | warrior_heavy_blade, warrior_rage, warrior_inflame | `triple_strike` + `finisher_chain` + warrior_demon_form |
| 3 | Reflexo (Thorns) | Warrior | `thorn` `defend` | warrior_flame_barrier, warrior_juggernaut | `thorn_reflex` + joker_002 |
| 4 | Canalizador (Orbs) | Mage | `channel` `evoke` `lightning`/`ice`/`dark` | mage_zap, mage_ball_lightning, mage_dualcast, mage_rainbow | `channel_burst` + mage_fission |
| 5 | Potion Mage | Mage | `heal` `draw` `mana` | effect_healing_potion, mage_arcane_sight, mage_healing_drop | joker_003 + `lifesteal_burst` |
| 6 | Magia Pura | Mage | `magic` `aoe` | mage_blizzard, mage_doom_and_gloom, mage_meteor_strike | `magic_focus` + mage_rune_of_power |
| 7 | Vampiro | Any (Rogue/Warrior) | `lifesteal` `strike` | attack_002, warrior_feed, rogue_death_mark | joker_003 + `lifesteal_burst` |
| 8 | Venenoso | Rogue | `poison` `debuff` | rogue_venom_fang, rogue_bouncing_flask, rogue_catalyst, rogue_corpse_explosion | `poison_stack` |
| 9 | Ciclo (Draw+Discard) | Rogue | `draw` `discard` `cycle` | rogue_survivor, rogue_acrobatics, rogue_calculated_gamble, warrior_second_wind | `cycle_motion` |
| 10 | Exaurir | Rogue | `exhaust` `finisher` | rogue_backstab, rogue_corpse_explosion, warrior_feed, warrior_immolate | finisher_chain (com strike+finisher) |

## Como testar cada arquétipo

Roda run com classe indicada, priorize nas recompensas/loja cartas com as tags-âncora, e observe os toasts de combo. Se o combo chave dispara em 60%+ das batalhas do meio/fim de ato, o arquétipo está "vivo".

## Arquétipos planejados (não-MVP)

- **Mana Battery** — precisa `restore_mana` triggers. Stub presente.
- **Armor-to-Damage Conversion** — precisa efeito novo `convert_armor_to_damage`. Fase 8+.
