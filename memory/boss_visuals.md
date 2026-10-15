---
name: boss_visuals
description: Visual dos 6 chefes (Out/2026) — idle assado em loop de 12 quadros, passe de arte por regra, aura assinatura (BossAura), contorno de chefe, eixo do corpo do winter_monarch. Como mexer sem reabrir as queixas.
type: project
---

# Visual dos chefes

> "Boss 2 é meio estático flutuando, não intimida. Boss 1 não tem nada de
> especial. Boss 3 está bom. Boss 4 meio torto. Boss 5 melhor mas pode
> melhorar. Boss 6 gostei, mas dá pra pôr mais detalhe de pixel art."
> (dono, Out/2026)

## Diagnóstico (medido, não chutado)

- **Idles antigos = chuvisco.** 4 quadros com 37-46% dos pixels mudando
  entre quadros vizinhos: regeração do PixelLab, não movimento. O lich (6
  quadros assados em Set/2026) mexia 2-4% — e com `bobSpeed 0.55` (ciclo de
  11s) o corpo estava, na prática, parado.
- **No salão o LightEngine não tem lightmap**: os emissivos
  (`enemy_emissives`) não acendem nada lá. Olho/orbe pintado ficava apagado
  justamente onde TODO chefe luta.
- **winter_monarch "torto"**: não é inclinação da arte (cabeça x≈56, cinto
  x≈55, meio das botas x≈58 — vertical). O cajado à esquerda e a capa
  esvoaçando à direita puxavam o centro do BBOX pra x 63.5; centrado por
  bbox, o CORPO caía ~20px de tela à esquerda da porta e da barra de vida.

## O que foi feito

| chefe | idle | arte | aura |
|---|---|---|---|
| carrion_king | 12q @8fps: asas BATEM (rotação no ombro ±10°), peito, talões atrasados; bob na frequência da asa | penas cinza-pardo → brilho azul-violeta de corvo (todos os clips) | 4 corvos rondando (frente/trás), penas, brasas, coração tum-tum, contorno brasa |
| tower_lich | 12q @6fps: abas da capa com atraso, barra, botas pêndulo, tronco respira | — | círculo rúnico no chão, 5 runas na cintura, faíscas no orbe, almas subindo, contorno ciano; bob 2x + deriva |
| abyss_tyrant | 12q @6fps: respiração de fornalha, capa | — | fagulhas, cinza escura (recorta na lava), fumaça rasteira, contorno ESCURO |
| winter_monarch | 12q @6fps: capa tremula, peito | — | redemoinho de neve, sopro gelado, névoa, brilho no cajado; **axisX = 56** |
| rot_colossus | 12q @5fps: fôlego, braços balançam | — | esporos, moscas (asinha clara), gosma pingando até o chão, contorno tóxico |
| eclipse_queen | 12q @5fps: asas abrem/fecham, barra ondula | capa vira céu noturno (dobras, estrelas, barra violeta), luz na borda da membrana | disco do eclipse com coroa de raios, pétalas, brilho correndo na asa, contorno magenta |

## Onde mora

- `tools/bake_boss_idle.py` — idle por DESLOCAMENTO a partir do quadro 0
  (deriva zero; quadro 0 = base = o mesmo do hurt/death). Regiões em px do
  canvas, `lag` por movimento (pano atrasado = movimento secundário), loop
  fechado (não ping-pong). **Região tem que passar da borda** (amostragem
  inversa: cobre onde o pano CHEGA).
- `tools/boss_art_pass.py` — detalhe por REGRA de cor/vizinhança, vale em
  todos os clips + `south.png`. Rodar UMA vez sobre a arte original (a
  rainha não é idempotente); depois `bake_boss_idle.py run <id>`.
- `src/data/enemy_poses.lua` — `idle = { fps, cycle = true }`, `drift`,
  `axisX`.
- `src/data/boss_auras.lua` (dados) + `src/ui/BossAura.lua` (motor) —
  chamado só pelo `EnemyRenderer` com `enemy.isBoss`. Camadas: `rim`,
  `glows`, `orbit(s)`, `emit`, `floor`, `corona`, `glint`.
- Prova visual: `love . test_one shot_boss_aura all` (ou `2:death`,
  `1:hurt`) → `boss_aura_<ato>.png` + `boss_full_<ato>.png`.
