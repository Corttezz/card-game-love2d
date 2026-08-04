---
name: Joker Proc FX
description: Contrato OBRIGATÓRIO — todo efeito de coringa precisa ticar visualmente no momento em que trabalha (auditoria Jul/2026, bug "Aprendizado de Máquina mudo")
type: project
---

# Proc visual de coringa — contrato

**Regra do dono (Jul/2026):** TODO coringa precisa **ticar visualmente no
slot** (pulinho + swell + popup com a contribuição + som) no MOMENTO EXATO
em que o efeito dele trabalha. Coringa que age em silêncio é bug — foi o
caso do "Aprendizado de Máquina" (compra extra no turn_start sem nenhum
feedback).

## Como o tique acontece (2 caminhos, mesma função)

`pushJokerProc(game, sink, joker, label, kind)` em `EffectSystem`:

1. **Dentro do pipeline de carta** (multiplicadores, bônus, on_attack_*,
   on_defend_*): passa `context.procSink` — os procs entram na CADEIA do
   CombatSequence e ticam em sequência estilo Balatro (stagger esticado,
   pitch crescente).
2. **Fora do pipeline** (turn_start etc.): `sink = nil` → dispara DIRETO
   no `JokerProcFx.tick`, com escalonamento próprio (vários procs no mesmo
   instante ticam a 0.18s um do outro, não em uníssono).

De fora do EffectSystem use o wrapper público:
`game.effectSystem:notifyJokerProc(game, joker, label, kind)` (ex: o
Bastião tica em `Game` quando o escudo é MANTIDO em Player:onTurnStart).

`kind` = cor do popup (FloatingText.KINDS): `mult` laranja, `heal` verde,
`buff` roxo, `damage` vermelho, `armor` azul, `info` branco.

## Checklist ao criar um CORINGA NOVO

1. Efeito de tipo JÁ COBERTO? (lista abaixo) → o tique vem de graça.
2. Tipo de efeito NOVO → implemente em EffectSystem E chame
   `pushJokerProc` no branch, com label curto da contribuição
   ("+2 cartas", "+3 PV", "Reflete 4", "×2") e o kind certo.
3. O tique só dispara quando o efeito REALMENTE agiu (respeite gates —
   ex: thorn de joker é 1x/turno; sem disparo, sem tique).
4. Som assinatura opcional: `audio/sfx/joker-sig/<id>.mp3` (scan
   automático; fallback = jokerTick).
5. Rode `love . smoke_ui_turn` (seção 7 cobre o caminho direto).

## Cobertura por tipo de efeito (auditoria Jul/2026)

| Tipo | Momento | Tique |
|---|---|---|
| damage/defense_multiplier, damage/defense_bonus, heal_multiplier | jogar carta | cadeia (procSink) |
| on_attack_heal, on_attack_debuff | jogar ataque | cadeia |
| on_defend_damage (joker, gate 1x/turno) | jogar defesa | cadeia |
| on_turn_start_draw | turn_start | direto ("+N cartas") |
| regen_per_turn | turn_start | direto ("+N PV") |
| damage_per_turn | turn_start | direto ("-N PV") |
| strength_per_turn | turn_start | direto ("+N Forca") |
| channel_per_turn | turn_start | direto ("+1 Orbe") |
| retain_armor | Player:onTurnStart | direto via Game ("Escudo mantido") |
