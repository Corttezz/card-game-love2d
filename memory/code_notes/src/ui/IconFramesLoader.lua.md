---
name: code_notes/src/ui/IconFramesLoader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/IconFramesLoader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/IconFramesLoader.lua`

Origem: `src/ui/IconFramesLoader.lua` em `7dbdb60d` (8 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local IconFramesLoader = {}`)

> src/ui/IconFramesLoader.lua
> Carrega frames animados de ícones gerados via PixelLab (animate_object v3).
> Estrutura: assets/sprites/icons_anim/<name>/frame_NNN.png
> assets/sprites/icons_anim/<name>/meta.lua (opcional: return { fps = N })
> Pipeline de geração: tools/pixellab_animate_card_icons.py (queue/poll).
>
> Uso:
> local anim = IconFramesLoader.get("dagger")
> if anim then local frame = anim:frameAt(t) end

## L13-18 (em `IconFramesLoader`, junto a `local DEFAULT_ROOT = "assets/sprites/icons_anim"`)

> Raiz padrao (icones de carta). Outros consumidores passam a sua -- o
> voucher da loja usa "assets/sprites/vouchers_anim". Mesmo CONTRATO de
> pasta (frame_NNN.png + meta.lua opcional), mesma logica de cache e de
> ausencia: pasta que nao existe devolve nil e quem chama mostra o PNG
> estatico. Chaves de cache carregam a raiz pra que dois assets de mesmo
> nome em pastas diferentes nao se confundam.

## L65-66 (em `IconFramesLoader.getFrom`, junto a `local fps = 8`)

> fps default 8 (loop de 9 frames ≈ 1.1s — idle vivo mas não frenético).
> Override por animação via meta.lua no diretório dos frames.

## L91-95 (em `IconFramesLoader.get`, junto a `local firstCache = {}`)

> v10.6 (perf): SÓ o primeiro frame (frame_000) — barato o suficiente pro
> render ESTÁTICO da carta na instanciação (idle = frame 0, regra do dono).
> O set completo (get) fica pra quando a animação é realmente pedida
> (primeiro hover/inspeção). Sem isso, abrir a Coleção carregava ~9 PNGs
> e compunha a carta inteira ~9x pra CADA uma das 116 cartas = travada.

## L108 (em `IconFramesLoader.firstFrom`, junto a `local items = love.filesystem.getDirectoryItems(dir)`)

> primeiro frame_NNN em ordem (quase sempre frame_000.png)

## L131-135 (em `IconFramesLoader.first`, junto a `function IconFramesLoader.has(name)`)

> Perf (Out/2026, medido em tools/perf_collection): `has` chamava get(), que
> carrega o set INTEIRO (9 PNGs do disco). O CardAnimationLayer pergunta has()
> pra TODA carta desenhada, todo frame — então a primeira vez que uma carta
> entrava na tela (rolar a Coleção) custava 9 decodificações de PNG naquele
> frame. Existência só precisa do frame 0, que o render estático já carregou.

## L142-145 (em `IconFramesLoader.has`, junto a `local pending = {}`)

> Carga INCREMENTAL do set completo: decodifica no máximo `perCall` PNGs por
> chamada e devolve o handle só quando terminou (nil enquanto carrega). Quem
> monta animação sob demanda (CardFrame.liveImage) usa isto pra espalhar o
> custo de disco por vários frames em vez de engasgar um só.

## L182-183 (em `p`, junto a `if #p.frames == 0 then missCache[key] = true; return nil end`)

> Completo: delega pro get() normal só pra fps/meta + cache (os PNGs já
> decodificados entram direto, sem reler do disco).

