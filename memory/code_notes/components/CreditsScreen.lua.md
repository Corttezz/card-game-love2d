---
name: code_notes/components/CreditsScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/CreditsScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/CreditsScreen.lua`

Origem: `components/CreditsScreen.lua` em `7dbdb60d` (3 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local FontManager = require("src.ui.FontManager")`)

> components/CreditsScreen.lua
> Créditos do jogo (aberto pelo link "Créditos" no rodapé do menu).
>
> Substitui o placeholder "Sobre" (known_gaps 6): jogo publicado na Steam
> precisa dizer quem fez e de onde vêm motor/fonte/ferramentas de asset —
> e a licença zlib do LÖVE e a SIL OFL da fonte PEDEM atribuição.
>
> Conteúdo é DADO (CREDITS abaixo) apontando pra chaves i18n: papel e nome
> vêm dos 5 locales (nome próprio repetido em cada um é intencional — a
> convenção do projeto não deixa literal de UI no código).
>
> Layout calculado A CADA draw a partir da tela atual: não há rect cacheado,
> então resize é de graça (memory/resize_pattern.md). Se a lista não cabe,
> a fonte encolhe (zona de conteúdo cede ESCALA, nunca posição).

## L25 (em `CreditsScreen`, junto a `CreditsScreen.CREDITS = {`)

> Ordem de exibição. Cada entrada: chave do papel + chave do nome.

## L164-166 (em `CreditsScreen:keypressed`, junto a `function CreditsScreen:mousepressed(x, y, button)`)

> Qualquer clique fecha (tela de leitura, sem nada clicável dentro) — mas
> só um clique INTEIRO dado aqui: o release do clique que ABRIU a tela (o
> press foi no link do menu) não pode fechá-la no mesmo instante.

