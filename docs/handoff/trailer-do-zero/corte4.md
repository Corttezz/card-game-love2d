# Corte 4 (trailer-do-zero)

_Diretora, 01/11/2026. Base: `instrucao-grimoire-corte4.md` (zoom em degraus inteiros e progressivos + 7 correções), `revisao-corte3.md` (versão Tirano e variante do Rei). **Sem 4K, sem Steam, sem push, sem save real. Nenhuma troca de faixa, texto ou salão.** NÃO MEXER mantido: quadro 0/pôster, gancho, textos exatos, golpe com hit-stop/flash/tremor, logo + CTA._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

Pipeline: `corte/edl4.py` (`TDZ_MUSIC=tirano|rei`), `build_video.py`, `crt_pass.py`, `mix2.py`, `mux2.py`, `medir2.py` (com `TDZ_EDL=edl4`). Cortes 1 a 3 intactos.

## Versão principal (Tirano)

**Arquivos:** `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte4_1080p.mp4` e `..._corte4_720p.mp4` (64,5 s, 60 fps).

### Zoom (ponto 4, resposta do Grimoire): degraus inteiros, progressivos, sem recuo
Sequência da virada (41,67 a 55,96 s), só ×2 e ×3, sem ×1 no meio:

| t (s) | plano | escala | centro de interesse |
|---|---|---|---|
| 41,67 | mão do guerreiro | ×2 | embaixo, centro |
| 44,08 | o Rei anuncia "Murder of Crows" (intent 4×4, órbita) | ×2 | centro |
| 45,48 | Rei (chamas à direita) + **painel de vida** embaixo à esquerda, corvos mergulhando: **25 → 21 → 17** | ×2 | painel de vida (canto inferior esquerdo) |
| 46,83 | **painel de vida a ×3**, mesma posição: **17 → 13 → 9**, "Weak" | ×3 | o mesmo canto, só mais perto |
| 48,27 | **mão + Rei + painel juntos** (opção do Grimoire "mão e painel juntos em ×2"): o painel sobe de 29 para **"48 LETHAL"**, Play Cards apertado | ×2 | painel à direita, mão embaixo |
| 52,83 | golpe | ×2 + hit-stop | Rei |

Espólio a ×2 com as **duas cartas inteiras** (Poison Dart e a rara Rain of Blades), sem lasca de outra carta; "145 LIVING CARDS." numa **linha livre** entre a base das cartas e os rótulos AFFINITY/RARE FIND, longe dos selos NEW (que ficam no topo). Recortes inteiros sempre (×2 = 2 px, ×3 = 3 px da captura por pixel de tela; a carta a 2 px por pixel lógico).

### As 7 correções

| # | correção | o que foi feito |
|---|---|---|
| 1 | virada | Sequência acima. A tomada `zero_carrion` foi regravada no corte 3 com a Revoada encenada (modo deus desligado nos golpes de corvo); a vida cai de 25 a 9 na tela. Nada de mão ×3 cortada, nada de LETHAL sozinho sobre a parede: o LETHAL aparece com a mão e o Rei. |
| 2 | golpe da mesma jogada, número = LETHAL | O golpe (52,83 s) e a morte vêm da **mesma tomada e da mesma jogada** do LETHAL (a jogada de 49,77 s da tomada); o número congelado é **48**, igual ao painel, e o banner COMBO é o do mesmo turno. |
| 3 | portão com som | `castleGateOpen` no **início do plano do portão** (29,95 s), **+6 dB** de propósito, com a cabeça aparada para começar junto com a imagem. O portão aparece em dois degraus inteiros no mesmo centro: ×1 abrindo (1,12 s) → ×2 no portão (1,48 s). |
| 4 | e5/e6 ≤ 1,5 s ou em ação | Mãe-esporo **1,33 s** (emergindo); anjo **1,53 s descendo** (em ação) → **×2 no pouso** do anjo (1,71 s, em ação). Nenhum plano de criatura parada. |
| 5 | espólio | ×2 com as cartas inteiras e o texto numa linha livre (acima). |
| 6 | mix | **Coringa:** música −18,3 / SFX −13,1 (**5,2 dB abaixo**, dentro de 4 a 6). **Salão do Tirano:** música −15,3 / efeito −27,2 (a música lidera por 12 dB); o segundo anterior foi baixado e o acento **sobe +3,1 dB no corte** (mix −11,3 → −8,2). |
| 7 | tom de sala na entrada do Rei | O trono vazio (32,55–34,71 s) agora tem **tom de sala** (`boss_hold_ambience` em loop): **−46 a −51 dBFS** (RMS em 100 ms, média ≈ −48), em vez de silêncio digital. Zero música. |

### Medidas (`medir2.py`)
- −14,2 LUFS, −1,1 dBFS de pico, LRA 9,7 LU.
- Silêncio da entrada (curto prazo por segundo): −13,4 / −16,0 / −25,4 / **−31,2** / −27,0 / −24,5; o groove antes da porta está em −12,5.
- Pico (golpe → morte): −8,7, **+3,1 dB** acima de qualquer outro trecho.
- Portão 30,1 s; pouso 38,88 s; revelação 39,48 s e 57,19 s (uma vez cada); nenhum clima externo dentro do castelo; antes da música só o liga-TV.
- Quadro 0 = pôster (Espantalho inteiro). Lift reforçado no escuro do salão (+22, 60 quadros).

## Variante (Rei-Carniça), 720p

_Em render. Esta seção será preenchida assim que `grimoire_zero_corte4_rei_720p.mp4` sair._ Além das 7 correções (mesmos planos), a variante traz o que a revisora pediu em `revisao-corte3.md` (18:13): fecho ≥ 2 dB abaixo do pico (música do logo a −2/−4), música do coringa 4 a 6 dB abaixo do SFX, a gárgula e o salão do Tirano no ataque real mais forte da faixa do Rei (janela de busca de ±0,8 s no áudio medido) e LRA mais alto (a volta do drop sobe +3 dB em vez de +6).
