---
name: code_notes/src/systems/MessageSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/MessageSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/MessageSystem.lua`

Origem: `src/systems/MessageSystem.lua` em `7dbdb60d` (8 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L14-15 (em `instance.messages`, junto a `function MessageSystem:addMessage(text, type)`)

> Aviso VAZIO não existe (dono: "não toastar resultado zero"). O mesmo texto
> repetido não empilha: o aviso que já está na tela renova e vira o mais novo.

## L58-60 (em `MessageSystem:update`, junto a `local warnedKind = {}`)

> Cor do TEXTO por tipo (dono, Out/2026: "coloque cores diferentes como
> era antes"): ouro = dinheiro, verde = cura/ganho, vermelho = perigo,
> laranja = aviso de regra, azul = informação, violeta = orbe/magia.

## L80-85 (em `accentFor`, junto a `function MessageSystem:layout()`)

> Geometria dos toasts para a janela atual (pura: o teste/captura confere).
> ZONA: coluna esquerda, do pé do quadro de coringas (31.8% da altura — era
> o y=244 fixo em 768) até o topo da zona da mão (62%). Escala com a altura
> como pausa/fim de run; o texto QUEBRA dentro da placa em vez de correr
> pela tela (antes: texto cru 12px em x=10, sem fundo, ilegível sobre o
> cenário claro).

## L97-98 (em `MessageSystem:layout`, junto a `local okGS, GS = pcall(require, "src.scenes.GameplayScene")`)

> nunca por cima do quadro de coringas (tela baixa — Steam Deck com a
> escala de UI em 125% — o quadro passa dos 31.8% da altura)

## L106-107 (em `MessageSystem:layout`, junto a `local items = {}`)

> mais NOVAS embaixo (ordem de chegada); se a zona encher, as mais
> antigas saem primeiro (ficam fora do layout, não por cima da mão)

## L111-112 (em `items`, junto a `if m._wrapFont ~= font or m._wrapW ~= wrapW then`)

> quebra cacheada por mensagem (o draw roda todo quadro; getWrap
> alocava uma tabela nova por aviso por quadro)

## L135-136 (em `items`, junto a `function MessageSystem:draw()`)

> Texto colorido com contorno de tinta (8 direções), SEM placa: a placa
> escura de antes pesava a coluna e apagava a cor do tipo.

## L147-148 (em `MessageSystem:draw`, junto a `local age = self.messageDuration - m.duration`)

> entrada: desliza nos primeiros 0,18s DENTRO da margem; fade junto.
> Com reducedMotion aparece no lugar, a informação é a mesma.

