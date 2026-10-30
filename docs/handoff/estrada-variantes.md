# Handoff: variantes da estrada (frente encerrada)

## Frente

- Subagente `estrada-variantes` ("Road variants per act (mockups)"), da sessão líder do Grimoire `f04fd583`.
- Entregou as 18 variantes no commit `9913b64c` (23/Out/2026, 13:20).
- A frente seguinte, `estrada-final`, fechou o assunto no commit `3b466b0f` (23/Out/2026, 16:02). O dono escolheu 1A, 2A, 3A, 4A, 5B e 6A, e essas viraram a estrada padrão. `engine/RoadVariants.lua`, `CARDGAME_ROAD` e as outras 12 variantes saíram do jogo. Detalhes em `memory/roadwear_engine.md`.
- Não há sessão ativa dona deste trabalho. A frente não está no `orq.ps1 list` de 30/Out/2026.

## Ferramentas que ficaram fora do git (estacionadas em 30/Out/2026)

As duas ferramentas da frente nunca foram commitadas e ficaram soltas em `tools/` na pasta da main:

| Arquivo | SHA-256 |
|---|---|
| `perf_estrada_variantes.lua` | `d65064e46cbd44ef77e15b53795dcdd2a35e8a5174d3ce21b0ed0632ca1e345d` |
| `screenshot_estrada_variantes.lua` | `d87b4eddbc123da6e262f5efea29b74280f2b81dc574d987af9a4690660edadc` |

- **Por que saíram:** as duas têm `print` fora da lista de ferramentas de resultado. Por isso, soltas em `tools/`, derrubavam `test_no_comments_no_prints` na suíte completa da main.
- **Elas não rodam mais:** medem as variantes que `3b466b0f` removeu.
- **Para onde foram:** `E:\dev\projects\_parking\card-game\`. O conteúdo não mudou (mesmo hash antes e depois) e a data original do arquivo foi mantida.
- **Outra cópia:** há uma cópia idêntica no worktree do subagente, em `.claude/worktrees/agent-ae2ecb23da75ab2f8/tools/`.
- **Os comandos antigos:** continuam descritos em `tools/preview_out/estrada_variantes/LEIA.md` ("Desempenho" e os comandos de captura).

Para usar de novo, a ferramenta tem de voltar a `tools/` sem `print` de ruído. Se ela imprimir resultado, tem de entrar em `TOOL_RESULT_PRINTERS` de `tools/test_no_comments_no_prints.lua`. E tem de ser adaptada à estrada atual, que está em `engine/RoadTiles.lua`.
