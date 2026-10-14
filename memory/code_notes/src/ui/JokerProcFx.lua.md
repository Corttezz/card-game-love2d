---
name: code_notes/src/ui/JokerProcFx.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/JokerProcFx.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/JokerProcFx.lua`

Origem: `src/ui/JokerProcFx.lua` em `7dbdb60d` (7 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local Sfx = require("src.systems.Sfx")`)

> src/ui/JokerProcFx.lua
> FX de "proc" de joker estilo Balatro (game feel v1, Jul/2026): quando uma
> carta jogada dispara um joker ativo, o SLOT dele reage — juice na carta do
> joker, popup flutuante com a contribuição ("×2", "+3", "+4 HP") e um tick
> sonoro curto com pitch crescente na cadeia (1º joker grave, 3º agudo).
>
> Quem AGENDA os ticks em sequência é o CombatSequence (via EventManager,
> espaçados por PROC_TICK). Este módulo só executa UM tick.
>
> proc = { slotIndex = i, joker = <instância>, label = "×2", kind = "mult" }
>
> Headless-safe: Sfx é no-op; posição do slot vem por pcall no GameplayScene
> (não carregado em tools) — sem tela, só o juice no objeto acontece.

## L24-26 (em `JokerProcFx.tick`, junto a `local joker = proc.joker`)

> Anima a instância ATUAL do slot, não a referência capturada no impacto:
> rebuildJokerSlots recria instâncias (coleção+bancada) e animar o objeto
> órfão = joker parado na tela ("não se move" — bug Jul/2026).

## L33-35 (em `JokerProcFx.tick`, junto a `if joker then`)

> 1) PULINHO do joker (feel v2/v3.1): sobe com o lado direito levantando
> (rotação anti-horária) + CRESCE (swell) — "levantar de tamanho e dar
> uma mexidinha" (dono). Amplo e longo pra ler mesmo no meio do combate.

## L37 (em `JokerProcFx.tick`, junto a `if joker.hop_up then joker:hop_up(26, 0.45) end`)

> v3.2: envelope chunky do hop/swell (estala-segura-cai-quica).

## L42-43 (em `JokerProcFx.tick`, junto a `if require("src.core.Release").isDev() then pcall(love.filesystem.append, "feel_debug.log",`)

> DEBUG FEEL (temporário): prova em jogo real de que o tick achou e
> kickou a instância desenhada. Só em DEV (release não escreve logs de caça).

## L50-52 (em `JokerProcFx.tick`, junto a `local sig = joker and joker.id and ("jokerSig_" .. joker.id)`)

> 2) Som: ASSINATURA do joker se existir (audio/sfx/joker-sig/<id>.mp3,
> registrada como jokerSig_<id> no main.lua) — cada lendário soa como ele
> mesmo. Fallback: jokerTick genérico. Pitch sobe na cadeia nos dois casos.

## L60 (em `JokerProcFx.tick`, junto a `local ok, GameplayScene = pcall(require, "src.scenes.GameplayScene")`)

> 3) Popup + faísca no slot (precisa da geometria da cena de gameplay).

