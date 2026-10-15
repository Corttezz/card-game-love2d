---
name: boss_cinematics
description: Out/2026. Cinemática de chefe (entrada no salão VAZIO + morte em câmera lenta) — roteiro por dados (src/data/boss_cinematics.lua), runner BossCinematic, como a cena/InputFocus/main.lua se encaixam, pular, reducedMotion, Continuar, prova visual. Os 6 chefes com entrada e morte por elemento (Out/2026); cortina da mão (HandDeal).
type: project
---

# Cinemática de chefe (Out/2026) — protótipo no rei-carniça

**Ordem fixada pelo dono:** porta do castelo abre (cerimônia já existente,
`WorldRoad.enterCastle`) → salão abre **VAZIO** (chefe ausente, HUD do
inimigo/mão/botões/painel do herói escondidos; TopBar fica) → a ENTRADA toca
dentro do salão, com o cenário do próprio salão → cartão com nome + epíteto →
HUD volta → luta. **Morte:** colapso em câmera lenta (clip de death + queda
existentes), luz saindo dos olhos (BossAura já apaga), rajada de penas e
corvos, dessaturação breve, o corpo fica no salão e SÓ DEPOIS cash out.

## Peças

| peça | arquivo |
|---|---|
| roteiro por chefe | `src/data/boss_cinematics.lua` — `intro`, `introReduced`, `death`, `deathReduced`; passos `{kind, dur, ...}` (dur = compasso; efeitos com envelope continuam) |
| runner | `src/ui/BossCinematic.lua` — linha do tempo própria (dt acumulado, não EventManager: pular = saltar pro estado final; testa sem fila); passos `dark/eyes/flyby/land/title/hud` e `slowmo/burst/desat/hold` |
| cena | `GameplayScene`: `_onBossEntered` (porta) chama `startIntro`; `hidesBoss()` → `EnemyRenderer.draw` roda num canvas descartado (`BossCinematic.measure`) só pra MEDIR o pouso (bbox + `lastFoot.drawX/drawY`); `drawBack` após `InteriorFX.draw`, `drawFront` antes de `InteriorFX.drawFront`; `hidesHud()` esconde HUD/mão/botões/coringas/prévia; `drawUI` (cartão) antes dos fades; `beginWorldPass/endWorldPass` embrulham o mundo pra dessaturar (`shaders/desat.glsl`); gates de vitória/espólios esperam `holdsEnd()` |
| input | `BossCinematic.overlay` registrado PRIMEIRO no InputFocus (menor prioridade: pausa/deck ganham dela) com `ownsNavigation` (NavCursor não come o Enter); main.lua: `combatFrozen` tem exceção pra `activeName() == "bossCinematic"` — é a única captora que deixa o relógio da cena correr |
| hooks novos | `EnemyRenderer.setTimeScale/getTimeScale` (câmera lenta só do corpo), `lastFoot.drawX`; `InteriorFX.gust(strength, dur)` (chamas baixam/tremem quando o chefe passa) |
| sons | `audio/sfx/boss/` (ElevenLabs FREE — regenerar; known_gaps §0b), registrados sob demanda em `loadSounds`; fallback por `Sfx.has` (sceneRustle / sceneStoneThud / enemyBuffRoar) |
| i18n | `src/i18n/locales/boss_cinematics/<loc>.lua` (`skip`, `<id>.name/.epithet`), 1 require por locale principal |
| trava | `tools/test_boss_cinematic.lua` (75 asserções) |
| ao vivo | `love . boss_rooms` (ou `lovec`): **I** = entrada a partir do salão vazio, **K** = morte pelo pipeline real (beat → clip → cinemática), **ENTER** pula; a sala remonta com `GameplayScene.setGame` (zera a cinemática anterior) |
| prova visual | `CARDGAME_HEADLESS=1 CARDGAME_IDENTITY=boss-cine lovec . test_one shot_boss_cinematic both` (pelo test_one: o main.lua não tem entrada própria pra ele) → quadros em `%APPDATA%/LOVE/boss-cine/`; `python tools/boss_cinematic_sheet.py <save_dir>` → `tools/preview_out/boss_cinematic/` (prancha 12+6 e GIFs) |

