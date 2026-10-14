---
name: code_notes/tools/scan_clones.lua
description: Comentários com decisão/regra/histórico colhidos de tools/scan_clones.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/scan_clones.lua`

Origem: `tools/scan_clones.lua` em `7dbdb60d` (3 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local M = {}`)

> tools/scan_clones.lua
> Varredura EXPLORATORIA: cartas com a MESMA assinatura de efeitos.
>
> Nasceu da queixa do dono (Set/2026): "qual a diferenca entre deus do abismo
> e forma de eco? nenhuma, e uma e lendaria a outra rara". Eram dois jokers
> com `damage_multiplier attack 1.5` identico. Achar UM assim significa que
> pode haver outros — e a regra do projeto e construir a varredura em vez de
> confiar na memoria (memory/defect_doctrine.md §10).
>
> love . scan_clones

## L14-19 (em `M`, junto a `local function assinatura(cd)`)

> A assinatura tem que incluir TODO campo escalar do efeito, nao so
> type/target/value. A primeira versao olhava esses tres e acusou
> rogue_envenom (raro) e rogue_toxin_master (lendario) como clones — eles
> diferem em `stacks` (1 vs 2), que e exatamente a escada de raridade
> legitima. Varredura que mente gera trabalho a toa e, pior, ensina a
> ignora-la.

## L25-26 (em `campos`, junto a `if k ~= "description" and type(v) ~= "table" and type(v) ~= "function" then`)

> `description` e texto de apoio, nao mecanica: duas cartas com a
> mesma mecanica e descricoes diferentes continuam clones.

