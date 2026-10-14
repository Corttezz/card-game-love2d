---
name: card_icon_animation
description: Pipeline de ícones de carta ANIMADOS (PixelLab animate_object v3 → icons_anim/ → canvases por frame no CardFrame). Como animar carta nova, contrato, pegadinhas.
type: project
---

# Ícones de carta animados (cartas "vivas")

Cartas raras/lendárias podem ter a ilustração central animada em loop idle
sutil (padrão Balatro "carta viva"). Piloto: `warrior_standard_bearer`
(Porta-Estandarte, rare) — pano do estandarte balançando ao vento.

## Arquitetura (decisão Jul/2026)

**A animação vive DENTRO da imagem da carta, via CANVAS VIVO — não como
overlay, e não como swap por tela.**

```
assets/sprites/icons_anim/<icon_name>/frame_NNN.png  (+ meta.lua com fps)
    ↓ IconFramesLoader.get(iconName)
CardFrame.render(card)  → detecta frames → pré-renderiza a carta COMPLETA
                          1× por frame (renderOne com iconOverride)
                          e devolve um canvas VIVO (o que vira instance.image)
    ↓ animCache[key] = { canvases = {9×Canvas 96×144}, fps, live, lastIdx }
CardFrame.update()      → chamado no love.update (main.lua, TODOS os estados):
                          quando o índice de frame muda, blita canvases[idx]
                          no canvas vivo (replace+premultiplied, 1 draw)
```

**CARTA VISÍVEL = CARTA VIVA (regra do dono, 13/Out/2026 — revoga o gating
por interação de Jul/2026):** "a todo momento as cartas que estão sendo
exibidas na tela eu quero que elas fiquem com a animação sendo mostrada.
Elas não podem estar estáticas em NENHUM tipo de visualização em nenhum
local." `instance.image` continua sendo o canvas ESTÁTICO (frame 0);
`CardFrame.displayImage(card)` é a REGRA (o que desenhar agora) e
`CardFrame.liveImage(card)` o MECANISMO (o canvas do quadro corrente).
Toda tela pergunta `displayImage` e troca `instance.image` por ele
TEMPORARIAMENTE durante o draw (restaura no fim — o estado nunca guarda o
quadro vivo): `Card:draw` (mão, coringas ativos, espólios, loja no cavalete
e no pergaminho, pacote, cartas iniciais da classe, revelação de desbloqueio,
voo do combate, pickers), `CollectionScreen.drawCardMini` + inspeção,
`CardGridRender` (Deck Viewer, Gerenciador de Coringas), `CardDetailPanel`,
`ShelfItem`, `CardInspectModal`, `UnlockReveal`, `UnlockShowcase`,
`JokerSlot`, carta voando pro deck na `CardRewardScreen`. Hover e seleção
continuam valendo (lift, tilt, tooltip) — só não são mais condição.

**Única exceção: `reducedMotion`** (Configurações → Jogo). A opção remove
MOVIMENTO: `CardFrame.liveEnabled()` fica falso, `displayImage` devolve o
estático em todo lugar (hover NÃO reanima) e os overlays procedurais do
`CardAnimationLayer` (brasas, gotas, halo) somem junto. Informação nunca
sai: o frame 0 é a ilustração inteira.

Trava: `tools/test_cards_always_live.lua` — nenhum arquivo de `components/`
ou `src/` chama `liveImage` (só o CardFrame); sem hover `Card:draw`,
`CardGridRender` e a grade da Coleção desenham o quadro corrente e o quadro
avança com o relógio simulado; com reducedMotion desenham o estático; o
frame 0 composto pelas camadas é pixel a pixel o render direto; 20 cartas
pedidas no mesmo quadro ganham vida em ondas. Prova visual:
`love . screenshot_cartas_vivas` (duas capturas por cena sem hover + imagem
da diferença, em `tools/preview_out/cartas_vivas/`).

Por que não overlay por cima do canvas: ficava FORA do mesh warp 3D do
hover (ícone "flutuando" reto sobre carta entortada), fora do HoloShader/
editions, e cobria o recess shadow do art slot. Com o frame dentro da
imagem, warp + holo + editions + CRT pegam a animação de graça.
Custo: 9 canvases 96×144 (~0,5 MB) por carta animada em uso; não há blit —
`liveImage` devolve direto o canvas do quadro corrente (ver Performance v11).

