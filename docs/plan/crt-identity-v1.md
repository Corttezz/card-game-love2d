# Identidade CRT v1 — "A Crônica no Tubo"

> **Status:** EM EXECUÇÃO (Jul/2026). Pedido do dono: CRT forte de verdade
> ("que pareça uma televisão de tubo, algo antigo"), bordas arredondadas,
> ligar o jogo = TV ligando, morrer/sair = TV desligando, transições do
> menu na mesma linguagem.

## 1. Conceito

O jogo INTEIRO vive dentro de um televisor de tubo antigo. Não é um filtro
por cima — é o aparelho. Consequências de design:

- A tela tem **forma**: cantos arredondados de tubo (máscara superelipse),
  curvatura de vidro (barrel), sombra de bezel nas bordas.
- A tela tem **matéria**: scanlines, máscara de fósforo RGB (aperture
  grille sutil), aberração cromática nas bordas, ruído de sinal, flicker
  de 60Hz quase imperceptível.
- A tela tem **estados físicos**: liga (warm-up), desliga (colapso em
  linha → ponto), e "pulos de canal" nas transições fortes.

Referências de comportamento físico (conhecimento de domínio):
- **Ligar**: ponto branco no centro → linha horizontal cresce → a imagem
  "abre" verticalmente com overshoot de brilho (o canhão aquecendo) →
  assenta com um leve wobble.
- **Desligar**: a imagem colapsa verticalmente numa linha branca quente →
  encolhe pra um ponto que persiste ~0.3s → apaga.
- Balatro/retro handhelds fazem versões disso; a nossa é own-math no
  shader (copyright-safe, como os demais shaders do projeto).

## 2. Arquitetura

### 2.1 shaders/crt.glsl v2 (reescrita)
Uniforms: `time`, `resolution`, `strength` (identidade), `power` (0..1,
estado físico do tubo).

Pipeline por pixel (ordem):
1. **Power remap**: p<1 remapeia uv pro estágio do warm-up:
   - p ∈ [0, .35): linha horizontal crescendo (vScale≈0.006, hScale=p/.35)
   - p ∈ [.35, .85): abertura vertical (vScale 0.006→1, ease quadrático)
   - p ∈ [.85, 1): assentamento (overshoot de brilho 1.2→1.0)
   - fora da área visível → preto; vScale pequeno → mistura pra branco
     quente (a linha brilha independente do conteúdo).
2. **Barrel**: curvatura de vidro `uv += cc * dot(cc,cc) * 0.035`.
3. **Máscara de tubo**: superelipse (expoente 8) com borda suave — cantos
   arredondados REAIS; fora = preto absoluto (o "gabinete").
4. **Sombra de bezel**: escurecimento extra encostado na máscara.
5. **Aberração cromática** escalada pela distância do centro (bordas
   sangram mais — física real do tubo).
6. **Scanlines** (0.035) + **grille RGB** (triade horizontal, 0.08).
7. **Vignette** + **flicker** 0.008 + **noise** de sinal.

Cuidado herdado (comentário no shader atual): NUNCA reintroduzir a onda
horizontal viajante — em pixel art ela lê como bug de cena (4 rodadas de
caça no GrassField). A curvatura barrel é ESTÁTICA, não viaja.

### 2.2 src/ui/CRTShader.lua v2
- Estado `power` (default 1) + animador próprio (sem EventManager — o
  power precisa animar até DURANTE transições de estado/quit).
- API: `setPower(p)`, `powerOn(dur, cb)`, `powerOff(dur, cb)`,
  `isPowering()`, `update(dt)` (tick no love.update).
- **Acessibilidade**: com CRT desligado nas Settings, powerOn/Off chamam
  o callback imediatamente (corte seco) — a identidade é opcional, o
  fluxo do jogo não.
- Canvas do endScene passa a filtrar LINEAR (o barrel em nearest cria
  degraus serrilhados; linear = suavidade de vidro, apropriado pro CRT).

### 2.3 Momentos (wiring em main.lua)
| Momento | Efeito |
|---|---|
| Boot do jogo | `setPower(0)` + `powerOn(1.5)` — a TV liga revelando o splash (a cascata de cartas já acontece "dentro" do tubo) |
| Morte (gameOver) | `powerOff(0.55)` → troca de estado no escuro → `powerOn(0.8)` já na tela de game over |
| Vitória | idem morte (a crônica "desliga" e religa no epílogo) |
| Sair (botão Sair do menu) | `powerOff(0.7)` → `love.event.quit()` no callback |
| GameOver/Victory → menu | `blip()` (dip rápido de power 1→0.85→1, "pulo de canal") |

