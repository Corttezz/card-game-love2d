# Entradas por inimigo (comuns, elites e mini-chefes)

Data: 22/Out/2026. Pedido do dono: "hoje o inimigo só vem de trás, parado, estático e para na tela. Faz sentido eles entrarem de forma diferente: alguns surgem do chão, outros vêm voando, outros vêm de trás de uma forma diferente. Cada bicho pode ser diferente, não tem que ter regra exata. Mesmo intervalo de hoje; se fizer sentido, 2 ou 3 segundos a mais não tem problema. Nenhum problema de continuidade: a gente continua andando para frente, depois chega o bichinho e para. Se o cenário reagir e ficar legal, pode."

## Intenção

Cada uma das 36 criaturas não-chefe ganha uma entrada própria, que vira a marca dela. O jogador reconhece o bicho pela chegada. Os 6 chefes já têm cinemática e ficam fora.

## Como funciona hoje (medido no código)

- Clique no ramo: a câmera converge 2,4 s. Escolhido o nó de luta, começa `WorldRoad.travel` (20 unidades, 6,5 s, easeInOutCubic).
- Durante a viagem o inimigo é um "billboard" do clipe `idle` na estrada (`WorldRoad._encounter`), preso ao ponto `camZ + 20 + BATTLE_REL`, então ele PARA exatamente no palco da batalha. Emerge por trás da crista (`drawEncounterBehind`), depois é desenhado na profundidade certa entre os props (`LMG.drawEncounterFront`), com a mesma sombra do idle (`idleShadow`).
- No fim da viagem o clipe é entregue ao `EnemyRenderer` (`_handoff`: mesmo quadro, mesmo tempo), que toca a quicada de 0,55 s (`triggerArrival`); só então a cortina da mão sobe e as cartas são dadas (0,11 s por carta + 0,30 s).
- O jogador só age depois de viagem + quicada + mão dada (`GameplayScene.isQuiet`, `HandDeal.isBusy`).
- `test_scene_continuity` traça corpo e sombra do inimigo durante viagem e chegada e falha em salto de posição (> 6 px), sombra que muda (> 12 %) ou sombra que aparece/some na chegada.
- Clipes existentes por inimigo: `idle`, `attack`, `attack_strong`, `hurt`, `death`. Nenhum comum/elite/mini-chefe tem clipe de entrada. Clipes novos entram só por pasta `animations/<clipe>/south/N.png`, sem registro.

## Regras (não negociáveis)

1. **Continuidade.** A câmera não para antes da chegada. A entrada termina EXATAMENTE no palco (`BATTLE_REL`), no quadro 0 do idle, com a mesma sombra do idle. Nada pula na troca para a batalha. `test_scene_continuity` cobre as 36 entradas.
2. **Tempo.** Base = a viagem de hoje (6,5 s). Cada criatura pode somar até 3 s (`extra`), gastos ou alongando a viagem (a câmera anda mais devagar no fim) ou num "assentamento" depois que a câmera para (o bicho termina de sair do chão, dobra as asas etc.). A mão só é dada quando a entrada acaba.
3. **Âncora sem pop.** Entrada que esconde o bicho até o fim (sai do chão, da água, de uma estátua, de um casulo) usa uma ÂNCORA no palco: um prop do cenário (monte de terra, poça, estátua, pedestal, cogumelo) que NASCE NA CRISTA como todo prop e viaja até o palco. Nada aparece do nada.
4. **Cenário reage** quando faz sentido e fica bom: poeira, terra, grama amassada, respingo, brasas, vento na grama, tremor leve. Tudo pelos motores existentes (Particles/CardFeel burst, ScreenShake, GrassField wind, LightEngine). `reducedMotion`: entrada curta (bicho já chega quase no lugar), sem tremor, sem partícula; informação mantida.
5. **Variação só no detalhe.** O tipo e o clipe são fixos por criatura; só o lado (esquerda/direita) e um pequeno atraso variam, sorteados no stream "misc".
6. **Arte.** Clipes novos gerados no PixelLab a partir do `idle/south/0.png` da criatura (quadro 0 = idle real), ferramenta nomeada e UMA por família (animação de personagem: `animate_image` v3 como `tools/pixellab_enemy_anims.py`; se não servir, `animate_image_pixminimax` ou esqueleto). Tripwires: animação morta, quadro final diferente do idle (o último quadro de todo clipe de entrada TEM de ser o idle 0, ou o clipe termina em pose que o idle continua sem salto). Âncoras/props: `create_image_pro` com o PNG da criatura como referência de estilo.
7. **Galeria.** `lovec . entradas [id]`: abre a cena real do ato da criatura, toca a entrada completa (viagem → chegada → mão), setas trocam de criatura, R repete, mostra nome, tipo, tempo e o clipe usado. `lovec . test_one screenshot_entradas [id]` grava a tira de quadros (12 quadros) de cada criatura em `tools/preview_out/entradas/atoN/<id>.png` e uma folha por ato.

