---
name: code_notes/tools/test_holo_shader.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_holo_shader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_holo_shader.lua`

Origem: `tools/test_holo_shader.lua` em `7dbdb60d` (2 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local TK = require("tools.testkit")`)

> tools/test_holo_shader.lua
> O reflexo das cartas raras/lendárias EXISTE, é ESTÁTICO em repouso, cresce
> com o hover e NUNCA lava a arte (Out/2026).
>
> Histórico: src/ui/HoloShader.lua nasceu em Abr/2026 (a182eae) com um
> `load()` que ninguém chamava — seis meses de doc descrevendo um efeito
> invisível. Ao ligar, a v1 do shader era um arco-íris na carta inteira,
> animado o tempo todo: lavava a cor da arte e punha a mesma listra em 41
> cartas — contra as regras do dono ("idle = estático", "foil que lava a cor,
> nunca"). A v2 (shaders/holo.glsl) é um reflexo no ARO + brilhos da arte,
> aditivo, com varredura em degraus só no hover; rara prata, lendária ouro.
>
> O que trava aqui:
> • main.lua carrega o HoloShader no boot (conferido no FONTE, porque o
> dispatcher de testes roda ANTES do bloco de shaders do love.load);
> • load() compila shaders/holo.glsl de verdade;
> • gate: lendária 0.08 em repouso (estática: time=0) → 0.5 no hover;
> rara 0 em repouso (carta CRUA, sem shader) → 0.25 no hover; comum
> nada; edition holo numa comum = lendária;
> • pixel a pixel: força 0 = textura idêntica; em repouso a lendária e a
> rara no hover deixam o MIOLO da ilustração intocado (só aro/brilhos).
>
> love . test_one test_holo_shader

## L162-164 (em `love.graphics.setShader`, junto a `local washed = 0`)

> com anim=1 a faixa existe; fora dela o miolo nao pode mudar — e na
> faixa so os brilhos (lum > 0.74). Conta pixels do miolo que mudaram
> E nao eram claros: tem que ser zero (nenhum hue-shift sobre a arte).

