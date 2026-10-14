---
name: code_notes/tools/test_scribe_dice.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_scribe_dice.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_scribe_dice.lua`

Origem: `tools/test_scribe_dice.lua` em `7dbdb60d` (2 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local TK = require("tools.testkit")`)

> tools/test_scribe_dice.lua
> Trava do mini-jogo DADOS DO ESCRIBA (Out/2026):
> 1. odds CONTADAS batem com a regra e o EV fica justo (0,9..1,1) —
> se alguém mexer no pagamento e a aposta virar mina ou imposto, vermelho;
> 2. as fichas escalam por ato e são pares (pagamento inteiro);
> 3. UMA jogada por loja: a segunda é recusada, e a próxima loja libera;
> 4. ouro cobrado/pago certo; mesma seed → mesmos dados (stream "shop");
> 5. o resultado SOBREVIVE a salvar-e-carregar (anti save-scum): a mesa
> volta usada e com a mesma soma, sem novo sorteio;
> 6. layout da tela sem sobreposição em 6 tamanhos, e a tela abre/rola/
> fecha headless sem erro.
> love . test_one test_scribe_dice

## L133 (em `sizes`, junto a `local I18n = require("src.i18n.I18n")`)

> O texto nao pode mentir sobre os numeros da regra (todos os idiomas).

