---
name: code_notes/src/data/boss_cinematics.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/boss_cinematics.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/boss_cinematics.lua`

Origem: `src/data/boss_cinematics.lua` em `7dbdb60d` (13 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-101 (junto a `return {`)

> src/data/boss_cinematics.lua
> CINEMÁTICAS DE CHEFE — dados puros (sem lógica), lidos por
> src/ui/BossCinematic.lua.
>
> Ordem fixada pelo dono (Out/2026): a porta do castelo abre (cerimônia já
> existente do WorldRoad) → o SALÃO abre VAZIO (chefe ausente, HUD escondido)
> → a entrada toca DENTRO do salão, com o cenário do próprio salão → nome do
> chefe → HUD → luta. Na morte: colapso em câmera lenta, luz saindo dos
> olhos, rajada de penas/corvos, dessaturação breve, o corpo fica no salão e
> SÓ DEPOIS entram os espólios.
>
> FORMATO: por chefe (spriteId), `intro` e `death` são LISTAS de passos. Cada
> passo tem `kind` e `dur` (segundos que o passo ocupa antes do próximo; 0 =
> dispara e segue). Efeitos com envelope próprio (gust, desat, slowmo)
> continuam vivos depois que o passo passou — o `dur` é só o COMPASSO da
> sequência. Tempos em segundos; posições em FRAÇÃO da arte do salão
> (400×256) quando dizem `u`/`v`, ou em fração da altura do corpo quando dizem
> `k`.
>
> Passos de ENTRADA:
> dark   { to }                 escurece/clareia o salão até `to` (0..1)
> eyes   { u, v, blinks={t..}, size } dois olhos de brasa abrem no escuro,
> piscam nos instantes da lista, apagam no fim
> flyby  { from="left"|"right", v, ghosts, arc, land, lights }
> o chefe VARRE o salão de um lado a outro
> (cópias fantasmas atrás = rastro de
> movimento, vento, penas, luminárias tremem);
> `land=true` termina NO palco (pouso);
> `lights` = valor de `dark` ao fim do passo
> land   { shake, dust, crows } impacto: tremor, poeira, corvos espantados,
> o chefe passa a ser desenhado pelo jogo
> title  { }                    cartão com nome + epíteto (i18n
> boss_cinematics.<id>.*)
> hud    { }                    HUD/mão voltam (fim da entrada)
>
> land   também aceita: `ring` (ice/frost/lava/spores/petal: cores da
> onda de choque), `particle` (feather/shard/ember/spore/petal) +
> `burst` (quantas), `sound` (impacto), `clip` (one-shot no palco;
> default "land"), `crows` (0 = sem corvos nem penas assentando)
>
> Passos de ENTRADA por ELEMENTO (os outros 5 chefes, Out/2026):
> runes      { n }                      runas no chão acendem uma a uma;
> o círculo fecha e fica até o `land`
> rise       { clip, storm }            chefe SOBE do piso (recorte na linha
> do chão, fagulhas do elemento, loop
> `storm`); termina visível no palco
> door_burst { u, v, debris, shake, lights }  portão do fundo estoura
> firewall   { v, h, hold }             cortina de chamas em bandas; `hold`
> = quanto fica depois do passo
> chains     { }                        as correntes do salão (`bonds` do
> chefe) nascem FROUXAS: ele entra
> arrastando e elas esticam no `land`;
> na luta arrebentam por `breakAt`
> walk_in    { clip, stomp, sound }     chefe cresce do fundo (backY) até o
> palco; `stomp` = tremor por passo
> whiteout   { peak }                   nevasca (5 degraus, teto 0.8)
> silhouette { clip, far, strike, strikeClip, hitDelay }
> vulto preto SÓLIDO com borda fria
> dentro do branco: longe e pequeno
> (`far`), cresce andando; em `strike`
> bate o cajado ainda em silhueta
> land.clip=false / land.hit=false      sem clip / sem impacto de tela
> settle     { }                        nevasca cai; chefe visível
> heartbeat  { rate, boost, hold }      pulses do salão aceleram + vinheta
> roots      { n, u, v }                raízes rastejam do ponto (u,v)
> { n, from="walls", grasp } ...ou descem das bocas pintadas do
> salão (InteriorFX rootMouths) e
> AGARRAM o corpo; retraem no `land`
> assemble   { block }                  o corpo se MONTA de blocos do próprio
> sprite puxados do chão, pés → cabeça
> land.cracks = true                    o chão racha em volta do pé
> eclipse    { u, v, to }               disco cobre a abertura + coroa
> descend    { clip, u, v, backlit, lights }  chefe desce de (u,v) ao palco
> RAINHA v2 (chefe final, frente rainha-eclipse, Out/2026):
> omen       { to, steps }              pressentimento: a luz do vão morre
> em degraus, o eclipse vira íris, a
> coroa sangra, cinzas caem
> unveil     { clip, u, v }             manifestação: olhos demais no escuro,
> silhueta em casulo que se abre em
> contraluz, sombra maior que ela
> coronation { clip, cadence }          cartão único: letras uma a uma com
> sino, halos quebrados, stinger
>
> Passos de MORTE:
> slowmo { scale, release }     EnemyRenderer em câmera lenta por `dur`,
> volta ao normal em `release` s
> burst  { n|feathers, crows, particle, sound }  rajada a partir do corpo
> desat  { peak, rise, fall }   dessaturação da cena: sobe em `rise`,
> segura, cai em `fall`
> lava   { }                    poça de lava cresce sob o corpo (tirano)
> crumble { delay, roots, block } raízes agarram e soltam; o corpo desaba
> em pedaços que viram monte e esporos (colosso)
> dawn   { u, v }               luz morna volta na abertura (rainha)
> hold   { }                    o corpo fica no salão; espólios esperam
>
> Todo chefe tem `palette` (body/glow/ember/flash/ghost/rim/particle/
> particle2): névoa, brilhos, flash e partículas usam ela. O runner avisa
> `kind` desconhecido e segue (fallback silencioso é proibido). Chefe SEM
> roteiro aqui ganha a entrada genérica (BossCinematic.GENERIC).
>
> `reduced` = versão curta pra reducedMotion (mesma linguagem, sem varrer).

## L104-106 (junto a `carrion_king = {`)

> ATO 1 — Rei da Carniça: corvo-rei que paira. Olhos de brasa acendem
> no vão âmbar atrás do trono (pulses[1] do salão 1: x 182..218,
> y 78..178 da arte), três passagens em rasante, pouso no palco.

## L108-110 (em `carrion_king`, junto a `intro = {`)

> v3 (dono, ao vivo): olhos maiores que abrem devagar e acompanham,
> passagens cada vez mais PERTO (longe → colada na câmera → pouso),
> clips PixelLab `dive`/`land`/`roar` quando instalados, som em tudo.

## L125-126 (em `blinks`, junto a `introReduced = {`)

> reducedMotion: olhos (uma piscada), um rasante curto que pousa,
> impacto sem tremor forte, cartão mais curto.

## L150-154 (em `deathReduced`, junto a `tower_lich = {`)

> ATO 2 — Lich da Torre (flutua): o salão GELA. O círculo rúnico do
> chão acende runa por runa (névoa branco-azul sobe), e o lich SOBE do
> piso dentro de uma tempestade de geada, cajado por último (clip
> `rise`), recortado na linha do chão. Impacto = o círculo completa +
> onda de gelo. Morte: se desfaz em geada (lascas) e esfria a cena.

## L192-197 (em `deathReduced`, junto a `abyss_tyrant = {`)

> ATO 3 — Tirano do Abismo (pisa): o portão-caveira do fundo ESTOURA
> (lascas, brasas, flash), uma PAREDE DE FOGO INFERNAL sobe atrás do
> palco, correntes caem das paredes e ele ATRAVESSA o fogo andando (clip
> `stride`, cresce do fundo até o palco, o chão treme a cada passo).
> Impacto = pisada: tremor forte, onda de lava. Morte: afunda na lava
> (poça de brasa cresce sob o corpo, bolhas, câmera lenta quente).

## L204-211 (em `particle`, junto a `bonds = {`)

> CORRENTES DO SALÃO (v2, Out/2026; dono: "as correntes saem do céu,
> poderiam ser parte da fase, ligadas a ele"): cada corrente vai de
> uma âncora PINTADA do castle_hall_3 (InteriorFX.HALLS[3].chainAnchors)
> a um ponto do corpo dele (grip = fração do canvas do sprite: pulsos
> e pescoço). Ele entra arrastando, elas esticam no pouso; na luta
> arrebentam uma a uma nos limiares de vida (`breakAt`; "enraged" =
> o ENFURECIDO de 30% que o jogo já tem) e, todas rompidas, ele está
> solto. Só leitura: nenhum número de dano/vida muda.

## L255-260 (em `deathReduced`, junto a `winter_monarch = {`)

> ATO 4 — Monarca do Inverno (pisa): NEVASCA. O salão vira branco em
> 3 degraus de dither, o vento uiva, os braseiros azuis quase apagam; a
> silhueta escura do monarca aparece DENTRO do branco, cada vez mais
> nítida, e a nevasca assenta revelando ele já no palco. Impacto = o
> cajado bate no chão (clip `roar`): cristais erguem do piso, onda de
> geada. Morte: estilhaça em cristais.

## L267-274 (em `particle`, junto a `intro = {`)

> v2 (Out/2026, dono: "a silhueta na nevasca poderia durar mais e
> ficar mais marcada"): a fase de silhueta vai de 1,2 s pra 3,8 s —
> vulto preto SÓLIDO com borda fria de 1 px, longe e pequeno no
> branco (`far`), cresce andando (clip `walk`), o cajado bate uma
> vez AINDA em silhueta (`strike` + clip `roar`: flash frio, onda de
> geada, lascas) e só então a neve assenta e a cor entra (`settle`).
> O `land` que vem depois é a revelação (sem segundo golpe: clip e
> impacto de tela desligados).

## L310-319 (em `deathReduced`, junto a `rot_colossus = {`)

> ATO 5 — Colosso Pútrido (pisa). v2 (Out/2026, dono: "do nada
> surgindo, não fez sentido"): o SALÃO É ELE. O coração de raízes do
> fundo acelera (pulses do salão 5 + vinheta por batida), raízes descem
> das PAREDES e do teto (`roots from=walls`, bocas em InteriorFX.HALLS[5]
> .rootMouths) e agarram o palco; ossos e entulho do chão são puxados e
> se juntam formando a silhueta DE BAIXO PRA CIMA (`assemble`: blocos
> do próprio sprite, pés → tronco → cabeça); as raízes se retraem, ele
> ergue a cabeça (clip `roar` no `land`) e o chão racha em volta
> (`land.cracks`). Morte = o processo ao contrário (`crumble`): raízes
> agarram e soltam, o corpo desaba em pedaços e esporos.

## L348-349 (em `introReduced`, junto a `death = {`)

> morte: sem slowmo do EnemyRenderer — o desabamento em pedaços É a
> câmera lenta (o chefe real fica escondido e volta sob o monte)

## L364-382 (em `deathReduced`, junto a `eclipse_queen = {`)

> ATO 6 — Rainha do Eclipse (flutua), o CHEFE FINAL — v2 (Out/2026,
> frente rainha-eclipse; dono: "algo mais macabro, mais estiloso,
> entradas mais marcantes"). Três atos próprios, ~14 s:
> 1. PRESSENTIMENTO (`omen`): o salão muda antes de ela existir — a luz
> do vão morre em 4 degraus (tique por degrau, silêncio entre eles),
> o eclipse pintado vira uma ÍRIS que olha o jogador, a coroa sangra,
> cinzas começam a cair, névoa magenta.
> 2. MANIFESTAÇÃO (`unveil` + `descend`): olhos demais acendem no escuro
> do vão, a silhueta em casulo de asas (clip `unveil`) se abre em
> contraluz com a sombra no mármore maior que ela e um halo quebrado;
> o `descend` a traz ao palco (silhueta → cor cheia).
> 3. COROAÇÃO (`coronation`): cartão único — letras uma a uma com sino,
> halos quebrados ladeando, stinger coral na última letra.
> LUTA: BossCinematic observa a fase do kit (src/data/enemies.lua, nunca
> alterado) e fecha o eclipse do salão 6 (InteriorFX.setEclipse) + halo
> quebrado nela. MORTE: cinzas que sobem, `dawn` v2 (a luz chega em
> degraus pelo vão, o disco abre num crescente, o mármore acende) e a
> voz dela se apagando (`bossEclipseFade`); o corpo fica no salão.
> Música própria: `musicBossEclipse` (MusicDirector, só no salão dela).

## L400-401 (em `intro`, junto a `introReduced = {`)

> reducedMotion: os três atos continuam (toda a informação), curtos:
> degraus sem íris móvel, casulo sem tremor, letras em cascata rápida.

