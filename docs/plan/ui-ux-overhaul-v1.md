# UI/UX Overhaul v1 — plano completo (menus, loja, packs, HUD, opções)

> **Status:** EM EXECUÇÃO (Jul/2026) — feito: F0 parcial (Panel9, HintBar,
> assets de painel + 10 ilustrações de evento), F1 completa (Continuar
> funcional com save por andar, hint da loja, screenshake), F4 completa
> (Rest/Event/ClassSelection renascidas com Panel9 + cenas + ilustrações +
> cartas reais), F2 COMPLETA na loja (slots FIXOS por oferta — bug de índice
> pós-compra corrigido em draw/hover/selection —, carta voa pro deck da
> TopBar ao comprar, popup -$N, stamp VENDIDO no slot, coluna esquerda
> Balatro com CONTINUAR vermelho + Novas ofertas + painel OURO, saleDim),
> F5 núcleo (Deck Viewer GLOBAL: tecla D / clique no deck da TopBar, grid
> ordenado + contagens + pilhas + badge de forja — fecha o gap "upgrade
> invisível"), MENU repaginado (perfil persistente engine/ProfileStats.lua
> com plaque de vitórias/melhor progresso + versão v0.9.0 no rodapé;
> _G.HEADLESS_TOOL protege o perfil das capturas de validação), SPLASH com
> título do jogo materializando no auge da cascade (BootScene).
> Pendentes: packs em container no PackOpen, F3 RoundEval recibo, F6
> DynaText nas demais telas, F7 Settings com abas; panel_gold falhou
> no PixelLab (503, re-gerar). Levantamento visual das 11 telas em
> [`ui-survey-2026-07.png`](ui-survey-2026-07.png) (harness novo:
> `love . screenshot_ui menu|class|settings|rest|event|collection|all`).
> Pesquisa em 3 frentes: anatomia do Balatro extraída do source (espelho
> público clonável — ver §2.1), best practices de deck-builders
> (StS/Monster Train/Wildfrost) e craft de UI pixel (9-slice, tipografia,
> estados). Segue a lei do projeto: `memory/balatro_fidelity_directive.md`.

---

## 1. Diagnóstico por tela (o que o levantamento achou)

| Tela | Nota | Problemas concretos (das capturas) |
|---|---|---|
| **Menu** | B | Instruções de GAMEPLAY vazando por cima do livro (texto ilegível sobre arte); botões cobrem a arte do grimório; sem "Continuar" (save existe!); sem hierarquia de CTA (Jogar = mesmo peso de Sair); "Sobre" placeholder |
| **ClassSelection** | C | ZERO informação por classe (o que joga, cartas iniciais); botões desconectados das estátuas; estátua central escondida atrás dos botões |
| **Settings** | B- | Sem sliders (só −/+); `screenshake` persiste no save mas NÃO aparece na UI; sem velocidade de animação; sem abas (vai lotar); instruções do menu vazam por trás |
| **Loja (CardRewardScreen)** | B | Hint bar ESTOURA a tela dos dois lados; botão "Pular" cortado embaixo; painel do Refresh 80% vazio; sem estado visual "não posso pagar" (esmaecer + preço vermelho); preço em badge cobre o nome da carta |
| **PackOpen** | C+ | Cartas FLUTUANDO sem container (viola lição nº2 da diretiva); painel-título desconectado das cartas; fundo preto genérico (Balatro troca a cor do fundo por tipo de pack); skip solto |
| **RoundEval** | B- | Painel metade vazio; fundo preto puro (deveria ver o mundo/cena atrás); linhas sem ícones; sem o "recibo" linha-a-linha com som (tem DynaText parcial) |
| **MapScreen** | B+ | Visual forte; números de node desalinhados entre painéis; papel ambíguo vs fork in-world (decidir: fork = escolha rápida, MapScreen = fallback/preview?) |
| **Rest** | D | A pior tela: fundo pontilhado chapado, SEM arte (o projeto TEM cenas de fogueira!), 2 botões soltos no vazio, sem preview do forge |
| **Event** | D+ | Painel com miolo vazio (sem ilustração do evento), botões genéricos, sem indicação de risco/recompensa |
| **Collection** | A- | A melhor tela; tooltip cobre 2 cartas do grid (virar painel lateral fixo); sem sort/contagens por aba; fileira de baixo cortada |
| **HUD combate** | B | TopBar "0 cartas (2 na mao)" confuso; sem deck/draw/discard viewer NA RUN; intent sem número ajustado por debuff?; botão "Jogar Cartas" sem estado pulsante/disabled claro |

