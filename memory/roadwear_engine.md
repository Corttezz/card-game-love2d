---
name: roadwear_engine
description: Motores do solo do caminho — RoadSurface (síntese da textura-base com relevo) + RoadWear (decals determinísticos por bioma)
type: architecture
---

# Solo do caminho — RoadSurface + RoadWear (v10/v10.1, Jul/2026)

**Pedido:** "o solo do caminho está muito padronizado/plano; quero imperfeições
naturais, diferenciadas por bioma, mantendo o visual do jogo."

## RoadSurface — SÍNTESE da textura-base (engine/RoadSurface.lua)

A v10 só decorava por cima do PNG tileado — o usuário rejeitou ("você não
mudou o terreno de fato; bioma 2 virou quadradinhos soltos"). A v10.1
SINTETIZA a superfície por bioma (192×512, tileia nos 2 eixos, noise em
lattice modular, bake 1× cacheado):

1. **Clusters tonais** — FBM periódico escolhe entre 4 tons de terra.
2. **Micro-relevo top-light** — borda superior de cluster elevado = highlight,
   inferior = sombra. É o que dá o "desnível" 3D.
3. **Sulcos de roda** contínuos serpenteando + rim claro; **desgaste central**.
4. **Especiais**: highlands = LAJES Voronoi (juntas escuras, relevo por laje —
   substitui os decals de cobble); abyss = craquelure FINA (células 18×40,
   junta 1 texel — 0.045 lia como placas); frost = veios de gelo; marsh =
   sheen úmido + verdete; dusk = flecos de folhiço.

**Integração (drawRoad)**: sampling CENTRADO no eixo da estrada
(`(segX-cxRow)/hs + tw*0.5`, sem uOff aleatório) → sulcos/desgaste seguem a
curva e cada braço do fork ganha os seus. Banda de brilho por faixa reduzida
(0.10→0.04) — banda forte re-achatava a textura em listras. PNG antigo segue
como fallback se o bake falhar.

## RoadWear — decals determinísticos (engine/RoadWear.lua)

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
