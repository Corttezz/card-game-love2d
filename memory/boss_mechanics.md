---
name: boss_mechanics
description: Roteiro (14-15/Out/2026) da mecânica-assinatura de cada chefe dos atos 2-6 no modelo do rei-carniça (regra com números, contra-jogo, status + ícone próprio, objeto contado na cena, coreografia do golpe, som) e o roteiro curto de assinatura dos comuns/elites/mini-chefes. Onde mora o código e as travas.
type: project
---

# Mecânica própria por chefe

> "Ficaram muito legais esses efeitos do boss do rei-carniça, dos corvos... O
> ideal é ter um efeito diferente para cada inimigo do jogo... o player consegue
> se antecipar e montar estratégias pensando nisso. O da neve pode ter algo
> relacionado a isso." (dono, 14/Out/2026)

O MODELO é o rei-carniça (`memory/boss_visuals.md`, seção 14/Out): uma regra
que o jogador LÊ antes de acontecer, um contador com ícone próprio e tooltip
que explica o contra-jogo, o estado VISÍVEL na cena como objeto contado
(sprite de verdade, escala inteira) e o golpe com coreografia própria DENTRO
do beat (nada alonga o turno).

## Regras comuns (valem para os cinco)

- **Intent continua CONGELADO.** Mecânica que mexe no golpe anunciado só pode
  DIMINUIR o número (runa quebrada tira golpe, corrente rompida corta metade).
  Nada aumenta um golpe já anunciado: o que fortalece vale do próximo anúncio.
- **Todo número sai de `src/data/enemies.lua`** (`mechanic = {...}` no kit), e
  a lógica mora num lugar só: `src/systems/BossMechanics.lua` (ganchos que o
  `Game`/`Enemy` chamam). O estado vive no `Enemy` (status) ou no `Player`
  (Geada), então o Continuar (que reabre a luta do começo) sempre nasce limpo.
- **Status do chefe = status comum** (`addStatusEffect`, duração 999): o pill,
  a contagem visual e o tooltip leem a MESMA pilha. Ícone 64x64 próprio do
  PixelLab no estilo de `status_poison`/`status_crows` (nunca arte de carta;
  trava por nome e bytes).
- **Visual contado:** `src/ui/BossTokens.lua` (objetos da mecânica na cena,
  reconciliados com a pilha como o bando de corvos: entra animado, sai
  animado; 1ª leitura e reducedMotion = já no lugar). **Golpe temático:**
  `src/ui/BossStrike.lua` (projétil/surgimento que chega ao painel do herói no
  apex do golpe, `ATK_WINDUP + ATK_LUNGE`, e some no recuo).
- **reducedMotion** tira o movimento (tokens parados, sem projétil), nunca a
  informação (pill, número, marca na barra de vida).
- **Piloto ciente:** `tools/balance_ai.lua` + `tools/autoplay.lua` respeitam
  carta congelada, leem a Geada e valorizam o que a regra premia.
- Sons: SÓ arquivos que já existem em `audio/sfx/boss/` e `audio/sfx/`, com
  volume MEDIDO (média do arquivo + ganho, alvo de -24 a -27 dB efetivos, a
  faixa dos corvos depois da queixa "alto demais").

## Ato 2: tower_lich, Runas do Ritual

- **Regra.** O lich nasce com 1 runa (`runes`) e acende +1 no fim de cada
  turno dele (teto 4). Com 4 runas o próximo anúncio é o **Cataclismo
  Rúnico**: 1 golpe por runa (0,5 × dano), cada golpe consome uma runa.
- **Contra-jogo.** A cada **15% da vida máxima** de dano que passa (vida
  perdida, depois do Bloqueio) num MESMO turno do jogador, uma runa racha e
  quebra. Quebrar runa com o Cataclismo já anunciado tira um golpe dele (o
  número só cai). O Escudo de Gelo (a cada 3) segura o dano e protege as runas:
  o turno do escudo é o pior pra quebrar. Prêmio: turno de explosão.
