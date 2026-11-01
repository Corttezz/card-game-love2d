# Revisão: corte 3 (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `corte3.md`, `revisao-grimoire-corte2.md` (5 pontos), `revisao-grimoire-corte1.md` (7 pontos) e os 14 critérios. Por ordem do Grimoire, esta rodada cobre **só a versão Tirano** (`grimoire_zero_corte3_1080p.mp4` de 17:57 e `_720p.mp4` de 17:58); a variante do Rei entra numa rodada própria, quando sair. O que fiz: medidas quadro a quadro (`medir.py` → `...\scratchpad\rev\e3_1080\`); folhas a 2 e 4 quadros/s da virada (43,9–53,1 s), das estradas (25,3–32,7 s) e quadros cheios dos salões, do espólio, do LETAL e do golpe (`...\rev\g3\`); mixagem sobre os stems reais `build\trailer\zero3\zero3_tirano\` (`mixagem.py` → `mix3_tirano.json`: nível por plano de cada stem, subida do grave da música em cada corte e perfil de 100 ms); leitura do `mix_sources.json`. Não ouvi._

## Versão Tirano, rodada 1: NÃO APROVADO

O corte 3 avançou de verdade:
- **Zero quadros pretos.** O pior quadro do salão escuro passou de 5% de luma, e os olhos continuam no escuro.
- **Caminhada:** virou um plano ×2 do portão de 1,48 s.
- **Salões do Higgsfield com o grão do jogo:** reduzidos a 480×270, com paleta do salão real e vizinho mais próximo, agora leem como o mesmo jogo, o de lava e o do trono em chamas (`g3/quad2.png`).
- **"FROST."** saiu do rosto do Monarca.
- **Virada legível:** **HERO 25 → 21 → 17 → 13 → 9** a ×3, um passo por corvo (45,48–48,27 s), e o painel **"LETHAL" a ×3** antes do golpe.
- **Mixagem:** o salão do Monarca agora lidera com a música (+8 dB sobre o efeito, subida de 10,4 dB no corte); o silêncio da entrada é total (−88 a −92 dBFS por 2 s), e a volta no nome do Rei sobe 15 dB num quadro.

Mas o ponto 4 do Grimoire não foi resolvido do jeito que ele pediu, e apareceram dois defeitos novos que não existiam no corte 2.

### Ponto 4 (zoom suave no miolo) contra a solução ×3: REPROVADO
A diretora trocou o zoom suave por **degraus inteiros ×3** e deixou a PERGUNTA ao Grimoire. Avaliei a sequência como ela aparece na tela (`g3/virada.png`):
- **Vai e volta de escala:** ×2 Rei (44,08) → **×3** painel de vida (45,48, canto inferior esquerdo) → **×1** plano geral (48,27, 1,06 s) → **×3** mão (49,33, embaixo) → **×3** painel LETHAL (50,54, canto superior direito) → ×2 golpe (52,83). São cinco cortes de escala e de lugar em 8,7 s, com o ×1 enfiado entre dois ×3. A câmera aproxima, recua e aproxima de novo. Isso é o oposto de "zoom suave" e lê como pulo.
- **O olho atravessa a tela a cada corte:** o centro de interesse salta do canto inferior esquerdo para o centro, depois para baixo e depois para o canto superior direito, sem elemento comum entre os planos. A regra 3 do §7 (objeto em foco na mesma região de um plano para o outro) quebra três vezes seguidas.
- **O ×3 da mão (49,33–50,54 s) corta as cartas:** Bash, Iron Wave e Ghostly Armor saem pelas bordas, e as etiquetas "Volley +6" se sobrepõem. Fica mais confuso que o ×2 do corte 2.
- **O ×3 do LETHAL (50,54–52,83 s)** mostra só a interface sobre uma parede (painel + Play Cards + End Turn), sem o Rei nem a mão: o LETHAL se lê, mas o plano parece captura de menu.
- **Espólio a ×3 (9,60–11,69 s):** Poison Dart e Rain of Blades saem as duas cortadas ao meio, e o texto "145 LIVING CARDS." agora **encosta nos dois selos "NEW"** do jogo (`g3/quad.png`, canto inferior direito). Trocou um encavalamento (com a faixa COMMON) por outro.

