---
name: pixellab_mcp
description: Como usar o MCP do PixelLab (gerar sprites/objetos/animações + baixar) — config, fluxo e pegadinhas. A chave NÃO fica versionada; ver seção "Chave".
type: reference
---

# PixelLab MCP — uso no projeto

Serviço de geração de pixel art (sprites, map objects, animações) via MCP.
Usado pras luminárias (`assets/sprites/world/*`), monstros e ícones.

## Configuração do MCP
Bloco em `~/.claude.json` (Win: `C:\Users\<user>\.claude.json`), por projeto,
dentro de `projects/<caminho-do-projeto>/mcpServers`:

```json
"pixellab": {
  "type": "http",
  "url": "https://api.pixellab.ai/mcp",
  "headers": {
    "Authorization": "Bearer <PIXELLAB_KEY>"
  }
}
```

## Chave (NÃO versionar)
`<PIXELLAB_KEY>` é um token Bearer da conta PixelLab. **Não fica no git**
(histórico é permanente; repo pode virar público; o secret-scan do GitHub
revoga chave exposta → quebraria em todas as máquinas).
- Mora em `~/.claude.json` no bloco acima.
- Pra montar em outra máquina: copiar o valor da máquina que já tem, ou
  gerar/rotacionar no painel da PixelLab e colar no `.claude.json` local.
- Ler sem imprimir em log: extrair `headers.Authorization` do `.claude.json`.

## Fluxo de geração (map objects — o que usamos nas luminárias)
1. `create_map_object(description, width, height, view="side",
   outline="selective outline", shading="detailed shading")`
   → retorna `id`, processa ~30-90s. **A API força canvas QUADRADO**
   (pediu 36×72 → vira 36×36!). Poste alto = pedir 72×72 + "full post
   visible from ground to top"; margens sobrando são absorvidas depois.
2. `get_map_object(id)` até `status: completed` (dá URL + preview inline).
3. Animar: `animate_object(object_id, animation_description, frame_count=8,
   mode="v3")` — funciona em map objects; ~6min/job, 8 slots concorrentes.
   `get_object(id)` mostra os grupos de animação + URLs dos frames.
4. **Baixar** (o MCP dá URL backblaze/api; baixo via curl com o Bearer):
   ```
   TOKEN=<extrai de ~/.claude.json>
   curl -sL -H "Authorization: Bearer $TOKEN" \
     "https://api.pixellab.ai/mcp/map-objects/<id>/download" -o saida.png
   # animação: .../objects/<ws>/<objid>/animations/<grp>/unknown/<i>.png (i=0..8)
   ```
   curl `-L` importa: o header sobrevive ao redirect S3 (403 antigo era o
   header seguindo o redirect sem `-L`/reenvio).

## Pegadinhas
- Rate limit: ~8 jobs concorrentes; excesso volta "rate limit exceeded",
  esperar ~15-30s.
- Validar animação por atividade de pixels (v3 às vezes anima fraco/morto)
  — ver [[luminaire_engine]] (lição do Pillow getbbox alpha_only).
- Saldo: `get_balance`.
- Contrato visual/estilo do projeto: [[sprite_design_queue]].