- **Status/ícone.** `runes` → `status_runes` ("Runas do Ritual").
- **Visual.** As runas são pedras rúnicas (sprite) orbitando o lich na altura
  da cintura, contadas (substituem as 5 runas decorativas procedurais). Runa
  nova acende saindo do orbe do cajado; runa quebrada estilhaça.
- **Golpe.** No Cataclismo cada runa voa do anel até o painel do herói e
  explode no apex (como o mergulho do corvo). Som: `boss_rune_ignite` ao
  acender e no impacto (baixo), `boss_frost_shatter` baixo na quebra.
- **Balanceamento esperado.** Troca um golpe médio (~1,3×) a cada ~4 turnos por
  um de 2,0× quando ninguém quebra runa; quem bate forte quase nunca vê o
  Cataclismo inteiro.

## Ato 3: abyss_tyrant, Correntes do Abismo

- **Regra.** Três correntes (`chains`) prendem o Tirano. Cada uma se rompe ao
  cruzar **75%, 50% e 25%** da vida (marcas na barra). Ao romper: o Tirano
  **cambaleia** (o golpe JÁ anunciado perde metade, uma vez por turno) e fica
  mais forte (+12% do dano base como Força, do próximo anúncio em diante).
- **Contra-jogo.** Guardar o dano pra cruzar a marca no turno em que ele
  anunciou o Fogo Infernal (a carga de Reunir Chamas dá um turno inteiro de
  aviso) corta o maior golpe da luta pela metade. Cruzar marca à toa só o
  fortalece.
- **Status/ícone.** `chains` → `status_chains`.
- **Visual.** Correntes de verdade (elo em sprite repetido ao longo da linha)
  saindo do chão do salão até o corpo; rompida = estala, os elos voam, a ponta
  cai. O tirano dá o tranco (hurt) na ruptura.
- **Golpe.** Fogo Infernal e Jorro de Cinzas mandam bolas de fogo (sprite) ao
  painel do herói; cada uma estoura em brasas no apex. Som da ruptura:
  `tyrant_chain_snap` (medido).

## Ato 4: winter_monarch, Geada

- **Regra.** Os golpes do Monarca deixam **Geada** no jogador (`frost`): Lâmina
  do Inverno +1, Nevasca Real +2, Inverno Eterno +2, Coroa Gélida +1 (o número
  vem no intent, congelado). Quando a mão nova é comprada com **4+ de Geada**,
  as **2 cartas mais caras chegam CONGELADAS** (não podem ser jogadas neste
  turno; derretem no fim do turno) e a Geada perde 4.
- **Contra-jogo.** Cada ATAQUE jogado derrete 1 de Geada (fogo derrete 2):
  quem chega a 2-3 de Geada antes da Nevasca troca defesa por ataque pra não
  perder a mão boa. Casa com a névoa do ato 4: o número do golpe pode estar
  escondido, mas a Geada que ele traz aparece no tooltip do tipo.
- **Status/ícone.** `frost` (no jogador, pill `frost`) → `status_frost`.
- **Visual.** Gelo cresce das bordas da tela (cantos de cristal em sprite) com
  a Geada; carta congelada vem dentro de um bloco de gelo (sprite por cima da
  carta) e racha ao derreter.
- **Golpe.** Nevasca Real e Lâmina do Inverno disparam estilhaços de gelo
  (sprite) do cajado ao painel. Som: `impact-ice` baixo no impacto,
  `boss_ice_crackle` ao congelar carta.

## Ato 5: rot_colossus, Raízes

- **Regra.** O Colosso nasce com **2 raízes** (`roots`, teto 4) e ganha +1 a
  cada 2 turnos dele. No fim de cada turno ele regenera **0,75% da vida máxima
  por raiz** (2 raízes = o 1,5% de antes, 4 raízes = 3%).
- **Contra-jogo.** Um único ATAQUE que tire **5% da vida máxima** (depois do
  Bloqueio) corta uma raiz. Dano miúdo e veneno não cortam: perdem pra
  regeneração; carta grande, Força e combo cortam.
- **Status/ícone.** `roots` → `status_roots`.
- **Visual.** Raízes (sprite) saindo do chão em volta dos pés, uma por pilha;
  na regeneração a seiva sobe por elas; cortada, a raiz murcha e afunda.