**Exigência para o corte 4:** o "zoom no miolo" como **aproximação progressiva, nunca recuo no meio**, mantendo o centro de interesse na mesma região. Ex.: ×2 Rei+painel → ×3 painel de vida (degrau no grave, com o painel na mesma posição relativa do plano anterior) → ×3 LETHAL ao lado da mão, ou a mão e o painel juntos num ×2 → golpe. Tirar o ×1 do meio (ou colocá-lo antes do primeiro ×3). O espólio volta a ×2 com as cartas inteiras (como no corte 2), ou ×3 numa carta inteira só, com o texto numa linha livre. Se o Grimoire quiser zoom com movimento, a única forma limpa com a regra do §5.3 é uma sucessão rápida de degraus inteiros (×1 → ×2 → ×3 em três graves seguidos, mesmo centro), não interpolação.

### Defeitos novos (regressões)
1. **O número do golpe não bate com o LETHAL, e o golpe vem de outra jogada.** O `k_volta` mostra o Rei com **48/220** e o painel diz **48 LETHAL** (+6 ×1,5); o golpe a 52,83 s mostra **"47"** e o banner **"Volley +18"**. A virada é da tomada regravada e o golpe ainda é da tomada antiga (em que o Rei tinha 47 e o combo era Volley +18). Num quadro o espectador lê 48, no seguinte lê 47, com um combo que não foi mostrado. **Exijo** o golpe da mesma tomada da virada, ou, se a morte da tomada nova servir, o número congelado igual ao do painel (48) e o banner do mesmo turno.
2. **O portão abre em silêncio.** No `mix_sources.json` do corte 3 não há mais `castleGateOpen`. O plano ×2 do portão (31,07–32,55 s) só tem grilos e vento, e o stem de SFX nesse trecho está a −∞. O som da porta do castelo audível é o **pedido nº 6 do Daniel**. O motivo é técnico: o evento começa antes do novo início do clipe e o `no_carry` o descarta. **Exijo** o `castleGateOpen` no início do plano do portão (o único evento que deve ser carregado de propósito, com a cabeça aparada).
3. **5,7 s de criatura parada** no lugar da caminhada. A estrada saiu, mas `e5_esporo` cresceu para 2,61 s e `e6_anjo` para 3,08 s (25,38–31,07 s); o anjo fica praticamente imóvel o plano inteiro (movimento médio 0,48 por quadro; `g3/estradas.png`). O tempo que a caminhada perdeu foi para dois planos parados, e a atenção desaba no mesmo lugar de antes (40 a 48% do filme). **Exijo** ≤ 1,5 s cada ou um plano com a criatura em ação (chegando, atacando, pousando).

### Mixagem (medida nos stems do corte 3)
- **Cortes no grave:** sem piora em relação ao corte 2. `ia_hall4` agora cai no ataque (subida de 10,4 dB no corte); o espólio cai no evento escrito (`packSealBreak`, mix +6,4 dB no corte); `k_porta` está a ≤ 2 quadros do ataque. `ia_hall3` continua sem subida no próprio quadro (−7,8 dB; o ataque fica a ~2 quadros), aceitável.
- **Salão do Tirano:** música −25,6, efeito −23,5. Melhorou 10 dB em relação ao corte 2, mas a música ainda não lidera; o acento ainda não sobe no corte (+0,9 dB no mix).
- **Silêncio:** 2,0 s de silêncio digital total (−88 a −92) sobre o trono IA e depois 3 s a −24/−36 com os olhos. O contraste é máximo. **Risco anotado** (não bloqueia): 2 s de zero absoluto num player de loja pode soar como áudio que caiu. Um tom de sala a −45/−50 preserva o silêncio sem parecer falha. Decisão de escuta.
- **Coringa (M4):** música −27,8, SFX −16,3. Continua 11,5 dB abaixo; o "−6 dB na revelação" não chegou ao mix.
- **Golpe:** respiro limpo e impacto a −7/−6; ok.

## Notas da versão Tirano (rodada 1)

