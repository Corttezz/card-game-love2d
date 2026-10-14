---
name: code_notes/tools/test_i18n_used_keys.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_i18n_used_keys.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_i18n_used_keys.lua`

Origem: `tools/test_i18n_used_keys.lua` em `7dbdb60d` (2 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local M = {}`)

> tools/test_i18n_used_keys.lua
> Trava: toda chave LITERAL passada a I18n.t(...) no codigo de runtime existe
> nos 5 locales. O test_i18n confere uma lista fixa de chaves criticas; este
> varre o codigo — chave nova no .lua sem a entrada no locale falha aqui, e
> nao so quando o jogador abre a tela em alemao.
>
> Chaves montadas por concatenacao ("acts.act" .. n, "status." .. name) nao
> sao verificaveis estaticamente: o literal termina em "." ou "_" e e pulado.
>
> Rodar: love . test_one test_i18n_used_keys

## L57-59 (em `used`, junto a `if not line:match("^%s*%-%-") then`)

> Linha de comentario nao conta (exemplos de uso no cabecalho).
> O literal tem que FECHAR o argumento (`"chave")` ou `"chave",`):
> `"acts.act" .. n` e concatenacao, nao chave.

