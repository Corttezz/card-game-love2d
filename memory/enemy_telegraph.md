---
name: Enemy Telegraph (intents v2)
description: Telegrafia do inimigo (Jul/2026) — intent com bob/severidade/flash de execução, nome do golpe, defend com escudo+anéis, buff com fagulhas+ícone, arco de golpe no apex; camada 2 = anims "attack" PixelLab por inimigo.
type: project
---

# Telegrafia do inimigo (padrão StS adaptado)

Pedido do Daniel (Jul/2026): "não está claro quando o boneco defende/ataca/buffa".
Referência: memory/sts_powers_catalog.md (IntentFlash/ShowMoveName/AttackEffect do StS).

## Camada 1 — procedural (TODOS os 21 inimigos, sem asset novo)

**Preview (EnemyHud.drawIntent):** ícone 34px (era 24), bob vertical ±3px contínuo
(reducedMotion desliga), STRONG = box 12% maior + pulso mais rápido. Tooltip já existia.

**Flash de execução (EnemyHud.flashIntent):** `Game:enemyTurn` chama antes de despachar
a ação — o box dá zoom 1.35→1 com lavagem branca + borda acesa por 0.55s ("o anúncio
virou ação" — IntentFlashAction do StS). Timer interno por getTime, sem update hook.

**Nome do golpe:** FloatingText kind `movename` sobe do sprite (`enemy_moves.*` no i18n
×5: Investida / GOLPE BRUTAL / Postura Defensiva / Furia Crescente). ShowMoveName do StS.

**Execução (EnemyRenderer):**
- ATAQUE: windup→investida→apex (já existia) + **arco de golpe** (slashTime 0.20s, 3
  traços diagonais na direção da investida) disparado no apex.
- DEFESA (DEFEND_DUR 0.9s, era 0.5 só de tint): 2 anéis aço sequenciais + **escudo
  `armor_shield` grande com pop-in/fade sobre o peito** + FloatingText "+N" armor.
- BUFF (BUFF_DUR 0.9s, era 0.6 só de throb): **14 fagulhas vermelhas sobem do corpo**
  (buffParticles, offsets relativos ao frame) + ícone `status_strength` pop acima da
  cabeça + FloatingText "+2 DANO".
- Tints de corpo continuam (aço/vermelho/verde) com as durações novas.

## Camada 2 — animações "attack" PixelLab

`EnemyRenderer.triggerAttack` agora toca o clip **"attack"** se
`SpriteAnimation.exists(id, "attack", "south")` — instalar frames em
`assets/sprites/characters/enemies/<id>/animations/attack/south/0..N.png` liga
automaticamente (a investida procedural continua por baixo — compõem).

Piloto gerado (mode v3, 8 frames, south, ~17 gerações): `cursed_scarecrow` (garra),
`harvest_reaper` (foice horizontal), `carrion_king` (smash bimanual) — os 3 do Ato 1
(ENEMY_ROSTER[1]). Fila pros outros 18: mesmo comando `animate_character(character_id,
animation_name="attack", action_description=<golpe da silhueta>, mode="v3",
frame_count=8, directions=["south"])` — ids da conta em `list_characters`. Instalação:
curl das URLs do `get_character` (padrão pixellab-base64-mcp-http: NUNCA transcrever
base64; sempre download direto).

**Why:** intents legíveis = decisões informadas (defender no strong, burstar no defend).
**How to apply:** ao adicionar inimigo novo, seguir memory/enemy_pipeline.md + gerar
também o clip "attack"; efeitos de intent novos entram no EnemyRenderer (triggers) e
no EnemyHud (preview), nunca hardcoded no Game.