## Regras

- **Continuar NÃO repete a entrada**: `ResumeFlow.apply` usa
  `_debugForceBossEntered` (salão direto); só a porta chama `_onBossEntered`.
  Save no meio da entrada → volta direto na luta.
- **Pular** só depois de `SKIP_AFTER` (1 s): o clique que fechou a porta não
  pode engolir a entrada. Pular = estado final (chefe no palco, HUD on).
- **Morte vira cinemática SÓ no salão** (`ctx.inHall`): o mini-boss tem
  `isBoss` e luta na estrada. Detecção por `game._deathHandled` (o
  `Game:_onEnemyDeath` já encenou clip/som/shake); `deathFor` impede repetir.
- `reducedMotion` = roteiro curto (sem varrer a tela, uma piscada), nunca sem
  o nome do chefe (informação fica).
- Chefe sem roteiro luta como antes (`startIntro` devolve false). Chefes
  APOIADOS (atos 3/4/5) pedem outra entrada (porta estourando / subir do
  chão): o formato aceita kinds novos — o runner AVISA kind desconhecido.
- Ferramenta com relógio simulado: `love.timer.getTime` tem que ANDAR dentro
  do quadro (laço com orçamento de tempo do prewarm do WorldRoad trava com
  relógio parado — custou um processo preso nesta sessão).
- `love.exe` sem console engole o print: rode ferramentas com `lovec`.
- **Mão/botões/coringas/prévia somem nas DUAS fases** (`hidesHand`); na morte
  o HUD de vida e a TopBar ficam (`hidesHud` é só da entrada). **Toasts ficam
  na fila** durante a cinemática (MessageSystem sem tick nem draw): a "carta
  desbloqueada" do chefe vencido aparecia por cima do corpo caindo.
- Rasante: o chefe é AUTO-ILUMINADO (rim light aditiva violeta, olhos de
  brasa nas âncoras dos emissivos, fantasmas claros, rastro de luz) — o salão
  continua a 0.86 de escuro; as arandelas FLAREIAM (`InteriorFX.gust`) na
  passagem. Revisão do lead: com o sprite escurecido junto do salão o voo não
  lia.

## Rodada 3 (dono, ao vivo): "efeito de túnel", nebuloso com cor, efeito de tela

- **"Checkered/boxy" nos rasantes** era o RASTRO em retângulos aditivos e os
  halos retangulares dos olhos. Regra: **nenhum `rectangle` de luz** — brilho
  é `glowBlob` (textura de névoa gerada: value noise + 3 degraus de alpha com
  dither Bayer 4×4, borda esfarelada). Rim light = a própria silhueta
  deslocada (alpha-tested por natureza). Fantasmas = o sprite.
- **Névoa colorida** (`spawnMist`/`drawMist`): 24 puffs em 3 camadas com
  paralaxe (2 atrás, 1 na frente, fina), posição truncada na grade da arte,
  corpo violeta escuro + brilho aditivo violeta/brasa (é o brilho que sangra
  cor na pedra). Sobe nos olhos (1.2 s), a rajada do rasante empurra
  (`InteriorFX.gustLevel × direção`), cai a 0.35 no pouso e some no cartão.
  reducedMotion: parada.
- **Efeito de tela do pouso** (`startHit` → `drawScreenFx` na UI +
  `BossCinematic.worldZoom` aplicado pelo GameplayScene só no MUNDO): flash
  na cor do chefe em 3 degraus de tempo, 2 anéis de choque em blocos na
  grade com dither Bayer no esvaecer, vinheta em 3 bandas, `CRTShader.jolt`
  (faixa de glitch agora) e soco de zoom 1.0→1.06→1.0 com translação
  inteira; + shake/jiggle/poeira/corvos/penas já existentes. reducedMotion:
  só a vinheta suave. **Sem gradiente liso em nada.**

