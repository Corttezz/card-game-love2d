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
  Alfa BINARIO por particula: ou desenha com o alfa do tipo, ou nao desenha (nasce aos 0,12 s, some nos
  ultimos 0,2 s, pisca liga/desliga, morte apaga na metade dos 0,5 s). Sem pixel quase transparente na borda
  do corpo, que o anel do `test_enemy_entrances` leria como luz vazando.
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
  tem teto de 4 tipos (`MAX_KINDS`), escolhidos em duas passadas por `PRIORITY` (burn, poison, enraged, block,
  strength, regen, vulnerable, weak, veil): primeiro o 1o tipo de CADA estado ativo, depois os segundos. Com teto
  2 o veneno+fraco dava os dois tipos ao veneno e o fraco sumia. As particulas proprias da criatura nao contam.

### Estados v2 (24/Out/2026): shader no corpo + particula com detalhe
O dono testou na galeria e so notou o veneno ("quase imperceptivel"); a queimadura "parece cortada ao meio,
uma linha preta reta do torso ao pe" (era o sprite redesenhado escuro sob scissor) e o resto "nada". Refeito:
- `shaders/enemy_states.glsl` desenha o CORPO quando ha estado (`EnemyStates.drawBody`, chamado no lugar do
  `currentAnim:draw` do corpo). Quad com 10 texels de folga em volta do quadro (`EnemyStates.PAD`, cache por
  tamanho) para a chama sair do contorno; cada pixel e um texel da arte (grade do sprite). Uniforms reusados
  (`EnemyStates._SH`), nada alocado por quadro. Sem shader (falha de compilacao) volta ao tom por CPU
  (`EnemyStates.tint`) com `Debug.warn`. Toda tinta segue os pixels do sprite: gradiente liso, ruido de valor
  ou frente ondulada por ruido; NUNCA borda reta horizontal (trava `test_enemy_life`).
- burn: lingua de fogo por coluna nascendo das bordas voltadas pra cima (busca o primeiro pixel opaco abaixo,
  ate 14 texels), altura por ruido rolando, nucleo claro, laranja, ponta vermelho-escura que pisca, balanco
  lateral (calor); luz quente de baixo no corpo (gradiente pelo y do pixel x luminancia), base das chamas
  acesa na borda, fissuras de brasa finas e esparsas; brasas sobem das bordas de cima enrolando e esfriando
  (rampa amarelo-vermelho), cinza escura da cabeca; na estrada uma luz `LightEngine.submit` com
  `flicker = "fire"` no pe do corpo (`EnemyStates.submitLight`, tabela reusada).
- poison: tinta verde que pulsa em onda vertical (+ verde aditivo para sprite escuro), manchas doentes por
  ruido, bolhas em celula 8x8 que nascem, crescem para 5x5 com aro escuro e brilho e estouram em anel;
  gotas caem das bordas de BAIXO e espirram 2 pingos no chao (`splash`), miasma verde 1-3 px sobe.
- weak: dessatura forte e escurece (aplicado antes dos outros, para o veneno junto continuar verde), corpo
  afunda 2-3 px de arte, idle 0,7x, gotas de suor de 3 texels escorrendo pelo corpo, suor espirrando da
  cabeca, 3 estrelinhas tontas orbitando a cabeca (passam atras/na frente pela fase).
- vulnerable: pulso violeta (mistura + aditivo), rachaduras em zigue-zague perto da borda que brilham em
  sequencia e acendem todas no tremor (guarda quebrada), brilhos lilas na borda.
- strength (revisto pelo lead): pulso quente vermelho-alaranjado CONSTANTE no corpo (4,2 rad/s), borda de 1 px
  de arte (dentro do sprite) acendendo a cada pulso, onda dourada ondulada subindo por cima, lambidas de 1-3
  texels acima da borda na onda, faiscas continuas das bordas de cima (ombros, bracos) com rastro de 2 px.
- enraged: vermelho em batimento duplo com teto (o pico nao vira flash de dano), olhos pulsando, rajadas de 10 baforadas de vapor
  (1->2x2->cruz 3x3) com tremedeira de 0,3 s em cada rajada, idle 1,3x.
- regen: onda verde-menta sobe pelo corpo (frente por ruido), centelhas no corpo, cruzes verdes nascem
  abaixo das bordas de baixo e SOBEM para dentro do corpo (`absorb`), para nao ler como veneno.
- block (revisto pelo lead): SEM dessaturar e sem escurecer (so `max(c, ...)`: emissivo da criatura, como o
  fogo do diabrete, fica intacto); faixa de reflexo aco-azulada diagonal a cada 1,5 s, contorno de aco de
  1 px de arte nas bordas DENTRO do sprite, brilhos brancos piscando em pixels de borda.
