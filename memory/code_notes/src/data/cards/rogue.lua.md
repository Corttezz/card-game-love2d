---
name: code_notes/src/data/cards/rogue.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/cards/rogue.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/cards/rogue.lua`

Origem: `src/data/cards/rogue.lua` em `7dbdb60d` (20 de 23 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `return {`)

> src/data/cards/rogue.lua
> Classe Ladino. Fase 7: tags + effects. Arquetipos: poison / discard-cycle / exhaust.
> Rebalance Jul/2026 (plano v2): WC Veneno destravada (2 commons novas + Mestre das
> Toxinas legendary por-ataque), ciclo/burst afinado (bullet_time +2 mana) e
> lifesteal in-class (Lamina Sanguessuga).

## L21-22 (em `rogue_defend`, junto a `type = "defense", subtype = "common",`)

> Rebalance Jul/2026: 6 -> 7 (era estritamente dominada por defense_001
> Iron Shield na mesma pool; rogue e quem mais morre no A2).

## L44-45 (em `rogue_survivor`, junto a `cost = 1, attack = 0, defense = 9,`)

> Rebalance Jul/2026: FIX DESC — o descarte e aleatorio (love.math.random
> na mao) e a desc omitia.

## L70-72 (em `rogue_backstab`, junto a `cost = 0, attack = 8, defense = 0,`)

> Out/2026 (balanceamento de classe): 11 -> 8. Gratis, inata e na
> abertura de TODA luta: era o pico do ladino no A1 e nada no A5 —
> o poder foi pra Toxinas, que cresce na luta.

## L98-99 (em `rogue_blue_elixir`, junto a `type = "effect", subtype = "potion",`)

> Rebalance Jul/2026: FIX DOMINANCIA (era estritamente pior que adrenaline):
> +draw 1. C1: net +1 mana +1 carta — nicho distinto do C0 net +2 da Adrenalina.

## L113-115 (em `effects`, junto a `rogue_poison_dart = {`)

> Rebalance Jul/2026 (NOVA): primeira common de poison do jogo (70% dos rolls
> do A1 sao common e veneno tinha 0); C0 tambem alimenta triple_strike e o
> tempo zero-cost da classe.

## L129-131 (em `effects`, junto a `rogue_dirty_blade = {`)

> Rebalance Jul/2026 (NOVA): segunda common de poison — com 2 no tier common a
> afinidade (cap progressivo 0.9/1.2/1.5) tem o que puxar no A1; par com
> qualquer poison dispara poison_stack.

## L160 (em `rogue_acrobatics`, junto a `type = "effect", subtype = "skill",`)

> Rebalance Jul/2026: FIX DESC — descarte aleatorio nao declarado.

## L175 (em `rogue_adrenaline`, junto a `cost = 1, attack = 0, defense = 0,`)

> Out/2026: custo 0 -> 1 (rende +1 de mana, nao +2, por luta).

## L200-201 (em `rogue_bouncing_flask`, junto a `type = "attack", subtype = "skill",`)

> Rebalance Jul/2026: BUFF (dominada em taxa por venom_fang): poison
> 3/2t -> 5/3t. Vira a opcao "mais veneno por carta" da build.

## L251-252 (em `rogue_twin_fangs`, junto a `type = "attack", subtype = "skill",`)

> Rebalance Jul/2026: FIX DESC — multi_hit e x2 no base (nao dispara
> Toxinas/Envenom 2x nem Forca por hit); desc deixa de prometer 2 golpes reais.

## L275 (em `effects`, junto a `{ type = "reveal_intent", value = 2 },`)

> Névoa de intenção (Out/2026): expor a fraqueza é expor o golpe

## L292-294 (em `effects`, junto a `rogue_leech_blade = {`)

> Rebalance Jul/2026 (NOVA): rogue tinha ZERO lifesteal no pool de classe —
> destrava lifesteal_burst e o arquetipo Vampiro (on_attack_heal em non-joker
> funciona via sourceCard, 1x por carta).

## L322-327 (em `rogue_catalyst`, junto a `type = "effect", subtype = "skill",`)

> Auditoria Jul/2026: era type="attack" com attack=0 — ganhava a Forca
> do jogador como dano ESCONDIDO (0+str) e disparava a Toxina passiva.
> Carta de veneno puro e effect, e o texto volta a ser verdade.
> Rebalance Jul/2026: REDESIGN zero-engine (era trap dominada por
> venom_coating): stacks 3 -> 6. 18 de DoT 1x/batalha vs coating 12
> reciclavel — escolha real, o nuke que a build precisa cedo.

## L367-368 (em `rogue_executioner`, junto a `type = "attack", subtype = "skill",`)

> Rebalance Jul/2026: BUFF 22 -> 26 e movida pro bloco RARE (estava
> fisicamente no bloco UNCOMMON apesar de rarity="rare").

## L403-405 (em `rogue_bullet_time`, junto a `type = "effect", subtype = "skill",`)

> Rebalance Jul/2026: BUFF (fraca p/ rare vs acrobatics uncommon):
> +restore_mana 2; tag "finisher" removida (habilitava finisher_chain
> invisivel). O turno explosivo que o nome promete.

## L460-461 (em `rogue_storm_of_steel`, junto a `type = "attack", subtype = "skill",`)

> Rebalance Jul/2026: BUFF 8 -> 10. Unica strike-rare barata da classe
> merece o topo da banda.

## L474-476 (em `rogue_shooting_star`, junto a `type = "attack", subtype = "skill",`)

> Rebalance Jul/2026: REDESIGN — strength_scaling numa classe sem NENHUMA
> fonte de Forca era scaling morto; vira 8x2 (16 efetivo, topo da banda
> rare C2) com tag "combo" (peso 2x em countAllTags).

## L489-513 (em `rogue_death_mark`, junto a `type = "joker", subtype = "power",`)

> NERF Set/2026 (dono: "carta coringa marca da morte e muito forte, no
> minimo ser considerada lendaria ou ter nerf"). Lifesteal 2 -> 1.
>
> Ele estava certo, e a comparacao com os PARES mostra por que. Os dois
> efeitos disparam POR CARTA DE ATAQUE JOGADA (`damage_bonus` soma no
> pipeline de cada ataque; `on_attack_heal` e trigger chamado por carta
> em `processCardInCombat`) — nao 1x/turno. Com 3 ataques no turno a
> versao antiga dava +6 de dano E +6 de cura, sem condicao nenhuma.
>
> Mil Cortes (ladino, RARA)        +3 dano
> Runa do Poder (mago, RARA)       +3 dano
> Porta-Estandarte (guerr., RARA)  +3 dano
> Senhor Vampiro (LENDARIA)        +3 de cura por ataque
> Marca da Morte (RARA)            +2 dano E +2 de cura   <- aqui
>
> Ou seja: o dano de uma rara MAIS dois tercos de uma lendaria, na
> raridade das que entregam UMA coisa so. Nao era "uma rara forte", era
> duas raras numa.
>
> ESCOLHI NERFAR EM VEZ DE PROMOVER A LENDARIA porque promover nao
> consertava a comparacao: mesmo como lendaria ela seguiria melhor que
> o Senhor Vampiro, que e lendario e so cura. E cortei a CURA, nao o
> dano, pra manter a identidade hibrida (strike + lifesteal) e deixar
> a troca explicita contra o par direto: contra Mil Cortes voce cede 1
> de dano por ataque e recebe 1 de HP. Isso e escolha; +2/+2 nao era.

## L526-530 (em `effects`, junto a `rogue_toxin_master = {`)

> ========== LEGENDARY ==========
> Rebalance Jul/2026 (NOVA): legendary de classe, capstone da WC Veneno —
> por-ataque MANTIDO (a regra 1x/turno do P2.3 e SO para on_defend_damage de
> joker); o quadratico ~7.5t^2 tem contra-jogo nativo: armor inimiga ABSORVE
> poison e o intent DEFEND congelado e o counter legivel.

