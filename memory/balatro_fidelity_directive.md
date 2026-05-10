---
name: Diretriz Balatro Fidelity
description: ⚠️ DIRETRIZ FORTE — UI/UX/animações sempre seguem Balatro source. Não inventar "minimal viable". Levantada após Fase 6 do refactor entregar implementação rasa.
type: feedback
---

# ⚠️ DIRETRIZ: Balatro source é o blueprint, não inspiração vaga

**Histórico:** o refactor Balatro Fases 0-6 (Abril/2026) entregou os sistemas de fundo
(shaders próprios, ShopSystem com modos, BoosterPackSystem, PackOpenScreen, FloatingText,
juice_up, ScreenShake jiggle) com smoke tests verdes — mas o **layout visual** ficou
genérico. Usuário rejeitou: "ficou muito tosco, nada organizado, parece o que estava
antes". Razão: implementei animações superficiais (slide-in 0.43s, materialize cascade)
sem reformular as **telas em si** seguindo o blueprint do Balatro source.

**Source de referência (sempre consultar antes de implementar UI):** `/home/cortez/projects/balatro-source/`

## Regra dura

Antes de criar/refatorar qualquer tela (loja, pack opening, recompensa, mapa, blind
select, scoring, etc.), **abrir o arquivo correspondente no Balatro e copiar a
estrutura de UIBox**. Não inventar layout próprio "que funciona". Não usar backdrop
escuro genérico. Não centralizar em arco "porque parece bonito". O Balatro tem
decisões intencionais — siga-as.

**Arquivos-chave do Balatro pra UI** (paths relativos a `/home/cortez/projects/balatro-source/`):
- `functions/UI_definitions.lua` — todos os UIBoxes (shop, packs, hud, run info, blind, etc.)
- `functions/button_callbacks.lua` — handlers de botão e transições de estado
- `card.lua` — animações (`start_dissolve`, `start_materialize`, `explode`, `flip`)
- `engine/event.lua` + `engine/event_manager.lua` — fila temporal
- `engine/moveable.lua` — T/VT damping (já portado pra `engine/Moveable.lua` na Fase 1)
- `engine/ui.lua` + `engine/uibox.lua` — sistema de UI declarativo

**Trechos canônicos pra cada cena (cite linhas ao implementar):**
- Pack opening Arcana: `functions/UI_definitions.lua:1629-1673`
- Pack opening Spectral: `:1675-1719`
- Pack opening Standard: `:1721-1765`
- Pack opening Buffoon: `:1767-1811`
- Pack opening Celestial: `:1813-1857`
- Shop UI: `:637-840`
- Round eval (scoring): grep por `round_eval` em `state_events.lua`
- Blind select: grep por `blind_select` em `UI_definitions.lua`

## Características distintivas do Balatro que **não estavam** na minha implementação F5/F6

1. **Pack opening NÃO tem backdrop escuro semitransparente.** O pack substitui a shop:
   a shop UIBox desliza pra baixo via `alignment.offset.y = G.ROOM.T.y + 29` (some
   pra fora) e o pack UIBox aparece centralizado no espaço onde a shop estava. Quando
   fecha, shop sobe de volta.

2. **Cards do pack ficam em CardArea LINEAR** (não em arco), com card_limit = pack_size,
   highlight_limit = 1. CardArea já lida com layout, hover, drag.

3. **Texto do pack usa `DynaText`** com `rotate=true, bump=true, pop_in`. Cada letra
   tem rotação suave alternada (idle wobble) e entra com pop bouncing. Eu fiz só
   um `print` simples com pulse — totalmente errado.

4. **"Choose N" mostra ref_table dinâmico** — `{ref_table = G.GAME, ref_value = 'pack_choices'}`.
   O DynaText auto-update quando o número muda. Não é label estático.

5. **Skip button fica em COLUMN à direita**, não no rodapé centralizado. Tem `minw=1.8,
   minh=1.2, r=0.15, colour=G.C.GREY` — visual cinza com cantos arredondados.

6. **Pack que está sendo aberto é o BoosterCard original** (com booster shader/sleeve
   art) que faz `card:explode()` no centro antes dos cards spawnarem. Eu não
   tinha sequer um sprite de pack — só "abria" na shop sem cinematic real.

7. **Cards entram com `start_materialize` partindo da posição do pack explodido**
   (não do nada). O `card.T.x = self.T.x; card.T.y = self.T.y` é setado antes do
   materialize pra que voem da posição da explosão.

## Diretriz pra próximas iterações

- **Sempre que tocar numa tela**: abrir Balatro source, ler UIBox correspondente,
  reproduzir estrutura de nós (rows, columns, padding, alignment). Pode adaptar
  estética (paleta sépia em vez de cassino) mas não a ARQUITETURA do layout.
- **Animações**: usar T/VT existente em `engine/Moveable.lua`. Não bater valor
  diretamente (sem `obj.scale = 1.5` direto — usa `obj.T.scale = 1.5; updateTVT(obj, dt)`).
- **DynaText**: NÃO TEMOS PORTADO. Item pendente — see known_gaps.
- **Pack sleeve art**: UI precisa de sprite real do pack envolto/lacrado (Standard
  Pack visualmente diferente de Buffoon, etc.) — gerar via PixelLab MCP. Queue
  preparado em `memory/pixellab_queue_packs.md`.

## How to apply

