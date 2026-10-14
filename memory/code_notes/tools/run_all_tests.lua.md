---
name: code_notes/tools/run_all_tests.lua
description: Comentários com decisão/regra/histórico colhidos de tools/run_all_tests.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/run_all_tests.lua`

Origem: `tools/run_all_tests.lua` em `7dbdb60d` (10 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local M = {}`)

> tools/run_all_tests.lua
> Runner mestre da suite COMPLETA: testes unit/integração novos + smoke tests
> de sistema + validação de catálogo + i18n. Cada suite roda em pcall (um crash
> não derruba as outras) e o resumo final lista o status de cada uma.
> love . test_all
>
> Rodar UM teste isolado: love . test_one <nome>

## L11-12 (em `M`, junto a `local SUITES = {`)

> Ordem: unit/integração primeiro (rápidos, determinísticos), depois smoke
> (sistema), depois validação. Cada entrada é um módulo com .run() -> bool.

## L28-29 (em `SUITES`, junto a `{ group = "unit",  name = "test_intent_visibility" },`)

> névoa de intenção: bioma/véu/revelação, intent segue congelado, HUD "?",
> contadores, clima acompanha, piloto não espia (memory/intent_visibility.md)

## L32-33 (em `SUITES`, junto a `{ group = "unit",  name = "test_tutorial_mage" },`)

> tutorial do MAGO: Conduíte, canalizar, pulso, evocar, estouro, Foco
> (gatilhos pelos acontecimentos do OrbRow; memory/onboarding.md)

## L73-74 (em `SUITES`, junto a `{ group = "unit",  name = "test_shop_layout" },`)

> Loja v3 (Balcao do Mercador): geometria pura + tela real em 7 tamanhos x
> 5 idiomas; hover/compra/sino/reducedMotion/alvos do pad

## L84-86 (em `SUITES`, junto a `{ group = "unit",  name = "test_instant_parity" },`)

> pipeline de balanceamento: relogio instantaneo == relogio de quadros
> (traco turno a turno), pilotos naive/average/expert, determinismo,
> throughput e o registro que o relatorio Python le

## L91-92 (em `SUITES`, junto a `{ group = "unit",  name = "test_shop_props" },`)

> props vivos da loja v3 (lanterna em degraus, copo dos dados lendo a
> jogada da visita, mariposa, reducedMotion sem perder informacao)

## L126-127 (em `SUITES`, junto a `{ group = "unit",  name = "test_shop_sale" },`)

> oferta do dia (Loja v3 F4): 1 e so 1 etiqueta com a flag, 0 sem,
> reroll re-sorteia, seed reproduz, save preserva

## L133-134 (em `SUITES`, junto a `{ group = "smoke", name = "test_perf_budget" },`)

> trava de performance do WorldRoad (draw calls, cache estático, GC,
> troca de bioma sem decodificar PNG) — não mede ms (varia por máquina)

## L154-162 (em `SUITES`, junto a `local GUARDED = {`)

> GUARDA DE VAZAMENTO ENTRE SUITES (Out/2026). Suites e tools monkeypatcham
> funções compartilhadas (relógio, janela falsa, mouse, print, render de
> carta). O que ainda estiver trocado ao FIM da suite é restaurado aqui e
> vira uma linha `[leak]` no relatório — porque o sintoma aparece em OUTRA
> suite, longe da causa: tools/balance_sim.setup (test_instant_parity e
> test_balance_pipeline) trocava CardFrame.render por um stub e
> test_class_select, oito suites depois, caía em CardFrame.lua:423 uma vez a
> cada nove rodadas, conforme o horário (memory/card_icon_animation.md).
> Restaurar aqui é a rede; a suite que vaza continua sendo a dona do defeito.

