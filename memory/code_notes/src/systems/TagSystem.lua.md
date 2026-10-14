---
name: code_notes/src/systems/TagSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/TagSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/TagSystem.lua`

Origem: `src/systems/TagSystem.lua` em `7dbdb60d` (6 de 20 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local TagSystem = {}`)

> src/systems/TagSystem.lua
> Catalogo canonico de tags + helpers para deteccao de combos/sinergias.
>
> Contrato:
> Toda carta pode ter um array card.tags = {"strike", "finisher"}.
> Tags sao strings sem prefixo "#" (o prefixo so aparece em UI/docs).
> getCardTags(card) normaliza: le card.tags, deriva tags implicitas do tipo
> (attack->"strike", defense->"defend", joker->"passive", effect->"utility"),
> e garante array sem duplicados.
>
> O CATALOG e a unica fonte de verdade das tags validas: se uma carta usar uma
> tag fora do catalogo, um warning e logado via Debug.warn. Isso evita typos
> silenciosos que quebrariam ComboSystem.

## L17-18 (em `TagSystem`, junto a `TagSystem.CATALOG = {`)

> Categorias ajudam a filtragem e cores em UI (pilulas coloridas no card).
> Toda tag nova DEVE ser adicionada aqui antes de ser usada em dados de carta.

## L20 (em `TagSystem.CATALOG`, junto a `strike     = { category = "archetype", color = {0.85, 0.30, 0.25}, desc = "Ataque fisico" },`)

> Arquetipos basicos (derivados do tipo, sempre presentes)

## L79-80 (em `TagSystem.implicitTagFor`, junto a `local warnedTag = {}`)

> Valida uma tag contra o catalogo. Retorna true se valida, false+log se nao
> (um aviso por tag: a mesma carta e instanciada dezenas de vezes por run).

## L93-95 (em `TagSystem.isValid`, junto a `function TagSystem.getCardTags(card)`)

> Normaliza tags de uma carta: le card.tags (ou {}), adiciona a implicita do tipo,
> remove duplicados, valida contra catalogo.
> Retorna array novo (nao muta a carta).

## L146-148 (em `counts`, junto a `local weight = 1`)

> F5 gameplay-overhaul: tag "combo" (Combo-starter) faz as DEMAIS
> tags da carta contarem em DOBRO pras regras do ComboSystem —
> antes era decorativa (a auditoria pegou "não faz nada").

