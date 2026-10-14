---
name: code_notes/shaders/boot_star_twinkle.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/boot_star_twinkle.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/boot_star_twinkle.glsl`

Origem: `shaders/boot_star_twinkle.glsl` em `7dbdb60d` (1 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `extern number t;`)

> shaders/boot_star_twinkle.glsl — CINTILAÇÃO das estrelas (entrada v11).
> Mesmo princípio da carga da lua: redesenha A PRÓPRIA ARTE em blend aditivo,
> mas só os pixels MUITO claros do CÉU (as estrelas) ganham reforço — e cada
> estrela pisca no seu próprio ritmo (fase pseudo-aleatória derivada da
> posição do pixel na ARTE, então a estrela inteira pisca coerente).
> A lua é excluída (ela tem a própria respiração via boot_seal_glow) e as
> colinas também (rim-light dourado não deve piscar).

