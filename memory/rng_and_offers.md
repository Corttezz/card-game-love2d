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
- Relíquias da loja (17/Out/2026): tesoura FIXA (`fixture = true` no
  `ShopServices.CATALOG`); bancada de coringa SORTEADA em
  `ShopSystem.chanceServiceHit` (um `random("shop")` por vitrine contra
  `Config.Offers.JOKER_SLOT_SERVICE_CHANCE`, só se o serviço está disponível,
  isto é, abaixo do teto de 2/run). Pity: `run.jokerSlotMisses` conta lojas
  seguidas sem bancada; com `JOKER_SLOT_SERVICE_PITY` (2) o sorteio é ignorado
  e ela entra. O reroll passa `generateOffers({ reroll = true })`: re-sorteia a
  vitrine inteira (a bancada pode entrar ou sair) sem tocar no contador. O
  Continuar reabre a vitrine salva em `run.shopState` sem novo sorteio, e o
  contador viaja no save por ser campo da run. Serviço com `chanceKey` nunca
  entra no sorteio ponderado das rotativas (`generateUpgradeOffer`). Medido em
  `test_shop_services`: 55% das lojas (teoria 4/7 com chance 0,5 e pity 2),
  nunca 3 ausências seguidas, tesoura em 100%, rotativas nunca repetidas.
- Pools ordenadas (`table.sort`) — `pairs()` não tem ordem estável e mataria a seed.

## Forja infinita (Step 3) — REGRA POR CENÁRIO (v2, playtest Jul/2026)

