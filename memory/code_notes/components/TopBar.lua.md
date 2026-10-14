---
name: code_notes/components/TopBar.lua
description: Comentários com decisão/regra/histórico colhidos de components/TopBar.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/TopBar.lua`

Origem: `components/TopBar.lua` em `7dbdb60d` (27 de 49 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local FontManager = require("src.ui.FontManager")`)

> components/TopBar.lua
> Barra superior com informações do jogo (ouro, deck, config).
> Pixel chrome: ink fill + borda dourada + ícones via IconLoader.

## L32 (em `TopBar:new`, junto a `instance.configSpin = 0`)

> ângulo acumulado da engrenagem (nunca snapa)

## L51-52 (em `TopBar:update`, junto a `local hoverTarget = self.isConfigHovered and 1 or 0`)

> Hover da engrenagem: valor SUAVIZADO 0..1 (placa/escala fazem fade)
> e giro ACUMULADO — acelera no hover, desacelera ao sair (sem snap).

## L58-59 (em `TopBar:update`, junto a `local g = game or self.game`)

> Ease gold toward real (ease_dollars-style do Balatro). Counter sobe/desce
> suave em vez de saltar quando ganhar/gastar ouro.

## L61-62 (em `TopBar:update`, junto a `if g and g ~= self.game then self.game = g end`)

> Adota o game ATUAL (returnToMenu recria o Game — sem isto a barra fica
> presa na instância morta: ouro congelado e engrenagem no aviso).

## L66-68 (em `TopBar:update`, junto a `if self._lastGold and self._lastGold ~= realGold then`)

> Detecta delta de gold (ganho/gasto) e dispara micro-jiggle Balatro-style
> (engine/ui.lua:990 pattern: cada evento monetário empurra o accumulator).
> Skip primeiro frame onde _lastGold é nil pra não jigglar no boot.

## L75-76 (em `TopBar:update`, junto a `self._goldFlash = {`)

> Flash direcional no NÚMERO (padrão TopPanel do StS: verde ao
> ganhar, vermelho ao gastar — a direção da mudança é informação).

## L81-86 (em `self._goldFlash`, junto a `self:_onGoldDelta(delta)`)

> SOM + número subindo no cofre. `goldGain` estava registrado
> desde sempre e NUNCA tinha sido tocado por ninguém (auditoria
> Set/2026); a barra já detectava o delta e só faltava soar.
> Ancorar aqui — e não em quem paga — faz TODA fonte de ouro
> (cash out, pular loja, evento, venda) celebrar no mesmo lugar:
> o cofre. É a "moeda sendo resgatada" chegando ao destino.

## L98-109 (em `self._goldFlash`, junto a `function TopBar:flashGold(dir)`)

> Toca o som do cofre e sobe o número no bloco de ouro.
>
> Dosagem deliberada (o dono pediu "efeitos sutis"): o pitch sobe com o
> tamanho do ganho, mas satura — 3 de ouro e 40 de ouro soam diferentes sem
> que 40 vire festa. Gasto NÃO ganha som próprio: quem gastou (compra,
> reroll, forja) já toca o seu, e dobrar viraria eco.
>
> O FloatingText é global (atualizado/desenhado em main.lua:1333/1462), então
> funciona em QUALQUER estado — inclusive por cima da loja e do cash out.
> Pisca o NÚMERO do ouro na direção dada (+1 ganho, -1 gasto/recusa) sem
> que o valor mude — a loja usa quando o jogador tenta comprar sem ouro
> (Loja v3: etiqueta treme, cofre pisca, nada de toast).

## L127-134 (em `TopBar:_onGoldDelta`, junto a `if delta > 0 then`)

> Ganho de ouro chove moedas até o contador. Mora AQUI, e não nas telas,
> porque este é o funil por onde todo delta passa — ligar tela por tela
> deixaria a próxima fonte de ouro sem animação e ninguém perceberia
> (era o caso do "Continuar" da loja). Ver src/ui/CoinBurst.lua.
>
> Vem ANTES do FloatingText de propósito: os dois são independentes, e
> pendurar as moedas depois do early-return dele faria uma falha no texto
> levar a animação junto, calada.

## L144-146 (em `TopBar:_onGoldDelta`, junto a `FloatingText.spawn(sign .. delta, alvoX, self.height - 6, {`)

> kind "gold" já existe no catálogo do FloatingText (dourado, 14px); só o
> gasto sobrescreve a cor, pra manter a mesma leitura verde/vermelho do
> flash direcional que roda logo acima.

## L154-160 (em `TopBar:_onGoldDelta`, junto a `function TopBar:_layout()`)

> Layout CENTRALIZADO da barra: o tubo CRT distorce os cantos em telas
> largas — todo o conteúdo (ouro/deck/score/progresso/engrenagem) vive num
> grupo central, onde o vidro é plano e legível (pedido playtest Jul/2026).
> FONTE ÚNICA de posições: draw, hover zones e mousepressed leem daqui.
>
> Larguras MEDIDAS pelos textos do locale atual com números-modelo largos:
> nenhum idioma estoura o bloco e o layout não "dança" quando o valor muda.

