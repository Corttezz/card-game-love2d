---
name: code_notes/tools/testkit.lua
description: Comentários com decisão/regra/histórico colhidos de tools/testkit.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/testkit.lua`

Origem: `tools/testkit.lua` em `7dbdb60d` (6 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-27 (junto a `local TK = {}`)

> tools/testkit.lua
> Kit compartilhado da suite de testes automatizados (love . test_all).
>
> Estilo: cada suite faz
> local TK = require("tools.testkit")
> local M = {}
> function M.run()
> local t = TK.new("nome da suite")
> t:eq("descricao", obtido, esperado)
> ...
> return t:done()
> end
> return M
>
> Helpers de assercao (t:*):
> check(name, cond)          -- booleano cru
> eq(name, got, want)        -- igualdade estrita (imprime got/want no fail)
> near(name, got, want, eps) -- igualdade de float com tolerancia
> truthy/falsy(name, v)
> throws(name, fn)           -- espera que fn LANCE erro
> noerror(name, fn)          -- espera que fn NAO lance
>
> Fabricas:
> TK.newRunGame(class)       -- Game de RUN pronto (deck, mao, combate pumpavel)
> TK.pump(game, secs)        -- avanca EventManager + animacoes por `secs`
> TK.mockGame(opts)          -- game leve pra testar EffectSystem isolado
> TK.seedRng(seed)           -- Rng determinístico ativo (default 12345)

## L89-91 (em `Tester:done`, junto a `function TK.seedRng(seed)`)

> ============================================================================
> Fabricas de ambiente
> ============================================================================

## L101 (em `TK.seedRng`, junto a `function TK.bootstrap()`)

> Bootstrap mínimo do runtime que o Game espera (idempotente).

## L105-107 (em `TK.bootstrap`, junto a `require("src.ui.UiScale").force(1)`)

> Escala de UI congelada em 1: os testes injetam cliques em coordenadas
> de layout com janela falsificada; o espaço escalado tem teste próprio
> (test_ui_scale, que desliga isto e restaura).

## L126-127 (em `TK.newRunGame`, junto a `function TK.pump(game, secs)`)

> Avança EventManager + animações por `secs` (dt fixo 1/30). Espelha o `pump`
> de smoke_turn_order: é assim que o combate diferido (apex ~0.34s) avança.

## L139-140 (em `TK.pump`, junto a `function TK.mockGame(opts)`)

> Game leve (sem combate/animação) pra exercitar EffectSystem em isolamento.
> Espelha o mock de smoke_effects, com drawCard/addMessage funcionais.

