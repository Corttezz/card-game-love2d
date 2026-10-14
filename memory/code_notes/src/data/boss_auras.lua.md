---
name: code_notes/src/data/boss_auras.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/boss_auras.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/boss_auras.lua`

Origem: `src/data/boss_auras.lua` em `7dbdb60d` (11 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-43 (junto a `return {`)

> src/data/boss_auras.lua
> ============================================================================
> AURA ASSINATURA DE CADA CHEFE — dados puros, desenhados por src/ui/BossAura.
> ============================================================================
> Queixa do dono (Out/2026): "o boss 2 é meio estático flutuando, não
> intimida"; "o boss 1 não tem nada de especial". Um chefe precisa de algo
> que só ELE tem em volta dele. Cada entrada abaixo é o tema do chefe dito
> em camadas baratas de pixel art (retângulos inteiros na grade do PIXEL DA
> ARTE do sprite — nunca círculo liso, nunca partícula subpixel).
>
> Unidades (todas no espaço do CANVAS DO IDLE do chefe — olhe o PNG com
> régua antes de mexer, doutrina do projeto):
> u, v      fração da largura/altura do canvas (0,0 = topo-esquerda)
> r, ru, rv raio em PIXELS DA ARTE (glow) ou fração (órbita: ru de w, rv de h)
> vx, vy    velocidade em pixels da arte por segundo
> area      { u0, v0, u1, v1 } de onde o emissor nasce
>
> Camadas:
> glows   brilho posterizado aditivo PEQUENO nos pixels que já são luz na
> arte (raio <= 8 px da arte: maior que isso vira "bola de luz",
> que o dono rejeitou nos salões)
> (mesmas âncoras de enemy_emissives — no salão o LightEngine não
> tem lightmap e o olho/orbe pintado ficava apagado)
> orbit   (ou `orbits`, lista) n corpos girando numa elipse; metade de trás desenha ATRÁS do
> sprite e a da frente NA FRENTE (regra de profundidade)
> emit    emissores (pena, alma, fagulha, fumaça, esporo, gota, pétala,
> sopro); `back = true` desenha atrás do sprite; `big` = chance
> de nascer com 2 pixels da arte (variação de tamanho)
> px      tamanho do BLOCO (pixels da arte por pixel do efeito). Chefe a
> ~2x na tela tem pixel da arte de ~2px: efeito de 1 bloco virava
> cisco invisível (medido nas salas a 1024x768). 2 = legível e
> ainda múltiplo inteiro da grade do sprite.
> floor   círculo rúnico no chão (só o lich: diz "ele paira SOBRE algo")
> corona  coroa de raios atrás da cabeça (só a rainha; `disc = false`
> tira o disco — a sala 6 já tem o eclipse pintado no fundo)
> (SEM contorno colorido: existiu e saiu — "a arte já tem o contorno
> dela", dono, Out/2026)
> glint   brilho que percorre a borda externa da silhueta (asas da rainha)
>
> `reducedMotion`: órbitas congelam, emissores param, coroa/círculo param de
> girar — MOVIMENTO sai. Brilho, círculo e coroa ficam: são a identidade do
> chefe (informação), não enfeite.
> ============================================================================

## L46-47 (junto a `carrion_king = {`)

> Ato 1 — Rei-carniça. Corvos rondando, penas caindo, coração de brasa
> batendo em DUAS pancadas (tum-tum) no peito de costelas.

## L70-72 (em `color`, junto a `tower_lich = {`)

> Ato 2 — Lich da Torre. Paira SOBRE um círculo rúnico que gira no chão,
> o orbe do cajado pulsa com faíscas arcanas em órbita e almas sobem da
> barra do manto.

## L100-101 (em `color`, junto a `abyss_tyrant = {`)

> Ato 3 — Tirano do abismo (o dono gostou: só realça). Fagulhas do
> inferno saindo da fornalha do peito e fumaça rasteira nas garras.

## L117-118 (em `color`, junto a `{ kind = "feather", px = 1, rate = 4, area = { 0.15, 0.20, 0.85, 0.70 },`)

> CINZA escura subindo: a sala 3 é lava laranja — fagulha
> laranja some no fundo, cinza preta recorta

## L129-130 (em `color`, junto a `winter_monarch = {`)

> Ato 4 — Monarca do inverno. Redemoinho de neve girando em volta,
> sopro gelado de tempos em tempos e névoa rasteira nos pés.

## L155-159 (em `color`, junto a `rot_colossus = {`)

> Ato 5 — Colosso podre. Revisão do dono (Out/2026): "as partículas não
> estão naturais". Agora POUCO e orgânico: moscas em enxame errático
> (agentes perseguindo alvos, não carrossel), gosma que se FORMA nos
> pontos pintados (boca, garras), estica, cai com gravidade e espirra
> uma vez no chão; esporos raros e lentos. Cores foscas, sem pop.

## L174-175 (em `emit`, junto a `vx = { -1, 1 }, vy = { -2.5, -1.0 }, sway = 4, life = { 5.0, 8.0 },`)

> mesmo vocabulário dos esporos do salão 5 (InteriorFX): subida
> de 1-2.5 px da arte/s, cor dessaturada, nada de verde aceso

## L178-179 (em `vx`, junto a `{ kind = "ooze", px = 2, gravity = 95, life = { 8, 8 },`)

> pontos PINTADOS de onde a gosma escorre (px do canvas 141x131,
> lidos com régua): lábio de baixo e pontas das garras

## L187-189 (em `color`, junto a `eclipse_queen = {`)

> Ato 6 — Rainha do eclipse (o dono gostou: realça sem trocar). Disco do
> eclipse com coroa de luz atrás da cabeça, pétalas de sombra no ar e um
> brilho que corre pela borda das asas.

## L191-192 (em `eclipse_queen`, junto a `corona = { u = 0.50, v = 0.24, r = 13, speed = 0.18, disc = false,`)

> coroa de raios curta em volta da CABEÇA, sem disco: o eclipse da
> cena é o da abertura do salão 6 (InteriorFX/arte da sala)

