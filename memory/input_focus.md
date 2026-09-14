---
name: Input Focus (quem é o dono do mouse)
description: Overlay aberto captura o input por CONSTRUÇÃO — registro em main.lua + camadas de despacho + portão no love.mouse.getPosition. Nasceu do bug "no menu de pausa o hover continua pegando elementos de trás" (Set/2026).
type: project
---

# Input Focus — overlay aberto é dono do mouse

**LER ANTES DE CRIAR QUALQUER OVERLAY/MODAL.** Uma linha de registro e a tela
nova já bloqueia o que está atrás. Esquecer essa linha é o único jeito de
reintroduzir o bug.

## O defeito que originou isto

Playtest Set/2026, dono: *"quando estou dentro do menu de pause o hover
continua pegando elementos de trás, revisar todas telas que podem ter o mesmo
comportamento"*.

O clique já era bloqueado (o `PauseMenu:mousepressed` sempre devolvia `true`).
O **hover** não, porque hover neste projeto **não passa por evento**: são ~43
call sites em 25 arquivos que perguntam `love.mouse.getPosition()` dentro do
próprio `update`/`draw` — `Button`, `Card`, `TopBar`, `EnemyHud`, `OrbRow`,
`JokerSlot`, `HudPlayerPanel`, `StatusPill`, e os grids de todas as telas
cheias. Enquanto o `main.lua` seguir despachando `update`/`draw` da cena de
trás — e ele **precisa** seguir, senão o mundo congela atrás do menu — cada um
desses 43 enxerga o mouse e acende.

Por isso a correção não podia ser `if pauseMenu.visible then return end`: seria
43 remendos, e o próximo overlay nasceria com o mesmo bug.

## O desenho (`src/ui/InputFocus.lua`)

Duas peças, uma ideia — *de quem é o mouse neste instante*:

1. **Registro** (uma lista em `love.load`, no `main.lua`). Cada overlay só
   precisa responder `isVisible()`. A ordem das chamadas é a prioridade; o
   topo visível tem o foco.
2. **Camada de despacho**: o `main.lua` declara, ao redor de cada update/draw,
   em nome de QUEM está desenhando (`IF.push(IF.SCENE)` … `IF.pop()`). O patch
   global de `love.mouse.getPosition` — **o mesmo ponto onde já morava a lente
   do CRT** (`CRTShader.screenToContent`) — devolve `-32000, -32000` quando a
   camada corrente não é a dona do foco.

Consequências que caem de graça:

* hover de trás morre **sem tocar em nenhum dos 43 call sites**;
* fechar o overlay devolve o hover **sem mexer o mouse** (hover é polling: volta
  no frame seguinte). Hover preso aceso e hover preso apagado são os dois
  defeitos inversos, e os dois estão travados por teste;
* hover DENTRO do overlay continua vivo: ele desenha na própria camada.

## Dois tipos de overlay

| tipo | registro | o que faz |
|---|---|---|
| **modal** (default) | `IF.register("pause", pauseMenu)` | captura mouse/teclado/roda e apaga TUDO atrás, **TopBar inclusive** |
| **cobertura** | `IF.register("rest", restScreen, { keepChrome = true })` | tapa a CENA, mas a TopBar (camada `CHROME`) segue viva e clicável e os eventos continuam indo pelo roteamento de ESTADO |

Cobertura existe porque loja/descanso/evento/mapa/cash-out **são estados**, e
clicar no ouro/deck/engrenagem da barra ali é comportamento desejado.

## Registro atual (ordem = prioridade)

`map` · `rest` · `event` · `roundEval` (coberturas) → `packOpen` ·
`deckViewer` · `jokerManager` · `runJournal` · `pause` · `settings` (modais).

Não registrados de propósito: `cardReward` (o mundo atrás é **interativo** —
`WorldRoad.pokeSceneAt`), a encruzilhada do `WorldRoad` (a escolha acontece NO
MUNDO, é cena), e os estados de tela cheia sem nada atrás (menu, coleção,
conquistas, seleção de classe).

## Ao criar uma tela nova

1. exponha `isVisible()`;
2. registre no bloco do `love.load` (`IF.register(...)`), no MESMO commit;
3. se ela desenha fora da cadeia normal, envolva o draw dela com
   `IF.push("nome") … IF.pop()`.

Sem o passo 2 a tela desenha por cima e **não bloqueia nada** — exatamente o
bug de origem.

## Armadilhas registradas

* **`push` sem `pop` bloqueia hover pra sempre** e é silencioso. Por isso
  `resetLayers()` avisa por `print` quando acha a pilha suja entre frames
  (nada de fallback silencioso — ver [[ui_layout_invariants]]).
* **Arrasto de carta**: com o mouse lendo fora da tela, a carta arrastada
  seguiria a sentinela e sumiria da mão. `GameplayScene.update` SOLTA o arrasto
  quando perde o foco.
* **Parallax do menu** lê o mouse: com Configurações aberto ele deriva
  suavemente pro canto (mouse "não está sobre a camada"). É esperado.
* Modais aninhados DENTRO de uma tela (o `CardInspectModal` do Deck Viewer e da
  Coleção) continuam resolvidos à mão pela tela dona, com uma flag `modalOpen`.
  Se um terceiro aparecer, promova pro registro em vez de copiar a flag.

Teste: `love . test_one test_input_focus` (50 asserções — mecanismo, `Button` e
`PauseMenu` reais, e a FIAÇÃO do `main.lua` fatiada por função, porque o
mecanismo certo com o dispatch revertido passava).