- veil (revisto pelo lead: as manchas cinza liam como sujeira): transparencia em dither ordenado que corre em
  faixas diagonais pelo corpo (no maximo metade dos pixels some no pico da faixa, a criatura segue nitida),
  lavado frio leve, fiapos de nevoa finos (1-2 texels da borda, poucos), nevoa baixa nos pes.
- reducedMotion: o relogio do estado para (`ST.clock` so anda no update) e o shader fica num quadro fixo:
  tinta, chamas, bolhas e rachaduras paradas continuam informando; sem particula, tremida e ritmo.
- Provas: `lovec . test_one screenshot_estados` (env `ESTADOS_IDS`, `ESTADOS_LIST`, `ESTADOS_TAG`,
  `ESTADOS_REDUCED=1`) grava recortes por quadro no save dir; pranchas e GIFs em `tools/preview_out/estados_v2/`
  (sem estado, antes na main, tira a cada 0,3 s, recorte 3x; seis criaturas: escura, clara, pequena, grande,
  voadora e chefe no salao). "Antes" = os modulos de 2e665048 copiados no save dir de outra identity (o
  save dir tem prioridade no `require`).
- Pontos do corpo: `EnemyStates.prepare(id)` (primeiro job do pre-aquecimento) le o idle 0 uma vez: ate 256
  pontos de borda, cabeca (media das linhas do topo), linha e vao dos pes.
- Override por criatura em `src/data/enemy_life/<id>.lua`:
  `states = { poison = { clip = "state_poison", fps = 8, fidgets = false, fx = { {kind, xr, yr, ...} } } }`.
  `clip` (8 a 16 quadros; o contrato pede 8 a 12, o runtime aceita ate 16 como os fidgets; quadro 0 e ultimo = idle 0) SUBSTITUI o idle enquanto o estado vale; entrar e sair
  trocam no quadro 0 do loop; fidgets so tocam por cima se `fidgets = true`; ataque/dano/morte continuam por
  cima e voltam para o loop do estado (`backToIdle` usa `EnemyLife.loopClip()`). `fx` troca as particulas
  genericas daquele estado pelas ancoras dadas (tipos do contrato).
- Morte: nenhum estado (cor, ritmo, particula). reducedMotion: cor, postura e o quadro parado do shader
  ficam (informacao), sem particula, sem tremida e sem mudar o ritmo.
- Trava (`test_enemy_life`, `checkStatePixels`): shader compila; em 6 criaturas cada estado muda >= 4% do
  corpo contra o mesmo quadro sem estado; nenhuma faixa reta (fração alterada em janelas de 4 linhas acima e
  abaixo nao salta mais que 0,65; o detector pega a faixa queimada antiga com salto 1,0; bordas que seguem o sprite chegam a ~0,55); `drawBody` sem
  alocacao.

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

## Sopro de quem voa: `downdraft` (24/Out/2026)
Tipo de fx disparado por QUADRO, nao por taxa: `{ kind = "downdraft", xr, yr = 1, spread, rate?, tint?, strokes = { q1, q2 } }`.
`strokes` = quadros do idle (1-based, mesmo `currentFrame` do `SpriteAnimation`) em que a asa/capa desce; so vale com o
clip `idle` tocando (fidget, estado, ataque e morte nao sopram), so com `S.spawnOk` (nunca na morte, nunca em
reducedMotion). Cada batida solta `8 x rate` motas no pool fixo (`K_DRAFT = 16`, fora de `KINDS`; sem tabela nova por
mota): nascem na linha do chao em pixel de arte (`EnemyLife.frame(..., groundA)`, `groundA = ih - footY/scale`, passado
pelo `EnemyRenderer`), metade para cada lado, varrem para fora com arrasto (`drag`), sobem 3 a 9 px e assentam;
`pseed` guarda a profundidade propria de cada mota (+-2 px, `DRAFT_DEPTH`), senao viram uma fileira de tracos.
Desenho atras do corpo (`back`), 1x1 ou 2x1 quando rapida, alfa binario. Cor por bioma (`DRAFT_TINT`; salao = poeira,
`SceneGrade` inativo), 1 em 3 vira folha nos biomas com folha (`DRAFT_LEAF`: campos, planalto, crepusculo). Na
estrada a mesma batida da `GrassField.pokeAt(nx, camZ + BATTLE_REL, t, DRAFT_POKE)`: o `pokeAt` agora reaproveita a
tabela e aceita amplitude (4o argumento, padrao 1 = o comportamento antigo; o shader multiplica por `uPoke.w`).
Validacao: downdraft sem `strokes`, stroke nao inteiro e `strokes` em outro tipo sao rejeitados. Trava em
`test_enemy_life` (`checkDowndraft`): so nos quadros de batida, uma rajada por batida, fidget nao sopra, sem alocacao,
morte e reducedMotion sem sopro, todo flutuante do roster declara, nenhum apoiado declara.