## v3 do rei-carniça (dono, 2ª olhada ao vivo)

- **Olhos**: amêndoa 12×7 (aro de brasa escura, íris, núcleo), pupila em
  fenda que ACOMPANHA (deriva senoidal + sacadas), halo em blob, calor
  subindo em blobs finos tremendo, abertura lenta (0.6 s) do meio; rumor
  grave em LOOP enquanto abertos (`playLoop`, para no exit) + clique a cada
  piscada.
- **Rasante = vulto**: passagens com `scale` crescente (0.8 longe → 1.55
  colada na câmera → pouso), fantasmas com atraso de 1 quadro quando perto,
  riscos de velocidade longos em 3 degraus pela faixa inteira, brilho
  próprio aditivo, whoosh de borda (`drawEdge`: blobs na borda de entrada
  e de saída), rajada empurra a névoa 230 px/s e flareia as chamas; clip
  PixelLab `dive` a 14 fps quando instalado (senão idle 2.6×).
- **Clips PixelLab** (`tools/pixellab_boss_cine.py run <id>`): animate_image
  com frame 0 = idle real (on-model por construção) → `animations/<clip>/south/`.
  carrion_king: `dive` (rasante), `land` (pouso), `roar` (cartão).
  `EnemyRenderer.playClip(name, fps)` toca one-shot e volta pro idle;
  `hasClip` decide. Prancha: `python tools/pixellab_boss_cine.py sheet <id>`.
- **Som em tudo** (`audio/sfx/boss/`, ElevenLabs FREE — regerar): olhos
  (ignite + rumble loop + blink click), rasante (wing pass com pitch por
  distância, crows caw na 1ª), pouso (land impact, feathers settle 0.45 s
  depois, caw), cartão (sting); morte (death thud no slowmo, feather burst +
  crows flee no burst, hold ambience em loop no hold). Fila própria
  `queueSfx` (relógio da cinemática) e `loops` parados no `finish`. Volume
  pelo grupo sfx do AudioManager. `BossCinematic.SOUNDS` é conferido pelo
  teste (todo arquivo existe).

## Entradas dos outros 5 chefes — IMPLEMENTADAS (Out/2026, commits 9e347e4 → rainha)

Mesma espinha (salão vazio → presença → chegada → impacto → cartão → HUD),
linguagem própria por chefe. Dados em `src/data/boss_cinematics.lua` (o
cabeçalho documenta todos os kinds e campos); cada chefe tem `palette`
(névoa, brilhos, flash e partículas usam ela) e os dois roteiros de morte.

