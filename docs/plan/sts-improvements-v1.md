# Plano — Melhorias inspiradas no estudo Slay the Spire (v1)

Origem: `memory/sts_gap_analysis.md` (confronto StS × nosso jogo, Jul/2026) + pedidos diretos do Daniel:
RNG melhor em tudo (com influência do histórico de escolhas), upgrade infinito e claro, TopBar melhor,
tela de recompensas melhor, eventos/raridades melhores, e TUDO sempre explicado pro jogador.

Regra permanente: `slay-the-spire-source` é referência de estrutura/números — **zero cópia** de código,
strings ou assets. Convenções do repo valem (PT-BR, Config responsivo, Theme/Palette, Sfx.play, EventManager).

---

## Step 1 — Criar RNG seedável com streams e integrar ao save

**Intent**: Hoje `RunManager`/`CardRegistry`/`ShopSystem`/`MapManager` usam `love.math.random` global sem seed —
nada é reprodutível e save-scum é possível. Criar `src/systems/Rng.lua`: seed única da run +
streams nomeados (`card`, `shop`, `map`, `event`, `enemy`, `misc`) via `love.math.newRandomGenerator`.
Serialização MELHOR que a do StS (que só tinha contador+fast-forward): o RandomGenerator do LÖVE expõe
`getState()/setState()` (string) — o save guarda `{seed, states = {stream->stateString}, counters}`;
o contador fica só como telemetria/debug. Load = `setState` direto, zero fast-forward.
Integrar: `RunManager:startNewRun` gera seed; save/load persiste `rngState`; expor `runManager:getRng("card")`.
Substituir `love.math.random` APENAS nos pontos de decisão de run: `CardRegistry.generateCardRewards/rollRarity`,
`ShopSystem` (ofertas, reroll, preços, booster), `MapManager.generate`, eventos. Usos visuais
(partículas, smoke, shaders, jiggle) continuam no RNG global.

**Arquivos**: novo `src/systems/Rng.lua`; `src/systems/RunManager.lua`; `src/systems/CardRegistry.lua`;
`src/systems/ShopSystem.lua`; `src/systems/MapManager.lua`; `engine/SaveManager.lua` (migration do save).

**Acceptance**:
1. Duas runs com a mesma seed e mesmas escolhas geram mesmas ofertas/nodes; após save+load a sequência continua idêntica (states restaurados via setState).
2. Save antigo (sem rngState) carrega sem crash via migration (gera seed nova).
3. `luac -p` limpo em todos os arquivos tocados.

**Harness de teste**: criar `tools/test_systems.lua` (rodável via `love . test_systems`, wire em main.lua
como os outros tools) com asserts de: reprodutibilidade por seed, roundtrip getState/setState, pity
convergindo (Step 2) e custo de forja crescente (Step 3). Só rodar se NÃO houver processo love do
usuário ativo (guarda obrigatória; nunca matar processo).

**Out of scope**: daily mode, UI de inserir seed, RNG de combate (inimigo usa Enemy.rollIntent atual).

---

## Step 2 — Pity de raridade + afinidade do deck nas ofertas

**Intent**: Raridade hoje é flat (70/25/5 na loja; 37/37/25/1 no registry) — má sorte não corrige e as
escolhas anteriores não importam. Adicionar ao roll de raridade um pity acumulativo estilo "blizzard"
(offset começa +5 em direção a common; cada common tirada move −1 até −40; sair rare/legendary reseta),
persistido em `run.rngState.cardPity` (compartilhado por rewards+loja). Nas ofertas (`generateCardRewards` e
ShopSystem): proibir duplicata na MESMA oferta; peso ×0.5 pra carta com 2+ cópias já no deck; afinidade:
carta candidata ganha +20% de peso por tag dela que aparece ≥2× nas cartas do deck atual (cap +60%),
oferta marcada com `affinity = true` e `affinityTags` pra UI (Step 5 mostra o badge). Usar stream `card`/`shop` do Step 1.

**Arquivos**: `src/systems/CardRegistry.lua`; `src/systems/ShopSystem.lua`; `src/systems/RunManager.lua` (estado);
`src/systems/TagSystem.lua` (helper de contagem de tags do deck, se necessário).

**Acceptance**:
1. Teste com seed fixa: em 200 rolls sem rare, o pity força rare em janela ≤ ~45 rolls; distribuição volta ao normal após reset.
2. Nenhuma oferta contém a mesma carta 2×; ofertas com afinidade têm `affinity=true` somente quando a regra bate.
3. `luac -p` limpo.

