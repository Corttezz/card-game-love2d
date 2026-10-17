# Integração dos landmarks ao terreno do WorldRoad

Data: 17/Out/2026. Pedido do dono: os assets são bons, mas parecem colocados no terreno em vez de pertencerem ao mesmo mundo. Seis passes, na ordem dele: sombra de contato, oclusão por vegetação, luz ambiente compartilhada, perspectiva atmosférica em camadas, interação com o terreno, quebra da repetição das árvores. Decisões do dono: tudo, na ordem do texto; ato 1 calibrado primeiro e depois os outros cinco biomas, cada passe com tabela por bioma desde o início; o céu continua a pintura fixa, só a luz na cena muda; toda preocupação com corpo próprio vira engine em `engine/`.

## 1. Diagnóstico (levantamento de 17/Out)

- O landmark escolhido na encruzilhada é desenhado por `drawLandmarkFront` depois de toda a grama e fora do balanço da cena. Nada do campo pode ficar na frente da base dele.
- Quatro regras de luz convivem: chão e estrada recebem o ambiente puro; árvores e arbustos recebem `ambient × lift` (até 1,8); landmarks recebem só o matiz (`flatColor = 1 - 0,35·(1 - amb/max)`), quase sem escurecer à noite; castelo, montanhas e inimigo são desenhados sem tom.
- Não há sombra de contato, nem clareira ou tufo na base de prop, nem névoa por profundidade. O que existe é 16% de cor de névoa fixa (`LMG.setTint`, props) e escurecimento pela distância (`aFade`).
- Árvores: 3 variantes por PNG, `big` em 45% da faixa externa, companheiras a 0,5 a 0,63, sem espelho, sem tom por instância; vento no CPU com rotação de 0,018 rad e cisalhamento por rajada; companheiras não se mexem.
- Limites: 198 de 200 locais no `WorldRoad.lua`; orçamento de 600 draw calls, 40 KB por quadro e zero decode de PNG no primeiro quadro após troca de bioma (`test_perf_budget`); medidos 418 a 475 draw calls e 26 a 31 KB.

## 2. Arquitetura

Nenhuma regra visual nova dentro do `WorldRoad.lua`: ele só chama. Tudo que for novo entra agrupado em tabelas ou em `require`.

### 2.1 `src/data/scene_integration.lua` (dados, sem lógica)

Uma entrada por bioma (`fields`, `highlands`, `abyss`, `frost`, `marsh`, `dusk`), todas presentes desde o primeiro commit. Campos:

```
grade = {
  day   = { r,g,b },   -- temperatura da luz com time of day 0
  dusk  = { r,g,b },   -- time of day 1 (o jogo real vai de 0,62 a 1)
  shadowTint = { r,g,b }, -- cor que as sombras puxam (roxo no pôr do sol dos campos)
  satNear = 1.0, satFar = 0.55,     -- saturação por profundidade
  contrastFar = 0.6,                -- contraste na profundidade 0 (horizonte)
  fog = { r,g,b }, fogNear = 0.0, fogFar = 0.45, fogCurve = 1.6,
}
contact = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true }
occlusion = { baseCover = 0.10, tuftsMin = 3, tuftsMax = 6, tuftScale = { 0.8, 1.2 } }
lowFog = { alpha = 0.18, height = 0.09, drift = 0.02 }  -- névoa baixa na base das montanhas
trees = { tint = 0.05, scale = 0.08, flip = true, windPhase = true,
          canopySway = 0.030, trunkSway = 0.010, bushSway = 0.040 }
landmarks = {
  rest   = { scorch = { radius = 1.35, alpha = 0.5 }, embers = true, smoke = "thin", pulse = 0.18 },
  battle = { flagWave = true, dust = { rate = 0.4, alpha = 0.10 } },
  shop   = { windowGlow = { alpha = 0.22, spread = 1.4 }, smoke = "chimney" },
  event  = { lanternGlow = true },
  elite  = { runeFlicker = true },
  castle = { lowFog = true, hillShadow = true },
}
```

Os números acima são o ponto de partida do ato 1 (`fields`); os outros cinco biomas nascem com valores derivados da paleta de cada um (`src/data/biomes.lua`: `lightDay`, `lightNight`, cor de névoa) e são calibrados por captura depois.