## L165-166 (em `TopBar:_layout`, junto a `local ICON_W = 50`)

> 50 = offset REAL onde o texto é desenhado nos blocos (x+50 no draw) —
> com 36 o texto invadia ~14px do gap do bloco vizinho.

## L214-216 (em `out`, junto a `function TopBar:_hoverZone(x0, w, tipName, ctx)`)

> Zona interativa da barra: highlight dourado sutil no hover + tooltip via
> StatusTooltip (show() agenda; main.lua desenha no fim do frame, por cima).
> Chamar ANTES de desenhar o conteúdo do bloco (o highlight fica por baixo).

## L241-243 (em `TopBar:draw`, junto a `PixelCanvas.rect(0, 0, screenWidth, self.height, { 0.07, 0.055, 0.04, 0.98 })`)

> Fundo pixel: ink fill + borda dourada dupla
> Fundo mais ESCURO que PANEL_FILL: sob o CRT (scanlines+vinheta) o
> dourado precisa de mais contraste (feedback: "difícil de enxergar").

## L277-279 (em `TopBar:drawGameInfo`, junto a `local rm = _G.gameSettings and _G.gameSettings.reducedMotion`)

> Ambient pulse Balatro-style (engine/text.lua:228 pulse pattern):
> ícone ondula scale ±3% em sin lento (0.7 rad/s) pra não ficar estático.
> Reduced motion zera a oscilação.

## L287-288 (em `TopBar:drawGameInfo`, junto a `local base = Palette.AGED_GOLD_LIGHT`)

> Cor do número: flash direcional (verde subiu / vermelho desceu)
> decaindo de volta pro dourado — padrão TopPanel do StS.

## L303 (em `TopBar:drawGameInfo`, junto a `local goldDisp = math.floor((self.disp.gold or self.game.economySystem.currentGold or 0) + 0.001)`)

> Display eased pra counter Balatro-style (sobe/desce número suave)

## L344-346 (em `TopBar:drawGameInfo`, junto a `if self.game and self.game.scoreSystem and L.score then`)

> Score da run (F3 gameplay-overhaul): TINTA×SELO acumulado, sempre
> visível — o "quero bater meu recorde" do Balatro. Vira dourado pulsante
> pelo resto da run quando o recorde histórico é cruzado.

## L379-380 (em `TopBar:drawGameInfo`, junto a `local run = self.game and self.game.runManager`)

> Progresso da run: "ATO N" + "andar X/8" (StS TopPanel: onde estou e o
> que vem por aí SEMPRE visíveis). Some fora do run mode (modo clássico).

## L421-422 (em `TopBar:drawGameInfo`, junto a `function TopBar:_navTargets()`)

> Alvo do foco de teclado/pad (src/ui/NavCursor): a engrenagem — o MESMO
> retângulo do hit-test do clique (mousepressed).

## L424-425 (em `TopBar:_navTargets`, junto a `local NavCursor = require("src.ui.NavCursor")`)

> (ouro/deck/pontos/roteiro registram no _hoverZone: o MESMO bloco do
> clique e da dica)

## L433-435 (em `TopBar:_getConfigRect`, junto a `local configX = love.graphics.getWidth() - iconPxSize - 30`)

> Engrenagem FIXA no canto direito (pedido do dono Jul/2026). Margem de
> 30px: bezel do CRT come 20px e a placa de hover cresce +5px além do
> ícone — assim nada fica atrás do gabinete.

## L447-448 (em `TopBar:drawConfigIcon`, junto a `if hover > 0.02 then`)

> Placa de hover FIXA (fora da rotação — só a engrenagem gira):
> rounded plate dourada + aro claro, ambos com fade pelo hover suave.

## L467-469 (em `TopBar:drawConfigIcon`, junto a `local drawSize = iconPxSize * (1 + 0.12 * hover)`)

> Só a ENGRENAGEM roda (e cresce um tico no hover). Escala pelo
> tamanho REAL do handle (PNG 64×64 do PixelLab ou matriz 16×16
> fallback — o hard-code de 16 estouraria o PNG pra 128px).

## L482-483 (em `TopBar:setDeckClickCallback`, junto a `function TopBar:setActClickCallback(cb) self.onActClick = cb end`)

> Clique no indicador de ATO abre o ROTEIRO da run (mesmo molde do deck →
> DeckViewer e do quadro de coringas → Gerenciador).

## L490-492 (em `TopBar:mousepressed`, junto a `if _G.togglePauseMenu then`)

> Engrenagem abre o MENU DE PAUSA (StS-style: continuar /
> configurações / salvar e sair / abandonar). Fallback legado:
> toggleMenu do game (settings direto) se o pause não existir.

