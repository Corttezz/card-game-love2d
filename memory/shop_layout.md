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

## v3b: o Balcão do Mercador EM PERSPECTIVA (Out/2026)

Pedido do dono (referência `docs/plan/shop_reference_gpt.png`, plano §12):
"as coisas na diagonal, o cenário bem parecido com isso pra dar sensação de
profundidade; hoje está preso a um todo plano". A v3 "estante + prateleira
+ balcão tileável" (commits 10b87ff1/d756449f) durou um dia: a loja virou
UMA PINTURA com objetos apoiados nela.

- **A cena é uma pintura**: `assets/sprites/shop/counter_scene.png`
  (688x384, PixelLab `create_image_pro` com a referência do dono como guia
  de composição; `tools/pixellab_shop_props.py scene queue|poll`), desenhada
  em cover-fit (mesma conta do `SceneBackground` dos salões). Balcão em três
  quartos, estantes de frascos atrás, vela e caveira à esquerda, lanterna
  pintada no alto (o pulso de luz usa `ShopProps.lightLevel`; o sprite da
  lanterna NÃO é desenhado), pano vermelho, livros e moedas no canto.
- **Slots em coordenadas da ARTE** (`ShopLayout.ART`): 4 cavaletes na borda
  do fundo (a esquerda é mais perto: escala 1,0 → 0,85) e 4 objetos na mesa
  em diagonal esquerda-frente → direita-fundo; sino e copo de dados à
  esquerda. `layout()` converte arte→tela e `validate()` confere pé dentro
  das MÁSCARAS pintadas (`ledgeMask`/`tableMask`, ponto-no-polígono), placas
  sem se tocar, nada sobre carta/pergaminho/CONTINUAR/placa de título.
  Janela estreita (4:3): o cover-fit corta a esquerda, a diagonal DESLIZA pra
  direita e, se ainda não cabe antes do pergaminho, COMPRIME (espaçamento e
  escala); a ordem e a profundidade nunca mudam. 9 tamanhos x 5 idiomas em
  `test_shop_layout`.
- **Cartas em cavaletes** (`card_stand_N.png`) com perspectiva FIXA do
  `card_perspective.glsl` (uniform `mouse = {0.8, 0}`, amount 0,7: a borda
  direita foge, como a mesa) e **placa de latão** procedural sob cada uma:
  raridade em cima (cor da raridade, escurecida), preço embaixo; selo NOVA
  do `DiscoveryMark` no topo. Hover levanta 8 px + brilho de borda;
  selecionado = brilho firme; sem ouro = preço vermelho e a placa treme.
- **Objetos NOVOS na mesa** (`assets/sprites/shop/objects/<id>.png`, 64 px,
  PixelLab pixen com "no table, no candle": o pixflux desenhava uma vela ao
  lado de tudo): tesoura sobre carta cortada, bancada de coringa, frasco,
  cristal, bigorna, prensa, grimório, arca, 5 fardos (pack_<id>) e o sino.
  Placa: efeito curto (`UpgradeTile.effectLabel`) ou nome do pacote + preço.
  Pacote não voa: abre o PackOpenScreen.
- **Pergaminho à direita** (9-slice + papel liso + `CardDetailPanel`
  `parchment`/`artMaxH`) com o botão **COMPRAR · $N** no rodapé. Clicar no
  objeto SELECIONA (`setSelectedOffer`, sem toggle); a compra é no COMPRAR
  (ou Enter/A nele). A primeira oferta já nasce selecionada e, depois de
  uma compra, o pergaminho passa pra próxima disponível. **CONTINUAR** é o
  `skipButton` visível no canto inferior direito; sino e copo são objetos
  na mesa com placa ("NOVAS OFERTAS $4" / "DADOS"), os Buttons deles são
  hitboxes invisíveis; os dois "?" ficam na placa de título.
- Sino: objetos antigos deslizam pra fora da mesa pela esquerda, os novos
  entram pela direita um a um (stagger 60 ms), tudo por `item.slide.x`
  (tabela, sobrevive ao rebuild do primeiro update).
- O que saiu: tábuas tileáveis, balcão procedural, etiquetas penduradas
  (o dono gostou; voltam como detalhe se sobrar tempo), feixe de luz na
  parede (a pintura já é iluminada).
- Travas: `test_shop_layout` (515 asserts) e `test_shop_scene` (82).
  Capturas fiéis à escala: `love . test_one screenshot_uiscale pt_BR:shop`;
  quadros de compra/sino: `SHOP_W=1280 SHOP_H=720 love . screenshot_shop fx`
  + `python tools/pixellab_shop_props.py sheet <tag>`.