## Tipos de entrada (vocabulário reutilizável)

| Tipo | O que acontece | Âncora | Clipe |
|---|---|---|---|
| `andar` | vem de trás andando com clipe próprio, para com um assentamento | não | `walk` (8q) ou idle |
| `investida` | vem de trás mais rápido que a câmera, derrapa e para; poeira | não | `charge` (8q) |
| `brotar` | âncora no palco; na chegada o bicho irrompe de dentro | sim | `emerge` (8q) |
| `acordar` | âncora é o próprio bicho inerte (estátua/espantalho/pedestal); na chegada ele desperta | sim (o bicho, inerte) | `awaken` (8q) |
| `mergulho` | desce do céu, pousa com vento/poeira | não | `swoop` (8q) + `land` opcional |
| `condensar` | névoa/sombra/enxame no palco se adensa e vira o bicho | sim (névoa/sombra) | `form` (8q) |
| `flanco` | sai da mata de um lado e entra na estrada | não | `walk` ou `trot` (8q) |
| `montar` | peças vêm dos lados e se montam | sim (pedras/ossos) | `assemble` (8q) |

## Roteiro das 36 criaturas

Formato: tipo · o que o jogador vê · cenário · som · tempo extra · clipe novo.

### Ato 1, Campos Arruinados
- **Espantalho Amaldiçoado** (`cursed_scarecrow`): `acordar`. Pendurado numa estaca na beira do palco, inerte, como um espantalho de verdade. Quando a câmera para, treme, arranca-se da estaca e pula para o meio da estrada. Corvos saem voando; palha voa. Som: corda estalando, grasnados. +1,5 s. Clipe `awaken`.
- **Lavrador Oco** (`hollow_farmer`): `andar`. Vem mancando devagar, arrastando o forcado, que risca a terra; para e finca o forcado com um baque. Poeira no baque. Som: arrasto e baque. +0 s. Clipe `walk`.
- **Ratos da Peste** (`plague_rats`): `condensar` em enxame. Ratos escorrem das duas matas, cruzam a estrada e se amontoam no palco virando a pilha. Grama chacoalha dos dois lados. Som: guinchos. +1 s. Clipe `form`.
- **Ceifador da Colheita** (`harvest_reaper`): `condensar`. Uma névoa escura no palco engrossa durante a viagem; na chegada ele se materializa já descendo a foice. Grama se deita para fora; vagalumes somem. Som: lâmina cantando. +1,5 s. Clipe `form`.
- **Touro da Praga** (`blight_bull`): `investida`. Vem trovejando de trás, mais rápido que a câmera, derrapa e para a um passo, bufando. Terra voa, tremor leve. Som: cascos e bufo. +0,5 s. Clipe `charge`.
- **Efígie de Vime** (`wicker_effigy`): `acordar`. Está apagada no palco, uma figura de vime escura. Na chegada acende de dentro para fora com um sopro. Chuva de brasas, poça de luz no chão. Som: fogo tomando. +2 s. Clipe `awaken` (ignição).