**Out of scope**: preços da loja, reroll cost, raridade de boosters.

---

## Step 3 — Upgrade infinito com custo crescente e clareza total

**Intent**: Forja hoje tem cap 5 (`RunManager.UPGRADE_LEVEL_CAP`), custo fixo e o nível quase não aparece.
Tornar o upgrade infinito: cap vira `Config.Game.UPGRADE_LEVEL_CAP = 0` (0 = sem cap, configurável);
custo de forja crescente por nível da carta (base 5, ×1.35 por nível já aplicado, arredondado — ler base
do ShopSystem/RestScreen atual); ganhos por nível mantidos (+2 ATQ, +2 DEF, +1 no 1º effect upgradável).
Clareza: (a) RestScreen mostra preview "ATQ 10 → 12 · DEF 6 → 8 · custo $8" ANTES de confirmar;
(b) selo "+N" permanente na moldura (verificar `CardFrame.render` — o cache por cardId precisa virar
cache por `cardId..'+'..nivel`, senão a arte antiga vaza); (c) `CardInfoDisplay` ganha linha
"Forjada +N (+X ATQ, +Y DEF)"; (d) descrição da carta reflete valores reais da instância upgradada
(interpolar os stats efetivos onde a descrição cita números — usar os campos da instância, não do template).

**Arquivos**: `src/systems/RunManager.lua`; `src/core/Config.lua`; `components/RestScreen.lua` (ou src/scenes —
localizar tela de forja); `src/systems/ShopSystem.lua` (oferta de upgrade); `src/ui/CardFrame.lua` (cache key +
selo +N); `src/ui/card/components/*` (onde o selo renderiza); `src/ui/CardInfoDisplay.lua`.

**Acceptance**:
1. Forjar a mesma carta 7× funciona; custo cresce a cada nível; deck mostra "+7" na moldura e stats corretos no footer.
2. Cache de moldura não mostra arte de nível anterior (duas cópias com níveis diferentes = molduras diferentes).
3. Preview na forja bate com o resultado real pós-forja; `luac -p` limpo.

**Out of scope**: upgrade de jokers (continuam não-forjáveis), rebalance dos ganhos por nível.

---

## Step 4 — TopBar v2 (ato/andar, tooltips em tudo, ouro direcional)

**Intent**: TopBar mostra ouro+juros, deck+mão, score+recorde, engrenagem — mas não mostra ONDE o jogador
está e quase nada explica em hover. Adicionar: (a) indicador de progresso "ATO N · andar X/8" (ícone + texto,
dados de `runManager.currentRun.actNumber/floorInAct`, esconder em modo clássico); (b) tooltip via
`StatusTooltip.show` em TODOS os elementos: ouro (com breakdown "juros: +$N a cada $5, cap $5"), deck
(deck/mão/descarte), score (já existe), ato/andar (próximo marco: mini-boss andar 7, boss andar 8);
(c) cor direcional no número do ouro: flash verde ~0.6s quando sobe, vermelho quando desce (usar `_lastGold`);
(d) highlight sutil de hover (retângulo dourado alpha baixo) em cada área interativa, cursor pointer.
Novas chaves i18n `top_bar.*` e `status.topbar_*` nos idiomas suportados.

**Arquivos**: `components/TopBar.lua`; `src/ui/StatusTooltip.lua` (se precisar de novo tipo);
`src/i18n/*` (strings); `src/core/Game.lua` só se faltar getter de progresso.

**Acceptance**:
1. Hover em ouro/deck/score/ato mostra tooltip correto e some ao sair; clique continua funcionando (config/deck).
2. Ganhar ouro pisca verde, gastar pisca vermelho; ato/andar atualiza ao avançar node e some fora de run mode.
3. `luac -p` limpo.

**Out of scope**: HP/poções/relíquias na barra (HP fica no HudPlayerPanel; consumíveis não existem).

---

## Step 5 — CardRewardScreen v2 no modo rewards (clareza da escolha)

