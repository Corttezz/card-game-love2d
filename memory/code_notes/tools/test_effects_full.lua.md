---
name: code_notes/tools/test_effects_full.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_effects_full.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_effects_full.lua`

Origem: `tools/test_effects_full.lua` em `7dbdb60d` (16 de 33 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local TK = require("tools.testkit")`)

> tools/test_effects_full.lua
> Cobertura ampla do EffectSystem além do smoke_effects: appliers contínuos de
> joker (multiplicadores/bônus com gating), applyCardEffects (multi_hit,
> damage_bonus_self), todos os processEffectCard, orbs por tipo (lightning/ice/
> dark/fire/holy + overflow), triggers (attack/defend/turn_start), heal_multiplier.
> Conferido em src/systems/EffectSystem.lua.
> love . test_effects_full

## L84-86 (em `g.discard`, junto a `t:eq("discard_cards move as 2 pro discard (não deleta)", #g.discard, 2)`)

> REGRESSÃO (Jul/2026): a carta descartada TEM que ir pro discard, não
> sumir. Antes table.remove só arrancava da mão → o deck de batalha
> degenerava (Sobrevivente comia 1 carta/turno até sobrar só as 3 jogadas).

## L129-134 (em `g.discard`, junto a `g = fresh()`)

> fire -> dano + QUEIMADURA (status proprio; NAO veneno)
> Set/2026: o dono, jogando de MAGO, viu veneno empilhando no inimigo e
> estranhou com razao -- veneno e o eixo do LADINO e nenhuma carta de mago
> aplica. O ramo `fire` de _evokeOrbEffect usava "poison" como atalho
> ("via poison por ora; refinar"), e o "por ora" ficou. Este par de
> asserções e o que impede o atalho de voltar.

## L143-147 (em `g.discard`, junto a `do`)

> ===== QUEIMADURA: o DoT proprio do fogo =====
> Mecanica IGUAL a do veneno (stacks de dano por turno, pela duracao,
> absorvido pela armadura) com status SEPARADO -- o pedido nao era
> rebalancear, era parar de mentir. Estas asserções travam as duas metades:
> que a queimadura queima de verdade, e que ela nao e veneno.

## L155-156 (em `g.discard`, junto a `local _, b1 = e:onTurnEnd()`)

> Tica no MESMO lugar que o veneno (Enemy:onTurnEnd), com a mesma
> cadencia: o dano sai ANTES do decremento de duration.

## L166-167 (em `g.discard`, junto a `local e4 = Enemy:new(50, 5)`)

> O 1o retorno continua sendo o VENENO (chamadas antigas nao mudam) e
> os dois DoTs sao numeros SEPARADOS, nunca somados num so.

## L183-189 (em `g.discard`, junto a `local e3 = Enemy:new(3, 5)`)

> MORTE POR DoT: os dois DoTs atravessam `_markDeathIfCrossed`, que e
> o que faz a morte cair NO tick que a causou (com animacao) em vez de
> ser recolhida pela rede de seguranca beats adiante. A aritmetica crua
> do DoT nao passa por takeDamage, entao a marcacao tem que ser
> explicita -- foi o caminho que o `morte-e-vitoria` consertou.
> As duas asserções juntas provam a EQUIVALENCIA: queimar e envenenar
> matam igual.

## L205-209 (em `g.discard`, junto a `do`)

> ===== VENENO E IDENTIDADE DO LADINO =====
> Varredura do catalogo inteiro. Foi ESTA fronteira que o atalho do fogo
> furava: o mago via a pill de Veneno e ia procurar no proprio deck uma
> carta que nao existe -- alem de disparar a conquista de 15+ veneno e o
> combo `poison_stack`, que sao do ladino.

## L255 (em `g.discard`, junto a `g = fresh()`)

> mystery: sempre resolvido (handled), sem crash

## L271-273 (em `g.jokerSlots`, junto a `g = fresh()`)

> on_defend_damage ARMA ESPINHOS (Set/2026) — nao causa dano na hora.
> Contrato novo: a carta/joker vira o buff "thorn"; quem dispara o dano
> e o GOLPE do inimigo (Game:enemyTurn -> fireThornReflect). Ver test_beats.

## L303-305 (em `reflectCard`, junto a `g = fresh()`)

> ===== P0.9 (rebalance v2): LARGEST-MULTIPLIER-WINS entre jokers =====
> 2 jokers x1.5 NAO compõem (x2.25) — só o maior multiplicador conta;
> bônus flat continuam somando todos. Regressão exigida pela crítica A1.

## L322-324 (em `atkCard`, junto a `do`)

> ===== Game feel v1: applyJokerEffects retorna PROCS (ticks Balatro) =====
> Cada joker que MUDOU o valor gera um proc {slotIndex, joker, label, kind}
> pro tick sequencial no slot. Previsão (predictJokerProcs) deve bater.

## L335-336 (em `atkCard`, junto a `local msgs = #(g.messages or {})`)

> Previa de dano (Out/2026): jokerSteps e o NUCLEO PURO de
> applyJokerEffects — mesmo valor, nada mexido no game.

## L346-350 (em `atkCard`, junto a `do`)

> ===== ECO: dobra a PRIMEIRA carta de ataque do turno (Set/2026) =====
> "Forma de Eco" era um CLONE do "Deus do Abismo" (os dois
> damage_multiplier attack 1.5) — e, com o largest-wins acima, ter os
> dois ativos nao somava nada. Queixa do dono: "qual a diferenca entre
> deus do abismo e forma de eco? nenhuma". Agora e um PICO condicional.

## L376-378 (em `gd.jokerSlots`, junto a `local gm = fresh()`)

> Fica FORA do largest-wins: eco e multiplicador de joker COMPÕEM.
> (E de proposito — sao camadas diferentes; o eco custa a condicao
> de ser a primeira carta do turno.)

## L388-391 (em `gm.jokerSlots`, junto a `g = fresh()`)

> ===== P2.3 (rebalance v2): thorn de JOKER ARMA 1x/turno =====
> A intencao de balanceamento sobreviveu a migracao pro modelo de ESTADO
> (Set/2026): o TETO por turno e o mesmo de antes — joker contribui uma
> vez, carta contribui por carta jogada. O que mudou e QUANDO o dano sai.