> ### ⚠️ A FORJA É POR CÓPIA, NÃO POR ID (corrigido Set/2026)
>
> O nível de forja mora **na entrada do `currentRun.currentDeck`** (campo `up`), e
> a identidade de uma cópia é o **índice no deck** — nunca o `cardId`. API:
> `getEntryLevel`, `getUpgradesAt`, `upgradeCardAt`, `canUpgradeAt`,
> `removeCardAt`, `duplicateCardAt`, `getDeckCopies`.
>
> **O que era antes, e por que importa:** o nível vivia em
> `currentRun.upgraded[cardId]`, um mapa por ID, e `buildPlayableDeck` aplicava
> esse nível a TODAS as cópias. Com três "Golpe" no deck, forjar uma **forjava
> as três**. E a tela de forja tinha um `seen[id]` que mostrava só uma cópia —
> o que era coerente com o modelo: exibir três cartas que sempre andam juntas
> seria mentira de UI.
>
> Quer dizer: a queixa do dono ("se eu tiver duas cartas iguais, na tela de
> forjar só aparece uma") era o SINTOMA VISÍVEL de um defeito de regra que dava
> forja de graça. Corrigir só a grade teria exposto a mentira em vez de
> consertá-la. **Quando uma tela esconde informação, desconfie de que ela está
> escondendo um defeito do modelo, não economizando espaço.**
>
> Saves antigos: o nível efetivo é `entry.up` **ou** `upgraded[id]` **ou** 0, então
> o mapa legado vira linha de base compartilhada e a primeira forja daquela cópia
> a desgruda. `upgradeCard(id)` (legado: eventos, autoplay, loja) sobe UMA cópia,
> a de menor nível, e avisa por `print` se não achar. Travado em `tools/test_forge.lua`.


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

## Booster packs no Rng seedado (P0.6, Rebalance v2 Jul/2026)

- `BoosterPackSystem`: TODO roll de pack sai do stream **`shop`** do `Rng` (era
  `love.math.random` — quebrava reprodutibilidade por seed e anti-save-scum).
- Pacote Bufão: pool de jokers da classe + neutros, pesos por raridade, dedup
  contra jokers já possuídos. Packs não-Standard: fallback deixou de ser pool global.
- Cobertura: `love . test_one smoke_packs`.

## Eventos de bioma (Out/2026)

A auditoria de conteúdo achou 14 eventos genéricos (StS ~50). Entraram 12 de
BIOMA, 2 por ato (`biomes = { N }` em `src/data/events.lua`): campos
(espantalho_falante, moinho_assombrado), planaltos (ninho_da_harpia,
santuario_do_vento), abismo (pacto_infernal, fosso_de_brasas), gelo
(lago_congelado, cavaleiro_congelado), pântano (cabana_da_bruxa,
poco_das_sanguessugas), crepúsculo (relicario_do_eclipse, corvo_mensageiro).

- `Events.roll(ato, history, bioma)`: o 3º argumento é o bioma que a CENA
  desenha (`EnemyRoster.biomeAct`) — no endless o ato passa de 6 e o bioma
  roda 4,5,6,1,2,3. Evento de bioma nunca sai fora do cenário dele.
- Mecânicas novas, todas no stream "event": TRANSFORMAR (a cópia só sai depois
  de haver substituta não-coringa), custo em VIDA MÁXIMA (teto nunca < 20;
  `canAfford` desabilita), coringa do pacto (incomum/raro, nunca lendário,
  pago em vida máxima — o dono não quer coringa barato).
- Rótulo `[+x / -y]` tem que caber em 476px na fonte mínima nos 5 idiomas
  (`love . check_event_i18n`) — opção curta, token curto.
- Arte 128×96 em `assets/sprites/ui/event_<id>.png` (PixelLab pixflux,
  contorno preto); `test_events` exige arte e texto nos 5 idiomas pros de
  bioma. Captura: `EVENT_ID=<id> EVENT_SIZE=1920x1080 love . screenshot_event de`.

## Coringa raro na recompensa (14/Out/2026)

Pedido do dono: "os jokers têm pouquíssimas chances de aparecer em batalhas
normais e só aparecem com grande frequência em elite ou boss... e quando
aparecerem, uma animaçãozinha diferente, bem feita, para ver que foi raro".

- Medido antes (`love . test_one test_reward_jokers`, 400 recompensas por
  classe/ato/nó, sem coringa possuído): comum 29% (A1) a 92% (A6), elite 41 a
  95%, mini-chefe igual à comum (não tinha minRarity), chefe 98 a 99,6%, e no
  chefe 72% das recompensas traziam 2+ coringas. A causa: coringa é carta
  incomum/rara/lendária do pool, e o peso de raridade sobe por ato.
- Regra nova, fonte única em `ShopSystem:generateOffers` (modo rewards):
  UM sorteio no stream "shop" contra `Config.Offers.REWARD_JOKER_CHANCE[nodeType]`
  (comum 0,04 · elite 0,40 · mini_boss 0,40 · boss 0,70; nó desconhecido = comum).
  Se passar, a ÚLTIMA vaga pede `jokers = "only"` ao `CardRegistry:pickRewardCard`;
  as outras pedem `jokers = "none"`. Medido depois: 3,5 a 4,4% · 37 a 41% ·
  37 a 41% · 69 a 72%, nunca 2 coringas. O filtro respeita "nunca repete
  coringa possuído" (todos possuídos = vaga vira carta normal) e a vaga de
  sustento (1ª vaga; se só houver uma vaga, o sustento ganha). Raridade do
  coringa: a sorteada; sem coringa nela, sobe (comum→incomum→rara) e depois
  desce; lendária só se o peso do ato permitir.
- A LOJA não muda (`jokers = nil`). Knob: `python tools/balance.py --joker-odds
  "battle:0.04,elite:0.4,mini_boss:0.4,boss:0.7"` (`BALANCE_JOKER_ODDS`).
- Revelação: `CardRewardScreen:_revealRare(inst, { delay })` (reutilizável; o
  `show` chama sozinho para toda carta `type == "joker"` em rewards, em
  sequência). Visual em `src/ui/RareReveal.lua`: as outras entram normais, pausa
  de 0,35 s, CARGA (0,75 s: moldura dourada acende, feixe, motes convergindo,
  `shopCrystalHum`), EXPLOSÃO (flash, anel, 40 faíscas com gravidade,
  `start_materialize` com a paleta "joker", `juice_up`, `packSealBreak` +
  `cardDiscovered`), som-assinatura do coringa 0,55 s depois (`jokerSig_<id>`,
  senão `jokerActivate`), depois raios girando devagar + brasas subindo e o
  selo "ACHADO RARO" (`reward.rare_find`) sob a carta. Todo efeito é desenhado
  numa camada a 1/3 da resolução com filtro nearest (`RareReveal.PIX = 3`):
  polígono suave ficava com "cara de IA". O estado mora na OFERTA
  (`offer._rareReveal`), então sobrevive ao resize que recria as instâncias;
  enquanto escondida a carta não recebe hover nem clique. `reducedMotion`:
  nada se move nem se esconde, ficam brilho parado, raios fixos, selo e som.
- Captura: `CARDGAME_HEADLESS=1 lovec . test_one screenshot_rare_joker` →
  `tools/preview_out/coringa_raro/`.
- Custo no balanceamento (expert_full 53/53/50 → 37/40/30), aceito pelo dono
  sem compensação no inimigo: o coringa passa a vir da loja e da economia.
  Ver `memory/balance_curves.md` (seção "Coringa raro").
