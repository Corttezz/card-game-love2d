---
name: STS Run Economy
description: Estrutura da run do Slay the Spire com números exatos — gold por sala, pity systems (raridade de carta, poção, eventos), shop, fogueira, Neow, baús/chaves, eventos, composição dos atos e poções.
type: reference
---

# STS — Estrutura de run e economia (números de balance)

Fonte: `rooms/`, `rewards/`, `shop/`, `neow/`, `events/`, `dungeons/`, `helpers/EventHelper|PotionHelper`. Verificados de primeira mão: pity de carta (AbstractDungeon.java:1417-1425, 1579, 2753-2755) e de poção (AbstractRoom.java:586-608).

## Os 3 PITY SYSTEMS (a lição mais importante do arquivo)

O StS esconde correções de má sorte em TODO lugar onde RNG frustraria:

1. **Raridade de carta ("card blizzard")**: `roll(0-99) + cardBlizzRandomizer`; randomizer começa **+5**, cada COMMON tirado **−1** (piso **−40**), sair RARE **reseta pra +5**. Com limiar `<3 RARE, <40 UNCOMMON`, a rare fica inevitável após ~40 commons. Salvo no save (`card_random_seed_randomizer`).
2. **Poção**: base **40%** de dropar em combate; dropou → **−10**, não dropou → **+10** (`blizzardPotionMod`). Nunca 5 combates sem poção, nunca chuva delas. Elite trava em 40 base; White Beast Statue = 100%; não rola se já há 4+ rewards.
3. **Salas "?" (EventHelper.roll)**: a sala-interrogação sorteia: ELITE 10%? não — no ato: MONSTER começa 10%, SHOP 3%, TREASURE 2%, resto EVENTO; **cada "?" que NÃO deu X incrementa a chance de X** (+10%/+3%/+2%) e resetar ao sair. Surpresa controlada.

**Ideia-chave pra nós**: RNG "honesto" = uniforme por trás + correção acumulativa salva na run. Barato de implementar (1 contador por categoria).

## Gold (fontes e valores)

- Combate normal `random(10,20)`; elite `random(25,35)`; boss `100±5` (A13+: ×0.75). Golden Idol (relíquia): +25%.
- Eventos dão/tomam (Golden Shrine +100, ladrões roubam e você RECUPERA se matar o ladrão depois — reward "STOLEN_GOLD").
- Neow pode dar 100 (grátis) ou 250 (com drawback).
- Sumidouros: shop (cartas 45-160 por raridade ±10%, colorless ×1.2, relíquias 143-999, poções ~50-105), **remoção de carta 75 +25 por uso na run**, eventos com custo em ouro.

## Combat rewards (CombatRewardScreen)

Pós-vitória, lista vertical: OURO → POÇÃO (se rolou) → CARTA (escolha de 3) → RELÍQUIA/CHAVE (elite) → STOLEN_GOLD. Tudo é RewardItem tipado. Carta: 3 opções, raridades pelo pity acima, **chance de vir upgraded sobe por ato** (A1 0% → A2 12.5-25% → A3 25-50%; Ascension 12 corta pela metade), elite puxa raridade melhor, **Singing Bowl** adiciona opção "+2 maxHP em vez de carta", skip permitido (e N. Loadstone/eventos premiam skip).

## Shop (Merchant + ShopScreen)

Estoque fixo por visita: **5 cartas da classe (2 ATTACK, 2 SKILL, 1 POWER) + 2 colorless (1 UNC, 1 RARE) + 3 relíquias (roll 48% C / 34% U / 18% R) + 3 poções + serviço de remoção**. UMA carta aleatória com **50% off** (etiqueta de promoção). Preços ±10%; A16 tudo ×1.1; Courier ×0.8 e re-estoca ao comprar; Membership Card ×0.5 (stackam ×0.4). Personagem do lojista com fala e ícone — loja é um NPC, não um menu.

## Fogueira (CampfireUI)

Opções base: **Rest (+30% maxHP)** e **Smith (upgrade 1 carta)**. Relíquias ADICIONAM opções ao menu: Girya (Lift: +1 Str permanente, máx 3 usos), Peace Pipe (Toke: remover carta), Shovel (Dig: relíquia aleatória), Dreamcatcher (rest → card reward), Regal Pillow (+15 no rest), Coffee Dripper/Fu Xi REMOVEM rest/smith em troca de poder. Ato 3+ sem Ruby Key: opção **Recall** (pega a chave em vez de qualquer ação). Fogueira = slot machine de decisões de 1 escolha.

