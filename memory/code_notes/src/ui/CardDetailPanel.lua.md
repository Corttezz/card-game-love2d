---
name: code_notes/src/ui/CardDetailPanel.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CardDetailPanel.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CardDetailPanel.lua`

Origem: `src/ui/CardDetailPanel.lua` em `7dbdb60d` (27 de 40 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-43 (junto a `local CardDetailPanel = {}`)

> src/ui/CardDetailPanel.lua
> Painel de DETALHE FIXO de uma oferta (carta / voucher / booster pack).
>
> Nasceu do redesign split-view da LOJA DE RELÍQUIAS (Jul/2026, pedido do
> dono: "não está muito boa a visualização das cartas"). O problema antigo era
> que a informação real da oferta só existia em painéis FLUTUANTES que
> saltavam de posição (CardRewardScreen._drawHoverInfoPanels) — o jogador
> tinha que varrer o mouse pra entender o que estava comprando.
>
> Aqui a leitura é ESTÁVEL: uma âncora que nunca muda de lugar, só de
> conteúdo. Grid compacto à esquerda decide, este painel à direita explica.
>
> Gramática visual: a MESMA do CardInspectModal (carta grande com warp 3D do
> CardMesh + coluna de meta/stats/descrição/efeitos). A duplicação com o
> CardInspectModal é consciente: aquele arquivo é o modal FULLSCREEN da
> Coleção/Deck Viewer (geometria própria, setas de navegação, backdrop) e
> estava sendo editado por outra frente — extrair de lá seria mexer em
> território alheio. Se um dia os dois convergirem, o modal deve passar a
> chamar CardDetailPanel.draw() com o retângulo dele.
>
> Uso:
> local rect = { x = ..., y = ..., w = ..., h = ... }
> CardDetailPanel.draw(rect, payload, opts)
>
> payload = nil                                   -- estado neutro
> | { kind = "card",    offer = o, instance = inst }
> | { kind = "voucher", offer = o }
> | { kind = "pack",    offer = o }
>
> opts = {
> alpha     = 0..1,    -- fade do conteúdo (default 1)
> stale     = bool,    -- é a ÚLTIMA carta olhada (nada em hover agora)
> footerH   = number,  -- altura reservada no rodapé (botões do caller)
> emptyHint = string,  -- texto do estado neutro
> staleHint = string,  -- rodapé discreto quando stale
> chrome    = bool,    -- desenha o painel de fundo (default true)
> parchment = bool,    -- tinta sobre papel (pergaminho da Loja v3)
> artMaxH   = number,  -- teto da altura da arte (pergaminho curto)
> priceOnButton = bool, -- o preço está no botão de compra: some da legenda
> objectArt = fn(payload, x, y, w, h, alpha) -> bool  -- desenha a arte de
> relíquia/pacote no lugar da composição padrão (Loja v3c: o
> pergaminho mostra o MESMO sprite da mesa); false = padrão
> }

## L57-60 (em `CardDetailPanel`, junto a `local DARK_PAL = {`)

> PALETAS. O painel nasceu como coluna escura (texto claro). Na Loja v3 ele
> vira o PERGAMINHO de inspeção pendurado no prego: tinta sobre papel. Em vez
> de duplicar o desenho, as cores saem de uma tabela escolhida por
> opts.parchment (ver ShopScene._drawScroll).

## L98-99 (em `reducedMotion`, junto a `local function fontTier(w)`)

> Escalonamento de fonte por largura do painel: o mesmo módulo serve uma
> coluna de 240px (janela pequena) e uma de 380px (fullscreen).

## L109-112 (em `fontTier`, junto a `local function fitFont(strings, maxW, from, to)`)

> Maior tamanho de fonte (descendo de `from` até `to`) em que TODAS as strings
> cabem em maxW. Existe porque os rótulos vêm do i18n: "Dano: 12" cabe, o
> "Verteid.: 10" do alemão não — e um printf que não cabe QUEBRA A LINHA,
> jogando o número por cima do texto de baixo (defeito visto em de_DE).

## L134-136 (em `divider`, junto a `local function drawCardArt(inst, ax, ay, aw, ah, alpha)`)

> ============================================================================
> ARTE (topo do painel)
> ============================================================================

## L138-139 (em `divider`, junto a `local function drawCardArt(inst, ax, ay, aw, ah, alpha)`)

> Carta grande com warp 3D seguindo o mouse (mesma linguagem da inspeção).
> Com reducedMotion o warp e a sombra dinâmica ficam em repouso.

## L144-145 (em `drawCardArt`, junto a `local okCF, CardFrame = pcall(require, "src.ui.CardFrame")`)

> Ícone animado (icons_anim/): carta visível = carta viva; a regra (e o
> reducedMotion) mora em CardFrame.displayImage (memory/card_icon_animation.md).

## L152-153 (em `drawCardArt`, junto a `local scale = math.min((aw - 28) / iw, (ah - 16) / ih)`)

> Margem própria: a carta NUNCA encosta nas bordas da coluna nem no bloco
> de texto. Encostada ela parecia espremida ("apertada contra o limite").

## L159-168 (em `drawCardArt`, junto a `local steps = 20`)

> VINHETA + CHÃO: a carta grande vira um objeto EM EXPOSIÇÃO em vez de um
> sprite colado no fundo. Halo quente que decai (nada de moldura — ela já
> tem borda). NÃO desenhamos sombra de contato aqui: o próprio Card:draw
> já projeta a sombra da carta (shDx/shDy abaixo), e a elipse somava uma
> SEGUNDA sombra — pedido do dono Set/2026: "tire a sombra circular, o
> componente da carta já tem sombra automaticamente".
> 20 passos (não 9): com poucos degraus o halo mostrava ANÉIS visíveis a
> 2×. Expoente 1.5 na queda pra a luz morrer suave e não virar um rim
> dourado colado na borda da carta (que já é dourada — isso reintroduziria
> a sensação de moldura dupla).

## L186-187 (em `drawCardArt`, junto a `local shDx = -uvx * 9`)

> Sombra projetada mais curta que antes: com a vinheta, um deslocamento
> grande virava uma "segunda carta" fantasma.

## L230-233 (em `drawPackArt`, junto a `local function drawVoucherArt(offer, ax, ay, aw, ah, alpha)`)

> Relíquia: MESMA composição do tile da vitrine (pedestal + halo na cor do
> efeito + sprite apoiado). Antes era só o PNG centrado no vazio — a peça
> flutuava no escuro e a coluna parecia inacabada ao lado da carta grande,
> que tem moldura e sombra. Uma composição só, dois lugares.

## L240-245 (em `drawVoucherArt`, junto a `animate = true,`)

> O PREVIEW TAMBEM ANIMA. Este painel e o lugar onde o jogador PARA
> pra decidir se compra — a peca maior e parada, ao lado do tile
> pequeno que se mexia, lia como se a grande tivesse travado.
> Pedido do dono (Set/2026). `time` compartilha o relogio com o tile,
> entao os dois ficam no MESMO frame da animacao: duas copias da
> mesma peca fora de fase na mesma tela seriam pior que nenhuma.

## L251-253 (em `drawVoucherArt`)

> ============================================================================
> TEXTO
> ============================================================================

## L255-259 (em `drawVoucherArt`, junto a `local function normalized(text)`)

> Quebra o texto em linhas reais: respeita "\n" explícito E o wrap por largura.
> Efeitos que a DESCRIÇÃO ainda não diz. Desde a auditoria carta a carta
> (descrição = efeito real nos 5 idiomas) a lista "Efeitos:" repetia, palavra
> por palavra, a frase logo acima ("Ganha 5 de Bloqueio" duas vezes) — ruído
> puro no painel da loja. Só sobra o que acrescenta informação.

## L287-293 (em `out`, junto a `local LINE_GAP = 6`)

> Escreve e devolve o novo cursor Y; para de desenhar ao passar do limite.
>
> ⚠️ NÃO usa printf multi-linha: o printf da LÖVE avança exatamente
> font:getHeight() por linha, ou seja ZERO entrelinha. Com a fonte pixel
> (Press Start 2P) isso encosta uma linha na outra e o texto parece
> sobreposto (defeito reportado no estado neutro do painel). Aqui cada linha
> é impressa individualmente com entrelinha explícita.

## L304-305 (em `line`, junto a `if ly + font:getHeight() > limit then return ly end`)

> v5: a linha inteira tem que caber (antes só o topo era conferido e a
> última linha podia invadir o botão)

## L323-325 (em `typeLabelFor`, junto a `function CardDetailPanel.draw(rect, payload, opts)`)

> ============================================================================
> DRAW
> ============================================================================

## L336-342 (em `CardDetailPanel.draw`, junto a `if opts.chrome ~= false then`)

> FUNDO, NÃO MOLDURA (correção Jul/2026 — "a carta expandida ficou muito
> feia, muito estranha"): o painel usava a moldura dourada canônica do
> UiPanel. Como a carta JÁ é um retângulo dourado ornamentado, os dois
> viravam um duplo enquadramento concêntrico, e o rodapé da carta
> ("DEFESA 5") encostava na borda externa parecendo erro.
> Agora: fundo escurecido + um único filete vertical separando da grade.
> A carta fica sozinha em campo, destacada pela sombra projetada dela.

## L360-364 (em `CardDetailPanel.draw`, junto a `if not payload or not payload.offer then`)

> ===== Estado neutro: rede de segurança =====
> Na prática a loja PRÉ-FOCA a primeira oferta ao abrir (ver
> CardRewardScreen:_prefocusDetail), então este estado só aparece em caso
> de borda — por exemplo tudo comprado. Mesmo assim ele fala, não fica um
> buraco preto: o texto é centralizado no eixo vertical do painel.

## L385 (em `CardDetailPanel.draw`, junto a `local desc = payload.kind == "card"`)

> ===== CONTEÚDO (resolvido ANTES de medir/desenhar) =====

## L398-400 (em `CardDetailPanel.draw`, junto a `local typeLabel = typeLabelFor(payload)`)

> Linha meta: TIPO · RARIDADE (· PREÇO). Loja v5: o preço já está no
> botão COMPRAR · $N logo abaixo e na plaquinha do objeto; repetir na
> legenda era a terceira cópia (opts.priceOnButton tira daqui).

## L427-431 (em `statParts`, junto a `local function linesH(text, font, w)`)

> ===== MEDIDA (Loja v5, briefing item 8: "o conteúdo não pode colidir
> com o botão, sair do painel ou exigir uma fonte minúscula"). Mede o
> bloco de texto com as MESMAS regras do desenho; quem cede primeiro é
> a ARTE (até 45% do teto), depois um degrau de fonte (nunca abaixo de
> 8 na descrição). O texto nunca é cortado no meio sem aviso.

## L464-465 (em `textBlockH`, junto a `local artCap = math.floor((h - footerH) * 0.60)`)

> Fração ADAPTATIVA da arte (com pouco texto a arte cresce), teto do
> pergaminho (opts.artMaxH) e piso de 45% do teto.

## L572 (em `tiers`, junto a `cy = line(desc, FontManager.getFont(F.desc), PAL.body, textX, cy, textW, bottom, alpha)`)

> ===== Descrição (o corpo: as regras) =====

## L594 (em `tiers`, junto a `if affinityTxt then`)

> ===== Afinidade: POR QUE esta oferta apareceu =====

## L600-601 (em `tiers`, junto a `if opts.stale and opts.staleHint then`)

> Rodapé discreto de contexto (pré-foco / última observada), ancorado no
> pé do painel; só se couber sem encostar no texto.

## L617 (em `tiers`, junto a `return { fits = fits and cy <= bottom + 1, contentBottom = cy, bottom = bottom, artH = artH,`)

> devolve a medida (test_shop_scene confere que nada sai do painel)

