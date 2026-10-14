---
name: code_notes/tools/test_confirm_dialog.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_confirm_dialog.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_confirm_dialog.lua`

Origem: `tools/test_confirm_dialog.lua` em `7dbdb60d` (2 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local M = {}`)

> tools/test_confirm_dialog.lua
> Trava do diálogo de confirmação do menu (src/ui/ConfirmDialog.lua).
>
> Defeitos que ele mata (known_gaps 25 + revisão de lançamento, Out/2026):
> 1. "Jogar" com uma corrida salva começava outra SEM PERGUNTAR — e a run
> nova sobrescreve o slot único no primeiro checkpoint. Um clique no
> botão errado apagava a corrida.
> 2. ESC no menu principal fechava o jogo NA HORA.
>
> Também verifica o contrato do modal: ESC cancela, ENTER confirma, clique
> fora não decide, confirmar dispara UMA vez, e o painel cabe na tela em
> todos os tamanhos e idiomas.
>
> Roda: love . test_one test_confirm_dialog
> love . test_one test_confirm_dialog shots   (salva PNGs pra olhar)

## L101 (em `onConfirm`, junto a `do`)

> 4. Geometria: painel e botões cabem na tela em todo idioma e tamanho.

