---
name: Save System
description: SaveManager + Migrations com atomic write e versionamento; RunManager e SettingsMenu delegam toda persistência aqui
type: project
---
`engine/SaveManager.lua` + `engine/SaveMigrations.lua`. Inspirado em `balatro-source/engine/save_manager.lua` mas síncrono e com formato Lua serializado (não `string_packer`).

**Arquivos persistidos** (relativos ao save dir do LÖVE):
- `settings.lua` — volumes (master/music/sfx), fullscreen, crtShader, locale
- `run.save.lua` — corrida ativa (RunManager.currentRun) + `version` + `savedAt`

**API pública (`SaveManager`):**
- `loadSettings()` → table com defaults backfilled (`DEFAULT_SETTINGS`).
- `saveSettings(settings)` → atomic write.
- `loadRun()` → roda `Migrations.run` antes de retornar; nil se ausente/corrompido.
- `saveRun(runData)` → embrulha em `{version, savedAt, runData}` e escreve.
- `hasRun()` / `deleteRun()`.
- `serialize(value)` — exposto pra debug (recursivo, suporta string/number/bool/table).

**Atomic write (Out/2026, real):** `SaveManager.writeFile(path, text)` — `.tmp` lido de volta e validado, principal BOM rotaciona pra `.bak` (1 geração), promoção por `os.rename` com fallback verificado. Leitura `readDataFile`: principal → `.tmp` → `.bak`; principal ilegível copiado pra `.corrupt-<ts>`. Perfil (`profile.lua`, via ProfileStats) usa o mesmo caminho; sem geração legível = modo recuperação (não grava). Detalhes e lista do Steam Auto-Cloud em `memory/release_pipeline.md`. Trava: `test_save_integrity`.

**Migrations:**
- `Migrations.CURRENT_VERSION = "1.1"` (atualizar quando schema mudar).
- `handlers["1.0"](payload)` muta `payload.runData` e seta `payload.version="1.1"`. Adicionar handlers conforme necessário.
- Loop com guard de 32 iterações (anti-infinito).

**Wired-up:**
- `RunManager:saveRun/loadRun/deleteSave/hasSavedRun` (linhas ~305-330) delegam direto ao SaveManager.
- `components/SettingsMenu:_persist()` é chamado em cada mudança (volume slider, fullscreen toggle, CRT toggle, language). Constrói o snapshot lendo `_G.audioSystem`, `love.window.getFullscreen()`, `CRTShader.isEnabled()`, `I18n.getLocale()`.
- `main.lua:love.load` carrega settings ANTES de inicializar AudioManager/CRT, aplica fullscreen pré-init.

**SANDBOX de ferramenta (v10.1.3 — Jul/2026):** `PATHS` é um proxy
(metatable `__index`). Quando `_G.HEADLESS_TOOL` está setado — `main.lua`
liga pra QUALQUER execução com argumento (`love . screenshot_*`, `test_*`,
`smoke_*`, `demo_*`, `play`...) — `run`/`settings` apontam pra `*.tool.lua`
em vez de `run.save.lua`/`settings.lua`. **O jogador roda `love .` sem args.**
- **Bug que isso matou:** toda tool de captura/teste chama
  `startNewRun`+`startGame`, e `checkpointRun` (a cada andar) escrevia no
  `run.save.lua` REAL. Com sessões Claude rodando capturas o dia todo, o
  save do jogador era sobrescrito por runs warrior de validação → "abandono
  a run e ela ressuscita", "Continuar mostra run que não joguei". O fluxo de
  save/abandono em si está CORRETO (regressão: `love . test_saveflow`).
- Nunca deixe uma tool escrever no save do jogador: se criar tool nova que
  instancia `Game`/`RunManager`, o sandbox já cobre (flag universal por arg).

**How to apply:**
- Schema mudou? Bump `Migrations.CURRENT_VERSION`, adicione handler pra versão antiga.
- Save novo (perfil, metrics)? Adicione path em `SaveManager.PATHS` + funções `saveX`/`loadX` análogas.
- Settings novo campo? Adicione em `DEFAULT_SETTINGS` (backfill automático no load) e persista no `_persist()` do SettingsMenu.

## Estágio da run e o Continuar (revisão de lançamento, Out/2026)

`currentRun.stage` diz ONDE retomar; gravado pelo `main.lua` (`setRunStage`)
em cada ponto seguro e decidido por `ResumeFlow.stageAction(run)` (pura,
travada em `tools/test_lifecycle.lua`):

| stage | gravado em | Continuar abre |
|---|---|---|
| `battle` (ou nil = save antigo) | `Game:nextPhase` (vida do INÍCIO da luta) | a luta, do começo |
| `cashout` | `showRoundEval` | o cash out |
| `rewards` | `showCardRewards` (ouro já resgatado) | a recompensa |
| `rest` / `event` (+`stageEventId`) / `shop` | `openNonBattleNode` | o mesmo nó (evento pelo id: `Events.get`) |
| `event_done` / `rest_done` | EventScreen (após o apply) / RestScreen `_markCampUsed` | encruzilhada seguinte (nunca reaplica) |
| `fork` | fim de `showMapSelection` | encruzilhada (pendingNodes) |

Regras que nasceram com isso:
- "Salvar e sair" com `stage == "battle"` e estado `playing` **não regrava** —
  o save do início da luta vale (padrão StS; antes gravava a vida perdida com o
  inimigo voltando cheio).
