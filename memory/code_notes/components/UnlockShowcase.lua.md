---
name: code_notes/components/UnlockShowcase.lua
description: Comentários com decisão/regra/histórico colhidos de components/UnlockShowcase.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/UnlockShowcase.lua`

Origem: `components/UnlockShowcase.lua` em `7dbdb60d` (23 de 49 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-29 (junto a `local FontManager = require("src.ui.FontManager")`)

> components/UnlockShowcase.lua
> REVELAÇÕES NO MENU (Out/2026, pedido do dono: "igual ao Balatro: terminou
> a run e voltou pro menu, mostra tudo o que desbloqueou").
>
> Um painel por vez sobre o menu escurecido, na ordem da fila
> (src/systems/UnlockQueue.lua): carta nova (com a moldura, grande), classe
> nova (emblema), nível de maestria, Selo liberado, conquista. Cada painel tem
> título curto, o item grande com um efeito de revelação, nome, uma linha do
> que ele significa, o contador "2 de 5" e os botões Continuar (clique / A /
> Enter) e Pular tudo (Esc / B).
>
> REVELAÇÃO NA GRADE DA ARTE (v2, Out/2026 — o dono achou os raios v1,
> triângulos vetoriais translúcidos girando, "muito tosco"): o palco é um
> shader por célula de 2 px (shaders/reveal_stage.glsl — halo posterizado com
> dither Bayer + espinhos de 1 célula girando em saltos), faíscas de 1-2
> células que piscam, e o item desenhado num canvas de MEIA resolução (1 px
> do canvas = 1 célula) — assim selo, emblema, ícone e carta nascem na mesma
> grade, a varredura de luz da carta inédita (DiscoveryMark) passa por todos
> com a mesma faixa chunky, e o clarão é a SILHUETA do item em aditivo, não
> um retângulo branco. Cartas raras/lendárias mantêm o holo delas.
> reducedMotion: halo parado, sem espinhos, faíscas, varredura nem pop.
>
> Abre SOZINHO: watch() roda todo frame e, com o jogador no menu, nenhum
> outro modal na frente e fila não vazia, mostra. A fila mora no perfil, então
> o que não foi visto (jogo fechado no meio) aparece no próximo boot.
>
> Layout em ZONAS puro (layout + validate) no espaço virtual do UiScale
> (a classe é adotada no fim do arquivo). reducedMotion tira o movimento
> (pop, giro, flutuação), nunca a informação.

## L45-46 (em `Showcase`, junto a `Showcase.ownsNavigation = true`)

> Navega sozinha (MenuKit): o NavCursor não toma as teclas; o pad chega
> como tecla. Os botões ainda publicam alvos pro anel de foco.

## L60-62 (em `reducedMotion`, junto a `local function className(id)`)

> ===================================================================
> DADOS DO PAINEL (puro: textos do item)
> ===================================================================

## L84 (em `Showcase.texts`, junto a `local bundles = require("src.data.unlocks").CLASS_BUNDLES[it.classId or ""]`)

> "novas cartas" só quando o nível traz pacote (nível vazio não mente)

## L108-110 (em `Showcase.texts`, junto a `function Showcase.layout(sw, sh)`)

> ===================================================================
> LAYOUT (puro)
> ===================================================================

## L161-163 (em `zones`, junto a `function Showcase:new()`)

> ===================================================================
> CICLO
> ===================================================================

## L168-170 (em `Showcase:new`, junto a `self.inspectModal = require("src.ui.CardInspectModal"):new()`)

> Inspeção da Coleção (carta grande + descrição) por cima do painel; Esc/B
> fecha SÓ ela — o painel continua. A revelação é o captor do InputFocus,
> então o roteamento é interno (mousepressed/keypressed abaixo).

## L219 (em `Showcase:resize`, junto a `function Showcase:watch(state, dt)`)

> Chamado todo frame pelo main: no menu, sem outro modal, com fila → abre.

## L258-261 (em `Showcase:update`, junto a `if self.item and self.item.kind == "card" then`)

> A carta revelada é uma Card DE VERDADE: hover levanta/inclina, anima o
> ícone e abre o tooltip ao lado (Card:draw cuida). O hover vale desde o
> começo — só o CLIQUE espera o INPUT_DELAY — e cede à inspeção aberta.
> Com o foco do teclado/pad na carta, o "mouse" mora no centro dela.

## L272-274 (em `Showcase:update`, junto a `local allowed = self.t > 0.1 and inst._showcaseLaid == true`)

> só vira alvo de hover depois de DESENHADA no lugar: antes disso
> self.x/y = 0 e a caixa de hover (união home+render) ia do canto
> da tela até a carta (mesma armadilha do _csLaid da seleção de classe)

## L292-294 (em `Showcase:update`, junto a `local function buttonAt(L, x, y)`)

> ===================================================================
> ENTRADA
> ===================================================================

## L312-313 (em `Showcase:_cardAt`, junto a `function Showcase:openInspect()`)

> Abre a inspeção da Coleção na carta revelada (clique / botão direito /
> A com a carta em foco / gatilho). Devolve true se abriu.

## L411-413 (em `Showcase:keypressed`, junto a `local cardDb = nil`)

> ===================================================================
> DRAW
> ===================================================================

## L441-442 (em `Showcase:_card`, junto a `function Showcase:_cardRect(L)`)

> Retângulo de REPOUSO da carta no palco (coords virtuais) + escala.
> Escala inteira a partir de 2x (a arte é pixel); abaixo disso, livre.

## L445-446 (em `Showcase:_cardRect`, junto a `local Config = require("src.core.Config")`)

> folga pro LIFT do hover (a carta sobe isto): sem ela, em 1024x768 a carta
> levantada cobria o título e o contador "1 de 5"

## L464-466 (em `cardImage`, junto a `Showcase.CELL = 2`)

> ===================================================================
> PALCO na grade da arte
> ===================================================================

## L509-510 (em `drawGlow`, junto a `local function hash(seed, i, k)`)

> Faíscas douradas: pontos de 1 célula que piscam (cruz de 3 no pico), em
> posições fixas por item (hash do seed) — nunca por cima do centro do palco.

## L542-543 (em `snap`, junto a `local function steppedDisc(cx, cy, r)`)

> Disco em DEGRAUS (coords do canvas do palco, 1 px = 1 célula): linhas
> horizontais de largura inteira — círculo vetorial liso destoava da grade.

## L574-575 (em `drawSeal`, junto a `function Showcase:_drawItem(it, st)`)

> Desenha o item no CANVAS do palco (coords do canvas: 1 px = 1 célula);
> devolve o retângulo da arte nessas coords. Escalas inteiras quando ≥ 1.

## L590-591 (em `Showcase:_drawItem`, junto a `local HoloShader = require("src.ui.HoloShader")`)

> Palco de revelação = interação plena: força de hover e a
> varredura correndo (HoloShader v2; rara prata, lendária ouro).

## L655-656 (em `Showcase:_drawStageItem`, junto a `love.graphics.setCanvas(snap)`)

> itens sem imagem única (emblema, selo, ícone): varre uma cópia
> do canvas do palco; a faixa segue a silhueta do que foi desenhado

## L747-749 (em `Showcase:draw`, junto a `local cr = self:_cardRect(L)`)

> carta DE VERDADE (Card:draw): hover levanta/inclina, ícone vivo,
> tooltip ao lado (adiado pro fim), alvo do NavCursor. Pop em volta
> do centro do palco; varredura e clarão na posição de repouso.

## L759-761 (em `Showcase:draw`, junto a `local shown = CardFrame.displayImage(inst) or inst.image`)

> varredura e clarao usam o MESMO quadro que a carta desenhou: com o
> icone vivo (dono, 13/Out/2026) a estatica aqui seria um fantasma
> parado por cima da animacao