Quando o usuário pedir "implementa X tela", primeira ação: `grep -rn "create_UIBox_X"
/home/cortez/projects/balatro-source/`. Se achar, ler 30+ linhas e estruturar o
componente Lua com a MESMA hierarquia de containers. Se NÃO achar, perguntar ao
usuário antes de inventar layout.

**Why:** usuário valoriza polimento Balatro-grade (foi o pedido original do refactor).
Implementação rasa custa retrabalho — a ordem certa é planejar olhando o source,
implementar, validar visualmente. Smoke tests verdes não substituem `love .` rodando
e o jogo parecer com Balatro.

## Lições aprendidas — F10 (loja compacta Apr/27 2026)

3 erros recorrentes que surgiram repetidamente até serem resolvidos. Documentados aqui pra futuros refactors **não cometerem de novo**:

### 1. Z-order de tooltips — segunda pass sempre

**Erro:** renderizar tooltip (hover info) DENTRO do `obj:draw()`. Quando outros objects são desenhados depois no loop da scene, eles ficam visualmente em cima do tooltip.

**Pattern correto:** scene/screen tem **duas passes**:
1. World pass: desenha bg, panels, cards, buttons
2. Overlay pass (após `pop`/após tudo): tooltip de objects hovered

Em CardRewardScreen.lua F10.2, o tooltip do hover de carta foi extraído pra `_drawCardTooltipOverlay(cardInstance)` chamado DEPOIS de tudo, garantindo Z-order correto.

**Quando aplicar:** sempre que hover-tooltip pode ser ocluído por outros elementos da tela. Card.lua mantém o render inline em modos não-reward (mão durante batalha — não tem outros elementos sobrepostos).

### 2. Containers visíveis sempre — não "slots flutuantes"

**Erro:** posicionar slots (cards, buttons, vouchers) flutuando no espaço da cena com gaps grandes (18-22% do cardW). Resultado parece "items soltos pela tela", não menu organizado.

**Pattern Balatro (UI_definitions.lua:637-740):**
- Painel principal com `bg = BOSS_MAIN`, `padding = 0.1`, `emboss = 0.05`, `r = 0.1`
- Subcontainers (`bg = L_BLACK`, `padding = 0.15-0.2`, `r = 0.2`, `emboss = 0.05`) AGRUPANDO os slots
- Slots dentro do subcontainer com **spacing pequeno** (Balatro usa `1.02 * CARD_W` pra cards encostados)
- Title bar DENTRO do painel principal, não solto na cena
- Buttons em column dedicada com bg próprio (não free-floating)

**Implementação Lua:** `_drawPanel(x, y, w, h, depth)` helper desenha bg + dual-border + emboss. `depth = "main"` (BOSS_MAIN dourado) ou `"inner"` (L_BLACK simples). Reusar em todas as scenes.

### 3. Bordas/halos animados — usar com parcimônia

**Erro:** rarity border pulsante atrás de TODAS as cartas (animação contínua sin-based) — efeito "festa de Natal" que polui visualmente.

**Pattern:** halo/border especial só pra **eventos pontuais** (juice_up momento, "card just bought"). Idle = sem animação.

Se precisa indicar raridade visualmente: usar **detalhe sutil no CardFrame** (cor da borda interna, gemstone na lapela) — não animação fullscreen.

### Como evitar repetir esses erros

Antes de implementar UI nova, procure:
- `grep "create_UIBox_X" /home/cortez/projects/balatro-source/` — se Balatro tem essa tela, copiar hierarquia
- `grep "_drawPanel\|_drawTitleBar" /home/cortez/projects/card-game-love2d/components/` — reusar helpers
- `grep "drawCardTooltipOverlay\|2nd pass" /home/cortez/projects/card-game-love2d/` — pattern de Z-order
- Sempre rodar `tools/screenshot_<scene>.lua` ANTES de marcar como pronto

## Pipeline de validação visual (auto-screenshot)

Smoke tests Lua validam lógica mas não layout. Pra validar UI, tem pipeline pronto:

1. Criar `tools/screenshot_<scene>.lua` que: setup minimal (loaders + game state) →
   simula N frames de update (ex: avança até `t=2.4s` rodando `update(1/60)` em loop) →
   render frame via draw calls explícitos → `love.graphics.captureScreenshot(callback)` →
   callback salva PNG no save dir e chama `love.event.quit()`.
2. Wirar em `main.lua`: `if loveArgs[1] == "screenshot_<scene>" then ... end`
3. Rodar: `love . screenshot_<scene>` — gera PNG em `~/.local/share/love/card-game/<name>.png`
4. **Ler PNG via tool Read** — funciona como image input, dá pra ver visualmente.

**Exemplos vivos:**
- `tools/screenshot_packopen.lua` — captura 5 frames da timeline de pack opening
  (sleeve appearing → explode → cards flying → text entered → idle ready)
- `tools/screenshot_gameplay.lua` — battle do ato 1
- `tools/screenshot_mapscreen.lua` — escolha de nó

**Regra:** após qualquer mudança visual significativa (layout, animação, shader),
gerar screenshot do estado-chave e ler com Read tool. Se ficou tosco, ITERAR antes
de marcar completo. Nunca confiar só em "o código tá certo" — ver com os olhos.

## PixelLab quando precisar de arte

Se o MCP `mcp__pixellab__*` não aparecer no ToolSearch, **não desistir**. O endpoint
HTTP responde via curl com o token em `~/.claude.json`. Ver `pixellab_queue_packs.md`
seção "Bypass HTTP" — script `tools/pixellab_generate_packs.py` é o blueprint
reutilizável (Python stdlib, sem deps).
