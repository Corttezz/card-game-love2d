---
name: art_direction
description: Direção de arte — estilo das cartas (grimório pintado) vs mundo pixel, e o pipeline de background por bioma (mountains + mountains_front + vista) que arte nova precisa respeitar
type: reference
---

# Direção de arte do projeto (Jul/2026)

## Estilo das CARTAS (assets/cards/*.png — referência-mãe)
NÃO é pixel art — é **ilustração pintada estilo grimório dark-fantasy**:
- Pergaminho envelhecido (sépia/creme) de fundo.
- Ilustração central dramática, semi-realista pintada (espada com sangue
  escorrendo, rocha com raios, bárbaro gritando, escudo ornado, poções).
- Moldura ornamental escura + banner dourado com o nome + selos de aço
  nos cantos + rodapé com tipo/stats.
- Paleta QUENTE: sépia, âmbar, ferrugem, aço frio, sangue, dourado
  envelhecido. Contraste dramático, iluminação de vela.
- Alta-res (~744×1035). O jogo REINTERPRETA isso em pixel (CardFrame +
  ilustrações 64×64) — ver [[pixel_art_system]] / seção 14 do CLAUDE.md.

**Mood-alvo pra QUALQUER arte nova**: dark-fantasy de grimório, quente,
dramática, envelhecida — nunca cartoon limpo/brilhante.

## Mundo (WorldRoad) — pixel art
Panorama de montanha + castelo + domo rolante, pixel art chunky com
gradiente de céu por bioma. As luminárias/monstros/props seguem o
contrato PixelLab ([[sprite_design_queue]]).

## Pipeline de BACKGROUND por bioma (o que arte nova PRECISA respeitar)
Assets em `assets/sprites/world/`:
- **`<bid>_mountains.png`** — panorama COMPLETO com **céu assado** no PNG
  (ex. fields 400×104). No draw: escala COVER preenchendo o céu, **tileado
  na horizontal** (`drawStripTiles`) e **espelhado abaixo** da última linha
  de arte (`drawStripMirrorBelow`) → é a "réplica lateral e inferior".
  `mountainsSkyColor` amostra a 1ª linha pra cor de céu do blend/gradiente.
- **`<bid>_mountains_front.png`** — o MESMO panorama, mas com o **céu
  TRANSPARENTE** (só a silhueta da serra). Redesenhado POR CIMA das nuvens
  → nuvem passa ATRÁS dos picos e na frente do céu. É o "corte das
  montanhas pras nuvens passarem por trás". Sem esse PNG, o bioma não tem
  oclusão de nuvem (ex. marsh).
- **`<bid>_vista.png`** — versão mais alta (400×112) pra aproximação do
  marco (castelo revelado).
- **`<bid>_castle.png`** — o castelo/marco do bioma (218×197).

### Processo pra CADA background novo
1. Gerar o panorama pixel (céu + serra) coerente com o mood do bioma.
2. Salvar como `<bid>_mountains.png`.
3. Derivar `<bid>_mountains_front.png`: apagar o céu (tudo acima da linha
   da crista → alpha 0), mantendo só a silhueta da montanha.
4. (Opcional) `<bid>_vista.png` mais alto.
5. Validar em cena: `screenshot_worldroad full<N>` — checar tiling
   horizontal sem emenda, espelho inferior, e nuvens passando atrás.

## Cores-assinatura por bioma (biomes.lua — guiar o céu do background)
- fields (1): sépia esverdeado, manhã→crepúsculo roxo. skyHorizon quente.
- highlands (2): azul-violeta frio, noite de lua.
- abyss (3): vermelho-âmbar infernal, sol baixo.
- frost (4): aço gelado, dia frio.
- marsh (5): verde-veneno turvo, lua.
- dusk (6): âmbar dourado, sol grande no horizonte.

## Plano (a pedido do usuário, Jul/2026)
Um bioma por vez: analisar bg atual → gerar 4-5 opções pixel novas
(mood grimório + coerente com o mundo) → documentar aqui → usuário
escolhe → aplicar pipeline (mountains + front + vista) → validar.
Começando pelo bioma 1 (fields).
