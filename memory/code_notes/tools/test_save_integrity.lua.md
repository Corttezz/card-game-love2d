---
name: code_notes/tools/test_save_integrity.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_save_integrity.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_save_integrity.lua`

Origem: `tools/test_save_integrity.lua` em `7dbdb60d` (5 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local TK = require("tools.testkit")`)

> tools/test_save_integrity.lua
> INTEGRIDADE DE SAVE + ANTI-SAVE-SCUM DA VITRINE (Out/2026).
>
> O QUE ESTA SUITE TRAVA
> 1. ESCRITA ATÔMICA (SaveManager.writeFile): .tmp verificado, rotação de
> UMA geração .bak (só de arquivo BOM), promoção por rename com fallback
> — e cada estado intermediário de um crash continua legível.
> 2. PERFIL NUNCA É APAGADO: principal ilegível → recupera do .bak; sem
> backup válido → modo recuperação, e o arquivo danificado NÃO é
> sobrescrito pelos defaults (era assim que conquistas/desbloqueios/
> vitórias sumiam).
> 3. RUN: save corrompido volta do .bak; deleteRun apaga TODAS as gerações
> (senão a run abandonada ressuscitaria pelo fallback).
> 4. LOJA: "Salvar e sair" + Continuar devolve a MESMA vitrine — ofertas,
> VENDIDO, preços e custo de reroll. Antes regerava (restock grátis).
> 5. RECOMPENSA: idem — e a carta já pega não libera uma segunda.
>
> love . test_one test_save_integrity

## L58 (em `testAtomic`, junto a `local ok = SaveManager.writeFile(P, "return 5")`)

> Texto inválido nunca é promovido.

## L63-64 (em `testAtomic`, junto a `fs.write(P, TRUNCATED)`)

> Crash no meio da escrita do principal (fallback sem rename): bytes
> truncados no principal, .bak bom.

## L79 (em `testAtomic`, junto a `fs.remove(P .. ".tmp")`)

> Principal corrompido NUNCA vira .bak.

## L259 (em `run.mapHistory`, junto a `local offer = firstCard(screen2.shopOffers)`)

> Pega uma carta e sai antes do fechamento: a 2ª não pode ser pega.

