---
name: Roteiro da run (journal) e RunJournalScreen
description: Registro do caminho percorrido (RunManager journal*, com os ramos de cada encruzilhada) e a tela que o desenha como MAPA À MÃO numa folha de pergaminho por ato (Out/2026): só tinta preta, um círculo vermelho, acordeão de atos. Invariantes de captura, backfill, endless, paleta e as travas.
type: project
---

# Roteiro da run

Pedido do dono (Set/2026): *"um mapa de tudo o que a gente já fez, tudo o que a
gente já escolheu, só para acompanhar ato por ato"*. Refeito a pedido dele em
13/Out/2026: *"Quero que ele seja literalmente um mapa, bem parecido com o mapa
do Slay the Spire, que vai mostrando ali os trilhos que a gente vai seguindo e
as decisões que a gente vai tomando. A gente consegue abrir e fechar o mapa
para cada ato... como se tivesse sido escrito à mão, apenas com tinta preta e,
no máximo, um círculo vermelho. Bem cara de mapa mesmo, com uma folha
envelhecida."* A versão anterior (grade de discos com ícones PNG e a foto do
castelo do bioma) foi descartada: "uns ícones genéricos, umas fotos genéricas
de castelo. Não faz sentido."

Leis da tela:

1. **Uma folha por ato, empilhadas; cada uma abre e fecha.** O ato em
   andamento nasce aberto; os anteriores, fechados numa tira com o título.
2. **O mapa SOBE** (andar 1 embaixo, castelo no topo), como no StS. Em cada
   encruzilhada aparecem os ramos que EXISTIAM: o tomado em traço cheio, os
   não tomados em pontilhado esmaecido terminando curto (hachura = não
   explorado), a encruzilhada ainda em aberto esmaecida à frente.
3. **Só tinta preta no papel e no máximo UM círculo vermelho** (onde o
   jogador está). Nenhum PNG, nenhuma cor de acento. Os símbolos são glifos
   de pena (bitmaps 1-bit), o traço ondula por seed da run.
4. **Resultado de cada parada = anotação à margem**, letra miúda, em tinta.
5. **Ato não jogado não aparece.**

---

## O dado: `currentRun.journal`

```lua
{ act, floor, gfloor, type, hpIn, hpOut, maxHp, goldIn, goldOut,
  branches = { "battle", "shop", "event" },   -- TIPOS dos ramos oferecidos (Out/2026)
  pick = 2,                                   -- índice do tomado
  gains = { {kind="card"|"joker"|"forge"|"remove", id=, lvl=, ...} },
  eventId, optionIndex, optionLabel, at = os.time() }
```

Ciclo de vida (`src/systems/RunManager.lua`):

| | quem chama | onde |
|---|---|---|
| `journalBegin(node, snap, options, pick)` | `chooseNode` | `options` = `pendingNodes` ANTES de sumir; `main.lua` passa `{hp,maxHp,gold}` em `onNodeChosen` |
| `journalNote(entry)` | os **sinks do próprio RunManager** | `addCardToDeck`, `addJokerToRun`, `upgradeCard`, `removeCardFromDeck` |
| `journalEvent(id, i, label)` | `main.lua` (id) + `EventScreen` (opção, antes do `apply`) | |
| `journalEnd(snap)` | `showMapSelection` | choke point de TODO nó resolvido |

**Compatibilidade de save:** `branches`/`pick` são ADITIVOS. Entrada sem
eles (save anterior a Out/2026, backfill do `mapHistory`, `journalBegin`
chamado sem opções em teste/autoplay) desenha só o caminho percorrido, sem
ramo. Nada em `Release.MIGRATE_FILES` (é campo dentro de `run.save.lua`,
não arquivo novo). `pick` fora da lista é resolvido pelo objeto do nó.

### Armadilhas já resolvidas (não reintroduzir)

- **`os.time()`, nunca `love.timer.getTime()`.**
- **`journalEnd` é idempotente** (`showMapSelection` roda duas vezes).
- **`journalBegin` auto-fecha uma entrada esquecida** (autoplay chama
  `chooseNode` direto).
- **`journalNote` fora de nó é no-op LEGÍTIMO** (deck inicial): `Debug.trace`.
- **`registerPaidForge` NÃO anota** (duplicaria a forja de `upgradeCard`).
- **Em endless o par (ato, andar) REPETE**: `getJournal` devolve em ordem
  CRONOLÓGICA; no mapa a linha do endless é o ÍNDICE, não o andar.
- **Backfill**: os `#mapHistory - #journal` primeiros nós entram como
  `partial = true`, sem ramos.

---

## A tela: `components/RunJournalScreen.lua`

Abre por clique no bloco "ATO N" da TopBar ou tecla `M`. `_G.runJournalScreen`
+ `_G.toggleRunJournal`, registrada no InputFocus e no `love.resize`; está em
`UiScale.SCREENS` (espaço virtual 1280x720).

