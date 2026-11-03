# Revisão independente: corte 11g (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivos: `grimoire_trailer_c11g_720p.mp4` (Tirano, 67,4 s, 4040 quadros), `grimoire_trailer_c11g_rei_720p.mp4` (Rei, 68,4 s, 4099 quadros) e os masters 1080p. Base: `revisao-grimoire-corte11f.md` (ae13205d; o lead pediu só edição e mix), minha `revisao-corte11f2.md` (d210e493) e `corte11g.md` (6d8811f6)._

_O que medi:_
- _detecção de cortes de 15 a 65 s;_
- _números 1:1 dos dois lados de todo corte da luta (`tl.png`, `rl.png`) e a 15 quadros/s pelo plano dos corvos (`corvos_t.png`, `corvos_r.png`);_
- _golpe letal quadro a quadro a 60 quadros/s (`golpe_t.png`, `g2.png`);_
- _morte na jogada de cartas a 20 quadros/s (`cartas_t.png`);_
- _envelope de 100 ms do mix e grave de 30 a 150 Hz nos cortes dos salões (`mix.py`);_
- _luma por quadro, `ebur128`, bitrate._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev11g\`. Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: PASS nas duas versões

| versão | nota |
|---|---|
| Tirano (principal) | **9,3** |
| Rei | **9,4** |

Os quatro itens do lead estão feitos e conferem. Ficam dois riscos de som que não seguram a nota, mas que vale corrigir (ver o fim).

## Os itens do lead

### 1. Tirano: impacto grave em cada troca de salão

**Feito.** Medi o grave (30 a 150 Hz, 100 ms) no corte contra os 0,1 a 0,4 s antes:

| corte | 39,572 | 40,710 | 41,848 | 42,707 | 44,135 | porta 45,285 |
|---|---|---|---|---|---|---|
| subida do grave | +12,6 dB | **+3,6 dB** | +6,1 dB | +11,3 dB | +8,3 dB | +8,2 dB |

- Cada troca agora tem um impacto que a faixa sozinha não dava. Os salões continuam com ~1,1 a 1,4 s, e a troca rápida se mantém.
- O mais fraco é o de **40,710 s**, porque o salão anterior ainda soa alto.
- Para comparar, o Rei dá +16 a +41 dB pela mesma medida. A Tirano não chega ao soco do Rei, mas deixou de ser plana.

### 2. Corvos a 1,8×

**Feito, contínuo.**
- **Tirano:** de 52,700 a 55,550 s (2,85 s, eram 5,4). HERO 41 → 38 → 37 → 33 → 29 → 26 → 25 → 23 → 21 → 19 → 17 → 15 → 13 → 10 → 9, cada um com o painel vermelho do golpe. Depois o tique no Rei 30 → 27 → 23 → 21.
- **Rei:** 3,15 s, com a mesma sequência.
- Dos dois lados dos cortes: 30/41 na entrada e 21/9 na saída para o LETHAL.
- A divisão do turno 1 continua contínua (85 coberto pela carta → 77 → 65 → 60 → 55).
- **Nenhum número muda num corte**, nas duas versões.

### 3. Golpe letal

**Imagem, feito.**
- Na Tirano, a 57,283 s: flash de 4 quadros, e a carta Colossus Blow com o "−31" sobre o Rei segura ~5 quadros (hit-stop); depois o tremor, e a morte entra a ~57,78 s.
- No Rei é igual, a 58,217 s.
- Sem zoom: a prova de escala só marca a TV ligando e a transição da porta.

**Som, feito no sentido do lead, com uma ressalva de régua.** É o momento mais alto do filme (pico de 100 ms em −4,9 dB nas duas). Contra a música que vem antes:

| medida | Tirano | Rei |
|---|---|---|
| contra o vale do duck (0,3 s antes) | +25 a +31 dB | +25 a +31 dB |
| contra a mediana da música de 2,5 a 0,5 s antes | **+11,1 dB** | **+8,5 dB** |
| contra o pico da música no mesmo trecho | +5,4 dB | +3,3 dB |

A diretora mede +19,6 / +17,9 dB contra a "cama 1 s antes", que já cai dentro do duck. Pela leitura estrita do lead ("≥ 12 dB acima da música antes"), dá ~+11 / +8,5 pela mediana. Mesmo assim, o golpe é agora o pico do filme, subindo depois de 0,45 s de silêncio. No 11f ele ficava 6 dB abaixo da música. Não reprovo, e deixo o número para o lead julgar.

### 4. Morte na jogada de cartas

**Feito.** O flash do −30 vem a 24,417 s, e o corte para a Coleção a 24,750 s: as cartas ficam ~0,3 s na frente do inimigo, não mais 1,2 s.

**Efeito colateral medido:** o som do golpe que mata ficou mais fraco. No envelope de 100 ms, entre 0,2 e 0,3 s depois do −30:

| versão | 11f | 11g |
|---|---|---|
| Tirano | −15 / −13 dB | **−22 / −20 dB** |
| Rei | −13 / −11 dB | **−18 / −17 dB** |

São 5 a 7 dB a menos, porque o corte para a Coleção corta a cauda do impacto, e o golpe fica abaixo da música do segundo anterior (−17 dB). Também não se vê o inimigo cair: o filme mostra o −30 e o flash e já corta. A jogada continua satisfatória (barra 55 → 7 com combo, turno LETHAL, −30), mas a morte perdeu peso no ouvido.

## Sem regressão

- **Abertura, coleção, entradas com o Espantalho, salões, luta e final:** iguais ao 11f2 nas folhas.
- **Final:** 390 quadros do `logo_sting`.
- **Quadros < 5% de luma:** 136 (Tirano) e 139 (Rei), só na TV ligando, no fundo do logo e no rabo de 0,03 a 0,08 s. Os 3 quadros a mais do Rei estão no fim do logo.
- **Loudness:** −14,0 LUFS nas duas; LRA 10,6 / 9,2; pico −1,3 / −0,9 dBFS.
- **Bitrate 720p:** 14,0 / 14,1 Mb/s.
- **Escala:** sem zoom.

## A) Notas por ponto do feedback

| # | ponto | Tirano | Rei |
|---|---|---|---|
| 1 | textos | 9 | 9 |
| 2 | abertura dos seis atos | 9,5 | 9,5 |
| 3 | qualidade de imagem | 9,5 | 9,5 |
| 4 | chefes trocando no ritmo | **9** (impacto em cada troca) | 9,5 |
| 5 | sensação épica (corvos rápidos, golpe com hit-stop e o mais alto do filme) | 9,5 | 9,5 |
| 6 | jogar cartas satisfatório | 9 (morte mais fraca no som) | 9 |
| 7 | coleção | 9,5 | 9,5 |
| 8 | entradas, Espantalho | 9 | 9 |
| 9 | final do Grimoire | 10 | 10 |
| 10 | geral contra os anteriores | 9,5 | 9,5 |
| — | continuidade de números | 9,5 | 9,5 |

## B) Lado a lado

| contra | resultado |
|---|---|
| **v5 / v6 / v8 / kinetic_new** | Claramente melhor nas duas versões: abertura calma, cartas que matam, coleção, entradas, montagem rápida (agora com impacto também na Tirano), luta inteira com corvos densos, golpe com hit-stop e morte, e o final do Grimoire. |
| **11f** | Melhor: o trecho morto dos corvos sumiu (5,4 → 2,85 s), o golpe letal ganhou peso, a Tirano ganhou impacto nas trocas e as cartas saíram da frente da morte. Perde só no som do golpe que mata na jogada de cartas (−5 a −7 dB). |

## Recomendações (não seguram o PASS)

1. **Som da morte na jogada de cartas:** subir o impacto do −30 em +6 dB e/ou abrir um duck curto na música antes dele, como no golpe letal. Ou atrasar o corte para a Coleção em 0,1 a 0,15 s, só no áudio, com um J-cut, para a cauda não ser cortada.
2. **Golpe letal:** se o lead medir pela mediana da música antes do duck, falta ~1 dB na Tirano e ~3,5 dB no Rei para os 12 dB. Antecipar o duck em 0,3 s ou subir o impacto em +3 dB resolve.
3. **Tirano 40,710 s:** o impacto é o mais fraco das trocas (+3,6 dB). Um duck um pouco mais fundo da música nesse corte deixa o soco igual aos outros.
4. **Para o Daniel:** "SIX BOSSES." aparece sobre cinco salões, e falta decidir qual música vai na versão principal.

**Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.

===CORTE11G_PRONTO===
