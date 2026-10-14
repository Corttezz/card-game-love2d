---
name: code_notes/tools/test_boss_cinematic.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_boss_cinematic.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_boss_cinematic.lua`

Origem: `tools/test_boss_cinematic.lua` em `7dbdb60d` (12 de 38 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-19 (junto a `local TK = require("tools.testkit")`)

> tools/test_boss_cinematic.lua
> TRAVA da cinemática do chefe (src/ui/BossCinematic + src/data/boss_cinematics).
>
> O que ela fixa:
> * roteiro válido (kinds conhecidos, dur numérico) em todo chefe com dado;
> * ENTRADA: chefe escondido até POUSAR, HUD escondido até o FIM, duração =
> soma nominal dos passos, escuro zerado e relógio do inimigo normal no fim;
> * PULAR: ignorado antes de SKIP_AFTER, salta pro estado final depois;
> * reducedMotion usa o roteiro curto;
> * MORTE: detectada pelo update (chefe no SALÃO com _deathHandled), segura
> espólios (holdsEnd), câmera lenta no EnemyRenderer e volta a 1; não
> reencena a mesma morte; mini-boss NA ESTRADA (isBoss sem salão) não
> vira cinemática; chefe sem roteiro não inicia nada;
> * CENA: a porta (GameplayScene._onBossEntered) inicia a entrada e a cena
> deixa de estar quieta (tutorial espera); o CONTINUAR (ResumeFlow.apply)
> abre o salão SEM entrada; setGame zera tudo;
> * i18n: nome + epíteto + dica de pular nos 5 locales.
>
> love . test_one test_boss_cinematic

## L59-60 (em `runUntilDone`, junto a `local stage = {`)

> palco falso (o GameplayScene passa um por frame; aqui a geometria do
> rasante só precisa de números coerentes)

## L179-180 (em `foot`, junto a `BC.reset()`)

> Continuar no cash out/espólios: o inimigo já nasce morto e a morte
> NÃO se reencena (markDeathSeen, chamado pelo __resumeRunStage)

## L194-195 (em `foot`, junto a `BC.reset()`)

> chefe sem roteiro próprio: entrada GENÉRICA (salão vazio → impacto →
> nome); quem não é chefe não tem entrada

## L239 (em `run.currentNode`, junto a `for code, spec in pairs(BC.SOUNDS) do`)

> ===== 6b. sons da cinemática: todo arquivo declarado existe =====

## L245-248 (em `run.currentNode`, junto a `local ids = {}`)

> ===== 6c. TODO chefe com roteiro: entrada e morte tocam inteiras =====
> (chefe escondido no começo e visível antes do fim, HUD só depois do
> chefe, duração = soma nominal, escuro zerado, relógio normal; morte
> segura espólios e solta; reducedMotion usa o roteiro curto)

## L296-302 (em `ids`, junto a `do`)

> ===== 6d. RAINHA DO ECLIPSE v2 (chefe final, frente rainha-eclipse) =====
> Escala: entrada de 12 a 18 s com os três atos (omen → unveil →
> coronation); reducedMotion curta mas com os três; letras do cartão
> chegam uma a uma e TODAS aparecem; a luta observa a fase do kit e
> fecha o eclipse do salão (InteriorFX.setEclipse) sem virar cinemática;
> a morte deixa a alvorada ligada (persiste no cash out) e o Continuar
> com a rainha morta nasce em alvorada.

## L428-433 (em `hasKind`, junto a `do`)

> ===== 6e. COLOSSO PÚTRIDO v2 (frente chefes-ajustes) =====
> O salão É ele: raízes descem das bocas pintadas do salão 5 e agarram,
> o corpo se MONTA de blocos do próprio sprite (pés → cabeça) e só então
> aparece; o chão racha no `land`. Morte: o chefe real some, as raízes
> agarram e soltam, o corpo desaba em pedaços e o monte esvaece sobre o
> cadáver (chefe visível de novo no fim).

## L476 (em `stage5`, junto a `if d.fx.asm.t >= d.fx.asm.dur - DT then`)

> ultimo instante da montagem: todo bloco ja partiu e chegou

## L525-528 (em `stage5`, junto a `do`)

> ===== 6f. MONARCA DO INVERNO v2 (frente chefes-ajustes) =====
> A silhueta na nevasca dura 3,5 a 4 s (era 1,2), cresce de longe, o
> cajado bate AINDA em silhueta (impacto de tela enquanto o chefe real
> está escondido) e só depois a neve assenta; o `land` não bate de novo.

## L570-575 (em `stage5`, junto a `do`)

> ===== 6g. TIRANO DO ABISMO v2: correntes do salão (frente chefes-ajustes) =====
> As correntes são do castle_hall_3 (âncoras pintadas) e dele (pulsos/
> pescoço): nascem frouxas no `chains`, esticam no `land`, e na LUTA
> arrebentam nos limiares de vida (0.72 / 0.52 / 0.38 / ENFURECIDO);
> todas rompidas = solto. Continuar nasce com as correntes já rompidas
> pela vida; morte solta todas; inimigo sem `bonds` não tem corrente.

## L678 (em `gt.enemy.statusEffects`, junto a `for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do`)

> ===== 7. i18n: todo chefe com roteiro tem nome + epiteto nos 5 locales =====