### Ato 2, Colinas da Torre
- **Gárgula Lunar** (`moon_gargoyle`): `acordar`. Está empoleirada em pedra na beira do palco, estátua. Pedra racha, olhos acendem, ela cai de pé na estrada. Lascas de pedra. Som: pedra rachando. +1,5 s. Clipe `awaken`.
- **Cultista do Carneiro** (`ram_cultist`): `andar`. Vem de trás entoando; um círculo rúnico no palco (âncora discreta) acende roxo quando ele pisa nele. Som: cântico baixo. +0,5 s. Clipe `walk`.
- **Harpia da Tempestade** (`storm_harpy`): `mergulho`. Um relâmpago, e ela desce em rasante, pousa de asas abertas. Rajada de vento na grama, chuva engrossa. Som: trovão e grito. +1 s. Clipes `swoop`, `land`.
- **Golem Rúnico** (`rune_golem`): `montar`. Pedras rolam dos dois lados para o palco e se empilham até virar o golem; as runas acendem por último. Tremor, pedregulho. Som: pedra batendo. +2 s. Clipe `assemble`.
- **Cavaleiro Espectral** (`spectral_knight`): `condensar`. A luz de uma lanterna se aproxima na névoa; ele vai de translúcido a sólido ao chegar. Névoa baixa se abre. Som: armadura abafada. +1 s. Clipe `form`.
- **Grifo da Tempestade** (`storm_griffin`): `mergulho`. Sombra do grifo cruza a estrada duas vezes antes de ele pousar com um trovão. Rajada forte, tremor. Som: trovão e guincho. +2 s. Clipes `swoop`, `land`.

### Ato 3, Estrada do Abismo
- **Diabrete de Brasa** (`ember_imp`): `brotar`. Uma rachadura incandescente no palco; na chegada o diabrete salta de dentro rindo. Jato de brasas. Som: risada aguda. +1 s. Clipe `emerge`.
- **Cão Infernal** (`hellhound`): `investida`. Vem de trás deixando rastro de fogo, derrapa. Brasas na derrapada. Som: rosnado. +0,5 s. Clipe `charge`.
- **Acólito do Abismo** (`abyss_acolyte`): `andar`. Vem de trás com o livro flutuando, para e ergue o livro; um sigilo acende no chão. Som: sussurros. +0,5 s. Clipe `walk`.
- **Sentinela de Obsidiana** (`obsidian_sentinel`): `acordar`. Está no palco como estátua apagada; os olhos acendem e ela dá um passo pesado à frente. Tremor. Som: pedra e metal. +1,5 s. Clipe `awaken`.
- **Bruto do Fosso** (`pit_brute`): `brotar`. Um fosso no palco (âncora); mãos agarram a borda e ele se iça para fora. Rocha cai, tremor. Som: urro. +2 s. Clipe `emerge`.
- **Vigia do Abismo** (`abyss_watcher`, flutua): `condensar`. Um borrão de escuridão flutua até o palco; os olhos abrem um a um. A luz da cena cai. Som: zumbido grave. +1,5 s. Clipe `form`.

### Ato 4, Geleira Espectral
- **Espectro do Gelo** (`frost_wight`): `condensar`. Forma-se da neve que o vento sopra sobre o palco. Nevasca engrossa. Som: vento. +1 s. Clipe `form`.
- **Lobo da Geada** (`frost_wolf`): `flanco`. Sai da mata de um lado, trota até a estrada e uiva. Neve dos galhos. Som: uivo. +1 s. Clipes `trot`, `howl`.
- **Xamã da Geada** (`rime_shaman`): `andar`. Vem de trás; ao parar, finca o cajado e um espigão de gelo sobe do chão. Som: gelo estalando. +0,5 s. Clipe `walk`.
- **Cavaleiro da Geleira** (`glacier_knight`): `andar` pesado. Cada passo deixa geada no chão e treme a tela de leve. Som: passos de ferro. +1 s. Clipe `walk`.
- **Troll do Gelo** (`frost_troll`): `flanco`. Rompe um monte de neve na beira do palco (âncora) e pisa na estrada. Neve explode, tremor. Som: urro rouco. +1,5 s. Clipe `emerge`.
- **Serpe de Gelo** (`ice_wyrm`): `brotar`. Uma lombada sob a neve avança com a câmera; no palco irrompe num gêiser de neve. Tremor. Som: gelo quebrando. +2 s. Clipe `emerge`.

