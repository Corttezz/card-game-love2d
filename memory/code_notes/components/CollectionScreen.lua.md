---
name: code_notes/components/CollectionScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/CollectionScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/CollectionScreen.lua`

Origem: `components/CollectionScreen.lua` em `7dbdb60d` (25 de 114 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local Debug        = require("src.core.Debug")`)

> components/CollectionScreen.lua
> Tela de coleção: grid com todas as cartas do CardDatabase.
> Scroll vertical com mouse wheel, filtros por classe, tooltip no hover.
> Acessível pelo botão "COLEÇÃO" no menu principal, ESC volta.

## L63-64 (em `self.filtered`, junto a `local function sortCards(list)`)

> Ordena cartas: class > rarity > name (ordena pelo nome localizado pra ficar
> alfabético no idioma atual)

## L77-82 (em `sortCards`, junto a `function CollectionScreen:_buildInstances(budgetSecs)`)

> Converte cartas raw → instâncias renderizadas (com CardFrame aplicado).
> v10.6 (perf — "engasgada ao clicar em COLEÇÃO"): INCREMENTAL com
> orçamento de tempo por frame. A tela abre instantânea e as cartas
> aparecem em ondas na ordem do grid (topo primeiro); ~0.3-0.6s pra
> completar, sem travar frame nenhum. show() constrói a 1ª leva,
> update() consome o resto.

## L102-104 (em `list`, junto a `self.cardInstances[#self.cardInstances + 1] = self:_makeHidden(cd)`)

> NÃO DESCOBERTA (Balatro): ocupa o slot mas aparece como verso
> "?". Stub leve — nem compõe o canvas da carta (que o jogador
> não vai ver), o que também barateia a abertura da tela.

## L134-135 (em `CollectionScreen:_makeHidden`, junto a `function CollectionScreen:_refreshDiscovery()`)

> Reabrir a Coleção depois de uma run: o que foi descoberto nesse meio-tempo
> vira carta de verdade (e o que estava liberado-mas-oculto atualiza o selo).

## L158 (em `CollectionScreen:_applyFilter`, junto a `self._hasManualOrder = false`)

> Trocar filtro reseta a ordem manual (usuário volta pra sort padrão)

## L191-192 (em `CollectionScreen:show`, junto a `self:_refreshDiscovery()`)

> 1ª leva um pouco maior (preenche o que está na tela de cara);
> o resto flui no update sem travar

## L209-211 (em `CollectionScreen:isVisible`, junto a `function CollectionScreen:resize()`)

> gridOrigin/cardRect calculam dinamicamente da window size a cada frame, então
> o CollectionScreen já é responsivo sem cache de layout. resize() é stub
> pra contrato uniforme com outras overlay screens.

## L238 (em `CollectionScreen:update`, junto a `if not self._buildDone then self:_buildInstances() end`)

> v10.6: consome a fila de instanciação (orçamento por frame)

## L262-265 (em `self.hoverCard`, junto a `local newHover = self.hoverCard and self.hoverCard.instance or nil`)

> Tick sutil quando o card em hover muda. Hover de carta usa hoverCard
> (sound de carta), não menuHover (sound de UI). Pitch random pra evitar
> fadiga ao percorrer a grid rápido. SEM baseVolume — usa Config.Audio.HOVER_VOLUME
> (=0.03) carregado em main.lua, ficando baixinho como esperado.

## L322-324 (em `CollectionScreen:_inspectNeighbor`, junto a `local function closeRect()`)

> X de fechar (mesmo lugar e desenho do Deck Viewer). Substitui a faixa de
> dica do rodapé ("CLIQUE pra inspecionar · RODA pra rolar · ESC volta"):
> regra do projeto, sem rodapé de instruções — a saída mora num objeto.

## L405-406 (em `CollectionScreen:mousepressed`, junto a `function CollectionScreen:_computeDropIndex(mx, my)`)