### Zonas (`src/ui/RunJournalLayout.lua`, puro, `validate()`)

- **CABEÇALHO** (60px): título em papel sobre a mesa escura, subtítulo
  (ato/andar/paradas + selo/ciclo), botão X em tinta.
- **FOLHAS** (rolável): uma por ato, largura ≤ 840, centradas.
  - fechada = tira de 34px: marca de dobra `[+]`, "ATO N · BIOMA", estado
    (CONQUISTADO / x/8 andares / N paradas) à direita;
  - aberta = título (28px) + **numerais** (24px) | **mapa** (44% do miolo) |
    **margem** (o resto) + **legenda** (1 ou 2 linhas, glifo + nome dos tipos
    presentes na folha).
- Dentro do mapa: `rowH = clamp(sheetW/15, 28, 56)`, glifo 9px em escala
  inteira (2x quando `rowH ≥ 40`), ramos lado a lado com `slotGap =
  clamp(mapW/4, glifo+14, 72)` centrados no ponto de onde o jogador veio
  (o tomado vira o centro da linha seguinte: o caminho serpenteia sozinho).
  Jitter ±3/±2 px por `hash(seed, ato, linha, ramo)`.
- Ato normal tem SEMPRE 8 linhas (as não jogadas ficam em branco, com o
  castelo esmaecido no topo); endless cresce uma linha por parada.
- Quando aperta, cede a ESCALA (linha, glifo, fonte da margem), nunca a
  posição das bandas. Ancorado no topo; abre com a folha do ato atual no
  topo da zona.

### Pena e papel (`src/ui/RunJournalInk.lua`)

- Todo pixel de tinta sai por UM SpriteBatch de um ponto 1x1 (uma chamada
  por folha). `Ink.line` = reta com duas senoides de ondulação + "pressão"
  ocasional (pixel a mais), opcional tracejada; `Ink.ring` = anel com raio
  ondulando e fecho com sobra; `Ink.glyph`/`Ink.castle` = bitmaps 1-bit
  (`#`), esmaecidos pulando pixels por hash.
- Papel = `Ink.paper(w, h, seed)`: Canvas cacheado (LRU 12) com textura
  256x256 tileada (3 tons de PARCHMENT por ruído de hash, gerada uma vez),
  manchas elípticas ditheradas, borda rasgada por perfil senoidal
  (recorte em blend `replace`) e aro `PARCHMENT_DARK`. A sombra é a própria
  silhueta deslocada em tinta. **Limpar o scissor antes de pintar o canvas**
  (o scissor da zona valia dentro dele e as primeiras linhas nasciam
  transparentes). `resize()` limpa o cache.
- Hash = xorshift 32 bits via `bit` (um LCG simples deixava triângulos
  visíveis no pontilhado das manchas).
- Paleta: PARCHMENT_LIGHT/PARCHMENT/PARCHMENT_DARK, INK, BLOOD. Mesa =
  `darken(INK, 0.55)`. Hover de botão em papel, nunca em vermelho (seria um
  segundo círculo vermelho).

### Input

Roda/setas/PgUp/PgDn/Home/End rolam; clique no título abre/fecha; Enter/
Espaço abre/fecha o ato focado (`NavCursor.focusKey()` = `act:N`) ou o sob
o mouse; `1..9` abre/fecha o ato N; Esc/M/X fecham. Títulos, paradas e ramos
registram `NavCursor.target` (foco = hover: o detalhe abre no foco).

### Validação

- `love . test_one test_journal` (dado: ciclo, sinks, ramos gravados e
  salvos, backfill, endless, TopBar).
- `love . test_one test_journal_resize` (7 tamanhos × 5 idiomas × curta/longa
  × acordeão inicial/tudo aberto/tudo fechado, topo e fim da rolagem,
  detalhe de toda parada e ramo visível, teclado).
- `love . test_one test_journal_map` (render em canvas 1024/1920/640:
  **zero cor fora de papel/tinta/vermelho**, **um círculo vermelho** em volta
  da parada atual e nenhum no ato conquistado, caminho contínuo por
  amostragem de pixels, todo ramo não tomado com tinta, acordeão por clique e
  teclado, save antigo sem ramos).
- Capturas: `love . screenshot_journal [long] [- loc]` →
  `tools/preview_out/journal_map/run_journal_<modo>_<WxH>_<loc>[_hover|_allopen].png`
  (janela falsa + canvas, sem setMode, mouse falso: nunca mover o cursor real).

**Why:** o dono quer LER a run como um mapa de pena, não uma lista de ícones.
**How to apply:** informação nova de parada entra na margem (2 linhas) ou no
detalhe; símbolo novo = bitmap em `RunJournalInk.RAW` (1-bit); cor nova é
proibida (a trava conta pixels).

## Ligações

[[ui_layout_invariants]] · [[resize_pattern]] · [[run_progression]] ·
[[nav_cursor]] · [[ui_scale]] · [[sts_source_reference]]