**Transversais:** hint bars sem padrão (cada tela improvisa e estoura); tooltip
sem warm-up/flip de borda; nenhuma transição entre telas (corte seco); paleta de
estados existe (`Palette.lua` UI Chrome) mas cores FUNCIONAIS não são semânticas
(dourado é decoração e ação ao mesmo tempo); `run.upgraded[id]` invisível no
frame da carta (gap conhecido).

## 2. Pesquisa — o que importa (síntese dos 3 dossiês)

### 2.1 Balatro (anatomia extraída do source)

Espelho público do source decompilado: `https://github.com/GladdonT/balatro-source-code`
(clonar em scratchpad quando precisar; **referência de ESTRUTURA, nunca copiar
código/assets** — doutrina copyright-safe do projeto). Arquivos-chave:
`functions/UI_definitions.lua` (6.4k linhas, todas as telas), `globals.lua`
(paleta), `engine/text.lua` (DynaText).

O que copiar (estrutura, adaptando estética pra sépia):
- **Painel-sanduíche 3 camadas**: halo transparente escuro → moldura (cor
  dinâmica por estado) com emboss → corpo escuro. Overlay sempre com véu
  `a≈0.7` sobre a cena + botão Voltar LARANJA embaixo.
- **Cor = função (semáforo)**: 6 cores fixas — navegação/voltar, perigo/
  avançar-round, confirmar/reroll, comprar/dinheiro, info, desabilitado.
  Mapeamento sépia (usando SÓ a paleta Grimoire): navegação = AGED_GOLD;
  perigo/commit = BLOOD; confirmar/reroll = MOSS; comprar = TAROT_GOLD;
  info = STEEL_LIGHT/azul-mana; disabled = STEEL escurecido. **Skip sempre
  cinza-fosco** (nunca compete com a ação principal).
- **`func` validators por frame** (`can_buy`/`can_reroll`): botão nunca "dá
  erro" — fica inativo ANTES do clique. Badge de preço com data binding.
- **Transição = slide de painel** (offset.y pra fora/dentro com mola), NUNCA
  fade preto. O HUD não sai do lugar; a carta comprada VIAJA da loja pro slot.
- **Round eval = recibo**: linhas entram uma a uma com som; ouro rola `$` por
  `$` (delay 0.18s, acelera se muitos); botão Cash Out gigante cai por último
  — o clique É a recompensa.
- **DynaText** (port pendente da diretiva): texto por letra com pop_in/float/
  bump/rotate/pulse; TODOS os modos zeram com reduced_motion (early-return
  no primitivo — padrão a copiar).
- **Game Speed global**: todos os delays multiplicados por um fator (0.5/1/2/4)
  — amarrar TODOS os EventManager.after de UI num `Config.UI.SPEED` desde o
  início.
- **Settings com abas**: Jogo (speed, screenshake slider, reduced motion) /
  Vídeo (fullscreen, CRT slider) / Áudio (3 sliders).

### 2.2 Deck-builders (usabilidade)

- **Intent com número FINAL** (ajustado por weak/vulnerable) + total de
  multi-hit ("3×4 (12)") — nunca fazer o jogador calcular.
- **Impagável = esmaecido + custo vermelho** (dois canais, nunca só cor).
- **Skip legítimo mas discreto** (cinza, menor que as cartas).
- **Deck viewer GLOBAL** (acessível de combate/loja/recompensa/mapa) com
  sort custo/tipo/raridade + header de contagens; draw/discard clicáveis no
  HUD (draw embaralhado — não revela ordem).
- **Card inspect**: clique → zoom com keywords explicadas ao lado.
- Upgrade visível no frame (nome verde + "+" no StS).
- Fricção proporcional: compra = 1 clique; remoção/abandono = confirmação.
- Hit target ≥ 40px; corpo de texto ≥ 16px @768p; feedback < 100ms.
- Fundo ATENUADO atrás de telas de decisão (escurecer o cenário).

### 2.3 Craft pixel

- **Panel9** (9-slice ~60 LOC, bordas REPETIDAS não esticadas, floor() e
  escala inteira sempre) — receita completa no dossiê; cachear em Canvas.
- **Tipografia**: Press Start 2P SÓ para títulos/números; adicionar
  **m5x7 (Daniel Linssen, grátis, tem acentos PT-BR)** para corpo/tooltips —
  drop em `assets/fonts/` + tamanhos semânticos no PixelFont.
- **Botão pressed** = corpo desce 2px + sombra-chão encolhe junto (ilusão
  física); disabled = trocar cores por steps próximos do fundo (NUNCA alpha).
- **Tooltip**: warm-up 300–500ms, vizinhos abrem sem delay enquanto varre,
  flip nas bordas, largura ≤ ~46 chars, singleton (StatusTooltip já é).
