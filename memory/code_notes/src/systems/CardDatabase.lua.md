---
name: code_notes/src/systems/CardDatabase.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/CardDatabase.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/CardDatabase.lua`

Origem: `src/systems/CardDatabase.lua` em `7dbdb60d` (10 de 18 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local CardDatabase = {}`)

> src/systems/CardDatabase.lua
> Loader de cartas e decks. Os dados vivem em src/data/cards/*.lua e src/data/decks.lua.
> Esta camada apenas: (1) merge dos módulos, (2) queries, (3) criação de instâncias de Card.

## L12-13 (em `CardDatabase`, junto a `local CARD_MODULES = {`)

> Fontes de dados por classe/categoria. Ordem determina precedência em colisão de ID
> (a última sobrescreve), mas os IDs são prefixados por classe, então não há colisão real.

## L113-115 (em `cards`, junto a `function CardDatabase:createCardInstance(cd)`)

> Cria instância de carta (Attack/Defense/Joker/Effect) a partir dos dados.
> Injeta `description`, `rarity`, `effects` na instância e **substitui a imagem**
> pelo canvas procedural gerado via CardFrame.

## L141-150 (em `CardDatabase:createCardInstance`, junto a `if cd.effects then`)

> CÓPIA, nunca a referência do catálogo (fix Set/2026).
> `cardData` é cache de PROCESSO (carregado 1x, nunca recarregado), então
> `cd.effects` é a tabela viva do catálogo. Apontar a instância pra ela
> fazia `RunManager:applyUpgradesToInstance` (RunManager.lua:546, a única
> escrita de `eff.value` do projeto) mutar o CATÁLOGO: forjar uma carta de
> efeito somava o ganho a CADA `buildPlayableDeck` — ou seja a cada andar,
> a cada carta adicionada e a cada abertura do visualizador de deck —
> crescendo sem limite e contaminando todas as cartas daquele id, inclusive
> em runs novas, até fechar o jogo. Efeitos são tabelas planas
> ({type=..., value=...}), então cópia de 2 níveis basta.

## L163-167 (em `e`, junto a `if cd.type == "effect" or cd.type == "joker" then`)

> O `passive` compilado acima fechava sobre `cd.effects` (o CATALOGO):
> quem resolvesse a carta pelo passive (caminho sem fila de beats)
> ignorava a FORJA, que so escreve na copia. Recompila sobre a copia
> (auditoria de cartas Out/2026: a descricao forjada tem que valer
> em qualquer caminho).

## L173-174 (em `e`, junto a `local TagSystem = require("src.systems.TagSystem")`)

> Normaliza tags na criacao: carrega do card-data ou deriva do tipo.
> TagSystem.getCardTags ja faz merge com tag implicita e remove duplicados.

## L180-182 (em `e`, junto a `instance.exhaust = cd.exhaust or nil`)

> Exhaust: Game.lua checa instance.exhaust (top-level), mas os dados
> declaram {type="exhaust"} dentro de effects — sem esta derivação
> NENHUMA carta exauria (bug F0 do gameplay-overhaul-v1).

## L191-192 (em `e`, junto a `local ok, proceduralImg = pcall(CardFrame.render, instance)`)

> Substitui imagem pela arte procedural pixel-perfect.
> Mantém o fallback original se CardFrame falhar (ex: em ambiente sem love).

## L199-201 (em `e`, junto a `love.graphics.setCanvas()`)

> CardFrame.render usa PixelCanvas.beginDraw (seta canvas) e endDraw (restaura).
> Se o crash for ENTRE os dois, o canvas fica preso ativo — isso bloqueia
> o love.graphics.present() do próximo frame ("Canvas is active"). Reset forçado:

## L216-218 (em `e`, junto a `function CardDatabase:createEffectFunction(effects)`)

> Compila a função `passive(game)` executada quando a carta é jogada.
> Delega para EffectSystem:processEffectCard. Se o efeito não for reconhecido,
> mostra a descrição traduzida via I18n.effectDesc (fallback: effect.description).

