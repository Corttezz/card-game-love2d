---
name: code_notes/main.lua
description: Comentários com decisão/regra/histórico colhidos de main.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `main.lua`

Origem: `main.lua` em `7dbdb60d` (219 de 344 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `require("src.core.Release").install()`)

> PRIMEIRA linha de proposito: errorhandler amigavel + log + modo DEV/RELEASE
> ativos antes de qualquer require do jogo (um erro carregando modulo ja
> passa pelo handler). Sem `local`: love.load vive no teto de 60 upvalues.

## L61-63 (junto a `local restScreen`)

> _G.jokerManagerScreen mora em _G (não como upvalue): love.load já está no teto
> de 60 upvalues do Lua e um a mais estoura o compilador. Segue o padrão dos
> outros singletons globais do arquivo (_G.togglePauseMenu etc.).

## L72-74 (junto a `local smokeSystem -- Sistema de partículas de smoke`)

> Screen shake agora vive em src/systems/ScreenShake.lua.
> _G.triggerShake é registrado em love.load via ScreenShake.install() pra
> manter back-compat com sistemas que já usam.

## L78-79 (junto a `local function startGame(classId, seal)`)

> Função para iniciar o jogo com classe selecionada
> seal = Selo do Grimório escolhido na seleção de classe (0..10).

## L90-93 (em `startGame`, junto a `game:checkpointRun()`)

> A corrida NOVA nasce salva. Sem isto o primeiro save só vinha no andar
> 2: fechar a janela na primeira luta fazia o Continuar carregar a run
> ANTERIOR (que o jogador já tinha confirmado descartar), e morrer na
> primeira luta apagava aquela run antiga.

## L97-98 (em `startGame`, junto a `GameplayScene.requestArrival()`)

> a primeira luta CHEGA (viagem na estrada + cortina + cartas dadas),
> em vez de nascer pronta na tela (dono, 13/Out)

## L112-117 (em `returnToMenu`, junto a `EventManager.clear()`)