**Pontos de código:**
- `src/ui/IconFramesLoader.lua` — frames + fps (meta.lua opcional, default 8).
- `src/ui/CardFrame.lua` — `render` multi-frame + canvas vivo,
  `CardFrame.update()` (tick global), `getAnimation(card)`.
- `main.lua` (`love.update`, topo) — chama `CardFrame.update()`.
- `src/ui/card/components/CardArtSlot.lua` — `layout()` compartilhado +
  `opts.iconOverride` (handle `{size, draw}`); geometria IDÊNTICA ao estático.
- `src/ui/card/CardAnimationLayer.lua` — procedural (shine/sparkle) SÓ roda
  quando NÃO há frames (senão duplicaria movimento).

## DOUTRINA (regra do dono, Jul/2026)

**Animação de ícone é PARTE DO PIPELINE de criação de carta** (passo 10 do
memory/card_creation_flow.md), não um extra. Duas regras inegociáveis:

1. **OLHE a imagem ANTES de escrever a animação.** `Read` no PNG do ícone e
   descreva pra si mesmo o que existe na cena (personagem? objeto? fogo?
   pano? luz?). A animação certa nasce do sujeito real da arte — pano
   ondula, fogo tremula, faísca cintila, personagem respira, metal reflete
   um brilho passageiro. NUNCA escrever prompt de animação sem ter visto a
   arte.

2. **A intensidade do movimento segue a RARIDADE** (feedback do Daniel: o
   estandarte rare ficou "bem movimentado" — certo pra rare, demais pra
   starter):

   | Raridade | Intensidade | fps | Vocabulário do prompt |
   |---|---|---|---|
   | basic/common | quase imperceptível — respiração, 1 ponto de brilho | 6 | "barely perceptible", "very slightly", "faint" |
   | uncommon | sutil — um elemento secundário se move devagar | 6-8 | "gently", "subtle", "softly" |
   | rare | visível — o elemento principal se move com clareza | 8 | "waving", "flickering", "swaying" |
   | legendary | vivo — movimento protagonista + brilho/energia | 8-10 | "dancing", "pulsing with energy" |

   Em todos os níveis o sufixo do script trava: "everything else perfectly
   static, seamless loop, colors and silhouette unchanged".

## Como animar uma carta nova

1. A carta precisa de ícone único em `assets/sprites/icons/<card_id>.png`
   com `object_id` PixelLab conhecido (lote Jul/2026:
   `tools/preview_out/newcards_jobs.json`). Ícone antigo sem object_id:
   usar MCP `animate_object` com `custom_start_frame_base64` (o mesmo
   padrão host-object usado nas animações do WorldRoad).
2. Adicionar entrada em `ANIMS` de `tools/pixellab_animate_card_icons.py`
   (object_id + descrição do movimento + fps) e rodar:
   `queue` → aguardar ~1-5min → `poll` → `check`.
3. Validar visual: `love . preview_card_anim <card_id>` → contact sheet em
   `~/Library/Application Support/LOVE/card-game/preview_card_anim.png`.
   SEMPRE olhar a imagem (regra do dono: nada visual sem screenshot).
4. Ver no jogo: `love .` — mão, reward e loja já funcionam sem code change.

## Contrato da descrição de animação

- Foco no movimento de UM elemento; resto: *"everything else perfectly
  static"* + *"seamless loop, colors and silhouette unchanged"* (o script
  já concatena esse sufixo).
- mode=v3, frame_count=8 → 9 frames (frame 0 = ícone original, é o que
  garante zero "pop" entre estático e animado).
- Movimentos que funcionam: pano/fogo/fumaça/energia/gotejar/pulsar.
  Evitar: mudar pose/silhueta (v3 distorce o subject).

## Pegadinhas

- **Stub de `CardFrame.render` vazando entre suites = flake de 1 em 9**
  (Out/2026): `tools/balance_sim.setup` troca `CardFrame.render` por um stub
  que devolve um canvas compartilhado SEM preencher o cache do CardFrame;
  `test_instant_parity`/`test_balance_pipeline` chamavam o setup e não
  restauravam, então `test_class_select` (8 suites depois) montava o set de
  frames como `{nil, c2..c9}` — `#` diz 9 e o blit caía no slot vazio só
  quando `floor(t*fps) % 9 == 0`: "Drawable expected, got nil" em
  `CardFrame.lua:423`, uma rodada a cada ~nove, por horário. Parecia carga.
  Travas: `liveImage` recusa set sem frame 0 (avisa 1× por carta e fica no
  estático), `frameIndex` nunca vira NaN, `blitFrame` com slot vazio marca
  `broken` e o set sai do cache; o runner (`run_all_tests`) restaura
  funções compartilhadas vazadas e imprime `[leak] <suite>`; o teste de
  `test_class_select` roda em relógio simulado (como `test_discovery_mark`).
  Regressão: `test_card_live_hover` §4. O teto do `animCache` virou MACIO:
  só expulsa animação parada há `STALE_SECS` — 25+ cartas vivas no mesmo
  quadro não se expulsam (thrash de 8 composições por quadro).
