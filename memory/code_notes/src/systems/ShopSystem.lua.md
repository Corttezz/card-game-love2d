---
name: code_notes/src/systems/ShopSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/ShopSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/ShopSystem.lua`

Origem: `src/systems/ShopSystem.lua` em `7dbdb60d` (44 de 62 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local ShopSystem = {}`)

> src/systems/ShopSystem.lua
> Sistema de loja inspirado no TFT e Balatro. Pós-redesign Fase 4:
> • Modo "rewards": gera 3 cartas (post-battle).
> • Modo "shop":    gera 4 cartas + 3 relíquias (tesoura e bancada fixas
> + 1 sorteada) + 1 booster pack.
> • Reroll linear 4→6→8→...→30 (base + 2 por reroll, teto 30).
> • Booster packs como ofertas próprias (Fase 5 implementa abertura).

## L18-29 (em `ShopSystem`, junto a `local function itemName(id, fallback)`)

> Catálogo de booster packs disponíveis na loja. Custo + tamanho do conteúdo.
> Fase 5 vai usar `size` (cards mostrados) e `choose` (cards escolhidos)
> ao abrir o pack pra renderizar a UI.
> Nome/descricao EXIBIDOS de um item da loja. O texto das tabelas de dados
> abaixo e so FALLBACK de dev: a vitrine e traduzida, e o nome do pacote/
> upgrade saia cravado em PT no meio dela. A resolucao acontece na CONSTRUCAO
> da oferta (ofertas sao geradas a cada visita e nao viajam no save, entao nao
> ha risco de string congelada no idioma antigo).
>
> DECLARADOS AQUI NO TOPO de proposito: local de Lua so existe ABAIXO da
> definicao, e generateUpgradeOffer usa estes helpers antes do meio do
> arquivo (mesma armadilha do notifyOrbUI no EffectSystem).

## L38-40 (em `itemDesc`, junto a `local BOOSTER_PACK_TYPES = {`)

> NOTA: `name`/`description` aqui sao FALLBACK DE DEV (sem acento de
> proposito, pra trava tools/test_no_hardcoded_pt nao precisar abrir excecao
> pro arquivo). O texto que o jogador le vem de `shop_items.<id>` no i18n.

## L73-75 (em `BOOSTER_PACK_TYPES`, junto a `description = "2 cartas, nenhuma comum; escolha 1.",`)

> Menos cartas que os irmaos, mas nenhuma comum (piso de raridade
> em BoosterPackSystem). A descricao PRECISA dizer isso, senao o
> jogador so ve "2 em vez de 3 pelo mesmo preco".

## L94-110 (em `shop`, junto a `upgrades = 3,`)

> 2 (era 1): com os SERVIÇOS (tesoura, prensa, bancada de coringa,
> grimório de compra) o slot único virava gargalo — seis relíquias
> disputando uma vaga fazem cada mecânica aparecer em ~1 de cada 6
> lojas. Duas vagas: uma é FIXA da tesoura (remoção, StS-style) e a
> outra sorteia entre forja/vida/mana/prensa/bancada/grimório.
>
> O layout absorve isso sozinho: a fileira 2 da vitrine é montada de
> `upgrades + boosters` células dividindo o MESMO vão da fileira 1
> (CardRewardScreen:updateLayout) — com 2+2 as duas fileiras passam a
> ter 4 colunas e ficam alinhadas coluna a coluna, o que antes (3
> contra 4) não acontecia.
> 3 (Out/2026): tesoura e bancada de coringa são FIXAS; a terceira
> vaga sorteia o resto. Fixa indisponível (deck no osso, bancada no
> teto) devolve a vaga ao sorteio — sempre 3 relíquias na prateleira.
> Pacotes 2 -> 1 pra fileira 2 continuar com 4 células alinhadas à
> fileira 1: com 3+2 as 5 células encolhiam TODAS as cartas da loja
> e cortavam o nome das relíquias ("Ban...") em 1024x768.

## L119-120 (em `shop`, junto a `local CLASSIC_UPGRADE_WEIGHT = {`)

> Upgrades GLOBAIS sorteáveis que não são serviço (custo fixo, aplicam direto
> no Player). O peso decide a chance relativa dentro do slot rotativo.