### 2.2 `engine/SceneGrade.lua` (fonte única de cor)

API:

- `SceneGrade.begin(biome, timeOfDay, blendTo, blendK, weatherMod)`: uma vez por quadro; resolve a linha da tabela, a mistura entre biomas e a modulação do clima (`WeatherEngine.modulateAmbient`).
- `SceneGrade.color(family, t, out)`: cor para `setColor` de um sprite da família (`ground`, `road`, `grass`, `prop`, `tree`, `rock`, `landmark`, `castle`, `mountain`, `enemy`, `luminaire`, `critter`) na profundidade `t` (0 horizonte, 1 base da tela). Aplica temperatura da luz, dessaturação e contraste por profundidade e mistura com a cor da névoa pela curva. Escreve em `out` (tabela reutilizada; zero alocação por quadro).
- `SceneGrade.flatColor(family, out)`: cor base para o oclusor do `LightEngine`. Uma regra só para todas as famílias: ambiente puro. O `lift` das árvores e o "só matiz" dos landmarks saem; o que escurece demais à noite é resolvido pela luz das luminárias e dos próprios landmarks (que já existe), não por exceção de família.
- `SceneGrade.fogAlpha(t)`: alpha da névoa de profundidade para quem desenha véu (WeatherEngine).

Quem chama: `drawDome`, `drawRoad`, `drawGrass` (ctx), `drawList` (props, árvores, pedras, luminárias, companheiras), `drawForkPhysical` e o novo caminho do landmark escolhido, `drawCastleOf`, a pintura das montanhas (frente e fundo), `drawPropsBehind`, o inimigo em viagem e em batalha, os bichos. Nenhum `setColor` com cor de sprite direto nesses pontos.

### 2.3 `engine/ContactShadow.lua`

- `ContactShadow.queue(opts)`: `x, y` do ponto de contato na tela, `w` da pegada, `t` de profundidade, `profile` (pegada medida: lista de colunas que tocam o chão, como em `src/data/shop_footprints.lua`), `alpha`, `scorch` opcional.
- Desenha: (1) faixa escura curta colada na base, altura `contact.height` da largura, dither Bayer na borda, escurece com a cor `shadowTint`; (2) se `scorch`, um disco irregular de chão marcado (terra queimada/poeira) com raio relativo e dither, desenhado ANTES da grama da fatia para a grama escurecida ficar por cima.
- `ContactShadow.flush()`: chamado pelo WorldRoad no mesmo ponto em que o `ShadowEngine` descarrega, para as duas sombras escurecerem a grama já desenhada.
- Pegadas: reaproveita o scan de conteúdo (`LuminaireEngine.contentScan`) para derivar as colunas que tocam o chão de cada PNG de landmark e prop; cache por sprite; medição só uma vez, no prewarm.

### 2.4 `engine/PropVariation.lua`

- `PropVariation.of(seed, kind, biomeTable)`: devolve (em tabela reutilizável) `tint`, `scale`, `flip`, `windPhase`, `canopy`, `trunk`. Determinístico pela semente do prop (que já existe na população), então não muda entre quadros nem entre capturas.
- O vento passa a ter duas amplitudes: copa (rotação maior, no topo) e tronco (quase parado). Como o sprite é um PNG só, a copa é desenhada com cisalhamento (`shear`) crescente com a altura e o tronco com a rotação pequena; arbustos usam a amplitude própria. Companheiras passam a se mexer com fase própria.
- Sem `reducedMotion` o vento continua como hoje em amplitude mínima; com `reducedMotion` o movimento some, a variação de tom/escala/espelho fica (remove MOVIMENTO, nunca INFORMAÇÃO).

### 2.5 `GrassField`: oclusão pela base

- `GrassField.requireTufts(rel, x, w, n, scale)`: registra, para a fatia logo à frente de `rel`, tufos obrigatórios distribuídos ao longo da base de um prop, cobrindo `occlusion.baseCover` da altura da base. Entram no lote da fatia, no mesmo shader de vento.
- `drawList` chama isso para cada landmark, cabana, castelo (na colina), pedra grande e tronco. Árvores já afundam pelo `PropCut`; ganham 1 a 2 tufos também.
- O landmark escolhido (`drawLandmarkFront`) deixa de existir como passe separado: vira um pseudo-prop em `drawList` com o `rel` da marca da encruzilhada, desenhado entre as fatias de grama como qualquer prop e dentro do balanço da cena. O mesmo vale para `drawEncounterFront` se for só o inimigo de batalha (já há o caminho intercalado em `nearPass`).