- **Reprovar/apagar animação SÓ entre runs da fábrica**: um `run` em
  andamento carrega o jobs file na memória; apagar frames/entrada no meio
  faz o pre-check re-baixar o group velho (caso joker_vampire v2 zumbi).
  O save agora recarrega do disco (não ressuscita entradas), mas o
  pre-check do run JÁ em execução ainda usa a memória — regra prática:
  esperar o run acabar, aí limpar e relançar.

- **1 job de interpolação POR VEZ na CONTA inteira** (lição Jul/2026,
  confirmada 2×): animate_object com custom_start_frame devolve group id
  válido mas a API DESCARTA silenciosamente jobs concorrentes — mesmo em
  hosts DISTINTOS (nem aparecem como pending; o group some do get_object).
  Fluxo obrigatório: submeter 1 → poll get_object até o bloco
  `[group: X] ... unknown: <url>/{i}.png` aparecer → baixar → só então
  submeter o próximo (~2-6 min/job). Driver serial de referência ficou
  documentado neste arquivo; group id retornado ≠ job aceito.

- **Backblaze 403 no urllib**: o bucket dos frames é público mas bloqueia o
  User-Agent default do Python e rejeita header Authorization. O `fetch()`
  do script já manda UA de curl e só usa Bearer em api.pixellab.ai.
- **Animação "morta"**: v3 às vezes gera frames quase idênticos (lição do
  luminaire). `check` compara md5 dos frames; se acusar MORTA?, regerar com
  descrição de movimento mais explícita (`replace_existing=true`).
- **`check` de md5 detecta animação MORTA, nunca animação ERRADA** (lição
  Set/2026, lote das 12 cartas órfãs): 8 das 12 animações passaram no `check`
  com "9 frames, 9 distintos — OK" e estavam quebradas. Frames distintos é
  exatamente o que uma animação que destrói a arte produz. O que passou pelo
  md5 e só o OLHO pegou:
  - `warrior_eternal_bulwark` — as portas do portão **dissolveram** ao longo
    do loop até sobrar um arco vazio (o modelo leu "portão" como abrível,
    mesmo com "the doors never open"); frame 8 vazio → frame 0 sólido = pop.
  - `warrior_adrenaline_rush` — "fluido girando no cilindro" virou uma bola
    de fogo crescendo no topo: o injetor virou tocha (silhueta destruída).
  - `rogue_toxin_master` — os "fumos verdes" viraram tentáculos FORA da
    silhueta da máscara.
  - `mage_primordial_storm` — o orbe de fogo **trocou de cor** para ciano ao
    longo do loop (viola "colors unchanged" e o loop não fecha).
  - `mage_radiant_prayer` / `warrior_taunt` / `rogue_poison_dart` — amplitude
    e matiz saindo da faixa da raridade; "glint" virando mancha branca
    estourada.

  **E a lição levou DUAS voltas.** A v2 destes oito foi registrada aqui como
  "todos aprovados na 2ª tentativa" — e não era verdade. Na inspeção visual
  antes do merge, três continuavam quebradas: `warrior_eternal_bulwark` (as
  portas somem no meio do loop, arco vazio nos frames 4-6), `mage_primordial_storm`
  (os orbes de fogo carbonizam de laranja para preto, loop não fecha) e
  `mage_radiant_prayer` (o sol migra de amarelo para vermelho). Estão em
  `tools/preview_out/_quarentena_anim/`, FORA de `icons_anim/` — carta com
  ícone estático é melhor que carta com animação quebrada.

  O erro de processo foi escrever "aprovado" na memória sem ter olhado o
  contact sheet da v2. **Escrever a regra não é cumprir a regra.**

  **Regra: `check` verde NÃO é aprovação — é só pré-requisito.** Nenhuma
  animação entra sem contact sheet olhado a 3× (64px esconde o defeito: a
  lâmina magenta do `rogue_leech_blade` lia como vermelho escuro a 1×).
  Grid rápido de N cartas × 9 frames com PIL, sem abrir o LÖVE:
  `tools/preview_out/anim_grid_12.png` foi gerado assim.
  Mesma lição que o áudio deu no mesmo dia: header de MP3 válido não diz
  nada sobre o som servir ao design. Validador automático prova que o
  ARQUIVO existe e é bem-formado; só o olho (ou o ouvido) prova que ele
  serve. Ver [[sfx_generation]].
