---
name: Enemy Pipeline (sprites + animações via pixellab)
description: Guia passo-a-passo pra adicionar um novo inimigo ao jogo usando pixellab MCP (create_character + animate_character) + integração no EnemyRenderer
type: project
---

# Pipeline de Inimigos

Fluxo completo pra adicionar **um inimigo novo** (sprite + animações + integração no combate).

## Arquivos envolvidos

| Arquivo | Papel |
|---|---|
| `src/ui/EnemyRenderer.lua` | Desenha o inimigo no combate; escolhe sprite por ato via `resolveSpriteId` |
| `src/ui/SpriteAnimation.lua` | Reproduz frames PNG em loop, suporta trocar animação (idle/hurt/death) |
| `tools/install_enemy_animation.sh` | Baixa ZIP do pixellab e instala frames no layout esperado |
| `assets/sprites/characters/enemies/<id>/` | Onde os PNGs do inimigo vivem em disco |
| `src/core/Game.lua` | `Game:nextPhase` seta `game.enemy.spriteId = EnemyRenderer.resolveSpriteId(act, nodeType)` |

## Layout em disco (SpriteAnimation espera)

```
assets/sprites/characters/enemies/
└── <enemy_id>/
    ├── south.png              ← rotação estática (fallback se não houver anim)
    ├── east.png
    ├── west.png
    ├── north.png
    └── animations/
        ├── idle/
        │   ├── south/ 0.png 1.png 2.png 3.png
        │   ├── east/  0.png 1.png 2.png 3.png
        │   ├── west/  0.png 1.png 2.png 3.png
        │   └── north/ 0.png 1.png 2.png 3.png
        ├── hurt/   (opcional — mesma estrutura)
        └── death/  (opcional)
```

## Passo-a-passo

### 1. Gerar o character via MCP

No Claude (com MCP pixellab ativo):

```lua
-- Exemplo: criar "fire imp" pro ato 2
mcp__pixellab__create_character({
  description = "<descrição detalhada> + <sufixo de estilo obrigatório>",
  name = "Fire Imp (Act 2)",
  view = "side",
  outline = "single color black outline",
  shading = "detailed shading",
  detail = "high detail",
  size = 48,            -- inimigo comum. 56-64 pra boss/mini-boss
  n_directions = 4,     -- 4 direções (cheap). 8 só se precisar
  proportions = "{\"type\": \"preset\", \"name\": \"chibi\"}",
})
```

**Sufixo de estilo obrigatório** (cole ao final da description pra coerência com os outros sprites):
> `dark fantasy grimoire illustration pixel art, inked engraving style, earthy desaturated palette (bone white, rust orange, deep blood crimson, tarnished dark steel, charcoal black, burnt sienna, aged gold, dark leather brown), NO neon colors, NO bright magenta or cyan, crisp 1px pure black outline, detailed shading with clear darks and mid-tones, dramatic silhouette, moody upper-left lighting, limited 8-color palette, Slay the Spire and Magic the Gathering card art aesthetic`

Guarde o `character_id` retornado (UUID).

**Proportions recomendadas por tipo:**
- `chibi` — inimigos baixinhos/gosmentos (slime)
- `stylized` — wraiths, humanoides esguios
- `heroic` — golem, boss imponente
- `default` — neutro

### 1.5. Otimização: gerar SÓ south (o jogo só renderiza essa direção)

⚠️ **IMPORTANTE — economia de 75% de créditos:**

O `EnemyRenderer` consome **apenas** sprite na direção `south` (combate frontal estático). As direções east/west/north são **desperdício** — geradas mas nunca renderizadas.

**Pipeline default agora é single-direction.** Quando chamar `animate_character`, sempre passe:

```lua
mcp__pixellab__animate_character({
  character_id = "...",
  template_animation_id = "breathing-idle",
  directions = { "south" },  -- ← sempre incluir
  animation_name = "idle",
})
```

Sem o `directions=["south"]`, o pixellab gera para todas as 4 direções armazenadas no character (4× créditos por animação). 1 inimigo completo (idle+hurt+death) com single direction = **3 créditos**. Com 4 dirs = **12 créditos**.

**Cleanup retroativo já feito** em 2026-04-21: 162 PNGs órfãos (east/west/north dos 3 inimigos atuais) foram deletados; código atualizado pra ignorar esses subdirs.