## L127-128 (em `CLASSIC_UPGRADE_WEIGHT`, junto a `local REROLL_BASE = 4   -- custo = REROLL_BASE + 2*n (ver updateRefreshCost)`)

> 4 (era 5, Out/2026): o reroll custava mais que uma carta comum ($3) e
> o piloto rerolava em ~0 lojas por corrida — a ação existia só no papel.

## L130-131 (em `CLASSIC_UPGRADE_WEIGHT`, junto a `local REROLL_MAX = 30`)

> Cap pra reroll cost: sem isso o jogador pode trapar gold infinitamente em
> rerolls (5→7→10→...→2.4M após 20 cliques). Balatro tem cap análogo.

## L151-152 (em `instance.shopUpgradePool`, junto a `instance.rarityWeights = {`)

> Fallback de raridade (só quando ninguém injeta contexto — P0.3 liga os
> pesos POR ATO via context.rarityWeights, incluindo legendary no A2/A3).

## L159-160 (em `instance.rarityWeights`, junto a `instance.cardRegistry = CardRegistry:new()`)

> Cérebro de oferta compartilhado com as recompensas (pity + afinidade +
> anti-duplicata moram no CardRegistry.pickRewardCard — uma regra só).

## L164-165 (em `instance.rarityWeights`, junto a `instance.context = {}`)

> Contexto da run (classe + deck) injetado por quem abre a loja
> (CardRewardScreen:show). Sem contexto: pool global, sem afinidade.

## L176-184 (em `instance._offeredUpgradeIds`, junto a `function ShopSystem:setContext(ctx)`)

> Injeta o contexto da run atual antes de gerar ofertas.
> ctx = {
> classId       = "warrior",
> deckIds       = { "id1", "id2", ... },
> runManager    = runManager,  -- forja (custo crescente) + dedup de joker (P0.10)
> actNumber     = 2,           -- P0.5: cap de afinidade progressivo por ato
> rarityWeights = {...},       -- P0.3/P0.4: pesos POR ATO (ActSystem.getRarityWeights)
> minRarity     = "uncommon",  -- P0.7: piso por node (elite/boss)
> }

## L189-194 (em `ShopSystem:setContext`, junto a `function ShopSystem.runContext(game, mode)`)

> Contexto da run pro cérebro de ofertas — FONTE ÚNICA entre a tela
> (CardRewardScreen:show) e o piloto (tools/autoplay primeShopContext). Antes
> o piloto montava o seu sem o piso de raridade de elite/chefe nem os pesos
> por ato, e media uma vitrine diferente da do jogador (wip/sustain, Out/2026).
> mode "rewards": elite → piso uncommon, boss → piso rare (P0.7); nodeType
> viaja no contexto pra vaga de sustento (Config.Offers.SUSTAIN_GUARANTEE).

## L210 (em `ShopSystem.runContext`, junto a `runManager = game.runManager,`)

> forja (custo crescente) + dedup de joker (P0.10)

## L211 (em `ShopSystem.runContext`, junto a `actNumber = actNumber,`)

> P0.5: cap de afinidade progressivo por ato

## L218-220 (em `ShopSystem.runContext`, junto a `function ShopSystem:initializeShopPools()`)

> Inicializa o pool de upgrades disponíveis na loja.
> (O pool de CARTAS por raridade foi aposentado: ofertas de carta saem do
> CardRegistry.pickRewardCard, que filtra por classe e aplica pity/afinidade.)

## L222-226 (em `ShopSystem:initializeShopPools`, junto a `self.shopUpgradePool = {`)

> P3.2 (rebalance Jul/2026): card_draw_upgrade, damage_upgrade e
> defense_upgrade eram TOAST-ONLY — CardRewardScreen:applyUpgrade só
> imprimia mensagem, zero efeito real ("ouro queimado"). Removidos da
> vitrine até serem implementados de verdade. Ficam só os upgrades que
> aplicam no Player (health/mana).

## L228-230 (em `self.shopUpgradePool`, junto a `{ id = "health_upgrade",     name = "Elixir Vital",    description = "+10 de vida maxima",  cost = 5,  effect `)