- **Vocabulário de prompt que corrigiu os 8 casos acima** (v2, todos
  aprovados na 2ª tentativa): declarar o sujeito como parede/estátua e não
  só "static" (`"the doors are a solid stone wall that never opens, never
  fades, never becomes transparent"`); proibir a categoria inteira do
  artefato (`"absolutely no fire, no flame, no glow, no light emission,
  nothing grows out of it"`); proibir pixel novo fora do contorno
  (`"nothing whatsoever may appear outside the mask outline"`); travar cor
  item a item (`"the fire orb stays orange and never turns blue or cyan"`);
  e travar FORMA deixando só o brilho variar, quando a raridade pede quase
  nada (`"keeps exactly the same shape size and outline in every frame, the
  ONLY change is that glow dimming and brightening"`).
- **Regerar arte estática abre uma janela de suite VERMELHA** (Set/2026):
  apagar `assets/sprites/icons/<id>.png` pra regerar faz a trava de arte do
  `tools/validate_cards.lua` acusar "atlas entry with unresolvable icon" —
  corretamente. Se outro agente rodar `test_all` nessa janela, vê vermelho
  que não é dele. Avisar o time antes de mexer em `icons/` ou `icons_anim/`,
  e NÃO rodar `test_all` com a fábrica escrevendo (leitura parcial de
  diretório = falso vermelho).
- **ROSTOS: travar a boca SEMPRE** (feedback do dono, Jul/2026): em busto/
  face, o v3 mexe a boca e o personagem "parece que tá falando"
  (joker_vampire v1 reprovado). Prompt de rosto precisa de "mouth lips and
  jaw completely frozen shut, face expression unchanged, no talking" — o
  que vive num rosto são OLHOS (glow/glint) e acessórios (capa, guizos).
  **Refinamento (2º veto do dono, mesmo com arte de boca fechada): usar
  WHITELIST, não blacklist** — "the ONLY two moving things are: <olhos> and
  <vestimenta>", com cabeça/rosto/boca declarados "frozen statue" antes.
  Proibir itens um a um deixa brecha; enumerar os únicos móveis fecha.
