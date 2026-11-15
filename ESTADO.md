# ESTADO: chefe do ato 6, Donzela do Astrolábio (branch boss6)

## Pedido
Daniel escolheu a opção B da v2 ("Donzela do Astrolábio"). Construir a chefe completa do ato 6 (id interno continua `eclipse_queen`): anéis legíveis (grossos/duplos, borda clara), ligação ao ato 6 (âmbar, sol eclipsado como coroa e núcleo, trigo/outono na arena), 4 fases visíveis nela e na arena (Crepúsculo, Totalidade, Coroa, Anel de Diamante), números do CONCEITO v2 (HP 1020, golpe 29→33, uma regra nova por fase, picos avisados ≤ ~59), música de ~128 s com um loop por fase no mesmo arquivo, SFX, entrada, transições, morte → alvorada → fim (VICTORY, run_victory, UnlockReveal intactos), balance com alvo de 9–12% das runs mortas por ela, testes, vídeo.
Conceitos: `C:\Users\corte\OpenBot\Shared\runemoire-boss6\v2\CONCEITO.md`. Entrega: `...\runemoire-boss6\final\`.

## Regras
Worktree `E:\dev\projects\card-game-boss6` (branch `boss6` a partir de main 3a122ce1). Commits como Daniel Cortez, sem merge/push. Lua sem comentários e sem print. Headless: `lovec . test_one <nome>` com `CARDGAME_IDENTITY=card-game-test-boss6`, `TOOL_WINDOW=1280x720`; um lovec por vez. PixelLab: teto de +157 gerações (saldo 337 no início da construção). ElevenLabs: ≤ ~2,1 min de música.

## Decisões
- Arte: base `create_image_pro` 160 px com referência na opção B v2 (anéis duplos ~4 px com borda creme); candidata 2. Fases 2–4 por referência (mesma pose). Fundo branco opaco do PixelLab limpo por preenchimento a partir da borda.
- Fases visíveis no corpo: troca de "pele" por fase (pasta `eclipse_queen/fase<N>/` com south + animações), sem mudar o id.
- Música: uma geração com composition_plan (5 seções); arquivo final com 4 regiões de loop em compassos inteiros (62,25 BPM), emendas cruzadas gravadas; a troca de fase faz crossfade para a região da fase seguinte mantendo a posição no compasso.

## Feito
- Kit `eclipse_queen` com 4 fases (Crepúsculo, Totalidade 75%, Coroa 50%, Anel de Diamante 25%), mecânica por fase (constelação de estrelas = runas; ciclo de labaredas = lua; carga revelada + Anel de Diamante 59), sem fúria genérica (`noEnrage`), fase atravessa vários limiares num golpe só.
- Pele por fase (`eclipse_queen/fase2..4`), transições t12/t23/t34, morte com dissolução; arena `castle_hall_6` (base do conceito) + fase2/3/4 + alvorada.
- Música única `boss-eclipse_queen.mp3` com 4 regiões de loop; MusicDirector troca de região na virada mantendo o compasso (`startAt`).
- Testes: `test_astrolabe_maiden` (novo), testes antigos da rainha atualizados.

## Saldos
- PixelLab: 337 antes; 227 depois das animações por fase (arena sem geração nova: base do conceito).
- ElevenLabs: 16.338 restantes antes; música 1.600; SFX ~84.

## Próximo
Instalar quadros (install.py), balance antes/depois, gravação da luta, prova dos anéis, suíte, commits, entrega.
