# Revisão: corte 4 (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `corte4.md` (18:37), `instrucao-grimoire-corte4.md` (zoom em degraus progressivos + 7 correções), `revisao-grimoire-corte2.md` (5 pontos), `revisao-grimoire-corte1.md` (7 pontos) e os 14 critérios. Esta rodada cobre a **versão Tirano** (`grimoire_zero_corte4_1080p.mp4` e `_720p.mp4`, 18:36); a variante do Rei entra numa seção própria quando sair. Método: medidas quadro a quadro (`...\scratchpad\rev\f4_1080\`), folhas a 3-4 quadros/s da virada (43,9–53,5 s) e das criaturas/portão (25,3–32,6 s), quadros cheios do espólio, da vida, do LETHAL e do golpe (`...\rev\g4\`), folha a 15 quadros/s da passagem portão → salão IA, e a mixagem sobre os stems reais `build\trailer\zero4\zero4_tirano\` (`mixagem.py` → `mix4_tirano.json`). Não ouvi._

## Versão Tirano, rodada 1: NÃO APROVADO (falta 1 item)

Este é o corte que finalmente conta a luta. As 7 correções do Grimoire chegaram, e a maioria ficou ótima:

| correção | veredito | o que vi e medi |
|---|---|---|
| Zoom (ponto 4) | **resolvido** | ×2 Rei anunciando "Murder of Crows" → ×2 Rei + painel de vida (25 → 22 → 21 → 18 → 17) → **×3 no mesmo canto** (14 → 13 → 10 → 9, "Weak") → ×2 mão + Rei + painel (29 → **48 LETHAL**, Play Cards apertado) → golpe. Aproximação progressiva, sem ×1 no meio; o recuo ×3 → ×2 no último degrau é a opção que o próprio Grimoire deu ("mão e painel juntos em ×2") |
| 1 virada | **resolvido** | a vida cai a cada corvo, de 25 a 9, legível; o LETHAL aparece com a mão e o Rei, antes do golpe |
| 2 golpe da mesma jogada | **resolvido** | "**48**" congelado = "48 LETHAL" do painel; o banner "Volley +18" é o do mesmo turno (as três cartas mostram "Volley +6" cada, somando +18). Rei inteiro, flash e tremor mantidos |
| 3 portão com som | **resolvido** | o portão soa no início do plano (`k_porta_a`, 29,95 s; SFX do trecho a −16 / −14 dBFS) |
| 4 criaturas | **resolvido** | mãe-esporo 1,33 s; anjo descendo 1,53 s → ×2 no pouso 1,71 s (em ação, `g4/estrada.png`) |
| 5 espólio | **resolvido** | ×2 com Poison Dart e Rain of Blades inteiras; "145 LIVING CARDS." numa linha livre, longe dos NEW e acima de AFFINITY / RARE FIND |
| 6 mix | **resolvido** | coringa: música −22,0 / SFX −16,7 (**5,3 dB abaixo**); salão do Tirano: música −18,9 / efeito −30,8 (**música lidera por 12 dB**) e o acento **sobe** no corte (+5,6 dB na música, +4,7 dB no mix) |
| 7 tom de sala | **resolvido** | trono vazio a −46 a −57 dBFS RMS (média ≈ −51) em vez de zero digital; zero música |

Pico: golpe e morte a −8,3/−8,4 LUFS de curto prazo, **+3,5 dB** sobre qualquer outro trecho. Silêncio da entrada: −24 a −36 com os olhos e eventos isolados. Volta no nome do Rei: +15 dB na música num quadro. −14,2 LUFS, −1,1 dBTP e LRA 9,7 no 1080p e no 720p.

### O que ainda segura: quadros pretos de novo (G1 / C2)
**15 quadros (0,25 s) totalmente pretos, de 32,30 a 32,53 s**, na passagem do portão para o salão IA do Rei (`g4/preto.png`). O plano do portão escurece até o preto, fica preto por uns 4 quadros e só então entra o trono em chamas. É um fade pelo preto, provavelmente o escurecimento do próprio jogo ao atravessar a porta, que entrou no corte quando o plano do portão foi esticado. O ponto 1 do Grimoire diz "nenhum quadro preto" e a régua é zero quadros abaixo de 5%. **Exijo** o corte seco do portão para o salão IA no grave **antes** de o escurecimento começar (os quadros de 32,30 a 32,53 s saem), ou um lift que mantenha o portão visível até o corte. É uma linha na EDL.

