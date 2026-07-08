---
name: bg_candidates_fields
description: Candidatos de background pixel art pro bioma 1 (fields/Campos Arruinados) — 4 opções PixelLab 400x128, aguardando escolha do usuário
type: project
---

# Backgrounds candidatos — bioma 1 (fields)

Gerados via PixelLab map_object (400×128, o canvas volta 400×400 com o
conteúdo na faixa do topo — bbox exato = 0,0,400,128). Mood grimório-quente
coerente com as cartas ([[art_direction]]). Ficam em
`assets/sprites/world/_bg_candidates/fields/`.

Bg atual do fields: serra nevada + céu pêssego (`fields_mountains.png`).

## Opções
1. **opt1_snowpeaks** — serra nevada, céu sépia-amanhecer com nuvens âmbar,
   treeline escura na base. Mais próximo do atual, porém mais quente/rico.
2. **opt2_ruinhills** — colinas de fazenda arruinada, torres de vigia
   quebradas no horizonte, campo sépia-verde, céu de crepúsculo roxo.
   Mais NARRATIVO (combina com "Campos Arruinados") e com primeiro plano
   de trigo.
3. **opt3_mistforest** — cristas de floresta em camadas sumindo na névoa,
   verde-sépia atmosférico. Mais minimalista/etéreo.
4. **opt4_autumnkeep** — colinas douradas de outono, ruína de castelo
   distante, folhagem âmbar/ferrugem, céu de twilight quente. O mais
   "grimório/dark-fantasy quente" e dramático.

## v2 (feedback: v1 rejeitada — "cores/elementos precisam bater com o mundo")
v1 usava paletas estrangeiras (roxo vulcânico, âmbar, teal) → descartada.
**Paleta travada** amostrada dos assets do mundo (em `_bg_candidates/fields_v2/`):
- verdes: pinho `#0c300c`, musgo `#306c30`, grama `#3c6c18`, oliva
- marrom: casca `#543c30`, escuro `#301818`, ferrugem `#9c3c18`, estrada `#403010`
- montanha fria (contraste): `#506080`/`#90a0b0`, neve `#d0d0c0`
- céu: pêssego `#fcd8b4` → azul-cinza empoeirado
Prompt PixelLab COMPLETO (paleta hex explícita + composição + mood + técnico).
- **v2a_mountainpine** — serra azul-fria nevada + treeline de pinho. Clean,
  clássico, coeso. Mais perto do atual porém mais rico.
- **v2b_farmhills** — colinas de fazenda verdes recuando pra montanha azul
  em névoa + torres quebradas distantes + treeline. Muita profundidade
  verde, casa perfeito com árvores/grama. Tema "Campos Arruinados".
- **v2c_mistridges** — cristas de floresta em camadas + montanha azul + sol
  no horizonte. Recuo atmosférico bonito, verde coeso.
- **v2d_highland** — campina verde com pedras/matacões + pinheiral + pico
  azul. Mais lush/saturado; pedras dão interesse.
Ver ao vivo: `love . demo_worldroad bg` (1-4 troca, T hora). Aguardando escolha.

## Próximo passo (após escolha)
Aplicar pipeline ([[art_direction]]):
- instalar como `fields_mountains.png` (crop 400×128),
- derivar `fields_mountains_front.png` (céu → transparente, só silhueta),
- (opcional) `fields_vista.png` mais alto,
- validar `screenshot_worldroad full1` (tiling + espelho + nuvem atrás).
