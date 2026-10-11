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