### Observações menores (não seguram, mas valem a rodada)
- `k_porta_a` (29,95 s) cai num ataque fraco da música (subida máxima de 9,5 dB em ±30 ms). Como entra junto com o portão a +6 dB, o corte é guiado pelo evento, o que é aceitável. Escrevam isso no `corte4.md`, como no espólio.
- As criaturas da montagem (esporo, anjo, pouso) não têm nenhum SFX (stem de SFX a −∞ de 25,38 a 29,95 s): o anjo pousa em silêncio. A música carrega o trecho, mas um baque de pouso do jogo daria peso ao plano ×2.
- O ×2 do LETHAL corta o Rei pela borda esquerda (meio corpo). A leitura não sofre, porque o assunto é o painel, mas se o recorte puder entrar uns 60 px de captura para a direita sem perder a mão, fica mais limpo.
- O tom de sala chega a −53/−57 em alguns trechos de 100 ms, um pouco abaixo da faixa pedida (−45 a −50). Inaudível como diferença; registro.

## Notas da versão Tirano (rodada 1)

| critério | nota | | ponto | nota |
|---|---|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | | G1 nenhum quadro preto | **8** |
| C2 Sem preto | **8** | | G2 caminhada ≤ 3 s | 9 |
| C3 Sincronia | 9 | | G3 salões legíveis e marcantes | 9 |
| C4 Legibilidade | 9 | | G4 luta do Rei sem interrupção | 10 |
| C5 Ritmo | 9 | | G5 golpe final forte | 9 |
| C6 Pico | 10 | | G6 LETAL do gancho | 10 |
| C7 Regra de 3 | 9 | | G7 textos exatos | 10 |
| C8 Fecho | 9 | | N1 virada legível | 9 |
| C9 Conformidade | 9 | | N2 caminhada ≤ 1,5–2 s ou porta | 9 |
| C10 Checklist do Daniel | 9 | | N3 salões na grade nativa | 9 |
| C11 Continuidade | 9 | | N4 zoom em degraus progressivos | 9 |
| C12 Está bom / legal de assistir | 9 | | N5 mixagem | 9 |
| C13 Prende do início ao fim | 9 | | correções 1 a 7 do corte 4 | 9 em todas |
| C14 Som | 9 | | | |

**Status da versão Tirano: NÃO APROVADO, por um único item:** os 15 quadros pretos de 32,30 a 32,53 s (C2 e G1 em 8). Com eles fora, sem outra mudança, a versão Tirano fica com ≥ 9 em tudo. `===CORTE4_PRONTO===` só depois disso e da aprovação da variante do Rei.

## Variante do Rei (`grimoire_zero_corte4_rei_720p.mp4`, 18:49), rodada 1: NÃO APROVADO

_Revisão focada no que é próprio da variante, porque a imagem é a mesma montagem da versão Tirano. Medidas: `...\scratchpadev4_rei\`; mixagem sobre os stems `build	railer\zero4_rei\zero4_rei_rei\` (`mix4_rei.json`). Não ouvi._

- **Quadros pretos:** os mesmos **15 quadros de 32,30 a 32,53 s** da versão Tirano (fade pelo preto entre o portão e o salão IA). Vale a mesma exigência.
- **Pico × fecho:** resolvido. Golpe e morte a −8,7 LUFS de curto prazo, contra −11,4 no melhor trecho fora do clímax (**+2,7 dB**). O logo caiu para −18,2 no mix.
- **LRA 9,0** (era 7,4): resolvido.
- **Salão do Tirano no grave real:** resolvido (`ia_hall3` cai no ataque, com a música 15,8 dB acima do efeito e subindo no corte).
- **Coringa: piorou.** Música −10,5, SFX −28,6: a música fica **18 dB acima** do som da revelação. A meta (4 a 6 dB abaixo do SFX) entrou na versão Tirano, não na variante. O som do coringa some.
- **Gárgula / "6 ACTS." (11,77 s): ainda sem grave real** (subida máxima de 5,9 dB em ±30 ms). `ia_hall4` (20,95 s) está fraco, com 11 dB.

| critério | nota | | critério | nota |
|---|---|---|---|---|
| C2 Sem preto / G1 | **8** | | C6 Pico | 9 |
| C3 Sincronia | **8** (gárgula) | | C14 Som / N5 | **8** (coringa) |

As demais notas são iguais às da versão Tirano. **Status da variante Rei do corte 4: NÃO APROVADO.** Para o corte 5: tirar os quadros pretos, pôr a música do coringa 4 a 6 dB abaixo do SFX também nesta variante e levar a gárgula a um ataque real da faixa do Rei.
