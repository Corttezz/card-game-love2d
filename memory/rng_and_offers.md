---
name: RNG Streams e Ofertas (pity/afinidade)
description: Como funciona o Rng seedável da run (streams, save via getState), o pity de raridade, a afinidade por tags do deck, a forja infinita com custo crescente e como testar (love . test_systems).
type: project
---

# RNG da run, pity, afinidade e forja infinita (entrega Jul/2026)

Plano de origem: `docs/plan/sts-improvements-v1.md` (Steps 1-7). Inspiração documentada em
[[STS Run Economy]] e [[STS Progression & Config]] — adaptado, nunca copiado.

## Rng (src/systems/Rng.lua)

- **1 seed por run → 6 streams** (`card`, `shop`, `map`, `event`, `enemy`, `misc`), cada um um
  `love.math.newRandomGenerator(seed + i*7919)`. Sortear carta NÃO mexe na sequência do mapa.
- **Instância ativa** (`Rng.setActive/get/clearActive`) criada em `RunManager:startNewRun`,
  restaurada em `loadRun`, limpa em `endRun`. Sem run ativa, `Rng.get()` cria efêmera (classic mode).
- **Save**: `RunManager:saveRun` grava `currentRun.rngState = rng:getState()` —
  `{seed, states (getState string por stream), counters (telemetria), meta}`. Load usa
  `setState` = estado EXATO (melhor que o contador+fast-forward do StS). Migration 1.2
  tolera save antigo sem rngState (gera seed nova).
- **REGRA (agora em CLAUDE.md §9)**: decisão de run → stream do Rng. Visual/cosmético
  (partícula, smoke, jiggle) → `love.math.random` global. Poluir stream com roll cosmético
  quebra a reprodutibilidade.
- `rng.meta` = tabela livre serializada junto (pity mora aqui: `meta.cardPity`).

## Pity de raridade (CardRegistry:rollRarity)

- Config em `Config.Offers`: `PITY_STEP=0.35`, `HARD_PITY=25`.
- Cada roll SEM rare/legendary: `meta.cardPity += 1`; peso efetivo de rare+legendary
  multiplica por `(1 + 0.35 × pity)`. Sair rare+ → pity = 0.
- **Hard pity**: no 25º roll seco, rare é FORÇADA (proporcional rare/legendary).
- Só conta quando rare é possível no peso (pools 100/0/0/0 dos testes não inflam).
- Compartilhado rewards+loja (mesmo meta) — uma sequência de azar só.
- Explicado ao jogador no "?" da tela de recompensas (`status.reward_rules` no i18n).

## Afinidade + anti-duplicata (CardRegistry:pickRewardCard)

- `countDeckTags(deckIds)`: conta tags POR CÓPIA do deck atual.
- Peso da carta candidata: ×(1 + 0.20 por tag dela presente 2+ vezes no deck, cap +0.60);
  ×0.5 se o deck já tem 2+ cópias dela. Sem duplicata na MESMA oferta (excludeIds).
- Oferta marcada `affinity=true` + `affinityTags` → badge "AFINIDADE" no slot (rewards) e
  linha no painel de hover. **As escolhas anteriores importam — e o jogador VÊ isso.**
- `ShopSystem` delega pro MESMO `pickRewardCard` (stream "shop", filtro de classe via
  `setContext{classId, deckIds, runManager}` injetado por `CardRewardScreen:show`).
- Pools ordenadas (`table.sort`) — `pairs()` não tem ordem estável e mataria a seed.

## Forja infinita (Step 3) — REGRA POR CENÁRIO (v2, playtest Jul/2026)

- `Config.Game.UPGRADE_LEVEL_CAP = 0` → SEM cap (>0 restaura teto). Ganhos por nível em
  `Config.Offers.FORGE_ATK/DEF/EFFECT_PER_LVL` (+2/+2/+1).
- **`RunManager.getForgeGains(cardData)` é a FONTE ÚNICA** dos ganhos — lida por
  `applyUpgradesToInstance`, `CardInfoDisplay` (linha de forja), `RestScreen`
  (preview hover + resultado + FILTRO do picker) e `canUpgrade`. A UI nunca mente.
- **MATRIZ DE CENÁRIOS** (a forja melhora O QUE A CARTA TEM — testada em test_systems 11b):

