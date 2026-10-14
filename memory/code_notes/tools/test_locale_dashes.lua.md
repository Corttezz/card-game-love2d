---
name: code_notes/tools/test_locale_dashes.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_locale_dashes.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_locale_dashes.lua`

Origem: `tools/test_locale_dashes.lua` em `7dbdb60d` (1 de 1 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local M = {}`)

> tools/test_locale_dashes.lua
> Sem travessão nos textos do jogo (Out/2026).
>
> Pedido do dono: "tira todos os travessões das falas do corvo, grita IA".
> Vale pra TODO texto que o jogador lê: o travessão (—), o meia-risca (–) e o
> hífen solto usado como travessão (" - ") viraram ponto, vírgula, dois-
> pontos ou reticências, com a frase reescrita. Palavra composta com hífen
> ("pós-jogo", "zlib-Lizenz") continua valendo: só o hífen ENTRE ESPAÇOS cai.
> Faixa de número se escreve por extenso ("2 a 6", "2 to 6").
>
> Varre as tabelas CARREGADAS (sub-locales entram pelo require do
> principal), então comentário de arquivo não conta.
>
> Roda: love . test_one test_locale_dashes