> name/description aqui sao FALLBACK DE DEV (sem acento). O texto que
> o jogador le sai de `shop_items.<id>` no i18n, que desde Set/2026
> tambem carrega `effect` (o numero do chip do tile) e `flavor`.

## L236 (em `self.shopUpgradePool`, junto a `function ShopSystem:setMode(mode)`)

> Define o modo antes de gerar ofertas. "rewards" pra post-battle; "shop" pra SHOP node.

## L266 (em `self.currentOffers`, junto a `self._offeredCardIds = {}`)

> Dedup por geração: a mesma carta nunca aparece 2x na mesma vitrine.

## L277-279 (em `self._offeredCardIds`, junto a `local Offers = require("src.core.Config").Offers or {}`)

> wip/sustain (Config.Offers.SUSTAIN_GUARANTEE): na recompensa de
> elite/chefe, enquanto o deck tem < SUSTAIN_MIN_SOURCES fontes de
> sustento, a 1ª vaga é reservada a uma carta de sustento.

## L293-295 (em `self._offeredCardIds`, junto a `self._offeredUpgradeIds = {}`)

> Vitrine de upgrades: a primeira vaga é FIXA dos serviços marcados
> `fixture` (hoje só a tesoura), as demais rotacionam. Dedup por geração:
> a mesma relíquia nunca ocupa duas vagas da mesma loja.

## L325-327 (em `self._offeredUpgradeIds`, junto a `for _, o in ipairs(self.currentOffers) do`)

> Selo "Mercado Caro" / maldição "Dízimo": UM ponto de ajuste pra toda a
> vitrine (carta, relíquia, forja, pacote). Ofertas restauradas do save
> vêm por importState e não passam aqui — nunca encarecem duas vezes.

## L332-333 (em `self._offeredUpgradeIds`, junto a `self:applyDailySale()`)

> Oferta do dia (Config.Offers.DAILY_SALE): depois do multiplicador do
> selo, pra desconto ser sobre o preco que o jogador veria.

## L337-346 (em `self._offeredUpgradeIds`, junto a `function ShopSystem:applyDailySale()`)

> OFERTA DO DIA (Loja v3 F4, Out/2026). So no modo "shop" (a recompensa e
> gratis), so com a flag ligada. UMA oferta com preco > 0 e sorteada no
> stream "shop" do Rng da run (reprodutivel por seed; nunca love.math.random)
> e marcada:
> offer.saleDiscount = pct      (0.25)
> offer.basePrice    = preco cheio (a cena risca este)
> offer.cost         = floor(preco x (1 - pct))
> Chamado no fim de generateOffers, entao o reroll sorteia OUTRA oferta;
> as ofertas vao pro save por exportState (plainCopy leva numeros), logo
> Continuar devolve a mesma etiqueta no mesmo objeto.

## L365-366 (em `ShopSystem:generateCardOffer`, junto a `local pick = self.cardRegistry:pickRewardCard({`)

> Delegado pro CardRegistry (pity + afinidade + anti-duplicata + filtro de
> classe). Stream "shop": rolls da loja não mexem na sequência de rewards.

## L370-372 (em `ShopSystem:generateCardOffer`, junto a `rarityWeights = self.context.rarityWeights or self.rarityWeights,`)

> P0.3/P0.4: pesos de raridade POR ATO injetados via contexto
> (CardRewardScreen:show → ActSystem.getRarityWeights). O fixo
> 70/25/5 antigo vira só fallback pra chamadas sem contexto.

## L374 (em `ShopSystem:generateCardOffer`, junto a `minRarity = self.context.minRarity,`)

> P0.7: piso elite/boss

## L376 (em `ShopSystem:generateCardOffer`, junto a `actNumber = self.context.actNumber,`)

> P0.5: cap de afinidade por ato

## L377 (em `ShopSystem:generateCardOffer`, junto a `runManager = self.context.runManager,`)

> P0.10: dedup de joker possuído

## L388-390 (em `ShopSystem:generateCardOffer`, junto a `if self.mode == "rewards" then cost = 0 end`)

> Recompensa pós-batalha é GRÁTIS (StS: escolha 1 de 3; pagar
> é papel da LOJA). Autoplay B: recompensas pagas travavam o
> crescimento do deck (~40% puladas por falta de ouro).

