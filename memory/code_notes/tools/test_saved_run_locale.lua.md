---
name: code_notes/tools/test_saved_run_locale.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_saved_run_locale.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_saved_run_locale.lua`

Origem: `tools/test_saved_run_locale.lua` em `7dbdb60d` (1 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local TK = require("tools.testkit")`)

> tools/test_saved_run_locale.lua
> Texto de UI guardado no SAVE não pode prender a tela no idioma antigo:
> uma run salva em pt_BR e reaberta depois de trocar pra alemão mostra os
> marcos da encruzilhada e a escolha de evento do Roteiro em ALEMÃO.
> (Os nós e as entradas do roteiro gravam `label`/`optionLabel` do idioma
> daquela hora; a tela resolve pelo tipo/id via I18n e só usa o gravado
> como fallback.)
>
> love . test_one test_saved_run_locale

