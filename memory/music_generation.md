---
name: Music Generation (ElevenLabs Music via RunComfy) — skill instalada, plano de trilha
description: Skill elevenlabs-music-generation instalada em Set/2026 pra compor as músicas ambientes do jogo (uma por ato, loja, descanso, cada boss). Schema, custo, o que falta pra rodar, e o plano de trilha. ATENÇÃO — não usa a mesma chave dos SFX.
type: project
---

# Music Generation — ElevenLabs Music via RunComfy

Skill instalada a pedido do dono (Set/2026) pra gerar as **músicas ambientes**
do jogo: uma por ato, loja, descanso, e uma por chefe diferente.

```
npx skills add https://github.com/prime-skills/runcomfy-agent-skills \
    --skill elevenlabs-music-generation
```
Instalada em `.agents/skills/elevenlabs-music-generation/`, symlinkada pro
Claude Code. Avaliação de segurança na instalação: Safe, 0 alertas, risco baixo.

## ⚠️ NÃO é a mesma chave dos SFX

Isto é o que mais confunde: apesar do nome, a skill **não** fala com a API do
ElevenLabs direto. Ela chama o **RunComfy CLI**, que é outra conta e outro
faturamento:

```bash
npm i -g @runcomfy/cli          # ou npx -y @runcomfy/cli
runcomfy login                  # ou export RUNCOMFY_TOKEN=<token>
runcomfy run elevenlabs/elevenlabs/music-generation \
  --input '{"prompt":"...","music_length_ms":40000,"force_instrumental":true}' \
  --output-dir ./out
```

A chave de SFX que está na memória automática (`elevenlabs-api-key`, free tier,
endpoint `sound-generation`) **não serve aqui** — ver [[sfx_generation]].

**Estado em Set/2026:** `runcomfy` NÃO está instalado e `RUNCOMFY_TOKEN` não
existe no ambiente. Antes da primeira geração é preciso instalar o CLI e o dono
fazer login / fornecer o token.

## Schema

| Campo | Tipo | Default | Nota |
|---|---|---|---|
| `prompt` | string | — | descrição de estilo **e** letra com marcadores de seção |
| `music_length_ms` | int | 40000 | 5000–300000 (5s a 5min) |
| `force_instrumental` | bool | false | **true pra tudo neste jogo** |
| `output_format` | string | mp3_standard | mp3 ou WAV |

Saída: 44,1 kHz estéreo. **Custo ~US$ 0,0083 por segundo gerado** (30s ≈ $0,25;
60s ≈ $0,50; 5min ≈ $2,49). Escala com a duração — **rascunhar curto, finalizar
longo**.

## Plano de trilha (pedido do dono)

Uma faixa por contexto. Sempre `force_instrumental: true` — o jogo não tem voz.

| Contexto | Direção sugerida |
|---|---|
| Ato 1 — Campos Arruinados | melancólico, corda dedilhada, tambor distante |
| Ato 2 — Planalto / Torre de Pedra | frio, coral etéreo, mais espaço |
| Ato 3 — Abismo | grave, dissonante, percussão pesada |
| Endless (frost / marsh / dusk) | variações mais esparsas dos temas |
| Loja de Relíquias | intimista, cordas suaves, curiosidade |
| Descanso / fogueira | quase silêncio, respiro, calor |
| Boss (um por ato) | tema próprio, tensão crescente |

**Pesquisar a paleta sonora antes de escrever prompt.** O jogo é grimório sépia
inspirado em Slay the Spire e Balatro; a trilha deve conversar com isso, não com
fantasia genérica. Mesma doutrina que vale pra arte: olhar/ouvir a referência
antes de prompt (ver [[ui_layout_invariants]] §4).

## Integração no jogo

Música hoje: `audio/music.mp3` único, carregado em `main.lua` e tocado em loop
pelo `AudioManager` (grupo `music`, volume separado de `sfx` — ver
[[audio_system]]). Trilha por contexto vai exigir:

1. **Loop sem emenda.** Verificar se a saída do modelo faz loop limpo; se não,
   cortar no zero-crossing. `tools/check_sfx.lua` mede envelope e serve pra
   conferir se começo e fim casam em amplitude.
2. **Crossfade na troca** de contexto (entrar na loja, chegar no boss). O
   `AudioManager` hoje não tem crossfade — precisa ser adicionado.
3. **Não recarregar do disco a cada troca** — cachear as faixas.
4. Registrar por SCAN com fallback pro `music.mp3` atual, mesmo contrato dos
   SFX ([[sfx_generation]]): faixa ausente nunca quebra, só não toca.

## Ligações

[[sfx_generation]] · [[audio_system]] · [[card_feel]] · [[project_overview]]