| chefe | entrada (dados) | morte |
|---|---|---|
| **tower_lich** (A2, flutua) | `dark` → `runes n=5` (glifos 3×5 em blocos de ~1,6 px da arte, círculo pontilhado fecha e FICA até o pouso) → `rise clip=rise storm=bossFrostStorm` (recorte na linha do chão, geada branca subindo) → `land ring=ice particle=shard` → `title clip=roar` | lascas (`shard`) + `bossFrostShatter`, slowmo, desat |
| **abyss_tyrant** (A3, pisa) — **v2 Out/2026** (dono: "as correntes saem do céu; poderiam ser parte da fase, ligadas a ele") | `dark` → `door_burst` → `firewall hold=2.3` → `chains` (as 3 CORRENTES DA MECÂNICA nascem frouxas; desde 15/Out/2026 são as MESMAS do `BossTokens`, desenhadas por `BossTokens.drawChainsAt` no andarilho, âncoras pintadas em `src/data/boss_tokens.lua`, ver `memory/boss_mechanics.md` "Correntes: um sistema só") → `walk_in clip=stride` (ele entra ARRASTANDO, `tyrantChainDrag`, folga via `BossTokens.setSlack`) → `land ring=lava` (esticam com tranco, `tyrantChainTaut`) → `title clip=roar`. **Luta**: quem rompe corrente é a mecânica (75/50/25%, beat `boss.chain_break`), nunca a vida na cinemática; com 0 inteiras = SOLTO (`T3.free`: `tyrantUnchained`, aura maior + brasas do chão). Morte rompe as restantes. Zero mudança de número. | brasas + `lava` (poça cresce sob o corpo, bolhas) + `bossLavaImplosion`, desat curta |
| **winter_monarch** (A4, pisa) — **v2 Out/2026** (dono: "a silhueta poderia durar mais e ficar mais marcada") | `dark` → `whiteout peak=0.9` (5 degraus, teto 0,72; rajadas de névoa em 2 camadas, flocos esticados, uivo em loop) → `silhouette dur=3.8 clip=walk far=0.38 strike=2.75 strikeClip=roar` (vulto preto SÓLIDO com borda fria de 1 px, longe e pequeno na borda de trás do piso, cresce ANDANDO até o palco; aos 2,75 s o cajado bate ainda em silhueta: flash frio + onda de geada + tremor + lascas, `monarchStrike`) → `settle` (a neve assenta, a cor entra) → `land clip=false hit=false ring=frost` (só a revelação) → `title` | 34 lascas + `bossFrostShatter` |
| **rot_colossus** (A5, pisa) — **v2 Out/2026** (dono: "do nada surgindo, não fez sentido") | `dark` → `heartbeat rate=2.4 hold=4.2` → `roots n=7 from=walls grasp` (raízes v3: caminho em segmentos de 12-20 px com cotovelos, nós e raminhos; pincel de 5→2 células da arte, marrom-esverdeado do próprio salão em dither, aresta clara só do lado da luz, verde SÓ na ponta que agarra, sem brilho aditivo; descem das bocas pintadas `InteriorFX.HALLS[5].rootMouths` e agarram o palco; vinheta da batida é ELÍPTICA em degraus com dither, nunca moldura reta) → `assemble block=5` (o corpo se MONTA de blocos do próprio quadro 0 do idle puxados do chão, pés → tronco → cabeça, `colossusAssemble`) → `land clip=roar cracks ring=spores` (raízes se retraem, ele ergue a cabeça, o chão racha com luz verde vazando, `colossusCrack`) → `title clip=false` | sem slowmo: `crumble delay=0.7 roots=6` (chefe real escondido; raízes agarram e soltam; blocos caem com gravidade, quicam, viram monte + esporos; o monte esvaece sobre o cadáver real) + `colossusCrumble` |
| **eclipse_queen** (A6, flutua) | `dark` → `eclipse u=.5 v=.227` (disco + coroa pontilhada, zumbido) → `descend clip=descend backlit` (silhueta → cor cheia) → `land ring=petal particle=petal` → `title clip=roar` | pétalas + `bossEclipseBreak` + `dawn` (luz morna cresce na abertura, feixe até o corpo) |

Infra que entrou pra isso: `land.ring` (RING_STYLES: cores da onda),
`land.particle/burst/sound/clip/crows`, `burst.particle/sound`, kinds de
morte `lava`/`dawn`, `ownAnim(clip, dur)` (o clip ocupa o passo inteiro;
sem clip, idle), `footInfo()` = onde o EnemyRenderer vai desenhar (os
desenhadores "fora do lugar" terminam EXATAMENTE ali). Chefes apoiados
nunca voam. Clips PixelLab de cada um em `animations/<clip>/south/`
(quadros fora do modelo descartados: carrion `dive` 7-8, rainha `descend`
7-8; colosso `roar` regerado sem nuvens brancas).

Prova visual por chefe: `BOSS_CINE_ACT=n CARDGAME_HEADLESS=1 CARDGAME_IDENTITY=x
lovec . test_one shot_boss_cinematic both` + `python tools/boss_cinematic_sheet.py
<save_dir> tools/preview_out/boss_cinematic <id>` → `boss_cine_{intro,death}_<id>_sheet.png`.
`test_boss_cinematic` roda entrada e morte de TODO chefe (normal + reduced)
e cobra nome/epíteto nos 5 locales.

