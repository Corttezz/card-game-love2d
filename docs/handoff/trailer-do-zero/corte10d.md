# Corte 10d (trailer-do-zero)

_Diretora, 02/11/2026. Base: `revisao-grimoire-corte10c.md` (d857b4b0, Tirano 9,0 e Rei 8,7, Rei reprovado na sincronia). Só montagem e overlay sobre a tomada `zero_carrion_c10c` do 10c. Nenhuma tomada nova; faixa, textos, salões, fecho e o cartão "42 CREATURES." sem mudança; escala 1,00. Pastas novas `zero10d` / `zero10d_rei`._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

## Arquivos
- `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte10d_1080p.mp4` e `grimoire_zero_corte10d_720p.mp4` (Tirano)
- `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte10d_rei_720p.mp4` (Rei)
- Pipeline: `corte/edl10d.py` (importa `edl10c.py`), `provas10d.py`, `tab10d.py` (onsets medidos no **`stem_music.wav` da própria versão**), `med10d.py`.

## Correções

| # | pedido | o que foi feito | medida |
|---|---|---|---|
| 1 | **Rei: cortes da luta no tempo forte** (bloqueava) | `k_inimigo` 41,379 → **41,993**; `k_vida` 42,656 → **43,270**; `k_letal` 47,672 → **48,274**; `k_letal_b` 48,926 → **49,528** s. São os onsets do stem do Rei junto dos tempos fortes que a revisão mediu (41,96 / 43,24 / 48,25 / 49,50). | Desvio **0,0 quadro** nos quatro (onset de 12×, 23×, 31× e 37× a mediana); a batida fica a ≤ 0,7 q. O guerreiro ganhou 0,6 s, e o −33 e a contagem até 30 terminam antes do corte (folha `rei/p1_barra_rei_*`). |
| 2 | número do golpe igual ao do jogo | Overlay **"33"** = o "−33" do Immolate no mesmo quadro. | quadro de 50,36 s |
| 3 | "Murder of Crows" grande ~0,8 s | Hit-stop de 42 quadros no quadro do nome grande (tomada 30,433 s). | Nome grande de ~43,0 a 43,8 s (Tirano) e ~42,5 a 43,3 s (Rei), **~0,8 s**, antes do primeiro corvo |
| 4 | faixa "COMBO! Volley +6" em relance | O guerreiro agora vai até 42,343 s (Tirano) / 41,993 s (Rei): a faixa entra, fica inteira e legível ~0,8 s e sai antes do corte. | folhas `p3_luta_*` |
| 5 | plano dos corvos 4,9 s | **Tirano:** `k_vida` cortado em dois, 43,794 a 47,498 s mais `k_vida_b` 47,498 a 48,067 s. O corte cai no patamar herói 9 / Rei 30, antes do tique de fogo, e tira os ~0,35 s parados depois do último corvo. A queda 41 → 9 fica toda na tela. **Rei:** o plano ficou em 5,0 s, porque o corte no tempo forte (pedido 1) já fixa as duas pontas; encurtar exigiria tirar um corvo. | folhas `p1_vida_hero_*`: nenhum número muda num corte |
| 6 | margem do golpe da Tirano ≥ 2 dB | Mix sem mudança de nível. | Tirano **+2,1 dB**; Rei +2,8 dB |

## Conferências
- **Vida:** herói 41 → 9 só com corvos (painel vermelho); Rei 102 → −39 → −33 → 30 → −9 → 21 → 33 no golpe. Nenhum número muda num corte nas duas versões (folhas a 10 quadros/s em `corte10d_provas\<versão>\`).
- **Sem regressão:** segundos 0 a 36 idênticos ao 10c (`p0_diferenca_corte10c_x_corte10d_por_segundo.txt`); escala igual ao 10c (`escala_filme_inteiro.txt`).
- **Fecho:** GRIMOIRE 58,850 / WISHLIST 61,983 s, WISHLIST 2,517 s nas duas (`p2_tempos_logo.json`).
- **Quadros escuros:** 0 nos 3870 quadros de cada versão.
- **Som:**
  - Tirano: −14,1 LUFS / −1,2 dBTP, LRA 6,9.
  - Rei: −14,1 LUFS / −1,3 dBTP, LRA 7,4.
- **Sincronia da Tirano:** todos os cortes a ≤ 0,1 quadro de um onset do stem, exceto a queda (−2,3 q), como antes.

## Aprovação e entrega
- Revisora: **APROVADO** nas duas versões, Tirano 9,3 e Rei 9,3 (`revisao-corte10d.md`, commit 3b67ae84). Sincronia do Rei 9,5.
- Copiados, iguais byte a byte aos masters: `C:\Users\corte\grokbot_entrega\corte10d_720p.mp4` e `corte10d_rei_720p.mp4`.
- Riscos registrados sem bloquear: margem do golpe da Tirano +2,1 dB; no Rei, o corte de 38,895 s (saída do nome) em tempo fraco desde o 10b; salões e ritmo com 8,5 do Grimoire no 10c, sem mudança.