| critério | nota | por quê |
|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | pôster com o Espantalho inteiro |
| C2 Sem preto | 10 | 0 quadros < 5% |
| C3 Sincronia | 9 | cortes no ataque ou a ≤ 2 quadros; espólio no evento escrito |
| C4 Legibilidade | **8** | vida e LETHAL legíveis; espólio ×3 com as cartas cortadas e o texto encostado nos selos NEW; mão ×3 cortada |
| C5 Ritmo | **8** | 5,7 s de criatura parada (25,4–31,1 s) |
| C6 Pico | 9 | flash, tremor, número, queda |
| C7 Regra de 3 | 9 | — |
| C8 Fecho | 9 | — |
| C9 Conformidade | 9 | sem troca de faixa, texto ou salão; marca "não publicável" |
| C10 Checklist do Daniel | **8** | porta do castelo sem som (pedido 6) |
| C11 Continuidade | **7** | 48 LETHAL → "47" + "Volley +18" de outra jogada; escala vai e volta ×3/×1/×3 com o foco atravessando a tela |
| C12 Está bom / legal de assistir | **8** | a virada agora conta a história, mas os pulos de escala e o número trocado tiram o crédito |
| C13 Prende do início ao fim | **8** | os dois planos parados de criatura antes da porta |
| C14 Som | **8** | portão mudo; coringa 11,5 dB abaixo; salão do Tirano ainda sem acento |

| pontos do Grimoire | nota |
|---|---|
| G1 nenhum quadro preto | 10 |
| G2 caminhada ≤ 3 s | 9 (a estrada saiu; o problema mudou para C5/C13) |
| G3 salões legíveis e marcantes | 9 |
| G4 luta do Rei sem interrupção | 9 |
| G5 golpe final forte | **8** (o número não bate com o LETHAL) |
| G6 LETAL do gancho | 10 |
| G7 textos exatos | 10 |
| N1 virada legível | **8** (vida e LETHAL ótimos; o golpe vem de outra jogada) |
| N2 caminhada ≤ 1,5–2 s ou porta abrindo | 9 |
| N3 salões pixelizados na grade nativa | 9 |
| N4 zoom suave no miolo | **6** (degraus ×3 com recuo ×1 no meio e foco saltando; espólio cortado) |
| N5 mixagem | **8** (portão mudo, coringa, acento do Tirano) |

**Status da versão Tirano: NÃO APROVADO.** Para o corte 4: o ponto 4 refeito como aproximação progressiva (ou a decisão explícita do Grimoire sobre a PERGUNTA), o golpe da mesma jogada da virada (número = LETHAL), o portão com som, os planos de criatura ≤ 1,5 s ou em ação, o espólio com as cartas inteiras e o texto livre, a música do coringa a 4–6 dB do SFX e o acento do salão do Tirano liderado pela música.

## Variante do Rei
Revisada na seção "Variante Rei do corte 3", no fim deste arquivo.


## Variante Rei do corte 3 (`grimoire_zero_corte3_rei_720p.mp4`, 18:09), rodada 1: NÃO APROVADO

