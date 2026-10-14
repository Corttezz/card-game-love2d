---
name: code_notes/tools/test_window.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_window.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_window.lua`

Origem: `tools/test_window.lua` em `7dbdb60d` (5 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local TK = require("tools.testkit")`)

> tools/test_window.lua
> Testa com que tamanho a janela deve NASCER.
>
> Existe porque o defeito é invisível na máquina de quem programa: 1024x768
> num monitor 1920x1080 parece aceitável, e num 2560x1440 lê como selo
> postal. O dono pediu que o jogo "nunca abra em modo janela pequeno" em
> Windows E macOS — ou seja, a regra tem que valer em monitores que eu não
> tenho. Testar abrindo janela de verdade não serviria: não é reproduzível
> entre máquinas, e `love.window.setMode` repetido dentro de um tool não
> retorna (memory/ui_layout_invariants.md).

## L30 (em `M.run`, junto a `w, h = f(3024, 1964, 1024)`)

> macOS Retina (o dono joga nos dois sistemas).

## L35 (em `M.run`, junto a `t:truthy("sobra margem na largura", select(1, f(1920, 1080, 1024)) < 1920)`)

> Nunca ocupa a tela inteira: barra de tarefas / menu bar / dock.

## L43-46 (em `M.run`, junto a `t:eq("monitor 800x600 nao e mexido", f(800, 600, 1024), nil)`)

> Monitor pequeno: 85% de 1024x768 daria 870x652, abaixo do minheight
> de 600? nao — 652 passa. Ja 800x600 daria 680x510, abaixo do minimo,
> e ai NAO se mexe: o setMode devolveria uma janela maior que a pedida
> e o layout nasceria com dimensao que a tela nao tem.

## L49 (em `M.run`, junto a `t:eq("desktop nil", f(nil, nil, 1024), nil)`)

> Entradas ruins não podem estourar no boot.

