---
name: code_notes/src/data/events.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/events.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/events.lua`

Origem: `src/data/events.lua` em `7dbdb60d` (22 de 34 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local Rng = require("src.systems.Rng")`)

> src/data/events.lua
> Pool de eventos narrativos. Cada evento tem:
> id (unique), act (1-3 ou "any"), title, body (texto),
> options = { { label, gains?, costs?, apply = function(game) ... end } }
>
> gains/costs (listas de strings curtas) viram o sufixo EXPLÍCITO do botão:
> "Beber da fonte  [+cura 40% HP]" — o jogador SEMPRE sabe a troca antes
> de clicar (padrão StS: risco informado, nunca pegadinha). Opções neutras
> ("ir embora") não declaram nada.
>
> apply pode retornar string com feedback textual para toast.
> RNG: decisões de evento usam o stream "event" do Rng da run (reprodutível
> por seed; não contamina os rolls de carta/loja/mapa).

## L18-24 (junto a `local function T(id, key, vars, fb)`)

> Texto do evento (title/body/label) vive nos locales sob `events.<id>`; os
> literais que sobraram aqui sao FALLBACK. Quem resolve e a EventScreen, no
> DRAW — se resolvesse aqui, no load do modulo, trocar de idioma em runtime
> nao mudaria nada, porque Events.POOL e construido uma vez so.
>
> Ja os retornos de `apply` resolvem AQUI mesmo: eles rodam no clique, entao
> o I18n.t acontece na hora certa.

## L31-33 (em `Events`, junto a `local function rewardOpts(game, extra)`)

> Helper: recompensa de carta com contexto do deck (afinidade/anti-duplicata).
> P0.5/P0.10 (rebalance Jul/2026): tambem passa actNumber (cap de afinidade
> progressivo por ato) e runManager (dedup de oferta de joker ja possuido).

## L43-44 (em `rewardOpts`, junto a `opts.discover = false`)

> Candidata sorteada não conta como vista: só a carta ENTREGUE é
> descoberta (Game:addCardToRun anuncia a inédita).

## L49-50 (em `rewardOpts`, junto a `local function deckIdOf(entry)`)

> ===== Helpers dos eventos de bioma (Out/2026) =====
> Toda escolha aleatória usa o stream "event" (reprodutível por seed).

## L56-57 (em `deckIdOf`, junto a `local function removeRandom(game)`)

> Remove UMA cópia aleatória (por índice — CLAUDE.md: a forja/identidade é
> POR CÓPIA). Nunca deixa o deck com menos de 2 cartas. Devolve o nome.

## L68-70 (em `removeRandom`, junto a `local function transformRandom(game, n)`)

> TRANSFORMAR (StS): a cópia sorteada sai e entra uma carta aleatória da
> classe (mesmo cérebro de oferta das recompensas). Devolve { old, new }
> prontos pro texto, ou nil se o deck é pequeno demais.

## L75-77 (em `transformRandom`, junto a `local rewards = game.runManager.cardRegistry:generateCardRewards(`)

> 3 candidatas e fica a primeira que NAO e coringa (coringa vai pra
> colecao, nao pro deck — a troca encolheria o grimorio). A carta so
> sai DEPOIS de haver substituta.

## L96 (em `transformRandom`, junto a `local function loseMaxHP(game, n)`)

> Custo em VIDA MÁXIMA: nunca abaixo de 20, e a vida atual acompanha o teto.

## L118-121 (em `forgeRandom`, junto a `local function grantRandomJoker(game)`)

> Coringa aleatório incomum/raro (da classe ou neutro, desbloqueado e que a
> run ainda não tem) — o pacto do abismo, NUNCA lendário e nunca de graça
> (custa vida máxima): o dono quer que o deck perfeito seja difícil. Entra
> pela porta canônica (addJokerToRun).

## L155-156 (em `apply`, junto a `game.player:loseHealth(math.min(8, game.player.health - 1))`)

