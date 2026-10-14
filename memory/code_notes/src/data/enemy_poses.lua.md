---
name: code_notes/src/data/enemy_poses.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/enemy_poses.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/enemy_poses.lua`

Origem: `src/data/enemy_poses.lua` em `7dbdb60d` (12 de 53 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-63 (junto a `local EnemyPoses = {}`)

> src/data/enemy_poses.lua
> ============================================================================
> POSE DOS INIMIGOS — apoiado no chão × flutuando de propósito
> ============================================================================
> Defeito que originou a tabela (Set/2026, reportado pelo dono): criatura
> pairando no ar COM sombra elíptica de contato embaixo. A sombra afirma
> "estou apoiado"; a pose afirma "estou no ar". As duas juntas não leem
> como nada — leem como bug.
>
> A correção NÃO é colar todo mundo no chão. É CLASSIFICAR:
>
> grounded  — tem pernas/pés/base. Pé do CONTEÚDO cravado no chão
> (EnemyRenderer já faz isso via clipMetrics.pad) e sombra
> de CONTATO: grande, próxima, opaca.
>
> floating  — espectro, aparição, criatura alada sem pé de apoio. Sobe
> `hover` (fração da altura do sprite) e balança `bob`.
> Sombra de ALTURA: menor, mais difusa, mais fraca e
> deslocada na direção oposta à luz — a linguagem visual de
> "isto está no ar", não "isto está apoiado".
>
> A classificação saiu de OLHAR os 21 sprites (assets/sprites/characters/
> enemies/<id>/animations/idle/south/0.png) — doutrina do projeto. O
> critério é literal: dá pra ver o PÉ tocando a linha de base? Bota,
> garra, casco, pata, base de lodo = grounded. Barra de manto que afina,
> farrapo que se desfaz, garra pendurada de asa aberta = floating.
>
> Campos (todos opcionais fora de `pose`):
> pose      "grounded" | "floating"
> hover     altura de repouso, fração da ALTURA DO SPRITE na tela
> bob       amplitude do balanço vertical, mesma unidade
> bobSpeed  rad/s do balanço (criatura pesada = lenta)
> shadowK   escala da sombra (largura); < 1 = mais longe do chão
> shadowA   multiplicador de opacidade da sombra
> drift     deriva HORIZONTAL do flutuante, mesma unidade do bob (só
> chefes: pairar parado lia "estático", Out/2026)
> idle      { fps, cycle = true } — idle assado em LOOP fechado (os 6
> chefes: tools/bake_boss_idle.py). Sem o campo: ping-pong no
> IDLE_FPS padrão do EnemyRenderer.
> groundRow linha (px do canvas do idle) do CHÃO — override da regra do
> apoio (EnemyRenderer: linha mais baixa com coluna opaca grossa,
> que ignora rabo/lâmina/farrapo finos). Declarar só quando a
> regra erra (rabo GROSSO deitado, base que não é o pé).
> shadowBaseK fração da altura do corpo que é PEGADA no chão (ShadowEngine
> v9, Out/2026): monte de ratos, touro, lobo — bicho largo e
> baixo. A sombra nasce no centro da pegada e a faixa da pegada
> não projeta (senão aparece um segundo bicho deitado à frente).
> Bípede em pé não declara (pegada = pé, sombra inteira).
> shadowRiseK fração acima da pegada que projeta (nil = tudo).
> axisX     coluna (px do canvas do idle) do EIXO DO CORPO — OVERRIDE do
> eixo automático (EnemyRenderer.bodyAxis, Out/2026). Declarar só
> quando o automático erra: escudo largo, quadrúpede de frente,
> cajado com orbe grande (conferido de olho com régua). O renderer
> centra pelo bbox do conteúdo; quando cajado de um lado e capa
> do outro desequilibram o bbox, o corpo sai do centro e o
> chefe lê TORTO (winter_monarch, Out/2026).
>
> ACESSIBILIDADE: com `reducedMotion` o `bob` some, o `hover` PERMANECE.
> Altura é informação (diz o que a criatura é), balanço é enfeite.
>
> Ver [[shadow_engine]] · [[ui_layout_invariants]] (regra 3: nada de
> fallback silencioso — id fora da tabela cai em grounded e AVISA).
> ============================================================================

## L75-78 (em `GROUNDED`, junto a `EnemyPoses.BY_ID = {`)

> OS 21 DO ROSTER (+ legados grave_slime / stone_golem / abyss_wraith)
> + LEVA NOVA de 24 (Out/2026, 4 por ato)

## L98-102 (em `stone_golem`, junto a `winter_monarch    = { pose = "grounded", axisX = 56,`)

> botas sob a capa. "Meio torto" (dono, Out/2026): o cajado pra fora à
> esquerda (x 7-30) e a capa esvoaçando à direita (até x 120) puxavam o
> centro do bbox pra x 63.5 — mas coroa, caveira, cinto e o meio das
> botas estão em x ~56. Centrado pelo bbox, o CORPO ficava 8px de arte
> (~20px de tela) à esquerda da porta, da barra de vida e do palco.

## L106-108 (em `idle`, junto a `hollow_farmer     = { pose = "grounded", idle = { fps = 6, cycle = true } },  -- botas`)

> === LEVA NOVA (Out/2026) — apoiados ===================================
> Idle de TODOS assado por deslocamento a partir do south.png (12
> quadros, loop fechado, pés fixos): tools/pixellab_new_enemies.py idle.

## L110-113 (em `hollow_farmer`, junto a `plague_rats       = { pose = "grounded", groundRow = 89, shadowBaseK = 0.35, idle = { fps = 6, cycle = true } `)

> groundRow 89: patas da frente (y 84-89 do canvas). O rabo enrolado
> desce até 93 e, com linha grossa deitada na horizontal, a regra do
> apoio não o separa do corpo — cravado o rabo, o monte pairava ("os
> ratos parecem flutuar", Out/2026). O rabo fica 4px À FRENTE do pé.

## L136-138 (em `fallen_angel`, junto a `abyss_wraith = { pose = "floating",`)

> === FLUTUANTES ==========================================================
> Espectro puro: manto que AFINA até virar nada. Sobe mais alto e
> balança mais — nada nele sugere peso.

## L148-152 (em `dusk_shade`, junto a `carrion_king = { pose = "floating",`)

> Rei-carniça: asas ABERTAS e talões PENDURADOS (dedos curvados, sem
> sola). Paira baixo e rápido — é batida de asa, não deriva etérea.
> Out/2026 ("não tem nada de especial"): o bob agora bate NA FREQUÊNCIA
> da asa (idle de 12 quadros a 8fps = 1.5s → 4.19 rad/s) — o corpo sobe
> a cada batida, como quem se sustenta no ar.

## L159-186 (em `idle`, junto a `tower_lich   = { pose = "floating",`)

> Lich da Torre: virou flutuante por DECISAO DE DESIGN do dono (Set/2026,
> 1a leva): "quero que o boss do ato 2 fique meio que flutuando, sem
> sombra no pe, indo pra cima e pra baixo lentamente". Na epoca ele era
> a UNICA excecao ao criterio literal da tabela — o sprite tinha botas
> de sola chata plantada e so o DADO dizia que ele flutuava.
>
> Set/2026, 2a leva: "o pezinho dele precisa parecer que ele esta
> realmente flutuando, entao ele precisa ficar inclinado para baixo. A
> capa tambem precisa ficar mexendo um pouquinho". A ARTE foi corrigida
> pra casar com o dado: as botas agora PENDEM com o bico pra baixo (pe
> relaxado de quem nao pisa) nos tres clips (idle/hurt/death), e o idle
> ganhou 6 frames com ondulacao de pano assada por deslocamento a partir
> de UM frame base. Ou seja: ele nao e mais excecao ao criterio literal
> ("da pra ver o pe tocando a linha de base?" — agora nao da), e SEGUE
> valendo o registro do porque, pra ninguem "corrigir" de volta.
>
> Numeros: hover BAIXO e bob LENTO (0.55 rad/s, o mais lento da tabela).
> Ele nao e um espectro esvoacante — e um morto-vivo coroado que paira
> porque despreza o chao. Pressa quebraria a leitura. O balanco RAPIDO
> dele mora na capa (ciclo ~1.4s no clip), nao no corpo: quem decide
> ondular o pano nao precisa acelerar o bob.
>
> Out/2026, 3a leva: "o boss 2 e meio estatico flutuando, nao intimida".
> 0.55 rad/s era um ciclo de 11s com 1.4% da altura: na pratica PARADO.
> Agora ciclo de ~5.7s com o dobro da amplitude e deriva lateral lenta,
> capa assada em 12 quadros com atraso entre as abas (bake_boss_idle) e
> o circulo runico girando no chao (BossAura) — o vao entre ele e o
> circulo e o que diz "paira".

## L193-194 (em `idle`, junto a `abyss_watcher = { pose = "floating",`)

> LEVA NOVA (Out/2026) — flutuantes. Olho-medusa: massa de carne com
> cortina de tentáculos, sem pé nenhum; paira pesado e lento.

## L199-201 (em `idle`, junto a `dusk_bat      = { pose = "floating",`)

> Morcego gigante: asas abertas e pés pendurados. O bob bate na
> frequência da asa (12 quadros a 8fps = 1.5s → 4.19 rad/s), como o
> rei-carniça — sobe a cada batida.

## L207-208 (em `idle`, junto a `eclipse_queen = { pose = "floating",`)

> Rainha do eclipse: capa imensa que se abre num leque, sem pé algum.
> Realeza não treme — deriva lenta e larga.

## L218-219 (em `warned`, junto a `function EnemyPoses.get(spriteId)`)

> Resolve a pose de um spriteId. Id desconhecido cai em `grounded` e
> AVISA uma vez (invariante 3 de ui_layout_invariants: sem fallback mudo).

