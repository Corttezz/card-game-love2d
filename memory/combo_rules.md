---
name: Combo Rules
description: Combos SIMPLES (Out/2026) — Saraivada, Muralha e Par (bônus plano por posição na jogada), coringas de combo, e por que a força global do inimigo caiu junto
type: project
---

# Combos (simples, Out/2026)

Decisão do dono: "combos estão MUITO fortes, de defesa e de ataque, e não são
explicados — o jogador só joga carta e combo sem saber. Tira e põe combos mais
simples: quanto mais cartas de ataque, mais o bônus sobe; o mesmo pra defesa;
carta igual vale mais; coringas de combo também."

As 13 regras por TAG (Combo de Ataques, Remate, Convergência Arcana, Veneno
Concentrado, Explosão Arcana, Ferida Vital...) SAÍRAM. Dependiam de tags que o
jogador não vê. Ficaram três regras que se leem na própria mão.

## As três regras (`src/systems/ComboSystem.lua:RULES`)

| id | nome | alcança | bônus |
|----|------|---------|-------|
| `volley` | Saraivada | cartas de ATAQUE | +3 por ataque ANTES dela na jogada (2º +3, 3º +6, 4º+ +9; `cap` 3) |
| `wall` | Muralha | cartas de DEFESA | +5 de Bloqueio por defesa antes dela (2ª +5, 3ª +10, 4ª+ +15) |
| `pair` | Par | ataque/defesa com o MESMO id | +4 por cópia anterior (2ª +4, 3ª+ +8) |

- Tudo é bônus PLANO, somado depois da Força e ANTES dos coringas (o
  multiplicador de coringa multiplica a carta já com o bônus).
- A "fila" é a ordem de seleção (= ordem de resolução).
- Carta com a tag `combo` (Golpe Rápido, Estilete) conta como DUAS na fila.
- Sem prêmio de fim de jogada (veneno/cura/evoke saíram com as regras por tag).
- Coringas de combo (`combo_boost`, neutros, incomuns): Chuva de Lâminas
  (Saraivada ×2), Muro de Escudos (Muralha ×2), Espelho Gêmeo (Par ×2).
  `ComboSystem.boostFor(game, id)` — maior vence.

## Onde aparece

- Prévia (`DamagePreview` / `DamagePreviewPanel`): linha do combo com o total da
  jogada, ficha dourada "+N" em cada carta, hover explica (texto
  `damage_preview.combo_desc.<id>` com `{v}`/`{max}` da própria regra).
- Mão: selo em cima da carta com o que ela GANHARIA se entrasse agora
  ("Saraivada +6 Par +4").
- Guia de combos (`GuideScreen.comboEntries`) lê `ComboSystem.RULES`.
- Conquista Tinta Viva = os 3 combos na mesma jogada (`AchievementSystem.T.COMBOS = 3`).

## Por que o inimigo ficou mais fraco junto

As regras por tag davam ~40% do dano e ~50% do Bloqueio das cartas, e a curva de
inimigos tinha sido calibrada com elas. Só trocar os combos derrubou o guerreiro
do piloto de 55% para 0–5% (bisect: só o ComboSystem). Compensar no jogador
(+60% de Bloqueio, +20% de ataque, combos 2×, +10 de vida) não voltou;
`Config.Game.ENEMY_POWER = { damage = 0.8, health = 0.85 }` (em
`ActSystem.getEnemyStats`, a run inteira) voltou. Números em
`memory/balance_curves.md`.

## Adicionar regra

1. Entrada em `ComboSystem.RULES` (`kind` = "attack" | "defense" | "same",
   `step`, `cap`, `bonusType`)
2. Nome em `combos.<id>`, texto em `damage_preview.combo_desc.<id>` ({v}/{max}),
   linha de coringa em `effects.combo_boost_<id>` — 5 locales
3. `love . smoke_combos` + `love . test_one test_damage_preview` (0 divergências)