- **Golpe.** Pancada Colossal e Golpe Pútrido: uma raiz rompe do chão sob o
  painel do herói no apex e afunda no recuo. Som: `boss_roots_crawl` curto e
  baixo, `colossus_crack` no corte.

## Ato 6: eclipse_queen, Ciclo da Lua

- **Regra.** A lua sobre a coroa gira a cada anúncio: **Crescente → Cheia →
  Minguante → Nova** (`moon` 1..4). Na **Cheia** o golpe anunciado vem ×1,5 (o
  número já aparece maior no intent). Na **Nova** ela fica **Vulnerável** durante
  o seu turno. O eclipse (abaixo de 50%) continua valendo por cima.
- **Contra-jogo.** Ritmo: defender na Cheia, explodir na Nova (+50% de dano).
  Guardar a carta grande dois turnos pra Lua Nova compensa.
- **Status/ícone.** `moon` → `status_moon` (fase no tooltip).
- **Visual.** Uma lua (sprite) pequena acima da coroa mostra a fase de verdade
  (sombra em degraus de pixel); a coroa de raios cresce na Cheia e apaga na
  Nova.
- **Golpe.** Lâminas Lunares e Chuva de Estrelas lançam crescentes (sprite) ao
  painel do herói, uma por golpe. Som: `boss_eclipse_phase` baixo na virada da
  fase.

## Roteiro curto: assinatura dos inimigos comuns, elites e mini-chefes (depois)

Uma assinatura por criatura, sempre legível e barata (status + 1 objeto ou
1 coreografia). Ordem sugerida: mini-chefes, depois elites, depois comuns.

| ato | inimigo | assinatura |
|---|---|---|
| 1 | cursed_scarecrow | Bicadas de Corvo: corvinhos do espantalho mergulham (reaproveita o corvo) |
| 1 | hollow_farmer | Preparar: o forcado brilha na carga; Espetar atravessa |
| 1 | plague_rats | Ninhada: cada mordida deixa 1 rato a mais na pilha (contado no chão) |
| 1 | harvest_reaper (elite) | Marca do Ceifador vira foice pairando sobre o painel até o golpe |
| 1 | blight_bull (elite) | Investida em linha: bate o casco 1 turno antes (poeira), golpe dobra com Vulnerável |
| 1 | wicker_effigy (mini) | Pavio: brasas acumulam e explodem quando ele morre (queimadura no jogador) |
| 2 | moon_gargoyle | Pele de Pedra: casca visível que racha com 2 ataques |
| 2 | ram_cultist | Hino: velas no chão contam o hino, 3 velas = maldição |
| 2 | storm_harpy | Vento: penas que desviam o 1º ataque do turno |
| 2 | rune_golem (elite) | Núcleo: runa no peito acende a cada Sobrecarga, quebrada por golpe perfurante do jogador |
| 2 | spectral_knight (elite) | Escudo-torre: Contra-ataque contado (Riposta) |
| 2 | storm_griffin (mini) | Carga elétrica: raios em volta, 3 cargas = Mergulho da Tempestade |
| 3 | ember_imp | Risada: cada risada acende uma chama; chamas viram Bola de Fogo |
| 3 | hellhound | Matilha de 2 cabeças: Mordida Dupla segue o alvo marcado |
| 3 | abyss_acolyte | Pacto: o livro absorve dano que vira Força |
| 3 | obsidian_sentinel (elite) | Couraça de lascas: estilhaços voltam quando o jogador bate com pouco dano |
| 3 | pit_brute (elite) | Martelo erguido (carga) visível; cruzar 50% da vida derruba o martelo |
| 3 | abyss_watcher (mini) | Olhos: cada olho aberto esconde uma informação do intent |
| 4 | frost_wight / frost_wolf / rime_shaman | Geada leve (+1) reaproveitando a regra do Monarca; totem do xamã contado |
| 4 | glacier_knight / frost_troll (elites) | Escudo de gelo que racha; troll regenera por cristal |
| 4 | ice_wyrm (mini) | Sopro carregado: o chão congela 1 turno antes |
| 5 | bog_ghoul / plague_toad / leech_horror | Sanguessugas presas no painel (cura dele por sanguessuga) |
| 5 | mire_hag / croc_warrior (elites) | Caldeirão borbulha contando poções; casco que só abre após Rolamento |
| 5 | spore_mother (mini) | Esporos contados no ar que viram veneno ao estourar |
| 6 | dusk_shade / dusk_bat / grave_thrall | Sombra que copia a última carta; morcegos contados; parede de escudos |
| 6 | blood_duke / dullahan (elites) | Taça de sangue que enche com a cura; cabeça arremessada como projétil |
| 6 | fallen_angel (mini) | Penas sagradas contadas que viram Julgamento |

