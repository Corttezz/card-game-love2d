---
name: code_notes/tools/test_credits.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_credits.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_credits.lua`

Origem: `tools/test_credits.lua` em `7dbdb60d` (2 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local M = {}`)

> tools/test_credits.lua
> Tela de créditos (components/CreditsScreen.lua): o conteúdo cabe no painel
> em todo idioma e tamanho, cada linha é texto traduzido (nunca a chave
> crua), e o ciclo abrir/fechar devolve o controle ao menu.
>
> Roda: love . test_one test_credits
> love . test_one test_credits shots   (credits_<loc>.png pra olhar)

## L34 (em `M.run`, junto a `local realW, realH = love.graphics.getWidth, love.graphics.getHeight`)

> 2. A lista cabe na zona de conteúdo (fonte encolhe, nunca transborda).

