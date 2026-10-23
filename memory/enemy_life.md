---
name: enemy_life
description: Monstros vivos parados (23/Out/2026) - EnemyLife + EnemyStates (status visivel no corpo): dados por criatura em src/data/enemy_life/<id>.lua, fidgets ocasionais sobre o idle (entram e saem no quadro 0), particulas de pixel por tipo (smoke/embers/drips/spores/flies/mist/frost/ash/glint/bubbles), galeria `love . vida`, trava test_enemy_life
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
- Sorteio proprio (`EnemyLife._rng`, gerador separado): fidget e particula NUNCA consomem o `love.math.random`
  global, senao mudam a sequencia de quem desenha o cenario e a entrada (o `test_enemy_entrances` ficou
  instavel na sombra da ancora quando o fx usava o gerador global).
- FX: pool fixo (`EnemyLife.MAX = 128`, arrays paralelos, sem tabela por particula, sem closure no laco).
  Coordenadas em PIXEL DE ARTE relativas a pose de repouso (o corpo que investe nao arrasta a fumaca); desenho
  encaixado na grade de pixel do sprite (1 particula = 1 ou 2 px de arte). Cor = cor do tipo x
  `SceneGrade.color("enemy", ...)` (brasa/brilho/gelo so parcialmente graduados). Vento =
  `GrassField.windAt` do bioma (`SceneGrade.biome()`), zero em interior. `mist` desenha ATRAS do corpo (pes);
  o resto na frente. Particula NAO entra no oclusor do `LightEngine`: recebe a luz da cena como o chao ao lado
  (no oclusor ela acendia pixels fora do contorno e o `test_enemy_entrances` pegou o anel de luz). O oclusor
  recebe a mesma escala vertical do estado (fraco/forca), senao sobra uma linha de luz chapada acima da cabeca.
  Sem micro-luz e sem disco de brilho. Morte: para de nascer e tudo some em 0,5 s. reducedMotion: sem fidget e
  sem fx (o idle continua tocando, como ja era).
- Tipos: smoke (sobe, cresce para 2 px, inclina com vento), embers (sobe rapido, pisca), drips (pendura e cai),
  spores (flutua devagar), flies (orbitam o ponto, 3 por emissor, reflexo de asa), mist (tracos 4x1 nos pes,
  atras), frost (cai com vento, pisca), ash (sobe e vira com vento), glint (ponto que vira cruz e some),
  bubbles (sobe e estoura em 4 cantos).

## Estados (fase 2, 23/Out/2026): cada status visivel no corpo
Pedido do dono: "um estado para cada tipo de efeito... todos os mobs, todos os estados". Modulo
`src/ui/EnemyStates.lua` (dirigido pelo `EnemyLife`; o `EnemyRenderer` so le os resultados).
- Leitura AO VIVO a cada update de `enemy.statusEffects` + `armor` + `baseDamage` (forca ganha na luta, base = o
  primeiro valor visto deste objeto inimigo) + `attackPattern == "aggressive"` + veu de intencao proprio
  (`intentVeilCause == "veil"`). `EnemyStates.canonical` mapeia: fury e fases do kit (eclipse...) = enraged,
  frail = vulnerable. `swarm` (corvos) e token de chefe e NAO ganha estado (sem duplicar BossTokens).
- Intensidade por acumulos/duracao (0,45 a 1). Varios estados somam cor/ritmo/postura; PARTICULA de estado
  tem teto de 2 tipos (`MAX_KINDS`), escolhidos por `PRIORITY` (burn, poison, enraged, block, strength, regen,
  vulnerable, weak, veil). As particulas proprias da criatura (fx da fase 1) nao contam no teto.
- Visual generico (sempre pixel, sem halo, sem contorno, sem disco):
  poison = corpo esverdeado (multiplica r/b), bolhas sobem e gotas caem, idle 0,9x, tremida de 1 px a cada 3-6 s;
  burn = chamas 1x2 na linha do pe + brasas, metade de baixo escurecida (sprite redesenhado escuro sob scissor);
  weak = idle 0,7x, topo afunda 1-2 px de arte (escala vertical pelo pe), dessatura, gotas de suor da cabeca;
  vulnerable = brilhos brancos em pontos da borda, tremor curto a cada 2,5-4 s;
  strength = faiscas vermelhas sobem, idle 1,15x, corpo 1 px mais alto;
  enraged = baforadas de vapor da cabeca em rajada, idle 1,3x, pixel vermelho pulsando nos olhos (so com
  emissivo cadastrado em `src/data/enemy_emissives.lua`);
  regen = motas verdes sobem; block = varredura de brilhos de aco pela borda quando o bloqueio SOBE, depois
  tom de aco fraco enquanto armor > 0; veil = nevoa nos pes.
- Pontos do corpo: `EnemyStates.prepare(id)` (primeiro job do pre-aquecimento) le o idle 0 uma vez: ate 256
  pontos de borda, cabeca (media das linhas do topo), linha e vao dos pes.
- Override por criatura em `src/data/enemy_life/<id>.lua`:
  `states = { poison = { clip = "state_poison", fps = 8, fidgets = false, fx = { {kind, xr, yr, ...} } } }`.
  `clip` (8 a 12 quadros, quadro 0 e ultimo = idle 0) SUBSTITUI o idle enquanto o estado vale; entrar e sair
  trocam no quadro 0 do loop; fidgets so tocam por cima se `fidgets = true`; ataque/dano/morte continuam por
  cima e voltam para o loop do estado (`backToIdle` usa `EnemyLife.loopClip()`). `fx` troca as particulas
  genericas daquele estado pelas ancoras dadas (tipos do contrato).
- Morte: nenhum estado (cor, ritmo, particula). reducedMotion: cor e postura ficam (informacao), sem
  particula, sem tremida e sem mudar o ritmo.

## Ferramentas
- Galeria: `love . vida [id]` (`tools/vida.lua`): criatura na cena do ato. Setas trocam, 1-9 forca o fidget N,
  S percorre estados forcados (nenhum, cada status, veneno+fraco, queimadura+enfurecido; o rotulo mostra os
  estados ativos), F liga/desliga fx, espaco pausa, R limpa caches e recarrega dados e arte. `VIDA_SIZE=WxH` muda a janela.
- Capturas: `VIDA_VIRTUAL=1920x1080 VIDA_IDS=a,b,c lovec . test_one screenshot_vida` grava no save dir
  `vida_idle/runtime/<id>_<res>_{full,seq_1x,seq_2x,fx_3x}.png` (sequencia a cada 0,1 s por 6 s, fidget forcado em
  1 s; `fx_3x` = so os pixels de fx sobre a cena escurecida). `VIDA_STATES=poison+weak` forca estados na captura. `VIDA_FIXTURE=1` cria um `fidget_prova` temporario
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
