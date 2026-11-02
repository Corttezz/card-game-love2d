# Revisão: corte 7 (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `corte7.md` (commit 0bae9780), as correções do meu `revisao-corte6.md`, os 10 pontos de `revisao-grimoire-corte5.md` e os critérios de sempre. Vídeos: `grimoire_zero_corte7_1080p.mp4`, `_720p.mp4` e `_rei_720p.mp4`; stems de 21:42 em `build\trailer\zero6\zero6_tirano\` e `zero6_rei\zero6_rei_rei\`. Método: luma de todos os quadros e loudness (`medir.py`), mixagem por plano (`mixagem.py` → `mix7_*.json`), força de ataque do grave (30 a 160 Hz, ±30 ms), fluxo espectral em mel (`flux.py`, porque o librosa não está instalado aqui), curto prazo por segundo (ebur128) e folhas a 2, 4, 5, 10 e 20 quadros/s. Tudo em `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\f967decd-bccd-487a-92fd-ff59f9b0ee6d\scratchpad\rev\c7\`. Não ouvi._

## Versão principal (Tirano), 1080p e 720p: APROVADO

### Correções pedidas no corte 6

| correção | veredito | o que medi e vi |
|---|---|---|
| música até o fim, WISHLIST sob trilha | **resolvido** | Stem da música de 57 a 64,5 s, em janelas de 0,5 s: −21 −21 −26 −29 −32 −26 −21 −26 −28 −26 −25 −34 −35 −38 −44 dB. Não há mais o zero digital a 60,7 s. O WISHLIST (62,17 s) entra com a trilha em −25/−34 dB, e ela some no fade até 64,5 s (`q\logo_t.png`). Curto prazo no logo: −14,6 a −16,9 LUFS, sem buraco. A segunda passagem fica no respiro antes do golpe (música a −66 e −94 dB de 49,75 a 50,25 s) e volta com o ataque de grave do golpe (81 dB a 50,334 s, −1,6 quadro do corte). É a mesma peça. |
| corpo caído sem a carta, sem giro duplo | **resolvido** | De 53,2 a 55,2 s há só o corpo segurado e "BREAK THEM BACK.", sem nenhum quadro de carta (`q\qt.png`). O coringa entra a 55,22 s com um giro só: verso de 55,23 a ~55,55 s, quina, face a partir de ~55,63 s e assentada a ~55,78 s (`q\ct.png`). Face parada e legível até 58,35 s (~2,6 s), com o nome. |

### Sincronia do trecho novo (conferida, não segura)
O trecho de música depois do golpe mudou, e as distâncias da queda e do coringa mudaram com ele. No grave: queda (50,96 s) a −3,8 quadros de um ataque de 16 dB; coringa (55,22 s) a +3,2 quadros de um de 15,6 dB; logo (58,35 s) a −2,7 quadros de um onset forte de banda cheia (no grave, −6,2 quadros de um de 25 dB). A tabela da própria diretora (`onsets_tirano_corte7.md`) sugere "mover" o logo para 58,63 s, e isso não foi feito nem comentado no `corte7.md`. Mesmo assim não reprovo, por dois motivos:
- **O acento forte do trecho cai na revelação.** O maior ataque perto do coringa (39 dB a 55,786 s) acontece no quadro em que a face assenta: a música bate na face, não no verso.
- **Fica dentro da régua que aprovei na Tirano do corte 5d** (coringa a 85 ms, logo a 170 ms). O trecho depois do golpe é uma grade densa de ataques de 15 a 29 dB a cada 0,1 a 0,2 s, e os acentos de verdade (golpe, 52,18 s e 55,79 s) estão cobertos.

Fica o pedido de registrar no `corte7.md` por que o logo não foi movido.

### Medidas
Zero quadros < 5% nos 3870 quadros (1080p e 720p). −14,1 LUFS, −1,0 dBTP, LRA 8,4. Pico de −9,5 no clímax contra −12,0 fora dele: **+2,5 dB**. Coringa com a música **4,7 dB abaixo do SFX** (−20,4 / −15,7 no plano). Antes do castelo, 2,0 s, com pouso (26,38 s, +1,3 quadro) e portão (27,38 s) no tempo. Silêncio do trono com volta de +57 dB no nome, no ataque.

### Os 10 pontos (sem regressão)
1 zoom sem recuo; 2 caminhada de 2,0 s; 3 portão abrindo; 4 "48" grande; 5 texto depois da poeira (corpo segurado, texto de 53,51 a 55,22 s, 1,71 s); 6 e 7 face parada ~2,6 s, com um giro só; 8 ponto final; 9 salões limpos (mesmos arquivos do corte 6); 10 vale para o Rei. Todos com 9 ou mais.

### Notas da versão principal

