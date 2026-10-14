---
name: code_notes/src/systems/Tutorial.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/Tutorial.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/Tutorial.lua`

Origem: `src/systems/Tutorial.lua` em `7dbdb60d` (41 de 80 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-34 (junto a `local Tutorial = {}`)

> src/systems/Tutorial.lua
> ONBOARDING v2 (Out/2026): a 1ª corrida GUIADA pelo corvo narrador.
>
> v1 eram placas soltas ancoradas no objeto. O dono: "precisa ser bem mais
> claro, chamar atenção, a tela FOCAR no que é explicado — e aparecer em
> momentos que façam sentido (no chefe apareceu numa hora sem sentido)".
> v2 é um ROTEIRO: conversas curtas do Pena (src/ui/Narrator — corvo,
> máquina de escrever com blip, véu com recorte no objeto), disparadas pelo
> momento certo da 1ª corrida.
>
> Peças:
> ROTEIRO (SCRIPT)  ordem = prioridade. Cada conversa diz em que estado vale,
> quando dispara (`when`) e as FALAS; cada fala diz o que
> ilumina (`spot` = âncoras) e, se for o caso, a AÇÃO que o
> jogador faz pra seguir ("selecione uma carta").
> ÂNCORAS           quem desenha o objeto reporta o retângulo no draw
> (`Tutorial.anchor(id, x, y, w, h)` / `anchorList`),
> convertido pra pixels reais com transformPoint.
> ENTRADA           FALA: a conversa é o modal mais alto do InputFocus —
> clique/A/Enter/Espaço avança (1º completa o texto), Esc/B
> pula a conversa, X/Q (ou o link) desliga o tutorial; o
> combate congela por baixo. AÇÃO: a conversa larga o
> modal e o main.lua consulta `blocksPointer`/`blocksKey`:
> só passa o que cai DENTRO do recorte.
> ACONTECIMENTOS    quem desenha o objeto reporta o FATO (OrbRow: canalizou,
> pulsou, evocou, expulsou → Tutorial.noteEvent); gatilho
> de conversa preso ao fato, com a chave da batalha.
> MOMENTO           batalha só com a cena QUIETA (GameplayScene.isQuiet: sem
> viagem, sem cerimônia da porta, sem banner de turno, sem
> investida) na vez do jogador; telas só com a tela parada.
> Condição precisa se manter STABLE_FOR antes de disparar.
> Uma conversa por vez; respiro entre elas.
> PERSISTÊNCIA      ProfileStats.tipsSeen (por conversa); Configurações → Jogo
> liga/desliga (gameSettings.tipsEnabled) e recomeça.

## L40 (em `Tutorial`, junto a `local STABLE_FOR = 0.45`)

> condição precisa valer por este tempo (s)

## L41 (em `Tutorial`, junto a `local GAP_AFTER = 0.40`)

> respiro depois de fechar uma conversa (s)

## L58-60 (em `events`, junto a `local function store(id, x1, y1, x2, y2)`)

> ===================================================================
> Âncoras
> ===================================================================

## L117-119 (em `Tutorial.setScreens`, junto a `local function realDims()`)

> ===================================================================
> Estado do jogo (predicados)
> ===================================================================

## L141-142 (em `nodeType`, junto a `local function sceneQuiet()`)

> Cena quieta: sem viagem, porta, banner, investida (GameplayScene.isQuiet).
> Testes injetam `Tutorial._quiet` pra não depender da cena.

## L164-165 (em `battleIdle`, junto a `local function battleQuiet(game)`)

> Hora quieta pras dicas de CONTEXTO: igual à de cima, mas mão vazia vale
> (jogou a última carta — o Bloqueio dela ainda pede explicação).

## L227-234 (em `anyAnchor`, junto a `local function battleKey(g)`)

> ===================================================================
> Acontecimentos reportados por quem os DESENHA (OrbRow: canalizou, pulsou,
> evocou, expulsou). O gatilho de uma conversa de contexto fica preso ao fato,
> não a uma inferência sobre o estado — "o pulso aconteceu" é o OrbRow
> dizendo, não "há orbe e o turno mudou". Cada evento guarda a CHAVE da
> batalha em que caiu: a conversa só vale nessa batalha (acabou a luta antes
> da hora quieta? o gatilho cai e re-arma só no próximo acontecimento).
> ===================================================================

## L285-288 (em `handHasEvokeAll`, junto a `function Tutorial.orbVars(g)`)

> Variáveis VIVAS das falas do mago: nenhum número cravado no texto.
> {passive} nome da passiva · {slots} vagas da fileira · {pulse}/{evoke} do
> orbe mais antigo (fórmula canônica do EffectSystem) · {focus} Foco atual ·
> {f} Foco inicial do Conduíte neste ato.

## L310-317 (em `focusSpot`, junto a `local function played(g, base)`)

> ===================================================================
> Ações (falas que pedem que o jogador FAÇA algo)
> ===================================================================
> done(game, base) → bool, onde `base` é a foto tirada no COMEÇO da conversa
> ({ hand = nº de cartas }): se o jogador já fez a coisa antes da fala pedir
> (jogou a carta direto na fala de "selecione"), a fala de jogar passa
> sozinha em vez de esperar uma 2ª jogada. keys = teclas/intenções liberadas
> além da navegação; label = rótulo no rodapé do balão.

## L340-344 (em `keys`, junto a `Tutorial.SCRIPT = {`)

> ===================================================================
> Roteiro (ordem = prioridade)
> ===================================================================
> Fala: { id, spot = âncora|lista|função, action = nome em ACTIONS }.
> Texto: tutorial.script.<conversa>.<fala> (5 locales).

## L360-370 (em `lines`, junto a `{ id = "end_turn", state = "playing", after = "intro",`)

> ===== Dicas de CONTEXTO da luta: armam na 1ª ocorrência =====
> `latch` = o gatilho (a coisa ACONTECEU — sem exigir cena quieta);
> `ready` = a hora de falar (cena quieta + objeto desenhado). O gatilho
> fica ARMADO com a hora em que aconteceu e a conversa sai no 1º momento
> quieto seguinte, em ordem de gatilho — nunca "quando der" numa luta
> futura. `sameTurn`: o assunto é do turno (Bloqueio, combo na mão) e o
> gatilho cai se o turno passar sem hora de falar. Defeito que isto mata
> (playtest do dono, Out/2026): a dica do Bloqueio só chegava depois de o
> jogador já ter usado Bloqueio várias vezes — ela exigia "ENCERRAR já
> visto" E armadura > 0 numa hora quieta, e a armadura zera no turno
> seguinte; o ENCERRAR ganhava a vez e a janela fechava.

## L394-395 (em `lines`, junto a `{ id = "fog", state = "playing", after = "intro",`)

> NÉVOA DE INTENÇÃO (Out/2026): a 1ª vez que o número do intent some
> (nevasca do bioma ou véu da criatura — src/systems/IntentVisibility).

## L416-421 (em `lines`, junto a `{ id = "conduit", state = "playing", after = "intro",`)

> ===== MAGO: orbes do zero (Out/2026, pedido do dono: "explicar tudo
> do zero, é bem complexo"). Cada conversa nasce no instante em que o
> objeto aparece pela 1ª vez, ancorada nele; os números vêm do código
> (Tutorial.orbVars) e os gatilhos de acontecimento vêm do OrbRow
> (Tutorial.noteEvent: canalizou/pulsou/evocou/expulsou). =====
> Conduíte + a fileira: a 1ª luta do mago já abre com um orbe de Raio.

## L430-431 (em `lines`, junto a `{ id = "channel", state = "playing", after = "intro",`)

> Canalizar: a 1ª carta de orbe na mão (antes de jogar) OU o 1º orbe que
> uma carta criou (depois) — as duas falas se excluem pela cond.

## L447-448 (em `cond`, junto a `{ id = "pulse", state = "playing", after = "second_turn",`)

> O pulso: só DEPOIS de acontecer (beat do fim do turno, reportado pelo
> OrbRow) e na 1ª hora quieta seguinte — a vez do jogador no turno 2.

## L466-467 (em `lines`, junto a `{ id = "overflow", state = "playing", after = "intro",`)

> Fileira cheia: canalizou com as vagas cheias e o mais antigo foi expulso
> (EffectSystem._stepChannelOrb: o expulso EVOCA com o valor cheio).

## L475-476 (em `lines`, junto a `{ id = "focus", state = "playing", after = "intro",`)

> Foco: a 1ª vez que o jogador tem Foco (Conduíte a partir do ato 3, ou
> carta de Foco antes disso).

## L499-502 (em `lines`, junto a `{ id = "dice_help", state = "cardReward", onDemand = true,`)

> SOB DEMANDA (Out/2026, queixa do dono: "os dados estão confusos"):
> nunca dispara sozinha (`when` falso); quem abre é o "?" dos dados
> (botão da loja e o próprio modal) via Tutorial.explain, a qualquer
> momento, mesmo depois de vista ou com as dicas desligadas.

## L512-514 (em `lines`, junto a `{ id = "shop", state = "cardReward",`)

> Loja v5 (Out/2026): a conversa segue a vitrine nova: ofertas nos
> cavaletes/balcão, PREÇO em cada peça (plaquinha sob a carta, etiqueta
> pendurada na frente do balcão), clique = pergaminho + fita COMPRAR.

## L535-537 (em `lines`, junto a `{ id = "class_select", state = "classSelection",`)

> Seleção de classe, 1ª visita: o Guerreiro (única aberta), a fita de
> começar, as acorrentadas (requisito LIDO do UnlockSystem) e o marcador
> de detalhes. Reabre pelo "?" da tela (Tutorial.explain).

## L557-558 (em `lines`, junto a `function Tutorial.lockedClassesText()`)

> "*Mago*: Vença o chefe do Ato 2. *Ladino*: ..." — classes bloqueadas
> com o requisito REAL (UnlockSystem.getClassUnlockInfo); "" se nenhuma.

## L583 (em `scriptIndex`, junto a `Tutorial.MAGE_CONVERSATIONS = { "conduit", "channel", "pulse", "evoke_card", "overflow", "focus" }`)

> As conversas do mago (orbes), na ordem em que entram na 1ª corrida.

## L586-588 (em `Tutorial.MAGE_CONVERSATIONS`, junto a `local function PS() return require("engine.ProfileStats") end`)

> ===================================================================
> Persistência / ligar-desligar
> ===================================================================

## L606-608 (em `latched`, junto a `local function stateMatches(def, state)`)

> ===================================================================
> Ciclo
> ===================================================================

## L626-630 (em `eligible`, junto a `local function safeCall(fn, def, game)`)

> `line.vars()` (opcional) preenche a fala com dado VIVO (requisito de
> classe do UnlockSystem, passiva da classe): o texto nunca crava número.
> Gatilhos: arma (1ª ocorrência) e expira. Roda TODO quadro, inclusive com
> outra conversa aberta ou outro modal — a ocorrência no meio da apresentação
> conta, e sai logo depois dela.

## L660-661 (em `updateLatches`, junto a `local function nextCandidate(state, game)`)

> A próxima conversa: roteiro fixo primeiro (apresentação, telas), depois os
> gatilhos armados que estão prontos, do mais antigo pro mais novo.

## L666-668 (em `nextCandidate`, junto a `local best, bestT, bestI`)

> Empate de hora (dois gatilhos no mesmo quadro, como Conduíte e a
> canalização logo depois da apresentação) sai pela ordem do roteiro —
> `pairs` sozinho deixaria a ordem ao acaso.

## L681-683 (em `nextCandidate`, junto a `function Tutorial.holdsTurn()`)

> A luta espera o corvo: com dica de luta ARMADA (ou falando), o turno não
> passa sozinho (GameplayScene: auto-encerrar). Sem isto, jogar a última
> carta encerrava o turno em 0,2s e a dica do Bloqueio perdia a vez.

## L687-688 (em `Tutorial.holdsTurn`, junto a `local now = love.timer.getTime()`)

> teto: gatilho armado segura no máximo HOLD_MAX s se a dica não fica
> pronta (objeto que não chegou a ser desenhado nunca trava a luta)

## L741-743 (em `closing`, junto a `local function lineApplies(line, game)`)

> Próxima fala (ou fim da conversa).
> `line.cond()` (opcional) falso = a fala não se aplica agora (ex.: nenhuma
> classe bloqueada) e é pulada.

## L774 (em `Tutorial.mode`, junto a `function Tutorial.update(dt, state, game)`)

> Chamado todo frame pelo main.lua (love.update).

## L845-847 (em `base`, junto a `function Tutorial.explain(id, game)`)

> Explicação SOB DEMANDA (o "?" de uma tela): abre a conversa `id` agora,
> ignorando "já vista" e o liga/desliga das dicas — foi o jogador que pediu.
> Recusa se outra conversa está aberta (não atropela). Devolve true se abriu.

## L856-857 (em `Tutorial.activeLine`, junto a `function Tutorial.advance()`)

> Clique/A/Enter: completa o texto; texto completo → próxima fala.
> Em fala de AÇÃO não avança (o jogador tem que fazer a coisa).

## L893-896 (em `Tutorial.disable`, junto a `function Tutorial._show(id, lineId, game)`)

> ===================================================================
> Testes/tools
> ===================================================================
> Mostra uma conversa direto (sem esperar a condição), na fala `lineId`.

## L920-922 (em `events`, junto a `function Tutorial.avoidZones()`)

> ===================================================================
> Layout (puro, pros testes) e desenho
> ===================================================================

## L947-948 (em `f.right`, junto a `f.right = { glyph = dev ~= "mouse" and lab("confirm") or nil,`)

> neutro: "Continuar"; no teclado/pad ganha o glifo do botão
> (ENTER / A) pelo último dispositivo usado

## L1001-1003 (em `towards`, junto a `local function inRect(r, x, y)`)

> ===================================================================
> Entrada
> ===================================================================

## L1018-1019 (em `footerClick`, junto a `function Tutorial.blocksPointer(x, y, phase)`)

> main.lua: na fala de AÇÃO, clique fora do recorte não passa (e o release
> de um clique barrado também não). phase = "pressed" | "released".

## L1038-1039 (em `Tutorial.blocksPointer`, junto a `function Tutorial.blocksKey(key)`)

> main.lua: na fala de AÇÃO, atalhos que não são a ação pedida não passam
> (Q/E e X/Y do pad encerram turno/jogam). Navegação e Esc passam.

## L1048 (em `gated`, junto a `local overlay = { ownsNavigation = true }`)

> Overlay do InputFocus: dono da entrada só na FALA (na ação, larga).

