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
| prova visual | `CARDGAME_HEADLESS=1 CARDGAME_IDENTITY=boss-cine lovec . shot_boss_cinematic both` → quadros em `%APPDATA%/LOVE/boss-cine/`; `python tools/boss_cinematic_sheet.py <save_dir>` → `tools/preview_out/boss_cinematic/` (prancha 12+6 e GIFs) |

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

[[boss_visuals]] · [[boss_halls]] · [[combat_beats]] · [[input_focus]] · [[onboarding]]
