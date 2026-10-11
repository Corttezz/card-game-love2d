---
name: Roteiro da run (journal) e RunJournalScreen
description: Registro do caminho percorrido (RunManager journal*) e a tela cheia que o desenha — capítulos em grade (coluna = andar) com o resultado sob cada parada, castelo fechando a linha. Invariantes de captura, backfill, endless e a decisão do redesenho Out/2026.
type: project
---

# Roteiro da run

Pedido do dono (Set/2026): *"um mapa de tudo o que a gente já fez, tudo o que a
gente já escolheu, só para acompanhar ato por ato... como se fosse um roteiro do
que já passou. No final, ali, seu castelo, tipo um mapa do Slay the Spire, mas
sem opções futuras, só opções que já passaram."*

Três leis da tela, todas vindas dessa frase:

1. **Uma trilha por ato, atos empilhados.** Lê como linha do tempo.
2. **Sem ramificação.** Uma linha só, o caminho real. É o que a distingue do
   mapa do StS — nada de "o que eu poderia ter escolhido".
3. **Ato não jogado não aparece.** Faixa vazia lê como buraco
   ([[ui_layout_invariants]] §1, corolário "zona vazia").

---

## O dado: `currentRun.journal`

Antes existia só `run.mapHistory` — ato/andar/tipo, **write-only**, sem um único
leitor no repo inteiro. O roteiro estende esse registro com o RESULTADO e as
ESCOLHAS de cada nó.

```lua
{ act, floor, gfloor, type, hpIn, hpOut, maxHp, goldIn, goldOut,
  gains = { {kind="card"|"joker"|"forge"|"remove", id=, lvl=, ...} },
  eventId, optionIndex, optionLabel, at = os.time() }
```

Ciclo de vida (`src/systems/RunManager.lua`):

| | quem chama | onde |
|---|---|---|
| `journalBegin(node, snap)` | `chooseNode` | `main.lua` passa `{hp,maxHp,gold}` em `onNodeChosen` |
| `journalNote(entry)` | os **sinks do próprio RunManager** | `addCardToDeck`, `addJokerToRun`, `upgradeCard`, `removeCardFromDeck` |
| `journalEvent(id, i, label)` | `main.lua` (id) + `EventScreen` (opção, antes do `apply`) | |
| `journalEnd(snap)` | `showMapSelection` | choke point de TODO nó resolvido |

**Por que instrumentar os sinks e não as telas:** loja, recompensa, fogueira,
eventos e packs desembocam todos nesses quatro métodos. Uma chamada em cada um
cobre as cinco telas — e não exige tocar em `CardRewardScreen`/`RestScreen`.

### Armadilhas já resolvidas (não reintroduzir)

- **`os.time()`, nunca `love.timer.getTime()`.** getTime é relativo à sessão e
  vira lixo depois de um load. O `cardHistory` legado tem esse bug.
- **`journalEnd` é idempotente.** `showMapSelection` roda duas vezes (o guard de
  `pendingNodes` existe por isso).
- **`journalBegin` auto-fecha uma entrada esquecida.** O `tools/autoplay.lua`
  chama `chooseNode` direto e nunca fecha; sem isso as escolhas seguintes
  cairiam no nó errado.
- **`journalNote` fora de nó é no-op LEGÍTIMO** (deck inicial da classe) — vai
  em `Debug.trace`, não em `warn`. Não confundir com fallback silencioso.
- **`registerPaidForge` NÃO anota.** Quem sabe *o que* foi forjado é
  `upgradeCard`; anotar nos dois duplicaria a entrada.
- **Em endless o par (ato, andar) REPETE** (act trava em `totalActs+1`, floor
  cicla 1..8). Por isso `getJournal` devolve em ordem CRONOLÓGICA e nunca usa
  (ato, andar) como chave. `gfloor` (= `currentFloor`) é o identificador.

### Backfill de runs antigas