- **O oposto também acontece — v3 anima a AÇÃO da arte** (lição Jul/2026):
  mão aberta virou punho fechando (mage_zap v1), ladino em pose de esquiva
  virou dança (rogue_defend v1 E v2). Arte com gesto implícito PRECISA de
  congelamento explícito no prompt ("completely frozen like a statue, no
  limb/finger movement whatsoever, only <elemento> moving") — e mesmo assim
  pode não obedecer. **Solução DEFINITIVA (validada 8× em Jul/2026, ordem
  do dono "toda carta precisa de animação"): REGERAR A ARTE em pose neutra
  (boca fechada, pés plantados, gesto resolvido) e animar com whitelist.**
  Funcionou para vampiro, abyss (ídolo que abre os olhos), consume, defend,
  rage, war_cry, acrobatics, torn_pages, thorn_cloak. SEMPRE aprovar/
  reprovar pelo contact sheet; reprovar silhueta mudando em basic/common,
  loop que "apaga" (brilho caindo até escuro = pop no reinício) e cores
  alucinadas fora da paleta (axe v1 azul-gelo).
- **fps**: meta.lua por animação (`return { fps = 8 }`). 8fps num loop de
  9 frames ≈ 1.1s — vivo sem ser frenético. Cadências menores p/ pulsos.
- **Ícones compartilhados** (ex: skull_crowned em várias cartas): animar o
  ícone anima TODAS as cartas que o usam — escolher cartas com ícone único.
- Candidatas seguintes (raras com object_id no jobs file): mage_arcane_torrent
  (torrente), mage_overcharge (arcos de energia), warrior_bastion (barreiras),
  rogue_venom_coating (veneno gotejando).

## Performance (v10.6, Jul/2026 — "engasgada ao abrir a Coleção")

Com 116/116 cartas vivas, o render EAGER (9 PNGs do disco + 9 composições
completas da carta POR carta na instanciação) travava a 1ª abertura da
Coleção por segundos. Corrigido em duas camadas:
- **Anim LAZY**: `CardFrame.render` compõe SÓ o frame 0 (estático — que é
  o idle pela doutrina). O set completo + canvas vivo nasce em
  `getAnimation()`, chamado no 1º hover/inspeção (poucos ms, 1 carta).
  `IconFramesLoader.first(name)` carrega só o frame_000.png.
- **Coleção INCREMENTAL**: `_buildInstances` com orçamento de 6ms/frame
  (1ª leva 12ms no show) — a tela abre instantânea, cartas fluem em ondas
  na ordem do grid. `_applyFilter` re-roda por chunk (grid parcial ok).
- REGRA (até 13/Out/2026): pontos de render usavam `instance.image` e SÓ
  pediam `liveImage()` sob gate de interação. Revogada — ver v11 abaixo.

## Performance (v11, Out/2026 — "carta visível = viva")

Com a regra nova a Coleção pede 15-20 sets de uma vez e o Deck Viewer/mão
mais uns 10-25. Medido (`love . test_one perf_card_anim_units`): decodificar
um PNG de frame 0,32-0,36 ms; compor a carta INTEIRA (texto, moldura) 0,7-0,8
ms; o antigo `liveImage` montava 1 composição completa por chamada SEM teto
global — 20 cartas = 20 composições (14 ms) num quadro. Três mudanças:

1. **Camadas** (`renderLayers`/`composeFrame` no CardFrame): a carta é
   `base (cor + textura) + ícone + chrome (decoração, sombra de recesso,
   moldura, banner, selos, rodapé, gemas de forja)`. O chrome é renderizado
   UMA vez por carta num canvas transparente (pré-multiplicado, composto com
   `("alpha", "premultiplied")`) e cada frame vira `base + frame + chrome`:
   ~0,3 ms (é o `newCanvas`, não os draws). Carta animada já NASCE assim no
   `render` (frame 0 = composição; paridade com o render direto: max 1/255,
   0 px fora de ±2 — travado no teste); o chrome fica em `layerCache` até o
   set montar e expira em 3 s sem uso (a Coleção instancia 131 cartas, só as
   visíveis montam o set).
2. **Orçamento GLOBAL por quadro**: 1 unidade = 1 PNG decodificado ou 1
   frame composto; o quadro para em `BUILD_PER_FRAME` (8) unidades OU
   `BUILD_BUDGET_MS` (2,5 ms) — a contagem é o que mantém o teste
   determinístico sob relógio simulado (spent = 0), o tempo é o que protege
   uma máquina lenta. Reposto em `CardFrame.update()` (e por janela de 1/30 s
   pra quem roda sem o update). As cartas ganham vida em ondas, na ordem em
   que foram pedidas; até lá desenham o frame 0.
3. **Sem canvas vivo nem blit**: `liveImage` devolve direto
   `canvases[frameIndex(t)]`; `update()` só repõe o orçamento e faz a higiene
   (teto macio 64 sets; só expulsa quem não foi pedido há 0,35 s). `cacheKey`
   memoizada por instância (tabela fraca) — era uma string nova por carta
   por quadro.

Números (`perf_collection`, 1024×768, 15 cartas animadas visíveis):

| cena | antes (hover-only) | depois (sempre viva) |
|---|---|---|
| aquecimento da grade | — | 15 sets em 36 quadros (0,6 s), pior quadro 3,97 ms |
| idle cpu avg / p95 | 0,34 / 0,43 ms | 0,31 / 0,40 ms |
| hover cpu avg / p95 | 0,87 / 1,38 ms | 0,39 / 0,50 ms |
| scroll cpu avg / p95 / max | 0,71 / 1,35 / 2,3 ms | 1,26 / 2,83 / 3,3 ms |

`test_perf_budget` (WorldRoad) inalterado: 427 draw calls, 30,3 KB/quadro.
O scroll paga as composições das fileiras que entram (limitadas a 2,5 ms);
instanciar uma carta animada ficou ~0,4 ms mais caro (2 canvases em vez de
1) — a abertura da Coleção já é incremental (6 ms/quadro) e absorve.

## O que salvou as 3 reprovadas na TERCEIRA tentativa (Set/2026)

`warrior_eternal_bulwark`, `mage_primordial_storm` e `mage_radiant_prayer`
falharam duas vezes seguidas com descrições cada vez mais específicas
("never fades", "stays orange", "same golden color"). Insistir no adjetivo
proibitivo não resolveu. O que resolveu foram duas mudanças de MÉTODO:

1. **Ciclo curto** — `frame_count` 4 em vez de 8. O v3 vai DERIVANDO cor e
   forma ao longo do ciclo; metade do caminho é metade da chance de derivar.
   O `frame_count` agora é por entrada (`spec.frames`).
2. **Movimento POSITIVO e mínimo**, em vez de whitelist cercada de proibições.
   *"a small orange brazier flame at each side flickers gently, and nothing
   else in the image changes at all"* funcionou onde "the doors never open,
   never fade, never become transparent" falhou duas vezes. É a mesma redação
   que fez os vouchers saírem certos de primeira.

### ⚠️ ARMADILHA DO PIPELINE: o pre-check ressuscitava a reprovada

Ao reprovar uma animação, o fluxo natural é apagar a pasta e reescrever o
prompt. Mas `run()` tinha um atalho que, ao achar um job salvo daquele ícone,
baixava os frames dele em vez de gerar — então voltavam **exatamente os frames
recusados**, com o prompt novo no arquivo e o resultado velho no disco. Parece
ter funcionado, que é pior que falhar.

Corrigido: o job guarda `anim_hash` (md5 da descrição + SUFFIX). Se o prompt
mudou, regenera e imprime *"descricao MUDOU desde o job salvo"*. Ver
[[defect_doctrine]] §6 — cache que não confere a entrada é armadilha.

### Medir a EMENDA, não só os frames

`check` de md5 diz que os frames são distintos; não diz que o ÚLTIMO casa com o
PRIMEIRO. Critério: diferença média 0→N não pode passar de ~1,6x a de um passo
normal (0→1). Acima disso, **ping-pong** (duplicar os frames de volta) mata a
emenda por construção — usado em `mage_radiant_prayer` e em dois vouchers.
Para chama e líquido corrente prefira regerar: fogo em marcha a ré se percebe.

## Quando o v3 NÃO serve: as gemas do mago (Set/2026)

Pedido do dono, jogando: *"as orbes ali, as gemas do mago: se a gente conseguir
colocar animações bem sutis ali na arte delas, bem sutíssimas, só para não ser
tipo um PNG estático igual está hoje"*.

O caminho deste arquivo foi tentado **primeiro**, nas cinco gemas
(`assets/sprites/orbs/*.png`, 48×48), com a redação que esta memória registra
como vencedora: ciclo curto (`frame_count=4`) e movimento positivo mínimo
("the ONLY change is that inner glow dimming and brightening"). **As cinco
foram reprovadas no contact sheet** — raio bombeando de âmbar a amarelo claro,
gelo virando mancha branca, fogo desbotando pra pêssego, sombra fervendo com um
buraco preto no meio do ciclo, e o sagrado com os RAIOS ENCOLHENDO. Frames em
`tools/preview_out/_quarentena_anim/orbs_pixellab_v3_reprovada/`.

**A lição nova não é sobre redação, é sobre ADEQUAÇÃO**: o v3 redesenha o
sprite inteiro a cada frame. Isso é aceitável quando o sujeito tem uma parte
móvel óbvia (pano, chama, fumaça) e o resto é fundo. Numa **pedra facetada de
48px**, onde o "resto" é justamente a identidade (paleta do elemento + contorno
+ o corte que diferencia as cinco), ele não tem onde errar pouco.

O que funcionou foi **trocar o método, não o prompt**: `tools/bake_orb_anim.lua`
não gera frame, ele DERIVA — cada pixel só pode subir **um degrau na rampa de
cor do próprio sprite**, e só dentro de uma faixa diagonal de luz que atravessa
a pedra. Isso torna impossível, por construção, inventar cor, mexer na silhueta
ou tocar o contorno; a emenda do loop é ZERO porque a faixa nasce e morre fora
da pedra (frame 0 e último frame são o PNG estático, pixel a pixel).

**Regra prática**: arte cuja IDENTIDADE é a paleta e o contorno (gema, ícone de
status, moeda, selo) pede animação derivada; arte com um sujeito e um elemento
móvel (personagem, estandarte, tocha) pede v3. Travas em
[`tools/test_orb_anim.lua`](../tools/test_orb_anim.lua) — silhueta, contorno,
paleta, emenda e um TETO de dosagem (35% dos pixels opacos no pior frame),
que é o que impede alguém re-assar com faixa larga e transformar cintilar em
piscar. Aprovação visual: `love . orb_anim_compare` e
`love . preview_battle_hud orbs anim`.
