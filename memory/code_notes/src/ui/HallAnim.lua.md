---
name: code_notes/src/ui/HallAnim.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/HallAnim.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/HallAnim.lua`

Origem: `src/ui/HallAnim.lua` em `7dbdb60d` (3 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local HallAnim = {}`)

> src/ui/HallAnim.lua
> Movimento PINTADO NO LUGAR dos salões de chefe (Out/2026, dono: "a sala 3
> está muito estática"). Complementa o InteriorFX: em vez de partícula por
> cima, mexe a própria pintura, sempre na grade da arte (400×256, nearest).
>
> flameFrames  as chamas pintadas (retângulos `flames` do salão) ganham N
> quadros: cada linha da chama ondula de lado e as pontas
> sobem/descem, mais forte em cima que na base. Onde a chama
> original sai do lugar, entra a cor do fundo daquela linha
> (nada de chama dobrada).
> flows        cascatas pintadas: faixas claras/escuras ROLANDO pra baixo
> só dentro da máscara de lava (luma alta). Padrão periódico
> em y + 1px por quadro = laço sem emenda.
> shimmer      calor: linhas da arte deslocadas ±1px por um seno — a
> distorção de ar quente sobre os rios de lava.
>
> Tudo é gerado UMA vez por salão (ImageData → Image). O draw só troca o
> quadro (viewport de um quad reaproveitado) — nada alocado por frame.

## L36-39 (em `hash1`, junto a `local function buildFlame(src, r, palette)`)

> Quadros de uma chama pintada, lado a lado num atlas (largura w*N).
> `palette` (opcional): lista de cores {r,g,b} 0..255 que SÃO a chama —
> chama repintada em degraus escuros (fogo-fátuo verde do hall 5) tem
> pixel abaixo do limiar de luma e confundiria com as raízes em volta.

## L92-93 (em `bg`, junto a `local function buildFlow(src, r)`)

> Quadros da lava descendo: faixas por coluna (fase aleatória por coluna)
> dentro da máscara clara da cascata.

