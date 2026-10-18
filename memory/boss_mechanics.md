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
- Sons: SÓ arquivos que já existem em `audio/sfx/boss/` e `audio/sfx/` (corvos:
  `audio/sfx/boss/crow/` via `CrowSfx`, seção abaixo), com
  volume MEDIDO (média do arquivo + ganho, alvo de -24 a -27 dB efetivos, a
  faixa dos corvos depois da queixa "alto demais").

## Som dos corvos do rei-carniça (17/Out/2026)

> "O barulho do corvo ainda está muito ruim... Fica tipo duas vezes fazendo o
> 'war war' dele... Sempre que ataca faz isso, e sempre que aparece faz o mesmo
> barulho." (dono, 17/Out/2026)

**Antes** (medido por `love . test_one test_crow_sfx`, entrada + 10 turnos do
rei + morte, semente 4242): UM arquivo, `boss_crows_caw` (três grasnados
seguidos no próprio arquivo), tocava no rasante e no pouso da entrada (2×) e em
todo mergulho de corvo com intervalo de 1,4 s (12× em 3 revoadas, 4 por
revoada); `boss_crows_flee` (dois grasnados) na morte e na subida do coringa
(2×). A invocação tocava o rugido genérico `enemyBuffRoar`.

**Agora:** 4 momentos, 3 variantes cada, em `audio/sfx/boss/crow/<momento>_<n>.mp3`
(registro por SCAN em `src/systems/CrowSfx.lua`: arquivo novo = soltar na pasta):

| momento | código | quando | conteúdo |
|---|---|---|---|
| aparecer | `crowAppear` | invocação (`Game`, beat `enemy.summon`, no lugar do rugido) | asas chegando; só 1 variante tem um grasnado curto |
| ataque | `crowDive` | 1º golpe da Revoada com corvo em órbita (`CrowSfx.attack`) | whoosh de mergulho + bicada seca, sem grasnado |
| revoada | `crowFlock` | 2º som da revoada longa (3+ golpes), pouso da entrada, subida do coringa | asas em massa, sem grasnado |
| cinemática | `crowCine` | rasante da entrada (`caw = true`) e explosão da morte | UM grasnado cheio + asas |

Regras (`CrowSfx`): pool sem repetir a variante anterior, pitch ±4-7%, cooldown
de 1,2 s por momento (cinemática 0,6 s) e do ataque como um todo; numa revoada
de N golpes toca no máximo 2 sons (mergulho no 1º, bando uma vez depois do
cooldown), nunca um por corvo. O som do mergulho sai 0,18 s depois do beat
(`DIVE_DELAY`, pelo `EventManager`) para a bicada cair perto do apex. O som não
depende de reducedMotion (som é informação). **Depois** (mesma simulação):
aparecer 3 (uma por invocação), mergulho 3 + bando 3 (uma revoada = 2 sons),
cinemática 2 (entrada 1, morte 1), bando 2 fora da luta (pouso, coringa).

Geração: ElevenLabs `sound-generation` (prompts em `tools/generate_sfx.py`,
ids `appear_1`...`cine_3`), 20 candidatos (~260 créditos), escolhidos por
envelope e espectrograma (descartados: mergulho com assobio tonal, bando
baixo com algo tonal no meio, cinemática fraca). Pós: silêncio cortado nas
pontas (-50/-55 dB), mono 44,1 kHz, média normalizada em -20,4 dB (pico
≤ -1 dB), fade 4 ms / até 60 ms. Volume no `loadSound`: aparecer 0,55,
mergulho 0,45, bando 0,50, cinemática 0,60 → -25,6 / -27,3 / -26,4 / -24,8 dB
efetivos (faixa -24 a -27 das regras acima). Amostras para o dono ouvir:
`audio/_amostras_corvo/` (fora do scan). **Licença:** plano FREE do
ElevenLabs, sem uso comercial: regerar no plano pago antes de vender.
Trava: `test_crow_sfx` (arquivos e códigos antigos fora, momentos com códigos
e arquivos exclusivos, sem repetição, cooldown, agrupamento, luta simulada).

## Ato 2: tower_lich, Runas do Ritual

