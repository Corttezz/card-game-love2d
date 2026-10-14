---
name: code_notes/src/ui/StatusPill.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/StatusPill.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/StatusPill.lua`

Origem: `src/ui/StatusPill.lua` em `7dbdb60d` (14 de 36 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/StatusPill.lua
> Componente visual único pra "pill" de status effect / buff / debuff.
> Usado tanto por EnemyHud (debuffs do inimigo) quanto PlayerBuffPills (buffs do jogador).
>
> Formato: círculo com halo colorido + fundo escuro + outlines + ícone central + contador.
> Comportamento: hover → StatusTooltip.show.
>
> Config única (STATUS_COLORS + STATUS_ICONS) vive aqui como source of truth.
> Callers passam opts pra ajustar tamanho, animação e regras de exibição de stacks.

## L19-21 (em `StatusPill`, junto a `StatusPill.COLORS = {`)

> ===== Tabelas canônicas (fonte única de verdade) =====
> Toda pill do jogo passa por aqui: quem não tem entrada nestas duas tabelas
> desenha cinza com a inicial e AVISA no console (ver warnOnce abaixo).

## L31-34 (em `focus`, junto a `thorn        = { 0.90, 0.50, 0.35 }, -- reflexo ao Bloquear (Barreira de Fogo & cia)`)

> Jul/2026 — estados que mudavam regras sem aparecer na tela:
> Cores escolhidas pra serem distinguíveis ENTRE SI na mesma row (a row do
> jogador chega a 8 pills): vermelho=Força, coral=Espinhos, magenta=Roubo
> de Vida, verde=Regeneração, carmim escuro=Sangria.

## L42-44 (em `enraged`, junto a `weak_self       = { 0.50, 0.45, 0.70 },`)

> Kit dos inimigos (Out/2026, src/data/enemies.lua): debuffs NO JOGADOR
> (sufixo _self: o tooltip fala com o jogador, "seus ataques...") e
> estados próprios do chefe.

## L57-59 (em `StatusPill.ICONS`, junto a `burn         = "status_burn",`)

> QUEIMADURA tem icone PROPRIO (Set/2026). Dividia `flame` com a Furia, e
> as duas sao pills laranja no MESMO inimigo: mesmo simbolo, mesma cor,
> dois estados diferentes. Agora so a Furia usa `flame`.

## L62-66 (em `StatusPill.ICONS`, junto a `fury         = "status_fury",`)

> FURIA nao e fogo: e o anti-stall do turno 8+, o inimigo escalando +2 de
> dano por turno. A fogueira era interina e, depois que a queimadura ganhou
> chama propria, as duas viravam "duas pills laranja" no MESMO inimigo. O
> icone novo separa por FORMA (cunhas retas subindo x chama gorda e
> arredondada), nao por matiz -- laranja e a cor certa pras duas.

## L70-75 (em `StatusPill.ICONS`, junto a `thorn        = "status_thorn",`)

> Interinos: reusam ícones existentes até a leva status_* do PixelLab
> (thorn/lifesteal/regen/bleed/retain_armor/enraged pedidos no relatório).
> Leva status_* dedicada (Set/2026) — os interinos de arte de carta saíram.
> Critério de aprovação: legibilidade no TAMANHO DE USO (36px), não a 4x;
> ampliado engana, e foi assim que `dagger` e `heart` passaram na primeira
> rodada e reprovaram na tela.

## L83-84 (em `StatusPill.ICONS`, junto a `weak_self       = "status_weak_self",        -- espada partida (24px nativo)`)

> Kit dos inimigos (Out/2026). Frágil tem ícone próprio (peitoral de aço
> rachado); revoada = garra e eclipse = lua seguem interinos.

## L94 (em `StatusPill.ICONS`, junto a `local warned = {}`)

> ===== Avisos (ui_layout_invariants §3: fallback silencioso é proibido) =====

## L113-114 (em `getIcon`, junto a `if icon and icon.kind == "matrix" and PixelIcons[iconName] == nil then`)

> IconLoader NUNCA devolve nil: sem PNG e sem matriz ele entrega o "?" de
> PixelIcons.question. Sem este check o ícone errado passaria despercebido.

## L142-144 (em `StatusPill.getRowDims`, junto a `function StatusPill.fitSize(count, maxWidth, preferred, spacing)`)

> Maior tamanho de pill que faz `count` pills caberem em `maxWidth`.
> Zona (ui_layout_invariants §1): quando o espaço aperta quem cede é a ESCALA
> do conteúdo — a row nunca quebra linha nem invade a banda de cima.

## L155-163 (em `StatusPill.fitSize`, junto a `function StatusPill.render(name, x, y, opts)`)

> Desenha UMA pill. Não gerencia posicionamento da row — cal ler passa (x, y) top-left.
> opts:
> size: diâmetro em px (default 32)
> stacks: número (default 1); contador só aparece se > 1 OU showStacksAlways
> duration: turnos restantes (passado pro tooltip, não renderizado)
> showStacksAlways: bool — buffs do player mostram sempre
> animTime: segundos acumulados (pra halo pulsante)
> pulseHalo: bool — buffs tem halo mais forte (pulsando)
> iconTarget: tamanho alvo do ícone em px (default = size * 0.76)

## L226-227 (em `color`, junto a `local br = math.max(7, math.floor(size * 0.28))`)

> Badge acompanha a escala da pill (row encolhida não ganha contador
> desproporcional).

## L243-249 (em `color`, junto a `function StatusPill.drawRow(effects, startX, startY, opts)`)

> Desenha uma row horizontal de pills. Trata hover → tooltip sozinho.
> effects: array { {name, stacks, duration, showStacks?, variant?}, ... }
> showStacks: sobrescreve opts.showStacksAlways por pill (estado sem número,
> tipo "Bloqueio Retido", passa false pra não imprimir "0").
> variant:    sufixo de desc no tooltip (ex: "permanent" → status.x.desc_permanent).
> startX, startY: top-left da row
> opts: mesmas opts de render + spacing

