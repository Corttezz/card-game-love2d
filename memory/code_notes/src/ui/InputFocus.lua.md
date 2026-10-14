---
name: code_notes/src/ui/InputFocus.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/InputFocus.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/InputFocus.lua`

Origem: `src/ui/InputFocus.lua` em `7dbdb60d` (19 de 29 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-48 (junto a `local InputFocus = {}`)

> src/ui/InputFocus.lua
> QUEM TEM O FOCO DE ENTRADA.
>
> O defeito que isto mata (playtest Set/2026): "dentro do menu de pausa o
> hover continua pegando elementos de trás". Overlays desenhavam por cima e
> até engoliam o CLIQUE, mas o HOVER deste projeto não passa por evento — ele
> é POLLING: 43 call sites em 25 arquivos perguntam `love.mouse.getPosition()`
> dentro do próprio update/draw (Button, Card, TopBar, EnemyHud, OrbRow,
> JokerSlot, grids das telas cheias...). Enquanto o dispatch do main.lua
> continuar chamando update/draw da cena de trás — e ele precisa continuar,
> senão o mundo congela — cada um desses 43 sites enxerga o mouse e acende.
>
> Consertar isso com `if pauseMenu.visible then return end` espalhado seria
> 43 remendos, e o próximo overlay nasceria com o mesmo bug. A verdade que
> FALTAVA é uma só: *de quem é o mouse neste instante*. Este módulo é ela.
>
> COMO FUNCIONA (duas peças, uma ideia):
>
> 1. REGISTRO de overlays, em ordem de prioridade. Cada um só precisa
> responder `isVisible()`. O topo visível é quem tem o foco.
>
> 2. CAMADA DE DESPACHO: o main.lua diz, ao redor de cada update/draw, em
> nome de QUEM está desenhando (`push("scene")` … `pop()`). O patch
> global de `love.mouse.getPosition` (mesmo ponto onde já mora a lente
> do CRT) devolve uma posição FORA DA TELA quando a camada corrente não
> é a dona do foco. Aí os 43 call sites descobrem sozinhos que o mouse
> "não está sobre eles" — sem uma linha de mudança em nenhum deles.
>
> Consequências que importam:
> * overlay NOVO nasce bloqueando: basta registrá-lo (uma linha); a camada
> "scene" já está declarada e é bloqueada por QUALQUER overlay visível;
> * fechar o overlay devolve o hover de trás SEM mexer o mouse — o hover é
> recalculado por polling todo frame, então volta no frame seguinte;
> * o hover DENTRO do overlay continua vivo: ele desenha na PRÓPRIA camada,
> que é justamente a que tem o foco.
>
> DOIS TIPOS DE OVERLAY:
> modal  (default)      captura os eventos (mouse/teclado/roda) e apaga
> TUDO atrás, inclusive a TopBar. Ex.: pausa,
> configurações, deck, coringas, roteiro, pacote.
> cobertura (keepChrome) tapa a CENA mas a TopBar continua viva e clicável,
> e os eventos seguem pelo roteamento de estado do
> main.lua. Ex.: descanso, evento, mapa, cash out —
> telas de ESTADO, onde clicar no ouro/deck/engrenagem
> da barra é comportamento desejado.
>
> Ver também: memory/ui_layout_invariants.md (§ fallback silencioso — aqui
> nada falha calado: registro inválido AVISA por print).

## L56-57 (em `InputFocus`, junto a `InputFocus.OFFSCREEN = -32000`)

> Sentinela: longe o bastante pra falhar qualquer hit-test, perto o bastante
> pra não estourar aritmética de ninguém.

## L65-66 (em `stack`, junto a `local positionOverride`)

> Navegação por teclado/pad (src/ui/NavCursor): no modo foco, o "mouse" é o
> centro do alvo focado — hover/tooltip/lift reagem ao foco sem mudar nada.

## L71-73 (em `InputFocus.setPositionOverride`, junto a `function InputFocus.clear()`)

> ==========================================================================
> Registro
> ==========================================================================

## L75-76 (em `InputFocus.setPositionOverride`, junto a `function InputFocus.clear()`)

> Zera registro e pilha. Existe pros testes/tools — o jogo registra uma vez
> no love.load.

## L82-86 (em `stack`, junto a `function InputFocus.register(name, obj, opts)`)

> register(name, obj [, opts])
> obj precisa expor isVisible().
> opts.keepChrome = true  → cobertura: não apaga a TopBar nem captura eventos.
> A ORDEM das chamadas é a prioridade: registre coberturas primeiro e o modal
> mais "por cima de tudo" (configurações) por último.

## L104-105 (em `entry`, junto a `capturesEvents = not keepChrome,`)

> Cobertura não captura evento: o roteamento por ESTADO do main.lua
> já entrega o clique pra ela, e a TopBar precisa continuar recebendo.

## L117-119 (em `InputFocus.count`, junto a `function InputFocus.freezesCombat(state)`)

> O combate congela? Sim quando há um MODAL (que captura eventos) aberto
> sobre a luta: pausa, configurações, deck, coringas, roteiro. Cobertura
> (keepChrome) não conta — ela nunca aparece durante "playing".

## L125-130 (em `InputFocus.freezesCombat`, junto a `function InputFocus.hideAll()`)

> Fecha TODO overlay registrado que estiver visível (do topo pra base).
> Usado ao voltar pro menu: uma cobertura esquecida visível (descanso,
> evento, mapa, cash out) tomava o foco e o menu inteiro ficava sem hover nem
> clique — softlock depois de "Salvar e sair" (revisão de lançamento,
> Out/2026). Overlay sem hide() é AVISADO, não ignorado em silêncio.
> Devolve quantos fechou.

## L156-158 (em `t`, junto a `local function topVisible()`)

> ==========================================================================
> Quem está com o foco
> ==========================================================================

## L183-184 (em `InputFocus.activeName`, junto a `function InputFocus.captor()`)

> O overlay que deve RECEBER os eventos (mouse/teclado/roda), ou nil se o
> roteamento normal por estado deve seguir. Devolve (obj, name).

## L191-193 (em `InputFocus.captor`, junto a `function InputFocus.push(layer) stack[#stack + 1] = layer end`)

> ==========================================================================
> Camadas de despacho
> ==========================================================================

## L199-200 (em `InputFocus.current`, junto a `local warnedLeak = false`)

> Higiene de frame: um erro no meio de um draw pode deixar a pilha torta.
> O main.lua zera no começo do update e do draw.

## L203-205 (em `InputFocus.resetLayers`, junto a `if #stack > 0 and not warnedLeak then`)

> Pilha suja aqui = alguem empurrou camada e nao tirou (return no meio de
> um dispatch, por exemplo). Isso BLOQUEIA hover pra sempre — o defeito
> inverso, e silencioso. Avisa uma vez e diz qual camada ficou presa.

## L215-216 (em `InputFocus.resetLayers`, junto a `local function entryNamed(name)`)

> A camada `layer` (default: a corrente) pode ler o mouse agora?
> Entrada registrada com este nome, ou nil.

## L228-229 (em `InputFocus.allows`, junto a `if layer == nil then return true end`)

> Camada nenhuma declarada = chrome global (cursor do mouse, tooltips já
> agendados). Nunca se bloqueia — senão o cursor pararia de seguir o mouse.

## L234-250 (em `InputFocus.allows`, junto a `if not e.capturesEvents then`)

> COBERTURA vs COBERTURA: quem está DESENHANDO manda.
>
> Coberturas são telas de ESTADO (mapa, descanso/picker, evento, cash
> out) e a prioridade entre elas é a ordem de registro — o que está certo
> para modais empilhados, e errado aqui, porque duas telas de estado podem
> estar visíveis ao mesmo tempo sem uma estar "por cima" da outra.
>
> O caso real (dono, Set/2026: "tela de remover carta nenhum clique
> funciona"): `_G.openCardPicker` reusa o RestScreen e troca
> `currentState` para "rest", mas NÃO esconde a tela que o chamou. Aberto
> a partir de um evento, o `eventScreen` seguia visível e — por ter sido
> registrado depois — roubava o foco do picker. O mouse do picker virava a
> sentinela, nenhum item ficava sob o cursor e o clique não achava alvo.
> O clique CHEGAVA; ele é que não tinha em quem cair.
>
> MODAL continua ganhando de tudo: se o topo captura eventos (pause,
> settings, deck viewer...), nenhuma cobertura passa por aqui.

## L262-264 (em `InputFocus.allows`, junto a `function InputFocus.gate(x, y)`)

> ==========================================================================
> O portão do mouse
> ==========================================================================

## L272-275 (em `InputFocus.gate`, junto a `function InputFocus.installMouseGate(screenToContent, rawFn)`)

> Instala o patch global de leitura do mouse.
> screenToContent : função opcional tela→conteúdo (a lente do CRT).
> rawFn           : fonte crua opcional (testes injetam um mouse falso).
> Idempotente: reinstalar não embrulha o próprio wrapper.

