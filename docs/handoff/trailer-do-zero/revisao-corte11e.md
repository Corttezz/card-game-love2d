# Revisão independente: corte 11, revisão 5 (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivos: `grimoire_trailer_c11_720p.mp4` (Tirano, 69,1 s), `grimoire_trailer_c11_rei_720p.mp4` (Rei, 69,7 s) e os masters 1080p. Base: minha `revisao-corte11d.md` (53bc9ce6) e `corte11.md`, seção "Revision 5" (81975775). Mesmos critérios e referências._

_O que medi:_
- _detecção de cortes quadro a quadro de 43 a 63 s;_
- _barra do Rei e painel HERO 1:1 a −3, −1, +1 e +3 quadros de **todo** corte da luta (`tl.png`, `rl.png`);_
- _o contador do Rei quadro a quadro na divisão do turno 1, inclusive ampliado sem filtro (`k.png`, `kr.png`, `dig.png`, `dig2.png`, `kf.png`);_
- _quadros escuros, `ebur128`, bitrate, onsets._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev11e\`. Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: PASS nas duas versões

As duas versões têm ≥ 9 em todos os pontos e na continuidade, e são claramente melhores que o v5, o v6, o v8 e o kinetic_new.

## Correção de um erro meu na revisão 4

O "contador 65 → 77" que reprovou a revisão 4 **foi leitura errada minha**.
- Nos quadros antes da divisão do turno 1, a dezena do contador do Rei fica coberta pela arte em chamas da carta Colossus Blow, que passa sobre o HUD. Ampliado sem filtro (`dig2.png`), só se vê a metade de baixo da dezena e o "5" inteiro. Eu li "65".
- Pela conta, só pode ser **85**: 124 − 39 do Colossus Blow. Antes do Immolate nenhum golpe pode levar o Rei a 65.
- Depois do clarão do Immolate ("WEAKNESS!", −55), o contador desce **85 → 77 → 70 → 65 → 60 → 55 → 52 → 49 → … → 30**, sem subir.

Na revisão 5 é o mesmo trecho, agora contíguo na tomada (quadro seguinte), então nada mudou nos números. Provavelmente a revisão 4 já estava certa nesse ponto. A diretora refez um corte por um defeito que não existia. Registro o erro.

## Todos os cortes da luta, dos dois lados

| corte (Tirano / Rei) | antes | depois | resultado |
|---|---|---|---|
| cartão do nome → turno 1 (48,683 / 50,150) | sem HUD | 124/220, herói 41 | primeiro número, ok |
| dentro do turno 1 (49,817 / 50,750) | 124, herói 41 | 124, herói 41 | ok |
| divisão do turno 1 (50,933 / 51,883) | 85 (meio coberto), herói 41 | clarão do Immolate, 77 → 70 → … | contíguo, só desce, ok |
| turno 1 → corvos (51,833 / 53,250) | Rei 30, herói 41 | Rei 30, herói 41 | ok |
| corvos → LETHAL (57,267 / 58,267) | Rei 21, herói 9 | Rei 21, herói 9 | ok |
| golpe → morte (58,967 / 59,550) | 21, "−31 Colossus Blow" | flash, morte | ok |

Dentro do plano dos corvos, o herói desce de 41 a 9 a cada mergulho, e o tique −9 leva o Rei de 30 a 21. Nenhum número muda num corte.

## A) Nota por ponto do feedback

| # | ponto | Tirano | Rei |
|---|---|---|---|
| 1 | textos (sem CHAINS/FROST, grandes, vendem) | 9 | 9 |
| 2 | abertura: seis atos andando, ambiente calmo (−24/−21 LUFS) | 9 | 9 |
| 3 | qualidade de imagem (Higgsfield do 4K, 13,7 Mb/s no 720p) | 9,5 | 9,5 |
| 4 | chefes trocando no ritmo | 9 | 9,5 |
| 5 | sensação épica (entrada, combo, corvos, LETHAL, golpe e morte, arco de som) | 9 | 9 |
| 6 | jogar cartas satisfatório | 9,5 | 9,5 |
| 7 | coleção com cartas descendo e cartas grandes | 9,5 | 9,5 |
| 8 | entradas de criaturas, Espantalho incluído | 9 | 9 |
| 9 | final do Grimoire com ícone e animações (390 quadros) | 10 | 10 |
| 10 | geral contra os trailers anteriores | 9,5 | 9,5 |
| — | continuidade de números na luta | 9,5 | 9,5 |

## B) Lado a lado

| referência | o corte 11 ganha |
|---|---|
| **v5** | Metade da duração, textos grandes, entradas, coleção com carta grande, golpe final e morte visíveis, imagem melhor. O v5 mostra mais sistemas (loja e pacotes). |
| **v6** | Entradas, SIX BOSSES no tempo forte, arco de som e o golpe que mata na tela (o v6 mata o Rei pelo atalho). |
| **v8** | Seis atos, coleção, a luta inteira até a morte, textos legíveis. Arco de som equivalente. |
| **kinetic_new** | Mostra o jogo em vez de cobrir com texto; tem atos, coleção, entradas, golpe e morte. O kinetic tem mais energia tipográfica, mas é o único ponto em que chega perto. |

Claramente melhor que as quatro referências no conjunto.

## C) Conferências técnicas

| item | Tirano | Rei |
|---|---|---|
| sem zoom | só a TV ligando e a transição da porta para o rasante do jogo | igual |
| cortes no onset | luta e chefes nos ataques fortes; a divisão do turno 1 (50,933) cai no clarão do Immolate | divisão do turno 1 a 51,883 (4,3×, +2,7 q do ataque de 51,934); os demais com grave de +20 a +44 dB |
| quadros < 5% de luma | 135: TV ligando, fundo do logo e o rabo de 0,03 s | igual |
| loudness | **−14,1 LUFS**, pico −1,4 dBFS, LRA 11,3 | **−14,0 LUFS**, pico −1,0 dBFS, LRA 9,5 |
| bitrate 720p | 13,7 Mb/s | 13,8 Mb/s |

## Observações para o Daniel (sem bloqueio)

- A luta começa com o Rei em 124/220 e o herói em 41/70, preparados fora dos quadros usados (modo deus desligado). Daí em diante, só golpes.
- "SIX BOSSES." mostra cinco salões: o chefe final fica escondido.
- Os salões são vídeos de IA (Higgsfield), usados só na montagem dos chefes, com nome.
- A ordem dos textos é proposta da diretora.

**Não publicável até trocar ou licenciar os SFX** (ElevenLabs free). Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.

===CORTE11_PRONTO===
