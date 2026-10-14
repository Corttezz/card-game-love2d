---
name: code_notes/src/ui/UpgradeTile.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/UpgradeTile.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/UpgradeTile.lua`

Origem: `src/ui/UpgradeTile.lua` em `7dbdb60d` (32 de 40 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-37 (junto a `local Palette       = require("src.ui.Palette")`)

> src/ui/UpgradeTile.lua
> Vitrine de UPGRADE (voucher) da loja: forja, vida maxima, mana maxima.
>
> POR QUE ESTE MODULO EXISTE
> O upgrade era desenhado como "o else" do slot de oferta: um retangulo
> PANEL_FILL (a MESMA cor do fundo da grade), o sprite flutuando no vazio,
> o nome miudo, uma tarja verde de 3px no topo e o preco como texto solto.
> No tile compacto do split-view a descricao era DESCARTADA, entao o item nao
> dizia o que fazia: o jogador via "Forja $5" e precisava passar o mouse pra
> descobrir o resto.
>
> Aqui ele vira um OBJETO na prateleira: placa iluminada (mais clara que o
> fundo, entao existe), relicario com halo na cor do efeito, PLACA GRAVADA com
> o efeito e MOEDA cunhada com o preco.
>
> REVISAO Set/2026 ("cara de IA"): a versao anterior mostrava o efeito e o
> preco como dois retangulos empilhados de cantos arredondados anti-aliasados,
> moldura de 1px simetrica e texto centrado -- vocabulario de formulario web,
> nao de grimorio, e diferente do que a CARTA ao lado ja fazia (moeda no canto
> superior direito). As duas placas foram substituidas pela gramatica unica de
> src/ui/ShopEngraving.lua, que carta, pacote e reliquia agora compartilham.
> Repare que o tile PERDEU uma banda: o preco nao ocupa mais linha nenhuma, e
> a sobra foi pra arte.
>
> LAYOUT POR ZONAS (memory/ui_layout_invariants.md, secao 1)
> layout() e uma funcao PURA que fatia o retangulo do slot em bandas
> empilhadas -- nome / arte / efeito -- mais o rect da MOEDA, que e overlay
> carimbado na moldura (como o custo de mana na carta) e por isso tem regra
> propria: nunca invade a coluna do nome. Nenhum elemento e ancorado no
> vizinho: quando falta altura, quem cede e a ESCALA do conteudo, e as bandas
> opcionais CAEM em ordem de prioridade declarada. validate() prova isso
> geometricamente e roda nos testes.
>
> RESIZE: este modulo nao guarda estado geometrico -- as bandas sao derivadas
> do retangulo a cada frame. O unico cache e o de bitmaps da placa gravada,
> que vive no ShopEngraving e e limpo por ShopEngraving.clearCache() no
> resize da loja (secao 2).

## L51-52 (em `UpgradeTile`, junto a `local function reducedMotion()`)

> Acessibilidade: reducedMotion remove MOVIMENTO, nunca INFORMACAO
> (ui_layout_invariants, secao 3). Halo, placa e destaque de hover continuam.

## L63-70 (em `setC`, junto a `local VOUCHER_STATIC = "assets/sprites/vouchers/"`)

> ============================================================================
> SPRITE: estatico por padrao, animado na INTERACAO
> ============================================================================
> Mesmo contrato dos icones de carta (memory/card_icon_animation.md):
> assets/sprites/vouchers_anim/<offer_id>/frame_NNN.png (+ meta.lua {fps})
> Pasta ausente = o tile usa o PNG estatico de assets/sprites/vouchers/. Os
> dois estados sao normais e nenhum quebra -- a faixa de animacao e um upgrade
> opcional do asset, nao um requisito do codigo.

## L78-80 (em `animWarned`, junto a `function UpgradeTile.animationFor(offerId)`)

> Handle de animacao do voucher, ou nil. AVISA uma vez se a pasta existe mas
> nao rendeu frame nenhum -- fallback silencioso e proibido (secao 3): uma
> pasta com PNG de nome errado degradaria pra estatico sem rastro nenhum.

## L96-97 (em `UpgradeTile.staticSprite`, junto a `return ImageCache.tryGet(VOUCHER_STATIC .. tostring(offerId) .. ".png")`)

> tryGet: miss = nil (o get() devolvia o placeholder theRock e o voucher
> sem arte mostrava uma carta no lugar).

## L101-104 (em `UpgradeTile.staticSprite`, junto a `function UpgradeTile.spriteFor(offerId, animate, t)`)

> A imagem a desenhar neste frame. `animate` liga o loop (as reliquias animam
> SEMPRE — ver a nota na banda de arte; o parametro segue existindo pra quem
> em foco no painel de detalhe) -- idle e estatico, regra do projeto: o que
> se move na prateleira e o que o jogador esta olhando.

## L113-114 (em `UpgradeTile.spriteFor`, junto a `local img = UpgradeTile.staticSprite(offerId)`)

> Frame 0 do set animado tambem serve de estatico (se a pasta existe mas
> o PNG solto nao). Ordem: estatico -> frame 0 -> nil.

## L120-123 (em `UpgradeTile.spriteFor`, junto a `local THEMES = {`)

> ============================================================================
> TEMA POR EFEITO (data-driven: chaveado pelo `effect`, nunca pelo nome --
> convencao do projeto contra condicional por card.name)
> ============================================================================

## L131-132 (em `DEFAULT_THEME`, junto a `function UpgradeTile.theme(offer)`)

> accent = cromo (filete da placa gravada, halo); text = cor do efeito quando
> ele aparece FORA da placa (popup de compra, etiqueta de categoria).

## L143-145 (em `UpgradeTile.theme`, junto a `function UpgradeTile.effectLabel(offer)`)

> Texto curto do efeito ("+10 VIDA MAX"). Vive no i18n como
> shop_items.<id>.effect; sem chave, devolve nil e a banda da placa nao e
> desenhada (o painel de detalhe continua explicando o item por extenso).

## L162-170 (em `UpgradeTile.flavor`, junto a `local ART_MIN = 44   -- piso da arte antes de derrubar banda opcional`)

> ============================================================================
> LAYOUT (puro)
> ============================================================================
> Bandas empilhadas, de cima pra baixo:
> name   (obrigatoria)  nome da reliquia -- largura DESCONTADA da moeda
> art    (obrigatoria)  halo + sombra de contato + sprite
> effect (opcional)     placa gravada com o efeito
> Overlay:
> seal   (quando ha preco)  moeda cunhada no canto superior direito

## L171 (em `UpgradeTile.flavor`, junto a `local ART_MIN = 44`)

> piso da arte antes de derrubar banda opcional

## L173-175 (em `UpgradeTile.flavor`, junto a `function UpgradeTile.layout(x, y, w, h, cost)`)

> `cost` e opcional: a moeda cresce com o numero de digitos, entao quem sabe o
> preco reserva o espaco EXATO e o nome fica com o resto. Sem ele, reserva-se
> o pior caso (3 digitos) -- a coluna do nome nunca pode ficar devendo.

## L186-187 (em `UpgradeTile.layout`, junto a `local function artOf(useEffect)`)

> Altura da arte = sobra. A banda opcional cai enquanto a arte nao alcanca
> o piso -- nunca por "ajuste fino" no call site.

## L207-209 (em `inner`, junto a `local nameW = math.max(12, seal.x - 2 - ix)`)

> A moeda tem prioridade na coluna da direita: o nome cede largura. Sem
> isso, um nome longo passaria POR BAIXO do disco (o defeito classico de
> dois elementos ancorados no mesmo canto sem saber um do outro).

## L221-222 (em `bands.effect`, junto a `function UpgradeTile.validate(x, y, w, h, cost)`)

> Violacoes geometricas (lista vazia = OK). Mesmo contrato do
> PackChoiceLayout.validate: o teste que layout por acumulacao nunca tem.

## L247 (em `prev`, junto a `local s = b.seal`)

> A moeda e overlay, mas nao pode sair do tile nem morder o nome.

## L259-271 (em `prev`, junto a `function UpgradeTile.drawArt(offer, rect, opts)`)

> ============================================================================
> ARTE DA RELIQUIA (compartilhada com o painel de detalhe)
> ============================================================================
> Halo + sombra de contato + sprite, centrados no rect.
>
> NAO desenha pedestal. A primeira versao punha uma laje sob a peca e foi
> removida olhando os PNGs: o cristal de mana JA vem com base de pedra na
> arte e a bigorna JA tem pe -- a laje virava um segundo pedestal empilhado
> no primeiro (o anti-pattern "somar camada sobre arte que ja tem",
> ui_layout_invariants secao 4). O que faltava era CHAO, nao mobilia: uma
> sombra de contato e um halo quente resolvem, sem cobrir nada.
> opts.alpha, opts.glow (0..1), opts.bob (px), opts.theme,
> opts.animate (bool), opts.time

## L290-293 (em `UpgradeTile.drawArt`, junto a `scale = (raw >= 1) and (math.floor(raw * 4) / 4) or raw`)

> Escala em passos de 1/4. Inteiro puro era luxo caro aqui: com
> sprite de 64px e banda de ~120, floor() joga tudo pra 1x e a peca
> encolhia pra metade da banda. Um quarto de passo mantem a malha
> previsivel e ainda preenche -- o jogo ja desenha carta em 1.333.

## L312-313 (em `UpgradeTile.drawArt`, junto a `setC(Palette.INK, alpha * 0.5 * (1 - math.min(0.7, lift / 12)))`)

> Sombra de contato: encolhe conforme a reliquia sobe (a sombra conta
> a altura -- sem ela o bob lia como o sprite "escorregando").

## L321 (em `UpgradeTile.drawArt`, junto a `local r = math.floor(math.min(rect.w, math.max(8, availH)) * 0.28)`)

> Sem PNG: selo ornamental (nunca um buraco).

## L332-333 (em `UpgradeTile.drawArt`, junto a `local function drawEmbers(rect, th, t, k, alpha)`)

> Brasas subindo do chao no hover. Deterministicas (senoide por indice):
> captura de tela vira reproduzivel e o RNG da run nao e gasto com cosmetico.

## L348-356 (em `drawEmbers`, junto a `function UpgradeTile.draw(offer, rect, state)`)

> ============================================================================
> DRAW
> ============================================================================
> state = {
> hover  = 0..1  (hover ja interpolado por quem e dono do tile)
> afford = bool
> time   = love.timer.getTime()
> alpha  = 0..1
> }

## L368-370 (em `UpgradeTile.draw`, junto a `local borderColor = afford and Palette.AGED_GOLD or Palette.BLOOD`)

> Foco clareia a moldura, MAS dentro da propria cor de estado: um tile
> impagavel em hover clareando pra dourado apagava justamente o aviso de
> "voce nao tem ouro" no momento em que o jogador esta olhando pra ele.

## L378-379 (em `UpgradeTile.draw`, junto a `local shade = afford and 1 or 0.55`)

> Impagavel = tile ESCURECIDO, alem do preco vermelho. Mesma regra das
> cartas (Card.saleDim): nunca comunicar so pela cor do numero.

## L383-385 (em `UpgradeTile.draw`, junto a `local R = 3   -- canto CORTADO (degraus), nao arredondado por vetor: a`)

> ===== Placa =====
> Sombra projetada: o tile e um OBJETO na prateleira, nao um recorte no
> fundo (o retangulo PANEL_FILL antigo tinha a cor do proprio fundo).

## L398-400 (em `UpgradeTile.draw`, junto a `local gx, gy = f.x + 2, f.y + 2`)

> Luz de cima pra baixo em LINHAS INTEIRAS de pixel (inset 2px, pra base
> arredondada seguir aparecendo na borda). O degrade de 8 faixas da versao
> anterior deixava emendas horizontais visiveis no meio da placa.

## L408-411 (em `UpgradeTile.draw`, junto a `PixelCanvas.rectRoundedOutline(f.x, f.y, f.w, f.h, R,`)

> Moldura: bevel direcional (luz no topo, sombra na base) + cunhas de
> canto -- o mesmo vocabulario do rodape da carta. A moldura dupla
> perfeitamente simetrica com quatro rebites 2x2 identicos saiu: simetria
> de maquina e exatamente o que le como gerado.

## L426-427 (em `UpgradeTile.draw`, junto a `local font, txt = TextFit.fit(name, size, b.name.w - 12)`)

> 12: margem real dos dois lados (com -4 um nome longo era reduzido
> ate encostar na moldura).

## L446-458 (em `UpgradeTile.draw`, junto a `animate = state.animate ~= false,`)

> RELIQUIA ANIMA SEMPRE — excecao deliberada a regra dos icones de
> carta ("idle estatico, anima na interacao").
>
> Por que a excecao: a regra existe pra mao e pro grid de colecao,
> onde DEZENAS de cartas dividem a tela e animar todas viraria um
> formigueiro — a animacao ali serve pra dizer "esta e a carta sob o
> mouse". Na loja sao 1 a 3 reliquias, cada uma um OBJETO numa
> prateleira, e a peca parada ao lado de cartas que respiram lia como
> imagem quebrada. Pedido explicito do dono (Set/2026): "a animacao
> delas nao precisa ser so no hover".
>
> `state.animate == false` ainda desliga (usado pelo teste e por
> qualquer chamador que queira o frame estatico).

## L477-479 (em `UpgradeTile.draw`, junto a `ShopEngraving.stampPrice(f, offer and offer.cost, {`)

> ===== PRECO: moeda cunhada na moldura =====
> Nao ocupa banda nenhuma: e carimbo sobre o objeto, como na carta ao
> lado. Foi a troca que fez a fileira inteira falar a mesma lingua.

## L487-488 (em `UpgradeTile.draw`, junto a `function UpgradeTile.scaleOf(fx)`)

> Escala viva do tile (entrada + kick de compra), pra quem desenha aplicar em
> torno do centro. Sem objeto de juice, devolve 1 / 0.

