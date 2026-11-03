# Revisão independente: corte 11g, revisão 2 (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivos (regravados): `grimoire_trailer_c11g_720p.mp4` (Tirano, 67,4 s) e `grimoire_trailer_c11g_rei_720p.mp4` (Rei, 68,4 s). Base: minha `revisao-corte11g.md` (f1fb98a1) e `corte11g.md`, seção "Revision 2" (6c1ef487)._

_O que medi:_
- _envelope de 100 ms do mix 720p, em passos de 20 ms;_
- _detecção de cortes de 15 a 65 s, para conferir que a imagem não mudou;_
- _luma por quadro, `ebur128` com true peak, bitrate._

_Scripts e saídas em `C:\Users\corte\AppData\Local\Temp\rev11g2\`. Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: PASS nas duas versões

| versão | nota |
|---|---|
| Tirano | **9,4** |
| Rei | **9,4** |

## Golpe letal: margem contra a música de antes

O golpe é o pico de 100 ms em torno do impacto (Tirano 57,283 s, Rei 58,217 s). Medi contra duas janelas:
- **A)** 2,5 a 0,5 s antes do golpe, a mesma da minha revisão anterior;
- **B)** a "música normal" antes do turno LETAL começar a ceder: os últimos 1,7 s dos corvos (Tirano 53,85 a 55,55 s; Rei 54,67 a 56,37 s).

| | Tirano rev 1 | **Tirano rev 2** | Rei rev 1 | **Rei rev 2** |
|---|---|---|---|---|
| pico do golpe | −4,9 | −4,7 | −4,9 | −4,5 |
| A: contra a mediana | +11,1 | **+19,0** | +8,5 | **+13,7** |
| A: contra o pico | +5,4 | **+5,0** | +3,3 | **+5,0** |
| B: contra a mediana dos corvos | — | **+7,1** | — | **+9,5** |
| B: contra o pico dos corvos | — | +3,2 | — | +5,0 |

Pela minha régua da revisão 1 (janela A, mediana), as duas versões passam dos **12 dB**: +19,0 e +13,7. Contra o pico dos corvos, a música mais alta do clímax, o golpe fica 3 a 5 dB acima. É o limite físico, já que o golpe está no teto e a cama dos corvos é forte. Isso continua dando o desenho certo: os corvos no topo, a música cedendo no turno LETAL e o golpe como o ponto mais alto do filme.

## Golpe que mata nas cartas

| | Tirano rev 1 | **Tirano rev 2** | Rei rev 1 | **Rei rev 2** |
|---|---|---|---|---|
| pico do golpe | −22,9 | **−6,0** | −18,5 | **−5,6** |
| contra a mediana de 1,5 a 0,3 s antes | −12,2 | **+10,2** | −3,3 | **+9,1** |
| contra o pico do mesmo trecho | | +5,1 | | +3,9 |

O impacto agora dura ~0,2 s em −6/−7 dB (curva: −15 → −9 → −7 → −7 → −7 → −10 → −12) e só depois cai para a Coleção. O risco da revisão 1 está resolvido.

## Sem regressão

- **Imagem:** os cortes detectados de 15 a 65 s são **idênticos** aos da revisão 1 nas duas versões (mesmos tempos e mesmas amplitudes), e a duração é a mesma. A continuidade dos números que conferi quadro a quadro na revisão 1 continua valendo.
- **Quadros < 5% de luma:** 136 (Tirano) e 139 (Rei), só na TV ligando, no fundo do logo e no rabo final.
- **Loudness:** Tirano **−14,1 LUFS**, LRA 10,2; Rei **−14,0 LUFS**, LRA 8,8.
- **Bitrate 720p:** 14,0 / 14,1 Mb/s.

**Ressalva técnica (não segura a nota):** o true peak está em **−0,9 dBTP** (Tirano) e **−0,6 dBTP** (Rei), acima do −1,0 que costumo usar de teto para a Steam e o YouTube. A recodificação em AAC pode clipar 0,5 dB. Recomendo um limitador de true peak a −1,0 dBTP, que mexe menos de 0,5 dB no golpe.

## A) Notas por ponto do feedback

| # | ponto | Tirano | Rei |
|---|---|---|---|
| 1 | textos | 9 | 9 |
| 2 | abertura dos seis atos | 9,5 | 9,5 |
| 3 | qualidade de imagem | 9,5 | 9,5 |
| 4 | chefes trocando no ritmo | 9 | 9,5 |
| 5 | sensação épica | 9,5 | 9,5 |
| 6 | jogar cartas satisfatório | **9,5** (morte com impacto) | **9,5** |
| 7 | coleção | 9,5 | 9,5 |
| 8 | entradas, Espantalho | 9 | 9 |
| 9 | final do Grimoire | 10 | 10 |
| 10 | geral contra os anteriores | 9,5 | 9,5 |
| — | continuidade de números | 9,5 | 9,5 |

## B) Lado a lado

Claramente melhor que o v5, o v6, o v8 e o kinetic_new (mesmo quadro da revisão 1). Contra o 11f e a rev 1 do 11g, ganha no som dos dois golpes de morte sem perder nada na imagem.

## Para o Daniel

- "SIX BOSSES." aparece sobre cinco salões.
- Falta decidir qual música vai na versão principal.
- Os salões são vídeo de IA (Higgsfield).

**Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.

===CORTE11G_PRONTO===
