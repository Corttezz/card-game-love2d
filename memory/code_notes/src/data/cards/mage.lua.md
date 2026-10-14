---
name: code_notes/src/data/cards/mage.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/cards/mage.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/cards/mage.lua`

Origem: `src/data/cards/mage.lua` em `7dbdb60d` (25 de 29 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `return {`)

> src/data/cards/mage.lua
> Classe Mago. Fase 7: tags + effects baseados em channel/evoke/magic/heal.

## L20-22 (em `mage_dualcast`, junto a `type = "effect", subtype = "common",`)

> Rebalance v2 Jul/2026: era trap no meta pos-pulso (evocar cedo
> destruia pulsos futuros). Agora evoca E repoe o slot — tempo
> neutro com burst, sem engine nova.

## L36-37 (em `mage_ball_lightning`, junto a `type = "attack", subtype = "skill",`)

> Rebalance v2 Jul/2026: nao superava as commons zap/lightning.
> attack 7->8, pot 4->5 pra valer o slot uncommon.

## L63-64 (em `mage_fireball`, junto a `cost = 2, attack = 12, defense = 0,`)

> Rebalance v2 Jul/2026: fix de desc apenas — e type=attack (escala
> com Forca/jokers), "dano magico" mentia; declara a potencia do orbe.

## L76-77 (em `mage_flame_tongue`, junto a `type = "attack", subtype = "common",`)

> Rebalance v2 Jul/2026: vulnerable 1t morria no onTurnEnd antes de
> pagar; duration 1->2 abre a janela real.

## L112-115 (em `mage_healing_drop`, junto a `type = "effect", subtype = "skill",`)

> Rebalance v2 Jul/2026: era dominada por effect_healing_potion
> (15 HP pelo mesmo custo). Vira a porta de entrada do orbe HOLY
> (engine completa, 0 cartas usavam): cura menor mas RECICLAVEL
> (sem exhaust) + pulso de cura/3 por turno via orbPassiveTick.

## L169-172 (em `mage_blizzard`, junto a `type = "effect", subtype = "skill",`)

> Auditoria Jul/2026: era type="attack" com attack=0 (ganhava Forca
> escondida). Dano magico e effect — nao escala com Forca (identidade).
> Rebalance v2 Jul/2026: dano flat que nao escala com nada precisa de
> numero honesto pro A3 (10->14); tag 'aoe' removida (jogo single-enemy).

## L214-216 (em `mage_overcharge`, junto a `type = "attack", subtype = "skill",`)

> Auditoria Jul/2026: era estritamente pior que Descarga (2 mana:
> 9+pot3 vs 1 mana: 7+pot3). Pot 3->6 da identidade de "carga
> pesada" e paga o custo 2.

## L229-231 (em `mage_arcane_focus`, junto a `type = "effect", subtype = "power",`)

> Auditoria Jul/2026: era clone do Grito de Guerra (+2 Forca). Agora
> concede FOCO (+1 potencia por orbe evocado) — o eixo de scaling do
> mago que o nome sempre prometeu. Ver _evokeOrbEffect.

## L244-245 (em `mage_mind_spike`, junto a `type = "attack", subtype = "skill",`)

> Rebalance v2 Jul/2026: attack 10->12, sobe ao meio da banda
> uncommon C2.

## L258-260 (em `mage_twin_bolts`, junto a `type = "attack", subtype = "skill",`)

> Rebalance v2 Jul/2026: attack 7->9, pot 2->3 (18 efetivo + orbe =
> banda rare C2). Desc corrigida: multi_hit e x2 no base, nao 2
> golpes reais — deixa de prometer multihit que nao existe.

## L274-294 (em `mage_arcane_torrent`, junto a `type = "attack", subtype = "skill",`)

> Set/2026 — CUSTO 3 -> 2, dano 26 -> 20. O dono jogou e achou a carta
> ruim apesar de ela ter o MELHOR dano por mana do mago (8,7).
>
> O erro estava na conta que a justificava, nao no numero: o comentario
> anterior calculava o pico como "26 x1.5 (magic_focus) x1.5 (joker)",
> mas `magic_focus` exige DUAS cartas com tag magic no mesmo turno e
> PLAYER_MAX_MANA e 3. Custo 3 consome o turno inteiro, entao o
> multiplicador que sustentava o balanceamento era INALCANCAVEL na
> configuracao padrao. Ela foi buffada (22->26) e vigiada por tripwire
> pelo lado do excesso; ninguem olhou o lado de baixo.
>
> Comparacao que o jogador faz sem saber que faz: com os mesmos 3 de
> mana, tres comuns de 1 (Relampago 8 + Raio Esferico 8 + Descarga 7)
> dao 23 base, viram ~34 com magic_focus ativo E deixam TRES orbes
> canalizados, que ainda pulsam nos turnos seguintes. Uma rare perdia
> para tres comuns.
>
> Com custo 2 sobra 1 de mana: o combo passa a ser alcancavel e a
> premissa do balanceamento volta a valer. 20 x1.5 x1.5 = 45 de pico
> real, contra 58 de um pico teorico que nunca acontecia.
> Tripwire: mago >65% de vitoria no autoplay -> baixar attack pra 18.

## L306-307 (em `mage_consume`, junto a `type = "effect", subtype = "skill",`)

> Auditoria Jul/2026: gain_strength -> Foco (mago escala orbe, nao
> musculo). Ordem: Foco ANTES do evoke pra ja valer nesta evocacao.

## L321-322 (em `mage_doom_and_gloom`, junto a `type = "attack", subtype = "skill",`)

> Rebalance v2 Jul/2026: fix desc/tags — tag 'aoe' removida (jogo
> single-enemy); desc declara a potencia da Sombra. Numeros ficam.

## L335-338 (em `mage_force_field`, junto a `type = "defense", subtype = "skill",`)

> Rebalance v2 Jul/2026: era dominada por auto_shields. defense
> 14->16 e vira o PRIMEIRO payoff de Destreza do jogo: dexterity_
> scaling (Destreza conta em DOBRO via scaledStat, effect que tinha
> 0 usos) no lugar do gain_dexterity +1.

## L375-378 (em `mage_arcane_sight`, junto a `type = "effect", subtype = "skill",`)

> Rebalance v2 Jul/2026 (critica A3): cost 1->0 + Exaurir. Sem
> exhaust, C0 "Compre 2" + reshuffle automatico de Game:drawCard =
> mao contem o deck inteiro de graca. 1x/batalha vira cantrip de
> tempo — nicho distinto de torn_pages (C0 draw2 discard1 reciclavel).

## L387 (em `effects`, junto a `{ type = "reveal_intent", value = 2 },`)

> Névoa de intenção (Out/2026): "visão" arcana VÊ através da nevasca

## L393-395 (em `effects`, junto a `mage_radiant_prayer = {`)

> Rebalance v2 Jul/2026 (nova): segunda fonte de holy — fecha o Clerigo
> Arcano com healing_drop + Calice (pulso = cura/3 por turno, evoke =
> cura cheia).

## L409-411 (em `effects`, junto a `mage_dark_harvest = {`)

> Rebalance v2 Jul/2026 (nova): payoff do dark (cresce +2/turno, evoca
> x2) sem esvaziar o tabuleiro; evoke_orb tinha 1 so carta. Tag 'evoke'
> e NAO 'channel' (critica B3: a carta nao canaliza).

## L441 (em `mage_creative_ai`, junto a `type = "joker", subtype = "power",`)

> Rebalance v2 Jul/2026: era dominada por sages_gem. regen 1->2.

## L455-467 (em `mage_echo_form`, junto a `type = "joker", subtype = "power",`)

> Set/2026 — REFORMULADA. Era `damage_multiplier attack 1.5`, ou seja,
> um CLONE EXATO do joker_001 (Deus do Abismo), que ainda por cima e
> lendario. Queixa do dono: "qual a diferenca entre deus do abismo e
> forma de eco? nenhuma, e uma e lendaria a outra rara". Pior: com o
> largest-wins do P0.9, ter os dois ativos nao somava NADA —
> max(1.5, 1.5) = 1.5 — entao a segunda copia era ouro no lixo.
>
> Agora ela faz o que o NOME promete: ECO. Dobra a PRIMEIRA carta de
> ataque do turno, uma vez por turno. Isso a separa do joker_001 no
> que importa, que e COMO se joga com ela: o lendario e um bonus
> plano que premia muitos ataques; o eco e um pico condicional que
> premia carregar UM golpe grande e bota-lo na frente. Mesma familia
> (dano), decisao diferente na mao.

## L481-485 (em `mage_electrodynamics`, junto a `type = "joker", subtype = "power",`)

> Rebalance v2 Jul/2026: era clone pior de rune_of_power. Vira o
> motor infinito de orbes da WC Canalizador. DEPENDE do trigger
> channel_per_turn (engine flagada P2.1 em EffectSystem, turn_start).
> Fallback zero-engine se o trigger for vetado: damage_bonus 2 +
> on_turn_start_draw 1.

## L511-512 (em `mage_machine_learning`, junto a `type = "joker", subtype = "power",`)

> Rebalance v2 Jul/2026: era estritamente pior que sages_gem (C1
> draw1 vs C1 draw1+dano). Agora motor de draw pesado: draw 2, C3.

## L577-579 (em `effects`, junto a `mage_sacred_chalice = {`)

> Rebalance v2 Jul/2026 (nova): amplificador do Clerigo Arcano —
> heal_multiplier plumbado em todo caminho de cura (com floor via P2.4
> e combo lifesteal_burst roteado via P2.5).

## L593-597 (em `effects`, junto a `mage_primordial_storm = {`)

> ========== LEGENDARY ==========
> Rebalance v2 Jul/2026 (nova): LEGENDARY de classe, capstone do
> Canalizador. Desc diz "nesta batalha" (duration=99 e idioma interno,
> cf. mage_arcane_focus — critica B7). VIGIADO (B6): se Foco total >= 5
> antes do A3 no autoplay, remove o +1 Foco.