- Trava: `love . test_one test_boss_visuals`.

## Regras aprendidas

1. **Efeito em pixel da ARTE, e em bloco legível.** Chefe a ~2x na tela tem
   pixel da arte de ~2px; partícula de 1 bloco era cisco invisível. `px = 2`
   (corvo `px = 3`) continua múltiplo inteiro da grade do sprite.
2. **Contraste com a SALA, não com o vazio.** Corvo preto sumia na parede
   escura (ganhou reflexo violeta e corpo cinza-violeta); fagulha laranja some
   na lava (o tirano ganhou cinza escura e contorno escuro); luz aditiva some
   no feixe branco da sala 6 (coroa do eclipse em mistura normal).
3. **`SpriteAnimation:draw` reseta a cor pra branco** — cor de silhueta vai
   como `tint`, nunca por `setColor` antes de várias chamadas.
4. Emissor que depende do chão (gota) pousa no UPDATE com o chão medido no
   último draw — pousar no draw quebra quando há vários updates por draw.

## Revisão combinada (Out/2026)

- Corvo de asa de 1 pixel com ponta clara lia como "risquinhos roxos
  soltos". Virou silhueta de pássaro de frente ("m", 9x5, corpo de 3px, asa
  de 2px, 3 quadros) desenhada a partir de máscara ASCII em `BossAura`
  (`parseShape`). Pena = diagonal de 3px que tomba; pétala = gota 2x2.
  **Partícula que é um traço reto de 2-3px lê como glitch, não como coisa.**
- A sala 6 ganhou um eclipse pintado na abertura do fundo: o disco da aura
  saiu (`corona.disc = false`), fica só uma coroa curta de raios na cabeça.
  Uma cena, um eclipse.

## Rodada 2 do dono (Out/2026)

- **Contorno colorido SAIU** de todos ("a arte já tem o contorno dela").
  Brilhos ficaram só pequenos (raio <= 8 px da arte; maior lê como bola de
  luz). `test_boss_visuals` trava os dois.
- **Natural > mecânico.** Emissor com intervalo FIXO (acumulador) virou
  chegada de Poisson; rajada com ±35%; órbitas com raio/velocidade/fase por
  corpo (exceto `regular = true`, runas); balanço com frequência própria.
- Colosso: moscas viraram ENXAME de agentes (alvo sorteado, aceleração
  limitada, tremido perpendicular — `swarm`); gosma `ooze` nasce em pontos
  PINTADOS (lábio, garras), forma → estica → cai com gravidade → espirra uma
  vez; esporos raros, lentos, foscos.
- Pés dos apoiados: a capa que balança passava rente às botas e a borda
  macia arrastava pixel do pé — `TYRANT_FEET`/`MONARCH_FEET` excluídos no
  bake (pé idêntico ao quadro 0 em todos os quadros).

## Queda na morte (Out/2026)

Quem voa (`pose = "floating"`), quando morre, CAI: `poseSink = (t/FALL_DUR)²`
(0.42s; reducedMotion 0.18s sem quique), quique curto + poeira no impacto, e
a margem de pé passa a ser a do QUADRO da death com o mesmo `FOOT_SINK` de
quem pisa — o cadáver repousa com o pixel mais baixo 2px dentro da linha de
chão que a cena passou (salão: scene_anchors; estrada: getRoadAnchor) e fica.
A descida linear antiga (0.7s) usava a margem do 1º quadro da death e sem
afundar: o corpo deitado terminava acima do chão. Trava `test_enemy_fall`
(todo flutuante × 6 salões × 3 tamanhos + estrada × 3 escalas de palco);
prova `SHOT_SIZE=1920x1080 love . test_one shot_boss_aura 2:death`.

**Chão do cadáver ≠ chão do vivo.** No salão 2 a linha do vivo (0.83) é a
faixa estreita colada na base da balaustrada; o lich morto deitado ali lia
"em cima do parapeito". `scene_anchors.deathYr` (só hall 2: 0.885, meio do
mosaico) → `GameplayScene` passa `opts.deathCy` → o flutuante escorrega a
linha de chão de cy pra deathCy junto da queda (cai pra frente). Como esse
chão fica abaixo do topo da mão, a MÃO DESCE e sai da tela quando o inimigo
morre nesse caso (`corpseUnderHand`). Demais salões e estrada: sem deathYr.