> Computa o índice 1..#filtered pra onde uma carta cairia, baseado em (mx, my).
> Ignora zonas fora da grid (retorna nil quando clampa pros extremos óbvios).

## L447 (em `CollectionScreen:mousereleased`, junto a `self._hasManualOrder = true`)

> Salva a ordem manual atual (vive enquanto a coleção está aberta)

## L454-455 (em `CollectionScreen:mousereleased`, junto a `Sfx.play("buttonClick", { pitch = 0.7 })`)

> Carta não descoberta não abre zoom (não há o que mostrar); a
> dica de como liberar já está no tooltip do hover.

## L535-538 (em `drawTitleAndFilters`, junto a `local function drawCardMini(instance, x, y, hoverScale, alpha, mouseUV, hoverStrength)`)

> Desenha card mini no grid com perspective warp (mesh+shader) + sombra direcional.
> Luz fixa acima do centro da tela → sombra cai pro lado oposto à posição + press.
> mouseUV: vec2 [-1,1] relativa ao centro da carta (0,0 = sem press)
> hoverStrength: 0..1 (usa pro warp + pro offset tilt da sombra)

## L546-550 (em `drawCardMini`, junto a `local _prevImage = instance.image`)

> Carta VISIVEL = carta VIVA (dono, 13/Out/2026): a grade inteira anima,
> com ou sem hover. A regra (e o reducedMotion) mora em
> CardFrame.displayImage — nunca inline aqui (foi um limiar cravado aqui
> que deixou o Deck Viewer sem animacao em Set/2026).
> Swap temporario de instance.image, restaurado no fim da funcao.

## L583-586 (em `drawCardMini`, junto a `local shader = (hoverStrength > 0.001) and CardMesh.getShader() or nil`)

> Desenha sombra (pode usar mesh pra acompanhar warp)
> Perf (Out/2026): em repouso (hoverStrength 0) o warp é IDENTIDADE —
> o vertex shader não move nada e o fragment é passthrough. Pular shader+
> mesh+uniforms nas cartas paradas tira ~30 shader switches por frame.

## L628-630 (em `drawCardMini`, junto a `local function getMysteryCanvas(self)`)

> Verso da carta NÃO DESCOBERTA, composto UMA vez num canvas 96×144 (mesma
> resolução do canvas da carta → mesma escala/nitidez no grid). Plain draw no
> grid, sem shader: em repouso o warp é identidade.

## L638-639 (em `getMysteryCanvas`, junto a `love.graphics.setScissor()`)

> O 1º uso acontece DENTRO do scissor do grid: sem limpar, o recorte de
> tela vale também pro canvas e o verso sai cortado.

## L681-682 (em `drawMystery`, junto a `local k = inst._locked and 0.55 or 0.9`)

> Bloqueada = mais apagada que a liberada-mas-não-vista: o jogador lê de
> relance o que já pode cair numa run e o que ainda depende de maestria.

## L750 (em `drawHoverTooltip`, junto a `local metaFont = FontManager.getFont(8)`)

> Type / Class / Rarity em 3 linhas separadas (evita overflow horizontal)

## L761-762 (em `drawHoverTooltip`, junto a `local TextFit = require("src.ui.TextFit")`)

> Colunas DINÂMICAS com fit (design system Jul/2026): os offsets fixos
> 72/172 colidiam entre si e vazavam do tooltip em idiomas longos.

## L831-833 (em `drawInspectModal`, junto a `local _prevImage = inst.image`)

> Render da carta com perspective warp + sombra direcional.
> Inspeção ampliada anima o ícone como toda carta visível
> (CardFrame.displayImage decide; reducedMotion = estática).

## L1070-1071 (em `hoverStrFromScale`, junto a `do`)

> foco de teclado/pad (NavCursor): a posição de GRADE de cada carta (a
> mesma do hit-test do clique), recortada pelo scissor da grade

## L1096 (em `hoverStrFromScale`, junto a `if self._draggingIdx then`)

> Drag card por cima — mouse sempre no centro (carta segue mouse), sem warp adicional

