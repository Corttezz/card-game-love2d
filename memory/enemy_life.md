---
name: enemy_life
description: Monstros vivos parados (23/Out/2026) - EnemyLife: dados por criatura em src/data/enemy_life/<id>.lua, fidgets ocasionais sobre o idle (entram e saem no quadro 0), particulas de pixel por tipo (smoke/embers/drips/spores/flies/mist/frost/ash/glint/bubbles), galeria `love . vida`, trava test_enemy_life
type: project
---

# Monstros vivos parados (EnemyLife)

Pedido do dono (23/Out/2026): parado na batalha o monstro estava "totalmente imovel". Referencia: Street Fighter 3,
muitos sprites mesmo em pe. Tres frentes de arte geram idle longo, fidgets e o arquivo de dados por criatura; o
runtime mora em `src/ui/EnemyLife.lua`.

## Contrato de arte (resumo; o completo esta no contrato da sessao)
- `animations/idle/south/0..N-1.png`: quadro 0 byte a byte igual ao idle 0 de antes (entradas, dano, morte e
  metricas de pe partem dele). 12 a 16 quadros, loop sem emenda. fps/ciclo seguem em `src/data/enemy_poses.lua`.
- `animations/fidget_<nome>/south/0..M-1.png`: 6 a 16 quadros, quadro 0 E ultimo = idle 0 (pixel a pixel).
- `src/data/enemy_life/<id>.lua` (tabela pura, sem comentario):
  `fidgets = { { clip, fps, weight } }`, `gap = { min, max }` (segundos de idle entre fidgets),
  `fx = { { kind, xr, yr, rate?, spread?, tint?, dir? } }`. xr/yr = fracao do canvas do idle 0 (mesma convencao
  dos emissivos). `dir` = "up" | "down" | "side". `tint` = {r,g,b} 0..1.

## Runtime
- Carga: `EnemyLife.load(id)` le `src/data/enemy_life/<id>.lua` com `love.filesystem.load`. Sem arquivo = so o idle
  (sem aviso). Malformado = `Debug.warn` uma vez e a criatura fica sem vida extra. Validacao unica em
  `EnemyLife.validate` (a mesma que o teste usa).
- Agendador (`EnemyLife.update(dt, id, animName, frame, busy)`, chamado no `EnemyRenderer.update`): conta `gap`
  segundos so enquanto o idle toca livre; quando vence, espera o idle chegar ao quadro 0 e devolve o clip
  sorteado por peso (nunca o mesmo duas vezes seguidas, salvo se so ha um). O `EnemyRenderer` toca pelo caminho
  de sempre (`playClip` -> `SpriteAnimation.new(id, "fidget_x", "south", fps)`, one-shot) e, ao voltar, o idle
  recomeca no quadro 2 (`EnemyLife.resumeIdle`), porque o ultimo quadro do fidget ja e o idle 0.
- Ocupado (`EnemyRenderer.lifeBusy`): ataque, dano, recuo, clip que nao e idle/fidget, chegada, defesa/buff/veneno,
  arco de golpe, morte, fase de `BossCinematic`, viagem do `WorldRoad`, reducedMotion. Ataque, dano, defesa, buff e
  morte INTERROMPEM o fidget na hora (`EnemyRenderer._dropFidget`), com ou sem clip proprio.
- Fidget NAO conta como ocupado em `EnemyRenderer.isBusy` (`EnemyLife.isIdleLike`): senao um piscar seguraria o
  turno e o `musicBreath`. O pe usa `framePads` do fidget igual ao idle.
- Pre-aquecimento: `getEncounterBillboard` (inicio da viagem) chama `EnemyLife.prewarm(id)`; cada update roda UM
  job (decodifica um clip inteiro + metricas de pe). Fidget so e sorteado depois de aquecido: nenhum PNG e
  decodificado no quadro em que ele comeca. Continuar (sem viagem) aquece nos primeiros quadros da luta.
- FX: pool fixo (`EnemyLife.MAX = 128`, arrays paralelos, sem tabela por particula, sem closure no laco).
  Coordenadas em PIXEL DE ARTE relativas a pose de repouso (o corpo que investe nao arrasta a fumaca); desenho
  encaixado na grade de pixel do sprite (1 particula = 1 ou 2 px de arte). Cor = cor do tipo x
  `SceneGrade.color("enemy", ...)` (brasa/brilho/gelo so parcialmente graduados). Vento =
  `GrassField.windAt` do bioma (`SceneGrade.biome()`), zero em interior. `mist` desenha ATRAS do corpo (pes);
  o resto na frente, e a camada da frente entra no oclusor do `LightEngine` (mesma luz chapada do corpo).
  Sem micro-luz e sem disco de brilho. Morte: para de nascer e tudo some em 0,5 s. reducedMotion: sem fidget e
  sem fx (o idle continua tocando, como ja era).
- Tipos: smoke (sobe, cresce para 2 px, inclina com vento), embers (sobe rapido, pisca), drips (pendura e cai),
  spores (flutua devagar), flies (orbitam o ponto, 3 por emissor, reflexo de asa), mist (tracos 4x1 nos pes,
  atras), frost (cai com vento, pisca), ash (sobe e vira com vento), glint (ponto que vira cruz e some),
  bubbles (sobe e estoura em 4 cantos).

## Ferramentas
- Galeria: `love . vida [id]` (`tools/vida.lua`): criatura na cena do ato. Setas trocam, 1-9 forca o fidget N,
  F liga/desliga fx, espaco pausa, R limpa caches e recarrega dados e arte. `VIDA_SIZE=WxH` muda a janela.
- Capturas: `VIDA_VIRTUAL=1920x1080 VIDA_IDS=a,b,c lovec . test_one screenshot_vida` grava no save dir
  `vida_idle/runtime/<id>_<res>_{full,seq_1x,seq_2x,fx_3x}.png` (sequencia a cada 0,1 s por 6 s, fidget forcado em
  1 s; `fx_3x` = so os pixels de fx sobre a cena escurecida). `VIDA_FIXTURE=1` cria um `fidget_prova` temporario
  (idle ida e volta) para quem ainda nao tem fidget de verdade e o apaga no fim.
- Trava: `love . test_one test_enemy_life` (dados validos e fixados no idle 0, agendador, pool sem alocacao por
  particula, morte, reducedMotion, integracao real com o `EnemyRenderer` usando um clip temporario no save dir).

## Adicionar uma criatura
1. Gerar idle longo e fidgets (contrato acima), olhar a arte antes.
2. Escrever `src/data/enemy_life/<id>.lua`; achar xr/yr no idle 0 ampliado.
3. `love . vida <id>` para olhar, `test_enemy_life` para travar.

## Fixtures desta frente
`ember_imp.lua` e `bog_ghoul.lua` foram escritos pelo runtime so com fx (sem fidget), antes das frentes de arte
entregarem. As frentes de arte sao donas deles e podem reescreve-los.
