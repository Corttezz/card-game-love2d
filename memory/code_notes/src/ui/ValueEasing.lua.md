---
name: code_notes/src/ui/ValueEasing.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/ValueEasing.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/ValueEasing.lua`

Origem: `src/ui/ValueEasing.lua` em `7dbdb60d` (3 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local ValueEasing = {}`)

> src/ui/ValueEasing.lua
> Helper pra UIs terem um "display value" que eases smoothly toward o valor
> real (gameplay-side). Desacopla lógica do jogo de feedback visual — spendMana
> desce imediato no player.mana (gameplay vê), mas o ORB mostra o valor
> descendo suavemente em ~0.3s.
>
> Inspirado em ease_chips / ease_dollars / ease_mana do Balatro
> (functions/common_events.lua:41+).
>
> Uso em cada componente de UI:
> local ValueEasing = require("src.ui.ValueEasing")
>
> function Foo:new()
> self.disp = {}  -- tabela nomeada pra valores eased
> end
>
> function Foo:update(dt, player)
> ValueEasing.tick(self.disp, "mana", player.mana, dt, 10)
> ValueEasing.tick(self.disp, "health", player.health, dt, 8)
> end
>
> function Foo:draw(player)
> local displayedMana = math.floor(self.disp.mana or player.mana)
> ...
> end

## L29-36 (em `ValueEasing`, junto a `function ValueEasing.tick(disp, key, target, dt, k)`)

> Tick: ease disp[key] toward target usando exp decay com rate K.
> Init: se disp[key] é nil, seta imediato ao target (evita "anim de 0 → N"
> quando o objeto é criado mid-game).
> disp: tabela do chamador (não precisa existir — criada no init)
> key: nome do campo (ex: "mana", "health", "gold")
> target: valor atual real (game-side)
> dt: delta time
> k: taxa do ease (default 8). Maior = mais snappy. 8-12 é sweet spot.

## L45 (em `ValueEasing.tick`, junto a `if math.abs(target - disp[key]) < 0.05 then`)

> Snap quando quase lá (evita decimais eternos tipo 6.9998)

