---
name: lighting_engine
description: LightEngine v1 — plano completo do motor de iluminação do WorldRoad (lightmap ¼ multiply-only, micro-luzes, dados por bioma); doutrina de luz do projeto e armadilhas conhecidas
type: project
---

# LightEngine v1 — motor de iluminação do WorldRoad

**STATUS: IMPLEMENTADO (Jul/2026)** — F0 (fundação) + F1 (ambiente por bioma) +
F2 (fontes pontuais: lanterna/braseiro procedurais, janelas do castelo com
ÂNCORAS REAIS extraídas por análise de pixel dos PNGs + cor por bioma, flicker
noise) + F3 parcial (vagalumes como micro-luzes, gate por LUMINÂNCIA do
ambiente, cap 14 no escuro) + **F6.1 ENTARDECER POR ANDAR** + **OCLUSÃO POR
SILHUETA**.

## F6.1 — entardecer progressivo por andar
`lightDay`/`lightNight` por bioma em biomes.lua; `WorldRoad.setTimeOfDay(t,
instant)` (0=dia..1=anoitecer, ease 0.30/s durante a viagem — amanhecer suave
ao entrar num ato novo); GameplayScene seta por `floorInAct` com curva
`0.62 + 0.38·((floor-1)/7)^1.35` — **PISO 0.62** (Jul/07: primeiro 0.5 —
"o jogo base está sem a iluminação do demo", tod=0 dava luz ~branca; depois
"pode começar um pouco mais escuro" → 0.62; fecha em tod=1 no boss).
Default tod=1 (tools mostram o mood cheio). Prefixos do screenshot tool:
`day_`/`mid_`; demo tecla T cicla 0→0.5→1. fields no andar do boss = o look
da REFERÊNCIA.
`lightAmbient` virou fallback (saiu de ENV_FIELDS — currentLightAmbient()
faz lerp dia/noite + blend de bioma).

## Oclusão por silhueta (pedido: luz atrás de corpo não vaza por cima)
`LightEngine.submitOccluder{z, bx, by, w, h, img/fn...}`: o composite vira um
PAINTER no lightmap — entradas (luzes + oclusores) ordenadas por z DESC; a
silhueta do oclusor é desenhada na cor AMBIENTE (alpha do sprite recorta
pixel-perfeito), apagando luz vinda de trás; luzes mais próximas (z menor)
desenham depois e ainda iluminam o corpo. Culling: oclusor só entra se alguma
luz mais funda toca seu retângulo (custo ~zero no bench). Oclusores ativos:
árvores/arbustos (drawProps), inimigo em batalha (EnemyRenderer.draw — fn com
anim; CUIDADO: SpriteAnimation:draw IGNORA setColor sem tint, repassar via
getColor), encounter descendo a estrada. Janelas do castelo têm z=999 (tudo
oclui); poças/núcleos z=rel do prop; vagalumes/brasas z=-1 (nunca ocluídos).
Arquivos: `engine/LightEngine.lua`, `shaders/light_dither.glsl`, `Config.Lighting`
(src/core/Config.lua), `lightAmbient`/`lightWindowColor` em src/data/biomes.lua,
integração em WorldRoad.lua (beginFrame no draw; submits em drawCastleOf/drawProps/
critters/embers; API drawLightComposite/drawForkOverlay/drawOverlays) +
GameplayScene (composite após inimigo, antes do HUD) + SettingsMenu (toggle
"Iluminacao", persistido como `lighting`). Tools: demo_worldroad (teclas L/O/P),
screenshot_worldroad (prefixo `nolight_` para A/B).
Validado: A/B ON≤OFF por pixel (delta máx 32 = só ambiente), scissor protege HUD,
zoom 3× sem franja/xadrez em silhueta, bench +0.70ms/frame, blend6/fork/travel ok.
Calibração fina: teclas O/P no demo alteram LightEngine.debugAmbientScale ao vivo.

**Plano completo:** [`docs/plan/lighting-engine-v1.md`](../docs/plan/lighting-engine-v1.md)
(pesquisa 9 frentes + revisão adversarial incorporada, Jul/2026). Prova de conceito:
`docs/plan/lighting-engine-v1-mockup.png` (simulação offline do pipeline sobre captura
real do `screenshot_worldroad enemy1_cursed_scarecrow`).

## Emissivos por monstro (v1.2 — Jul/2026)
Todos os 21 inimigos revisados pixel-a-pixel: micro-luzes nos emissivos que
a ARTE pintou (olhos do espantalho, orbe do tower_lich, runas do rune_golem,
fornalha do abyss_tyrant, olho vermelho único do abyss_wraith...). Dados em
`src/data/enemy_emissives.lua`; pipeline padrão pra monstro novo em
memory/enemy_pipeline.md (extrator + revisão da folha anotada). Runtime:
EnemyRenderer (pulso lento, apaga na morte, mesma z da silhueta — tie-break
do engine desenha luz depois do oclusor no mesmo plano) + billboard da
viagem (drawEncounterFront). harvest_reaper ficou SEM luz de propósito
(skull de osso sem glow pintado — restraint é parte do padrão).

