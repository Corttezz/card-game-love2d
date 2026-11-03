# Revisão independente: corte 11, revisão 4 (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivos (regravados): `grimoire_trailer_c11_720p.mp4` (Tirano, 69,1 s, 4141 quadros) e `grimoire_trailer_c11_rei_720p.mp4` (Rei, 69,7 s, 4175 quadros), mais os masters 1080p. Base: minha `revisao-corte11c.md` (b4059330) e `corte11.md`, seção "Revision 4" (727c350f). Mesmos critérios e referências._

_O que medi:_
- _detecção de cortes quadro a quadro de 43 a 63 s nos masters;_
- _recorte 1:1 da barra do Rei e do painel HERO a −3, −1, +1 e +3 quadros de **todo** corte da luta (`tl.png`, `rl.png`), e quadro a quadro do contador do Rei no corte do turno 1 (`k51.png`, `k52r.png`);_
- _quadros escuros, `ebur128`, bitrate;_
- _onsets na faixa de cada versão._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev11d\`. Observação: `cortes_x_onsets_*.txt` em `corte11_provas\` ainda são da revisão 3 (terminam em 65,381 s / 66,797 s) e não descrevem este corte. Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: FAIL nas duas versões, por um defeito pequeno e de correção trivial

Os três saltos da revisão 3 estão resolvidos. Mas, conferindo os dois lados de **todo** corte da luta, achei um que nem a prova da diretora nem a minha revisão anterior viram: **o contador da vida do Rei volta para trás no corte que divide o turno 1.**

| corte (Tirano / Rei) | antes | depois | resultado |
|---|---|---|---|
| cartão do nome → turno 1 (48,683 / 50,150) | sem HUD | 124/220, herói 41 | ok, primeiro número |
| dentro do turno 1 (49,817 / 50,750) | 124, herói 41 | 124, herói 41 | ok |
| **divisão do turno 1 (50,983 / 52,000)** | contador do Rei em **65** (descendo) | **77** → 70 → 65 → 60 → 55 → 52 → 49 … | **o número sobe 12 no corte e conta de novo** |
| turno 1 → corvos (51,833 / 53,250) | Rei 30, herói 41 | Rei 30, herói 41 | ok |
| corvos → LETHAL (57,267 / 58,267) | Rei 21, herói 9 | Rei 21, herói 9 | ok |
| golpe −31 → morte (58,967 / 59,550) | 21, "−31 Colossus Blow" | flash, morte | ok |

O plano dos corvos é contínuo: herói 41 → 9 com os 8 mergulhos, e o tique −9 no Rei (30 → 21) aparece dentro dele. Os três saltos da revisão 3 acabaram.

**O defeito novo.** No corte que divide o turno 1, o primeiro pedaço termina com o contador do Rei rolando para baixo em 65. O segundo começa alguns quadros mais cedo na mesma contagem, em 77, com o "−55" do Immolate, e rola 77 → 70 → 65 → 60. O número da barra sobe 12 sem cura e repete a contagem por ~0,1 s. Dura pouco, mas é a barra maior da tela, logo acima do Rei, no turno que mostra o dano. Pela régua de todas as revisões desde o corte 9, o número não pode mudar num corte sem golpe, e aqui ele **sobe**. A correção é só de EDL: começar o segundo pedaço no quadro em que o contador já está em ≤ 65, ou terminar o primeiro antes de passar de 77. Nos dois casos, o corte continua no tempo forte vizinho.

## A) Nota por ponto do feedback

| # | ponto | Tirano | Rei |
|---|---|---|---|
| 1 | textos | 9 | 9 |
| 2 | abertura: seis atos com ambiente calmo | 9 | 9 |
| 3 | qualidade de imagem | 9,5 | 9,5 |
| 4 | chefes no ritmo | 9 | 9,5 |
| 5 | sensação épica | 9 | 9 |
| 6 | jogar cartas satisfatório | 9,5 | 9,5 |
| 7 | coleção | 9,5 | 9,5 |
| 8 | entradas de criaturas | 9 | 9 |
| 9 | final do Grimoire | 10 | 10 |
| 10 | geral contra as referências | 9 | 9 |
| — | **continuidade de números na luta** | **8,5** (contador 65 → 77 a 50,983 s) | **8,5** (a 52,000 s) |

## B) Lado a lado com as referências

Corrigido o contador, o corte 11 é **claramente melhor** que o v5, o v6, o v8 e o kinetic_new:
- É o único com a luta inteira legível: entrada, combo, corvos, LETHAL, golpe −31 e morte.
- Tem o arco de som que o v8 tinha (LRA 11,2 / 9,6).
- Tem os seis atos calmos do v5, a coleção do v6 com as cartas grandes, as entradas com o Espantalho, o SIX BOSSES no tempo forte e o final do Grimoire inteiro.
- A imagem é a melhor de todas no 720p.

Hoje ainda carrega o pulo do contador.

## C) Conferências técnicas

| item | Tirano | Rei |
|---|---|---|
| sem zoom | `escala_filme_inteiro.txt` só sinaliza a TV ligando e a transição da porta para o rasante. Ok. | Ok. |
| cortes da luta no onset | 50,983 (3,6×, grave +10,3 dB), 51,856 (4,9×), 57,289 (3,6×, +3,9 dB) | 52,000 (**fraco:** 1,2×, o forte está a −4 q), 53,214 (4,4×), 58,230 (5,8×, +32 dB) |
| quadros < 5% de luma | 135: TV ligando, fundo do logo e o rabo de 0,03 s. Ok. | Igual. |
| loudness | **−14,1 LUFS**, pico −1,3 dBFS, LRA 11,2 | **−14,0 LUFS**, pico −1,0 dBFS, LRA 9,6 |
| bitrate 720p | 13,7 Mb/s | 13,8 Mb/s |

## O que mudar, em ordem de impacto

1. **Divisão do turno 1** (Tirano 50,983 s, Rei 52,000 s): mover a entrada do segundo pedaço até o contador do Rei estar em ≤ 65, ou o fim do primeiro até antes de 77, para que o número só desça. No Rei, aproveite para pôr o corte no ataque forte, 4 quadros antes (51,934 s). Prova: o quadro a quadro do contador dos dois lados deste corte.
2. **Atualizar `cortes_x_onsets_*.txt`** para este corte. Os atuais são da revisão 3.

Fora isso, nada a mudar. Corrigido o item 1, as duas versões ficam ≥ 9 em tudo e passam.

**Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.
