---
name: code_notes/components/ClassSelectionScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/ClassSelectionScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/ClassSelectionScreen.lua`

Origem: `components/ClassSelectionScreen.lua` em `7dbdb60d` (24 de 75 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `local Button = require("components.Button")`)

> components/ClassSelectionScreen.lua
> Seleção de classe v4 — "a página do grimório" (Out/2026).
> O dono achou a v3 poluída e com "cara de IA": três painéis iguais lado a
> lado, cada um com nome, maestria, barra, descrição, vida, passiva longa e
> duas cartas — tudo de uma vez. A v4 mostra UMA classe por vez:
> • à esquerda, o EMBLEMA da classe em foco, grande e vivo (ClassEmblem +
> o ar em volta, ClassHeroFx) e, no pé, as três classes pequenas pra
> trocar o foco; ao lado delas o Selo do Grimório (só se já liberado);
> • à direita, uma folha de grimório (GrimoirePage) com o essencial —
> nome, uma linha de identidade, a passiva em uma linha, vida/mana/
> baralho em ícones — e a fita COMEÇAR. O resto (passiva completa,
> cartas iniciais, maestria, recordes) mora atrás do marcador DETALHES.
> Classe bloqueada: silhueta acorrentada + a condição de liberação, só.
> Tipografia: DUAS fontes (nome e corpo); ênfase por cor, não por tamanho.
> Layout = ZONAS (src/ui/ClassSelectLayout.lua, com validate()).
>
> Contrato com o main/tools/testes: new/show/hide/update/draw/keypressed/
> mousepressed/mousereleased/resize/updatePositions, selectClass(id) inicia a
> run (bloqueada recusa), focusClass(id) só troca o foco, sealFor(id),
> buttons[classId] = o emblema pequeno da classe, _panelOf(id).

## L51 (em `rogue`, junto a `local CLASS_ORDER = { "warrior", "mage", "rogue" }`)

> Ordem FIXA de exibição (pairs() embaralhava a ordem entre sessões)

## L73 (em `instance._sparks`, junto a `instance._sealTip = 0`)

> regra do selo visível por um instante

## L75-78 (em `instance._sparks`, junto a `instance.inspectModal = require("src.ui.CardInspectModal"):new()`)

> Inspeção das cartas iniciais (a MESMA da Coleção/Deck). O handle é
> registrado no InputFocus (main.lua): aberto, ele captura teclado/pad/
> mouse e o NavCursor não anda por trás. Tudo passa pelos métodos da tela
> (adotados pelo UiScale: coordenadas virtuais).

## L166-168 (em `panel`, junto a `do`)

> "?" do corvo narrador: à direita da escolha de classe (a banda do pé
> tem folga até o marcador; junto do "voltar" ele brigaria com o selo).
> Reabre a conversa da seleção a qualquer momento (Tutorial.explain).

## L185-186 (em `self._help`, junto a `function ClassSelectionScreen:_syncButtons()`)

> Botões que dependem do estado (classe bloqueada não tem COMEÇAR nem
> DETALHES; sem selo liberado o seletor some).

## L312 (em `ClassSelectionScreen:selectClass`, junto a `if not UnlockSystem.isClassUnlocked(classId) then`)

> BLOQUEADA: nega com som + tremor; nunca inicia run.

## L330-331 (em `confirm`, junto a `local EM = _G.EventManager`)

> O MOMENTO da escolha: emblema acende, anel, faíscas, som; a
> confirmação vem 0.45s depois (fila própria e não-bloqueante).

## L348-351 (em `confirm`, junto a `Sfx.play("healShimmerSoft", { volume = 1.0, pitch = 0.95 })`)

> Era o stinger de COMBO a 0,8 (dono, 13/Out: "muito alto, muito
> estridente, horroroso"): escolher a classe ganha um brilho suave,
> não uma fanfarra. O embaralhar do deck (deckStart) toca logo em
> seguida, baixo, no startGame.

## L464-465 (em `hovered`, junto a `local function paragraph(text, x, y, w, size, maxLines)`)

> Parágrafo quebrado na largura, na fonte dada (sem encolher: a tela tem só
> duas fontes). Devolve a altura usada; `maxLines` corta o excedente com "...".

## L517 (em `ClassSelectionScreen:draw`, junto a `for _, p in ipairs(self.panels) do`)

> alvos do foco (teclado/pad): a ordem de leitura da tela

## L543-544 (em `ClassSelectionScreen:draw`, junto a `local owner = self:tooltipOwner()`)

> tooltip da carta inicial: UM dono só (a carta sob o mouse/foco, como
> a mão do combate); com a inspeção aberta, nenhum

## L602-603 (em `ClassSelectionScreen:_drawHero`, junto a `function ClassSelectionScreen:_drawChooser()`)

> As três classes pequenas: em foco = cor plena e marcador dourado embaixo;
> as outras recuam (escurecidas); bloqueada = silhueta acorrentada.

## L620 (em `ClassSelectionScreen:_drawChooser`, junto a `local f = FontManager.getFont(self.layout.bodyFont)`)

> nome sob demanda: só quando o mouse/foco passa pela classe

## L683 (em `inner`, junto a `if f:getWidth(title) > inner.x + inner.w - tx then`)

> sem caber, o título encurta pra "Selo N" (o nome vai pra dica) — nunca "..."

## L690-691 (em `inner`, junto a `local mx, my = love.mouse.getPosition()`)

> a REGRA do selo (e o teto da classe em foco) aparece sob demanda:
> mouse/foco na faixa, ou logo depois de trocar o selo

## L789 (em `ClassSelectionScreen:_drawSummaryPage`, junto a `ink(Palette.BLOOD, a)`)

> passiva: nome em sangue, a regra numa linha curta

## L820-821 (em `items`, junto a `function ClassSelectionScreen:_drawPlate(p, r, a)`)

> GRAVURA: o objeto da classe desenhado em tinta, apagado, no pé da folha
> (as pranchas dos grimórios). Ocupa o papel que sobra sem dizer nada.

## L855-857 (em `ClassSelectionScreen:_drawDetailsPage`, junto a `local cx = r.x`)

> cartas DE VERDADE (Card:draw): hover levanta/inclina, anima o ícone e
> abre o tooltip ao lado; clique/A/botão direito = inspeção. O foco do
> NavCursor vem do próprio Card:draw.

## L868-870 (em `self._starterRects`, junto a `inst._csLaid = true`)

> só vira alvo de hover depois de desenhada no lugar: antes disso
> self.x/y = 0 e a caixa de hover (união home+render) ia do
> canto da tela até a carta

## L996-997 (em `ClassSelectionScreen:_drawHelp`, junto a `function ClassSelectionScreen:_reportTutorialAnchors()`)

> Âncoras do corvo narrador (conversa "class_select" em src/systems/Tutorial):
> emblema grande, fita do COMEÇAR, marcador DETALHES, as classes acorrentadas.

## L1025-1027 (em `ClassSelectionScreen:_drawBack`, junto a `local BRAZIER_ANCHORS = {`)

> ===== backdrop vivo =====
> Âncoras dos 2 BRASEIROS na imagem do salão (coords relativas ao PNG
> 400×256, v2 "limpo" Jul/2026 — ajuste se regenerar).

## L1114-1116 (em `ClassSelectionScreen:_starterAt`, junto a `function ClassSelectionScreen:tooltipOwner()`)

> A carta inicial dona do tooltip: a que está sob o mouse/foco agora. Se a
> caixa de hover de duas se tocar (a que sobe invade a vizinha), vence a que
> contém o ponteiro; sem ponteiro dentro, nenhuma.

## L1146-1147 (em `ClassSelectionScreen:_updateStarters`, junto a `function ClassSelectionScreen:openInspect(i)`)

> Abre a inspeção (a da Coleção) na carta i da classe em foco; as setas
> passam pelas outras iniciais. Nunca por cima de uma fala do corvo.

