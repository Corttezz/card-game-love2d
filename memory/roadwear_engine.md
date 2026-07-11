---
name: roadwear_engine
description: Motor de imperfeições do solo do caminho (engine/RoadWear.lua) — stamps determinísticos por bioma sobre o leito da estrada
type: architecture
---

# RoadWear — imperfeições do solo do caminho (v10, Jul/2026)

**Pedido:** "o solo do caminho está muito padronizado/plano; quero imperfeições
naturais, diferenciadas por bioma, mantendo o visual do jogo."

## Arquitetura

`engine/RoadWear.lua`, mesma família do GrassField/LuminaireEngine:

- **Determinístico**: feature = f(worldZ, hash). Sem estado/spawn — a estrada
  rola e os detalhes rolam junto, sempre os mesmos. Slots de z por feature
  (`cada` unidades) com jitter interno (quebra o ritmo de grade).
- **Projeção injetada**: WorldRoad passa ctx (geom do domo, roadCenter com
  wobble, roadHalf, envColor) — o engine nunca tem coordenadas próprias.
- **Stamps grayscale** procedurais (gerados 1×) tintados por `envColor` no
  draw → o crossfade de bioma lerpa as cores de graça.
- **SQUASH vertical (~0.55)**: o stamp deita no chão (foreshortening) em vez
  de parecer adesivo em pé. Flip horizontal por hash (variedade grátis).
- **Fork**: rel > FORK_REL−1 não recebe detalhe (área de escolha limpa).
- Chamado em `WorldRoad.draw` logo APÓS `drawRoad`, ANTES da grama/props
  (detalhe é do CHÃO: capim de borda e pés de árvore cobrem ele).

## Catálogo por bioma (RoadWear.CATALOG)

| bioma | features |
|---|---|
| fields | manchas úmidas, pedras encravadas, palha, pegadas, seixos |
| highlands | LAJES de calçamento (2 tons), musgo, pedras |
| abyss | RACHADURAS com brasa (submitMicro pulsante!), chamusco, ossos |
| frost | bancos de NEVE invadindo, placas de gelo, pegadas |
| marsh | POÇAS espelhando o céu (tint fog×1.35), lama, raízes, junco |
| dusk | FOLHAS de outono (2 tons quentes), raízes, pedras |

## Knobs

- `RoadWear.DENSITY` (1.6): multiplicador global de densidade.
- Por feature: `cada` (espaçamento z), `alpha`, `uMax` (fração da meia-
  largura), `scaleK`, `tint(ctx)`, `ember` (micro-luz abyss).
- Escala na tela: `(0.70 + 2.6·t) · scaleK`, squash y ×0.55.

## Lições

- A 1ª calibração (DENSITY=1, escala 0.55+2.2t) ficou invisível — stamps de
  chão precisam de MAIS presença do que parece no código (a perspectiva +
  ambiente escuro comem tudo). Validar SEMPRE com zoom no leito.
- Poça = aro escuro + miolo CLARO tintado com a cor do fog (reflexo do céu).
- Rachadura do abyss ilumina (submitMicro rel=z) — chão vivo à noite.
