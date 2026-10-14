---
name: code_notes/tools/test_toast_audit.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_toast_audit.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_toast_audit.lua`

Origem: `tools/test_toast_audit.lua` em `7dbdb60d` (3 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local TK = require("tools.testkit")`)

> tools/test_toast_audit.lua
> Avisos do combate (MessageSystem) = SÓ o que o jogador precisa e não vê em
> outro lugar (dono, Out/2026: "muita informação que não precisa aparecer,
> tipo os de início de batalha"). Três travas:
>
> 1. LISTA FECHADA: toda chamada de addMessage do jogo usa uma chave desta
> lista. Aviso novo entra aqui de propósito (com o motivo), nunca por
> acidente — o feed lateral não volta a virar log de depuração.
> 2. Uma batalha roteirizada (início + um turno inteiro do guerreiro)
> não gera aviso nenhum: dano, bloqueio, veneno, golpe do inimigo e
> andar já têm número/selo/barra próprios.
> 3. MessageSystem: vazio não entra, repetido não empilha, no máximo 3,
> cor por tipo.

## L18 (em `M`, junto a `M.ALLOWED = {`)

> chave → por que FICA (não há outro lugar que mostre)

## L111-112 (em `files`, junto a `for key in pairs(M.ALLOWED) do`)

> chaves da lista existem nos 5 idiomas (as de fase/fallback são dinâmicas;
> travessão nos textos é trava do test_locale_dashes)

