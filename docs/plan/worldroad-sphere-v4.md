# WorldRoad v4 — "Circle Land" (domo-esfera fiel ao Path of Kings)

Refactor do cenário rolante para replicar a MECÂNICA REAL do jogo de
referência, confirmada no APK: **`CircleLandController`** + GameObjects
`Circle`/`Sphere` + `ParallaxSpawner`/`ParallaxTextureOffset`. O mundo é um
**disco-terra gigante** (não um plano em perspectiva); avançar = o disco
gira; inimigos/castelo vivem na borda e **emergem de trás da curva**.

**Feedback do usuário (Jul/2026, com 3 prints de referência):**
o plano atual está "retinho"; inimigos devem surgir meio-corpo por trás da
curva; escala de assets incoerente (árvore ≈ arbusto); chão não parece
pixel-art; NÃO ter herói/boneco nos representando; retângulo escuro bugado no
topo do céu; castelo deve crescer conforme aproxima. "Tem que ser idêntica a
qualidade."

**Medidas extraídas dos prints de referência:**
- Domo verde ocupa ~50-55% inferior da tela; a crista é um ARCO visível
  (sag ~8-12% da largura nas bordas vs centro).
- Céu ~45-50% superior: azul com nuvens pixel chunky (blocos 4-8px). No nosso:
  manter identidade sépia grimoire, mas SEM a faixa/retângulo escuro no topo.
- Castelo: ancorado no CENTRO da crista, atrás do domo; base sempre oculta
  pela curva; escala ~1.0→~2.6× conforme progresso do trecho.
- Estrada: faixa de tijolos 2 tons descendo do castelo até a base da tela,
  seguindo a curvatura; borda escura 2px; linhas de tijolo horizontais.
- Inimigo: surge no centro da estrada ATRÁS da crista (só cabeça/tronco),
  desce/cresce até posição de batalha (~55% da altura), corpo inteiro.
- Props: pinheiros nas laterais do domo (~3× a altura dos arbustos), tufos de
  grama pixel (clumps 4-6px), montanhas em parallax atrás da crista.

**Arte:** usar MUITO o PixelLab (assinatura ativa, 1988 gerações) pra
backgrounds/cenário detalhados — nuvens, montanhas parallax, castelo-destino,
tijolos da estrada, tufos de grama — seguindo o sufixo de estilo grimório de
`memory/backgrounds_catalog.md`. Assets existentes de `assets/sprites/world/`
continuam valendo (árvores/arbustos/cercas/placas).

**Out of scope:** mudanças de gameplay/cartas/HUD; sfx.

## Step 0 — Gerar assets de cenário via PixelLab

Leva 1 (bioma fields/ato 1): cloud_0 (96×48), cloud_1 (64×32),
mountains_fields (400×112, strip parallax), castle_goal_fields (224×288),
road_bricks (64×64 tileável lineless), grass_tuft (32×32). Salvar em
`assets/sprites/world/` com o contrato de nomes do WorldRoad. Levas 2-3
(highlands/abyss) depois da validação do bioma 1.

Critérios: PNGs salvos e carregando via tryLoadPng; paleta sépia coerente
(checklist do backgrounds_catalog).

---

## Step 1 — Projetar a geometria do Circle Land

Especificar o novo modelo de render em `src/ui/WorldRoad.lua` (substitui a
projeção de scanline plana):

- **Domo**: círculo gigante de raio R (~2.2× largura da tela) com centro
  abaixo da tela; o topo do círculo é a crista curva. `crestY(x) = cy -
  sqrt(R² - (x-cx)²)` dá o arco.
- **Coordenada de mundo**: posição angular θ ao longo do disco; avançar =
  `worldRot += v`; um prop em θ aparece quando `θ - worldRot < janela`,
  posição na tela = ponto no arco + descida radial conforme se aproxima.
- **Painter's order** (a oclusão é de graça, sem stencil): céu → nuvens →
  montanhas parallax → CASTELO (escala por progresso) → INIMIGO emergindo →
  PREENCHIMENTO DO DOMO (oculta a base de castelo/inimigo) → estrada sobre o
  domo → props do lado de cá da crista → poeira/efeitos.