## Neow (bênção inicial — "mulligan de run")

4 opções: (1) vantagem de carta (3 cartas à escolha, remover 1, transformar 1, upgrade 1, rare aleatória, colorless), (2) vantagem de recurso (100 gold, +10% maxHP, 3 poções, relíquia comum, Lament: 3 primeiros inimigos com 1 HP), (3) **vantagem GRANDE com drawback** (250 gold / 2 rares / relic rara / +20% HP... × perder 10% maxHP, perder todo ouro, ganhar curse, tomar 30% de dano), (4) **trocar a relíquia inicial por uma BOSS relic aleatória** (all-in). Morreu no ato 1 → próxima Neow oferece opções melhores (anti-frustração de novo).

## Baús & chaves

Small 50% / Medium 33% / Large 17%; conteúdo: relíquia (tier por tamanho) + chance de ouro. No Ato 3 desbloqueado (chaves ativas): baú NÃO-boss oferece **Sapphire Key em TROCA da relíquia** (escolha exclusiva). Emerald = burning elite (elite marcado no mapa), Ruby = Recall na fogueira. As 3 chaves abrem o Ato 4 — transformam rotas em objetivos.

## Eventos (56) — anatomia

Pools por ato + shrines (aparecem em qualquer ato). Estrutura universal: retrato + texto curto + 2-4 opções com **custos/ganhos EXPLÍCITOS no botão** ("[Perder 7 HP. Ganhar 100 gold]") — risco informado, não pegadinha. Ícones: Big Fish (cura 1/3 vs +5maxHP vs relíquia+curse), Golden Idol (relíquia + escolher: curse Injury / dano 25% / −8% maxHP; A15 pior), Vampires (remove TODAS as Strikes → 5 Bites), Duplicator (copia carta), Falling (perde skill OU power OU attack — escolhe qual perder), Bonfire Spirits (sacrifica carta → recompensa pela raridade). Vários usam a MECÂNICA DO DECK como moeda (remover/transformar/duplicar) — eventos mexem no build, não só em HP/gold.

## Composição dos atos

Mapa 15×7, 6 caminhos, chances de sala: shop 5%, rest 12%, event 22%, elite 8% (A1+ ×1.6), resto monster; linha 0 monster, 8 treasure, 14 rest (pré-boss garantido). **Encontros com curadoria**: cada ato tem lista `weakMonsters` (primeiras 3 lutas do ato vêm dela) e `strongMonsters` (depois), 3 elites fixos por ato, 3 bosses por ato (1 sorteado; A20 = 2 seguidos). HP dos monstros: range por monstro rolado com `monsterHpRng` (ex. Cultist 48-54). Boss derrotado → **escolha de 1 entre 3 BOSS relics** (build pivot) + cura total entre atos (A5+: 75%).

## Poções (44)

Raridade 65% C / 25% U / 10% R; slots 3 (A11: 2; Potion Belt +2). Potência escala com a classe (Focus potion só Defect etc.). Fairy in a Bottle: auto-revive 30% (única "vida extra"). Sacred Bark (relíquia): dobra efeito de poções. Design: poção = "botão de emergência" que o pity garante que você tenha.

## → Confronto com o nosso jogo

Temos: EconomySystem com juros TFT/Balatro cap 5 (✔ identidade própria), shop com reroll ×1.4 (Balatro-style, ok), rewards 3 cartas grátis, RestScreen, EventScreen, MapManager com pesos por andar. **Faltam/ideias**: os 3 pity systems (raridade/“poção”→consumível/eventos), gold por TIPO de sala com ranges (hoje flat 5+juros), fogueira extensível por joker (opções dinâmicas), Neow-like (bênção inicial com trade-off — hoje a run começa seca), baú/chaves como objetivo de rota, eventos com custo explícito no botão e que MEXEM NO DECK, curadoria weak/strong nos primeiros andares do ato, boss relic choice (grande recompensa de pivô). Ver [[STS Gap Analysis]].
