# Frente: audio-plano-pago (Grimoire)

> **CANCELADA pelo Daniel em 10/11/2026** ("eu não quero que troque do Grimoire"). Não gerar nada na ElevenLabs para o Grimoire, não trocar, arquivar nem remixar áudio. Estado conferido pelo Lead após o cancelamento: 0 crédito gasto (660 usados, igual ao início), nenhum commit, nenhum arquivo de áudio do jogo ou do trailer alterado. Grimoire Dev interrompido.

## Frente
_Pedido do Grok Bot em 10/11/2026, com aprovação do Daniel ("essa chave tem que ser usada para tudo, até para o Grimoire"). Nível M. Executor: Grimoire Dev._

### Objetivo
Trocar todo áudio do Grimoire (jogo e trailer de gameplay) que veio do **ElevenLabs grátis** (proíbe uso comercial) por áudio gerado no **plano pago Starter** (uso comercial liberado), mantendo o mesmo estilo. Daqui para frente, todo áudio ElevenLabs do Grimoire sai do plano pago.

### Conta e chave
- Plano Starter: 30.064 créditos/mês, renova em 10/12/2026. Saldo em 10/11 (conferido pelo Lead): 660 usados, ~29.400 livres. Conta compartilhada com as narrações de Social (~300 créditos por vídeo).
- Máximo 3 pedidos simultâneos à API.
- Chave no cofre do OpenBot: `C:\Users\corte\AppData\Roaming\OpenBot\agent-api-keys\.vault\ELEVENLABS_API_KEY`. Leia o arquivo **dentro do próprio comando** (ex.: `ELEVENLABS_API_KEY="$(cat '<caminho>')" node ...`). Nunca imprimir, registrar, copiar para arquivo, `.env` ou commit.
- Skills do repo que leem a chave: `elevenlabs-music-generation` e `sound-effects`.

### Passos
1. **Inventário:** listar todo arquivo de áudio do jogo e do trailer com a origem (ElevenLabs free / ACE-Step / outra / sem origem). Só os ElevenLabs free entram na troca. Os sem origem documentada (5 no jogo, segundo a entrega do trailer-gameplay) vão listados à parte para o Daniel decidir; não regerar sem pedir.
2. **Saldo e custo:** antes de gerar, `GET /v1/user/subscription` e estimativa de créditos. **Se o total passar de ~15.000 créditos**, fazer só o trailer primeiro e parar avisando o Lead com a estimativa do resto.
3. **Gerar** no plano pago, mesmo estilo/duração/função de cada arquivo (prompts antigos, se existirem).
4. **Trocar** no jogo e no trailer. Os arquivos do plano grátis ficam guardados (mover para pasta `_free_arquivado/` ou similar), **nada apagado**.
5. **Remixar o trailer de gameplay** (1080p, 720p, mobile < 25 MB) com nomes novos, sem sobrescrever os atuais. Medir LUFS e true peak como antes.
6. **Proveniência:** um arquivo de registro (ex.: `assets/audio/PROVENIENCIA.md`) com cada arquivo: origem, plano pago, data, prompt.
7. Rodar a suíte de testes do jogo (via `suite_lock.sh`) depois da troca no jogo.

### Limites
- Não aprovado: assinar, pagar ou mudar de plano; publicar na Steam ou em qualquer lugar.
- Só headless, 1 `lovec` por vez, nunca o save real, nunca matar processo por nome.
- Commits em nome de Daniel Cortez, sem Co-Authored-By nem menção a Claude/Grok/Codex, em branch própria, sem push.

### Pronto quando
O trailer e o jogo usam só áudio do plano pago (ou de origem não-ElevenLabs já documentada), com: lista de arquivos trocados, créditos gastos (saldo antes/depois), caminho do trailer novo, suíte passando, e a lista dos arquivos sem origem para o Daniel.

## CANCELADO (10/11/2026)
Cancelado pelo Daniel ("eu não quero que troque do Grimoire"), repassado pelo Grok Bot. Até o cancelamento o Grimoire Dev só fez leitura: inventário dos 543 arquivos de áudio (~1.466 s; ~700 s gerados direto no ElevenLabs free) e uma consulta de saldo (`GET /v1/user/subscription`: 660 de 30.064 usados). Nenhuma geração, 0 crédito gasto, nenhum áudio trocado, movido ou arquivado, trailer não remixado, nenhum commit nem branch.
