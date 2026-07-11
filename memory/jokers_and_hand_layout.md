---
name: Jokers (coleção+bancada), leque da mão e Deck Viewer cheio
description: Modelo coleção+bancada de coringas (possui ilimitado, ativa até MAX_JOKER_SLOTS), Gerenciador de Coringas, quadro de jokers top-esquerdo, leque/squeeze da mão estilo Balatro + botões subidos, e Deck Viewer em tela cheia. Entrega Jul/2026.
type: project
---

# Coringas coleção+bancada, leque da mão e Deck Viewer cheio (Jul/2026)

Três frentes de UX pedidas pelo Daniel, baseadas no Balatro source
(`balatro-source/cardarea.lua` align_cards + layout dos jokers).

## 1. Coringas: modelo COLEÇÃO + BANCADA (mata o bug "some ao comprar o 4º")

- **Antes**: `currentRun.jokers` ↔ `jokerSlots` 1:1. Comprar com 3 slots cheios
  RETORNAVA false e o joker (já pago) SUMIA.
- **Agora** (RunManager): `currentRun.jokers` = COLEÇÃO ilimitada;
  `currentRun.jokerActive[]` = flags paralelas de ativo. Só até
  `getMaxJokerSlots()` ficam ativos; o resto fica na BANCADA. Comprar sempre
  entra na coleção (auto-ativa se houver slot; senão bancada). Nunca se perde.
- **jokerSlots** (instâncias jogáveis) é construído SÓ dos ativos
  (`buildJokerInstances`). `buildAllJokerInstances` devolve TODOS marcados com
  `_ownedIndex` + `_active` (pro gerenciador). Fonte única de rebuild:
  `Game:rebuildJokerSlots()` (load, compra, troca) → `syncJokerFlags`.
- **Seguro porque** os efeitos de joker são CONTÍNUOS/TRIGGER lidos AO VIVO de
  jokerSlots (`applyJokerEffects`/`applyTriggerEffects`). Nenhum joker atual tem
  passive one-shot permanente (increase_max_mana é de effect card, não joker),
  então trocar ativo = só reconstruir os slots. Passive NÃO é chamada em rebuild
  (evita stack). Se um dia criar joker com passive permanente → precisa de hook
  de activate/deactivate.
- **Teto**: `RunManager:getMaxJokerSlots()` = `currentRun.maxJokerSlots or
  Config.Game.MAX_JOKER_SLOTS(3)`. `Game:recomputeMaxJokerSlots` espelha o
  bônus da edition **Negative** em `currentRun.maxJokerSlots` (senão a bancada
  usaria o base fixo). `setJokerActive(i, true)` barra com motivo `"cap"`.
- **Save**: `jokerActive` viaja junto (currentRun serializado inteiro).
  `_ensureJokerActive` tolera save antigo (nil → primeiros cap ativos) e
  normaliza tamanho/cap. `_migrateJokersFromDeck` mantém jokerActive em lockstep.
- **Gerenciador de Coringas** (`components/JokerManagerScreen.lua`): tela cheia,
  grid de TODOS os coringas; ativos com moldura dourada + "ATIVO N", bancada
  esmaecida + "BANCADA". Clique alterna (respeita cap → toast). Abre por: clique
  no quadro de coringas (combate) OU tecla **J**. Wire igual ao DeckViewer em
  main.lua (draw + input roteado no topo; `_G.toggleJokerManager`).
- **Quadro de coringas** (GameplayScene `drawJokersAsCards`): saiu do topo-CENTRO
  parado → QUADRO rotulado top-ESQUERDO ("CORINGAS n/3 (J)" + "+N bancada"),
  slots FIXOS (placeholder "+" nos vazios). `GameplayScene.jokerFrameRect()` é a
  fonte única de geometria (draw + hit-test do clique).

## 2. Leque/squeeze da mão + botões subidos (Balatro cardarea.lua:456)

- **Problema**: espaçamento fixo (`CARD_SPACING_RATIO`) fazia a mão CRESCER sem
  limite e invadir os botões Jogar/Encerrar à direita.
- **`GameplayScene.handLayout()`** (fonte única — usada por updateCardPositions,
  draw e computeHandDropIndex): a mão é um LEQUE centrado numa ÁREA que termina
  antes dos botões (`areaRight = playButton.x - 16`, `areaLeft = 30`).
  `spacing = min(maxSpacing, (areaW - cardW)/(n-1))` → poucas cartas ficam
  confortáveis; muitas se ESPREMEM (overlap) sem nunca estourar a área. Como
  Card:draw usa (x,y) = CANTO SUP-ESQ, o leque é centrado VISUALMENTE
  (`startX = areaCenter - (totalW+cardW)/2`). A carta em hover já sobe e desenha
  por cima (feito no draw).
- **Botões subidos**: `updatePlayButtonPosition` de `0.72` → `0.62` da altura
  (dupla garantia de folga).

## 3. Deck Viewer em TELA CHEIA (não-modal)

- `components/DeckViewerScreen.lua` reescrito: era painel Panel9 centrado; agora
  é tela cheia estilo Coleção — fundo `SceneBackground("collection")` escurecido,
  título "SEU DECK" + contagens por tipo, grid rolável de largura total (colunas
  dinâmicas 3-7), hover levanta a carta + moldura dourada + tooltip completo
  (CardInfoDisplay), botão X + hint. Mostra o deck COM forja aplicada (valor
  verde + gemas). Guard `_openedAt < 0.25s` mata o "clico e já fecha".

## i18n
`deck_viewer.*` e `joker_manager.*` em pt_BR + en (es/fr/de caem no fallback en).
Todas as chaves têm fallback embutido no código (3º arg de `I18n.t`).

## ⚠️ Pegadinha: teto de 60 upvalues do LuaJIT em main.lua
`love.load` já estava com **exatos 60 upvalues** (o LIMITE do LuaJIT/Lua 5.1 que
o LÖVE usa). Declarar `jokerManagerScreen` como `local` top-level virou o 61º e
o jogo NEM BOOTOU: `main.lua: function at line 325 has more than 60 upvalues`.
O `luac.exe` standalone é **Lua 5.4 (limite 255)** — NÃO reproduz esse erro,
então `luac -p` passa e mesmo assim o LÖVE quebra. **Regra**: novo singleton de
tela/overlay em main.lua vai em `_G.<nome>` (como `_G.togglePauseMenu`,
`_G.jokerManagerScreen`), NUNCA como novo `local` top-level, senão estoura o
compilador. Pra validar de verdade, rodar no LÖVE (LuaJIT), não só no luac.

## Teste
`love . test_systems` cobre o modelo de coringas (11 asserts novos: coleção
guarda todos, cap de ativos, bancada não some, build ativos/all, troca de
ativos, barra por cap, roundtrip de jokerActive). **GUARDA: só rodar sem
processo `love` do usuário aberto.** Ver [[rng_and_offers]], [[known_gaps]].
