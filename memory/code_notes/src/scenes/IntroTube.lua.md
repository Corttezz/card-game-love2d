---
name: code_notes/src/scenes/IntroTube.lua
description: Comentários com decisão/regra/histórico colhidos de src/scenes/IntroTube.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/scenes/IntroTube.lua`

Origem: `src/scenes/IntroTube.lua` em `7dbdb60d` (15 de 39 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local Palette     = require("src.ui.Palette")`)

> src/scenes/IntroTube.lua
> ABERTURA "a página e o televisor" (Out/2026, pedido do dono a partir de
> heyparker.ai: "gostei do começo: a tela, a fita; quero o nosso visual").
>
> Antes do boot de sempre (sintonia do canal, lua, redemoinho), a tela é
> uma PÁGINA de pergaminho com o NOSSO televisor pequeno no meio (o mesmo
> gabinete/tubo do crt.glsl, renderizado numa tela menor por
> CRTShader.renderTube). Na tela do televisor o título e o subtítulo são
> DATILOGRAFADOS com o blip do corvo e um cursor piscando; depois a câmera
> MERGULHA no tubo (o televisor cresce até a abertura do tubo encher a
> janela) e, nesse instante, o boot normal assume: o CRT de tela cheia liga
> (powerOn) e a sintonia começa dentro do tubo.
>
> Regras: qualquer tecla/clique pula; reducedMotion = texto inteiro na
> hora, sem mergulho (corte); sem shader (driver sem GLSL) o televisor é
> uma moldura plana de pixel art, AVISADA uma vez. Nada aqui é regra de
> jogo: só coreografia. Tempos em IntroTube.T (segundos).

## L37-43 (em `IntroTube.T`, junto a `IntroTube.DATA_PATH = "src/data/intro_computer.lua"`)

> ARTE DO COMPUTADOR (dono, Out/2026: "gerar literalmente o computador do
> site da Parker, nas nossas cores; o primeiro quadro é ele e depois dá
> zoom"). Quando src/data/intro_computer.lua existe (gerado por
> tools/intro_computer_import.py, ver docs/plan/intro-computer-prompt.md),
> a abertura desenha ESSA arte no lugar do televisor do shader: o tubo
> (sem o gabinete do shader, só a abertura curva com scanlines) vai DENTRO
> do retângulo da tela da arte e o mergulho é na tela.

## L46-48 (em `IntroTube.T`, junto a `IntroTube.SLOT_FALLBACK = { x = 0.52, y = 0.80, w = 0.34, h = 0.03 }`)

> A FENDA do disquete: no site uma mão enfia um disquete antes do mergulho;
> aqui uma CARTA (o verso, src/ui/CardBack) entra pela fenda. `slot` vem
> do importador (faixa escura abaixo da tela); sem ele, esta fração da arte.

## L108-110 (em `warnOnce`, junto a `function IntroTube.init(opts)`)

> ===================================================================
> Estado
> ===================================================================

## L133-134 (em `IntroTube.phase`, junto a `function IntroTube.endedWithDive() return S.dove == true end`)

> true quando a abertura terminou PELO mergulho (não por pular nem por
> reducedMotion): o CRT do jogo pode ligar já aceso, sem o apagão.

## L154-156 (em `IntroTube.skip`, junto a `local function blip()`)

> ===================================================================
> Update: datilografia + mergulho
> ===================================================================

## L216-222 (em `IntroTube.update`, junto a `function IntroTube.geometry(W, H)`)

> ===================================================================
> Draw
> ===================================================================
> Geometria do televisor na janela (px): canvas do tubo e escala do mergulho.
> Com a ARTE: `art` = escala da imagem, `ax/ay` = canto dela, `sx/sy/sw/sh`
> = a tela em px da janela; o tubo é renderizado no tamanho da tela mais o
> gabinete do shader (que fica de fora, recortado).

## L233-234 (em `IntroTube.geometry`, junto a `local B = IntroTube.BEZEL_PX`)

> fim do mergulho: a TELA da arte cai EXATAMENTE na abertura do CRT
> de tela cheia (janela menos o gabinete de B px), eixo a eixo

## L249-250 (em `slot`, junto a `local B = IntroTube.BEZEL_PX`)

> a ABERTURA do tubo (canvas menos o gabinete) tem que encher a janela
> no fim do mergulho: escala pela maior razão (cobre, não cabe)

## L279-281 (em `sub`, junto a `local function textAlpha()`)

> O texto some ANTES do zoom (dono, Out/2026: "antes do zoom apague o que
> tá escrito"): com a arte, apaga junto com o flash da carta; no televisor
> do shader, nos últimos 0,3 s da espera. No mergulho a tela está vazia.

## L296-297 (em `textAlpha`, junto a `local function drawTubeContent(tw, th, alpha)`)

> O programa que passa na tela do televisor: fósforo escuro + texto
> datilografado + cursor. Em px do canvas do tubo.

## L323-325 (em `drawTubeContent`, junto a `local inner = tw - 2 * IntroTube.BEZEL_PX - 28`)

> o subtítulo cabe na ABERTURA do tubo: encolhe a fonte e, se ainda
> não couber, quebra em linhas (a largura do texto completo decide a
> quebra, pra não pular de linha enquanto datilografa)

## L351-355 (em `drawTubeContent`, junto a `local function drawInsertCard(G, W, H)`)

> A CARTA entra na fenda do disquete (o disquete do site, no nosso visual):
> vem do canto inferior direito já girada, endireita no caminho e some pela
> FENDA. O truque é um recorte na linha da fenda: tudo acima dela está
> "dentro" do gabinete, então a carta desaparece conforme sobe. Em px da
> janela (durante a fase insert o computador está em escala 1).

## L470-471 (em `IntroTube.draw`, junto a `local B = IntroTube.BEZEL_PX`)

> a ARTE do computador: tubo (recortado, sem gabinete) dentro da
> tela, a imagem por cima; tudo escala em torno do centro da tela

## L474-481 (em `IntroTube.draw`, junto a `local sxK = pop * (1 + (G.sEndX - 1) * dive)`)

> MERGULHO (dono, 13/Out: "a transição da borda do zoom para a do
> jogo tem que ficar melhor"): a tela da arte termina EXATAMENTE na
> abertura do CRT de tela cheia: escala por eixo (a tela 4:3 vira a
> janela 16:9 no caminho), o centro da tela caminha até o centro da
> janela e o tubo é renderizado na resolução FINAL (W×H) e encolhido
> até a tela, de modo que o último quadro do mergulho é, pixel a
> pixel, o primeiro do CRT do jogo (que liga já aceso, sem apagão:
> BootScene._tubeOn(seamless)).

