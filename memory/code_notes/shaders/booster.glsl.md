---
name: code_notes/shaders/booster.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/booster.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/booster.glsl`

Origem: `shaders/booster.glsl` em `7dbdb60d` (9 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-28 (junto a `extern vec2 booster;`)

> shaders/booster.glsl
> Embalagem iridescente pra booster packs. Implementação própria — combina:
> • Tint azul-prateado base (papel metalizado).
> • Hue iridescente que varia com UV + tempo (multi-banda).
> • Specular sweep diagonal lento.
> • FBM shimmer fino.
> • Mask de dissolve compartilhado (mesma matemática do dissolve.glsl novo).
>
> Não é derivado do código do Balatro.
>
> Uniforms (compat com src/ui/BoosterShader.lua):
> booster        (vec2)   — (phase, _) — phase é fase da animação (segundos)
> dissolve       (number) — 0..1 (0 visível, 1 sumiu)
> time           (number) — segundos absolutos
> texture_details(vec4)   — (off_x, off_y, w, h)
> image_details  (vec2)   — (image.w, image.h)
> shadow         (bool)
> burn_colour_1, burn_colour_2 (vec4)
> sheen          (vec3)   — cor dominante do TIPO de pacote (PackThemes.glow)
> sheen_amt      (number) — INTENSIDADE do foil. 0 = arte crua, sem efeito
> nenhum; 1 = faixa no maximo. Valor por tipo em
> PackThemes (hoje 0.28-0.45: o foil tem que
> ATRAVESSAR e sumir, nao cobrir)
>
> Por que sheen existe: o arco-íris genérico fazia os 5 pacotes brilharem
> IGUAIS, apagando a identidade que a arte de cada um estabelece. Com sheen,
> o Espectral cintila verde e o Arcano cintila roxo — continua sendo papel
> metalizado, mas do metal certo.

## L68-69 (junto a `float dissolveMask(vec2 uv, float dis) {`)

> Mask de dissolve. Mesma ideia do dissolve.glsl mas inline pra não depender
> do shader externo (evita require glsl).

## L88-98 (junto a `float phase = booster.x;`)

> ========================================================================
> FOIL COMO BANDA QUE VARRE, NAO COMO FILME PERMANENTE (Set/2026)
> ------------------------------------------------------------------------
> A versao anterior somava a iridescencia sobre a superficie INTEIRA
> (px.rgb*0.70 + rainbow*0.30) e ainda reduzia o alpha da arte. O efeito
> era um veu constante: o pergaminho do Padrao ficava bege lavado, as
> tiras de couro sumiam, o verde escuro do Espectral virava verde-menta.
> Trocar arte por filtro e o defeito que esta rodada inteira esta
> consertando -- entao agora, na maior parte da superficie e do tempo, o
> pixel sai EXATAMENTE como o artista pintou, e o brilho e uma faixa
> estreita que passa devagar e some.

## L101-106 (junto a `float cyc = fract(phase * 0.11);`)

> A faixa CRUZA e SOME. Um ciclo lento de ~9s: durante os primeiros 30%
> dela o reflexo atravessa a superficie de um canto ao outro; nos outros
> 70% nao existe faixa nenhuma e o pacote esta EXATAMENTE como o artista
> pintou. A versao anterior usava fract() sem pausa, e como a diagonal do
> pacote cobre mais de um ciclo inteiro sempre havia uma faixa em cima
> dele -- ou seja, continuava sendo filme permanente, so que listrado.

## L108-110 (junto a `float sweeping = step(cyc, 0.30);`)

> NAO renomear de volta pra 'act'+'ive': e palavra RESERVADA em GLSL e o
> shader inteiro deixa de compilar (o BoosterShader entao degrada calado
> pra 'sem foil', que foi exatamente como este bug passou despercebido).

## L114-116 (junto a `float band = (1.0 - smoothstep(0.0, 0.16, abs(proj - center))) * sweeping;`)

> ATENCAO: smoothstep(edge0, edge1, x) com edge0 >= edge1 e comportamento
> INDEFINIDO em GLSL -- nesta GPU retorna 0, ou seja, a faixa simplesmente
> nao existia. Sempre bordas crescentes + inversao explicita.

## L120-121 (junto a `float hue = fract(uv.x * 0.6 + uv.y * 0.25 + phase * 0.15);`)

> Matiz da faixa: puxada pra cor do TIPO de pacote. Mantem um residuo de
> variacao de matiz (e isso que faz parecer metal, nao tinta chapada).

## L126-128 (junto a `float lum = dot(px.rgb, vec3(0.299, 0.587, 0.114));`)

> Brilho pega mais no que ja e claro: couro escuro e tinta preta quase nao
> recebem foil na vida real, e e justamente o escurecimento deles que a
> versao antiga comia.

## L142-144 (junto a `float baseAlpha = px.a;`)

> Alpha INTOCADO. A versao antiga multiplicava por (0.78 + 0.22*...), ou
> seja, deixava a arte ate 22% mais transparente contra o fundo -- parte
> do "lavado" vinha daqui, nao so da cor.