## Calibração por feedback do usuário (Jul/2026)
- **Vagalumes**: "só no meio da estrada, luz grande demais" → spawn nas FAIXAS
  DE VEGETAÇÃO laterais (xr 0.03-0.33 ∪ 0.67-0.97; só 12% livres), faixa de
  profundidade 0.42-0.90, FIREFLY radius 9→6 / intensity 0.7→0.45, halo e
  micro-luz escalam com a profundidade (`depth = 0.45 + 0.55*yr`).
- Vagalume acende por LUMINÂNCIA do ambiente (< 0.75), não por bioma — fields
  ao anoitecer (F6.1) ganha vagalumes como na referência.
- **BUG corrigido**: culling de oclusores testava contra `entries` (que já
  continha oclusores aceitos, sem `.r`) → crash aritmético. Testar interseção
  SÓ contra a lista de luzes.
- Captura estática esquenta só ~1s — vagalumes acumulam até o cap em ~30s de
  jogo; validação de densidade é no demo interativo, não no screenshot.

## Armadilhas descobertas NA implementação (além do plano)
- Poça de chão de lanterna DISTANTE ditherizava a copa das árvores vizinhas
  (F-1 na prática) → `Config.Lighting.POOL_MIN_T = 0.42`: poça só quando o prop
  está no terço de baixo da perspectiva; de longe fica só o núcleo (micro-luz).
- Cor da luz de janela segue a JANELA PINTADA do castelo do bioma
  (`lightWindowColor`: marsh verde, abyss brasa, frost azul) — laranja fixo
  denunciava no castelo verde do marsh.
- Capturas de modos diferentes do screenshot tool NÃO são comparáveis por diff
  (estado do RNG diverge → nuvens em posições diferentes); A/B sempre
  like-for-like: `full1` vs `nolight_full1`.

## Arquitetura em uma linha
Canvas de luz ¼ res nearest (rgba8) limpo com `lightAmbient` do bioma (alpha=1!),
luzes `add` posterizadas (poça de chão: 4 degraus + Bayer 4×4; horizonte/pequenas:
2 degraus SEM dither), micro-luzes (cap 64, sem shader) para vagalumes/chamas/janelas,
composto com `multiply, premultiplied` + scissor sobre a cena ANTES da UI.
Multiply-only ⇒ nunca clareia acima da arte (a lição-mãe do projeto).

## Doutrina de luz do projeto (não repetir erros)
- "Luz em pixel art se DESENHA na paleta, não se sobrepõe com alpha" (WorldRoad ~1157).
  Removidos no v7: god rays, rim light, glow de janela, sombra de nuvem (ciclo 26 —
  razão CONCEITUAL), faixa de crista. Sombra de nuvem/god rays só voltam GATED (F5).
- Zero stencil (NVIDIA). Scissor ok. light_world/lighter usam stencil ⇒ banidas.
- Emissivo = pintado na arte (glow assado no PNG) + micro-luz por cima. `boost()`
  (dividir pela ambient) foi REJEITADO na revisão: não restaura canal saturado e
  clareia acima da arte perto de luz pontual.
- Luz screen-space vaza sobre occluders ⇒ raio ∝ persp(t), janelas = luzes pequenas
  POR JANELA (radiusK 0.18, int ≤ 0.6), poça só com emissor visível no frame.
- Fork marks/pills = UI in-world ⇒ desenhar APÓS o composite (drawForkOverlay).
- Interiores não chamam WorldRoad.draw ⇒ composite tem guard (no-op sem beginFrame).

## Fases
F0 fundação fail-safe (toggle `lighting`, diff<1% ON neutro) → F1 ambiente por bioma
(`lightAmbient` em ENV_FIELDS = crossfade grátis) → F2 fontes pontuais (assets
lantern/brazier PixelLab + janelas do castelo) → F3 vida emissiva (vagalumes micro)
→ F4 bruma por fatia de profundidade → F5 gated (LUT, variação tonal, god rays)
→ F6 decisões abertas (entardecer progressivo por andar; interiores; bloom Kawase).

## API LÖVE — pegadinhas verificadas
`multiply` exige `premultiplied` (erro senão); multiply multiplica alpha do destino
(clear do lightmap com alpha=1); GLSL do LÖVE sem array initializer (Bayer = if-chain);
`rectangle` não tem UV útil (desenhar Image branca 2×2 escalada com o shader);
`screen_coords` do effect() = pixel do render target ativo; transformPoint converte
coords dentro do room-sway.
