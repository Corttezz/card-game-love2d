---
name: Emblemas de classe + seleção com bloqueio/maestria
description: Classes representadas por OBJETO icônico (não personagem); idle procedural em ClassEmblem; tela de seleção em zonas (ClassSelectLayout) com estado bloqueado acorrentado e maestria via UnlockSystem
type: project
---

# Emblemas de classe (Out/2026)

**Decisão do dono:** os heróis chibi (`assets/sprites/characters/heroes/`)
"abriam margem para críticas" — personagem com rosto/corpo vira alvo de
leitura (gênero, etnia, proporção). Foram REMOVIDOS do repositório. Cada classe
agora é um OBJETO:

| classe  | emblema                                     | idle procedural |
|---------|---------------------------------------------|-----------------|
| warrior | espada cravada à frente de escudo redondo   | faixa de brilho dura (step) correndo pela lâmina a cada 3,4s |
| mage    | orbe arcano sobre anel de bronze rúnico     | flutua (bob), pulsa (luz aditiva nos pixels claros), 3 faíscas em órbita, sombra encolhe ao subir |
| rogue   | adaga com sangue escorrendo                 | gotas alternando VENENO (verde) e SANGUE pingando da ponta (ponta medida no PNG) |

- Arte: PixelLab `create_map_object` 128×128, `view=side`, `high detail`,
  `detailed shading`, `single color outline` + sufixo do contrato grimório
  (memory/sprite_design_queue.md). Escolhidos entre 3-4 variações cada:
  rejeitados o escudo com CRUZ (conotação religiosa), orbe com "G" (lia como
  logo), orbe-planeta (lia como Saturno), adaga com caveira cartoon.
- `mage.png` foi pós-processado: saturação ×0.72 / luz ×0.92 nos roxos
  (saiu neon) e 2 pixels escuros no brilho removidos (pareciam OLHOS — o
  orbe virava um rostinho; exatamente o que se queria evitar).
- Bloqueado: silhueta (cor 0.34/0.29/0.26) + `locked_chains.png` (correntes em
  X + cadeado, PixelLab) por cima, sem animação.
- Assets: `assets/sprites/emblems/{warrior,mage,rogue,locked_chains}.png`.
- Módulo: `src/ui/ClassEmblem.lua` — `update(dt, hovered)`,
  `draw(id, cx, cy, boxH, {hover, locked, flash, boxW})`. Escala por
  ALTURA DE REFERÊNCIA (`EMBLEM_REF`, orbe com ref menor), quantizada em 1/4 —
  escalar pelo conteúdo fazia o orbe 1,6× maior que a espada. Asset ausente /
  shader que não compila AVISAM no console (fallback silencioso proibido).
- Por que procedural e não PixelLab animate: o idle é sutil e por classe; no
  código ele acelera no hover, some no bloqueado e não custa geração. A
  animação gerada também redesenharia o objeto a cada frame (tremido).

# Tela de seleção v3 (`components/ClassSelectionScreen.lua`)

- Layout = ZONAS em `src/ui/ClassSelectLayout.lua` (`compute(sw,sh)` puro +
  `validate()`): título / 3 painéis / voltar / hint. Painel: emblema (flex) →
  nome → status → descrição → stats (VIDA + nº de cartas) → passiva → cartas
  iniciais (flex). Quem cede é a escala do emblema e das cartas; texto escala
  com `ts = clamp(min(sh/768, sw/1024), 1, 1.5)`.
- Status liberada: "MAESTRIA N" + pips (`maxLevel`) + barra de XP
  (`xp/xpToNext`; cheia no máximo). Bloqueada: requisito (`I18n.t(reqKey,
  vars)`, NUNCA truncado — quebra em 2 linhas) + barra `progress/goal` + "p/g",
  etiqueta BLOQUEADA no pé do emblema, véu sobre o resto, hint bar troca pra
  `class_select.locked_hint` no hover.
- Clique em bloqueada: `selectClass` retorna false, som `error`, tremor do
  painel; callback nunca roda. Liberada: flash/anel/faíscas e confirma em
  0,45s numa fila PRÓPRIA não-bloqueante (`EM.parallel(..., "class_select")`) —
  com `EM.after` na fila base, um evento travado de outra tela segurava o
  início da run (o test_all pegou).
- `resize()` = `updatePositions()` = rebuild completo (preserva lift/fx/shake).
- Contrato `src/systems/UnlockSystem.lua` (stub desta frente; a real vem da
  frente progressão): `isClassUnlocked`, `getClassUnlockInfo -> {unlocked,
  reqKey, vars, progress, goal}`, `getClassMastery -> {level, maxLevel, xp,
  xpToNext}`. Chaves `unlock.class.{default,mage_req,rogue_req}` (bloco
  `unlock` nos 5 locales; a frente progressão usa `unlocks`, plural).

# Validação

- `love . test_one test_class_select` — layout válido de 800×600 a 2560×1440,
  resize real com janela falsificada, bloqueada não inicia run (inclusive por
  clique), liberada inicia, assets carregam, zero referência a heróis.
- `love . screenshot_class_select` — `class_select_<W>x<H>_<estado>.png`
  (fresh/mixed/all/pick/denied em 4 tamanhos) + `class_emblems_strip.png`
  (8 instantes de cada emblema + versão acorrentada).