- **Transições**: dither-wipe Bayer (matemática JÁ existe em light_dither/
  dissolve) na cor INK-sépia, ≤300ms; slide com stagger 30-60ms entre painéis.
- **PixelLab pra UI**: gerar PEÇAS (corner 16×16, edge tileable), não painéis
  prontos; travar paleta por hex no prompt; testar tiling imediatamente.
  Endpoint dedicado `generate-ui-v2`; bypass HTTP validado (token no script
  `tools/pixellab_generate_packs.py`).

## 3. Fundação — o design system (F0/F1, tudo o resto depende disso)

1. **`src/ui/Panel9.lua`** — 9-slice com 3 texturas PixelLab: `panel_main`
   (moldura ornamentada grimório), `panel_inner` (corpo escuro simples),
   `panel_gold` (destaque/hero). Cache por tamanho em Canvas.
2. **`components/Button.lua` v2** — manter API; adicionar: variante semântica
   (`nav|commit|confirm|buy|info|skip`), pressed físico (2px + sombra),
   `setValidator(fn)` estilo `func` do Balatro (roda por frame, seta
   enabled + tooltip do porquê), `one_press`.
3. **`src/ui/DynaText.lua`** — PORT (pendência da diretiva): por letra,
   pop_in/float/bump/pulse/pop_out, respeitando reduced_motion no primitivo.
4. **`src/ui/UiSpeed.lua`** — fator global de velocidade de UI/animação
   (0.5/1/2/4) aplicado em TODOS os delays de EventManager de UI.
5. **Tooltip v2** (`StatusTooltip` estendido): warm-up 350ms + cadeia sem
   delay + flip de borda + largura máx; usado por cartas, intents, botões
   desabilitados ("Ouro insuficiente").
6. **`src/ui/HintBar.lua`** — barra de dicas PADRONIZADA (1 componente,
   truncagem com fade, nunca estoura — mata o bug da loja).
7. **Fonte de corpo m5x7** + hierarquia no PixelFont (título=PS2P,
   corpo=m5x7 16/24px).
8. **Cores funcionais** — novos aliases semânticos na Palette (ACTION_NAV,
   ACTION_COMMIT, ACTION_CONFIRM, ACTION_BUY, PRICE_OK, PRICE_NO...).
9. **Transições**: `src/ui/ScreenTransition.lua` — slide de painel (mola) +
   dither-wipe Bayer sépia p/ trocas de estado grandes.

## 4. Redesign por tela (blueprint Balatro adaptado)

- **Menu**: remover instruções de gameplay (vão pro primeiro combate como
  hint contextual); barra inferior estilo Balatro: **JOGAR** (hero, gold,
  maior) + **CONTINUAR** (se `run.save.lua` existe — fecha gap conhecido) |
  coluna Opções+Sair | **COLEÇÃO**; título com DynaText float; cartas do
  fundo com ambient_tilt (já tem juice no projeto).
- **ClassSelection**: 3 PAINÉIS-carta (um por classe) com retrato PixelLab,
  nome, 2 linhas de identidade ("Aço e sangue — dano bruto e armadura"),
  preview das 2 cartas iniciais (CardFrame real), hover = painel levanta +
  estátua correspondente ilumina (LightEngine!); selecionar = commit.
- **Loja**: estrutura Balatro — placa "LOJA" DynaText deslizando; coluna
  esquerda [Continuar (commit) / Reroll $N (confirm, preço bindado)];
  cartas com badge de preço acima + botão COMPRAR embaixo de cada uma
  (validator can_buy → esmaece + preço BLOOD); packs e upgrade em
  subcontainers com título; carta comprada VOA pro deck; hint via HintBar.
- **PackOpen**: pack sleeve (5 artes JÁ existem em assets/sprites/packs!)
  explode no centro → cartas materializam em CardArea linear DENTRO de
  container; fundo = a CENA atual escurecida (não preto); título+Choose N
  em dyn_container; skip cinza à direita.
- **RoundEval**: sobre a cena escurecida; recibo linha-a-linha com som
  (Vitória → HP → Juros → jokers de economia) + ouro rolando $ a $;
  botão RESGATAR gigante caindo por último.
- **Rest**: fundo = cena `path_rest`/fogueira REAL (existe!) + LightEngine
  (fogueira como fonte quente); 2 cartões grandes de escolha (Descansar
  +30% HP com preview do HP resultante / Forjar com preview do deck);
  padrão de card-choice do EventScreen.
- **Event**: painel com ILUSTRAÇÃO (PixelLab 1 por evento, fila §6),
  texto narrativo em m5x7, botões de escolha com indicação de risco
  (ícone + cor), consequência com attention_text.