_Mesma régua e mesmo método da versão Tirano: medidas quadro a quadro (`...\scratchpad\rev\e3_rei\`); mixagem nos stems reais `build\trailer\zero3_rei\zero3_rei_rei\` (`mix3_rei.json`); EDL `edl3.py` com `TDZ_MUSIC=rei`; quadros do LETAL e do golpe (`...\rev\g3\rei_lg.png`). Não ouvi._

A variante usa a mesma montagem da versão Tirano, então herda os mesmos defeitos de imagem, que **valem igual aqui**: o ponto 4 reprovado (degraus ×3 com recuo ×1 no meio e o foco atravessando a tela, 44,47–53,24 s), o espólio a ×3 com as duas cartas cortadas e o texto encostado nos selos NEW (9,99–11,87 s) e os 5,3 s de criatura parada (`e5_esporo` 2,51 s + `e6_anjo` 2,83 s, 25,07–30,41 s). E também o golpe de outra jogada: o painel diz **48 LETHAL** e o golpe mostra **"47"** com o banner **"Volley +18"** e um "20" solto do jogo ao lado do número (`rei_lg.png`).

**O que a variante tem de melhor:**
- **O portão soa:** `castleGateOpen` a 30,93 s (−4,2 dB), audível no plano ×2 da porta.
- **A volta do drop** no nome do Rei (39,44 s) ficou forte: a música passou de −25,3 para **−19,2**, no nível da principal (M2 resolvido), com a maior subida de grave do filme no quadro exato.
- **Silêncio:** fade de ~1,5 s da porta para o trono IA, até o zero digital por ~0,4 s, e depois −25 a −37 no escuro com os olhos. O contraste é ótimo.
- **Zero quadros abaixo de 5%;** −14,1 LUFS, −1,2 dBTP.

**O que é só desta variante (mixagem medida):**
1. **O pico não é o maior trecho do filme.** Curto prazo por segundo: golpe e morte a −9,2/−9,1 (55–56 s), mas o **logo chega a −9,9 (62 s) e −10,3/−10,4** (61 e 63 s). A margem do pico sobre o fecho é de cerca de **0,8 dB**, abaixo dos ≥ 2 dB que o roteiro fixou. A tabela do `corte3.md` dá +3,8 dB, mas, medindo o mp4 por segundo, o fecho praticamente empata. No plano do logo a música está a −14,7 e no coringa a −14,2, os trechos mais altos de música do filme depois do golpe. **Exijo** o fecho pelo menos 2 dB abaixo do pico (a música do logo uns 3 a 4 dB abaixo).
2. **Coringa invertido (M4 ao contrário):** na variante a música fica **12,8 dB acima** do SFX na revelação (música −14,2, SFX −27,0). A meta é a música 4 a 6 dB **abaixo** do SFX; aqui o som da revelação do coringa some.
3. **LRA 7,4** contra 9,3 da principal: a segunda metade é mais chapada (curto prazo de −13 a −15 do nome ao fim, com o logo no topo). É consequência dos itens 1 e 2.
4. **Cortes ainda fora do grave real** (subida no próprio quadro / maior subida em ±30 ms): `e2_gargula` 11,87 s (0,3 / 14,8 dB), `ia_hall3` 13,15 s (−16,7 / 10,0 dB), `k_revoada_rei` 44,47 s (−1,7 / 18,4), `k_porta` 30,41 s (−2,3 / 17,2) e `logo` 58,41 s (−7,7 / 17,2). Os dois primeiros continuam sem ataque perto (a própria tabela da diretora mostra 4,5 e 7,4 dB). O salão do Tirano, que é o acento, não bate em grave nesta faixa. Os outros três têm o ataque a ≤ 2 quadros, o que é aceitável.

### Notas da variante Rei (rodada 1)

| critério | nota | por quê |
|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | — |
| C2 Sem preto | 10 | — |
| C3 Sincronia | **8** | gárgula e salão do Tirano sem grave real |
| C4 Legibilidade | **8** | mesmo da Tirano (espólio e mão ×3 cortados) |
| C5 Ritmo | **8** | 5,3 s de criatura parada |
| C6 Pico | **7** | o fecho praticamente empata com o golpe (margem ~0,8 dB) |
| C7 Regra de 3 | 9 | — |
| C8 Fecho | 9 | imagem ok; o volume é o item 1 |
| C9 Conformidade | 9 | — |
| C10 Checklist do Daniel | 9 | portão audível; salto interno da faixa anotado para ele |
| C11 Continuidade | **7** | 48 LETHAL → "47" + "Volley +18"; vai e volta ×3/×1/×3 |
| C12 Está bom / legal de assistir | **8** | — |
| C13 Prende do início ao fim | **8** | criaturas paradas antes da porta |
| C14 Som | **8** | coringa invertido, LRA 7,4, fecho alto |
| G1 a G7 | 10 · 9 · 9 · 9 · **8** · 10 · 10 | G5: número do golpe ≠ LETHAL |
| N1 a N5 | **8** · 9 · 9 · **6** · **8** | iguais à Tirano; N5 pelos itens 1, 2 e 4 |

**Status da variante Rei do corte 3: NÃO APROVADO.** Tudo entra no corte 4, junto com as 7 correções da `instrucao-grimoire-corte4.md`. Na versão Rei do corte 4 confiro em especial: fecho ≥ 2 dB abaixo do pico, música do coringa 4 a 6 dB abaixo do SFX, e gárgula e salão do Tirano num ataque real da faixa do Rei.
