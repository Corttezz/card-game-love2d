# Revisão independente: corte 11f (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivos: `grimoire_trailer_c11f_720p.mp4` (Tirano, 76,6 s, 4591 quadros), `grimoire_trailer_c11f_rei_720p.mp4` (Rei, 69,7 s, 4174 quadros) e os masters 1080p. Base: `revisao-grimoire-corte11e.md` (13a503b3; o lead pediu só os itens 1 a 3), minha `revisao-corte11e.md` (5616373d) e `corte11f.md` (756ec0ea)._

_O que medi:_
- _folhas a 1 quadro/s;_
- _jogada de cartas a 4 e 6 quadros/s, mais a vida do inimigo 1:1 ao longo do bloco e nos dois lados de cada corte (`hpc.png`, `entra.png`, `entra_hp.png`, `tc.png`);_
- _luma por quadro e detecção de cortes;_
- _`ebur128`;_
- _ataque e energia de grave (30 a 160 Hz e 30 a 120 Hz) e fluxo espectral na faixa de cada versão (Tirano a partir de 21 s, Rei a partir de 36 s, música aos 12,6 s do filme), comparando os cortes do 11e com os do 11f._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev11f\`. Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito

| versão | nota | resultado |
|---|---|---|
| **Rei** | **9,4** | **PASS**: ≥ 9 em tudo e claramente melhor que as referências e que o 11e |
| **Tirano** | **8,9** | **FAIL**: a montagem dos chefes ficou mais lenta sem ganhar acento mensurável |

A régua pede as duas versões, então o **corte 11f fica em FAIL**. A versão Rei está pronta para ir ao Daniel.

## Os três itens do lead

### 1. Montagem dos salões no acento forte

- **Rei: confirmado.** Os seis cortes (39,398 / 40,664 / 41,604 / 43,160 / 44,414 / 45,679 s) caem cada um no pico mais forte da vizinhança, com o grave subindo **+34 a +50 dB** no corte (fluxo 3,9× a 7,4×). O primeiro salão foi para o ataque forte, como pedido. É exatamente o "trocava de vídeo seguindo o ritmo" que o Daniel elogiou.
- **Tirano: não melhorou pela minha medida, e o custo foi alto.**
  - **Ataque de grave no corte:** 11f **+4,0 / +11,9 / +7,4 / +8,8 / +4,7 / +10,3 dB** (média 7,9); 11e +5,9 / +8,8 / +9,5 / +6,4 dB (média 7,7). Praticamente igual.
  - **Energia de grave nos 120 ms após o corte:** 11f entre −20,2 e −15,8 dB; 11e entre −21,8 e −11,6 dB. Não aparece um tempo forte por compasso. A faixa da Tirano tem grave denso e uniforme, e os picos de grave reais ficam em 39,9 a 41,1 s e 49,1 a 50,3 s, fora da grade de 2,29 s.
  - **Fluxo:** só 2 dos 6 cortes são o pico local a ±0,6 s; nos outros 4, o pico fica ~0,33 s antes.
  - **O custo:** cada salão passou de ~1,14 s para **~2,29 s**. A montagem foi de 5,4 s para **11,4 s**, e o filme de 69,1 para **76,6 s**. O que o Daniel elogiou foi a troca rápida, "um após o outro". Com 2,3 s por salão de IA parado, o olho tem tempo para os defeitos que ele já criticou nos vídeos do Higgsfield, e o trecho perde energia.

  A medida da diretora (ranking por força × subida dentro de ±1 s) mostra que cada corte é o "melhor" da janela. Mas, nesta faixa, o melhor da janela não é um acento forte. É a mesma conclusão do lead: "o grave nunca salta como no Rei".

### 2. Atos com dissolve curto

**Confirmado nas duas versões.** Seis atos de ~2,3 s andando pela estrada, ambiente calmo, sem corte seco entre eles e com transições curtas. Na entrada da jogada de cartas (Tirano 16,41 s) há um clarão branco de ~0,1 s (luma até 188). É um único flash, abaixo do limite de 3 por segundo. Ok.

### 3. Jogada de cartas com a barra caindo e a morte

**Confirmado nas duas versões, e é a maior melhora do 11f.** O ladino contra o brutamontes com **55/55**:
- prévia −13 → −29 → −48 enquanto as cartas são escolhidas;
- "COMBO! Volley +15";
- a barra cai 55 → 36 → 28 → 26 → 11 → 8 → **7/55** com os golpes, flashes e tremor do jogo;
- no turno seguinte, −7 e a morte.

Vida nos cortes do bloco:
- entrada: **55/55** depois do clarão;
- divisão dos turnos (Tirano 23,272 s): inimigo **7/55** e herói **60/60** dos dois lados;
- saída para a coleção depois da morte.

Sem zoom. Agora a jogada de cartas é satisfatória de ver, o que o v8 e o 11e não eram (inimigo com 466).

## Sem regressão

- **Abertura, coleção (grade e duas cartas grandes), entradas com o Espantalho, luta do Rei e final:** iguais ao 11e nas folhas.
- **Luta do Rei:** a diretora registra nenhuma mudança de número nos cortes. O trecho e a tomada são os do 11e, que conferi quadro a quadro na revisão 5.
- **Final:** 390 quadros do `logo_sting`.
- **Quadros < 5% de luma:** 135 nas duas, só na TV ligando, no fundo do logo e no rabo de 0,03 s.
- **Loudness:** −14,1 LUFS nas duas; LRA 10,2 na Tirano e 9,2 no Rei; pico −1,1 dBFS.
- **Bitrate 720p:** 13,7 Mb/s (Tirano) e 14,1 Mb/s (Rei).

## A) Notas por ponto do feedback

| # | ponto | Tirano | Rei |
|---|---|---|---|
| 1 | textos | 9 | 9 |
| 2 | abertura: seis atos andando, ambiente calmo | 9,5 | 9,5 |
| 3 | qualidade de imagem / Higgsfield | 9 (salão de IA 2,3 s na tela) | 9,5 |
| 4 | chefes trocando no ritmo | **8** (mais lento, sem ganho de acento) | **9,5** |
| 5 | sensação épica | 9 | 9,5 |
| 6 | jogar cartas satisfatório | 9,5 | 9,5 |
| 7 | coleção | 9,5 | 9,5 |
| 8 | entradas, Espantalho | 9 | 9 |
| 9 | final do Grimoire | 10 | 10 |
| 10 | geral contra os anteriores | 8,5 (76,6 s, ritmo cai no meio) | 9,5 |
| — | continuidade de números | 9,5 | 9,5 |

## B) Lado a lado

| referência | Rei 11f | Tirano 11f |
|---|---|---|
| v5 / v6 / v8 / kinetic_new | Claramente melhor: cartas que matam, luta inteira até a morte, montagem no grave, atos limpos, coleção, entradas, final. | Melhor em conteúdo, mas a montagem dos chefes perde o ritmo que o v8 tinha (5 salões em ~5,7 s no drop) e o filme fica 14 s mais longo que o v8. |
| 11e | Melhor: cartas, atos e primeiro salão no tempo forte. | Melhor nas cartas e nos atos, pior na montagem. Empate no saldo. |

## O que mudar (Tirano), em ordem de impacto

1. **Voltar a montagem da Tirano para ~1,14 s por salão** (meio compasso, como no 11e), com os cortes nos ataques de grave da grade de meio compasso. Os picos medidos de 39,9 a 41,1 s e de 49,1 a 50,3 s podem segurar o primeiro e o último salão. Isso devolve a troca rápida e tira ~6 s do filme.
2. **Se o lead quiser mesmo o soco de grave do Rei**, a faixa da Tirano não entrega isso em ponto nenhum: o grave é denso e uniforme. A alternativa honesta é decidir com o Daniel qual música vai na versão principal. Hoje a versão Rei é a que cumpre o ponto 3a dele.
3. **Para o Daniel, sem mexer:** "SIX BOSSES." sobre cinco salões.

**Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.