> Custo de SANGUE: loseHealth (armadura não paga sangue) e
> nunca mata — o botão já fica desabilitado sem vida (Events.canAfford).

## L181-182 (em `apply`, junto a `for _ = 1, 5 do`)

> Tenta até 5 vezes pegar uma carta que ainda não bateu o cap;
> senão cancela com mensagem (com cap 0/infinito passa de primeira).

## L187-189 (em `apply`, junto a `local lvl = game.runManager:upgradeCardAt(idx)`)

> POR CÓPIA (upgradeCardAt): pelo id, a forja ia pra
> cópia de menor nível daquele id, não pra sorteada
> (CLAUDE.md: "A FORJA É POR CÓPIA, NÃO POR ID").

## L312-316 (em `apply`, junto a `local registry = game.runManager.cardRegistry`)

> P0.8 (rebalance Jul/2026): com legendaries por classe no
> pool, minRarity='legendary' resolve. FALLBACK: se o pool
> legendary da classe estiver vazio/esgotado (ex: dedup de
> jokers ja possuidos), ignora o filtro de classe — NUNCA
> entregar rare por $150.

## L349-350 (em `apply`, junto a `game.runManager:removeCardAt(idx)`)

> removeCardAt: tira A COPIA sorteada. Por id sairia sempre
> a primeira do deck, que pode estar noutro nivel de forja.

## L377-378 (em `apply`, junto a `game.player:loseHealth(math.max(0, math.min(6, game.player.health - 1)))`)

> Armadilha fere mas não mata fora de combate (morte
> num evento não tinha tela de derrota: a run seguia a 0 HP).

## L404-405 (em `effect`, junto a `{`)

> ========== Eventos de DECK (Jul/2026 — o evento mexe no build, padrão
> StS: remover/duplicar/forjar valem mais que ouro no longo prazo) ==========

## L495-499 (em `apply`, junto a `{`)

> ========== Eventos de BIOMA (Out/2026) ==========
> Cada um só aparece nos atos listados em `biomes` (o bioma que a cena
> desenha — no endless, o da rotação 4,5,6,1,2,3; ver Events.roll). A
> auditoria de conteúdo achou 14 eventos genéricos (StS tem ~50) e nenhum
> falava do lugar onde o jogador estava.

## L817-821 (em `apply`, junto a `function Events.canAfford(opt, game)`)

> O jogador PODE pagar a opção? Lido dos custos declarados (os mesmos que
> montam o rótulo "[+$45 / -12 HP]"): ouro precisa existir, vida precisa
> SOBRAR (custo de sangue nunca mata). Sem isto o botão de uma opção
> impagável ficava clicável, gastava o evento e ainda subia "-$20" na tela
> sem cobrar nada.

## L831 (em `Events.canAfford`, junto a `local mx = game and game.player and game.player.maxHealth or 0`)

> teto de vida nunca cai abaixo de 20 (loseMaxHP)

## L842-843 (em `Events.canAfford`, junto a `function Events.get(id)`)

> Evento por id (ou nil). O Continuar reabre o MESMO evento em que o jogador
> salvou (run.stageEventId) em vez de sortear outro.

## L851-858 (em `Events.get`, junto a `local function fitsHere(e, actNumber, biome)`)

> Sorteia um evento do pool para um ato especifico (ou "any").
> `biome` (opcional): bioma que a cena DESENHA (EnemyRoster.biomeAct) — no
> endless o ato passa de 6 e o bioma roda 4,5,6,1,2,3; eventos de bioma
> (`biomes = {..}`) seguem o cenario, nao o numero do ato. Sem o argumento,
> vale o proprio ato (1-6).
> history: run.eventHistory ({ [id] = actNumber }) — evento visto NO MESMO ATO
> não repete; pool esgotada no ato libera repetição (melhor que evento nenhum).
> Stream "event" do Rng da run (reprodutível por seed).

