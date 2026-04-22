---
name: Tag System
description: Catálogo canônico de tags (#strike, #armor, #poison, etc.) e como o ComboSystem usa pra detectar sinergias
type: project
---

# Sistema de Tags

**Fase 1 do redesign.** Toda carta recebe uma lista de tags. Tags vivem no catálogo em `src/systems/TagSystem.lua` e são a moeda de troca do `ComboSystem`.

## Categorias

- **archetype** (sempre derivada do tipo): `strike` (attack), `defend` (defense), `passive` (joker), `utility` (effect).
- **mechanic**: `armor`, `poison`, `weak`, `vulnerable`, `strength`, `dexterity`, `channel`, `evoke`, `exhaust`, `innate`, `retain`, `draw`, `discard`, `heal`, `lifesteal`, `thorn`, `aoe`, `mana`, `debuff`, `potion`.
- **element**: `fire`, `ice`, `lightning`, `dark`, `holy`, `magic`.
- **role**: `finisher`, `starter`, `combo`, `cycle`, `scaling`, `zero_cost`.

## Regras

- Tag implícita é injetada na criação da instância (`CardDatabase:createCardInstance`). Ex: toda carta `attack` ganha `strike` automaticamente.
- Tags no dado-fonte aceitam `"poison"` ou `"#poison"` — o prefixo `#` é removido na normalização.
- Tag desconhecida loga warning via `print("[TagSystem] tag desconhecida: ...")` mas não quebra.

## API essencial

- `TagSystem.getCardTags(card)` — retorna array normalizado
- `TagSystem.countAllTags(cards)` — dict `{tag=n}`
- `TagSystem.cardHasTag(card, tag)` / `cardHasAnyTag` / `cardHasAllTags`
- `TagSystem.getTagInfo(tag)` — retorna `{category, color, desc}` (com fallback para tag desconhecida)
- `TagSystem.listByCategory("element")` — lista ordenada de tags de uma categoria

## Como adicionar uma tag nova

1. Incluir entrada em `TagSystem.CATALOG`
2. Se vai participar de combo, adicionar regra em `ComboSystem.RULES`
3. Usar no campo `tags = { ... }` das cartas
4. Rodar `love . validate_cards` para garantir que nenhum warning apareça
