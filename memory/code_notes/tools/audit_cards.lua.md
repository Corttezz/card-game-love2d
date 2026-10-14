---
name: code_notes/tools/audit_cards.lua
description: Comentários com decisão/regra/histórico colhidos de tools/audit_cards.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/audit_cards.lua`

Origem: `tools/audit_cards.lua` em `7dbdb60d` (25 de 53 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-30 (junto a `local TK = require("tools.testkit")`)

> tools/audit_cards.lua
> AUDITORIA CARTA A CARTA (Out/2026, frente de balanceamento).
>
> Pergunta que esta ferramenta responde, para CADA carta do catalogo:
> "o que a carta DIZ (descricao exibida, nos 5 idiomas, com a forja
> aplicada) e EXATAMENTE o que ela FAZ quando jogada?"
>
> Tres camadas, cada uma com sua propria lista de defeitos:
>
> 1. COMPORTAMENTO — joga a carta num Game de verdade (mesmo caminho do
> jogador: selectCard -> playSelectedCards -> fila de beats), mede os
> deltas reais (dano no inimigo, bloqueio, vida, mana, Forca/Destreza/
> Foco/Espinhos, orbes, compra/descarte, exaurir, debuffs) e compara com
> o MODELO derivado so dos DADOS da carta. Jokers sao medidos com cartas-
> sonda (ataque 10 / defesa 10 / cura 15) e um ciclo de turno completo
> (gatilhos de inicio de turno, espinhos refletidos, bloqueio retido).
> Repete com a carta FORJADA (+1 e +2): o ganho tem que aparecer no efeito.
> 2. DESCRICAO — renderiza a descricao nos 5 locales (base e forjada) e
> checa: placeholder cru, numero que nao existe nos dados, numero cravado
> no template (apodrece na forja), efeito dos dados sem palavra na
> descricao, palavra-chave na descricao sem efeito nos dados, e o
> VOCABULARIO canonico por idioma (um termo por conceito).
> 3. CURVA DE PODER — pontos por mana por raridade/classe, com outliers.
> Informativa (heuristica): o veredito de forca vem do simulador
> (tools/balance_sim.lua), nao daqui.
>
> love . test_one test_card_audit        -> trava (falha com qualquer defeito)
> love . test_one audit_cards            -> relatorio completo no console
> AUDIT_CARDS_OUT=docs/balance/card_audit.md love . test_one audit_cards
> > tambem grava o relatorio em arquivo

## L36-38 (em `M`, junto a `local function catalog()`)

> ============================================================================
> Catalogo
> ============================================================================

## L62-64 (em `hasEff`, junto a `local FILLER_ID = "defense_001"`)

> ============================================================================
> 1. COMPORTAMENTO
> ============================================================================

## L70-71 (em `hasEff`, junto a `local SEED_ORBS = {`)

> Orbes pre-semeados para cartas que EVOCAM (sem eles o evoke e no-op e a
> medicao nao diria nada). Valores escolhidos pra serem distinguiveis.

## L154-157 (em `playOne`, junto a `local STAT = 3   -- Forca/Destreza do cenario "com stats"`)

> Modelo puro de DADOS (o que a carta promete), carta jogada SOZINHA,
> Forca/Destreza/Foco 0, sem joker. `inst` ja vem forjada quando for o caso.
> Combos: so os que a PROPRIA carta dispara sozinha (tag `combo` conta em
> dobro — regra documentada do ComboSystem, anunciada por banner).

## L196 (em `evokeOrb`, junto a `local v = o.value + ex.focus`)

> Foco ja ganho NESTA carta (Consumir: Foco antes de evocar) conta

## L346 (em `compare`, junto a `local any = got.enemyDmg ~= 0 or got.armor ~= 0 or got.hpDelta ~= 0 or got.drawn ~= 0`)

> aleatorio por design: so exige que ALGO tenha acontecido

## L385-386 (em `inst.tags`, junto a `local function fullEnemyCycle(g)`)

> Roda o turno do inimigo INTEIRO (golpe de 1, espinhos, DoT, upkeep, compra,
> gatilhos de inicio de turno) e devolve o snapshot depois.

## L557-559 (em `counted`, junto a `if cd.innate or cd.retain then`)

> Inato: embaralhada no FUNDO do baralho, tem que voltar ao topo
> (o caminho real: reembaralhar promove as inatas).
> Retencao: fica na mao no fim do turno; as outras vao pro descarte.

## L582 (em `counted`, junto a `local gains = RunManager.getForgeGains(cd)`)

> forja: o ganho declarado TEM que aparecer no efeito medido

## L603-605 (em `counted`, junto a `local LOCALES = { "pt_BR", "en", "es", "fr", "de" }`)

> ============================================================================
> 2. DESCRICAO
> ============================================================================

## L609-610 (em `LOCALES`, junto a `local VOCAB = {`)

> Termos canonicos (minusculo, sem acento). Um conceito = um termo por idioma.
> `any` = qualquer um basta pra "mencionar" o conceito.

## L644 (em `double`, junto a `local FORBIDDEN = {`)

> Sinonimos PROIBIDOS (vocabulario fora do padrao): termo -> canonico.

## L657-659 (em `de`, junto a `local BATTLE_PHRASE = { ["nesta batalha"] = true, ["this battle"] = true,`)

> "nesta batalha" e informacao REAL so onde o efeito some no fim da batalha
> e o jogador poderia achar que nao (mana maxima). Forca/Destreza/Foco sempre
> duram a batalha — repetir isso em umas cartas e nao em outras e ruido.

## L663-664 (em `BATTLE_PHRASE`, junto a `local STYLE = {`)

> Padroes de FORMATO (Lua patterns sobre o texto normalizado): a mesma ideia
> escrita sempre do mesmo jeito dentro de um idioma.

## L684 (em `ORB_CONCEPT`, junto a `local function requiredConcepts(cd)`)

> Conceitos que os DADOS exigem que a descricao mencione.

## L730 (em `need`, junto a `local CLAIM_CHECK = { "poison", "vulnerable", "weak", "strength", "dexterity", "focus",`)

> Conceitos que, se aparecem na descricao, PRECISAM existir nos dados.

## L810 (em `rawByLocale`, junto a `for concept, why in pairs(requiredConcepts(cd)) do`)

> (a) todo efeito dos dados tem palavra na descricao

## L822-823 (em `rawByLocale`, junto a `local skip = (concept == "discard" and cd.retain)`)

> "Conta em DOBRO para combos" e "2 vezes" nao sao multi_hit
> "Retencao: nao e descartada" explica a palavra-chave, nao e descarte

## L841-842 (em `rawByLocale`, junto a `local rawNoPh = raw:gsub("{%w+}", "")`)

> (d) numero CRAVADO no template que coincide com um valor dos
> dados (apodrece no proximo rebalance/forja)

## L859 (em `rawByLocale`, junto a `for bad, good in pairs(FORBIDDEN[loc] or {}) do`)

> (e) vocabulario proibido

## L874-876 (em `rawByLocale`, junto a `for _, e in ipairs(cd.effects or {}) do`)

> (h) LINHAS DE EFEITO (painel de detalhe / colecao / inspecao):
> todo efeito tem chave traduzida — sem cair no `description`
> PT dos dados nem no tipo cru — e nenhum numero inventado.

## L957-959 (em `phs`, junto a `M.WEIGHTS = {`)

> ============================================================================
> 3. CURVA DE PODER (heuristica — o veredito e do simulador)
> ============================================================================

## L1023-1024 (em `M.powerCurve`, junto a `local r = { id = id, cls = cd.class or "basic", rarity = cd.rarity or "common",`)

> exaurir = carta de uso unico na batalha: vale o mesmo por mana,
> mas aparece marcada (comparar so dentro do mesmo perfil)

## L1050-1052 (em `stats`, junto a `function M.collect()`)

> ============================================================================
> Relatorio
> ============================================================================

