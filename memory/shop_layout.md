---
name: Loja em tela cheia (layout sem modal)
description: Decisão Out/2026 — a loja deixou de ser um modal sobre o interior pintado e passou a ocupar a área de jogo, zonas separadas por respiro (sem moldura). Variantes testadas, critério de escolha e o que NÃO reintroduzir.
type: project
---

# Loja em tela cheia (Out/2026)

Queixa do dono: "a loja está meio poluída, talvez seja o background de fundo com
o modal na frente". `components/CardRewardScreen.lua`, modo `"shop"`.

## Diagnóstico (medido nas capturas 1024×768 / 1280×720 / 1920×1080)

1. **Cinco retângulos dourados aninhados**: painel com moldura dupla → barra de
   título com contorno duplo → caixa da vitrine → coluna de detalhe → caixa do
   rodapé de ações. Mais a placa de cada relíquia = seis níveis.
2. **Cenário vivo vazando pelas bordas**: o interior pintado (`shop_interior`,
   estantes, lampião, moedas) aparecia só em pedaços em volta do modal — em
   1920 ocupava ~40% da tela competindo com as ofertas.
3. **Informação repetida**: ouro na TopBar E na barra de título ("Ouro: $30" a
   50px do "$30"); etiqueta "◆ RELÍQUIA ◆"/"◆ PACOTE ◆" sob objetos que já
   dizem o que são; "Efeitos: - Ganha 5 de Bloqueio" repetindo a descrição
   logo acima (desde a auditoria descrição = efeito real).

## Variantes testadas (switch temporário + `tools/screenshot_shop.lua`)

- **A** tela cheia, SEM cenário (superfície escura lisa + luz central suave)
- **B** tela cheia com o interior da loja como cenário (véu 0.50), sem caixa
- **C** modal "limpo": uma moldura só, sem sub-painéis, fundo mais escuro

Critérios: ler em 1s o que está à venda e quanto custa; hierarquia cartas >
relíquias/pacotes > ações; menos camadas; coerência com o resto do jogo.
**A venceu.** B: o texto do painel de detalhe ficava ilegível sobre a mesa de
moedas e as garrafas brigavam com os pacotes. C: melhorou, mas ainda era
"caixa sobre cenário" e o fundo continuava vazando nas bordas em 1920. A tem
o mesmo idioma do modo recompensa (banner com filetes + "?", sem painel).

## Como ficou (não regredir)

- `self.panel` = área útil sob a TopBar (margem 12–40px, teto 1560px de
  largura). Continua existindo porque as ZONAS o fatiam e o `validateLayout`
  confere — só não é desenhado.
- Cabeçalho solto (`_drawShopHeader`): título + filetes + "?" das regras. SEM
  ouro (a TopBar mostra).
- Vitrine/rodapé sem caixa; zonas separadas por `colGap` (16–40px). O
  `validateLayout` agora exige vitrine ∩ detalhe = ∅ e rodapé abaixo das duas.
- Sem etiqueta de categoria em relíquia/pacote (chaves `reward.badge_*` e
  `reward.gold_label` removidas dos 5 locales). Cartas mantêm a raridade.
- `CardDetailPanel` só lista em "Efeitos:" o que a descrição ainda NÃO diz.
- Nome de pacote com palavra maior que o slot (DE "Totengräbertuch") vai em
  linha única via TextFit, em vez de o printf cortar a palavra no meio.
- Removidos: `_drawTitleBar`, `_drawActionBar`, `drawCategoryBadge`,
  `drawTitle` (morto), `_drawPanel`. O PNG `shop_interior` ficou sem uso.

## Ferramentas

`SHOP_W/SHOP_H/SHOP_TAG/SHOP_LOCALE/SHOP_SEED` no `screenshot_shop` (seed fixa
4242 por padrão: mesma vitrine em todo tamanho) e a TopBar real desenhada por
cima, como no jogo. `love . screenshot_shop resize` = tortura de resize.
Trava: `test_upgrade_tile` roda a loja nos 5 idiomas × 7 tamanhos (800×600 até
2560×1440) com oferta selecionada.

**Why:** ruído = molduras empilhadas + cenário cortado + informação repetida;
nenhum deles carregava informação. **How to apply:** ao adicionar algo à loja,
coloque numa zona existente e separe por respiro — não por moldura nova. Ver
[[ui_design_system]] e [[ui_layout_invariants]].

## Ambiente (Out/2026, "mais bonita")

Sem voltar ao cenário: `_drawShopAmbience` (luz âmbar em degraus do alto da
vitrine + vinheta lateral, fora do slide) e `_drawShopShelves` (tábua de
madeira sob cada fileira, dentro do slide — entra com as ofertas). Nenhum
texto, nenhuma moldura nova. Seções NÃO ganharam cabeçalho de texto: a
prateleira já separa os dois andares, e rótulo de categoria foi o ruído
removido acima. Teto de largura da vitrine = `max(1560, sh*1.25)` (em 1440p
um terço da tela ficava vazio).