- **MapScreen**: manter visual; alinhar números; adicionar preview de
  inimigo no hover de battle/elite; papel definido: overlay de escolha
  quando fork in-world não está ativo.
- **Collection**: tooltip vira PAINEL LATERAL fixo (não cobre grid); sort
  (custo/tipo/raridade/A-Z) + contagem por aba; scroll com fileira inteira.
- **HUD combate**: TopBar ganha **deck counter clicável** (abre Deck Viewer
  global) + draw/discard counters; intent com número final ajustado;
  "Jogar Cartas" com 3 estados (disabled/normal/pulsante quando cartas
  selecionadas); custo da carta em BLOOD quando mana insuficiente + carta
  não levanta no hover.

## 5. Novas visualizações (pedido explícito: "mais opções de visualização")

1. **Deck Viewer global** (overlay de 1 clique em QUALQUER tela da run):
   grid com sort/contagens, cartas upgradadas com "+" e nome MOSS.
2. **Draw/Discard viewers** (draw embaralhado).
3. **Card Inspect** (clique em qualquer carta → zoom + keywords explicadas).
4. **Run Info** (aba: combos ativos do turno, jokers, ouro/juros, ato/andar).
5. **Settings com abas**: Jogo (velocidade ★, screenshake slider ★ — já
   persiste!, reduced motion), Vídeo (fullscreen, CRT, Iluminação), Áudio
   (3 sliders de verdade), Idioma.

## 6. Fila PixelLab (bypass HTTP validado nesta sessão)

| Asset | Specs | Uso |
|---|---|---|
| `ui/panel_main` 9-slice | 48×48, margem 12, cantos ornamentados latão/filigrana, centro pergaminho | painel principal |
| `ui/panel_inner` | 32×32, margem 8, borda simples ink | subcontainers |
| `ui/panel_gold` | 48×48, moldura dourada hero | CTA/destaques |
| `ui/button_plate` ×3 estados | 48×16, margem 6 | botões |
| `ui/tab_strip` | 32×24 | abas settings/collection |
| retratos de classe ×3 | 96×96, warrior/mage/rogue busto | ClassSelection |
| ilustrações de evento ×N | 128×96 por evento de `src/data/events.lua` | EventScreen |
| ícones UI: sort, search, draw pile, discard pile, speed, shake | 16×16 | HUD/settings |
| placa "LOJA" | 160×48 ornamentada | shop header |

Prompts seguem o contrato canônico + travar paleta por hex + "seamlessly
tileable edges, no anti-aliasing, transparent background". Gerar PEÇAS e
testar tiling montando painel 3× antes de aceitar.

## 7. Fases (cada uma com captura de validação via screenshot_ui)

- **F0 Fundação** — Panel9 + Button v2 + HintBar + fontes + cores semânticas
  + UiSpeed + Tooltip v2 + assets PixelLab de painel/botão. Aceite: tela de
  demonstração com todos os estados; zero regressão nas telas atuais.
- **F1 Quick wins** — bugs visíveis: hint bar da loja, Pular cortado,
  Continuar no menu, instruções fora do menu, screenshake slider,
  esmaecer impagável (loja + mão). Aceite: capturas antes/depois.
- **F2 Loja + PackOpen** (blueprint Balatro completo). Aceite: fluxo
  comprar→voar→reroll→pack→abrir sem corte seco, tudo em container.
- **F3 RoundEval + transições** (recibo + ouro rolando + dither-wipe).
- **F4 Rest + Event + ClassSelection** (as 3 telas fracas, com arte).
- **F5 Visualizações** — Deck Viewer global + draw/discard + inspect +
  Run Info + Collection sort/painel lateral.
- **F6 DynaText port + polimento** (títulos vivos, attention_text, juice
  de compra completo).
- **F7 Settings com abas** + Menu final.

Validação padrão: `love . screenshot_ui all` + telas específicas; zoom nos
estados de botão; teste de resize (contrato memory/resize_pattern.md);
`love . validate_cards` continua verde.

## 8. Riscos e lições a respeitar

- **Lição da diretiva**: implementar tela SEM abrir o blueprint = retrabalho
  ("ficou tosco"). Sempre citar a estrutura de referência ao implementar.
- **Tooltip z-order**: SEMPRE segunda pass (lição F10.1).
- **Containers visíveis** (lição F10.2): nada de slots flutuando.
- **Halos animados com parcimônia** (lição F10.3): idle = parado.
- **Resize**: toda tela nova/refeita entra no checklist resize_pattern.
- **Não copiar código do espelho Balatro** — estrutura e números só.
- Mirror do Balatro é decompilação: manter FORA do repositório.
