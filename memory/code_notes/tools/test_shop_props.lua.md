---
name: code_notes/tools/test_shop_props.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_shop_props.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_shop_props.lua`

Origem: `tools/test_shop_props.lua` em `7dbdb60d` (1 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local TK = require("tools.testkit")`)

> tools/test_shop_props.lua
> Trava dos PROPS VIVOS da loja (src/ui/shop/ShopProps.lua, F3 Out/2026):
> 1. nenhum asset ausente (fallback silencioso é proibido) e cada sheet
> tem o número de quadros do contrato;
> 2. lanterna: chama e nível de luz só assumem valores do catálogo (quadro
> 1..3, LEVELS), a poça anda em DEGRAUS inteiros perseguindo o hover a
> 4 passos/s, nunca interpola;
> 3. copo: estados idle/shake/rolled, rolled exige faces 1..6, syncRun lê
> a jogada da visita (ScribeDice.state) e volta a idle em nó novo;
> 4. mariposa agenda travessia entre 20 e 40 s, atravessa e some;
> 5. reducedMotion: chama/nível/poeira parados, copo sem chacoalho, a
> mariposa nunca voa — mas dados jogados e copo deitado CONTINUAM
> (informação não some);
> 6. fachada da cena (update/drawBack/drawLantern/drawDiceCup/drawFront)
> desenha num canvas sem erro e lê a run.
> love . test_one test_shop_props

