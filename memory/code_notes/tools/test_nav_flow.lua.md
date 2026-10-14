---
name: code_notes/tools/test_nav_flow.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_nav_flow.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_nav_flow.lua`

Origem: `tools/test_nav_flow.lua` em `7dbdb60d` (3 de 27 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local M = {}`)

> tools/test_nav_flow.lua
> RUN INTEIRA SÓ POR TECLADO/PAD (meta Steam Deck Verified): o jogo de
> verdade (main.lua depois do love.load), sem mouse nenhum —
> menu → classe → batalha (seleciona e joga) → cash out → espólio →
> encruzilhada → loja (compra) → encruzilhada → descanso → encruzilhada →
> evento → pausa → configurações → volta.
> Cada passo navega com SETAS/D-PAD de verdade (o motorista escolhe a
> direção que aproxima o foco do alvo e aperta a tecla), confirma com
> Enter/A, e confere que o foco nunca cai fora da tela.
>
> love . nav_flow                (sai com 0/1)
> NAV_PART=2 love . nav_flow     (2º roteiro: coleção, conquistas, coringas,
> deck, roteiro, pacote, vitória → endless)
>
> Trapaças declaradas (não são navegação): inimigo com 1 de vida (a luta não
> é o que se testa) e o tipo dos nós da encruzilhada forçado (loja, descanso,
> evento) pra o roteiro ser determinístico.

## L31-32 (em `frames`, junto a `local function sleep(secs)`)

> espera TEMPO de jogo (sem vsync o tool roda a centenas de quadros/s: contar
> quadros não espera animação nenhuma)

## L73-74 (em `noteFocus`, junto a `local function navigateTo(match, label, useKeys)`)

> Navega com SETAS até o alvo que satisfaz `match(target)`; devolve true se
> o foco chegou nele. Escolhe a direção pelo vetor foco→alvo.

