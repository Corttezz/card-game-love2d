---
name: boss_cinematics
description: Out/2026. Cinemática de chefe (entrada no salão VAZIO + morte em câmera lenta) — roteiro por dados (src/data/boss_cinematics.lua), runner BossCinematic, como a cena/InputFocus/main.lua se encaixam, pular, reducedMotion, Continuar, prova visual. Protótipo só no carrion_king.
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

## Entradas dos outros 5 chefes — PROPOSTA (aguarda aprovação do dono)

Mesma espinha (salão vazio → presença → chegada → impacto → cartão → HUD),
linguagem própria por chefe. Passos novos marcados com ★ (o runner avisa
kind desconhecido até existirem). Tempos ~6-7 s, reduced ~3 s.

| chefe | conceito | passos (dados) |
|---|---|---|
| **tower_lich** (A2, flutua) | O salão gela: cristais de geada sobem pelas colunas, o círculo rúnico do chão acende runa por runa, e o lich SOBE do piso dentro de uma tempestade de neve/geada, cajado por último, orbe acendendo. Impacto = o círculo completa + onda de gelo. | `dark 0.8` → ★`runes {n=5, dur 1.6}` (círculo da BossAura.floor acende em sequência, mist branco-azul) → ★`rise {from="floor", dur 1.4, storm="frost"}` (chefe sobe do piso: scissor na linha do chão do chão pra cima NÃO — recorte pela silhueta: desenha o clip idle deslocado pra baixo e vai subindo, com névoa cobrindo o pé) → `land {shake 8, ring="ice"}` → `title` → `hud` |
| **abyss_tyrant** (A3, pisa) | A porta do fundo (portão-caveira) ESTOURA: lascas e brasas, uma PAREDE DE FOGO INFERNAL sobe atrás, correntes caem das paredes e ele atravessa o fogo andando (apoiado — sem voo). Impacto = pisada: shake forte, rachadura de lava no chão. | `dark 0.7` → ★`door_burst {u=0.5, v=0.55, dur 0.6, debris=18}` → ★`firewall {dur 1.6, h=0.5}` (cortina de chamas em bandas, HallAnim-like) → ★`walk_in {from="back", dur 1.6}` (sprite cresce do backYr até yr pela depthSizeK) → ★`chains {n=4}` (correntes caem e balançam, kind opcional) → `land {shake 18, ring="lava"}` → `title` → `hud` |
| **winter_monarch** (A4, pisa) | NEVASCA: o salão vira branco (whiteout em 3 degraus de dither), o vento uiva, as chamas azuis quase apagam; a silhueta escura aparece dentro do branco, cada vez mais nítida, e a nevasca assenta revelando o monarca já no palco. Impacto = o cajado bate no chão: cristais erguem do piso. | `dark 0.3` → ★`whiteout {dur 2.0, peak 0.9}` → ★`silhouette {dur 1.4}` (chefe desenhado em preto sólido, alpha subindo, dentro do branco) → ★`settle {dur 0.8}` (whiteout cai, neve do InteriorFX ×3) → `land {shake 10, ring="frost", staff=true}` → `title` → `hud` |
| **rot_colossus** (A5, pisa) | O coração de raízes do fundo BATE mais forte e mais rápido (pulses do hall 5), raízes rastejam do túnel pelo chão (bandas de pixel), esporos e vaga-lumes fogem; o colosso EMERGE do túnel ao fundo e vem pra frente arrastando os pés (chão treme a cada passo). Impacto = último passo: lama/esporos explodem. | `dark 0.6` → ★`heartbeat {dur 1.8, rate 2.4}` (pulse do InteriorFX acelera) → ★`roots {n=6, dur 1.2}` → ★`walk_in {from="back", dur 2.0, stomp=0.5}` (shake a cada passo) → `land {shake 16, ring="spores"}` → `title` → `hud` |
| **eclipse_queen** (A6, flutua) | O ECLIPSE pintado na abertura do fundo fecha de vez: o salão escurece até a coroa de raios, pétalas caem, e a rainha DESCE da abertura de asas abertas, em contraluz (silhueta magenta), até o palco; a luz volta com ela. Impacto = pouso leve + onda magenta. | `dark 0.9` → ★`eclipse {dur 1.6}` (disco cobre, coroa de raios, mist magenta) → ★`descend {from="opening", u=0.5, v=0.25, dur 1.8, backlit=true}` (sprite desce com alpha de contraluz → cor cheia no fim) → `land {shake 9, ring="petal"}` → `title` → `hud` |

Mortes (mesma máquina `death`): lich se desfaz em geada (burst "frost"), tirano
afunda na lava do chão (slowmo + desat quente), monarca estilhaça (burst de
cristais), colosso desaba e vira esporos, rainha vira pétalas e o eclipse
abre. Cada uma = `burst {kind=...}` novo + `desat` com tom próprio.

Infra comum necessária antes: `land.ring` escolhe cor/forma da onda,
`burst.kind` escolhe a partícula, `walk_in`/`rise`/`descend` precisam de um
"desenhador do chefe fora do lugar" genérico (hoje o rasante usa o clip idle
próprio — vira `drawBossAt(x, y, opts)` compartilhado). Chefes apoiados
NUNCA voam.

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