## HUD no eixo do CORPO (todos os inimigos, Out/2026)

> "o 29 e a barra estão à esquerda do corpo" (dono, inimigo de gelo)

Causa: o bbox devolvido pelo `EnemyRenderer.draw` tinha `cx` = centro do
CANVAS do sprite, e o EnemyHud ancora nele. Canvas com arma/cajado/capa/
margem de um lado só = HUD fora do corpo (medido a 1080p: glacier_knight
36px, obsidian 34, ember_imp 25, frost_wight 19...). Agora:
`EnemyRenderer.bodyAxis(id)` = mediana, nas linhas 20-80% do conteúdo do
quadro 0, do centro do maior trecho opaco de cada linha (override `axisX` em
enemy_poses quando erra: escudo largo, quadrúpede de frente, orbe grande —
hoje 7). O corpo é desenhado COM O EIXO no ponto pedido e o bbox devolve
esse ponto: HUD, sombra elíptica, aura e texto flutuante ancoram no corpo;
o billboard da viagem usa o mesmo offset. Trava `test_enemy_axis` (todo
diretório de inimigo: HUD <= 3px da arte do eixo, eixo na âncora ±1);
prancha `SHOT_SIZE=1920x1080 love . test_one shot_enemy_sheet`.

## Chão pela REGRA DO APOIO + sombra de contato (Out/2026)

> "os ratos parecem flutuar" (plague_rats)

O pé era o pixel opaco mais baixo; no monte de ratos é a ponta do rabo
enrolado, e os corpos pairavam. Agora (`EnemyRenderer` `groundOf`) o chão é a
linha mais baixa com >= M px "sólidos" (coluna opaca contínua >= 5px; M =
max(3, 6% da largura)) — ponta de rabo/lâmina/farrapo fina não conta. Rabo
GROSSO deitado (os ratos) a regra não separa: override `groundRow` na pose
(ratos = 89, patas). A pegada (footL..footR) dimensiona uma sombra de
CONTATO em degraus de pixel da arte sob quem pisa na estrada (a silhueta
projetada vai pra longe do sol e não escurecia o chão debaixo do pé) e a
elipse dos salões. Travas: `test_enemy_pose` (rabo sintético + ratos) e
`test_enemy_stage` (régua independente com a mesma regra). Prancha dos pés:
`SHEET_MODE=feet SHOT_SIZE=1920x1080 love . test_one shot_enemy_sheet`.

**Morte de quem pisa** usa a margem DO QUADRO (regra do apoio), não só a
do 1º quadro da death — corpo que tomba/desaba muda de base a cada quadro.
O `groundRow` da pose vale também na death (o quadro 0 é o do idle). A
morte dos ratos (monte afundando na estrada, cortado em linha reta) foi
refeita por `tools/bake_pile_collapse.py`: faixas do quadro 0 caem e
escorregam por cima das de baixo SEM redimensionar (achatar dizimava linhas
e virava chuvisco) → monte baixo de ratos mortos na estrada. Trava:
`test_enemy_fall` (cadáver de todo apoiado com o pé FOOT_SINK no chão).
Prancha dos cadáveres: `SHEET_MODE=death ... shot_enemy_sheet`.

## Olho apaga na morte + fogo pintado que queima (Out/2026)

- "O espantalho morre de olho aberto": a micro-luz já sumia na death, mas o
  olho PINTADO seguia aceso até o cadáver. `tools/death_eyes_off.py` segue
  cada âncora "olho" de enemy_emissives quadro a quadro (registro por SSD
  do retalho da cabeça + fallback de mancha pequena) e escurece o olho na
  2ª metade da morte. Cor sozinha pegava palha/trigo/fagulha. Exceções na
  ferramenta: SWEEP (lich, cor única), SKIP (o rastreio caía num realce).
- Fogo pintado só balançava com o corpo: `tools/bake_flame_flicker.py`
  (caixas por inimigo) estica a chama da base, ondula as pontas e sobe um
  tom de cor, 3 tremidas por volta do idle, no idle e no hurt —
  wicker_effigy (ombros + peito), hellhound (crina + rabo), abyss_acolyte
  (livro). Chefes com fogo têm a BossAura por cima.

