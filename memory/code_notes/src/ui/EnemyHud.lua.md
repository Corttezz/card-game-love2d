---
name: code_notes/src/ui/EnemyHud.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/EnemyHud.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/EnemyHud.lua`

Origem: `src/ui/EnemyHud.lua` em `7dbdb60d` (29 de 70 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/EnemyHud.lua
> HP bar e intent icon ancorados no sprite do inimigo (estilo Slay the Spire).
> Renderiza FORA do HudManager para ficar próximo ao sprite ao invés de num painel de canto.
>
> Uso em main.lua após EnemyRenderer.draw():
> local bbox = EnemyRenderer.draw(game, cx, cy)
> EnemyHud.draw(game, bbox, cx, cy)
>
> Se bbox for `false` (sprite não carregado), cai em posição default.

## L21-22 (em `setColor`, junto a `local INTENT_ICON = {`)

> Cache dos ícones de intent (preguiçoso). Mapa kind -> ícone: o kind é a
> categoria de LEITURA do golpe (src/data/enemies.lua).

## L41-42 (em `getIntentIcon`, junto a `return getIconByName(INTENT_ICON[kind or "attack"] or "intent_unknown")`)

> kind sem ícone declarado = "?" (desconhecido), nunca um ataque falso
> (fallback silencioso proibido: getIconByName já avisa se faltar PNG).

## L54-56 (em `DEBUFF_ICON`, junto a `local function intentPreview(enemy, player)`)

> Preview do intent (F1 gameplay-overhaul): usa Enemy:getIntentPreview se
> existir (kind + valor já com weak/vulnerável aplicados); fallback legado =
> ataque com enemy.damage.

## L68-73 (em `intentPreview`, junto a `function EnemyHud.intentSpec(enemy, player)`)

> O que o box do intent mostra — fonte ÚNICA do desenho, da medida e do
> tooltip (o número desenhado e o número explicado não podem divergir).
> text    "12" | "4×3" | "+5" | nil (golpe sem número: debuff/carga/invocação)
> extras  ícones pequenos depois do número (debuffs do golpe, bloqueio)
> pierce  golpe que atravessa o Bloqueio (marca vermelha no box)
> title/body  tooltip: nome do golpe + linhas montadas dos números CONGELADOS

## L91-92 (em `lines`, junto a `if it.pierce and (it.perHit or 0) > 0 then`)

> PERFURANTE: ícone próprio (lança furando placa) logo depois do número
> — o risco vermelho sobre o ícone do ataque lia como "ataque cancelado".

## L141-144 (em `lines`, junto a `local visibility = (enemy.getIntentVisibility and enemy:getIntentVisibility()) or "full"`)

> NÉVOA DE INTENÇÃO (Out/2026, src/systems/IntentVisibility.lua): o que
> o HUD pode mostrar deste anúncio. O intent continua congelado e inteiro
> em `it`; aqui só se decide o que SAI do spec — nenhum número escondido
> pode vazar pelo texto, pelo tooltip ou pela medida do box.

## L159-160 (em `lines`, junto a `text = I18n.t("enemy_kit.intent.unknown_value", nil, "?")`)

> type_only: o ÍCONE fica, o número vira "?"; perfurante e os
> NOMES dos debuffs seguem (são tipo, não peso) — durações não.

## L192-196 (em `lines`, junto a `local function hpBarGeom(cx, groundY, spriteWidth, barYOverride)`)

> ===== HP BAR =====
> Por default fica sob os pés do sprite. Se `barYOverride` for passado, desenha
> naquele Y (usado pra posicionar HP acima do sprite, logo abaixo do intent row).
> Geometria da barra (fonte unica: o desenho abaixo e a previa de dano —
> src/ui/DamagePreviewPanel — leem daqui).

## L217-218 (em `EnemyHud.drawHpBar`, junto a `local hpReal = enemy.health or 0`)

> Usa valor eased (enemy.disp.health) pra feedback Balatro-style.
> Enemy:update(dt) tickDa o easing. Fallback ao real se disp não existe.

## L256-258 (em `EnemyHud.drawHpBar`, junto a `if pct < 0.25 and pct > 0 then`)

> Quiver Balatro-style: HP crítico (< 25%) faz o número tremer randomicamente.
> Replica engine/text.lua:198 do Balatro, mas inline (sem DynaText) pra
> minimizar overhead num path quente. Intensidade escala com proximidade da morte.

## L270-271 (em `EnemyHud.drawHpBar`, junto a `local StatusPill = require("src.ui.StatusPill")`)

> ===== STATUS EFFECT BADGES (sob o HP bar) =====
> Delega pro componente StatusPill (fonte única de COLORS/ICONS + renderização).

## L278-291 (em `EnemyHud.drawHpBar`, junto a `local function hasStatus(enemy, name)`)

> Estados do inimigo que mudam as regras e não viviam em statusEffects:
> block   — enemy.armor, ganho pelo intent "defender". Era INVISÍVEL: o
> jogador batia e o dano sumia sem explicação.
> enraged — enemy.attackPattern == "aggressive" (abaixo de 30% de vida o
> dano vira ×1.5 em Enemy:takeDamage:101). Acontece em TODA batalha
> e era invisível: sem pill, sem toast, sem som — o número do
> intent simplesmente subia. Provavelmente o estado escondido mais
> caro do jogo, porque muda a conta do dano que o jogador leva.
> Ambos são derivados (leitura pura) — nada é escrito no inimigo aqui.
>
> FORWARD-COMPAT (combinado com o dono do Enemy.lua): se um dia a fúria virar
> um status de verdade em `enemy.statusEffects` (nome esperado: "enraged"), a
> lista de lá VENCE e o derivado é suprimido — assim a transição não duplica a
> pill em nenhum dos dois lados, aconteça na ordem que acontecer.

## L316-317 (em `list`, junto a `function EnemyHud.getStatusPillsDims(enemy, size)`)

> Dimensions da row de status pills (sem desenhar). Útil pra layout.
> `size` opcional: o caller passa o tamanho já ajustado à largura disponível.

## L323-324 (em `EnemyHud.getStatusPillsDims`, junto a `function EnemyHud.drawStatusEffects(enemy, cx, groundY, startX, startY, size)`)

> Desenha os pills começando em (startX, startY) top-left.
> Se startX/startY forem nil, cai em fallback centralizado em cx/groundY (legado).

## L343-347 (em `EnemyHud.drawStatusEffects`, junto a `local flashUntil = 0`)

> ===== INTENT (acima do sprite) =====
> Estilo Slay the Spire v2 (telegrafia Jul/2026): ícone GRANDE + número, bob
> vertical contínuo (o olho acha movimento), escala por severidade (strong é
> maior e pulsa mais rápido) e FLASH DE EXECUÇÃO quando o turno inimigo
> começa ("é AGORA que ele faz o que anunciou" — IntentFlashAction do StS).

## L349-350 (em `EnemyHud.drawStatusEffects`, junto a `local flashUntil = 0`)

> Flash de execução: Game:enemyTurn chama EnemyHud.flashIntent() antes de
> despachar a ação; o box dá zoom+glow por ~0.55s.

## L358-360 (em `EnemyHud.flashIntent`, junto a `local function intentBoxGeom(spec)`)

> O set de intents (Out/2026, v2) é desenhado NATIVO em 32x32: computeScale
> (32, 34) = 1, pixel 1:1. PNG maior que o alvo é reduzido por nearest
> fracionário e o pixel picota — foi o defeito do set v1 (64px → 0.53).

## L380-381 (em `intentBoxGeom`, junto a `function EnemyHud.getIntentDims(enemy, player)`)

> Dimensions do box do intent (sem desenhar). Útil pra layout.
> `player` opcional (Vulnerável congelado entra no número).

## L412 (em `EnemyHud.drawIntent`, junto a `if not rm then`)

> Bob vertical contínuo (StS: o intent "flutua" — movimento chama o olho).

## L417-418 (em `EnemyHud.drawIntent`, junto a `local scaleK = spec.heavy and 1.12 or 1.0`)

> Escala: golpe pesado é maior (perigo tem hierarquia) + flash de execução
> dá zoom no box inteiro. Transform centrado no box.

## L442-443 (em `EnemyHud.drawIntent`, junto a `local accent = Palette.BLOOD`)

> Cor semântica do intent: sangue = ataque, aço = defesa, ouro = buff,
> violeta = debuff/carga (ameaça que não é dano agora), verde = cura.

## L485-486 (em `accent`, junto a `require("src.ui.NavCursor").target("enemy:intent", boxX, boxY, boxW, boxH)   -- foco = hover (pad)`)

> Hover no box → tooltip com o NOME do golpe e o que ele faz, montado dos
> números congelados (intentSpec). Clareza total.

## L507-508 (em `numColor`, junto a `if spec.visibility ~= "full" then numColor = { 0.88, 0.88, 0.92, 1 } end`)

> número escondido pela névoa: "?" em pergaminho pálido, sem a cor
> semântica (um "?" vermelho leria como dano desconhecido mas certo)

## L532-534 (em `numColor`, junto a `require("src.ui.IntentVeil").draw(boxX, boxY, boxW, boxH, spec.visibility,`)

> NÉVOA: bruma correndo por cima do box quando a visibilidade não é cheia
> (e o aro piscando quando ela cai — src/ui/IntentVeil). Por cima do
> conteúdo e por baixo do flash de execução.

## L538-539 (em `numColor`, junto a `if flashK > 0 then`)

> FLASH DE EXECUÇÃO: lavagem branca + borda acesa enquanto o zoom decai
> ("o anúncio virou ação"). Desenhado por cima de tudo do box.

## L553-563 (em `numColor`, junto a `function EnemyHud.layout(game, bbox, fallbackCx, fallbackGroundY)`)

> ===== MAIN ENTRY =====
> bbox: table (from EnemyRenderer.draw) ou false se sprite não renderizou.
> Layout TOP-STACK (tudo acima do sprite):
> Linha 1 (mais alta): intent + status pills lado a lado, centralizados
> Linha 2: HP bar com número acima do bar
> Linha 3: sprite
> Deixa a área inferior livre pra cartas da mão.
> Geometria do cluster (intent + pills + HP) — PURA, sem desenhar. Fonte
> única do draw e da régua do palco da batalha (tools/test_enemy_stage):
> quem mede se o inimigo colide com a carta em hover precisa do MESMO
> retângulo que a tela pinta. `rect` = união do cluster + sprite.

## L576-577 (em `EnemyHud.layout`, junto a `local iw, ih = EnemyHud.getIntentDims(game.enemy, game.player)`)

> Layout: o cluster inteiro fica acima do sprite.
> Espaço necessário pra HP: 13pt font (número) + 4 gap + 10 bar = ~27px

## L580-582 (em `EnemyHud.layout`, junto a `local pillCount = #EnemyHud.collectPills(game.enemy)`)

> Zona: o cluster (intent + pills) não pode passar de 90% da largura da
> tela. Com estados novos (Bloqueio, Enfurecido) a row cresceu — quem cede
> é a ESCALA das pills, nunca a posição do intent (ui_layout_invariants §1).

