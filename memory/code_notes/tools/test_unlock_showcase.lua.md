---
name: code_notes/tools/test_unlock_showcase.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_unlock_showcase.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_unlock_showcase.lua`

Origem: `tools/test_unlock_showcase.lua` em `7dbdb60d` (2 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local TK = require("tools.testkit")`)

> tools/test_unlock_showcase.lua
> Revelações do menu (UnlockQueue + UnlockShowcase), pedido do dono:
> "igual ao Balatro: terminou a run e voltou pro menu, mostra tudo o que
> desbloqueou".
>
> Trava:
> 1. a fila nasce de uma run que libera várias coisas, na ordem de leitura
> (classe, nível de maestria + cartas do pacote, demais cartas, selo) e
> as conquistas entram quando acontecem;
> 2. a fila mora no PERFIL em disco (fechar o jogo antes de ver não perde);
> 3. o painel abre sozinho só no menu, mostra um por vez na ordem,
> Continuar (Enter / A / clique) avança e Pular tudo (Esc / B) esvazia;
> 4. o caminho REAL (UnlockSystem.onRunEnded) enche a fila;
> 5. layout em zonas válido e todo tipo de item tem texto nos 5 idiomas.
>
> love . test_one test_unlock_showcase

## L157-159 (em `saw`, junto a `do`)

> ===== 4b. A carta revelada e uma Card de verdade (dono, Out/2026) =====
> hover = sobe + tooltip ao lado; clique / botao direito / I / Enter
> com a carta em foco = inspecao da Colecao; Esc fecha SO a inspecao.