- **Regra.** O lich nasce sem runa (`runes`) e acende +1 no fim de cada
  turno dele (teto 4). Com 4 runas o próximo anúncio é o **Cataclismo
  Rúnico**: 1 golpe por runa (0,45 × dano), cada golpe consome uma runa.
- **Contra-jogo.** A cada **12% da vida máxima** de dano que passa (vida
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
  mais forte (+8% do dano base como Força, mínimo 1, do próximo anúncio em diante).
- **Contra-jogo.** Guardar o dano pra cruzar a marca no turno em que ele
  anunciou o Fogo Infernal (a carga de Reunir Chamas dá um turno inteiro de
  aviso) corta o maior golpe da luta pela metade. Cruzar marca à toa só o
  fortalece.
- **Status/ícone.** `chains` → `status_chains`.
- **Visual.** Correntes de verdade (elo em sprite repetido ao longo da linha)
  saindo de pontos PINTADOS do salão até o corpo; rompida = estala em brasa,
  as metades caem balançando e somem. O tirano dá o tranco (hurt) na ruptura.
  UM sistema só desde 15/Out/2026 (ver "Correntes: um sistema só" abaixo).
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

- **Regra.** O Colosso nasce com **2 raízes** (`roots`, teto 3) e ganha +1 a
  cada 2 turnos dele. No fim de cada turno ele regenera **0,65% da vida máxima
  por raiz** (2 raízes = 1,3%, 3 raízes = 1,95%).
- **Contra-jogo.** Um único ATAQUE que tire **4% da vida máxima** (depois do
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

- Números em `enemies.lua` `tower_lich.mechanic` (`start 0, gain 1, max 4,
  breakPct 0.12`) e o golpe `rune_cataclysm` (multi, 0,45×, `runes = true`).
- Quebra conta vida PERDIDA (depois do Bloqueio) por golpe/pulso/espinho,
  nunca veneno/queimadura; zera no upkeep do jogador.
- Runas: 4 sprites (`tower_lich/mechanic/rune_0..3.png`, 32x32, candidatos
  15/4/19/31) em escala inteira CHEIA do chefe (na metade liam como cisco a
  1600x900). As 5 runas procedurais da aura saíram (mentiriam sobre a contagem).
- Ícone `status_runes` (candidato 0). Sons: `boss_rune_ignite` 0,34 (acende,
  -26 dB efetivo) e 0,30 (impacto), `boss_frost_shatter` 0,36 (quebra, -26 dB).

### Tirano (implementado)

- `abyss_tyrant.mechanic` = `marks {0.75, 0.5, 0.25}`, `strengthPct 0.08`,
  `stagger 0.5`. A detecção da marca é na hora do dano (golpe OU queimadura),
  a ruptura (pilha -1, Força, metade do golpe anunciado) acontece no beat
  `boss.chain_break`. O "uma vez por turno" zera no upkeep do jogador.
- `BM.hpMarks(enemy)` → marcas douradas na barra de vida (`EnemyHud.drawHpBar`)
  para as correntes que faltam E para fases de kit ainda não atingidas (a
  Rainha ganhou a marca dos 50% de graça).
- Intent cambaleado ganha linha própria no tooltip (`enemy_kit.intent.staggered`).
- Cena: `layout = "chains"` (ver "Correntes: um sistema só" abaixo).
- Golpe: Fogo Infernal e Jorro de Cinzas disparam `fireball.png` do núcleo do
  peito, girada na direção do voo em degraus de 15 graus, com rastro aditivo.
- Sons: `tyrant_chain_snap` 0,45 (-26 dB), `impact-fire` 0,30/0,22 (-26/-29 dB).

### Correntes: um sistema só (15/Out/2026)

> "Por que está tendo dois tipos de correntes diferentes ali nesse boss de
> fogo? ... verificar de onde cada corrente está saindo certinho ... padronizar
> as correntes" (dono, captura do salão em combate com 3 no contador)

**Causa.** Dois sistemas desenhavam corrente no mesmo chefe: o antigo
`T3.bond` da cinemática (`BossCinematic`, 4 correntes FINAS procedurais de
retângulos, âncoras `InteriorFX.HALLS[3].chainAnchors` nos pilares e nos
chifres do portão, quebrando sozinho pela VIDA em 0,72/0,52/0,38/enfurecido,
cruzando a tela em X) e o novo da mecânica (`BossTokens`, 3 correntes em
sprite com pontas em coordenada do SPRITE: uma "do teto" a -0,55 da altura,
atravessando o HUD do inimigo, e duas "do chão" a 34% de largura fora do
corpo, saindo do vazio). Contagem 4 + 3 contra 3 da regra.

**Agora.** Só `src/ui/BossTokens.lua` desenha corrente do tirano, e a fonte
da verdade é a pilha `chains` do `BossMechanics` (3 = 75/50/25%):

- Dado: `src/data/boss_tokens.lua` → `abyss_tyrant.chains[i] = { from = {x,y}
  em px da ARTE do salão (`hall = 3`), grip = nome, front, sag }`. Ordem =
  ordem de ruptura ao contrário (a de índice maior rompe primeiro):
  1. tornozelo direito ← argola no PISO à direita dos pés (258,196), rompe nos 25%;
  2. pulso esquerdo ← pilar escuro esquerdo onde a corrente PINTADA termina (90,144), 50%;
  3. pulso direito ← pilar escuro direito, espelho (310,144), 75%.
  Âncora → tela pelo cover-fit (`SceneBackground.getCoverTransform`, passado
  como `opts.hallTr` do `GameplayScene` ao `EnemyRenderer.draw` → `auraRect`).
  Sem `hallTr` não desenha (aviso `Debug.warn`), nunca inventa ponta.
- Pegada no corpo: `src/data/boss_chain_grips.lua`, gerado por
  `python tools/tyrant_chain_assets.py` (casamento de padrão do recorte 14x14
  do idle quadro 0 em TODO quadro de TODO clipe: idle, stride, hurt, roar,
  attack, attack_strong, death), em px do PRÓPRIO quadro. O `auraRect` leva
  `clip`/`frame`, então a corrente acompanha a respiração, o tranco, o rugido
  e o bote. O tool também escreve o `grips_sheet.png` de conferência.
- Elo: `mechanic/chain_link.png` agora é 5x8 (aro de frente + elo de lado,
  paleta do elo antigo), desenhado na ESCALA DE PIXEL do sprite
  (`round(scale)`), ladrilhado ao longo de uma curva com barriga e girado em
  degraus de pi/16. A argola da âncora é o próprio aro (linhas 0-4) e fica
  na parede/piso mesmo depois de a corrente romper.
- Ruptura: o beat `boss.chain_break` baixa a pilha → `_syncChains` rompe a
  MESMA corrente (estilhaços no ponto de corte, metades em brasa aditiva que
  balançam e caem, 0,9 s); som/tremor/hurt continuam no `BossTokens.react`.
  Morte: `sync` marca `dead` com vida 0 e TODAS as restantes rompem na hora
  (um som só, `deathSnap`).
- Cinemática: o passo `chains` cria só `T3.bond = { id, state = drag }`;
  durante o `walk_in` o `T3.drawBond` chama `BossTokens.drawChainsAt` com o
  retângulo do andarilho (clipe `stride`, escala da perspectiva) e a folga vem
  de `BossTokens.setSlack` (0,30 arrastando, tranco amortecido no pouso,
  0 depois). O "SOLTO" (`T3.free`: rugido `tyrantUnchained` + aura + brasas)
  dispara quando `BossTokens.chainState(id).intact` cai a 0, nunca pela vida.
  Removidos: `chainAnchors`, `bonds`, `makeBond/ensureBond/chainShouldBreak/
  bondGrip/snapChain/drawChainLinks`.
- Travas: `test_boss_mechanics` (`testTyrantChains`: desenhadas = inteiras em
  3/2/1/0 nas 4 resoluções 1600x900, 1920x1080, 1280x720, 1024x768; âncora
  visível no recorte do cover-fit; toda pegada em pixel OPACO de todo quadro;
  só `boss_tokens.lua` conhece o elo; a cinemática delega e não rompe por
  vida) e `test_boss_cinematic` (drag/taut, folga volta a 0, solto só pela
  mecânica). Capturas: `lovec . test_one shot_correntes_tirano` com
  `SHOT_SIZE=WxH` → `correntes_tirano/` no save dir.

### Monarca (implementado)

- A Geada mora no JOGADOR (`player.frost`, inteiro), zera em
  `applyClassBattleStartPassive` e no spawn do Continuar. Pill `frost` no
  `PlayerBuffPills` (com o limiar no tooltip).
- `winter_monarch.mechanic` = `threshold 4, freeze 2, attackMelt 1, fireMelt 2`
  + `gains` por golpe. `shapeIntent` grava `intent.frost` (congelado no
  anúncio; a névoa `type_only` NÃO esconde, é tipo, como o debuff).
  `BM.intentSteps` vira o beat `boss.frost_gain` (STATUS, depois do golpe).
- Congelar acontece no beat `player.draw`: `BM.onPlayerDraw` marca
  `card.frozen` nas 2 de maior custo (empate: a mais à esquerda) e tira 4.
  `Game:canPlayCard` recusa congelada, `selectCard` avisa (`card_frozen`) e não
  gasta mana; `discardHandEndOfTurn` derrete (`BM.thaw`, `_thawAt` pro fade).
  Ataque jogado derrete (`BM.onPlayerAttack`, tag `fire` derrete 2) num beat
  MICRO `player.frost_melt`.
- Pilotos: `balance_ai.playable` e as escolhas do `autoplay` (pick, naive,
  motor, bestDamageSet) pulam carta congelada; `AI.mechanicBonus` premia a
  leva que derrete o bastante pra fugir do congelamento.
- Cena: `layout = "screen"`: `BossTokens.drawScreen(game)` (chamado pela
  `GameplayScene` antes do HUD) cresce cristais de gelo dos cantos de baixo
  (sprite `frost_corner`, escala inteira pelo nível Geada/limiar; a 3/4 surgem
  mais dois cantos acima); no congelamento os cantos piscam. Carta congelada:
  `ice_block.png` por cima da carta (`Card:draw`, alfa 0,62: a arte ainda lê),
  some em 0,45 s no degelo. reducedMotion: nível sem transição.
- Golpe: Lâmina do Inverno e Nevasca Real disparam `ice_shard.png` do orbe do
  cajado. Sons: `impact-ice` 0,90 no impacto (-26 dB) e 0,70 na Geada,
  `boss_ice_crackle` 1,0 ao congelar (-37 dB, arquivo baixo de origem),
  `shop-crystal-shatter` 0,40 no derretimento (-30 dB).

### Colosso (implementado)

- A regeneração fixa (`passive.regenPct 0.015`) SAIU do kit: virou
  `rot_colossus.mechanic` = `start 2, max 3, growEvery 2, regenPct 0.0065`
  (por raiz) `, cutPct 0.04` (números do mc2, ver Balanceamento).
  `Enemy:tickRegen` soma `BM.regenBonus` à pilha `regen` (que continua valendo
  pra outros inimigos); o beat `enemy.regen` passa a existir se houver raiz.
- Corte: vida PERDIDA num único `takeDamage` (fonte "hit": carta, orbe,
  espinho) >= 5% da vida máxima enfileira `root_cut`. Bloqueio do Colosso
  segura e, se segurar o bastante, não corta. Veneno/queimadura nunca.
- Crescimento: passo de fim de turno `root_grow` conta os turnos dele e brota
  uma raiz nos pares (beat MICRO que só estica se brotou).
- Cena: `layout = "ground"`: 4 vagas fixas em volta dos pés (2 na frente, 2
  atrás, espelhadas), raiz sobe do chão revelando linhas do sprite (quad por
  altura, sem esticar) e murcha afundando escura. Na regeneração a seiva
  acende as raízes (aditivo verde subindo). Sprites `root_0..3.png` (32x64,
  candidatos 3/12/19/7), escala cheia.
- Golpe: Pancada Colossal e Golpe Pútrido fazem uma raiz romper do pé da tela
  sob o painel do herói no apex e afundar no recuo (`kind = "rise"`).
- Sons: `boss_roots_crawl` 0,90 ao brotar (-29 dB), `colossus_crack` 0,75 no
  corte (-26 dB), `impact-poison` 1,0 no golpe (-31 dB).
- `test_enemies` passou a medir a cura pela regra das raízes.

### Rainha (implementado)

- `eclipse_queen.mechanic` = `cycle 4, full 2, new 4, fullMul 1.5`. A fase
  gira DENTRO de `rollIntent` (`BM.shapeIntent`): todo anúncio avança a lua,
  inclusive o primeiro (Crescente). Cheia: `perHit ×1,5` no próprio anúncio
  (congelado, o HUD já mostra maior). Nova: `vulnerable` duração 1 no inimigo,
  que vale o turno inteiro do jogador e cai no `onTurnEnd` dela (a prévia de
  dano já lê Vulnerável do inimigo, sem conta nova). A fase do eclipse (<50%)
  segue por cima, e a marca dos 50% aparece na barra (hpMarks).
- Aviso: `BM.afterRoll` no beat `enemy.next_intent` (estica pra STATUS só na
  Cheia e na Nova): texto flutuante + `boss_eclipse_phase` 0,09 (arquivo
  -5 dB, efetivo -26) na Cheia, `boss_crown_tick` 0,75 na Nova (-26).
- Pill `moon` sem número (`stacks = 1` na cópia do HUD) e tooltip pela fase
  (`variant` p1..p4 → `enemy_kit.status.moon.desc_p<n>`).
- Cena: `layout = "moon"`: lua (sprite `moon.png`, candidato 12) à direita da
  cabeça, acima da asa (no centro ela sumia atrás da barra de vida e no feixe
  branco). As 4 fases são DERIVADAS do sprite (`BossTokens.moonImage`):
  terminador elíptico por pixel, lado apagado escurecido e violeta, sem
  redimensionar; troca de fase com crossfade de 0,45 s; brilho atrás ∝ parte
  acesa. reducedMotion: sem crossfade nem balanço.
- Golpe: Lâminas Lunares, Chuva de Estrelas e Coroa Negra lançam a lâmina
  crescente (sprite `crescent.png`) girando em degraus de 15°; impacto
  `impact-arcane` 0,32 (-27 dB).

## Balanceamento (15/Out/2026)

Bateria `python tools/balance.py --runs 30 --classes <c> --pilots average,expert_full
--seeds 720000 --procs 4`, uma classe por vez. Base = main antes das mecânicas
(`d075d734`, já com a regra dos coringas raros), mesmas seeds.

| expert_full | guerreiro | mago | ladino | média |
|---|---|---|---|---|
| base (d075d734) | 37% | 30% | 40% | 36% |
| mc (números do roteiro) | 40% | 23% | 43% | 35% |
| **mc2 (adotado)** | 27% | 40% | 47% | 38% |

average: 3/0/3% nas três medições (morre no A1/A2, chefes do A3+ quase não
aparecem). IC de 30 runs ±17pp: a queda do guerreiro no mc2 vem de semente
(o diff do mc2 só ENFRAQUECE chefes), decisão do lead.

Ajuste mc → mc2 (porque no mc o mago passou a morrer no lich 0→4 e no colosso
2→6, com 38 de vida perdida por luta contra 11):
- lich: nasce com 0 runas (era 1), quebra a cada 12% (era 15%), Cataclismo
  0,45× por golpe (era 0,5×);
- tirano: +8% do dano base por corrente (era 12%);
- colosso: teto 3 raízes (era 4), 0,65%/raiz (era 0,75%), corte com 4% (era 5%).

Mortes por chefe, expert_full, base → mc2 (G / M / L): lich 1→0 / 0→4 / 1→2;
tirano 2→4 / 2→0 / 1→2; monarca 3→3 / 2→0 / 1→0; colosso 6→6 / 2→2 / 3→4;
rainha 1→3 / 0→1 / 2→1. Vida perdida por luta de chefe sobe no LICH (G 11→13,
M 8→11, L 7→15): é o chefe que mais pune quem não explode o turno, e fica
monitorado; monarca e tirano ficaram mais leves pra quem lê a regra.
Relatórios: `reports/balance/mc2_<classe>/` (worktree mecchefes) e
`reports/balance/mcbase_<classe>/` (worktree mecchefes-base).
