---
name: code_notes/src/ui/SpriteAnimation.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/SpriteAnimation.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/SpriteAnimation.lua`

Origem: `src/ui/SpriteAnimation.lua` em `7dbdb60d` (4 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local SpriteAnimation = {}`)

> src/ui/SpriteAnimation.lua
> Animacao frame-by-frame de sprites (gerados via pixellab animate_character).
>
> Layout esperado em disco:
> assets/sprites/characters/enemies/<id>/animations/<anim>/<dir>/<frame>.png
> Ex: .../grave_slime/animations/idle/south/0.png, 1.png, 2.png, ...
>
> Uso:
> local anim = SpriteAnimation.new("grave_slime", "idle", "south", 8) -- 8fps
> anim:update(dt)
> anim:draw(x, y, scale)
> anim:play("hurt", { onComplete = function() ... end })  -- troca de animacao
>
> Fallback: se a pasta da animacao nao existe, retorna nil (caller usa sprite
> estatico via EnemyRenderer antigo).

## L28-31 (em `enemyKey`, junto a `local function basePath(id)`)

> Raiz em disco por id. Ids simples ("grave_slime") continuam em enemies/
> (compat). Ids com categoria ("<categoria>/<id>") resolvem direto sob
> characters/ (os heróis da seleção de classe que usavam isso viraram
> emblemas em Out/2026 — src/ui/ClassEmblem.lua).

## L39 (em `basePath`, junto a `local function loadFrames(enemyId, animation, direction)`)

> Carrega todos os PNGs de uma pasta em ordem alfabetica. Retorna {img1, img2, ...} ou nil.

## L95-97 (em `SpriteAnimation.new`, junto a `self.pingpong = opts.pingpong or false`)

> Ping-pong (1,2,3,4,3,2,...): elimina o corte do wrap 4→1 nos idles
> de 4 frames (análise Jul/2026: ember_imp/abyss_tyrant/blood_duke
> tinham descontinuidade 1.4-1.7× a diferença média entre frames).