**Cadáver apagado (2ª leva):** só o olho rastreado não bastava — o
espantalho tem a CARA inteira clara de abóbora (fenda laranja + dentes) e o
dono ainda viu o morto "de olho aceso e sorriso brilhando". `tools/corpse_dim.py`:
nos 4 últimos quadros da death tudo que é LUZ pintada (claro + saturado:
olho, boca, gema, núcleo, brasa, chama) perde a luz progressivamente, em
todos os 45; rosto declarado (FACES: espantalho) ganha pálpebra fechada e a
cara vai pra sombra. Prova pela cena real: `SHEET_MODE=death ...
shot_enemy_sheet [id]`.

## Pendente

- Círculo rúnico do lich: em 1024x768 a laje do salão 2 cai atrás da mão de
  cartas (limitação de enquadramento já registrada em
  [[enemy_pose_and_scene_anchor]] §2) — aparece em telas mais altas.
- Ataque com clip próprio só o carrion_king (o resto usa a investida
  procedural).

[[enemy_pose_and_scene_anchor]] · [[enemy_pipeline]] · [[lighting_engine]]

## Rei-carniça: corvos = contagem, ícone próprio, mergulho, som mais baixo (14/Out/2026)

> "O grito está muito alto... o ícone de corvos summonados é de outra carta...
> coloca o número de corvos voando ao redor dele... ataques temáticos" (dono)

- **Corvos ao redor = status `swarm`.** `boss_auras.carrion_king.orbit` tem
  `countBy = "swarm"`, `max = 10` (teto VISUAL; o pill mostra o número exato).
  `EnemyRenderer.draw` chama `BossAura.setCountFrom(auraId, enemy)` todo quadro;
  `BossAura.update` reconcilia o bando (`syncFlock`): corvo novo ENTRA com
  rasante (vem de fora da tela grande, mergulha abaixo do palco e sobe pra
  órbita, 0,95 s, um a cada 0,24 s), corvo a mais SAI voando pro alto (0,8 s).
  Espaçamento uniforme na órbita, suavizado quando o número muda. Primeira
  leitura (Continuar no meio da luta) e reducedMotion = já em órbita, sem
  rasante. **Contagem 0 = nenhum corvo**: corvo de ambiente mentiria sobre a
  revoada; o ambiente fica nas penas e brasas. Corvo maior (`px = 3`) e mais
  claro que antes, senão não dava pra contar na parede escura.
- **Ataque temático.** O intent carrega `swarm` (Enemy:rollIntent) e o Game
  passa `{ swarm = it.swarm }` ao `ER.triggerAttack`. Na Revoada, CADA golpe
  manda um corvo da órbita (rodízio) mergulhar até o painel do herói
  (`BossAura.playerTarget`, convertido por `inverseTransformPoint`), crescendo
  até 2,2× ao chegar na câmera, no MESMO apex do golpe (ATK_WINDUP+ATK_LUNGE),
  estoura 9 penas e volta na janela do recuo: o beat não alonga. O rei só faz
  o gesto de comando (`kind = "command"`, avanço de 8 px). Grito de corvo
  baixo (`diveSound`, 0,22, pitch 0,82, no máximo 1 a cada 1,4 s). Bicada
  Real (golpe dele): o avanço de sempre + `hitFeathers = 7` penas no painel.
  Sem corvo na órbita o golpe cai no avanço normal. reducedMotion: nenhum
  mergulho (só o número). Banquete de Carniça (cura) ficou como estava.
- **Ícone próprio** `assets/sprites/icons/status_crows.png` (PixelLab
  `create_image_pro`, referência de estilo `status_poison`, spec em
  `tools/pixellab_endless_icons.py`, candidato 7). Os 16 candidatos saíram
  corvo preto em preto (contraste 6 na métrica de `memory/ui_rendering.md`):
  remapeado pra violeta claro com contorno quase preto (contraste 39, faixa do
  violeta). Antes o pill usava `claw` (arte de carta). Ainda reaproveitam arte
  de carta, à espera de decisão: `focus` → `rune`, `eclipse` → `moon`
  (StatusPill.ICONS); TopBar usa `star`/`scroll`, Menu `star`; o EnemyRenderer
  cai em `shield_round` só se `armor_shield` faltar.