## L409-411 (em `ShopSystem:generateCardOffer`, junto a `function ShopSystem:buildServiceOffer(id)`)

> Monta a oferta de um SERVIÇO (tesoura, prensa, bancada de coringa,
> grimório). Devolve nil quando o serviço não está disponível nesta run —
> teto de compras batido ou deck curto demais pra tesoura.

## L428-429 (em `ShopSystem:buildServiceOffer`, junto a `name = itemName(id, id),`)

> Fallback de dev sem acento (mesma regra do resto do arquivo): o
> texto do jogador sai de `shop_items.<id>` nos 5 locales.

## L435 (em `ShopSystem:buildServiceOffer`, junto a `picker = svc.picker,`)

> A UI não precisa saber COMO o serviço funciona, mas o picker sim.

## L441-447 (em `ShopSystem:buildServiceOffer`, junto a `function ShopSystem:generateUpgradeOffer()`)

> Uma vaga ROTATIVA da vitrine de upgrades.
>
> Antes eram dois caminhos costurados na mão: "50% de chance de ser forja,
> senão sorteia o pool clássico". Com seis relíquias possíveis isso não
> escala — e a chance de cada uma ficava escondida num `if`. Agora todos os
> candidatos DISPONÍVEIS entram numa lista ponderada única e o sorteio é um
> só, no stream `shop` do Rng da run (reprodutível por seed).

## L459-460 (em `candidate`, junto a `if runManager and runManager.getPaidForgeCost then`)

> FORJA: +1 nível numa carta à escolha; custo cresce por forja COMPRADA
> na run (RunManager:getPaidForgeCost). Ledger próprio, herdado.

## L488-490 (em `candidate`, junto a `for _, svc in ipairs(ShopServices.CATALOG) do`)

> Serviços não-fixos (a tesoura já ocupou a vaga fixa em generateOffers).
> O peso é PERGUNTADO ao ShopServices, não lido do catálogo: a bancada de
> coringa pesa mais quando o jogador tem coringa parado na bancada.

## L524-525 (em `rarityMultipliers`, junto a `common = 1, uncommon = 2, rare = 3, legendary = 7,`)

> legendary 7 (era 10 = $30, Out/2026): o salto rara $9 → lendária
> $30 tirava a lendária da loja na prática (ouro na porta ~$26 no A1).

## L531-533 (em `rarityMultipliers`, junto a `function ShopSystem:refreshOffers()`)

> rollRarity local removido: a raridade da loja agora sai do MESMO roll das
> recompensas (CardRegistry:rollRarity via pickRewardCard) — com pity
> compartilhado e ordem determinística (o pairs() antigo nem era estável).

## L535-536 (em `rarityMultipliers`, junto a `function ShopSystem:refreshOffers()`)

> Refresha ofertas. Custo cresce exponencialmente (Balatro feel) — não linear como antes.
> Cap em REROLL_MAX pra impedir trap de gold drain.

## L539-540 (em `ShopSystem:refreshOffers`, junto a `local raw = REROLL_BASE + 2 * self.refreshCount`)

> Linear Balatro-style (base + 2/reroll): o exponencial punia demais o
> segundo reroll e o cap ficava irrelevante.

## L562-563 (em `ShopSystem:getCurrentOffers`, junto a `local function plainCopy(v, depth)`)

> Cópia só-dados de uma oferta (sem cardInstance, funções ou objetos com
> metatable): é o que cabe no save via SaveManager.serialize.

## L578-582 (em `out`, junto a `function ShopSystem:exportState()`)

> VITRINE NO SAVE (anti-save-scum, Out/2026): a loja/recompensa gerada para
> um nó é estado da run. Antes, "Salvar e sair" + Continuar regerava as
> ofertas com o RNG já avançado — restock grátis, reroll zerado e itens
> comprados de volta à prateleira. exportState/importState levam ofertas
> (com `purchased`), preços (forja inclusa) e o contador/custo de reroll.

## L603-604 (em `ShopSystem:getRefreshCost`, junto a `local rm = self.context and self.context.runManager`)

> O contador cru fica no estado (save); o preço exibido/cobrado passa pelo
> mesmo multiplicador da vitrine.

