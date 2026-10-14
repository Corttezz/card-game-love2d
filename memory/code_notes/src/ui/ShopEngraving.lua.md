---
name: code_notes/src/ui/ShopEngraving.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/ShopEngraving.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/ShopEngraving.lua`

Origem: `src/ui/ShopEngraving.lua` em `7dbdb60d` (27 de 33 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-33 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/ShopEngraving.lua
> A gramatica UNICA de "quanto custa" e "o que faz" na prateleira da loja.
>
> POR QUE ESTE MODULO EXISTE
> O dono olhou a loja e disse que o preco e o efeito estavam "com cara de IA"
> (Set/2026). Olhando as capturas, o diagnostico e concreto e tem tres partes:
>
> 1) DIALETO ERRADO. A carta ja mostrava o preco como MOEDA cunhada no canto
> superior direito -- disco de ouro com aro escuro, encostado na moldura.
> O pacote e o voucher, na MESMA fileira da MESMA tela, mostravam o preco
> como retangulo de 1px flutuando embaixo do objeto. Duas gramaticas pra
> mesma informacao a 40px de distancia: a segunda so podia ler como
> componente de template que caiu ali.
> 2) FORMA SUAVE EM TELA DE PIXEL. Os retangulos usavam cantos arredondados
> do love.graphics (vetor anti-aliasado) e o disco da carta usava
> love.graphics.circle -- tambem AA. Borda macia no meio de arte de borda
> dura e o tell mais rapido de "isso nao foi desenhado, foi gerado".
> 3) SUPERFICIE MORTA. Fundo chapado (ou degrade continuo), moldura de 1px
> perfeitamente simetrica, texto mecanicamente centrado. O resto do jogo
> ver src/ui/card/components/CardStatsFooter.lua -- da MATERIA a cada
> placa: bevel direcional (luz em cima/esquerda, sombra embaixo/direita),
> cunhas de canto, grao por hash e desgaste concentrado nas bordas.
>
> A correcao nao foi inventar forma nova: foi falar o dialeto que o jogo ja
> tem. `priceSeal` e a moeda da carta, agora desenhada em pixel (degraus) e em
> cores da Palette; `effectStrip` e a placa gravada do rodape da carta,
> parametrizada. Carta, pacote e reliquia passam pelas MESMAS duas funcoes.
>
> CACHE: a placa de efeito tem grao e desgaste por pixel -- caro demais por
> frame. Ela e rasterizada num canvas com chave (w|h|texto|accent|seed). A
> chave inclui as dimensoes, entao um resize nunca reaproveita bitmap velho;
> ainda assim `clearCache()` existe e e chamado no resize da loja, pra nao
> acumular canvas de tamanhos mortos (ui_layout_invariants, secao 2).

## L46-48 (em `withA`, junto a `local function seedOf(s)`)

> Hash estavel string -> inteiro. Usado pra que CADA item envelheca com o
> proprio padrao de desgaste, e sempre o mesmo entre re-renders (nada de
> random no draw -- captura de tela tem que ser reproduzivel).

## L58-68 (em `seedOf`, junto a `function ShopEngraving.sealRadius(objW, cost)`)

> ============================================================================
> MOEDA DE PRECO
> ============================================================================
> Raio proporcional ao objeto (um disco de tamanho fixo come a ilustracao no
> tile compacto e some no tile grande) E ao TAMANHO DO NUMERO.
>
> A segunda parte custou uma rodada: com raio fixo, "$25" so cabia encolhendo
> a fonte pro minimo, e o numero virava dois pontinhos ilegiveis no disco --
> o preco, que e a razao de a moeda existir, era a unica coisa que nao dava
> pra ler. Moeda de valor maior e MAIOR; e assim que moeda funciona.
> `cost` nil = reserva o pior caso (3 digitos), pra quem so precisa do espaco.

## L72-74 (em `ShopEngraving.sealRadius`, junto a `r = r + math.min(4, digits * 2)`)

> O "$" conta como digito: "$8" ja sao 2 glifos. Sem folga pra 1 digito
> o numero colava no aro e "$8" lia "$&" (relato da arte das reliquias,
> Out/2026). A reserva do layout (cost nil = 3 digitos) segue o teto.

## L79-80 (em `ShopEngraving.sealRadius`, junto a `function ShopEngraving.sealAnchor(rect, cost)`)

> Onde a moeda encosta, dado o retangulo do objeto: canto superior-direito,
> mordendo a moldura -- exatamente como na carta. Devolve cx, cy, r.

## L86-91 (em `ShopEngraving.sealAnchor`, junto a `function ShopEngraving.sealRect(rect, cost)`)

> Retangulo do CORPO da moeda (pro layout reservar espaco e pro validate).
> Deliberadamente NAO inclui a sombra projetada: a moeda descansa na quina e
> a sombra dela cai 2px pra fora do objeto, como na carta. O que nao pode
> vazar e o disco.
> Sem `cost`, devolve a reserva do pior caso -- e o que o layout quer: a
> coluna do nome nao pode depender de quanto o item custa hoje.

## L97-102 (em `ShopEngraving.sealRect`, junto a `function ShopEngraving.priceSeal(cx, cy, r, cost, opts)`)

> Moeda cunhada. opts = { afford = bool, alpha = 0..1, glow = 0..1 }
>
> Cinco camadas, todas em degraus: sombra projetada, aro de tinta, corpo com
> luz direcional (lerp POR LINHA, nunca shader), serrilha da borda e o numero
> gravado -- tinta escura com realce claro embaixo, que e como um relevo
> batido se le de verdade.

## L113-114 (em `ShopEngraving.priceSeal`, junto a `local glow = opts.glow or 0`)

> Halo: so no hover/destaque. Em repouso a moeda nao brilha -- metal velho
> nao emite luz, e o halo permanente era mais uma camada sobre a arte.

## L122-123 (em `ShopEngraving.priceSeal`, junto a `PixelCanvas.disc(cx, cy, r, withA(rim, alpha))`)

> Aro de 2px em tinta: e o que separa a moeda do fundo claro do pergaminho
> E do fundo escuro da placa. Com 1px ela sumia nos dois.

## L125-126 (em `ShopEngraving.priceSeal`, junto a `PixelCanvas.discShaded(cx, cy, r - 2,`)

> Corpo: ouro de verdade (nao creme). A primeira versao clareava 50% no
> topo e a moeda lia como disco bege sem material nenhum.

## L131-132 (em `ShopEngraving.priceSeal`, junto a `local milled = withA(Palette.lighten(body, 0.55), alpha * 0.8)`)

> Serrilha: 8 tiques no aro. E o detalhe que transforma "circulo dourado"
> em "moeda" -- e nao existe em nenhum componente de template.

## L139-146 (em `ShopEngraving.priceSeal`, junto a `local txt = "$" .. tostring(cost or 0)`)

> Numero GRAVADO: glifo em tinta com realce claro 1px abaixo-direita.
>
> O numero e a razao de a moeda existir: ele manda na moeda, nao o
> contrario. Passar por TextFit com a largura util do disco fazia "$25"
> desabar pro minimo de 8px e virar dois pontinhos ilegiveis (visto na
> captura, Set/2026). Aqui a fonte so desce um degrau, e o glifo pode
> invadir 1-2px do aro -- numero grande cunhado de borda a borda e
> exatamente como moeda antiga se le.

## L151-152 (em `ShopEngraving.priceSeal`, junto a `if size > 9 and font:getWidth(txt) > r * 2 - 6 then`)

> Folga de 6px: o glifo pode morder o aro, mas nao pode ser COMIDO por
> ele. "$25" em 11 media 29px num disco de 28 e as pontas sumiam.

## L177-183 (em `ShopEngraving.stampPrice`, junto a `local WEDGE = { 4, 2, 1 }`)

> ============================================================================
> PLACA GRAVADA DO EFEITO
> ============================================================================
> Mesmo vocabulario do rodape da carta (CardStatsFooter): bevel direcional,
> cunhas de canto, grao do material, desgaste nas bordas e um filete da cor do
> efeito que ATRAVESSA a placa e termina em ponta de lanca de cada lado,
> "apresentando" o texto. Nada de moldura de 1px simetrica.

## L185-186 (em `ShopEngraving.stampPrice`, junto a `local WEDGE = { 4, 2, 1 }`)

> Cunha de canto 4-2-1 (versao curta da do CardStatsFooter -- a placa do tile
> tem ~14px de altura, a da carta tem 20).

## L199-200 (em `drawCornerWedge`, junto a `local function drawStripeEnd(x, cy, accent, dir)`)

> Ponta de lanca que arremata o filete junto ao texto (dir = -1 aponta pra
> esquerda, 1 pra direita).

## L219-221 (em `RUST_TINT`, junto a `local function drawWear(w, h, seed)`)

> Desgaste: lascas de 2px deitadas concentradas nas bordas (onde a mao gasta
> a placa) e ferrugem so grudada na moldura. Centro quase intocado -- pixel
> solto no meio da chapa le como sujeira de render, nao como uso.

## L238 (em `drawWear`, junto a `local function renderStrip(w, h, text, accent, seed)`)

> Rasteriza a placa (w x h) num canvas. Chamado so no miss do cache.

## L243-244 (em `renderStrip`, junto a `local top = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.22)`)

> Chapa: lerp POR LINHA (o degrade que o projeto aceita). O degrade de 8
> faixas da versao anterior deixava emendas horizontais visiveis.

## L250-251 (em `renderStrip`, junto a `for y = 1, h - 2 do`)

> Grao do material: variacao densa e MUITO sutil por hash. E o que separa
> "superficie com materia" de "retangulo preenchido".

## L270-271 (em `renderStrip`, junto a `local bronze = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.45)`)

> Bevel direcional: luz em cima/esquerda, bronze embaixo/direita. Nunca
> moldura de tom unico -- e a diferenca entre "placa" e "borda de div".

## L311-317 (em `renderStrip`, junto a `local function renderValuePlate(w, h, label, value, accent, seed)`)

> ============================================================================
> CARTUCHO DE VALOR (rotulo pequeno + numero grande)
> ============================================================================
> Mesma chapa da placa de efeito, em duas linhas. Substitui os "chips" de
> CUSTO/DANO da tela de abertura de pacote, que eram retangulo preto a 45% com
> contorno de 1px na cor do tipo -- o mesmo dialeto de formulario que o dono
> reprovou na loja, na tela ao lado.

## L349-355 (em `renderValuePlate`, junto a `local function engrave(text, font, x, y, color)`)

> Rotulo pequeno em cima, filete do tipo embaixo dele, numero grande no
> resto. O filete separa sem precisar de uma segunda moldura.
> Texto GRAVADO na chapa: sombra de tinta 1px abaixo-direita, nunca
> contorno de 4 lados. Com o contorno, os vazios do "8" em 13px fechavam e
> o numero lia como "S" -- e o numero e a informacao inteira deste
> cartucho. Sobre chapa escura o contorno nem faz falta: o contraste ja
> esta la.

## L381-388 (em `engrave`, junto a `local function pixelDiamond(cx, cy, r, color)`)

> ============================================================================
> MARCADOR DE ETIQUETA (losango . TEXTO . losango)
> ============================================================================
> A loja ja etiquetava raridade e categoria assim ("* INCOMUM *"). A tela de
> abertura de pacote desenhava a MESMA informacao numa caixinha preta com
> contorno -- outra vez duas gramaticas pra mesma coisa. Aqui vira uma funcao
> so, e o losango passou a ser desenhado em degraus (o polygon do love e
> anti-aliasado; num rotulo de 5px isso vira um borrao).

## L428-430 (em `colorKey`, junto a `function ShopEngraving.effectStrip(x, y, w, h, text, opts)`)

> Placa de efeito. opts = { accent, alpha, dim (0..1), seed }
> O conteudo NAO reage ao hover de proposito: metal gravado nao acende. O
> destaque de foco mora na moldura do tile, no halo e no movimento da peca.

## L441-442 (em `ShopEngraving.effectStrip`, junto a `if stripCount > 96 then ShopEngraving.clearCache() end`)

> Teto de seguranca: se alguem chamar com texto variavel por frame,
> o cache zera em vez de comer VRAM em silencio.

## L451-452 (em `ShopEngraving.effectStrip`, junto a `love.graphics.setColor(0, 0, 0, 0.55 * a)`)

> Sombra de contato sob a placa (ela e um objeto parafusado, nao um
> recorte no fundo).