## Onde mora (implementado)

Ver seção "Implementação" abaixo, preenchida chefe a chefe.

[[boss_visuals]] · [[enemies]] · [[combat_beats]] · [[intent_visibility]] ·
[[damage_preview]] · [[balance_curves]]

## Implementação

### Motor (vale para os cinco)

- `src/systems/BossMechanics.lua`: lógica pura. `onSpawn` (pilha inicial),
  `forcedMove` (anúncio obrigatório, antes do opener), `shapeIntent` (campos do
  intent no anúncio), `onDamaged(enemy, hpLost, "hit"|"dot")` chamado por
  `Enemy:takeDamage`/`_applyDot` (enfileira EVENTOS, não muda nada na hora),
  `applyEvent` (aplica no beat), `turnEndSteps`/`applyStep` (passos do fim do
  turno do chefe, beat MICRO que só estica pra STATUS se algo aconteceu),
  `onHitLanded` (golpe que consome pilha), `strikeFor` (coreografia),
  `pillVars` (números extras do tooltip).
- `Game:_announceMechanicIfPending(sink)` entra no `settleEnemyDamage`: cada
  evento vira UM beat `boss.<kind>` (STATUS) na fila da carta que o causou.
- `src/ui/BossTokens.lua` + `src/data/boss_tokens.lua`: objetos contados
  (reconciliados com a pilha a cada quadro: entra animado, sai animado, 1ª
  leitura e reducedMotion já no lugar), golpe temático (`strike`: token que voa
  e é consumido no apex, ou projétil), rastro e clarão no impacto, sons com
  volume medido (`playSound`, carregados sob demanda), reação dos eventos
  (`react`). Chamado pelo `EnemyRenderer` ao lado da `BossAura`.
- Piloto: `AI.mechanicBonus` em `tools/balance_ai.lua` soma o valor do que a
  regra premia no placar da leva (piloto de busca: expert*).
- Galeria: `love . boss_rooms <ato>`: C/X sobem e descem o contador do chefe,
  G dispara o golpe temático. Capturas:
  `CARDGAME_HEADLESS=1 SHOT_SIZE=1600x900 lovec . test_one shot_mecanicas_chefes <id>`
  → `mecanicas_chefes/<id>_*.png` no save dir (cópias em
  `tools/preview_out/mecanicas_chefes/`). Trava: `test_boss_mechanics`.
- Arte: `tools/pixellab_boss_mechanics.py gen|pick` (ícones 64x64 com
  referência `status_poison`; objetos com referência no idle do chefe).

### Lich (implementado)

- Números em `enemies.lua` `tower_lich.mechanic` (`start 1, gain 1, max 4,
  breakPct 0.15`) e o golpe `rune_cataclysm` (multi, 0,5×, `runes = true`).
- Quebra conta vida PERDIDA (depois do Bloqueio) por golpe/pulso/espinho,
  nunca veneno/queimadura; zera no upkeep do jogador.
- Runas: 4 sprites (`tower_lich/mechanic/rune_0..3.png`, 32x32, candidatos
  15/4/19/31) em escala inteira CHEIA do chefe (na metade liam como cisco a
  1600x900). As 5 runas procedurais da aura saíram (mentiriam sobre a contagem).
- Ícone `status_runes` (candidato 0). Sons: `boss_rune_ignite` 0,34 (acende,
  -26 dB efetivo) e 0,30 (impacto), `boss_frost_shatter` 0,36 (quebra, -26 dB).