### 2.6 `WeatherEngine`: névoa em camadas

- Camada baixa: faixa de névoa com ruído lento na base das montanhas (acima do horizonte, entre o fundo e a frente das montanhas), alpha e altura da tabela `lowFog`; desenhada antes do castelo para o castelo distante também receber um pouco.
- Névoa de profundidade: o `drawHaze` passa a usar `SceneGrade.fogAlpha(t)` nas fatias (via `flushTo`), somando ao véu do `fogHook` (o estado de névoa de intenção continua mandando, nunca o contrário).
- A mistura de cor por profundidade está no `SceneGrade.color`; aqui é só o véu desenhado.

### 2.7 Interação de cada landmark com o terreno

Tudo lido de `landmarks` na tabela. Mecanismos:

- **Fogueira (rest):** terra queimada pelo `ContactShadow.scorch`; brasas pelo `LuminaireEngine.drawEmbers` (campo `embers`, já existe para braseiros); fumaça fina pelo mesmo sistema da chaminé da loja (`drawLandmarkSmoke`), com preset `thin`; pulso da poça de luz (`submitLandmarkLight` com `pulse`), que já faz o chão brilhar.
- **Bandeira (battle):** a bandeira ganha fase de vento por `PropVariation` (cisalhamento no pano, haste parada); poeira leve na estrada perto dela: partículas raras no `WeatherEngine` restritas à faixa da estrada.
- **Loja (shop):** brilho das janelas no chão: uma luz rasa e alongada no `LightEngine` abaixo da base, cor quente, alpha baixo; a fumaça da chaminé continua.
- **Castelo:** névoa baixa própria quando cresce (progress > 0,55, onde a fumaça já nasce) e sombra projetada no topo da colina pelo `ShadowEngine` com a direção do sol, substituindo as duas elipses fixas de hoje.
- **Evento e elite:** brilho já existe; passam pelo `SceneGrade` e ganham sombra de contato como todo landmark.

## 3. Ordem de trabalho e entrega

Um commit por passe, cada um com `test_all` verde e capturas antes/depois do ato 1 em `tools/preview_out/integracao_terreno/<passe>/` (dia, meio, pôr do sol; encruzilhada aberta, landmark escolhido, viagem, castelo crescendo). Depois do sexto passe, um commit por bioma restante calibrando os valores da tabela com a mesma grade de capturas.

1. `SceneGrade` + tabela, com todas as famílias migradas (é a base dos outros).
2. `ContactShadow` + terra queimada da fogueira.
3. Oclusão pela base na `GrassField` + landmark escolhido de volta ao pintor.
4. Névoa em camadas no `WeatherEngine`.
5. Interação dos landmarks.
6. `PropVariation` nas árvores.
7. Biomas 2 a 6, um commit cada.

## 4. Travas

- `test_scene_grade` (novo): toda família listada em `SceneGrade.FAMILIES` tem chamada no desenho (varredura dos pontos de `setColor` da cena); cor de uma família varia com a profundidade do jeito da tabela; `flatColor` igual para todas; com `reducedMotion` só o movimento some.
- `test_contact_shadow` (novo): para cada landmark e prop com pegada, a linha logo abaixo da base é mais escura que o chão ao lado, sem vão; terra queimada só na fogueira.
- `test_world_props`: landmark escolhido aparece entre fatias de grama (tufo na frente da base), e dentro do balanço.
- `test_perf_budget`: mantém 600 draw calls e 40 KB; meta de ficar abaixo de 520 draw calls e 34 KB com tudo ligado (tufos e sombras de contato entram nos lotes existentes; nada de closure em laço quente).
- `test_world_shadows`, `test_weather`, `test_lumanim`: continuam verdes.
- Contagem de locais do `WorldRoad.lua` não sobe (meta: cair abaixo de 190).

## 5. Fora do escopo

Céu e montanhas acompanhando a hora do dia (decisão do dono), novos assets de prop, mudanças na população e posição dos props, alterações no interior dos chefes.
