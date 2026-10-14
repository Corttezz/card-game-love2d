---
name: code_notes/src/systems/SteamBridge.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/SteamBridge.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/SteamBridge.lua`

Origem: `src/systems/SteamBridge.lua` em `7dbdb60d` (4 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-26 (junto a `local SteamBridge = {}`)

> src/systems/SteamBridge.lua
> Ponte entre as conquistas LOCAIS (AchievementSystem/ProfileStats) e a Steam.
>
> LOVE puro nao fala com o Steamworks. O caminho previsto e o binding
> `luasteam` (github.com/uspgamedev/luasteam): uma DLL/SO nativa carregada
> via require("luasteam") + steam_api64.dll + steam_appid.txt ao lado do
> executavel. NADA disso vem no repo — ver memory/steam_achievements.md.
>
> Contrato:
> * A conquista LOCAL e a fonte de verdade (o jogo funciona igual sem
> Steam; o perfil guarda tudo). A Steam e um espelho.
> * Sem Steam: TODA chamada e no-op — mas AVISADA, uma vez, no console
> ("fallback silencioso e proibido", CLAUDE.md). Nunca derruba o jogo.
> * Com Steam: init() sincroniza o que ja estava desbloqueado localmente
> (quem jogou antes de a Steam existir nao perde nada) e cada unlock()
> chama SetAchievement + StoreStats.
>
> API:
> SteamBridge.init()                       -- idempotente; true se ativa
> SteamBridge.isActive()
> SteamBridge.unlock(apiName)              -- SetAchievement + StoreStats
> SteamBridge.indicateProgress(apiName, cur, max)
> SteamBridge.syncAll(defs, isUnlockedFn)  -- empurra os locais pra Steam
> SteamBridge.update()                     -- runCallbacks (love.update)
> SteamBridge.shutdown()
> SteamBridge._setBackend(fake)            -- testes injetam um fake

## L34 (em `SteamBridge`, junto a `SteamBridge.log = {}`)

> Registro do que foi pedido (testes e diagnostico leem isso, Steam ou nao).

## L48 (em `SteamBridge.init`, junto a `warnOnce("ferramenta headless")`)

> Tools/testes nunca tocam a Steam real do jogador.

## L134-135 (em `SteamBridge.shutdown`, junto a `function SteamBridge._setBackend(fake)`)

> Testes: injeta um backend fake (tabela com init/userStats/...) e zera o
> estado. Passar nil volta ao estado "nunca inicializado".

