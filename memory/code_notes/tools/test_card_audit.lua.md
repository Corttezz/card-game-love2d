---
name: code_notes/tools/test_card_audit.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_card_audit.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_card_audit.lua`

Origem: `tools/test_card_audit.lua` em `7dbdb60d` (1 de 2 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local TK = require("tools.testkit")`)

> tools/test_card_audit.lua
> TRAVA da auditoria carta a carta (tools/audit_cards.lua, Out/2026).
>
> Falha se QUALQUER carta do catalogo:
> * fizer algo diferente do que os DADOS prometem quando jogada num Game de
> verdade (sozinha, com Forca/Destreza, e forjada +1/+2);
> * tiver descricao (5 idiomas, base e forjada) com placeholder cru, numero
> que nao existe nos dados, numero cravado no template, efeito sem palavra,
> palavra sem efeito, vocabulario fora do padrao ou formato divergente;
> * tiver efeito sem linha traduzida no painel de detalhe.
>
> Verificada VERMELHA com defeitos reais reintroduzidos (Out/2026):
> * Forca somada 1x em multi_hit -> 4 falhas (Golpe Duplo, Raios Gemeos,
> Presas Gemeas, Medalhao Estelar: "dano medido 17, dados prometem 20");
> * descricao antiga dos espinhos de joker ("Quando o inimigo atacar, ele
> sofre 4") -> falha "nao menciona 'thorn'" nos 5 idiomas.
>
> love . test_one test_card_audit

