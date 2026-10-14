---
name: code_notes/engine/ProfileStats.lua
description: Comentários com decisão/regra/histórico colhidos de engine/ProfileStats.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/ProfileStats.lua`

Origem: `engine/ProfileStats.lua` em `7dbdb60d` (11 de 28 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local SaveManager = require("engine.SaveManager")`)

> engine/ProfileStats.lua
> Perfil persistente do jogador (fora da run): vitórias, derrotas, melhor
> progresso, classe favorita. Sobrevive entre sessões via love.filesystem
> (profile.lua no save dir), mesmo padrão atomic-write do SaveManager.
>
> É o que faz o menu parecer "de verdade": o jogo lembra de você.
>
> Uso:
> local ProfileStats = require("engine.ProfileStats")
> ProfileStats.recordRunStart("warrior")
> ProfileStats.recordVictory(actNumber)
> ProfileStats.recordDefeat(actNumber, floorInAct)
> local s = ProfileStats.get()   -- {runs, wins, losses, bestAct, bestFloor, ...}

## L21-26 (em `ProfileStats`, junto a `local recoveryMode = false`)

> MODO RECUPERAÇÃO (Out/2026): o perfil existia no disco e NENHUMA geração
> (principal, .tmp, .bak) parseou. Antes o load caía nos defaults e o
> próximo save gravava os defaults POR CIMA — conquistas, desbloqueios e
> vitórias perdidos. Agora o jogo segue com o perfil em memória, mas NUNCA
> grava: o arquivo danificado fica intacto (e copiado em .corrupt-<ts>)
> para recuperação manual.

## L54 (em `cache`, junto a `cache.achievements = {}`)

> Tabelas aninhadas precisam existir mesmo em perfis antigos.

## L60-61 (em `cache.tipsSeen`, junto a `local data, info = SaveManager.readDataFile(testPath or PATH)`)

> Perfil e DADO, nunca codigo: readDataFile recusa bytecode e roda o
> chunk sem acesso a os/io; se o principal não parseia, tenta .tmp/.bak.

## L81 (em `save`, junto a `if _G.HEADLESS_TOOL and not testPath then return end`)

> Tools headless (screenshots/smokes) não podem poluir o perfil real.

## L101-102 (em `ProfileStats.isRecoveryMode`, junto a `function ProfileStats._setPathForTests(path)`)

> SÓ TESTES: aponta o perfil para outro arquivo (nil = volta ao real) e
> zera cache/modo recuperação, forçando releitura do disco.

## L121-122 (em `ProfileStats.recordRunStart`, junto a `local function bumpBest(actNumber, floorInAct)`)

> Atualiza o "melhor progresso" (chamado por victory/defeat com o ponto
> onde a run terminou).

## L162-164 (em `ProfileStats.updateBestScore`, junto a `function ProfileStats.bump(key, n)`)

> Contadores acumulados entre runs (cartas jogadas, forjas...). NÃO salva a
> cada bump (seria 1 write de disco por turno) — quem fecha o ciclo chama
> flush() (fim de batalha / unlock de conquista).

## L178-180 (em `ProfileStats.markSeen`, junto a `function ProfileStats.isTipSeen(id)`)

> ===== Dicas do tutorial (Out/2026) =====
> Cada dica aparece UMA vez por perfil. Marcar grava na hora (é raro: ~15
> dicas na vida do jogador) — fechar o jogo logo depois não pode re-mostrar.

## L215-217 (em `ProfileStats.flush`, junto a `function ProfileStats._swapForTests(tbl)`)

> SÓ TESTES: troca o perfil em memória (nil = recarrega do disco no próximo
> get). Devolve o anterior pra o teste restaurar. Nada vai pro disco
> (save() já é no-op sob _G.HEADLESS_TOOL).

## L234 (em `ProfileStats._swapForTests`, junto a `function ProfileStats.hasHistory()`)

> true se há qualquer histórico (menu decide se mostra a plaque de perfil).

