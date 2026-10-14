---
name: code_notes/src/systems/Sfx.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/Sfx.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/Sfx.lua`

Origem: `src/systems/Sfx.lua` em `7dbdb60d` (5 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local Sfx = {}`)

> src/systems/Sfx.lua
> Facade único pra _G.audioSystem (instância de AudioManager).
> Mantém compatibilidade total com a API antiga (Sfx.play("name")) e expõe
> novos helpers de música/volume sem forçar consumers a tocar audioSystem direto.

## L14-15 (em `audio`, junto a `function Sfx.play(name, opts)`)

> Toca um SFX por nome. opts = { volume, pitch, loop }.
> O AudioManager já é no-op gracioso quando áudio indisponível.

## L26-30 (em `Sfx.play`, junto a `function Sfx.playWithVariation(name, basePitch, pitchVar, baseVolume, volVar)`)

> Toca SFX com pitch/volume aleatórios em torno de um centro. Replica o
> pattern do Balatro (engine/text.lua:201) que evita fadiga auditiva em sons
> repetidos (hover, click). pitchVar e volVar são amplitudes simétricas.
> Ex: Sfx.playWithVariation("hoverCard", 0.95, 0.15, 0.4, 0.05) →
> pitch ∈ [0.80, 1.10], volume ∈ [0.35, 0.45].

## L45-46 (em `opts`, junto a `function Sfx.has(name)`)

> Um som com esse código está registrado? (feel v2: JokerProcFx decide entre
> assinatura do joker e o jokerTick genérico sem disparar warning de missing).

## L74-76 (em `Sfx.getSfxVolume`, junto a `function Sfx.fadeMusicOut(duration)`)

> Fade out da música atual em `duration` segundos e depois para. Usa
> EventManager.parallelEase pra interpolar o group volume sem bloquear outras
> filas; restaura volume original depois.

