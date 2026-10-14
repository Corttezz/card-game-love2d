---
name: code_notes/shaders/polychrome.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/polychrome.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/polychrome.glsl`

Origem: `shaders/polychrome.glsl` em `7dbdb60d` (7 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-29 (junto a `extern number time;`)

> shaders/polychrome.glsl
> Edition "Polychrome" — iridescencia DENTRO da paleta do grimorio.
>
> POR QUE ESTA VERSAO EXISTE (Set/2026)
> A anterior fazia `phsv2rgb(hue, 0.95, 1.0)` varrendo o espectro INTEIRO e
> substituia ate 60% do pixel por essa cor:
> vec3 rainbow = phsv2rgb(vec3(hue, 0.95, 1.0));
> outRgb = mix(base.rgb, rainbow, strength * 0.6 * ...);
> O resultado eram ciano e magenta em saturacao cheia — as duas cores banidas
> no contrato visual do projeto — cobrindo a ilustracao. Numa tela toda em
> sepia dessaturado, a carta polychrome nao lia como "rara": lia como erro de
> shader, de outro jogo.
>
> A troca NAO e "deixar discreto" -- a primeira tentativa errou pra esse lado
> e ficou MENOS notavel que o Foil, o que e tao errado quanto o neon. Polychrome
> e a edition mais rara e tem de ser a mais eventful em COR das tres (Foil e
> prata fria monocromatica; Negative inverte, diverge em luminancia, mas nao
> anima matiz). O que muda e o vocabulario:
> • a matiz percorre uma RAMPA do grimorio (ambar, ocre, ferrugem, violeta
> profundo, verde-musgo) em vez do circulo de matiz completo;
> • a cor MODULA a arte multiplicativamente em vez de pintar por cima, entao
> toda a estrutura da ilustracao sobrevive — mesma licao que ja tinha
> valido pro foil do sleeve;
> • o brilho viaja numa faixa, que e o que da o "vivo" sem cobrir nada.
>
> Uniforms:
> time     (number) — segundos. Congelado pelo wrapper com reducedMotion: a
> matiz vira gradiente ESTATICO, a carta continua obvia.
> strength (number) — 0..1 (default 0.7)

## L41-43 (junto a `vec3 grimoireRamp(float t) {`)

> Rampa ciclica de 5 ancoras do grimorio. Os valores saem de src/ui/Palette.lua
> (AGED_GOLD_LIGHT, RUST, MOSS) mais um violeta profundo e um ocre derivados
> na mesma familia dessaturada.

## L70-72 (junto a `vec2 cuv = uv - 0.5;`)

> Matiz varia no ESPACO (diagonal + radial) e no TEMPO. O termo radial faz
> a cor girar em torno do centro da carta, nao so escorrer de canto a
> canto — e o que da a sensacao de superficie curva, de oleo.

## L75-80 (junto a `float t = (uv.x * 0.55 + uv.y * 0.35 - r * 0.45) * 2.1 + time * 0.13;`)

> O fator 2.1 e o que faz MAIS DE UMA VOLTA da rampa caber na carta: com o
> termo espacial pequeno so ~metade do ciclo aparecia de uma vez, so os
> tons quentes, e a carta lia como "versao ambar da limpa" -- menos
> notavel que o Foil, que e o erro oposto ao que esta versao corrige.
> Com mais de um ciclo, ambar, violeta e musgo convivem na mesma carta e a
> iridescencia fica inequivoca sem nenhuma cor sair da paleta.

## L84-98 (junto a `vec3 tinted = base.rgb * (0.30 + 1.60 * ramp);`)

> MODULACAO MULTIPLICATIVA: a arte manda na luminancia, a rampa manda na
> matiz. Como e multiplicacao, preto continua preto e o desenho nunca
> some — o oposto do mix() que substituia o pixel.
> A AMPLITUDE do multiplicador (0.30..1.90) e o que separa Polychrome de
> Foil: e o contraste entre as zonas da rampa, nao a saturacao da cor, que
> faz a superficie parecer oleo.
> Medido em `love . test_one preview_editions` (recortes 1:1 vs a carta
> limpa, na warrior_defend):
> Foil        desvio 18.6   correlacao de luminancia  0.955
> Polychrome  desvio 24.1   correlacao de luminancia  0.932
> Negative    desvio 89.1   correlacao de luminancia -0.595
> Correlacao 0.93 = a estrutura do desenho sobrevive inteira (a versao
> antiga substituia o pixel e destruia isso). Negative desvia MUITO mais
> porque inverte de proposito -- ele diverge em LUMINANCIA; o Polychrome e
> o mais eventful em COR, que e o eixo dele.

## L102-104 (junto a `float diag = uv.x * 1.25 + uv.y * 0.85 - time * 0.30;`)

> Faixa de brilho viajando na diagonal. Mais larga e mais forte que a do
> foil: e ela que faz o Polychrome ser o mais notavel dos tres sem
> precisar de cor gritada.

## L110-111 (junto a `vec3 glint = mix(grimoireRamp(t + 0.12), vec3(1.0), 0.45);`)

> O brilho da faixa e da propria rampa, clareado — nao branco puro, senao
> vira "reflexo de plastico" em vez de metal colorido.

