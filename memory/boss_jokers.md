---
name: boss_jokers
description: Out/2026. Coringa próprio de cada chefe (6, lendários, class "boss"): carta que SOBE do corpo girando no fim da morte e PARA no ar, depois ocupa UMA vaga da recompensa do chefe. Dados, arte, oferta, cinemática, endless, testes.
type: project
---

# Coringa do chefe (Out/2026, pedido do dono)

> "Quando cada boss morre, a partir do corpo dele sobe uma carta que fica
> girando, com várias coisas em volta. Quando ela para no ar, ela é uma carta
> de Joker do próprio boss. [...] abre a escolha de cartas que a gente tem hoje
> por padrão, só que com uma dessas cartas sendo a própria carta de Joker do
> boss." (dono, 14/Out/2026)

**Não é coringa EXTRA** (a decisão antiga "chefe não dá coringa" continua no
espírito): ele ocupa UMA das 3 vagas da escolha normal e o jogador pode não
pegá-lo. A ideia de cada carta é um TROFÉU do chefe vencido.

## As 6 cartas (`src/data/cards/boss.lua`)

| chefe | carta | efeito (tipos já existentes) |
|---|---|---|
| carrion_king | Coroa da Carniça | `damage_bonus` +1 + `on_attack_heal` 1 |
| tower_lich | Filactério do Lich | `channel_per_turn` Gelo valor 3 |
| abyss_tyrant | Coração do Tirano | `on_attack_debuff` Queimadura 3 (2 turnos) |
| winter_monarch | Égide do Inverno | `retain_armor` + `defense_bonus` 2 |
| rot_colossus | Raiz do Colosso | `regen_per_turn` 3 (Veneno ficou de fora: a trava de `test_effects_full` reserva Veneno ao ladino) |
| eclipse_queen | Halo do Eclipse | `echo_first_attack` ×2 + `on_turn_start_draw` 1 |

- `rarity = "legendary"`, **`class = "boss"`**, `bossId = <chefe>`. A classe
  própria tira as 6 de TODO pool comum: `getCardsByClassAndRarity` só aceita
  classe do jogador/basic/nil, `_poolFor(nil, ...)` e `BoosterPackSystem.classOk`
  recusam `"boss"` explicitamente, o evento de coringa filtra por classe.
  Rótulo da classe na inspeção: `classes.boss.name` ("Chefe") nos 5 locales.
- Nenhum tipo de efeito novo: DamagePreview, piloto e validador já conhecem
  todos. O piloto ganhou nota de bancada para `echo_first_attack` e
  `retain_armor` (`JOKER_EFFECT_SCORE` em `tools/autoplay.lua`); o expert_full
  avalia coringa por simulação (`pickBySim`), então a carta nova entra sozinha.
- Assinatura sonora (`audio/sfx/joker-sig/joker_boss_*.mp3`): recortes de sons
  do próprio chefe (`audio/sfx/boss/`; carniça = grasnado cortado em 0,95 s,
  eclipse = virada de fase em 1,0 s). ElevenLabs FREE: entram na lista de
  regenerar antes de vender.

## Arte

`tools/pixellab_boss_jokers.py gen|fetch|contact|pick` (create_map_object
64x64, side, detailed shading, sufixo canônico com UM acento de cor do chefe).
Pranchas e escolhidas em `tools/preview_out/coringa_chefe/`
(`<id>_prancha.png`, `escolhidas.png`). Todas como relíquia/troféu do chefe:
caveira de corvo coroada com dois corvos; caveira do lich de coroa de gelo
segurando o orbe; coração de obsidiana com veias de lava (a 1ª leva deu
coração de namorados: reprovado); escudo de gelo com caveira (o nome virou
Égide porque o cetro saiu fino demais e o escudo LÊ "Bloqueio que fica");
caveira tomada por raiz e cogumelos verdes; disco negro com coroa dourada e
asas de morcego. Ícone animado (lendária = vivo) em `icons_anim/joker_boss_*`
pelo `tools/pixellab_animate_card_icons.py` (entradas no ANIMS), aprovado
pelo contact sheet a 3x.

## Oferta (`src/systems/BossJokers.lua` + `ShopSystem:_applyBossJoker`)

- `BossJokers.offerFor(run)`: nó `boss` com `node.enemyId` → carta do chefe,
  **se a run ainda não a possui**. `_applyBossJoker` roda logo depois do laço
  de cartas da recompensa e TROCA a última oferta de carta por ela
  (`bossJoker = true`, custo 0, marca descoberta na Coleção). Compõe com a vaga
  de coringa da frente coringa-raro sem tocar nela.
