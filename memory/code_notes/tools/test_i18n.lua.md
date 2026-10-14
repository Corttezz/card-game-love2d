---
name: code_notes/tools/test_i18n.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_i18n.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_i18n.lua`

Origem: `tools/test_i18n.lua` em `7dbdb60d` (5 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local I18n = require("src.i18n.I18n")`)

> tools/test_i18n.lua
> Smoke test do sistema de i18n. Roda dentro do LOVE com:
> love . tools/test_i18n.lua
> ou via main.lua trocando o entry. Aqui implementamos uma love.load minima
> que so executa os asserts e fecha.
>
> Verifica:
> todos os locales carregam
> todas as chaves de UI existem em todos os locales
> troca de locale funciona
> I18n.cardName/cardDesc retornam strings nao vazias
> substituicao de variaveis funciona

## L30 (em `ok`, junto a `local locales = I18n.getAvailable()`)

> 1. Carrega todos os locales conhecidos

## L37 (em `ok`, junto a `local CRITICAL_KEYS = {`)

> 2. Chaves criticas que precisam existir em todos os locales

## L102-103 (em `card`, junto a `I18n.setLocale("pt_BR")`)

> 5b. Auto-injecao de variaveis em cardDesc ({atk}/{def}/{value}/{stacks})
> A descricao de warrior_strike usa {atk}; em PT deve resolver pra "Causa 6 de dano."

## L191-194 (em `seen`, junto a `do`)

> 7. REGRESSAO (bug Jul/2026 "valor {value}" cru na loja): cardDesc de TODA
> carta, em TODO locale, nao pode conter placeholder nao-substituido — tanto
> pelo caminho id-string quanto pelo caminho tabela-minima {id, description}
> (o que a CardRewardScreen passa). O fix busca a carta no CardDatabase.