- **Escala por tipo** (coerência): tabela worldSize por kind — tree 2.4u,
  pine 2.6u, deadtree 2.2u, fence 1.0u, sign 1.2u, bush 0.7u, rock 0.55u,
  flowers 0.4u; px = worldSize × fator de proximidade radial.
- Sem herói e sem poeira de passos (remover drawHero/spawnDustPuff do fluxo).
- API pública preservada: draw/update/travel/isTraveling/setBiome/
  getRoadAnchor/BATTLE_REL (GameplayScene não muda de contrato).

Critérios: doc de design curto no topo do arquivo + assinatura das funções
novas; nenhum uso restante de rowNormOf/relOf plano.

## Step 2 — Implementar o domo + estrada curva + props angulares

Reescrever o render core conforme Step 1:

- Domo preenchido em 2 tons de verde-sépia com dither pixel na borda (chunks
  4px), tufos de grama determinísticos que giram com worldRot.
- Estrada: faixa curva do centro-base até o ponto da crista onde fica o
  castelo; largura afunila; tijolos = fileiras horizontais alternadas 2 tons +
  borda escura 2px; as fileiras ROLAM com worldRot (sensação de giro).
- Props em θ com a tabela de escala do Step 1; spawn atrás da crista, fade-in
  desnecessário (a curva já oculta); reciclagem ao sair pela base.
- Montanhas parallax + nuvens chunky mantidas (ajustar pra ficarem ATRÁS da
  crista sempre).

Critérios: `love . screenshot_worldroad full` mostra arco visível na crista;
árvore claramente ~3× arbusto; nenhum herói; 60fps no demo interativo.

## Step 3 — Inimigo emergindo da curva + castelo crescendo

- **Encounter**: durante travel, inimigo é desenhado ANTES do preenchimento
  do domo, posicionado no arco atrás da crista → primeiro só a cabeça,
  depois tronco, corpo inteiro ao cruzar a crista (idêntico ao print 2 da
  referência); termina plantado no BATTLE_REL com handoff pro EnemyRenderer.
- **Castelo**: sprite ancorado no centro da crista, atrás do domo (base
  sempre oculta); escala lerp 1.0→2.6 com `progress = (camadas andadas no
  trecho)/8`; substitui a "vista ascendente" atual (a vista panorâmica vira
  só montanhas parallax).
- Fix do bug: remover o retângulo escuro no topo do céu (rework do gradiente:
  bandas sólidas chunky, topo apenas ~15% mais escuro que o meio, sem faixa
  preta; conferir também o strip da topbar nos screenshots).

Critérios: keyframe do tour mostra inimigo meio-corpo atrás da crista;
castelo visivelmente maior a cada keyframe de progresso; céu sem retângulo.

## Step 4 — Validar contra as referências e iterar

- Atualizar `tools/demo_worldroad.lua` (tour): remover keyframes de herói;
  adicionar keyframes: k_emerge (inimigo meio-corpo), k_castle_near
  (progress 0.9, castelo grande), k_dome (arco visível sem inimigo).
- Rodar tour, ler os PNGs e comparar 1:1 com os 3 prints de referência
  (composição, curvatura, oclusão, escala, pixel-art do chão, céu).
- Iterar tuning (R do domo, velocidades, larguras) até bater visualmente.
- Rodar smoke tests (acts/map/effects/combos) e `love . play warrior`.

Critérios: 6 keyframes aprovados lado a lado com as referências; smokes
verdes; sem regressão no gameplay.

## Step 5 — Atualizar documentação

Atualizar `memory/worldroad_scene.md` (nova geometria Circle Land, remoção do
herói, tabela de escalas, painter's order) e a linha correspondente no
CLAUDE.md §2. Registrar lições (por que domo > scanline plano pra esse look).

Critérios: memory reflete a v4; CLAUDE.md em sincronia; backlog atualizado.
