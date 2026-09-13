---
name: Roteiro da run (journal) e RunJournalScreen
description: Registro do caminho percorrido (RunManager journal*) e a tela cheia que o desenha — trilha por ato terminando no castelo do bioma. Invariantes de captura, backfill e endless.
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

## A tela: `components/RunJournalScreen.lua`

Abre por clique no bloco "ATO N" da TopBar (`TopBar:setActClickCallback`, wire em
`main.lua`) **ou** tecla `M`. Mesmo molde do [[jokers_and_hand_layout]]
(DeckViewer/Gerenciador): `_G.runJournalScreen` + `_G.toggleRunJournal`, registro
nos 6 hooks do `main.lua` **e no `love.resize`** — onde de quebra entraram
`deckViewerScreen` e `jokerManagerScreen`, que definiam `resize()` e nunca eram
chamados.

**Zonas:** CABEÇALHO / TRILHAS (rolável) / RODAPÉ. Dentro da faixa de ato:
TÍTULO / TRILHA (nós à esquerda serpenteando, castelo à direita).

**Escala:** o layout inteiro é derivado da janela a cada frame — nenhuma
coordenada sobrevive a um resize; `resize()` só reclampa o scroll (único estado
de posição guardado). A largura do castelo sai da JANELA (16%), não do nó, pra o
cálculo do `nodeSize` não ficar circular. Quando sobra tela a faixa ESTICA até
`BAND_STRETCH` e a folga vai pro **castelo** — ele é o marco, é ele que merece o
espaço; os nós não crescem junto.

**Castelo:** `assets/sprites/world/<biomeId>_castle.png`, com
`biomeId = biomes[((act-1) % 6) + 1].id` — mesma regra do `WorldRoad.rawBiome`,
replicada pra não acoplar a tela ao motor de cena. Conquistado usa o último frame
de `anim/<bid>_castle_door/` (portão aberto) + etiqueta CONQUISTADO; em andamento
é silhueta + "x/8 andares". Ancorado no CHÃO da faixa pra etiqueta ficar colada.

**Do StS veio a INTENÇÃO, não o código:** nó percorrido em cor sólida com anel em
volta (`MapRoomNode.taken`), trilha como cadeia de pontinhos (`MapEdge`), marco
final grande e fora da fileira dos nós (`DungeonMap.renderBossIcon`).

**Validação:** `love . screenshot_journal` (+ `small`), `love . test_one
test_journal` (42 asserts) e `test_journal_resize` (auditoria geométrica em 7
tamanhos com janela falsificada, padrão de `tools/test_forge_resize.lua`).

## Ligações

[[ui_layout_invariants]] · [[resize_pattern]] · [[run_progression]] ·
[[jokers_and_hand_layout]] · [[sts_source_reference]]