| critério | nota | | ponto | nota |
|---|---|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | | G1 nenhum quadro preto | 10 |
| C2 Sem preto | 10 | | G2 caminhada | 10 |
| C3 Sincronia | 9 | | G3 salões legíveis e marcantes | 9 |
| C4 Legibilidade | 9 | | G4 luta do Rei sem interrupção | 10 |
| C5 Ritmo | 9 | | G5 golpe final forte | 9 |
| C6 Pico | 9 (+2,5 dB) | | G6 LETAL do gancho | 10 |
| C7 Regra de 3 | 9 | | G7 textos exatos | 10 |
| C8 Fecho | 9 | | N1 virada legível | 9 |
| C9 Conformidade | 9 | | N2 caminhada / porta | 10 |
| C10 Checklist do Daniel | 9 | | N3 salões na grade nativa | 9 |
| C11 Continuidade | 9 | | N4 zoom em degraus progressivos | 10 |
| C12 Está bom / legal de assistir | 9 | | N5 mixagem | 9 |
| C13 Prende do início ao fim | 9 | | correções do corte 4 | 9 em todas |
| C14 Som | 9 | | 6 pontos do corte 4 | 9 em todos |
| **Q queda do Rei** | **9** | | 10 pontos do corte 5 e correções do corte 6 | 9 ou mais em todos |

**Status da principal: APROVADO** (1080p e 720p, mesmas medidas).

## Variante do Rei (720p): NÃO APROVADO (falta 1 item)

### Correções pedidas no corte 6

| correção | veredito | o que medi e vi |
|---|---|---|
| portão no ataque forte | **resolvido** | Portão a 27,31 s: ataque de grave de 20,8 dB a −0,1 quadro. Pouso a 26,31 s: ataque de 51,2 dB a +1,0 quadro (no fluxo espectral, onset forte a −0,1 quadro). Esporo 1,24 s + pouso 1,0 s = **2,24 s** antes do castelo. As folhas abrem dentro do plano (`q\cast_r.png`). Registro: há um ataque ainda maior a 27,58 s (48,5 dB, +16,6 quadros), mas o pedido era 27,31 s e ele está cumprido. |
| carta fora do texto | **resolvido** | De 53,1 a 54,55 s há só o corpo segurado e o texto (53,28 a 54,555 s, 1,27 s), sem carta (`q\qr.png`). |

### O que ainda segura: giro duplo da carta no plano do coringa (C11, C4)
A folha a 20 quadros/s (`q\cr.png`) mostra, a partir do corte de 54,555 s:
- verso de 54,57 a 54,67 s;
- **face de 54,72 a 54,82 s** (cerca de 6 quadros);
- **verso de novo** de 54,92 a 55,12 s;
- face definitiva só a partir de ~55,3 s.

É o mesmo giro duplo que foi pedido e tirado da principal ("sem giro duplo"): a face pisca e some antes da revelação de verdade. **Erro meu no corte 6:** a minha folha do Rei era de 5 quadros/s, pulou a face de 54,72 s e eu escrevi "giro quase limpo". Os dois quadros dessa folha que mostram a face (`q\cr.png`) provam o contrário.

**Exijo** o mesmo tratamento da principal. O corte fica a 54,555 s (onset forte da tabela), mas o ponto de entrada da tomada começa ~0,37 s depois, no segundo verso. O plano passa a mostrar verso → giro → face, uma vez só, e a face continua parada por bem mais que 2,5 s (o plano tem 3,75 s).

### Medidas
Zero quadros < 5%. −14,2 LUFS, −1,1 dBTP, LRA 8,5. Pico +3,2 dB (−9,0 contra −12,2). Coringa com a música **4,8 dB abaixo do SFX**. Música até o fim, com fade. Os 5 cortes do ponto 10 continuam iguais ao corte 6 (queda e logo em onsets fortes; coringa no onset da tabela, com 14,8 dB no grave e um baque de 28,8 dB 8 quadros depois, como já registrado).

### Notas da variante do Rei

Iguais às da principal, menos:

| critério | nota |
|---|---|
| C3 Sincronia | 9 (pouso e portão no ataque) |
| C4 Legibilidade | **8** (face pisca 0,1 s e some) |
| C6 Pico | 10 (+3,2 dB) |
| C11 Continuidade | **8** (giro duplo) |
| pontos 6 e 7 do Grimoire | 9 (a face assentada dura ~3 s, mas é precedida do flash) |

**Status da variante do Rei: NÃO APROVADO**, por um único item: o giro duplo da carta de 54,57 a 55,3 s. Com o ponto de entrada da tomada ajustado, sem outra mudança, a variante fica com 9 ou mais em tudo.

## Status geral
Principal (Tirano): **APROVADO**. Variante (Rei): **NÃO APROVADO** (giro duplo). `===CORTE7_PRONTO===` só depois da variante.