## Rainha do Eclipse v2 — o chefe FINAL (Out/2026, frente rainha-eclipse)

> "No 6 eu gostei bastante, mas ainda tem muito que melhorar. Esse é o boss
> final. Algo mais macabro, mais estiloso, música tipo Radagon/Besta
> Prístina, entradas mais marcantes." (dono)

Entrada de **14,1 s** (reduced 6,7 s, com os três atos), pulável após 1 s:

| ato | kind | o que acontece |
|---|---|---|
| 1. pressentimento | `omen` (3,6 s, `steps=4`) | a luz do vão **morre em 4 degraus** (tique por degrau, silêncio entre eles: `bossBlinkClick` agendado), o eclipse pintado vira **íris** (pupila em fenda magenta que acompanha), a coroa **sangra** (dentes do halo quebrado escorrem em blocos), cinzas caem, névoa magenta sobe; `bossEclipseOmen` + loop `bossEclipseHum` |
| 2. manifestação | `unveil` (3,2 s, clip `unveil`) + `descend` | **olhos demais** (6 pares que não são dela, `STRAY_EYES`) acendem no escuro do vão e somem quando ela acende; a silhueta em **casulo de asas** se abre em contraluz (borda = silhueta deslocada em 4 direções, aditiva; corpo quase preto), **sombra no mármore maior que ela** (quadro espelhado 1,35×1,7, corpo violeta + cópia aditiva), halo quebrado dourado sobre a cabeça; o `descend` existente traz do vão ao palco |
| 3. coroação | `coronation` (4,4 s, clip `crown`, `cadence=0.085`) | cartão **próprio** (não o `title`): faixa negra com fio magenta, nome em ouro com sombra magenta **letra a letra** (`bossCrownTick` com pitch subindo), halos quebrados girando em sentidos opostos ladeando, epíteto letra a letra depois, **stinger** `bossEclipseCrown` + flash em 3 degraus + jolt do CRT na última letra |

Tudo mora na seção "RAINHA DO ECLIPSE v2" de `src/ui/BossCinematic.lua`
(`queenEnter/queenExit/queenUpdate/queenDrawBack/queenDrawFront/queenDrawUI`,
um gancho de uma linha em cada ponto do runner). Paleta própria
magenta/dourado/negro (`GOLD`, `MAGENTA`, `WARM`).

**Luta por fases (só visual; o kit em `src/data/enemies.lua` NÃO muda):**
`queenUpdate` observa `enemy._phaseIdx` com `ctx.inHall`; a virada ganha um
instante próprio (`fx.phaseShift`: coroa larga esvaecendo, pétalas do vão,
`bossEclipsePhase`, shake) e `eclipse.level` → `InteriorFX.setEclipse(level,
dawn)`: no salão 6 a luz do vão morre em 4 degraus (faixa x 160..240 da arte,
bordas na parede), a névoa do chão vira violeta, as poeiras do feixe ficam
magenta; `queenDrawFront` põe o **halo quebrado magenta** sobre a cabeça dela;
a íris olha o jogador de vez em quando (`eclipse.gaze`, Poisson ~7-13 s;
`_debugGaze()` pra captura). O estado SOBREVIVE ao fim da entrada
(módulo, zerado em `reset()`/`startIntro`).

**Morte v2:** `burst` com partícula **`ash`** (pétala 2×2 que esmaece de
magenta pra cinza e SOBE), `dawn` v2 (`drawDawnV2`: o disco pintado abre num
**crescente** de luz, a luz chega em **5 bandas** pelo vão de cima pra baixo, o
mármore acende em volta do corpo; `InteriorFX` redesenha o feixe e o reflexo
em aditivo morno), `bossEclipseFade` (a voz dela apagando), slowmo 1,7 s, hold
1,8 s. A alvorada **persiste** no cash out/espólios; Continuar com a rainha
morta nasce em alvorada (`queenUpdate`: `deathFor == enemy` e vida 0).