### 2.4 Validação
`tools/screenshot_crt.lua`: renderiza o menu dentro do CRT com power em
{0.15, 0.55, 0.80, 1.0} → contact sheet; revisar a linha quente, a
abertura, os cantos arredondados e a imagem assentada. Capturas normais
de outras ferramentas continuam SEM CRT (doutrina existente).

## 3. Fora de escopo (v2 futura)
- Moldura de gabinete desenhada (bezel com textura/reflexo de sala).
- Estática de canal entre TODAS as trocas de tela.
- Som: hum de 60Hz ao ligar + "tack" do desligar (pede SFX novos).
- Curvatura afetando input de mouse (hoje o hit-test ignora o barrel —
  com curvatura 0.035 o desvio máximo é ~1.5% na borda; aceitável).


## v2.1 (Jul/2026 — feedback do dono + pesquisa)

Pesquisa: RetroArch CRT-Geom (cornersize/jitter), CRT-Interlaced-Halation,
SDF de retângulo arredondado (Shadertoy WtdSDs/fsdyzB).

- **UNDERSCAN**: o conteúdo inteiro ocupa a área interna segura do tubo
  (inset ~4.5%) — máscara/curvatura comem só moldura preta. Revisão de
  telas validada com captura: mana orb, painel de vida, TopBar e HintBar
  100% visíveis nos cantos.
- **Cantos v2**: SDF de retângulo arredondado com aspecto corrigido
  (círculos reais, raio generoso 0.085) no lugar da superelipse.
- **TREMIDINHA**: sync jitter ocasional — banda horizontal estreita treme
  ~0.15s a cada 4-9s (agendado em CRTShader.update, uniforms
  glitch/glitchY). É EVENTO discreto, não a onda viajante banida.
- **Interlace shimmer** (paridade de linha alterna por quadro, 30Hz de
  vida) + **halation** (brilho sangrando, 4-tap).


## v2.2 (Jul/2026 — relevo do domo + legibilidade)

Pesquisa: crt-pi.glsl (libretro — Distort com CURVATURE_X/Y anisotrópico
+ barrelScale), CRT-Royale (geometria esférica/cilíndrica, refractive
diffusion), CRT-Geom-Deluxe.

- **Geometria de DOMO**: curvatura r² + termo r⁴ (7.0) — centro quase
  plano, cantos dobrando FECHADO (a descrição exata do dono). Anisotrópica
  (Y 0.062 > X 0.045, padrão crt-pi).
- **Relevo perceptível**: sombreamento lambertiano do domo (centro "mais
  perto" = mais claro; queda acelera nos cantos via r⁴) + BRILHO DE VIDRO
  estático (elipse larga no terço superior — reflexo da sala, a pista
  mais forte de convexidade).
- **TopBar legível sob o tubo** (feedback): fundo mais escuro
  (0.07/0.055/0.04), fontes 12→14 e 8→9, bezel do shader 0.32→0.22.


## v2.3 (Jul/2026 — conteúdo intocável)

Feedback do dono: "as bordas devem ficar FORA do que a gente renderiza,
pegando muito pouco; parte de baixo das cartas e mana/vida ainda ruins."
Diagnóstico numérico: no canto, domo(×0.60) × vinheta(×0.53) × bezel
derrubava o brilho pra ~25% — a UI ficava visível mas AFOGADA.

Nova filosofia: **efeitos pra fora do conteúdo, escurecimento mínimo
por cima dele**:
- Underscan 4.5%→1.5% fixo (borda pega quase nada do render).
- Cantos 0.079→0.045 (não se aproximam da UI).
- Domo: queda máxima 45%→15% (clamp 0.85) — relevo por LUZ (sheen),
  não por escuridão.
- Vinheta: pow 3→2, mix 0.55, alcance menor.
- Bezel 0.22→0.12 e só na moldura.
Medição pós-fix (luminância média na captura): mana orb 45.7, painel de
vida 52.3 (sobre fundo ~15) — legíveis. Regra: legibilidade > efeito.


## v3 (Jul/2026 — GABINETE visível, referência pixelbuddha do dono)

O preto morto ao redor virou um TELEVISOR desenhado proceduralmente no
shader (zero assets, qualquer resolução):
- Moldura de plástico escuro (26px) com luz vinda de cima, textura fina
  de ruído estático e cantos externos escurecidos.
- LÁBIO especular na abertura do tubo + sombra de recesso ao redor +
  sombra curta do vidro recuado por dentro (0.20, legibilidade intacta).
- Abertura com cantos arredondados (SDF, raio 0.05).
- POWER agora apaga SÓ O VIDRO: TV desligada continua visível com um
  reflexo fraco do ambiente no vidro (imersão do desligar).
- Conteúdo mapeado pro interior do tubo (janela - 2×26px).
