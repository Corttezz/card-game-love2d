---
name: code_notes/tools/test_upgrade_tile.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_upgrade_tile.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_upgrade_tile.lua`

Origem: `tools/test_upgrade_tile.lua` em `7dbdb60d` (24 de 35 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-36 (junto a `local TK = require("tools.testkit")`)

> tools/test_upgrade_tile.lua
> Trava do tile de RELIQUIA da loja (src/ui/UpgradeTile.lua) em tres frentes.
>
> 1) GEOMETRIA POR CONSTRUCAO (memory/ui_layout_invariants.md, secao 1)
> As bandas nome/arte/efeito nao podem se sobrepor nem escapar do
> tile em NENHUM tamanho -- e a MOEDA de preco, que e overlay carimbado
> na moldura, nao pode passar por cima do nome -- nem no slot largo de 1920x1080 nem no aperto
> de 800x600. O defeito de origem desta familia (PackChoiceLayout) foi
> exatamente dois elementos ancorados no mesmo Y sem saber um do outro.
>
> 2) RESIZE (secao 2 -- "nascer grande != crescer")
> A loja NASCE num tamanho e a janela MUDA com ela aberta. A janela e
> FALSIFICADA (monkey-patch em love.graphics.getWidth/getHeight) porque
> love.window.setMode repetido dentro de um tool nao retorna. O caminho
> imitado e o do jogo (main.lua:love.resize): limpa FontManager/CardFrame
> e chama updateLayout().
>
> 3) I18N (memory/i18n_discipline.md)
> As quatro camadas de texto da reliquia (name/effect/desc/flavor) tem que
> existir nos 5 locales -- e o chip precisa interpolar {value}. A vitrine
> ja mostrou "Reliquia" em PT no meio de uma tela em alemao porque a chave
> so existia como fallback no codigo; isto impede a reincidencia.
>
> 4) SOM DE HOVER DO SLOT — mudou de dono na Loja v3 (ShopScene); a trava
> vive em tools/test_shop_scene.lua.
>
> 5) SPRITE ANIMADO COM FALLBACK
> O tile consome assets/sprites_anim opcionais (vouchers_anim/<id>/
> frame_NNN.png). A faixa de animacao pode nao existir -- e o codigo tem
> que funcionar NOS DOIS ESTADOS. O teste exercita os dois de verdade:
> escreve uma pasta de frames falsa no save dir (que o love.filesystem
> monta por cima do source) e confere que o handle aparece; depois remove
> e confere que volta pro PNG estatico sem erro nenhum.
>
> love . test_one test_upgrade_tile
> love . test_all

## L69-71 (em `pump`, junto a `local function resizeTo(screen, w, h)`)

> O que o jogo REALMENTE faz no love.resize (main.lua). Espelhar isso importa:
> um teste que limpa menos que o jogo acusa bug inexistente; que limpa mais,
> deixa passar um que existe.

## L91-93 (em `M.run`, junto a `local RECTS = {`)

> ======================================================================
> 1. Geometria pura
> ======================================================================

## L99 (em `RECTS`, junto a `{ 0, 0, 64, 60 },`)

> degenerado: ainda nao pode quebrar

## L107 (em `RECTS`, junto a `local bad = UpgradeTile.validate(r[1], r[2], r[3], r[4])`)

> Sem custo conhecido: reserva o pior caso; tambem tem que fechar.

## L113 (em `RECTS`, junto a `local tiny = UpgradeTile.layout(0, 0, 64, 60, 5)`)

> Bandas obrigatorias existem SEMPRE; o efeito e o unico que pode cair.

## L130-133 (em `RECTS`, junto a `t:falsy("preco nao e mais uma banda empilhada", roomy.price ~= nil)`)

> O PRECO nao ocupa banda nenhuma: e moeda carimbada na moldura. A regra
> que substituiu a antiga "placa de preco embaixo da placa de efeito" --
> precisa continuar valendo pra nao voltar a empilhar dois retangulos
> iguais (o defeito "cara de IA" de Set/2026).

## L141-143 (em `RECTS`, junto a `t:truthy("moeda de 2 digitos e maior que a de 1",`)

> Moeda maior pra numero maior: e o que garante que o preco continua
> LEGIVEL. Com raio fixo, "$25" desabava pro minimo da fonte e virava dois
> pontinhos no disco (visto na captura antes da correcao).

## L149-151 (em `RECTS`, junto a `local locales = I18n.getAvailable()`)

> ======================================================================
> 2. i18n das quatro camadas, nos 5 locales
> ======================================================================

## L179 (em `RECTS`, junto a `t:falsy("id desconhecido nao inventa chip",`)

> Oferta sem chave de efeito: o chip some, mas nada quebra.

## L183 (em `RECTS`, junto a `local a = UpgradeTile.theme({ effect = "increase_max_health" })`)

> Tema por EFEITO (data-driven), nunca por nome.

## L191-197 (em `RECTS`)

> ======================================================================
> 3. Som do hover no slot nao-carta (reliquia / pacote)
> ======================================================================
> Loja v3 (Out/2026): a reliquia virou um OBJETO na prateleira
> (src/ui/shop/ShelfItem) e o hover — som UMA vez na borda de entrada, no
> volume do registro, nunca durante o deslize — e do ShopScene. A trava
> mora em tools/test_shop_scene.lua (secao 2).

## L199-205 (em `RECTS`, junto a `do`)

> ======================================================================
> 4. Sprite animado do voucher: anima quando ha faixa, estatico quando nao
> ======================================================================
> A pasta de animacao e escrita no SAVE DIR: o love.filesystem procura ali
> antes do source, entao o loader enxerga como se o asset existisse no
> projeto -- sem sujar o repo e sem depender de arte que pode nao ter sido
> gerada ainda.

## L216-218 (em `RECTS`, junto a `for _, id in ipairs(UPGRADE_IDS) do`)

> Oferta REAL: com ou sem faixa de animacao gerada, SEMPRE sai imagem.
> Os dois estados sao validos e o teste nao exige nenhum dos dois --
> so que a escolha seja coerente com o que existe no disco.

## L252-254 (em `RECTS`, junto a `local idle, idleAnimated = UpgradeTile.spriteFor(FAKE, false, 0)`)

> IDLE e ESTATICO (regra do projeto): sem interacao, nem consulta a
> faixa. Aqui nao ha PNG estatico, entao cai no frame 0 -- que e o
> comportamento desejado: parado, nunca buraco.

## L276-278 (em `RECTS`, junto a `t:noerror("clearCache no meio do uso nao quebra o proximo draw", function()`)

> A placa gravada e cacheada como bitmap: o cache tem que aceitar ser
> zerado a qualquer momento (e o que o resize da loja faz) sem quebrar o
> desenho seguinte.

## L287-289 (em `RECTS`, junto a `installFakeWindow()`)

> ======================================================================
> 5. Resize da loja com a reliquia na vitrine
> ======================================================================

## L300 (em `RECTS`, junto a `local voucher`)

> Garante uma RELIQUIA na vitrine (o roll e 50/50 entre forja e pool).

## L320-321 (em `RECTS`, junto a `if voucher then`)

> E com uma oferta SELECIONADA (o estado com mais geometria derivada:
> botoes de compra ancorados no rodape do painel de detalhe).

## L333-335 (em `RECTS`, junto a `screen:clearSelection()`)

> Loja em TELA CHEIA (Out/2026): as zonas sem moldura continuam
> separadas em todo tamanho E em todo idioma — o rodape mede o rotulo
> dos botoes no locale atual (alemao e o mais longo em varias telas).

## L356-357 (em `RECTS`, junto a `if voucher then`)

> O tile e desenhavel em qualquer tamanho (o draw le as MESMAS bandas
> que o validate; um erro de nil aqui seria crash na loja real).

## L373-378 (em `RECTS`, junto a `do`)

> ===== ANIMACAO DA RELIQUIA: SEMPRE, nao so no hover =====
> Pedido do dono (Set/2026): "na loja, a aba de upgrade, o preview dos
> itens na direita precisa ter a animacao tambem; a animacao deles nao
> precisa ser so no hover". Excecao deliberada a regra dos icones de
> carta (que so animam na interacao) — la sao dezenas na tela, aqui sao
> 1 a 3 objetos numa prateleira.

## L390 (em `RECTS`, junto a `local a = UT.spriteFor(comAnim, true, 0.0)`)

> Em tempos diferentes o frame tem que MUDAR sem hover nenhum.

## L403 (em `RECTS`, junto a `t:noerror("voucher sem animacao nao estoura ao animar", function()`)

> Sem pasta de animacao, animar nao pode quebrar: cai no estatico.