### 2. Gerar animações (template mode, ~1 gen por direção)

Templates úteis do pixellab (49 disponíveis — `mcp__pixellab__get_character` lista todas):

| Template | Serve pra |
|---|---|
| `breathing-idle` | **idle** padrão (respira/balança) — 4 frames |
| `fight-stance-idle-8-frames` | idle mais dinâmico (8 frames, mais pesado) |
| `taking-punch` | **hurt** (recua, quadro de dor) |
| `falling-back-death` | **death** (cai pra trás, one-shot) |
| `cross-punch` / `high-kick` / `hurricane-kick` | ataque do inimigo no jogador (futuro) |
| `fireball` | ataque mágico ranged |
| `jumping-1` / `jumping-2` | boss especial |

Disparar (pode 3 em paralelo; limite concorrente é ~8 jobs = 2 anims × 4 direções):

```lua
mcp__pixellab__animate_character({
  character_id = "81ed1ec7-...",
  template_animation_id = "breathing-idle",
  animation_name = "idle",  -- só rótulo pra identificar
})
```

Processa em 2-4min. Polling via `mcp__pixellab__get_character`.

### 3. Instalar os PNGs

Quando o job terminar (`get_character` mostra as animations como `completed`):

```bash
./tools/install_enemy_animation.sh <UUID> <enemy_id_no_jogo> <anim_name>

# Exemplos
./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime idle
./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime hurt
./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime death
```

O script:
- Baixa o ZIP do character
- Instala `rotations/*.png` em `enemies/<enemy_id>/` (só se ainda não houver)
- Instala `animations/animating-<hash>/<dir>/frame_NNN.png` em `enemies/<enemy_id>/animations/<anim>/<dir>/N.png`

**Múltiplas animations no mesmo character:** a partir da 2ª chamada de `animate_character`, o pixellab cria pastas distintas no ZIP, nomeadas pelo **template_id** (não pelo `animation_name` que você passa). Use o **4º argumento (folder_pattern)** pra selecionar explicitamente:

| Template chamado | Pasta gerada no ZIP | Pattern pro script |
|---|---|---|
| `breathing-idle` (primeira anim do character) | `animating-<hash>` | `"animating-*"` |
| `taking-punch` | `taking_a_punch-<hash>` | `"taking_a_punch-*"` |
| `falling-back-death` | `falling_backward-<hash>` | `"falling_backward-*"` |
| `fireball` | `fireball-<hash>` | `"fireball-*"` |
| `cross-punch` | `cross_punch-<hash>` | `"cross_punch-*"` |

**Regra empírica:** o pixellab troca `-` por `_` no template_id e corta sufixos "-death"/"-idle". Se errar o pattern, o script aborta listando as pastas disponíveis — copia-cola da mensagem de erro é o jeito mais rápido de achar o pattern certo.

Exemplos práticos (os 3 inimigos atuais):

```bash
./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime  idle  "animating-*"
./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime  hurt  "taking_a_punch-*"
./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime  death "falling_backward-*"
```

### 4. Registrar no EnemyRenderer

Abra `src/ui/EnemyRenderer.lua` e adicione o mapeamento:

```lua
function EnemyRenderer.resolveSpriteId(actNumber, nodeType)
    local effectiveAct = math.min(actNumber or 1, 3)
    local map = {
        [1] = "grave_slime",
        [2] = "stone_golem",
        [3] = "abyss_wraith",
        -- adiciona aqui se for um novo ato ou variante
    }
    return map[effectiveAct]
end
```

Pra bosses únicos ou variantes por `nodeType` (ex: `elite` do ato 1 usar sprite diferente do `battle` normal), expanda o mapa:

```lua
if nodeType == "boss" then
    return ({ "act1_boss", "act2_boss", "act3_boss" })[effectiveAct]
elseif nodeType == "elite" then
    return ({ "act1_elite", ... })[effectiveAct]
end
return map[effectiveAct]
```

### 5. Testar

```bash
love . smoke_all       # deve continuar verde (nada quebrou)
love .                 # inicia uma run, veja o inimigo animado
```

No combate:
- **Idle** toca automaticamente em loop quando você entra na batalha
- **Hurt** toca ao tomar dano se `hurt/` existir (senão, overlay branco fake como fallback)
- **Death** toca quando `triggerDeath` for chamado (TODO: wire em Game quando `enemy.health <= 0`)