- **Endless**: o chefe do ciclo repete um chefe já vencido; como a carta já é
  da run (ou foi recusada uma vez e ainda pode vir), a regra única "só se não
  possui" vale lá também: recusou na campanha, ganha outra chance; pegou, a
  vaga volta a ser carta comum.
- Tela: o coringa do chefe entra pela MESMA revelação dourada dos coringas
  raros (`CardRewardScreen:_revealRare`, `src/ui/RareReveal.lua`, frente
  coringa-raro: todo coringa da recompensa é revelado por último). A etiqueta
  de cima vira "CORINGA DO CHEFE" (`reward.boss_joker_badge`) e o selo "ACHADO
  RARO" de baixo não aparece para ele (o troféu já foi a revelação).
- Composição com a vaga de coringa raro (`REWARD_JOKER_CHANCE`, chefe 70%,
  sempre a ÚLTIMA vaga): `_applyBossJoker` roda depois e troca a última vaga,
  então a recompensa do chefe nunca tem dois coringas.

## Cinemática (`src/ui/BossTrophy.lua` + `src/data/boss_trophy.lua`)

- Um passo `trophy` (DEATH_KINDS) é ANEXADO ao roteiro de morte de qualquer
  chefe por `BossTrophy.withTrophy(steps, game, reduced)` dentro de
  `BossCinematic.startDeath`, só quando há carta a oferecer. BossCinematic
  ganhou 8 linhas e ZERO `local` novo (teto de 200): tudo por `require` inline.
- Linha do tempo (dados): `delay` 0,35 (brilho no corpo) → `rise` 1,45 (sobe
  do corpo em arco até 50%/40% da tela, cresce de 0,22 a 1, gira 5 voltas em
  ease-out-quart: o verso dourado aparece quando cos < 0) → `settle` 0,95 (o
  giro morre de frente) → revela (anéis, rajada de partículas, raios, nome da
  carta, `bossRevealSting` + assinatura do coringa, `CRTShader.jolt`) → segura
  balançando → `fade` 0,45. Total 4,4 s (reduced 2,2 s: sem giro, sem
  partícula, a carta aparece já parada).
- Tema por chefe em `themes`: partícula (pena/lasca/brasa/neve/esporo/pétala),
  cores, brilho, raio, som de subida. Brilho em 3 degraus aditivos na grade de
  pixel (`px = h/240`), partículas presas à grade.
- Coordenadas: o `stage` vem no espaço do MUNDO (largura maior que a tela no
  salão); `start` converte por `screenW/stage.w`. Sem isso a carta nascia
  longe do corpo (1ª captura).
- Continuar: `markDeathSeen` impede a morte, logo a carta não sobe de novo.
  Pular a morte (ENTER depois de 1 s) encerra a carta junto (`finish` →
  `BossTrophy.stop`); a escolha mostra o coringa do mesmo jeito.

## Balanceamento (bateria expert_full, 30 runs/classe, seeds 720000+)

1ª versão (carniça = Fraco em todo ataque + cura 1; lich Gelo 4) levou o
guerreiro de 53% a 73% na mesma base pareada (carniça pega em 94% das runs:
Fraco re-aplicado a cada ataque vira Fraco PERMANENTE no inimigo). Carniça
virou +1 dano e cura por ataque, lich Gelo 3. Depois da frente coringa-raro
(base 4615a95f, que o dono aceitou em 37/40/30), com os 6 coringas de chefe:
**guerreiro 40% [25-58], mago 30% [17-48] (base pareada 40%), ladino 43%
[27-61]**. A queda do mago está dentro do ruído (12 contra 9 vitórias nas
mesmas seeds) e o lift dos coringas de chefe no relatório do mago é positivo
ou neutro; mago abaixo de 40 era o estado aceito da base. Relatórios em
`reports/balance/ccf_<classe>/`.

## Travas e provas

- `love . test_one test_boss_jokers` (no `test_all`): as 6 cartas completas
  (atlas, ícone, anim, assinatura, 5 locales), fora de todo pool comum e de
  pacotes, recompensa do chefe com o coringa certo em UMA vaga (3 cartas),
  possuído não volta, elite não tem; cinemática de cada chefe termina com a
  carta PARADA de frente, gira no normal e não gira no reduced; possuído não
  sobe; Continuar não repete; pular encerra.
- `test_boss_cinematic`: a soma nominal da morte inclui o passo trophy.
- Capturas: `BOSS_CINE_ACT=n CARDGAME_HEADLESS=1 lovec . test_one
  shot_boss_cinematic death` (o tool agora grava `currentNode.enemyId`) →
  `tools/preview_out/coringa_chefe/morte_<id>.png` (sobe/gira/parada) e
  `recompensa_<id>.png`.

[[boss_cinematics]] · [[jokers_and_hand_layout]] · [[card_icon_animation]] · [[balance_curves]] · [[unlocks]]
