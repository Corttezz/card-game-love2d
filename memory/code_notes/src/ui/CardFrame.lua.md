---
name: code_notes/src/ui/CardFrame.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CardFrame.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CardFrame.lua`

Origem: `src/ui/CardFrame.lua` em `7dbdb60d` (42 de 74 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local PixelCanvas      = require("src.ui.PixelCanvas")`)

> src/ui/CardFrame.lua
> Compositor de carta — estilo grimório inspirado em assets/cards/*.png.
> Fluxo:
> 1) Canvas = cor sólida de pergaminho
> 2) Texture PNG de papel envelhecido cobre toda a carta
> 3) Ilustração central direto no pergaminho (sem inner frame)
> 4) Borda ornamental + medalhões nos cantos + banner nome + footer + badges
>
> Dimensões: 96×144 lógicos (BASE_SCALE 1.333 → 128×192 na tela).

## L36-45 (em `CardFrame`, junto a `function CardFrame.showsManaCost(card)`)

> CORINGA NAO TEM CUSTO DE MANA. Ele e passivo: entra nos slots e nunca passa
> pela mao, entao o `cost` do dado e vestigial — mostrar o numero ensina uma
> regra que nao existe ("preciso de 2 de mana pra usar esse coringa?").
>
> Isto e uma PERGUNTA SOBRE A CARTA, nao sobre o desenho, e mora aqui porque
> ja foi corrigida tres vezes em lugares diferentes: no badge da arte
> (renderJoker), no tooltip (CardInfoDisplay) e — reportada pelo dono em
> Set/2026, "tem joker na hora de escolher que apresenta custo tbm" — no chip
> da escolha de pacote. Cada tela que mostra custo REPETIA o `if`, e a
> proxima tela ia repetir o defeito. Pergunte aqui.

## L50-75 (em `CardFrame.showsManaCost`, junto a `function CardFrame.liveEnabled()`)

> ============================================================================
> CARTA VISIVEL = CARTA VIVA (regra do dono, 13/Out/2026)
> ============================================================================
> "A todo momento as cartas que estao sendo exibidas na tela eu quero que
> elas fiquem com a animacao sendo mostrada. Elas nao podem estar estaticas
> em NENHUM tipo de visualizacao em nenhum local."
>
> Isto REVOGA a regra de Jul/2026 ("idle = estatico, interacao = vivo"), que
> morava aqui como `isInteracting`/`imageFor(card, hoverScale, hoverStrength)`.
> A animacao do icone agora aparece em TODA renderizacao de carta: mao,
> coringas ativos, espolios, loja (bancada e pergaminho), pacote, Colecao
> (grade e inspecao), Deck Viewer, Gerenciador de Coringas, cartas iniciais
> da classe, revelacoes de desbloqueio, pickers, cartas voando no combate.
>
> A UNICA excecao e `reducedMotion` (Configuracoes -> Jogo): a opcao remove
> MOVIMENTO, e o loop do icone e movimento. Com ela ligada a carta fica no
> frame 0, que e pixel a pixel a arte estatica — e hover/selecao NAO reabrem
> a animacao (seria movimento de novo). Informacao nunca e removida: o frame
> 0 e a ilustracao completa.
>
> A decisao mora SO aqui. Toda tela pergunta `CardFrame.displayImage(card)`
> (ver defect_doctrine 16: regra repetida em N telas volta na tela N+1 — foi
> assim que o Deck Viewer ficou sem animacao em Set/2026). `liveImage` e o
> mecanismo (monta e devolve o quadro corrente); `displayImage` e a REGRA.
> Trava: tools/test_cards_always_live.lua (nenhum arquivo de tela chama
> `liveImage` direto).

## L81-85 (em `CardFrame.liveEnabled`, junto a `function CardFrame.displayImage(card)`)

> A imagem que a carta deve desenhar AGORA: o quadro corrente da animacao
> quando ela existe (e o movimento esta ligado), a estatica caso contrario.
> Devolver `card.image` no fallback e de proposito — carta sem frames
> animados (ou com o set ainda montando) nunca deixa de desenhar: o
> estatico E o frame 0, entao nao ha salto visual quando o set termina.

## L96-101 (em `cache`, junto a `local animCache = {}`)

> Cartas com ícone animado (icons_anim/): key → { canvases = {...}, fps,
> lastReq }. `canvases` = a carta COMPLETA pré-renderizada uma vez por frame
> do ícone; `liveImage` devolve o canvas do quadro corrente e as telas o
> desenham no lugar de `instance.image` (swap temporário no draw). Como o
> frame está DENTRO da imagem da carta, hover warp/holo/editions/CRT aplicam
> na animação de graça. Regra de quando usar: `displayImage` (topo).

## L103-105 (em `animCache`, junto a `local layerCache = {}`)

> Camadas base/chrome de uma carta animada (ver renderLayers), guardadas
> entre o render ESTÁTICO e a montagem do set — assim o set custa só as
> composições. key → { under, over, t }. Expiram em LAYER_TTL s sem uso.

## L125-129 (em `getParchmentTex`, junto a `CardFrame.TOP_INSET = 3`)

> FILETE DO TOPO (Out/2026, dono: "o topo das cartas está cortado"): o
> banner do nome e as gemas de custo/raridade colavam na borda de cima do
> canvas, então a faixa de nó da moldura (desenhada em y=1) sumia sob o
> banner e a gema parecia decepada — embaixo a moldura aparecia inteira.
> Tudo do topo desce TOP_INSET px; a arte cede essa altura.

## L134-136 (em `artSlotBounds`, junto a `local headerH, footerH`)

> Slot cola direto no header e no footer (sem gap vertical).
> Joker e card padrão usam header/footer DIFERENTES com alturas próprias —
> usar a altura errada cria gap visual ("arte cortada abaixo do título").

## L150-151 (em `artSlotBounds`, junto a `function CardFrame.artSlotBounds(card)`)

> Exposto pro CardAnimationLayer posicionar frames animados do ícone na
> mesma geometria do canvas estático (coords locais do canvas 96×144).

## L156-159 (em `CardFrame.artSlotBounds`, junto a `local BANNER_SHADOW_INSET = {`)

> Inset por raridade: painel sólido do banner PNG não preenche a largura
> inteira em todas as raridades. Rare é quase full-width (bar vermelho grosso),
> mas common/uncommon/legendary têm ornamentos curly nas pontas que não
> projetam sombra. Inset é quantos pixels encolher a sombra top em cada lado.

## L167-174 (em `BANNER_SHADOW_INSET`, junto a `local function drawRecessShadow(ax, ay, aw, ah, bannerX, bannerW, rarity)`)

> Inset shadow pra dar profundidade ao art slot: cria impressão de que o bg
> está RECESSED abaixo das bandas de header/footer. Inspirado no `emboss`+
> `darken` do Balatro (engine/ui.lua:749 + functions/misc_functions.lua:851).
>
> TOP shadow: só no range horizontal da banner do título, ajustado por
> raridade via BANNER_SHADOW_INSET (painel sólido varia de largura).
> BOTTOM shadow: full width — footer é quase edge-to-edge (x=1..95).
> LEFT/RIGHT shadow: 1-2px coluna — CardBorder projeta sombra lateral.

## L185-186 (em `drawRecessShadow`, junto a `Palette.set(Palette.INK, 0.32)`)

> BOTTOM: footer é full-width, shadow cobre o art slot inteiro.
> Alphas subidos pra ficar visível (antes 0.22/0.10, agora 0.32/0.16).

## L192-193 (em `drawRecessShadow`, junto a `Palette.set(Palette.INK, 0.26)`)

> LEFT + RIGHT: 2px de profundidade (antes 1px com alpha 0.14 — invisível).
> Border externa casta sombra rightward no left edge, leftward no right.

## L219-220 (em `renderStandard`, junto a `drawRecessShadow(ax, ay, aw, ah, 15, w - 30, rarity)`)

> Depth: inset shadow antes da borda externa (art slot "afunda").
> Banner coords sincronizadas com CardHeader.draw: bx=15, bw=w-30.

## L239-240 (em `renderJoker`, junto a `local autoDec = CardDecoration.autoForBackground(art.bgPattern)`)

> Aplica decoração auto pelo bg pattern (mesmo comportamento de renderStandard)
> — ex: joker_001 tem bg=abyss → abyss_tendrils por cima do tarot card.

## L246-247 (em `renderJoker`, junto a `drawRecessShadow(ax, ay, aw, ah, 13, w - 26, rarity)`)

> Mesmo inset shadow do standard pra dar profundidade.
> JokerHeader usa bx=13, bw=w-26 (diferente do standard).

## L252-254 (em `renderJoker`, junto a `JokerMoon.draw()`)

> Joker NAO tem custo de mana (passivo, nunca passa pela mao) — o badge
> de custo aqui era vestigial. No lugar: lua crescente tarot, contrapeso
> do JokerSeal do canto direito (pedido do dono, Jul/2026).

## L260-263 (em `renderJoker`, junto a `local keyMemo = setmetatable({}, { __mode = "k" })`)

> Chave do cache por (id, nível de forja). Memoizada por instância numa
> tabela de chaves FRACAS: com toda carta visível pedindo a imagem viva a
> cada draw (Out/2026), montar a string por chamada eram dezenas de
> alocações por quadro — lixo que o GC paga.

## L275-277 (em `cacheKey`, junto a `local function frameHandle(img)`)

> Adapta um love.Image de frame animado pro contrato de handle do IconLoader
> ({ size, draw }) — assim o CardArtSlot posiciona o frame EXATAMENTE como o
> ícone estático (cover-fit/artScale/artOffsetY idênticos).

## L288-299 (em `draw`, junto a `local function drawBase(card, w, h)`)

> A carta é composta em TRÊS camadas, nesta ordem:
> base   — pergaminho sólido + textura (opaco, sem nada da carta)
> ícone  — a ilustração (estática, ou um frame da animação), recortada ao slot
> chrome — decoração, sombra de recesso, moldura, banner do nome, gemas,
> selo, rodapé, gemas de forja (tudo que fica POR CIMA do ícone)
> e os cantos são recortados por último. `renderOne` desenha as três direto
> num canvas (o render ESTÁTICO). Pra ANIMAÇÃO (Out/2026, carta visível =
> viva) a base e o chrome são renderizados UMA vez em canvases próprios e
> cada frame do ícone vira `base + frame + chrome` (3 draws, ~0,1 ms) em vez
> de recompor a carta inteira (texto, moldura, ~0,7 ms medido) — era isso
> que fazia a Coleção gaguejar com dezenas de cartas ganhando vida ao mesmo
> tempo. Paridade pixel a pixel com o render direto: test_cards_always_live.

## L323-327 (em `drawChrome`, junto a `if (card.upgrades or 0) > 0 then`)

> GEMAS DE FORJA (v2 Jul/2026 — substitui o selo "+N" que duplicava
> informação e brigava com o footer): detalhe SUTIL que ESCALA com a
> evolução. Uma gema esmeralda 3×3 por nível numa fileira discreta na
> base do art slot; do 6º nível em diante vira gema + "xN". O VALOR real
> já muda no footer (verde-forja) — a carta é o template vivo.

## L361-363 (em `cutCorners`, junto a `local CORNER_CUT = 3`)

> Stepped pixel-art corner cut (3px em L) — aplicado por último pra recortar
> tudo: base + texture + borda + header + footer + seals. setBlendMode("replace")
> sobrescreve alpha pra 0, criando transparência real nos cantos.

## L394-398 (em `renderOne`, junto a `local function renderLayers(card)`)

> Camada reutilizável da animação: { over }. O chrome nasce num canvas
> TRANSPARENTE (fica pré-multiplicado) e é composto com
> ("alpha", "premultiplied") — matematicamente o mesmo "over" do desenho
> direto, a menos de arredondamento de 8 bits. A BASE (cor + textura, 2
> draws) é redesenhada direto em cada composição: canvas a menos por carta.

## L427-431 (em `composeFrame`, junto a `function CardFrame.render(card)`)

> Descarta os canvases cacheados. NECESSARIO depois de qualquer coisa que
> invalide o contexto grafico -- na pratica, love.window.setMode: o Canvas
> sobrevive como objeto mas seu conteudo e perdido, e CardFrame.render devolve
> o canvas VAZIO do cache. Sintoma: a carta some e so restam selo e moldura.
> E o analogo de FontManager.clearCache(), que love.resize ja chama.

## L436-446 (em `CardFrame.render`, junto a `local art = CardArt.resolve(card)`)

> v10.6 (perf — "engasgada ao abrir a Coleção"): na INSTANCIAÇÃO só o
> render ESTÁTICO com o frame 0 da animação. Os demais frames ficam
> LAZY (liveImage sob orçamento / getAnimation). Antes: 116 cartas ×
> (~9 PNGs do disco + ~9 composições completas) num frame só = travada
> de segundos na primeira abertura.
>
> v11 (Out/2026, carta visível = viva): carta com ícone animado nasce
> pelas CAMADAS — base e chrome renderizados uma vez e o frame 0 composto
> por cima (mesmo caminho dos outros frames: o set nunca "pisca" na volta
> do loop). As camadas ficam em layerCache até o set ser montado, então
> animar custa só as composições (~0,1 ms cada), não a carta inteira.

## L461-462 (em `CardFrame.render`, junto a `local warned = {}     -- key → true: um aviso por carta, não um por quadro`)

> (Declarados ANTES de getAnimation/liveImage: local Lua só existe abaixo da
> definição — mesma pegadinha do notifyOrbUI no EffectSystem.)

## L471-476 (em `warnOnce`, junto a `local function validSet(canvases)`)

> Set de frames VÁLIDO = canvases 1..n todos presentes, n ≥ 1. Um buraco
> aqui não dá erro na hora: `#` ainda devolve n e o draw cai no slot vazio
> só quando o relógio aponta pra ele — defeito de 1 em n quadros, por
> horário (Out/2026: CardFrame.render estubado por tools/balance_sim.setup
> vazava pras suites seguintes; o set nascia {nil, c2..c9} e test_class_select
> caía em `draw(nil)` uma vez a cada nove rodadas).

## L486-513 (em `validSet`, junto a `local BUILD_PER_FRAME = 8      -- unidades (PNG ou frame) por quadro`)

> ===== Ciclo de vida das animações (v3, Out/2026 — "carta visível = viva") =====
> Cada carta animada tem um SET de canvases (a carta completa composta uma
> vez por frame do ícone). `liveImage` devolve DIRETO o canvas do quadro
> corrente — não existe mais um "canvas vivo" intermediário blitado a cada
> mudança de frame: com dezenas de cartas vivas no mesmo quadro (Coleção,
> Deck Viewer) isso eram dezenas de trocas de canvas por segundo pra copiar
> um canvas em outro. Quem desenha já pede a imagem a cada draw (swap
> temporário de `instance.image`), então devolver o quadro certo basta.
>
> Custo controlado em TRÊS lugares:
> 1. ORÇAMENTO GLOBAL por quadro, somado em TODAS as cartas: abrir a
> Coleção pede 15-20 cartas vivas de uma vez = ~90 ms de trabalho
> (decodificar 9 PNGs a ~0,36 ms + compor 8 frames a ~0,34 ms por
> carta, medido em tools/perf_card_anim_units); sem teto isso é um engasgo num
> quadro só. Cada UNIDADE é um PNG decodificado ou um frame composto;
> o quadro para quando gastou BUILD_BUDGET_MS de relógio OU
> BUILD_PER_FRAME unidades (o teto por contagem é o que torna o
> comportamento determinístico sob relógio simulado nos testes). As
> cartas ganham vida em ondas, na ordem em que foram pedidas, em
> ~0,5 s pra grade inteira; até lá desenham o estático = frame 0, sem
> salto visual.
> 2. SÓ QUEM FOI PEDIDO fica em memória: animação que ninguém desenhou há
> STALE_SECS é candidata a sair quando o cache passa de MAX_LIVE sets.
> O teto é MACIO: nunca descarta uma animação em uso (seria recomposta
> no quadro seguinte — thrash que piscava o estático).
> 3. Nada acontece em `update()` além de higiene: zero blits.
> Memória: um set = 9 canvases 96×144 ≈ 0,5 MB; MAX_LIVE 64 ≈ 32 MB de VRAM
> no pior caso (≈3× a grade visível da Coleção, pra rolar sem recompor).

## L524-526 (em `building`, junto a `local BUDGET_WINDOW = 1 / 30`)

> Orçamento do quadro: reposto em CardFrame.update() (love.update) e, como
> rede pra quem roda sem o update (tools antigos), quando o relógio andou
> mais que BUDGET_WINDOW desde a última reposição.

## L537-539 (em `budgetTick`, junto a `if now < budget.t0 or now - budget.t0 >= BUDGET_WINDOW then budgetReset(now) end`)

> `now < t0`: o relógio ANDOU PRA TRÁS (suites com relógio simulado em
> sequência) — sem isto o orçamento nunca mais era reposto e a montagem
> parava: test_class_select falhava SÓ dentro do test_all.

## L553 (em `budgetSpend`, junto a `local function frameIndex(anim, t)`)

> Índice do frame no instante t. Nunca NaN: n = 0 ou t não-finito → 1.

## L567-570 (em `CardFrame.frameAt`, junto a `function CardFrame.getAnimation(card)`)

> Retorna { canvases, fps } se a carta tem ícone animado; nil caso contrário.
> Monta o set INTEIRO agora (sem orçamento) — é o caminho dos tools/testes e
> da inspeção que quer a animação completa num só passo. O frame 0 reusa o
> canvas estático já composto no render.

## L598-602 (em `canvases`, junto a `local function evictLRU(now)`)

> Teto MACIO: só descarta animação que ninguém pediu há STALE_SECS. Com mais
> de MAX_LIVE cartas animadas visíveis no MESMO quadro, descartar uma viva a
> faria ser recomposta no quadro seguinte pra ser descartada de novo —
> thrash que piscava o estático no lugar do vivo. Passar do teto por um
> instante custa só memória; o excesso sai assim que sai da tela.

## L618-624 (em `evictLRU`, junto a `function CardFrame.liveImage(card)`)

> Canvas do QUADRO CORRENTE da animação da carta, ou nil se ela não tem
> animação (ou se o set ainda está sendo montado — quem chama desenha o
> estático, que É o frame 0).
>
> Este é o MECANISMO. A REGRA de quando usar mora em `displayImage`
> (topo do arquivo): telas não chamam `liveImage` direto — assim o
> `reducedMotion` vale em todo lugar de uma vez.

## L660-662 (em `CardFrame.liveImage`, junto a `if not cache[key] then`)

> O frame 0 do set É o canvas estático do cache. Sem ele (render
> substituído por um stub, cache limpo no meio) o set nasceria com
> buraco na posição 1 — ver validSet. Avisa e fica no estático.

## L714-716 (em `anim`, junto a `function CardFrame.update()`)

> Tick global (main.lua love.update, todos os estados): repõe o orçamento
> de composição do quadro e faz a higiene do cache. NÃO blita nada — o
> quadro corrente é escolhido na hora do draw (liveImage).

## L722 (em `CardFrame.update`, junto a `if n > MAX_LIVE then evictLRU(t) end`)

> o excesso sobre o teto macio sai quando as cartas saem da tela

## L724-725 (em `CardFrame.update`, junto a `for k, L in pairs(layerCache) do`)

> camadas de carta que nasceu mas nunca ganhou vida (Coleção instancia
> o catálogo inteiro; só as visíveis montam o set) expiram

## L738-741 (em `CardFrame._liveCount`, junto a `function CardFrame._renderDirectForParity(card)`)

> Paridade das camadas (teste): o frame 0 pelo caminho da ANIMAÇÃO (base +
> ícone estático + chrome, o que `render` devolve pra carta animada) contra
> a carta DESENHADA DIRETO num canvas só — os dois têm que bater pixel a
> pixel (a menos de ±1 de arredondamento do pré-multiplicado).

## L764 (em `CardFrame.invalidate`, junto a `local prefix = (card.id or (card.name or "?")) .. "+"`)

> Keys carregam o sufixo "+<upgrades>" — invalida todos os níveis do ID.

## L780-786 (em `CardFrame.invalidate`, junto a `function CardFrame.clearCache()`)

> Invalida os canvases. Chamar SEMPRE que algo invalidar o contexto grafico —
> na pratica `love.window.setMode`: o Canvas sobrevive como OBJETO mas o
> conteudo dele e perdido, e render() devolveria o canvas VAZIO do cache.
> Sintoma: a carta some e sobram so moldura e selo. E o analogo de
> FontManager.clearCache(), e love.resize chama os dois lado a lado.
> (Havia uma 2a definicao desta funcao acima, sobrescrita por esta e
> incompleta — so limpava `cache`, deixando `animCache` morto. Removida.)

## L794-795 (em `layerCache`, junto a `I18n.onLocaleChanged(function() CardFrame.clearCache() end)`)

> Quando o idioma muda, todas as cartas precisam ser re-renderizadas pra
> mostrar o nome no novo idioma no banner do header.

