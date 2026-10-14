---
name: code_notes/tools/test_intro_tube.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_intro_tube.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_intro_tube.lua`

Origem: `tools/test_intro_tube.lua` em `7dbdb60d` (3 de 15 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local TK = require("tools.testkit")`)

> tools/test_intro_tube.lua
> Trava da ABERTURA "página e televisor" (src/scenes/IntroTube.lua):
> 1. fases page -> dive -> done no tempo da tabela IntroTube.T, com o
> título e o subtítulo datilografados por inteiro antes do mergulho;
> 2. a geometria do mergulho enche a janela com a ABERTURA do tubo (não
> com o gabinete) em 6 tamanhos de janela;
> 3. pular (tecla/clique) termina na hora e chama onDone uma vez;
> 4. reducedMotion: texto inteiro imediato, sem fase dive, termina;
> 5. draw em todas as fases sem erro (com e sem canvas);
> 6. BootScene com intro ligada passa pela fase "intro" antes de "loading"
> e chama onTubeOn exatamente uma vez; com intro desligada chama direto;
> 7. o Menu desenha SEM a fita ticker (removida a pedido do dono).
> love . test_one test_intro_tube

## L27-28 (em `M.run`, junto a `local prevData = IntroTube.DATA_PATH`)

> as secoes 1-5 sao do televisor do shader: sem a arte do computador,
> mesmo que o jogo ja tenha src/data/intro_computer.lua instalado

## L194 (em `onComplete`, junto a `local Menu = require("components.Menu")`)

> ===== 7. menu SEM fita (dono, 13/Out: "tira isso, deixa sem nada") =====