| Carta | Ganho por nível |
|---|---|
| attack > 0, defense = 0 | +2 ATQ apenas |
| defense > 0, attack = 0 | +2 DEF apenas |
| híbrida (ambos > 0) | +2 ATQ e +2 DEF |
| efeito puro (sem stats) | +1 no PRIMEIRO effect de tipo upgradável (UPGRADABLE_EFFECT_TYPES) |
| sem stat nem effect upgradável | NÃO forjável (canUpgrade barra; picker esconde) |
| joker | NÃO forjável (invariante joker-split) |

- ⚠️ Bug histórico que motivou a regra: `if instance.defense` era true pra defense=0
  (0 é truthy em Lua) — carta de ATAQUE PURO ganhava "+2 DEF" fantasma e o tooltip
  anunciava o absurdo. NUNCA usar truthiness pra stats numéricos: sempre `> 0`.
- **VISUAL da forja (v3, playtest Jul/2026)**: NENHUM badge "+N" — os dois antigos
  (Card:_drawUpgradeBadge no canto inf-direito e o selo do CardFrame) foram REMOVIDOS
  porque tampavam o valor do footer. A evolução vive NA carta-template: o VALOR do
  footer (já upgradado) pinta em **verde-forja** (padrão StS de stat aumentado) +
  **gemas esmeralda 3×3** na base do art slot, 1 por nível (cap 5; depois "xN") —
  sutil e escala com a evolução. Cache do CardFrame por id+nível re-renderiza tudo.
- **Ao criar carta nova**: decidir conscientemente em qual cenário ela cai (ver
  memory/card_creation_flow.md) — carta de efeito puro precisa do 1º effect
  upgradável se quiser ser forjável.
- **Forja paga** (oferta "Forja" na loja, 50% do slot de upgrade): custo
  `5 × 1.35^forjasPagasNaRun` (cap 60) via `RunManager:getPaidForgeCost`; comprar abre o
  picker (`_G.openCardPicker("forge")`). Fogueira continua grátis (1/acampamento).
- `_G.openCardPicker(mode, onDone)` (main.lua): overlay que troca `currentState` pra "rest"
  com o RestScreen em modo `forge`/`remove`/`duplicate` e restaura ao fechar. O RestScreen
  virou o picker de carta genérico do jogo.

## Eventos v2 (Step 6)

- Opções com `gains={...}`/`costs={...}` → label vira "Rótulo  [+$45 / -12 HP]"
  (EventScreen.composeOptionLabel). Custo SEMPRE explícito no botão.
- 4 eventos novos que mexem no deck: `escriba_errante` (remover à escolha),
  `espelho_de_tinta` (duplicar), `forja_abandonada` (forja grátis), `mercador_sangue`
  (ouro↔HP nos dois sentidos).
- `Events.roll(act, run.eventHistory)`: stream "event", evento visto não repete no MESMO
  ato (pool esgotada libera). main.lua registra `run.eventHistory[ev.id] = act`.

## TopBar v2 + Rewards v2 (Steps 4-5)

- TopBar: ATO/andar sempre visível (some no classic), tooltip em TUDO (ouro c/ juros, deck,
  score, progresso, engrenagem — chaves `status.topbar_*`), flash verde/vermelho no ouro,
  highlight de hover. `StatusTooltip.draw()` extra no fim do `love.draw` (consome o
  agendamento — double-call é no-op por construção).
- Rewards (modo rewards APENAS; shop F13 intocado): título "ESPÓLIOS DA BATALHA" +
  subtítulo, pill de raridade NOMEADA no topo do slot, pill AFINIDADE embaixo, skip
  "Seguir sem carta", "?" com as regras.

## Como testar

- `love . test_systems` — 15+ asserts: determinismo por seed, roundtrip getState/setState,
  pity (janela ≤ HARD_PITY, hard pity força, 100/0/0/0 não infla), ofertas sem duplicata +
  flag de afinidade coerente, minRarity, forja 7× + custo crescente, mapa reprodutível,
  eventos sem repetição no ato, serialize do rngState.
- **GUARDA**: só rodar se NÃO houver processo `love` do usuário (nunca matar processo!).
- i18n: seções novas em TODOS os 5 locales (`top_bar.*`, `card_info.forged`, `reward.*`);
  `status.*` só existe em pt_BR/en — es/fr/de caem no fallback en (padrão pré-existente).
