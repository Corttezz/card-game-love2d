# Resposta à revisão das ferramentas (rodada 1)

_Diretora, 01/11/2026. Provas novas em `ferramentas.md` §5; imagens e vídeos no scratchpad da diretora (`...\scratchpad\crop\`). Worktree `card-game-trailer-zero`, commit `7997aaed`._

| # | ponto | resposta | prova |
|---|---|---|---|
| 1 | pixel irregular já no ×2 | **Aceito e resolvido no gravador.** `TRAILER_CARD_PX=2` (carta a 2 px por pixel lógico, sem zoom de hover, sem tilt nem rotação). Corridas ímpares na arte em repouso: 55% → **0,1%**. Limite declarado: carta em movimento ou no juice ainda tem 10%; close só de carta parada. | §5.1, `full2_13.png`, `zoom2.png` |
| 2 | ×3 reprovado | **Aceito: o ×3 sai.** Com a carta a 2 px, o ×2 já dá 4 px por pixel lógico (carta a 53% da altura). | §5.2 |
| 3 | teste de câmera | **Feito.** `teste_camera.mp4`. 15 px/s pula; 60 e 120 px/s ficam uniformes (2 e 4 px por quadro) se a posição vier do número do quadro (com `floor(60*t)` dava 2/0/4). Regra escrita. | §5.3 |
| 4 | CRT de pós = CRT do jogo | **Feito com o próprio `crt.glsl`** via `CRTShader` (`tools/trailer_crt_post.lua`). No mesmo quadro: diferença média 2,4/255 onde o conteúdo é igual, 0,14 na moldura. | §5.4, `lado_a_lado.png`, `diff_x8.png` |
| 5 | liga-TV | **Feito.** Mesmo `powerOn(1.8)`; as 10 fases batem quadro a quadro com a tomada `poweron` do jogo. | §5.5, `tv_comparacao.png` |
| 6 | integração do Higgsfield | **Método e teste feitos.** Grade 400×225 + LAB igualado + paleta do salão real (48 cores) + vizinho mais próximo + CRT. Luma 67 → 43 (real 42,5), saturação 138 → 119 (real 98; ajuste no corte). Entra como plano fechado do trono depois do plano aberto real. | §5.6, `hall_comparacao.png` |
| 7 | HUD | Plano ×1 com HUD antes de 5 s, recortado da mesma tomada. | §5.7 |
| 8 | tooltip | `TRAILER_TOOLTIP=0` no gravador; escolha por plano. | §5.8 |
| 9 | luta encenada | Lista chamada → estado → prova para LETAL, Geada e Correntes, com dono (diretora, etapa 4). | §5.9 |
