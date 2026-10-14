---
name: code_notes/src/ui/Narrator.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/Narrator.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/Narrator.lua`

Origem: `src/ui/Narrator.lua` em `7dbdb60d` (13 de 53 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local Narrator = {}`)

> src/ui/Narrator.lua
> O NARRADOR do tutorial (Out/2026): PENA, o corvo do grimório.
>
> Pedido do dono: "muito mais parecido com o Balatro — um personagenzinho
> falando, letras enchendo a tela com um blip tipo Sans (Undertale), a tela
> FOCANDO no que ele explica". Este módulo é só APRESENTAÇÃO; o roteiro, os
> gatilhos e a entrada moram em src/systems/Tutorial.lua.
>
> Peças:
> CORVO     sprite PixelLab (assets/sprites/narrator/, gerado por
> tools/pixellab_raven.py): pose base + bico aberto + olho fechado,
> cada um com variante de RESPIRO (cabeça 1px acima). Bico abre a
> cada blip; pisca a cada 2,5-5s; pulinho ao começar uma fala.
> BALÃO     pergaminho com o nome do narrador, texto MÁQUINA DE ESCREVER
> (pausa na pontuação) e *ênfase* em sangue; rodapé com os glifos
> do dispositivo (continuar / pular) — dentro do balão, nunca
> numa tarja de rodapé.
> VOZ       blips sintetizados (tools/synth_narrator_blips.py →
> audio/sfx/narrator/blip_N.wav), registrados no AudioManager no
> grupo sfx (respeitam o volume de efeitos), sorteados sem repetir.
> FOCO      véu escuro com um RECORTE no objeto explicado (quatro
> retângulos — sem stencil: o canvas do CRT não tem um), moldura
> dourada pulsando e uma seta que quica apontando pro recorte.
> LUGAR     o painel escolhe o canto que NÃO cobre o recorte nem a TopBar
> (`Narrator.layout`, puro — os testes validam por tamanho).

## L43-45 (em `Narrator`, junto a `local frames`)

> ===================================================================
> Recursos (preguiçosos; falta de arquivo AVISA, nunca cala)
> ===================================================================

## L70-75 (em `frames`, junto a `local voice = nil            -- { [i] = Source } ou nil (solto)`)

> VOZ: pool FIXO de fontes, uma por variação de blip, criadas uma vez e
> reusadas (stop()+play()) — nada de fonte por caractere. Não passa pelo
> pool do AudioManager de propósito: lá cada som cresce até 8 clones e
> nunca devolve (6 variações × 8 = 48 vozes presas do OpenAL só pro corvo).
> O volume segue os grupos do AudioManager (master × sfx) a cada blip, e
> `Narrator.releaseVoice()` solta tudo quando a conversa acaba.

## L111 (em `Narrator.releaseVoice`, junto a `function Narrator.voiceCount()`)

> Quantas fontes o corvo segura agora (teste: nunca passa de BLIP_COUNT).

## L119-122 (em `Narrator.voiceCount`, junto a `local function tokenize(text)`)

> ===================================================================
> Texto rico: *ênfase* + quebra de linha por palavra + revelação por letra
> ===================================================================
> Devolve lista de palavras { text, emph, space } (space = espaço antes).

## L158 (em `cur`, junto a `function Narrator.wrap(text, font, width)`)

> Quebra em linhas. Cada linha = lista de pedaços { text, emph, chars }.

## L187-189 (em `lines`, junto a `local S = {`)

> ===================================================================
> Estado da fala
> ===================================================================

## L274-276 (em `Narrator.update`, junto a `local function fonts(k)`)

> ===================================================================
> Medidas e lugar
> ===================================================================

## L299-302 (em `footItemW`, junto a `function Narrator.measure(text, k, W, footer)`)

> Mede o balão pra um texto (largura máx. limitada pela tela). footer =
> { left, right }: se os dois não cabem lado a lado, o rodapé EMPILHA
> (continuar em cima, à direita; pular embaixo, à esquerda) — nunca se
> sobrepõem.

## L342-346 (em `overlap`, junto a `function Narrator.layout(size, W, H, k, spot, avoid, keep)`)

> Posições candidatas do painel (corvo + balão), em ordem de preferência:
> canto inferior esquerdo (o Jimbo do Balatro mora ali), inferior direito,
> superior esquerdo/direito (abaixo da TopBar) e meio esquerdo/direito.
> spot = recorte (ou nil); avoid = zonas proibidas (TopBar).
> Devolve { panel, raven, bubble, flip, side } — puro.

## L419-421 (em `errs`, junto a `local function setC(c, a)`)

> ===================================================================
> Desenho
> ===================================================================

## L493 (em `frameName`, junto a `local quadCache = {}`)

> Quads livro/pássaro (todos os quadros têm o mesmo tamanho: criados 1x).

## L530-531 (em `Narrator.drawRaven`, junto a `function Narrator.drawBubble(b, size, alpha, k, flip, footer)`)

> Balão: pergaminho + nome + texto revelado + rodapé (continuar/pular).
> footer = { left = {glyph, label}, right = {glyph, label}, actionLabel }

