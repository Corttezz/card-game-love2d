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

**GATING POR INTERAÇÃO (regra do dono, Jul/2026 v2 — substitui o "anima em
tudo sempre"):** `instance.image` é o canvas ESTÁTICO (frame 0);
`CardFrame.liveImage(card)` devolve o canvas vivo. A animação SÓ aparece:
- mão/loja/rewards/jokers ativos: hover OU carta selecionada pra jogar
  (`Card:draw` faz o swap sozinho via `self.isHovered or self.isSelected`;
  GameplayScene seta `card.isSelected` por frame);
- coleção: hover no grid (drawCardMini) + modal de inspeção (sempre);
- seleção de classe: hover no painel da classe (`hover > 0.35`);
- deck viewer: carta hovered.
Idle em qualquer tela = estático. Padrão de código: swap TEMPORÁRIO de
`instance.image` durante o draw, restaurar no fim (nunca deixar o live
vazar pro estado).

Por que não overlay por cima do canvas: ficava FORA do mesh warp 3D do
hover (ícone "flutuando" reto sobre carta entortada), fora do HoloShader/
editions, e cobria o recess shadow do art slot. Com o frame dentro da
imagem, warp + holo + editions + CRT pegam a animação de graça.
Custo: 9 canvases 96×144 + 1 blit ~8×/s por carta animada — desprezível.

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
- REGRA: pontos de render usam `instance.image` (estático) e SÓ pedem
  `liveImage()` sob gate de interação (hover/seleção/inspeção) — é isso
  que faz o lazy disparar na hora certa. Validado: test_all 22/22.
