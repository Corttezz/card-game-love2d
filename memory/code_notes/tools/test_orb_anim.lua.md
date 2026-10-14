---
name: code_notes/tools/test_orb_anim.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_orb_anim.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_orb_anim.lua`

Origem: `tools/test_orb_anim.lua` em `7dbdb60d` (6 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-24 (junto a `local TK = require("tools.testkit")`)

> tools/test_orb_anim.lua
> Trava do loop idle das GEMAS do mago (assets/sprites/orbs_anim/).
>
> O pedido do dono foi "animações bem sutis, bem sutíssimas" numa arte que o
> jogador usa como INFORMAÇÃO: a cor diz o elemento e a pedra fica colada na
> placa do número que ele lê pra decidir. Então "sutil" aqui não é gosto, é
> contrato, e contrato se mede. Cada bloco abaixo é uma forma de a animação
> estragar a leitura, virada do avesso:
>
> silhueta   nenhum pixel opaco vira transparente (nem o contrário) —
> a gema nunca "muda de forma" nem respira de tamanho;
> contorno   pixel escuro (a borda) é idêntico em todo frame — é a borda que
> define a pedra contra o fundo escuro da HUD;
> paleta     nenhuma cor nova em frame nenhum: a paleta do animado é
> subconjunto da do parado, então a COR DO ELEMENTO não pode
> derivar (foi exatamente assim que os frames de PixelLab
> falharam — fogo desbotando pra pêssego);
> emenda     frame 0 e último frame são o PNG estático, pixel a pixel: sem
> pop na volta do loop e sem pop entre parado e vivo;
> dosagem    teto de pixels que mudam no pior frame — é o número que impede
> alguém re-assar com faixa larga e transformar "cintilar" em
> "piscar".
>
> Roda em tools/ como todas as suites: love . test_one test_orb_anim

## L29 (em `M`, junto a `local MIN_LUM = 0.30`)

> Mesmo corte do tools/bake_orb_anim.lua (pixel de contorno nunca é tocado).

## L31-33 (em `M`, junto a `local TETO_DOSAGEM = 0.35`)

> Teto de dosagem: no pior frame, no máximo 35% dos pixels opacos podem ter
> mudado. A safra assada em Set/2026 vai de 16% (sombra) a 29% (sagrado); 35%
> é folga pra ajuste fino sem abrir espaço pra faixa larga de novo.

## L109-112 (em `quadros`, junto a `local function igualAoEstatico(fd)`)

> EMENDA: os dois extremos do ciclo são o PNG parado. Isso é mais forte
> que a regra de "diferença da emenda <= 1,6x a de um passo": aqui a
> diferença é ZERO, então não há emenda a medir — a faixa de luz nasce e
> morre fora da pedra.

## L139-140 (em `igualAoEstatico`, junto a `local parada = OrbRow.gemImageAt("fire", nil)`)

> reducedMotion tira o MOVIMENTO, nunca a INFORMAÇÃO: sem relógio a gema
> continua sendo desenhada, congelada no quadro de repouso.

## L148 (em `igualAoEstatico`, junto a `t:eq("tipo inexistente não tem animação", OrbRow.animationFor("plasma"), nil)`)

> Tipo desconhecido não pode explodir nem inventar animação.

