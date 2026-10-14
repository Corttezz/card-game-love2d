---
name: code_notes/src/ui/ClassSelectLayout.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/ClassSelectLayout.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/ClassSelectLayout.lua`

Origem: `src/ui/ClassSelectLayout.lua` em `7dbdb60d` (5 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `local L = {}`)

> src/ui/ClassSelectLayout.lua
> PLANO DE ZONAS da seleção de classe v4 (Out/2026, "página do grimório").
> O dono achou a v3 poluída (três painéis iguais, muito rótulo, tudo de uma
> vez — "cara de IA"). A v4 é ASSIMÉTRICA e mostra UMA classe por vez:
>
> ┌───────────────────────────────────────────────┐
> │ ‹ menu      [<] selo [>]    ┌───────────────┐ │
> │                             │  (cabeçalho)  │ │
> │         HERÓI               │  NOME         │ │
> │   (emblema grande,      [▸] │  identidade   │ │
> │    efeito da classe)  marca │  passiva      │ │
> │                             │  ♥ ◆ ▤        │ │
> │   ◇  ◇  ◇                   │   [COMEÇAR]   │ │
> └─────────────────────────────┴───────────────┘─┘
> escolha                        página
>
> Cada elemento mora numa BANDA; quando falta espaço cede a escala do
> emblema e o tamanho da fonte, não a posição. compute() é PURO (só
> aritmética sobre sw/sh, no espaço VIRTUAL do UiScale) e validate() é
> rodado pelo test_class_select e pelo test_endless_seals.

## L50-51 (em `out`, junto a `local pw = math.floor(math.min(560, math.max(300, sw * 0.40)))`)

> PÁGINA (direita): 40% da largura, altura quase toda; o pé deixa folga
> pra fita do COMEÇAR, que pende 10 px pra fora do papel.

## L69-71 (em `out`, junto a `local md = math.floor(math.max(64, math.min(104, (zr - zx) * 0.20)))`)

> Emblemas pequenos: 20% da zona esquerda (era 17%; o dono achou os de
> 1024x768 "pequenos" — lá 89 → 104 px, +17%). O teto de 104 segue o
> mesmo, então de 1280 pra cima nada muda; só as janelas estreitas crescem.

## L80-82 (em `out.medallions`, junto a `local hr = L.HELP_R + 3`)

> "?" do corvo narrador: à direita da faixa das classes (caixa clicável do
> HelpBadge.rect = raio + 3 de folga). Mora no layout pra o validate()
> garantir que o emblema maior não o empurra pra cima do marcador/página.

## L87-89 (em `out.medallions`, junto a `local sealH = 40`)

> SELO: no alto da zona esquerda, alinhado à direita (o voltar fica na
> ponta oposta). Só existe com selo liberado — a tela decide; a banda é
> reservada sempre.

