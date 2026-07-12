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
- **O oposto também acontece — v3 anima a AÇÃO da arte** (lição Jul/2026):
  mão aberta virou punho fechando (mage_zap v1), ladino em pose de esquiva
  virou dança (rogue_defend v1 E v2). Arte com gesto implícito PRECISA de
  congelamento explícito no prompt ("completely frozen like a statue, no
  limb/finger movement whatsoever, only <elemento> moving") — e mesmo assim
  pode não obedecer. **Arte em pose de AÇÃO (mid-dodge, mid-swing) não é
  animável por v3: após 2 reprovações, deixar ESTÁTICA** (nem toda carta
  precisa de animação — regra do dono). SEMPRE aprovar/reprovar pelo
  contact sheet; reprovar se a silhueta muda entre frames em basic/common.
- **fps**: meta.lua por animação (`return { fps = 8 }`). 8fps num loop de
  9 frames ≈ 1.1s — vivo sem ser frenético. Cadências menores p/ pulsos.
- **Ícones compartilhados** (ex: skull_crowned em várias cartas): animar o
  ícone anima TODAS as cartas que o usam — escolher cartas com ícone único.
- Candidatas seguintes (raras com object_id no jobs file): mage_arcane_torrent
  (torrente), mage_overcharge (arcos de energia), warrior_bastion (barreiras),
  rogue_venom_coating (veneno gotejando).
