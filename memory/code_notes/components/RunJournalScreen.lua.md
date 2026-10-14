---
name: code_notes/components/RunJournalScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/RunJournalScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/RunJournalScreen.lua`

Origem: `components/RunJournalScreen.lua` em `7dbdb60d` (13 de 47 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-29 (junto a `local RunJournalScreen = {}`)

> components/RunJournalScreen.lua
> ROTEIRO DA JORNADA — um MAPA DESENHADO À MÃO, por ato, numa folha de
> pergaminho envelhecida.
>
> Pedido do dono (13/Out/2026): "Quero que ele seja literalmente um mapa, bem
> parecido com o mapa do Slay the Spire, que vai mostrando ali os trilhos que
> a gente vai seguindo e as decisões que a gente vai tomando. A gente
> consegue abrir e fechar o mapa para cada ato... como se tivesse sido
> escrito à mão, apenas com tinta preta e, no máximo, um círculo vermelho.
> Bem cara de mapa mesmo, com uma folha envelhecida."
>
> Daí as leis desta tela:
> 1. UMA FOLHA POR ATO, empilhadas; cada uma ABRE e FECHA (o ato em
> andamento nasce aberto, os anteriores fechados numa tira com o título).
> 2. O mapa SOBE (andar 1 embaixo, castelo no topo), como no StS. Em cada
> encruzilhada aparecem os ramos que EXISTIAM: o tomado em traço cheio,
> os outros em pontilhado esmaecido terminando curto (não explorado).
> A encruzilhada ainda em aberto (pendingNodes) aparece à frente.
> 3. SÓ TINTA PRETA no papel, e no máximo UM círculo vermelho: onde o
> jogador está. Nada de ícone PNG, foto de castelo nem cor de acento.
> Os símbolos são glifos de pena (src/ui/RunJournalInk.lua), o traço
> ondula por seed da run (sempre igual pra mesma run).
> 4. O resultado de cada parada vira ANOTAÇÃO À MARGEM, em letra miúda.
> 5. ATO NÃO JOGADO NÃO APARECE.
>
> Layout por ZONAS em src/ui/RunJournalLayout.lua (puro, validate()).
> Abrir: clique no indicador de ATO da TopBar OU tecla M. ESC/M/X fecha.
> Teclado/pad: setas rolam, Enter/A abre ou fecha o ato focado (NavCursor),
> 1..9 abre ou fecha o ato N.

## L51-52 (em `RunJournalScreen`, junto a `local warned = {}`)

> Avisos de dado faltando saem UMA vez por chave (nada de fallback silencioso
> — mas também nada de spam a 60fps).

## L71-73 (em `setAlpha`, junto a `function RunJournalScreen.optionText(e)`)

> Opção escolhida num evento, no idioma ATUAL: pela chave do evento
> (events.<id>.optN). O texto gravado no save (`optionLabel`) é do idioma
> daquela hora — fica só de fallback (evento sem chave, save antigo).

## L109-111 (em `instance.acts`, junto a `function RunJournalScreen:_build()`)

> Agrupa os nós visitados em atos, na ordem em que foram visitados, e decide
> a LINHA de cada parada no mapa: andar (ato normal) ou índice (endless, em
> que o par ato/andar se repete).

## L139-141 (em `band`, junto a `local curAct = run.actNumber or 1`)

> Ato concluído = o jogador já cruzou pra um ato posterior. O ato corrente
> fica "em progresso" mesmo com o boss no fim da lista, porque a travessia
> só acontece no advanceFloorInAct seguinte.

## L214-216 (em `RunJournalScreen:isVisible`, junto a `function RunJournalScreen:resize()`)

> O layout inteiro é DERIVADO da janela a cada frame (_layout()); nenhuma
> coordenada sobrevive a um resize. O único estado de posição guardado é o
> scroll, e a janela nova pode ter um maxScroll menor — _layout reclampa.

## L331-332 (em `RunJournalScreen:mousereleased`, junto a `if love.timer.getTime() - (self._openedAt or 0) < 0.25 then return true end`)

> O RELEASE do mesmo clique que abriu (press na TopBar) chega aqui e
> fecharia a tela no mesmo frame — mesma armadilha do DeckViewerScreen.

## L347-348 (em `RunJournalScreen:mousereleased`, junto a `local function primaryOutcome(e)`)

> A anotação à margem: o ganho mais importante, ou a opção do evento.
> Devolve texto, quantos ganhos ficaram de fora, e se é remoção (riscada).

## L373-374 (em `order`, junto a `local function detailLines(e)`)

> Linhas do detalhe completo (hover). Linha só aparece quando o valor MUDOU:
> "Vida 56 -> 56" numa loja é ruído.

## L472-473 (em `RunJournalScreen:_drawHeader`, junto a `function RunJournalScreen:_drawTitle(L, S, i, hovered)`)

> Título da folha (aberta ou fechada): marca de dobra [+]/[-], nome do ato,
> estado à direita. Toda a banda é o alvo do clique.

## L532-533 (em `RunJournalScreen:_drawMap`, junto a `local nf = FontManager.getFont(8)`)

> numerais dos andares (ato normal: 1..8 sempre; endless: o andar de cada
> parada na linha dela)

## L562-563 (em `RunJournalScreen:_drawMap`, junto a `for k, st in ipairs(S.stubs) do`)

> ramos NÃO tomados: pontilhado esmaecido até o símbolo, e hachura curta
> acima dele ("não explorado")

## L660-661 (em `parts`, junto a `function RunJournalScreen:_tipFor(L, si, hover)`)

> Monta as linhas do detalhe cortadas à altura disponível e devolve o
> retângulo já resolvido pelo layout. Exposto pros testes (validate do hover).

