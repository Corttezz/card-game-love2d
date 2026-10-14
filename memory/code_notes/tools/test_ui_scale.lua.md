---
name: code_notes/tools/test_ui_scale.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_ui_scale.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_ui_scale.lua`

Origem: `tools/test_ui_scale.lua` em `7dbdb60d` (1 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local TK = require("tools.testkit")`)

> tools/test_ui_scale.lua
> ESCALA GLOBAL DE UI (src/ui/UiScale.lua): fator por janela, espaço virtual
> dentro do contexto (dimensões, mouse, scissor, fonte), adoção das telas
> (layout + clique no mesmo espaço), higiene de vazamento e a opção
> "Escala da interface" das Configurações.
>
> love . test_one test_ui_scale
>
> Janela e mouse FALSIFICADOS; tudo restaurado no fim (inclusive o force(1)
> que o testkit liga pros outros testes).

