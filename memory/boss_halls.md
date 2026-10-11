---
name: boss_halls
description: Salões de chefe (castle_hall_1..6) — arte por ato, InteriorFX v2 (luz nas chamas PINTADAS, névoa, vinheta, clima atrás/na frente do chefe), regras de chão e de composição, como regerar.
type: project
---

# Salões de chefe — o clímax de cada ato

## Estado (Out/2026)
| Ato | Arte | Atmosfera (InteriorFX.HALLS) |
|---|---|---|
| 1 rei-carniça | NOVA (PixelLab pro, estilo do hall 2): vão âmbar atrás do chefe, caveira de corvo acima da cabeça, estandartes, 6 arandelas, ossos | flicker nas 6 chamas, vão respira, poeira no vão |
| 2 lich | original, letras alucinadas dos estandartes APAGADAS (edit_image, colado só nas faixas laterais) | flicker nos 4 candelabros, luar respira, poeira roxa |
| 3 tirano | NOVA: portão-caveira com cascata de lava atrás do corpo, correntes com crânios, braseiros. 18 linhas (176-193) removidas + rodapé espelhado pra o chão começar em ~0.71 | lava respira, braseiros, cinza caindo |
| 4 monarca | original (simétrica, eixo 200.5) | braseiros azuis, NEVE |
| 5 colosso | original deslocada 5px (eixo estava em 206) + CORAÇÃO de raízes no fundo do túnel (edit_image, colado só no túnel) | coração BATE (pulso duplo), esporos/vaga-lumes, névoa verde |
| 6 rainha | original + ECLIPSE pintado em pixel na grade da arte (disco duro r=12 em (200,58), coroa carmim em faixas pontilhadas Bayer, 8 raios de 1px) — o do inpaint tinha gradiente liso e lia como vetor | feixe respira, poeira só no feixe |

## Regras
- **Nada de disco de luz.** A luz da chama é a própria pintura: máscara
  EMISSIVA (pixels claros dos retângulos `flames`/`pulses`, alpha pela luma)
  desenhada em aditivo com flicker. Redesenhar o retângulo cru clareia o fundo
  e vira caixa.
- **Tudo em coordenadas da ARTE** (px da PNG 400×256) pelo cover-fit do
  SceneBackground. A v1 usava fração da TELA calibrada em 4:3 — em 16:9 os
  discos caíam ao lado das chamas (era isso o "não alinhado" do hall 4).
- **Salão = `InteriorFX.hallFor(ato)`**, fonte única de draw e update (a v1
  tickava com `min(3, ato)` → brasas da lava do hall 3 nos atos 4-6).
- **Profundidade:** `InteriorFX.draw` logo após o fundo (névoa no chão,
  vinheta, partículas de trás — atrás do chefe); `InteriorFX.drawFront`
  depois do `EnemyRenderer.draw` (neve/cinza/esporos próximos), recortado
  abaixo da TopBar (`drawFront(hall, topBarHeight)` — a barra já foi desenhada).
- Partícula = 1 pixel da arte (posição truncada na grade da PNG).
- Troca de salão pré-aquece o clima (25s simulados) — a sala nunca abre vazia.

## Chão × mão (o que decide se uma arte serve)
Em 16:9 (escala 4.8, corte de ~15px da arte em cima e embaixo) o teto da mão
segura o pé do chefe por volta da linha **0.72-0.75 da PNG**. Arte cujo chão
começa abaixo disso põe o chefe flutuando no que estiver pintado ali (o hall 3
gerado tinha o chão em 0.78 → tirano dentro da cascata). Ao regerar: chão
começando em ≤0.71; elemento de identidade ACIMA da cabeça (y < ~0.35) e
fundo claro atrás de chefe escuro (ver known_gaps, hall 3). Conferir SEMPRE
nos dois aspectos: `BOSS_ROOMS_SIZE=1920x1080 love . boss_rooms shots`.

## Como regerar
`create_image_pro` 400×256 `no_background=false` com `style_image` = um hall
existente (`style_copy` sem `color_palette` pra trocar a paleta). O style image
domina a COMPOSIÇÃO — duas seeds com o prompt mudado deram a mesma cena;
mudança de enquadramento se faz na arte (remover linhas de faixa vertical).
Inpaint acima de 256px exige Tier 2: recortar ≤256², inpaintar, colar.
Cliente MCP que lê base64 do disco: ver [[pixellab-base64-mcp-http]].
Depois de trocar a arte: remedir `flames`/`pulses` (cluster de luma) e
`scene_anchors` (yr/backYr); `love . test_one test_interior_fx` confere que
toda chama pousa em fogo pintado.