## Custos estimados (template mode = 1 gen/direção)

| Ação | Gens | Tempo |
|---|---|---|
| Novo character (4 dir, mínimo do API) | 1 | 2-3 min |
| Uma animação template (1 dir = south) | 1 | ~1 min |
| Uma animação template (4 dir) | 4 | 2-4 min |
| Uma animação custom (1 dir) | 20-40 | ~3 min |
| **Inimigo completo (idle+hurt+death, south only)** ← default | **1 + 1×3 = 4** | **~5 min** |
| Inimigo completo (idle+hurt+death, 4 dir) | 1 + 4×3 = 13 | ~10 min |

**Pro tips:**
- Sempre `directions=["south"]` em `animate_character` (jogo só renderiza south).
- Evite custom animations — template mode é 20-40× mais barato.
- Generate batch: 8 jobs concorrentes max.

## Rate limit / concorrência

- Limite padrão: **8 jobs concorrentes**. Se estourar, o job novo retorna `Insufficient job slots`.
- Uma animação template = 4 jobs (1 por direção).
- Estratégia segura: dispara 2 anims de uma vez (= 8 jobs), aguarda, dispara próximas.
- Upgrade de tier: até 30 jobs concorrentes (ver docs do pixellab).

## Troubleshooting

**"get_character mostra animations mas o ZIP não tem os frames"**
→ O job ainda está processando. Aguarde 1-2min e tente de novo. O ZIP pode retornar HTTP 423 se houver anim pendente — use `curl --fail`.

**"Rodei install mas o sprite fica estático no jogo"**
→ Confira que a pasta `animations/<anim>/<dir>/` tem PNGs e que os nomes são `0.png`, `1.png`, ... (não `frame_000.png`). O script faz essa renomeação; se o jogo não vê, confira que `EnemyRenderer.resolveSpriteId` retorna o nome certo e que a pasta casa.

**"Inimigo gigantesco na tela"**
→ `EnemyRenderer.draw` escala pra `targetHeight=200` (normal) ou `260` (boss). Ajuste se o sprite tem muito padding transparente. Para sprites menores, aumente o fator.

**"Estilo do novo inimigo não bate visualmente com os outros"**
→ Certifica que usou o sufixo de estilo obrigatório (passo 1). Se ainda destoar, regere com prompt mais específico reforçando paleta sépia.

## Estado atual do catálogo

Ver `assets/sprites/characters/enemies/` — atualmente:
- `grave_slime` — ato 1 (idle 4f × 4dir)
- `stone_golem` — ato 2 (idle 4f × 4dir)
- `abyss_wraith` — ato 3 (idle 4f × 4dir)

Nenhum deles tem `hurt`/`death` ainda — quando gerar, seguir este guia.

## Emissivos do monstro (LightEngine) — PASSO OBRIGATÓRIO pra inimigo novo

Todo monstro novo ganha micro-luzes nos pixels que a ARTE pintou como
emissivos (olhos, chamas, cristais, runas — nunca dourado/palha/osso):

1. `python3 tools/extract_enemy_emissives.py <enemy_id>` — detector de
   clusters saturados+claros; imprime candidatos no formato Lua.
2. **Revisar a folha anotada** (`tools/preview_out/enemy_emissives_sheet.png`)
   — o detector confunde dourado/palha com emissivo (falsos positivos do
   espantalho: ombros e mãos de palha).
   REGRA (pedido do usuário, Jul/2026): TODO monstro tem OLHOS emitindo na
   cor deles — órbita escura de caveira/visor ganha cor coerente (brasa,
   ciano, violeta...). Medir a posição por scan de pixel (não por zoom).
3. Adicionar a entrada revisada em `src/data/enemy_emissives.lua`
   (xr/yr relativos ao frame idle 0; r em fração da altura; intensity
   default 0.35 — 0.5 só pra núcleos/orbes; SUTIL é a regra).
4. Validar: `love . screenshot_worldroad enemy<N>_<id>` no bioma certo
   (cor-sobre-cor some — ex.: bog_ghoul verde no marsh precisou 0.50).

Runtime: EnemyRenderer.submitEmissives (pulso lento dessincronizado, apaga
na morte, mesma z da silhueta-oclusora) + billboard da viagem em
WorldRoad.drawEncounterFront ("olhos vindo na estrada"). Ver
memory/lighting_engine.md.