> Mata TODAS as sequências pendentes do jogo descartado (combate, eases,
> transições agendadas). Sem isto, callbacks do game VELHO continuavam
> rodando por baixo do menu — re-salvavam a run recém-abandonada e até
> puxavam currentState de volta pro jogo ("abandonei, cliquei em Jogar e
> caí na run antiga" — playtest Jul/2026). Ordem importa: clear ANTES de
> menu:show() (a intro do menu agenda eases novos).

## L120-125 (em `returnToMenu`, junto a `require("src.ui.InputFocus").hideAll()`)

> Toda tela da run SOME junto. As de estado (descanso/evento/mapa/cash
> out) são coberturas no InputFocus: uma delas visível por baixo do menu
> tomava o foco e o menu ficava MORTO — nenhum botão respondia depois de
> "Salvar e sair" no acampamento (revisão de lançamento, Out/2026).
> (InputFocus.hideAll cobre todo overlay registrado — tela nova entra de
> graça; a loja/recompensa é tela de ESTADO, fora do registro.)

## L128-130 (em `returnToMenu`, junto a `require("src.ui.EndTransition").clear()`)

> Morte/vitória em curso (TV desligando) morre aqui também: o callback
> dela trocava o estado pra gameOver POR CIMA do menu. powerOn substitui
> a animação de desligar (e o callback dela) e devolve a imagem.

## L134-135 (em `returnToMenu`, junto a `if game and game.runManager then`)

> A run antiga morre NA MEMÓRIA também. deleteSave/saveRun já decidiram o
> disco; isto impede qualquer checkpointRun retardatário de ressuscitá-la.

## L144-145 (em `returnToMenu`, junto a `if topBar then topBar:setGame(game) end`)

> Re-vincula a TopBar ao game NOVO (antes ficava apontando pro morto:
> ouro/deck congelavam e o clique da engrenagem caía no aviso).

## L147-150 (em `returnToMenu`, junto a `GameplayScene.setGame(game)`)

> Re-vincula a CENA DE GAMEPLAY ao game novo (bug Jul/2026: a cena
> capturava deps.game e seguia desenhando a run ABANDONADA — "abandonei,
> escolhi mago e caí na run antiga com tudo bugado"). Também zera o
> estado de turno do módulo (turnStage/bossEntered per-run).

## L157-167 (em `returnToMenu`, junto a `local function replayRun()`)

> Recomeçar da tela de fim de run (R no game over, ESPAÇO na vitória).
>
> Antes os dois chamavam `startGame()` SEM classe, e isso estourava:
> RunManager.lua:29: Classe nao encontrada: nil
> ou seja, o jogo CRASHAVA ao vencer — o pior momento possível pra quebrar,
> porque é onde a run inteira está em jogo (bug do dono, Set/2026).
>
> Reusa a classe da run que acabou, que é o que o jogador espera de
> "tentar de novo". Sem classe (save antigo, estado inesperado), vai pra
> SELEÇÃO em vez de adivinhar — e avisa, porque chegar aqui sem classe é
> anômalo.

## L174-176 (em `replayRun`, junto a `local run = game and game.runManager and game.runManager.currentRun`)

> Mesmo Selo da run que acabou (limitado ao que a classe já liberou
> — vencer com o selo k pode ter acabado de abrir o k+1, mas repetir
> é repetir).

## L184-185 (em `replayRun`, junto a `classSelectionScreen:show(`)

> MESMOS callbacks do Jogar: sem eles a escolha de classe e o Voltar
> só avisavam no console — tela sem saída.

## L200-201 (em `applyActSmoke`, junto a `local preset`)

> Presets de smoke existem só pros 3 primeiros atos; os atos 4-6 herdam o
> do irmão de clima (mesma escolha do salão de chefe em GameplayScene).

## L209-213 (em `porAto`, junto a `_G.openCardPicker = function(mode, onDone)`)

> Abre o picker de cartas como OVERLAY de qualquer estado (oferta "Forja" da
> loja, eventos de deck). Reusa o RestScreen no modo pedido ("forge" |
> "remove" | "duplicate"): troca temporariamente pro estado "rest" (que já
> roteia update/draw/input do RestScreen) e restaura o estado anterior ao
> fechar. onDone roda após a restauração.

## L231-232 (em `skipBattleAndShowMap`, junto a `game._exhaustedThisBattle = game._exhaustedThisBattle or {}`)

> Forca advance como se uma batalha tivesse sido vencida sem combate.
> Processa exhaust pendente para consistencia.

## L234-235 (em `skipBattleAndShowMap`, junto a `showMapSelection()`)

> Nao incrementa currentPhase para nao bagunçar scoring; o floor da run
> avança em showMapSelection via advanceFloorInAct.

## L237-239 (em `skipBattleAndShowMap`, junto a `game:checkpointRun()`)

> Nós SEM batalha (descanso/evento/loja) não passavam por checkpointRun
> (só Game:nextPhase salvava) — o roteiro deles só chegava ao disco na
> batalha seguinte. Salva aqui, depois do journalEnd de showMapSelection.

## L243-252 (em `skipBattleAndShowMap`, junto a `local function setRunStage(stage, extra)`)

> ONDE a run está, pra o Continuar retomar no MESMO lugar (revisão de
> lançamento, Out/2026). Antes o save só sabia "nó corrente" e o resume SEMPRE
> abria batalha: "Salvar e sair" no acampamento/evento/loja voltava como uma
> LUTA, e sair no cash out/recompensa refazia a batalha já vencida com o ouro
> e a carta no bolso (farm infinito). Estágios:
> "battle"  luta em andamento   -> retoma a luta do COMEÇO (save do início)
> "cashout" vitória, antes do Resgatar -> reabre o cash out
> "rewards" ouro resgatado, carta não escolhida -> reabre a recompensa
> "rest" | "event" | "shop"     -> reabre o nó
> "fork"    encruzilhada (pendingNodes) -> escolhe o caminho

## L261-262 (em `setRunStage`, junto a `local function openNonBattleNode(t, eventId)`)

> Abre um nó SEM batalha (descanso/evento/loja). Usado na escolha do caminho
> e no Continuar. `eventId` (opcional) reabre o MESMO evento salvo.

## L271-272 (em `openNonBattleNode`, junto a `skipBattleAndShowMap()`)

> Note: REST consome o slot do floor (floorInAct ja avancou no showMapSelection).
> O proximo showMapSelection vai gerar novos nodes.

## L282-285 (em `openNonBattleNode`, junto a `ev = Events.roll(run.actNumber or 1, run.eventHistory,`)

> Sorteio pelo stream "event" com histórico: evento visto não repete
> no MESMO ato (Events.roll libera repetição se a pool do ato esgotar).
> Bioma da CENA (endless roda 4,5,6,1,...): evento de bioma segue
> o cenario, nao o numero do ato.

## L290-291 (em `openNonBattleNode`, junto a `game.runManager:journalEvent(ev.id, nil, nil)`)

> ROTEIRO: o evento sorteado entra já; a OPÇÃO escolhida é anotada
> pelo EventScreen no clique (antes do apply).

## L301-302 (em `openNonBattleNode`, junto a `mapScreen:hide()`)

> Reusa CardRewardScreen como shop em modo "shop":
> 4 cartas + 1 voucher + 2 packs + reroll exponencial + skip +3g.

## L322-324 (em `onNodeChosen`, junto a `game.runManager:chooseNode(index, {`)

> Snapshot de entrada do nó pro ROTEIRO (o RunManager não enxerga o Game).
> Inline de propósito: um local novo no topo do arquivo viraria upvalue de
> love.load, que já está no teto de 60 do LuaJIT (ver _G.openCardPicker).

## L360-363 (em `showMapSelection`, junto a `game.runManager:journalEnd({`)

> ROTEIRO: fecha a entrada do nó que acabou de resolver. Este é o choke
> point por onde TODO nó passa depois de resolvido (batalha, descanso,
> evento, loja) — journalEnd é idempotente, então o caminho de reentrada
> abaixo (guard de pendingNodes) não faz mal.

## L370-371 (em `showMapSelection`, junto a `if not game.runManager:getPendingNodes() then`)

> Se nao ha nos pendentes, avanca o floor e gera novos. Guard contra
> duplo-advance (usuario voltar e abrir o mapa de novo).

## L382-384 (em `showMapSelection`, junto a `local GameplayScene = require("src.scenes.GameplayScene")`)

> v5 (A Encruzilhada): na estrada, a escolha acontece NO MUNDO — a
> estrada se bifurca e cada braço tem um marco. MapScreen vira fallback
> (cena não-worldroad ou falha ao montar o fork).

## L395-397 (em `showMapSelection`, junto a `setRunStage("fork")`)

> Encruzilhada é ponto seguro: salva aqui (antes, depois de uma BATALHA
> nada salvava até o próximo nó — fechar a janela na encruzilhada
> devolvia o jogador à luta já vencida, sem a carta e o ouro).

## L400-403 (em `showMapSelection`, junto a `_G.__showMapSelection = function() showMapSelection() end`)

> Hook global pro callback de Continuar (rotear pro mapa quando o save
> foi na encruzilhada). Referenciar a local direto no callback estourava
> o limite de 60 upvalues do love.load (LuaJIT) — mesmo padrão do
> _G.openCardPicker.

## L407-411 (em `_G.__showMapSelection`, junto a `local function continueAfterReward()`)

> Continua o jogo após escolher/pular recompensa.
> Vitoria agora e disparada por Game:checkVictory (chefe do ultimo ato). Para
> decidir se mostra o mapa ou nao, apenas checamos se o game ja marcou vitoria.
> A run NAO e encerrada aqui (antes chamava endCurrentRun): ela fica viva na
> tela de vitoria para o "Seguir no Endless"; Menu/Tentar de novo descartam.

## L424-426 (em `continueAfterReward`, junto a `showRoundEval = function()`)

> Mostra a tela de Round Eval (cash out estilo Balatro). Triggered após
> batalha vencida em modo run, antes da loja. Sources construídas por
> Game:_buildRoundEvalSources. Click "Resgatar" → showCardRewards.

## L448-449 (em `showCardRewards`, junto a `cardRewardScreen:show(game,`)

> F12.2: battleVictory já toca em showRoundEval (antes deste fluxo). Remover
> aqui evita som duplicado quando jogador clica Resgatar e abre cardReward.

## L463-465 (em `showCardRewards`, junto a `EndScreens.setCallbacks({`)

> Botões das telas finais (src/scenes/EndScreens.lua). No escopo do ARQUIVO,
> não no love.load: closures criadas lá dentro virariam upvalues dele, que
> vive no teto de 60 do LuaJIT.

## L469-473 (em `onMenu`, junto a `onEndless = function()`)

> Seguir no Endless (só na vitória): a vitória JÁ foi registrada no
> checkVictory; enterEndless liga o modo e devolve a run ao jogo. O chefe
> final paga o cash out e a recompensa como qualquer chefe, e a
> encruzilhada (showMapSelection → advanceFloorInAct) leva ao andar 1 do
> endless — e volta a salvar.

## L484-486 (em `onEndless`, junto a `_G.__resumeRunStage = function()`)

> Continuar: reabre o ESTÁGIO salvo (ver setRunStage). Devolve true se tratou
> (o caller não precisa fazer mais nada). Hook global pelo mesmo motivo do
> __showMapSelection (teto de upvalues do love.load).

## L492-493 (em `_G.__resumeRunStage`, junto a `if game.enemy then`)

> A luta deste nó JÁ acabou (ou o nó nem tem luta): o inimigo que o
> resumeRun montou não pode ficar de pé atrás do cash out/descanso.

## L512-513 (em `love.load`, junto a `require("src.ui.UiScale").adoptDefaults()`)

> ESCALA DE UI: adota as telas ANTES de qualquer tool/teste/tela nascer
> (lista e motivo em src/ui/UiScale.lua → adoptDefaults).

## L515-523 (em `love.load`, junto a `loveArgs = require("src.core.Release").filterArgs(loveArgs)`)

> QUALQUER execução com argumento é ferramenta/dev (screenshot/smoke/
> test/preview/demo/play...) — o jogador de verdade roda `love .` sem
> args. A flag manda sistemas persistentes pro SANDBOX: ProfileStats
> vira no-op e o SaveManager troca run/settings pra *.tool.lua.
> BUG que isso mata (Jul/2026): as tools chamavam startNewRun+startGame
> e o checkpointRun SOBRESCREVIA o run.save.lua do JOGADOR — "abandono a
> run e ela ressuscita; aparece run que nunca joguei" (o save fantasma
> era das capturas de validação, recriado a cada tool rodada).
> RELEASE: nenhum argumento chega ao dispatcher (tools/ nem vai no pacote).

## L530-532 (em `love.load`, junto a `require("src.systems.UnlockSystem").setOverrideAll(true)`)

> Meta-progressão: ferramenta (autoplay/balanceamento/smokes) mede o
> CATÁLOGO INTEIRO e as 3 classes. Teste que quer o comportamento real
> desliga explicitamente (test_unlocks).

## L534-536 (em `love.load`, junto a `if os.getenv("TOOL_WINDOW") then`)

> TOOL_WINDOW=1920x1080: janela de captura em tamanho fixo ANTES de
> qualquer tool montar layout (screenshots da loja Steam:
> tools/store_art.py). Tool com setMode próprio sobrescreve.

## L543-553 (em `love.load`, junto a `local HW = require("tools.headless_window")`)

> SEM JANELA VISÍVEL, MAS COM JANELA DE TRABALHO (Out/2026). Com
> CARDGAME_HEADLESS=1 o conf.lua faz a janela nascer 1x1 fora da
> tela. Pra bateria de balanceamento bastava; pra suíte não: dez
> suites desenham no backbuffer REAL (GameplayScene/LightEngine com
> scissor negativo, NavCursor sem alvo, grade da forja com uma carta
> só, mouse do CRT, vitrine de desbloqueio) e falhavam IGUAIS em três
> rodadas — parecia carga, era a janela. UMA chamada de setMode
> (repetir dentro de tool trava — memory/ui_layout_invariants.md) pro
> tamanho de referência das capturas, no mesmo lugar fora de qualquer
> monitor, e escondida da barra de tarefas (user32, idempotente).
> Quem pede TOOL_WINDOW já escolheu o tamanho e não entra aqui.

## L566-567 (em `love.load`, junto a `require("src.systems.UnlockSystem").ensure()`)

> Migração de perfil antigo → desbloqueios retroativos, ANTES de qualquer
> tela ler classe/carta liberada.

## L570-575 (em `love.load`, junto a `if toolArg and (tostring(toolArg):match("^screenshot_")`)

> IDIOMA DETERMINISTICO em captura visual (Set/2026). Tool de screenshot e
> preview existe pra REVISAO VISUAL — sair em alemao porque o sandbox
> herdou o locale de um `test_i18n` anterior ja custou 4 rodadas de
> captura refeita nesta sessao. O `test_i18n` restaura o locale de
> ENTRADA, entao uma vez que o sandbox vira "de" ele se auto-perpetua.
> Testes NAO entram aqui: test_i18n precisa girar os 5 idiomas.

## L578-580 (em `love.load`, junto a `_G.TOOL_FORCE_LOCALE = os.getenv("TOOL_LOCALE") or "pt_BR"`)

> A flag e lida DENTRO de I18n.init() -- 19 tools chamam init() por
> conta propria depois daqui, e antes disso o init relia o save por
> cima e desfazia o force. Setar a flag cobre todos os caminhos.

## L586-588 (em `love.load`, junto a `if not toolArg and require("src.core.Release").isDev() then`)

> DEBUG (caça "cartas não renderizam"): marca o BOOT no log de reward —
> prova imediata de que ESTE build (instrumentado) é o que está rodando
> (mtime do arquivo muda ao abrir o jogo, sem precisar chegar num reward).

## L593-594 (em `love.load`, junto a `pcall(love.filesystem.write, "feel_debug.log",`)

> DEBUG FEEL: prova de build no log do feel (mesma técnica do RDBG).
> write (não append): log fresco por SESSÃO, o boot é a 1ª linha.

## L600-602 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "preview_cards" then`)

> Modo preview: renderiza algumas cartas em PNG e sai.
> love . preview_cards
> Saida: ~/.local/share/love/card-game/preview_*.png

## L611-612 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "preview_button_border" then`)

> Borda do Button ANTES vs DEPOIS do fix do traço interno, 6x nearest.
> love . preview_button_border

## L619-620 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "preview_card_art_fix" then`)

> Contact sheet do fix de arte repetida (as 12 cartas que eram orfas no
> atlas + as 4 com que colidiam).  love . preview_card_art_fix

## L653-654 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "preview_card_anim" then`)

> Contact sheet de carta com ícone animado (icons_anim/).
> love . preview_card_anim [card_id]

## L661-663 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_gameplay" then`)

> Captura screenshot do gameplay (ato 1 warrior) pra debug visual.
> love . screenshot_gameplay
> Saida: ~/.local/share/love/card-game/gameplay_screenshot.png

## L676-677 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_enemy_scene" then`)

> Captura o WorldRoad (mundo rolante): 3 biomas ou "full" (1 bioma inteiro).
> love . screenshot_worldroad [full]

## L682-683 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_resume_boss" then`)

> Prova VISUAL do Continuar numa luta de chefe: save real → load →
> ResumeFlow → GameplayScene.draw.  love . screenshot_resume_boss [antes]

## L688 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_worldroad" then`)

> (boss_rooms despacha no FIM do love.load: precisa do áudio registrado)

## L694-695 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "measure_lightpool" then`)

> P6': a poça de luz aparece? A/B do MESMO frame com e sem luz, diff
> por pixel (arte assada no PNG subtrai a zero). love . measure_lightpool [bioma]

## L701-704 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "demo_worldroad" then`)

> Demo interativo do WorldRoad (SPACE=viagem, 1-6=bioma, E=encounter,
> V=vista, R=reset) OU tour automático com keyframes:
> love . demo_worldroad          (interativo)
> love . demo_worldroad tour     (captura 6 keyframes e sai)

## L710-711 (em `love.load`, junto a `local autoPlayClass = nil`)

> Quickstart: pula menu/seleção e cai DIRETO na batalha (validação).
> love . play [warrior|mage|rogue]

## L717-718 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_bootfx" then`)

> Captura 3 screenshots da animação death (early/mid/late).
> love . screenshot_death

## L729-738 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_event" then`)

> Valida a BIGORNA (RestScreen modo picker): grade de cartas reais,
> Envelope de SFX: duracao, pico, RMS e tempos de decaimento. Serve pra
> validar som gerado por IA no que IMPORTA — header de MP3 nao diz se a
> cauda e curta, e som percussivo tocado em sequencia (forgeStrike toca 3x
> a cada ~0.28s) vira lama se decair devagar.
> love . check_sfx           (todos)
> love . check_sfx forge     (filtra por substring)
> EventScreen nos 5 locales (prova que as chaves de i18n resolvem: chave
> errada cai no fallback PT e a tela fica perfeita SÓ em português).
> love . screenshot_event [locale]

## L745-746 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "check_event_i18n" then`)

> Rotulos de opcao de evento estouram o botao em algum idioma?
> love . check_event_i18n [largura]

## L753-754 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "check_font_metrics" then`)

> Metrica da fonte: altura reportada vs tinta real (entrelinha segura).
> love . check_font_metrics [10,12,14,20]

## L769-770 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_event_anim" then`)

> Contact sheet da entrada/saída da EventScreen (dosagem da animação).
> love . screenshot_event_anim

## L777-778 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "sfx_envelope" then`)

> Curva ASCII do envelope de UM sfx (a FORMA, não só os números).
> love . sfx_envelope card-shelf-place [janelaSegundos]

## L785-789 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "check_music" then`)

> Emenda de loop das faixas de musica (audio/music/*.mp3).
> love . check_loop           (todas)
> love . check_loop act       (filtra por substring)
> Percorre os contextos e diz qual faixa tocaria (mudo).
> love . check_music

## L801-802 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "probe_continue" then`)

> Contact sheet de PNGs (frames de anim, variacoes de arte).
> love . sheet <dir|a.png,b.png> [escala] [saida.png]

## L870-873 (em `love.load`, junto a `love.event.quit(ok and 0 or 1)`)

> Sem o quit a janela ficava aberta pra sempre depois de imprimir o
> relatório: rodar o tool por pipe (| grep, | tail) travava, porque a
> saída só libera quando o processo morre. Todos os outros tools da
> lista fecham; este era o único que não.

## L878-883 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_forge" then`)

> hover + painel de preview e os beats da animação de forja.
> love . screenshot_forge                  — janela padrao, pt_BR
> love . screenshot_forge 1600 900          — outra janela
> love . screenshot_forge - - de            — pt_BR trocado por outro idioma
> O 4o argumento existe pra validar TRADUCAO: e em idioma estrangeiro que
> o portugues cravado aparece.

## L892-895 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_death" then`)

> 2o arg = FONTE do golpe fatal. Sem arg, dispara a animacao na mao
> (valida o clip). `orb` mata pelo pipeline de verdade (pulso de orbe),
> que e justamente a fonte que NAO encenava morte nenhuma.
> love . screenshot_death [orb]

## L901-902 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_endscreens" then`)

> Telas de fim (GAME OVER / VITÓRIA). 2º arg = locale.
> love . screenshot_endscreens [locale]

## L908-909 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_achievements" then`)

> Galeria de conquistas. 2º arg = locale, ou "all" pros 5.
> love . screenshot_achievements all

## L918-919 (em `love.load`, junto a `_G.PREVIEW_HUD_CAP = (loveArgs[2] == "cap")`)

> 2o arg "cap": sobe o Bloqueio ao teto pra inspecionar o indicador
> de cap (halo ambar + "/30"), que so aparece a partir de 70%.

## L924-925 (em `love.load`, junto a `_G.PREVIEW_HUD_ORBS_EVOKE = (loveArgs[3] == "evoke")`)

> `orbs evoke`: mesma fileira com a mao sobre uma carta de Evocar --
> e onde os numeros e DOIS glifos mudam (sombra vira dano).

## L927-928 (em `love.load`, junto a `_G.PREVIEW_HUD_ORBS_ANIM = (loveArgs[3] == "anim")`)

> `orbs anim`: mesma fileira com o relogio do loop idle adiantado --
> prova que as gemas estao VIVAS e fora de fase entre si.

## L942-943 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "smoke_tags" then`)

> Modo smoke test: roda verificacao do TagSystem e sai com exit code.
> love . smoke_tags

## L950-951 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "smoke_effects" then`)

> Modo smoke test da Fase 2 (efeitos): strength/orbs/poison/etc.
> love . smoke_effects

## L974-975 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "test_systems" then`)

> Modo teste da entrega STS-improvements v1 (Rng/pity/afinidade/forja/eventos).
> love . test_systems

## L998-999 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "smoke_upgrades" then`)

> Smoke test: upgrade pipeline + editions + seals (Fase 3 do refactor Balatro).
> love . smoke_upgrades

## L1006-1007 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "smoke_shop" then`)

> Smoke test: ShopSystem modes + booster packs + reroll (Fase 4 do refactor Balatro).
> love . smoke_shop

## L1014-1015 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "smoke_packs" then`)

> Smoke test: BoosterPackSystem + persistência por cópia (Fase 5).
> love . smoke_packs

## L1022-1023 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_packopen" then`)

> Screenshot tool: pack opening cinemático (Fase 7). Phase 0..4.
> love . screenshot_packopen 4

## L1029-1030 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_shop" then`)

> Screenshot tool: shop em modo "shop" (Fase 8 do refactor Balatro).
> love . screenshot_shop 1

## L1036-1037 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_collection" then`)

> Screenshot da coleção (grid + modal inspect da carta alvo).
> love . screenshot_collection [card_id]

## L1043-1044 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_unlocks" then`)

> Meta-progressão: reveal pós-run + Coleção com cartas "?".
> love . screenshot_unlocks

## L1050-1051 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_round_eval" then`)

> Screenshot tool: round eval / cash out (Fase 9). Phase 0..3.
> love . screenshot_round_eval 3

## L1058-1059 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "test_saveflow" then`)

> Testa o fluxo de save/abandono/run nova (bug "run antiga ressuscita"):
> love . test_saveflow

## L1066-1067 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_turnbanner" then`)

> Valida o TurnBanner v2 (placa grimório, player + enemy):
> love . screenshot_turnbanner

## L1073-1074 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_combobanner" then`)

> Valida o ComboBanner (1 combo, 3 combos, reduced motion, + TurnBanner):
> love . screenshot_combobanner

## L1087-1088 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_menuanim" then`)

> Valida a animação de vela do menu (grid do ciclo de crossfade):
> love . screenshot_menuanim

## L1094-1095 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_ui" then`)

> Telas de UI sem harness próprio (levantamento redesign UI/UX):
> love . screenshot_ui menu|class|settings|rest|event|collection|all

## L1119-1120 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "autoplay" then`)

> Piloto de IA: joga runs completas sozinho e escreve diario+metricas.
> love . autoplay [runs] [warrior|mage|rogue|all] [seedBase]

## L1126-1127 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "balance_sim" then`)

> Bateria de balanceamento (piloto v6, relatorio agregado).
> love . balance_sim [runsPorClasse] [classes] [seedBase] [v6|v5]

## L1132-1133 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "leak_probe" then`)

> Sonda de vazamento: runs em sequencia + heap/texturas/censo por run.
> love . leak_probe [runs] [classe] [seedBase] [v6|v5]

## L1138-1139 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "balance_bench" then`)

> Banco de batalhas (A/B so do COMBATE do piloto, sem ruido de run).
> love . balance_bench [runsGravadas] [classes] [seed] [v5,v6]

## L1153 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "smoke_ui_turn" then`)

> Regressão do caminho do CLIQUE (botões de turno via UI).

## L1178-1183 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_journal" then`)

> Capturas do Roteiro da jornada (run mock com histórico de 2 atos).
> love . screenshot_journal              — janela padrão, pt_BR
> love . screenshot_journal small        — janela estreita (zonas comprimidas)
> love . screenshot_journal - de         — pt_BR trocado por outro idioma
> O 3º argumento existe pra validar TRADUÇÃO: é em idioma estrangeiro que
> o português cravado aparece.

## L1191-1194 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "screenshot_pause" then`)

> Capturas do menu de PAUSA + CONFIGURAÇÕES em 3 tamanhos (canvas com
> janela falsificada — sem setMode).
> love . screenshot_pause          — pt_BR
> love . screenshot_pause de       — outro idioma

## L1200 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "smoke_crt_mouse" then`)

> Regressão do mouse através do vidro (domo do CRT vs hit-test).

## L1207 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "smoke_turn_order" then`)

> Regressão da ordem do turno (escudo vs apex da investida).

## L1222-1223 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "test_all" then`)

> Suite COMPLETA (unit + smoke + validacao). Total geral + exit code.
> love . test_all

## L1238-1239 (em `love.load`, junto a `if loveArgs and loveArgs[1] == "smoke_all" then`)

> Roda TODOS os smoke tests em sequencia.
> love . smoke_all

## L1259-1260 (em `love.load`, junto a `I18n.init()`)

> I18n primeiro: carrega locale salvo (default pt_BR) antes de qualquer
> modulo que use I18n.t na inicializacao (Menu, CardRegistry, etc.)

## L1268-1269 (em `love.load`, junto a `local persistedSettings = SaveManager.loadSettings()`)

> Carrega settings persistidos (volumes, fullscreen, CRT, locale).
> Se nao existir, retorna defaults (DEFAULT_SETTINGS no SaveManager).

## L1272-1287 (em `love.load`, junto a `if not _G.HEADLESS_TOOL then`)

> JANELA: nascer grande, ANTES de inicializar UI (evita reflow).
>
> `conf.lua` não consegue decidir isso: ele roda antes do módulo window
> existir, então não tem como perguntar o tamanho do monitor. Os 1024x768
> de lá são um piso, e num monitor 2560x1440 abrem um selo postal no meio
> da tela. Aqui já dá pra medir.
>
> Duas garantias, porque uma só não cobre todo mundo:
> 1. quem nunca abriu o jogo entra em fullscreen (DEFAULT_SETTINGS);
> 2. quem PREFERE janela ganha uma proporcional ao monitor, não a fixa.
> Sem a 2, trocar o default não faria nada para quem já tem
> `fullscreen = false` salvo — que é a maioria de quem já jogou.
>
> Fora em modo ferramenta: screenshot/preview definem a própria janela, e
> captura tem que ser reproduzível entre máquinas com monitores
> diferentes. Sem este guard, o default fullscreen vazaria pros tools.

## L1295-1297 (em `love.load`, junto a `local okDim, dw, dh = pcall(love.window.getDesktopDimensions, display)`)

> 85% do desktop e centralizada. Pedir a área TOTAL põe a barra
> de título atrás da barra de tarefas (Windows) ou do menu bar
> (macOS); pedir mais que a área útil trava o `setMode`.

## L1326-1328 (em `love.load`, junto a `_G.gameSettings = persistedSettings`)

> Settings runtime que outros sistemas leem (ScreenShake, Moveable.juice_up,
> Card ambient_tilt). Bind direto em persistedSettings: mudanças no
> SettingsMenu refletem aqui automaticamente sem proxy.

## L1330-1331 (em `love.load`, junto a `SettingsMenu.applyRuntime(persistedSettings)`)

> Settings sem módulo próprio (ritmo do combate → CombatBeats.speed,
> vsync) — fonte única em SettingsMenu.applyRuntime.

## L1334-1335 (em `love.load`, junto a `_G.EventManager = EventManager`)

> Fila de eventos temporais (engine/EventManager). Sistemas podem
> agendar sequências via _G.EventManager.addEvent{...} sem passar ctx.

## L1341-1357 (em `love.load`, junto a `audioSystem:loadSound("menuMusic", "audio/music.mp3", {`)

> Música do menu (loop, streaming). Tocada via Sfx.playMusic("menuMusic")
> após o splash terminar (ver components/Menu.lua:enterWithIntro).
> VOLUME CALIBRADO PELO NIVEL MEDIDO, nao por palpite (Set/2026).
>
> As 9 faixas de audio/music/ foram niveladas a -18 LUFS no
> pos-processamento (memory/music_generation.md). Esta aqui e a musica
> ORIGINAL do jogo e nunca passou por isso: medida, ela esta a
> **-16,3 LUFS** contra -19,2 do ato 3. Registrada no mesmo 0.6 das
> outras, saia ~2,9 dB MAIS ALTA que todo o resto.
>
> Isso nao e detalhe de mixagem: e o que fazia o dono dizer "ainda
> tocando a musica do menu depois que clico em continuar". O diretor
> troca na hora (o log dele prova), mas durante o crossfade a faixa
> mais alta domina — entao o menu continuava audivel por cima do
> drone grave e quieto do ato ate quase o fim do cruzamento.
>
> 0.6 * 10^(-2,9/20) = 0.43 poe as duas no mesmo nivel percebido.

## L1365-1371 (em `love.load`, junto a `require("src.systems.MusicDirector").registerTracks(audioSystem)`)

> Trilha por contexto: registro por SCAN a partir da tabela única
> em MusicDirector.TRACKS (ver src/systems/MusicDirector.lua).
> require INLINE de propósito: `love.load` já roda no teto de 60
> upvalues do Lua, e um `local` a mais no topo deste arquivo derruba
> o jogo no boot com "function at line 367 has more than 60
> upvalues". O resto do dispatcher usa a mesma forma. Não promova
> isto para um local no topo.

## L1403-1404 (em `love.load`, junto a `require("src.systems.WeatherAudio").registerSounds(audioSystem)`)

> clima do WorldRoad (camas, avulsos, trovões): registro por SCAN de
> audio/sfx/weather/ — ver src/systems/WeatherAudio.lua

## L1406-1407 (em `love.load`, junto a `require("src.systems.PlaceAudio").registerSounds(audioSystem)`)

> ambiente de cada LUGAR (loja/forja/descanso/evento/salão) — ver
> src/systems/PlaceAudio.lua

## L1417-1418 (em `love.load`, junto a `audioSystem:loadSound("coinClink",     "audio/sfx/coin-clink.mp3",       0.55)`)

> F11.4: SFX dedicados pra Round Eval / Pack Open / Shop (substituem
> usos repetidos de cardSelect/deckStart/purchaseConfirm).

## L1421 (em `love.load`, junto a `audioSystem:loadSound("cashOutChime",  "audio/sfx/cash-out-chime.mp3",   0.55)`)

> arquivo suavizado (passa-baixa 5 kHz, -10 dB), 13/Out/2026

## L1428-1429 (em `love.load`, junto a `audioSystem:loadSound("forkHoverFire",  "audio/sfx/fork-hover-fire.mp3",  0.40)`)

> v9.6: hover dos LUGARES do fork (WorldRoad) — som por lugar
> (v9.7: volumes reduzidos — feedback "estão muito altas")

## L1431 (em `love.load`, junto a `audioSystem:loadSound("forkHoverDoor",  "audio/sfx/fork-hover-door.mp3",  0.24)`)

> porta da loja mais baixa (dono, 13/Out/2026)

## L1436 (em `love.load`, junto a `audioSystem:loadSound("sceneRustle",     "audio/sfx/scene-rustle.mp3",      0.34)`)

> v9.7: CENÁRIO INTERATIVO (clique em árvore/poste/nuvem/grama etc)

## L1449-1455 (em `love.load`, junto a `for code, path in pairs({`)

> BIGORNA (Set/2026): sons-assinatura da forja. Registro por SCAN —
> os arquivos ainda NÃO existem no repo; quando forem soltos em
> audio/sfx/ eles passam a tocar sozinhos, sem tocar em código.
> O RestScreen escolhe via Sfx.has e cai em "restComplete" enquanto
> não houver arquivo (mesmo contrato dos sons de joker).
> forgeStrike → a martelada (início da sequência)
> forgeReveal → o aço voltando da brasa (materialize da carta nova)

## L1465-1468 (em `love.load`, junto a `if love.filesystem.getInfo("audio/sfx/card-explode.mp3") then`)

> Carta ESTOURANDO tem som proprio, com volume proprio: o 0.65 do
> bloco acima e alto demais pra um efeito que dispara no meio do
> combate. Enquanto o arquivo nao existir, Card:explode cai no
> enemyDeath (fallback via Sfx.has) e nada quebra.

## L1474-1497 (em `love.load`, junto a `for code, cfg in pairs({`)

> LOJA (Set/2026) — mesmo contrato de scan. Enquanto o arquivo não
> existe, o call site cai num som genérico via Sfx.has:
> cardShelfPlace  → cada carta pousando na prateleira (→ cardDraw)
> shopLeaveWhoosh → a loja deslizando pra fora  (→ menuClose)
> cardDeselect    → desmarcar coringa (→ alias abaixo)
>
> Volumes CALIBRADOS pelo pico medido de cada amostra
> (`love . sfx_envelope <nome>`), não por chute — dois arquivos com o
> mesmo volume registrado soam muito diferente se um tem pico 0,25 e
> o outro 1,00. Referência do projeto: cardDraw = 0,35 sobre pico
> 0,124, ou seja ~0,043 de amplitude efetiva.
> cardShelfPlace  pico 0,246 → 0,22 ≈ 0,054 efetivo. Um tico acima
> do cardDraw (é o único evento do momento), mas contido: toca
> em cascata, 6-7x seguidas, e som repetido cansa rápido.
> shopLeaveWhoosh pico 0,764 → 0,50 (evento único, gesto de saída).
> cardDeselect    pico 1,000 (amostra no talo) → 0,16, senão
> estoura sobre todo o resto da UI.
> eventEnterWind  → entrar num evento (→ menuOpen)
> eventChoiceSeal → confirmar a escolha do evento (→ buttonClick)
> Os dois picam perto de 1,000, então vão registrados BAIXO pelo
> mesmo motivo do cardDeselect. O vento ainda é ambiente sob a
> tela inteira (0,20 no pico, ~0,04 na cauda sustentada); o lacre
> é pontuação de UM momento por evento e pode ser um tico mais
> presente que um clique comum, mas segue bem abaixo do combate.

## L1504 (em `eventChoiceSeal`, junto a `shopBellHover     = { "audio/sfx/shop-bell-hover.mp3",     0.30 },`)

> Loja v5 (Out/2026): sino, copo, hover e compra por objeto

## L1526-1530 (em `shopCrystalShatter`, junto a `if not audioSystem.sources["cardDeselect"] then`)

> ALIASES pra códigos que call sites JÁ tocavam sem nunca terem sido
> registrados — eram no-op silencioso (proibido por
> memory/ui_layout_invariants §3). JokerManagerScreen:125/:134 toca
> "cardDeselect" e "error"; até existir arte sonora própria, ambos
> apontam pra um som existente com a semântica certa.

## L1536-1537 (em `shopCrystalShatter`, junto a `audioSystem:loadSound("bootTvPowerOn",  "audio/sfx/boot-tv-power-on.mp3", 0.70)`)

> Entrada do jogo (BootScene) — SFX próprios (ElevenLabs, Jul/2026):
> power-on da TV, whoosh da convergência das cartas, impacto do flash.

## L1544-1545 (em `shopCrystalShatter`, junto a `audioSystem:loadSound("impactFire",      "audio/sfx/impact-fire.mp3",      0.55)`)

> Game feel v1 (Jul/2026): identidade sonora por TEMA de carta
> (CardFeel.THEMES resolve tag → som) + procs de joker + inimigo.

## L1554-1555 (em `shopCrystalShatter`, junto a `audioSystem:loadSound("healShimmerSoft", "audio/sfx/heal-shimmer.mp3",     0.30)`)

> Alias mais baixo pro lifesteal (proc por ataque — não pode gritar).
> NÃO usar opts.volume no play: AudioManager:play MUTA o baseVolume.

## L1561-1562 (em `shopCrystalShatter`, junto a `audioSystem:loadSound("effectCast",    "audio/sfx/effect-cast.mp3",    0.45)`)

> Game feel v2: carta de EFEITO tem 3 camadas (cast no voo → chime
> no impacto → resolve fechando) — identidade própria de "conjuração".

## L1567-1570 (em `shopCrystalShatter`, junto a `for _, f in ipairs(love.filesystem.getDirectoryItems("audio/sfx/joker-sig")) do`)

> Game feel v2: assinatura sonora POR JOKER (são lendários — cada um
> soa como ele mesmo no proc). SCAN do diretório: joker novo = só
> dropar audio/sfx/joker-sig/<id>.mp3; registra como jokerSig_<id>.
> JokerProcFx faz fallback pro jokerTick quando não há assinatura.

## L1603-1604 (em `shopCrystalShatter`, junto a `require("engine.SaveManager").quarantineRun()`)

> Save ilegível sai do caminho (vira .corrupt) e o jogador SABE:
> antes o Continuar ficava no menu e cada clique falhava calado.

## L1607 (em `shopCrystalShatter`, junto a `local T = require("src.i18n.I18n").t`)

> inline: teto de upvalues

## L1618-1633 (em `shopCrystalShatter`, junto a `require("src.systems.ResumeFlow").apply(game,`)

> O MUNDO retoma no exato lugar do save: bioma do ato, câmera na
> distância caminhada (andar N = N-1 viagens), proximidade do
> castelo e entardecer reconstruídos (pedido do dono, Jul/2026).
> A cena também ancora o ANDAR aqui — retomando NA encruzilhada o
> mundo fica um andar atrás, senão a caminhada até o nó escolhido
> nunca dispara (ver GameplayScene.resumeWorld).
> E a CENA volta com o mundo: retomar dentro da luta do chefe é
> retomar DENTRO do salão. O nó salvo já diz "boss" (por isso o
> inimigo vem certo), mas `bossEntered` do GameplayScene é estado
> de módulo que nasce false e só vira true pela cerimônia da porta
> — cerimônia que o Continuar nunca dispara. Sem isto o chefe
> aparecia plantado no meio da ESTRADA (bug do dono, Set/2026).
> Elite/mini-boss ficam de fora de propósito: eles lutam na estrada
> (memory/enemy_pose_and_scene_anchor.md).
> (require inline: love.load já está no teto de 60 upvalues do
> LuaJIT — mesmo motivo do _G.openCardPicker / __showMapSelection)

## L1638-1643 (em `shopCrystalShatter`, junto a `if not _G.__resumeRunStage() and game.runManager:getPendingNodes() then`)

> Save feito NA ENCRUZILHADA (nós pendentes, nada escolhido):
> retoma ESCOLHENDO o caminho, não numa batalha — sem isto o
> resumeRun soltava um inimigo "do nada" (bug do dono, Jul/2026).
> showMapSelection reusa os pendentes salvos (guard anti-advance);
> o inimigo provisório do resumeRun é substituído pelo nextPhase
> do nó que o jogador escolher. (via hook _G — limite de upvalues)

## L1665-1666 (em `shopCrystalShatter`, junto a `menu:setCreditsCallback(function()`)

> Créditos (link no rodapé do menu): estado próprio, mesmo padrão das
> conquistas. A tela mora em _G pra não somar upvalue ao love.load.

## L1688-1689 (em `shopCrystalShatter`, junto a `game = Game:new()`)

> Inicializa o jogo primeiro (donos dos sistemas singleton: ShopSystem,
> EconomySystem, etc). Telas que dependem deles são criadas depois.

## L1714-1716 (em `_G.toggleJokerManager`, junto a `_G.runJournalScreen = require("components.RunJournalScreen"):new()`)

> ROTEIRO da run: clique no indicador de ATO da TopBar OU tecla M.
> Mora em _G pelo mesmo motivo do jokerManagerScreen: love.load já está
> no teto de 60 upvalues do LuaJIT.

## L1721-1722 (em `_G.toggleRunJournal`, junto a `_G.guideScreen = require("components.GuideScreen"):new()`)

> GUIA (combos + glossário): atalho da pausa OU tecla G. _G pelo teto de
> upvalues do love.load.

## L1728-1729 (em `_G.toggleGuide`, junto a `_G.scribeDiceScreen = require("components.ScribeDiceScreen"):new()`)

> DADOS DO ESCRIBA (aposta opcional da loja). _G pelo teto de upvalues;
> quem abre (CardRewardScreen) passa o game e o callback de fechamento.

## L1735-1736 (em `_G.openScribeDice`, junto a `_G.endlessCurseScreen = require("components.EndlessCurseScreen"):new()`)

> MALDIÇÃO do endless (escolha 1-de-2 a cada ciclo). Abre sozinha quando
> o mapa aparece com escolha pendente (EndlessCurseScreen.watch).

## L1738 (em `_G.openScribeDice`, junto a `_G.unlockShowcase = require("components.UnlockShowcase"):new()`)

> Revelações do menu (Balatro): o que a run liberou, um painel por vez.

## L1741-1742 (em `_G.openScribeDice`, junto a `pauseMenu = require("components.PauseMenu"):new()`)

> Menu de PAUSA (engrenagem da TopBar, padrão StS): Continuar /
> Configurações / Salvar e voltar ao menu / Abandonar run (confirmado).

## L1744-1745 (em `_G.openScribeDice`, junto a `_G.togglePauseMenu = function(opts)`)

> opts.quiet: reabertura vinda das Configurações (VOLTAR devolve pra
> pausa, padrão back_func='options' do Balatro) — sem som duplicado.

## L1751-1752 (em `_G.togglePauseMenu`, junto a `if require("src.ui.EndTransition").pending() then return end`)

> TV já desligando pra tela de morte/vitória: a run acabou. Abrir a
> pausa aqui deixava "Salvar e sair" regravar uma run morta.

## L1772-1780 (em `onSaveQuit`, junto a `local run = game.runManager and game.runManager.currentRun`)

> Run ativa fica GUARDADA. checkpointRun (não saveRun cru!):
> SINCRONIZA HP/vida máxima/mana base/ouro ATUAIS antes de
> persistir — o saveRun direto gravava o playerState do
> checkpoint ANTERIOR e ganhos recentes (evento +5 vida
> máxima, +1 mana) evaporavam no Continuar (bug Set/2026).
> No MEIO de uma luta o save do INÍCIO dela (Game:nextPhase)
> é o que vale: salvar agora gravava a vida já perdida com o
> inimigo voltando cheio — e, morto atrás do menu, gravava 0.
> Retomar = refazer a luta do começo (como no StS).

## L1791-1792 (em `onAbandon`, junto a `game:abandonRun()`)

> Abandono confirmado: encerra a run (XP de maestria + derrota
> no perfil) e apaga o save.

## L1801-1804 (em `onAbandon`, junto a `_G.topBar = topBar`)

> Exposta como global no mesmo espírito de _G.audioSystem/_G.EventManager:
> telas que precisam VOAR algo até o cofre (moedas do cash out) têm que
> perguntar à barra onde ele está, em vez de repetir a coordenada e
> dessincronizar na próxima mudança de layout.

## L1807-1809 (em `onAbandon`, junto a `topBar:setDeckClickCallback(function()`)

> F5 do UI Overhaul: clique no deck da TopBar abre o Deck Viewer.
> (Este wire vivia ANTES do TopBar:new() — topBar era nil e o callback
> nunca era registrado; clique no deck da barra não fazia nada.)

## L1826-1827 (em `onAbandon`, junto a `packOpenScreen = PackOpenScreen:new()`)

> Pack opening cinemático (Fase 5 do refactor Balatro). Overlay sobre
> cardReward state — não é state próprio.

## L1830-1831 (em `onAbandon`, junto a `roundEvalScreen = RoundEvalScreen:new()`)

> Round Eval / Cash Out screen (Fase 9 do refactor Balatro). State próprio
> "roundEval" entre playing → cardReward em modo run.

## L1834-1847 (em `onAbandon`, junto a `do`)

> ===================================================================
> FOCO DE ENTRADA: quem, ao ficar visível, toma o mouse de quem está
> atrás. ESTA é a lista — overlay que não está aqui não bloqueia nada,
> e overlay que está aqui bloqueia por construção (src/ui/InputFocus).
>
> A ORDEM é a prioridade (último = mais por cima). Primeiro as
> COBERTURAS (keepChrome: tapam a cena, mas a TopBar segue viva e
> clicável — clicar no ouro/deck/engrenagem na loja/descanso é
> comportamento desejado), depois os MODAIS (engolem tudo, TopBar
> inclusive, e capturam os eventos).
>
> AO CRIAR UMA TELA NOVA: registre aqui, no mesmo commit. É a única
> linha necessária — o bloqueio do hover de trás vem de graça.
> ===================================================================

## L1851-1854 (em `onAbandon`, junto a `IF.register("bossCinematic", require("src.ui.BossCinematic").overlay)`)

> Cinemática do chefe (entrada/morte): captura clique/tecla/A pra
> PULAR e tira o Enter do NavCursor, mas fica EMBAIXO de tudo —
> pausa, deck, coringas continuam ganhando dela. O combate NÃO
> congela com ela no topo (exceção no love.update).

## L1871-1872 (em `onAbandon`, junto a `IF.register("guide",        _G.guideScreen)`)

> Guia (combos/glossário) e, por cima de TUDO, a placa de dica do
> tutorial: enquanto ela está na tela, o clique/tecla/A é dela.

## L1883-1886 (em `onAbandon`, junto a `_G.openBoosterPack = function(pack, onComplete)`)

> API global pra ser chamada pela CardRewardScreen quando jogador compra
> um booster pack. Padrão Balatro (UI_definitions.lua:1629+): a loja
> desliza pra fora da tela enquanto o pack toma o foco. Quando o pack
> fecha, a loja volta — sem backdrop preto sobreposto.

## L1890-1892 (em `_G.openBoosterPack`, junto a `if cardRewardScreen and cardRewardScreen.slideOut and cardRewardScreen.mode ~= "shop" then`)

> 1) Loja sai de cena (recompensa). Na LOJA ela FICA, escurecida
> pelo PackOpenScreen: deslizar pra fora mostrava a estrada do bioma
> atras do pacote (dono, Out/2026: "teleportou pro mundo de fora").

## L1909-1910 (em `_G.openBoosterPack`, junto a `game.onToggleSettings = function() settingsMenu:toggle() end`)

> Wire: ícone de config na TopBar -> toggle do settingsMenu.
> TopBar chama game:toggleMenu() que chama game.onToggleSettings.

## L1913-1914 (em `game.onToggleSettings`, junto a `CRTShader.load()`)

> Pós-processamento CRT (scanlines, wave, aberração cromática). Balatro-style.
> Settings → "CRT Shader" liga/desliga via CRTShader.toggle().

## L1916-1917 (em `game.onToggleSettings`, junto a `require("src.ui.CursorManager").load()`)

> Cursor pixel-art próprio (esconde o do SO; desenha no fim do draw,
> dentro da cena CRT — sofre o warp do tubo junto com o mundo)

## L1920-1921 (em `game.onToggleSettings`, junto a `CRTShader.setLevel(CRTShader.levelFromSettings(persistedSettings))`)

> Níveis do CRT (Out/2026): Desligado / Baixo / Normal — `crtLevel`
> novo; save antigo só tinha o booleano (false → off).

## L1923-1924 (em `game.onToggleSettings`, junto a `CRTShader.setPower(0)`)

> Identidade CRT: o jogo ABRE como uma TV ligando — ponto → linha
> quente → a imagem abre revelando o splash (docs/plan/crt-identity-v1).

## L1928-1935 (em `game.onToggleSettings`, junto a `require("src.ui.InputFocus").installMouseGate(CRTShader.screenToContent)`)

> MOUSE ATRAVÉS DO VIDRO + PORTÃO DE FOCO. Duas verdades, o MESMO ponto
> único: todo mundo que lê love.mouse.getPosition/getX/getY enxerga
> (a) coordenadas de CONTEÚDO, na mesma lente do CRT (o domo desloca a
> imagem perto das bordas — sem isto, clique/hover perto do topo/
> base acertam ACIMA de onde o botão aparece; bug da Coleção);
> (b) o mouse FORA DA TELA quando quem está desenhando não é o dono do
> foco (overlay modal aberto) — é o que faz o hover de trás morrer
> sozinho. Ver src/ui/InputFocus.lua.

## L1942-1944 (em `_G.getCurrentState`, junto a `DissolveShader.load()`)

> FX pipeline (shaders próprios, copyright-safe — Fase 2 do refactor Balatro).
> Dissolve: exhaust/destroy. Flash: impactos. Booster: pacotes selados.
> Foil/Polychrome: editions de carta (Fase 3). A Negative saiu (Out/2026).

## L1950-1955 (em `_G.getCurrentState`, junto a `if not require("src.ui.HoloShader").load() then`)

> Holo das cartas RARAS/LENDÁRIAS (CLAUDE.md §14, v2: aro/realces, 0→0.25 rara, 0.08→0.5 lendária no hover) e
> da edition "holo". O módulo nasceu em Abr/2026 (a182eae) documentado
> como ativo e NUNCA teve o load() chamado: isAvailable() ficava false,
> Card:draw caía no draw cru e a edition holo era descartada em silêncio.
> Trava: test_holo_shader. (require inline: main.lua está no teto de
> upvalues do love.load — ver §9.)

## L1960 (em `_G.getCurrentState`, junto a `ScreenShake.install()`)

> Screen shake como sistema → registra _G.triggerShake pra back-compat.

## L1998 (em `_G.getCurrentState`, junto a `SmokeConfig.applyToSystem(smokeSystem, "default")`)

> Aplica configuração padrão (sutil)

## L2004-2005 (em `_G.getCurrentState`, junto a `GameplayScene.init({`)

> Inicializa GameplayScene com deps. Callbacks mutam currentState aqui
> (state machine fica em main.lua; scene só sinaliza).

## L2014-2016 (em `setCurrentState`, junto a `if name == "gameOver" or name == "victory" then`)

> Identidade CRT: morte/vitória = a TV DESLIGA (colapso em
> linha quente) e RELIGA já na tela final. Com CRT off nas
> Settings, powerOff/On viram corte seco (acessibilidade).

## L2018-2030 (em `setCurrentState`, junto a `require("src.ui.EndTransition").start(name,`)

> TRAVA DE REENTRADA — sem ela o jogo TRAVA NA TELA PRETA.
> O gatilho é uma CONDIÇÃO, não um evento: o
> GameplayScene.update chama isto toda vez que
> `game:checkGameOver()` é verdadeiro, e morte não deixa de
> ser verdadeira. Cada chamada substituía o `powerAnim` em
> curso e zerava o cronômetro dele, então o callback que
> troca o estado NUNCA chegava ao fim: a TV ficava desligada
> para sempre, sem tela, sem input, só fechando o jogo
> (relatado pelo dono, Set/2026).
> v3.6: colapso + ponto de fósforo apagando pedem fôlego.
> A trava de reentrada mora em src/ui/EndTransition.lua —
> sem ela o jogo TRAVA NA TELA PRETA (o gatilho é condição,
> não evento, e reiniciava o desligamento todo frame).

## L2044-2045 (em `onPhaseCleared`, junto a `showRoundEval()`)

> Run mode: passa por Round Eval (cash out) primeiro;
> ao Resgatar, cai em showCardRewards.

## L2054-2055 (em `onReturnToMenu`, junto a `BootScene.init({`)

> Inicia BootScene (splash/loading). Quando termina, troca pra menu e
> dispara intro animado + música.

## L2057-2060 (em `onReturnToMenu`, junto a `onIntroStart = function()`)

> ABERTURA (Out/2026): a página com o televisor pequeno é desenhada
> SEM o CRT de tela cheia (o tubo pequeno usa o mesmo shader por
> CRTShader.renderTube); no mergulho o CRT volta e liga com o
> warm-up v3.6 (ponto → linha → abre → rolo de sync → assenta).

## L2067-2072 (em `onTubeOn`, junto a `CRTShader.setPower(0)`)

> A TV LIGANDO fica (dono, 13/Out: "perdeu o efeito da tela
> ligando, eu quero ele"): o mergulho termina com a tela da arte
> exatamente na abertura do gabinete do CRT e o VIDRO escuro;
> power 0 só apaga o vidro (a TV continua ali), então a borda
> continua e o warm-up v3.6 (ponto → linha → abre → assenta)
> acontece dentro dela.

## L2089-2090 (em `onComplete`, junto a `if loveArgs and loveArgs[1] == "nav_flow" then`)

> Fluxo de run inteiro SÓ por teclado/pad (o jogo de verdade, depois do
> love.load): `love . nav_flow` — sai com 0/1 (tools/test_nav_flow.lua).

## L2095-2100 (em `onComplete`, junto a `if loveArgs and loveArgs[1] == "boss_rooms" then`)

> Galeria interativa das salas de chefe (1-6 / setas troca o ato; I =
> entrada, K = morte, com SOM e trilha). Despachada AQUI, depois do
> registro dos sons e da trilha — no topo do love.load (onde morava) o
> audioSystem ainda não existia e a cinemática rodava muda (dono,
> 13/Out: "como vejo cada entrada e morte de chefe com som?").
> love . boss_rooms [ato]

## L2113 (em `love.update`, junto a `require("src.ui.UiScale").reset()`)

> Escala de UI: higiene do frame (a batalha também escala desde Out/2026).

## L2119-2121 (em `love.update`, junto a `CardFrame.update()`)

> Cartas com ícone animado (icons_anim/): blita o frame corrente no
> canvas vivo de cada carta animada. Roda em TODOS os estados — mão,
> loja, coleção, deck viewer e menu animam pela mesma referência.

## L2127-2128 (em `love.update`, junto a `local IF = require("src.ui.InputFocus")`)

> FOCO DE ENTRADA: zera a pilha de camadas do frame (higiene — um erro
> no meio de um draw anterior não pode deixar o portão do mouse torto).

## L2132-2136 (em `love.update`, junto a `IF.push(IF.CHROME)`)

> TopBar precisa tickar em TODOS os estados onde é desenhada (loja,
> roundEval, rest, event, mapa) — o contador eased de ouro congelava
> fora do combate ("comprei e o ouro não mudou", playtest Jul/2026).
> Camada CHROME: modal apaga o hover da barra; cobertura (loja/descanso/
> mapa) deixa ela viva.

## L2142-2149 (em `love.update`, junto a `local combatFrozen = IF.freezesCombat(currentState)`)

> PAUSA DE VERDADE: com um modal aberto (pausa, configurações, deck,
> coringas, roteiro) NO COMBATE, o combate congela. Antes o turno do
> inimigo seguia rodando atrás do menu — dava pra morrer com a pausa
> aberta (e "Salvar e sair" gravava o morto). O relógio do combate é o
> EventManager (beats, eases, compra) + o GameplayScene.update.
> Exceção: a CINEMÁTICA do chefe é captora (pular/pausar vêm pra ela),
> mas o relógio da cena tem que correr — é ela quem anima a entrada e
> a morte (src/ui/BossCinematic). Pausa por cima dela congela normal.

## L2152-2155 (em `love.update`, junto a `if not combatFrozen then`)

> Infra global (antes do dispatch de estado): event queue, particles,
> flash fade, screen shake decay.
> Callbacks do EventManager são lógica de jogo/UI (beats, floating text,
> compra, FX de carta): rodam no espaço da UI, o mesmo da cena adotada.

## L2166-2168 (em `love.update`, junto a `do`)

> Trilha por contexto: o diretor observa o estado e troca de faixa com
> crossfade. Idempotente — chamar todo frame é o desenho, não descuido
> (ver src/systems/MusicDirector.lua).

## L2173-2174 (em `love.update`, junto a `local nt = node and node.type`)

> Ambiente por LUGAR, mesmo padrão observador: fecha o clima da
> estrada fora dela e toca a cama do lugar (src/systems/PlaceAudio.lua)

## L2187-2190 (em `love.update`, junto a `IF.push(IF.SCENE)`)

> Dispatch por estado, na camada SCENE: é tudo que fica ATRÁS de um
> overlay. Continua rodando (o mundo não congela), mas com um overlay
> visível o portão do InputFocus faz o mouse ler fora da tela aqui
> dentro — hover de carta/botão/HUD morre sozinho.

## L2200-2201 (em `love.update`, junto a `require("src.ui.WorldRoad").prewarmTick(nil, 1)`)

> Aquece o bioma 1 enquanto o jogador escolhe: a run nasce com o
> mundo pronto (sem engasgo no primeiro frame).

## L2204-2205 (em `love.update`, junto a `if game and game.isRunMode then`)

> v9.7.1: o mundo continua VIVO atrás das ofertas (anims dos
> lugares, vento, nuvens — e o juice dos cliques no cenário)

## L2211-2212 (em `love.update`, junto a `IF.push("packOpen")`)

> O pacote é MODAL sobre a loja: atualiza na camada dele (só ele
> enxerga o mouse), e a loja atrás para de acender.

## L2246-2247 (em `love.update`, junto a `if settingsMenu then`)

> Overlays modais: cada um na SUA camada — o topo visível é o único que
> enxerga o mouse de verdade.

## L2261-2262 (em `love.draw`, junto a `CRTShader.beginScene()`)

> Abre a cena CRT: tudo que for desenhado até endScene() vai pro canvas
> de pós-processamento e depois é redesenhado com o shader aplicado.

## L2268-2270 (em `love.draw`, junto a `local IF = require("src.ui.InputFocus")`)

> FOCO DE ENTRADA. Boa parte do hover deste jogo é decidida no DRAW
> (grids das telas cheias, quadro de coringas, botão X...), então a
> camada precisa valer aqui também, não só no update.

## L2284-2287 (em `love.draw`, junto a `GameplayScene.drawWorldOnly()`)

> Reforma Jul/2026 (feedback: "limpar mão/jokers/botões do fundo"):
> a batalha ACABOU — atrás dos espólios fica só o MUNDO limpo (estrada
> viva), sem UI de combate. drawWorldOnly é o mesmo caminho do
> mapSelection.

## L2324-2327 (em `love.draw`, junto a `if topBar and (currentState == "playing"`)

> HUD top bar SEMPRE visível em estados gameplay-adjacentes (Balatro pattern:
> moeda + deck count visíveis em loja, mapa, rest, event, roundEval).
> Desenhado APÓS overlays pra não ser dimmed pelos backdrops dessas telas.
> topBar:draw() já checa self.game e self.visible internamente.

## L2342-2344 (em `love.draw`, junto a `require("src.ui.StatusTooltip").draw()`)

> Tooltips agendados durante topBar:draw() desenham AQUI, por cima da
> barra e no MESMO frame. StatusTooltip.draw() consome o agendamento —
> se o GameplayScene já desenhou o tooltip deste frame, isto é no-op.

## L2347-2351 (em `love.draw`, junto a `local fxScaled = currentState ~= "boot"`)

> Partículas atachadas a cartas (dissolve/materialize/explode).
> Desenhadas APÓS as cartas mas DENTRO do shake + CRT scene, assim
> seguem o warp do pós-processamento.
> Elas nascem nas coordenadas VIRTUAIS da UI (batalha inclusive: o centro
> do inimigo sai do EnemyRenderer já ÷ k) — desenham no mesmo espaço.

## L2356-2357 (em `love.draw`, junto a `require("src.ui.CoinBurst").draw()`)

> Floating text (números de dano/cura/ouro). Acima das partículas, mas
> dentro do shake pra acompanhar o jiggle.

## L2374-2375 (em `love.draw`, junto a `if _G.scribeDiceScreen and _G.scribeDiceScreen:isVisible() then`)

> Dados do Escriba: modal sobre a loja (update na camada dele, aqui
> mesmo — o layout é por frame e o mouse só existe pra quem tem foco).

## L2405-2406 (em `love.draw`, junto a `if pauseMenu then IF.push("pause"); pauseMenu:draw(); IF.pop() end`)

> Overlay de settings (modal) ainda DENTRO da cena CRT — assim o shader
> cobre o overlay também.

## L2430-2433 (em `love.draw`, junto a `require("src.ui.NavCursor").draw()`)

> Cursor pixel-art por cima de TUDO, mas dentro da cena CRT (warp do
> tubo pega o cursor também — coerência Balatro). SEM camada: o cursor
> segue o mouse de verdade em qualquer situação.
> Anel de foco + glifos (teclado/pad), em pixels da tela.

## L2440-2442 (em `love.draw`)

> drawGame / drawJokersAsCards / updateCardPositions / updateGame /
> handleGameMouse* foram extraídas pra src/scenes/GameplayScene.lua.
> main.lua agora despacha diretamente via GameplayScene.*.

## L2444-2446 (em `love.draw`, junto a `function love.resize(w, h)`)

> Reposiciona UI e invalida caches quando a janela muda (fullscreen, drag de borda).
> LÖVE dispara isso sempre que window size muda; se esquecermos, buttons/layout
> ficam congelados nas dimensões do boot.

## L2449-2457 (em `love.resize`, junto a `CardFrame.clearCache()`)

> CardFrame JUNTO com FontManager, e ANTES de qualquer tela recalcular:
> love.window.setMode invalida o contexto grafico e o CONTEUDO de todo
> Canvas morre (o objeto sobrevive). As cartas guardam esse canvas em
> `card.image`, entao sem esta linha a ilustracao some ao dar fullscreen --
> ficam so moldura e selo. Pior: `cardRewardScreen:createCardInstances()`
> logo abaixo chama CardFrame.render e, sem o clear ANTES, reconstroi a
> loja inteira lendo o cache MORTO -- ela renasce em branco mesmo
> recriando tudo. Atinge toda tela com carta: loja, mao, DeckViewer,
> Colecao, Gerenciador de Coringas, abertura de pacote. (Set/2026)

## L2462-2465 (em `love.resize`, junto a `if menu and menu.updatePositions then menu:updatePositions() end`)

> Cada overlay/menu tem chance de recalcular layout. Padrão obrigatório:
> TODA tela com positions cacheadas (cardPositions, button rects, panel
> bounds) DEVE expor resize() ou updateLayout() e tratar o caso "ainda
> não visível" silenciosamente. Doc: memory/resize_pattern.md.

## L2472-2473 (em `love.resize`, junto a `if #(cardRewardScreen.shopOffers or {}) > 0 then`)

> Rebuild buttons pra refletir as novas cardPositions imediatamente
> (sem precisar esperar o detector de resize no update()).

## L2486-2488 (em `love.resize`, junto a `if deckViewerScreen and deckViewerScreen.resize then deckViewerScreen:resize() end`)

> Overlays de tela cheia: DeckViewer e Gerenciador de Coringas definiam
> resize() desde sempre e NUNCA eram chamados aqui (o scroll ficava preso
> na altura antiga). Corrigido junto com a entrada do Roteiro.

## L2512-2516 (em `love.keypressed`, junto a `do`)

> NAVEGAÇÃO POR TECLADO (src/ui/NavCursor): setas/Enter/Espaço movem e
> escolhem o FOCO em qualquer tela; Q/E/Z/C/I são as ações de contexto
> que a tela publicou. Telas com navegação própria (pausa, config,
> confirmação, dados, fim de jogo, conquistas, zoom da coleção) seguem
> recebendo as teclas como antes.

## L2526-2529 (em `love.keypressed`, junto a `do`)

> MODAL ABERTO ENGOLE O TECLADO. Uma chamada no lugar de seis cadeias
> escritas à mão: o topo do registro (src/ui/InputFocus) é quem recebe,
> e nada vaza pro atalho de trás. Overlay novo entra aqui de graça —
> basta estar registrado no love.load.

## L2540-2542 (em `love.keypressed`, junto a `local runScreen = currentState == "playing" or currentState == "cardReward"`)

> F5: tecla D abre o deck da run em qualquer tela dela
> Telas da run onde D/J/M funcionam: TODAS (antes descanso, evento e
> cash out ficavam de fora — o atalho "não funcionava às vezes").

## L2569-2570 (em `love.keypressed`, junto a `if key == "v" and currentState == "playing" then`)

> Tecla V na batalha: prévia de dano resumo ↔ detalhes (lembrado em
> Configurações → Jogo). O clique na placa faz o mesmo (love.mousepressed).

## L2591-2592 (em `love.keypressed`, junto a `local wasInspecting = collectionScreen.inspectedCard ~= nil`)

> Esc com o ZOOM aberto só fecha o zoom (antes também saía da
> coleção — Esc/B "pulava" uma tela; achado no fluxo por pad)

## L2614-2615 (em `love.keypressed`, junto a `if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end`)

> ESC em estado de run: abre o MENU DE PAUSA (sair/salvar/abandonar
> são decisões dele — ESC direto pro menu descartava sem perguntar).

## L2624-2625 (em `love.keypressed`, junto a `if currentState == "cardReward" or currentState == "roundEval" then`)

> ESC na loja/recompensa/cash out: pausa (antes não fazia nada — a
> engrenagem era o único caminho). Teclas próprias da tela vêm antes.

## L2670-2671 (em `love.keypressed`, junto a `EndScreens.keypressed(key)`)

> Telas finais: navegação MenuKit (setas/Enter/ESC) + R = de novo.
> As ações são os callbacks de EndScreens.setCallbacks.

## L2676-2682 (em `love.keypressed`, junto a `function love.gamepadpressed(joystick, button)`)

> GAMEPAD (Out/2026): por ora só os MODAIS de sistema e o START da pausa.
> O botão vira TECLA e segue o caminho do teclado (src/ui/MenuKit é o mapa
> único de intenções). Fora de modal, só START/BACK fazem algo — e só em
> estado de run (no menu principal, ESC fecha o jogo; START não pode).
> v2 (Out/2026, Steam Deck): TODAS as telas. D-pad/A/X/Y/ombros vão pro
> cursor de foco (src/ui/NavCursor) onde a tela não navega sozinha; nas que
> navegam (MenuKit), o botão vira TECLA como antes. B = Esc (voltar/pausa).

## L2767-2768 (em `love.mousepressed`, junto a `do`)

> Modal aberto recebe o clique e NADA passa — nem pra TopBar (ver
> love.keypressed). Ordem de prioridade = ordem do registro no love.load.

## L2776-2777 (em `love.mousepressed`, junto a `if require("src.systems.Tutorial").blocksPointer(x, y, "pressed") then return end`)

> Tutorial pedindo uma AÇÃO ("selecione uma carta"): só passa o clique
> que cai dentro do recorte iluminado (src/systems/Tutorial).

## L2780-2782 (em `love.mousepressed`, junto a `local topBarStates = {`)

> TopBar consome cliques na faixa superior (engrenagem/deck) em todos os
> estados onde é desenhada. (Nunca era roteada — o clique da engrenagem
> não funcionava em lugar NENHUM; bug playtest Jul/2026.)

## L2797-2799 (em `topBarStates`, junto a `if require("src.ui.DamagePreviewPanel").mousepressed(x, y, button) then return end`)

> Placa da prévia de dano: clique alterna resumo ↔ detalhes (ela
> fica na banda de ação, acima do JOGAR — antes da cena pra não
> virar poke no cenário nem drag de carta).

## L2801-2802 (em `topBarStates`, junto a `if not GameplayScene.mousepressed(x, y, button) and button == 1 then`)

> v9.7.1: clique que NENHUM elemento de gameplay consumiu cutuca
> o cenário (mapa vivo estilo Hearthstone — árvore/poste/nuvem)

## L2808 (em `topBarStates`, junto a `require("src.ui.WorldRoad").pokeSceneAt(x, y)`)

> v9.7.1: clique fora das ofertas cutuca o cenário atrás

## L2836-2838 (em `love.wheelmoved`, junto a `do`)

> Modal aberto fica com a roda. Quem não tem wheelmoved (pausa,
> configurações) ENGOLE — rolar sobre um modal não pode rolar a lista
> que está atrás dele.

## L2857-2858 (em `love.mousemoved`, junto a `do`)

> Modal aberto fica com o movimento (sem isto o arrasto de carta lá
> atrás continuava armando por baixo do menu).