**Intent**: O modo "rewards" (pós-batalha, 3 cartas grátis) está funcional mas "estranho": raridade não é
nomeada, afinidade (Step 2) não aparece, e o skip não comunica a troca. Melhorar SOMENTE o modo rewards
(o modo shop teve overhaul F13 recente e fica como está): (a) título contextual "Espólios da Batalha" +
subtítulo "Escolha 1 carta para o grimório"; (b) badge de raridade NOMEADA por slot (texto "COMUM/INCOMUM/RARA/LENDÁRIA"
com cor da raridade, acima ou abaixo do slot — não só borda); (c) badge "✦ Afinidade" quando `offer.affinity`,
com tooltip listando `affinityTags` ("seu deck já tem N cartas de veneno"); (d) botão skip renomeado
"Seguir sem carta" com subtexto do que acontece; (e) ícone "?" no canto do painel com tooltip explicando as
regras de oferta (raridade por ato, pity, afinidade) em linguagem de jogador; (f) manter animações existentes
(materialize cascade, fly-to-deck).

**Arquivos**: `components/CardRewardScreen.lua` (modo rewards); `src/i18n/*`; `src/ui/StatusTooltip.lua` (reuso).

**Acceptance**:
1. Cada slot mostra o nome da raridade com a cor certa; badge de afinidade aparece só quando a oferta tem `affinity=true`.
2. Tooltip do "?" abre em hover e explica pity+afinidade; skip fecha a tela e segue o fluxo normal.
3. `luac -p` limpo.

**Out of scope**: modo shop (layout, reroll, packs, vouchers), preços.

---

## Step 6 — Eventos v2 (custos explícitos + 4 eventos que mexem no deck)

**Intent**: Eventos hoje são básicos e as escolhas não declaram custo/ganho no botão. (a) Padronizar o
template de escolha do EventScreen: label da opção SEMPRE com o efeito entre colchetes — ex.
"Beber da fonte [Cura 30% · Perde $20]" — gerado de campos data-driven `{ costs = {...}, gains = {...} }`,
nunca texto solto; (b) adicionar 4 eventos novos data-driven que operam no DECK (padrão StS: evento mexe
no build, não só em HP/ouro): Escriba Errante (remover 1 carta do deck — abre picker), Espelho de Tinta
(duplicar 1 carta), Forja Abandonada (forjar 1 carta grátis +1 nível — reusa Step 3), Mercador de Sangue
(ganhar $45 · perder 12 HP, e variante inversa); (c) sorteio de evento usa stream `event` (Step 1) e não
repete evento no mesmo ato (histórico em `run.eventHistory`).

**Arquivos**: `components/EventScreen.lua` (ou onde eventos moram — localizar via grep "event"); dados de
eventos (arquivo data-driven novo `src/data/events.lua` se ainda não existir); `src/i18n/*`; `src/systems/RunManager.lua` (eventHistory).

**Acceptance**:
1. Todos os botões de evento mostram custo/ganho no label vindo dos campos data-driven.
2. Os 4 eventos novos funcionam de ponta a ponta (picker de carta abre, efeito aplica, run salva) e não repetem no mesmo ato.
3. `luac -p` limpo.

**Out of scope**: eventos narrativos multi-etapa, arte nova de eventos (usar ícones existentes).

---

## Step 7 — i18n completo, validação e memórias

**Intent**: Fechar a entrega: (a) varrer TODAS as chaves i18n novas dos Steps 3-6 e preencher nos idiomas
suportados em `src/i18n/` (verificar quantos locales existem — memória cita "i18n×5"); (b) rodar
`luac -p` em todos os `.lua` tocados na entrega (usar o luac standalone — LOVE exit 253 indica driver, não código);
(c) rodar `love . validate_cards` SOMENTE se não houver processo `love` do usuário rodando (checar antes;
nunca matar processo existente); (d) atualizar memórias do repo: `gameplay_systems.md` (RNG streams + pity),
`known_gaps.md` (remover itens resolvidos: "upgrade visual de cartas forjadas", save sem seed), nova
`memory/rng_and_offers.md` (como o RNG/pity/afinidade funcionam + como testar), e seção 12 do `CLAUDE.md`.

**Arquivos**: `src/i18n/*`; `memory/gameplay_systems.md`; `memory/known_gaps.md`; novo `memory/rng_and_offers.md`; `CLAUDE.md`.

**Acceptance**:
1. Nenhuma chave i18n nova sem tradução em todos os locales (fallback de chave crua não aparece em nenhuma tela nova).
2. `luac -p` retorna 0 erros no conjunto tocado; `validate_cards` passa (ou motivo documentado se não pôde rodar).
3. Memórias e CLAUDE.md atualizados refletindo o comportamento real do código.

**Out of scope**: traduzir textos pré-existentes que já estavam faltando antes desta entrega.
