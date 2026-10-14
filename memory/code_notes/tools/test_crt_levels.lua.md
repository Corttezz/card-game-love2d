---
name: code_notes/tools/test_crt_levels.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_crt_levels.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_crt_levels.lua`

Origem: `tools/test_crt_levels.lua` em `7dbdb60d` (2 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-22 (junto a `local TK = require("tools.testkit")`)

> tools/test_crt_levels.lua
> CRT em NÍVEIS (Out/2026): Desligado / Baixo / Normal, lembrado em
> settings.crtLevel; texto legível em 1080p e 1440p.
>
> Dono: "esses efeitos CRT" — o tubo cheio (0.75) era o único estado além
> de desligado, e a aberração cromática era medida em fração da tela: em
> 1440p virava 1,5-6 px e borrava o texto.
>
> O que trava aqui:
> • setLevel/getLevel/nextLevel: ordem off → low → normal (Normal + 1
> dá a volta pro Off — Enter no Normal desliga, como o toggle antigo);
> • levelFromSettings: crtLevel novo; save antigo crtShader=false → off;
> • screenToContent é passthrough com o CRT desligado;
> • o shader compila e endScene(target) renderiza num canvas (sem janela);
> • ABERRAÇÃO EM PIXELS: uma linha branca de 2 px no centro, pela lente,
> ganha franja de cor de no máximo 4 px — EM 1080p E EM 1440p (mesma
> largura em px, não em fração da tela); no nível Baixo, ≤ 2 px;
> • Desligado: a lente é identidade (pixel a pixel);
> • o chuvisco (TvOsd) e a varredura do botão do menu só existem com o
> tubo ligado; main.lua aplica o nível salvo; SaveManager tem default.
>
> love . test_one test_crt_levels

## L51-55 (em `throughTube`, junto a `local function fringe(data, y, x0, x1)`)

> Franja colorida numa linha horizontal: quantos pixels têm R e B
> divergentes (extensão do borrão) e o MAIOR desvio |R−B| (intensidade).
> Uma linha de 2 px com deslocamento sub-pixel já pinta os 2 px dela e 1
> de cada lado (filtro linear) — por isso a extensão mede o "até onde" e a
> intensidade mede o "quanto" (o nível Baixo cai na intensidade).