`mapHistory` e `journal` são alimentados na MESMA chamada, então as `J` entradas
do journal são sempre os `J` últimos nós. Os `#mapHistory - #journal` primeiros
são anteriores à feature e entram como `partial = true` ("Sem detalhes
registrados"). Uma run em andamento ganha o caminho retroativo sem duplicar nada.

### Persistência

`journal` é só number/string/boolean/table, então viaja no save junto do resto de
`currentRun` (`SaveManager.serialize`) — **sem migration**. Save antigo entra com
`journal = nil` e o backfill cobre. `game:checkpointRun()` foi adicionado em
`skipBattleAndShowMap` (`main.lua`): antes, nós sem batalha só chegavam ao disco
na batalha seguinte.

---

## A tela: `components/RunJournalScreen.lua` (+ `src/ui/RunJournalLayout.lua`)

Abre por clique no bloco "ATO N" da TopBar (`TopBar:setActClickCallback`, wire em
`main.lua`) **ou** tecla `M`. Mesmo molde do [[jokers_and_hand_layout]]
(DeckViewer/Gerenciador): `_G.runJournalScreen` + `_G.toggleRunJournal`, registro
nos 6 hooks do `main.lua` **e no `love.resize`**.

### Redesenho Out/2026 ("a tela de logs tá muito feia")

Diagnóstico da v1 (capturas 1024/1280/1920, en/pt_BR, run curta e de 6 atos):
cenário de biblioteca competindo com discos e texto de 9px; toda parada com o
mesmo peso (batalha comum = chefe); NADA dizia o que aconteceu sem hover;
castelo maior que a trilha (16% da janela, até 280px); tooltip subindo pra
faixa do ato de cima; com 6 atos os nós encolhiam pra 26px e metade direita da
tela virava pontilhado vazio.

Variantes capturadas (prancha no relatório da sessão; switch temporário via
`JOURNAL_PROTO`, já removido):
- **A** capítulos em GRADE — uma coluna por andar, resultado escrito sob cada
  parada, chefe/elite com disco maior e aro duplo, castelo pequeno fechando a
  linha, superfície lisa.
- **B** trilha compacta sem texto + painel de detalhe FIXO à direita.
- **C** a v1 limpa (sem cenário, castelo menor).

**A venceu.** Critérios: entender a run em segundos (só A mostra o resultado
sem hover — B e C exigem passar o mouse em 48 paradas); hierarquia (A e B);
sem fundo concorrendo (as três); 6 atos com rolagem clara (A rola, B cabe mas
o painel fica ~80% vazio = zona vazia); coerência com a loja nova (A e B usam a
mesma superfície lisa + título com filetes de `memory/shop_layout.md`).

### Como ficou (não regredir)

- **Coluna = andar.** Todo andar 6 fica na mesma vertical: a run lê como grade.
  Endless (ato trava, andar cicla) quebra em linhas de 8 na mesma faixa.
- **Resultado sob a parada, 2 linhas:** (1) o ganho mais importante (coringa >
  carta > forja "Nome +N" > remoção riscada; senão a opção do evento) + PIPS
  dourados pros ganhos extras — nunca "+N", que nesta tela já é forja;
  (2) vida/ouro com sinal e ícone (independe de idioma) ou "AGORA" no nó aberto.
- **Hierarquia:** chefe/mini-chefe/elite = disco cheio com aro duplo; resto =
  74% do disco. Nó parcial (backfill) a 50%.
- **Castelo** = ~1 coluna (10% do conteúdo, teto 132px), fecha a ÚLTIMA linha
  do capítulo. Estado ("CONQUISTADO" / "x/8 andares" / "N paradas") vai no
  título do capítulo, à direita.
- **Detalhe (hover) mora AO LADO da parada**, dentro da faixa do próprio ato
  ∩ zona visível: largura limitada a `tipRoom` (lado com mais espaço), linhas
  cortadas a `maxTipH` com "+N mais". Faixa quase toda rolada pra fora = sem
  detalhe (não invade a vizinha).
- **Abre no fim** (ato em andamento). Roda, setas, PgUp/PgDn, Home/End.
- Cabeçalho: título + filetes, progresso, e resumo da run (cartas/forjas/
  coringas/removidas) — `run_journal.summary`.
- Layout PURO em `RunJournalLayout.compute(sw, sh, bands, scroll)` +
  `validate(L, tip?)`. Ancorado no topo (página de diário), não centrado.

**Validação:** `love . screenshot_journal [long|small] [- <loc>]` com
`JOURNAL_W/JOURNAL_H` (um setMode por processo) → `run_journal_<modo>_<WxH>_<loc>[_hover].png`;
`JOURNAL_PROTO=<módulo>` captura outra tela no mesmo cenário (antes/depois).
`test_journal_resize`: 7 tamanhos × 5 idiomas × run curta/longa, topo e fim da
rolagem, `validate` + detalhe de TODA parada visível + teclado.

**Why:** a tela era um mapa de ícones sem informação e o fundo brigava com ela.
**How to apply:** informação nova de parada entra na célula (2 linhas) ou no
detalhe — nunca numa banda nova; não reintroduzir cenário nem castelo-protagonista.

## Ligações

[[ui_layout_invariants]] · [[resize_pattern]] · [[run_progression]] ·
[[jokers_and_hand_layout]] · [[sts_source_reference]]