**Música:** `musicBossEclipse` (`audio/music/music-boss-eclipse.mp3`, coral +
órgão + sinos + taiko com virada dissonante, 28 s em loop; placeholder até a
faixa longa `boss-eclipse_queen.mp3`). Desde 14/Out/2026 vale a regra do
silêncio para TODO chefe (ver "Silêncio antes do chefe" em
[[music_generation]]): bandeira, viagem, porta e entrada sem música; a faixa
do chefe entra no fim da entrada (ou no pular) e segue por luta, morte e
cash out (`roundEval` → nil). Validação:
`love . check_loop eclipse` (salto 0,0013, razão 1,04x, DC 0,0014, brilho 0,78k).

Clips PixelLab (`tools/pixellab_boss_cine.py run eclipse_queen`): `unveil`
(asas fecham em casulo nos quadros 3-5 e reabrem) e `crown` (braços erguidos).
Travas: `test_boss_cinematic` (§6d: escala 12-18 s, três atos também no
reduced, todas as letras chegam, fase fecha o salão sem cinemática, alvorada
persiste, Continuar morta, reset limpa) + `test_music`. Provas:
`BOSS_CINE_ACT=6 ... shot_boss_cinematic both|phases` →
`tools/preview_out/boss_cinematic/boss_cine_{intro,death,phases}_eclipse_queen_sheet.png` (+GIF).

## Cash out e espólios DENTRO do salão (Out/2026, dono)

Depois da morte do chefe, o fundo do cash out (`roundEval`, que desenha
`GameplayScene.draw` com a mesa fechada) e dos espólios (`cardReward`, que
desenha `GameplayScene.drawWorldOnly`) é o SALÃO com o cadáver, nunca a
estrada: `GameplayScene.worldOnlyMode()` devolve `"hall"` enquanto o nó for
o do chefe com a porta já aberta (`inBossRoom` e não `isEntering`), e
`drawWorldOnly` então roda o `draw()` em `WORLD_ONLY` (corta antes da UI).
A estrada só volta quando a encruzilhada troca o nó (`advanceFloorInAct`) —
a encruzilhada em si é a saída, na estrada. Música: `MusicDirector.pick`
devolve nil em `roundEval` (o tema do chefe segue pelo salão; a faixa do ato
novo entra na encruzilhada). Travas: `test_hand_deal` (2b) + `test_music`;
prova: `boss_cine_death_hall.png` do `shot_boss_cinematic death`.

## O nó de chefe inteiro (auditoria Out/2026, pedido do lead)

1. **Caminhada** (`WorldRoad.travel`, 6,5 s): castelo cresce; cortina da mão
   abaixada; HUD do herói fica; tema do chefe já toca (`playing` + `boss`).
2. **Porta** (`WorldRoad.enterCastle`, 1,4 s + fade 0,9 s): HUD some junto;
   cliques engolidos; som do portão.
3. **Salão vazio → entrada** (`_onBossEntered` → `BossCinematic.startIntro`,
   6-9 s; genérica se o chefe não tiver roteiro): cartão nome+epíteto; pular
   depois de 1 s.
4. **Cartas dadas** (HandDeal, 0,11 s/carta) → botões + HUD → luta.
5. **Morte** (`_deathHandled` no salão → `startDeath`): câmera lenta, rajada,
   dessaturação, corpo no chão; segura espólios (`holdsEnd`). Mesa fechada.
6. **Cash out** (`roundEval`, desenha `GameplayScene.draw` com mesa fechada):
   SALÃO + corpo; música mantida (pick → nil).
7. **Espólios** (`cardReward` → `drawWorldOnly` = "hall"): salão + corpo;
   uma das 3 vagas é o coringa PRÓPRIO do chefe, que subiu do corpo no fim
   da morte (passo `trophy`, [[boss_jokers]]); música mantida.