## v3: o Balcão do Mercador (Out/2026)

Pedido do dono (captura em 1440p): "estante de cima e de baixo, itens em
cima dela de forma bem realista, hover e descrição do lado direito, bem
animada, novas ofertas, dados integrados". Plano em
`docs/plan/shop-v3-balcao.md`. A loja virou uma CENA, não uma grade:

- **Geometria pura** em `src/ui/shop/ShopLayout.lua`: `layout(sw, sh,
  nCards, nRelics)` devolve as zonas (`sign` / `shelfTop` / `shelfBottom` /
  `counter` / `scroll` / `lantern`) e o retângulo de cada objeto (carta +
  suporte + etiqueta; relíquia + etiqueta; pacote + gancho; sino / copo /
  livro no tampo). `validate(L)` exige zonas disjuntas, PÉ de todo objeto
  dentro da tábua (ou do suporte apoiado nela), pacote pendurado sem tocar a
  prateleira, nada fora da tela. Falta espaço = a ESCALA cede (800x600 tem
  carta de ~90px, 1440p de ~250px), as bandas nunca trocam de lugar.
- **Cena** em `src/ui/shop/ShopScene.lua` (parede, feixe de luz em degraus
  que "olha" pro hover, placa com o "?" das regras, tábuas tileáveis,
  balcão, lanterna, pergaminho 9-slice com o `CardDetailPanel` em
  `parchment = true`), **objeto** em `src/ui/shop/ShelfItem.lua` (hover
  levanta 4..6px, etiqueta em pêndulo amortecido, deny = tremor vermelho,
  compra = etiqueta arrancada + marca de poeira + VENDIDO a giz).
- `components/CardRewardScreen.lua` modo `"shop"` DELEGA update/draw/hit à
  cena e guarda só a economia (purchaseOffer, serviços, persistência, saída).
  Os campos históricos (`panel`, `cardPositions`, `slotCount`, `gridArea`,
  `detailPanel`, `actionBar`) continuam espelhados: tools, testes e o
  tutorial leem deles. `skipButton`/`refreshButton`/`diceButton` são hitboxes
  INVISÍVEIS sobre livro-razão / sino / copo (o onClick e o alvo do
  NavCursor continuam sendo deles; o rótulo vira giz no balcão).
- Clique no objeto COMPRA (press + release no mesmo objeto); direito
  inspeciona; A/Enter no foco do pad é o mesmo clique; X = sino, Y = livro.
- Vida ambiente (lanterna, copo de dados com faces, mariposa, teia, etiqueta
  da oferta do dia) é de `src/ui/shop/ShopProps.lua` (frente loja-vida),
  chamada por contrato opcional (`update/drawBack/drawLantern/flameAnchor/
  lookDx/lightLevel/drawDiceCup/drawFront`); ausente = placeholder + aviso.
- Arte em `assets/sprites/shop/`: tábuas/sino/livro/pergaminho vindos do
  PixelLab (`tools/pixellab_shop_props.py queue|poll|install`, fatiados em
  left/mid/right e quadros), suportes/etiqueta/prego/gancho/poeira
  desenhados pixel a pixel pelo mesmo script (`pixels`). O BALCÃO é
  procedural (tampo liso): a arte gerada tinha cerca na frente e nada se
  lia por cima. O pergaminho leva uma lavada de cor de papel (90%) sob o
  texto: grão da arte ≤ 6% atrás de letra pequena.
- Etiquetas e rótulos (revisão da F2): a etiqueta de preço pendura do
  BEIRAL da tábua, sob o objeto, nunca sobre a arte (o selo de raridade da
  carta fica à vista); o rótulo mora na mesma banda, à esquerda: raridade
  (+ AFINIDADE) na carta, efeito curto ("+1 SLOT") na relíquia, nome no
  pacote. Sino e livro-razão têm a MESMA etiqueta pendurada do tampo ("$4",
  "+$3"); o "?" dos dados mora na placa do cabeçalho, ao lado do das regras.
  Altura do pergaminho = conteúdo (arte ≤ 0,78 da carta da prateleira +
  bloco de texto), não a tela inteira.
- Travas: `test_shop_layout` (7 tamanhos x 5 idiomas, tela nasce e cresce)
  e `test_shop_scene` (entrada, hover + som na borda, sem ouro, compra +
  voo pro destino, sino, reducedMotion, alvos do pad). Capturas:
  `SHOP_W=.. SHOP_H=.. love . screenshot_shop`.