- **Som** (média do arquivo + ganho = nível efetivo):
  `boss_crows_caw` passa-baixa 4,5 kHz ×2 e -3 dB na fonte (média -15,2 →
  -19,3; energia acima de 4 kHz -24,7 → -32,3) e ganho 0,60 → 0,48: -19,6 →
  -25,7 dB. `boss_crows_flee` mesmo passa-baixa e -2 dB (-21,1 → -23,9), ganho
  0,60 → 0,45: -25,5 → -30,8. `boss_reveal_sting` (o grito do cartão, metal +
  corvos) ganho 0,85 → 0,50: -15,4 → -20,0. Rugido da invocação
  (`enemyBuffRoar`, só o rei invoca) ganho 0,55 → `Game.SUMMON_ROAR_VOLUME`
  0,33: -4,4 dB. Ninguém ouviu ainda.
- Trava: `test_boss_visuals` (0/3/6/teto, entrada, saída, mergulho, reduced,
  ícone ≠ arte de carta por nome e bytes, volumes). Prova:
  `CARDGAME_HEADLESS=1 CARDGAME_IDENTITY=x lovec . test_one shot_rei_carnica`
  → `rei_carnica_*.png` no save dir (0, rasante, 3, 6, teto, mergulho a/b/c,
  bicada).

### Rodada 2: corvo SPRITE, não forma procedural (14/Out/2026)

Revisão do lead: o corvo de máscara 9x5 em blocos (e ampliado 2,2x no
mergulho) lia como cruz/glitch. Trocado por sprite PixelLab:
`assets/sprites/characters/enemies/carrion_king/crow/frame_0..6.png` (32x32,
de perfil olhando pra direita, 7 quadros de batida de asa;
`tools/pixellab_crow_sprite.py base|pick|anim|install`, base =
create_image_pro com estilo do idle do rei, candidato 13; anim =
animate_image 6 quadros + o original). `orbit.sprite` aponta a pasta;
`BossAura.crowFrames` carrega com filtro nearest.
- Escala SEMPRE inteira: órbita `crowScale(r.scale) = max(1, floor(scale/2 + 0.5))`,
  rasante e mergulho em `FLOCK.big = 2` × isso (troca de degrau, nunca
  ampliação fracionada). Posição truncada no pixel de tela.
- Cada corvo com fase de asa própria (`h1`), 10 fps na órbita e 15 fora;
  virado no sentido do voo (órbita: frente vai pra esquerda, fundo pra
  direita; rasante/saída pelo deslocamento do quadro anterior). No mergulho
  plana (quadro de asa aberta) apontando pro herói: rotação limitada a ±0,9
  rad em degraus de 15°. Corvo de trás com tinta 0,70.
- Penas do impacto em `px = 2` (com 3 viravam borrão).
- O `CROW` procedural continua só no `orbitOne` genérico (nenhuma aura usa).


## Mecânica contada dos chefes 2-6 (15/Out/2026)

Os chefes 2-6 ganharam o pacote do rei-carniça (objeto contado na cena,
ícone de status próprio, golpe temático). Tudo em [[boss_mechanics]]; aqui só
o que mexeu na AURA:
- As 5 runas procedurais da aura do lich SAÍRAM: as runas agora são pedras em
  sprite contadas pelo status `runes` (`src/ui/BossTokens.lua`, desenhado pelo
  `EnemyRenderer` junto da `BossAura`, atrás/frente do corpo).
- Objeto da mecânica sempre em escala INTEIRA do chefe (`BossTokens.tokenScale`,
  `full` = escala cheia; runas, raízes, lua e bola de fogo em escala cheia,
  elo de corrente na metade como o corvo). Na metade, a runa lia como cisco
  a 1600x900.
- Golpe temático (`BossTokens.strike`): token que voa e some no apex (runa),
  projétil girado na direção do voo em degraus de 15° com rastro aditivo (bola
  de fogo, estilhaço de gelo, crescente girando) ou surgimento do pé da tela
  (raiz). Tudo chega no apex `ATK_WINDUP + ATK_LUNGE`; o chefe só faz o gesto.
- Ícones `status_runes/chains/frost/roots/moon` (PixelLab, referência
  `status_poison`); `focus → rune` e `eclipse → moon` continuam arte de carta.