8. **Encruzilhada** (`showMapSelection` → `advanceFloorInAct`, `journalEnd`):
   o nó muda → `isInteriorNode` cai → estrada; cura inter-ato no `nextPhase`
   do andar seguinte; faixa do ato novo entra aqui.
9. **Continuar** no meio: `battle` → salão direto SEM entrada
   (`_debugForceBossEntered`); `cashout`/`rewards` → inimigo nasce morto
   (`__resumeRunStage`: health 0, `_deathHandled`, clip de morte) e
   `BossCinematic.markDeathSeen` impede reencenar a morte; `worldOnlyMode`
   = "hall". Trava em `test_boss_cinematic`.

Ajustes da revisão do lead (Out/2026): whiteout do monarca com teto 0,72
(a 0,82 as colunas não se liam a 1:1); raízes do colosso a 1 bloco por px
da arte em ambos os eixos e corpo a meio caminho do brilho (a 2 px e escuro
viravam linha pontilhada). Recortes 1:1 em `tools/preview_out/boss_cinematic/
{monarch_whiteout,colossus_roots}_1to1.png`.

## Cortina da mão + distribuição (Out/2026, bug do dono)

> "a mão, os botões e o HUD aparecem no meio da porta e da entrada"

`src/ui/HandDeal.lua`, dirigido pelo `GameplayScene.update` (bloco "CORTINA
DA MÃO", avaliado DEPOIS do gatilho da viagem — o andar novo nasce atrás
dela). Cortina abaixada em TODA cutscene: viagem na estrada, cerimônia da
porta, salão à espera do chefe (`bossEntered=false`), `BossCinematic.isActive()`
(entrada E morte) e a quicada de chegada (`EnemyRenderer.getArrivalOffset`).
Com ela abaixada: zero carta, zero botão, zero coringa, zero prévia/toast; no
caminho do castelo (porta + salão, `opts.hud`) o HUD do herói e o do inimigo
esperam também — na estrada o HUD fica (é status, não cutscene).

Quando sobe: as cartas da mão voltam pra PILHA (`dissolve=1`, renderPos no
`game:getDeckOrigin()`) e saem uma a uma (`STAGGER` 0.11 s, materialize +
`cardDraw` com pitch subindo); botões/coringas/HUD só `TAIL` 0.3 s depois da
última. Linha do tempo própria (sem EventManager a carta aparece na hora).
Cortina que desce no meio interrompe (quem faltava fica na pilha) e a subida
seguinte redistribui do zero. Inimigo morto (espólios a caminho) = sem
distribuição. Atrás da cortina a mão não recebe hover nem clique
(`HandDeal.isBusy`), o auto-encerrar não roda e o narrador espera
(`GameplayScene.isQuiet`).

**Chefe sem roteiro próprio** ganha a entrada GENÉRICA (`BossCinematic.GENERIC`:
escuro → impacto no palco → cartão com o nome → HUD): o salão nunca mais abre
com o chefe já parado e a mão na tela. Inimigo comum não tem entrada.

Travas: `test_hand_deal` (módulo puro; cena real viagem → porta → entrada →
distribuição com ZERO carta até o fim da entrada, uma carta por compasso,
botões/HUD depois da última; genérica; estrada: inimigo chega → cartas, HUD
fica; clique cego não seleciona) e `test_boss_cinematic`. Prova visual:
`CARDGAME_HEADLESS=1 CARDGAME_IDENTITY=boss-cine lovec . test_one shot_boss_cinematic arrival`
(`BOSS_CINE_ACT=n` escolhe o chefe) → `python tools/boss_cinematic_sheet.py
<save_dir> [out_dir] [tag]` monta `boss_cine_arrival_sheet.png` + GIF.

[[boss_visuals]] · [[boss_halls]] · [[combat_beats]] · [[input_focus]] · [[onboarding]]