### Ato 5, Pântano da Podridão
- **Carniçal do Brejo** (`bog_ghoul`): `brotar`. Uma mão sai da lama no palco, depois o corpo. Bolhas e respingo. Som: lama. +1,5 s. Clipe `emerge`.
- **Sapo da Peste** (`plague_toad`): `flanco`. Entra aos saltos de um lado; o último salto cai no palco com respingo. Som: coaxo. +1 s. Clipe `hop`.
- **Horror Sanguessuga** (`leech_horror`): `brotar`. Uma poça no palco ondula; ele jorra de dentro. Respingo. Som: sucção. +1,5 s. Clipe `emerge`.
- **Bruxa do Lodo** (`mire_hag`): `andar`. Primeiro só a luz do lampião na névoa; ela vem de trás e para. Névoa se abre. Som: risinho. +1 s. Clipe `walk`.
- **Guerreiro Crocodilo** (`croc_warrior`): `flanco`. Sai da água na beira da estrada e se arrasta para o palco. Respingo, lama. Som: água e rosnado. +1,5 s. Clipe `crawl`.
- **Mãe dos Esporos** (`spore_mother`): `brotar`. Um aglomerado de cogumelos no palco incha e se abre, revelando-a. Nuvem de esporos. Som: estalo úmido. +2 s. Clipe `emerge`.

### Ato 6, Campos do Crepúsculo
- **Sombra do Crepúsculo** (`dusk_shade`, flutua): `condensar`. Condensa das sombras do chão, tremeluzindo. Som: sopro. +1 s. Clipe `form`.
- **Morcego do Crepúsculo** (`dusk_bat`, flutua): `mergulho` errático. Vem do alto em ziguezague e para batendo asas. Som: asas. +0,5 s. Clipe `swoop`.
- **Servo da Cova** (`grave_thrall`): `brotar`. Garras rompem a terra no palco (âncora: terra revolvida) e ele sai da cova. Terra voa. Som: terra e gemido. +1,5 s. Clipe `emerge`.
- **Duque de Sangue** (`blood_duke`): `condensar`. Um enxame de morcegos converge no palco e se fecha nele com um floreio da capa. Som: asas e risada. +2 s. Clipe `form`.
- **Dullahan** (`dullahan`): `andar`. Vem de trás com a cabeça no braço; a cabeça acende e ri antes de parar. Som: risada. +1 s. Clipe `walk`.
- **Anjo Caído** (`fallen_angel`): `mergulho`. Desce numa coluna de luz do crepúsculo, as asas se dobram ao pousar, penas caem. Luz no chão. Som: coro grave. +2,5 s. Clipes `descend`, `land`.

## Arquitetura

- **Dados**: `src/data/enemy_entrances.lua`: `[id] = { kind, clips = {...}, extra, settle, anchor, fx = {...}, sfx = {...}, side = "random"|"left"|"right", reduced = {...} }`. Sem entrada = `andar` com idle (comportamento de hoje, mas com assentamento).
- **Motor**: `src/ui/EnemyEntrance.lua` (módulo novo; `WorldRoad.lua` está no teto de locais). Recebe o billboard e dirige o visual do `_encounter` durante a viagem e o assentamento: qual clipe tocar, quando, deslocamento/escala extra (voo, flanco), opacidade (só para condensar), âncora a desenhar no palco, FX e sons por marca de tempo. No fim entrega o idle ao `EnemyRenderer` como hoje (`_handoff`), e `triggerArrival` só para entradas que terminam com pouso.
- **Tempo**: `WorldRoad.travel({ duration = 6.5 + extraViagem })` por criatura e `settle` depois da parada; `GameplayScene.isQuiet`/cortina esperam `EnemyEntrance.isActive()`.
- **Âncoras**: props do `world_props` com `kind = "anchor_<x>"`, criados pelo plano da parada (`planStop`) e nascidos na crista, nunca no palco. Removidos na chegada, quando o bicho os substitui (com partícula cobrindo a troca).
- **Clipes**: `SpriteAnimation(id, clip)`; clipe ausente → cai no idle com aviso `Debug.warn` (a entrada ainda funciona, só sem o clipe próprio). O último quadro de cada clipe de entrada deve casar com o idle 0 (tripwire na instalação).
- **Testes**: `test_scene_continuity` ganha o cenário `entradas` (36 criaturas × ato real × 1 semente, mais 3 resoluções para 6 delas): corpo e sombra sem salto no fim, âncora nascida na crista, duração total ≤ 6,5 + 3 s, quadro final = idle 0; `test_enemy_entrances` valida os dados (clipes referenciados existem ou caem no idle, tipos válidos, extra ≤ 3).
- **Galeria e captura**: `tools/entradas.lua` (interativo) e `tools/screenshot_entradas.lua` (tiras por criatura e folha por ato).

## Fora de escopo

Chefes (já têm cinemática). Entradas para o inimigo da primeira luta da corrida, que hoje chega sem encruzilhada: usa a mesma entrada da criatura.