- `checkpointRun` recusa jogador morto e `gameState` gameOver/victory (a morte
  atrás da pausa ressuscitava com 1 de vida).
- `checkVictory` apaga o save (o menu oferecia Continuar pro chefe vencido).
- `startGame(classId)` faz checkpoint na hora (run nova nasce salva).
- Save ilegível: `SaveManager.quarantineRun()` → `run.save.lua.corrupt` + aviso
  (ConfirmDialog em modo aviso); o Continuar some do menu.

## Vitrine persistida (anti-save-scum, Out/2026)

Loja e recompensa geradas para um nó moram em `currentRun.shopState`
(`{key, mode, offers, refreshCount, refreshCost}`; key = modo|ato|andar|#mapHistory).
`CardRewardScreen:show` RESTAURA se a chave bate (nunca regera) e, quando
gera, faz checkpoint na hora (RNG pós-geração no disco). Compra/estorno/reroll
espelham no currentRun; sair do nó (`_exitWithFlourish`) limpa. Antes o
Continuar regerava com o RNG avançado: restock grátis, reroll zerado, item
comprado de volta e — na recompensa — uma 2ª carta. `Game:setJokerActive`
fora da luta usa `checkpointRun` (o saveRun cru gravava a compra com o ouro
antigo). Eventos já eram seguros: o RNG do evento é salvo na abertura e a
escolha marca `event_done`. Pacote: não há pausa durante a abertura (captor
de input); fechar a janela no meio volta ao save da abertura da loja, e o
pacote, rerolado pelo mesmo estado do stream `shop`, sai idêntico.

## Inventário: o que o Continuar precisa trazer de volta (Out/2026)

Bug do dono que originou: "cliquei em Continuar e os PONTOS zeraram". O
`runScore` até viajava no save, mas a TopBar, a tela final, o recorde do
perfil e o XP de maestria leem `game.score`, que o `startGame` zera e só o
fim da PRÓXIMA luta reescrevia. Trava de tudo abaixo:
`love . test_one test_resume_state` (retrato profundo antes/depois em
cashout, rewards, fork, shop, rest, event, luta e endless; o retrato copia o
currentRun INTEIRO, então campo novo entra de graça).

| Estado | Onde vive | Volta como |
|---|---|---|
| classe, selo, deck (id/`up`/edição/selo), coringas + `jokerActive`, ledger de serviços (slots, compra extra, Cofre, custo da forja), ato/andar/endless/`floorsInEndless`/`campaignWon`, maldições e ciclo (`run.endless`), nós pendentes/atual (`enemyId`), `mapHistory`, roteiro, `eventHistory`, `recentEnemies`, `stage`/`stageEventId`, `shopState`, `scribeDice`, stats da tela final (`battlesWon`, `turnsTotal`, `playSeconds`, dano), flags de conquista da run (`_usedShop`...) | `currentRun` (o save É o currentRun) | direto |
| streams do Rng + pity (`meta`) | `currentRun.rngState` | `loadRun` |
| RNG do INÍCIO da luta | `currentRun.battleRng` (nextPhase, antes do embaralho) + `battleEnemyRng` (stream "enemy" no instante do spawn — o inimigo provisório do startGame e o resolveNode consomem o stream de jeitos diferentes) | luta retomada = mesma mão, mesmo golpe |
| vida, vida máx., mana base, ouro | `playerState` (syncRunPlayerState) | resumeRun |
| pontuação da run + `game.score` | `playerState.runScore` | resumeRun espelha em `game.score` (**era o bug**) |
| "RECORDE!" da run, recibo da última luta (cash out) | `playerState.scoreRecordBroken` / `lastBattleScore` | resumeRun (novo) |
| ouro ganho/gasto na run | `playerState.goldEarned`/`goldSpent` | resumeRun (novo) |
| conquistas, contadores, cartas vistas, dicas do tutorial, desbloqueios, maestria | `profile.lua` (ProfileStats) | `checkpointRun` agora faz `flush` (antes "Salvar e sair" perdia os contadores) |

**Derivado, nunca salvo** (recalculado no resume — salvar duplicaria a
fonte): teto de Bloqueio (ato), teto de juros (serviço Cofre), slots de
coringa (serviços + edição negativa), `jokerSlots`, `retainArmor`, baralho
jogável (`buildPlayableDeck`), nível da passiva de classe (ato).

**Transitório de luta, de propósito fora** (retomar = refazer a luta do
COMEÇO, padrão StS; o `battleRng` garante que é a MESMA luta): mão/pilhas,
mana atual, Bloqueio, Força/Destreza, orbes, buffs/debuffs, vida/intent do
inimigo, `_exhaustedThisBattle`, flags de turno, `battleTurn`,
`ScoreSystem._battle`. Fora da luta o inimigo provisório do resumeRun é
descartado e o RNG volta ao estado salvo (sair e voltar na loja não muda a
próxima luta; o nó não ganha `enemyId`). Também fora: `purchaseHistory`
(não exibido), `currentPhase` (só modo clássico).

Achados na mesma auditoria: a passiva do mago (orbe + Foco) era aplicada no
`nextPhase` ANTES do `resetTransientStats` e apagada — só a 1ª luta da run
(e as retomadas, em dobro) tinha Conduíte. Agora roda depois do reset, uma
vez. `serialize` agora escapa chave reservada (`end`) e ±inf/NaN — antes um
desses derrubava o save inteiro na validação do writeFile.
