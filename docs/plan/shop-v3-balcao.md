# Loja v3: o Balcão do Mercador

Pedido do dono (13/Out/2026, sobre a captura da loja em 1440p): "embaixo de
cada prateleira tem como se fosse uma estante de madeira. Sem colocar estantes
de verdade em pixel art, seria uma estante de cima e uma de baixo; os itens em
cima dessa estante, de forma bem realista, quando você interage aparece hover
e a descrição do lado direito. Loja bem bonita, bem animada, com várias
interações, novas ofertas, os dados integrados. Algo bem diferente."

## 1. Visão em uma frase

A loja deixa de ser "cartas flutuando sobre tábuas" e vira **o balcão de um
mercador**: uma estante de madeira de dois andares pintada em pixel art, onde
cada oferta é um OBJETO apoiado (carta em pé num suporte, tesoura, bancada,
frasco, fardo), o balcão na frente carrega as ações (sino de novas ofertas,
copo de dados, livro-razão pra seguir viagem) e o pergaminho de inspeção
pendurado à direita mostra o que o cursor toca.

## 2. O que NÃO muda (decisões já tomadas, não regredir)

- Tela cheia, sem modal e sem cenário vazando nas bordas ([`memory/shop_layout.md`]).
  O balcão É o cenário: ocupa a área útil inteira, nada "atrás" dele.
- Layout por ZONAS com `layout()`/`validate()` puros, recalculado por frame
  (resize de graça), 7 tamanhos × 5 idiomas na trava (`test_upgrade_tile`).
- Sem moldura empilhada, sem rótulo de categoria, sem rodapé de dica
  (`HintBar.ENABLED = false`). Informação mora ANCORADA no objeto.
- Objeto, nunca personagem: o mercador não aparece. A loja é o balcão dele.
- Regras econômicas de `ShopSystem` (4 cartas + 3 relíquias + 1 pacote,
  reroll 4+2n, Dados do Escriba 1×/visita, anti save-scum) ficam iguais.
  Toda oferta nova passa pela bateria (`memory/balance_pipeline.md`) antes
  de ligar por padrão.
- Texto só por `I18n.t` nos 5 locales, sem travessão; `UiScale.SCREENS`;
  `NavCursor` em todo objeto clicável; `reducedMotion` tira movimento, não
  informação.

## 3. A cena (camadas, do fundo pra frente)

```
┌ TopBar ──────────────────────────────────────────────────────────────┐
│  parede de madeira escura (véu, sem textura berrante)     ┌────────┐ │
│  ┌── ESTANTE DE CIMA ──────────────────────────┐          │prego   │ │
│  │ [carta][carta][carta][carta] em SUPORTES     │          │        │ │
│  │   etiqueta de preço pendurada em cada uma    │          │ PERGA- │ │
│  ├── PRATELEIRA DE BAIXO ───────────────────────┤  lanterna│ MINHO  │ │
│  │ [tesoura] [bancada] [frasco]   [fardo]       │   (luz)  │ DE     │ │
│  │   objetos apoiados, pacote pendurado no gancho│          │ INSPE- │ │
│  └──────────────────────────────────────────────┘          │ ÇÃO    │ │
│  ══ BALCÃO (tampo) ═══════════════════════════════          │        │ │
│   [sino: novas ofertas $4] [copo de dados]        [livro-razão: seguir]│
└──────────────────────────────────────────────────────────────────────┘
```

Zonas (nomes do `ShopLayout.layout(sw, sh, nCards, nRelics)`):

| zona | o que é | regra |
|---|---|---|
| `wall` | área útil inteira sob a TopBar | fundo; recebe a luz da lanterna |
| `shelfTop` | estante de cima: cartas em pé em suportes | largura = vitrine atual; altura = carta + suporte + etiqueta |
| `shelfBottom` | prateleira de baixo: relíquias apoiadas + gancho do pacote | mesma largura; objetos com "pé" na tábua |
| `counter` | balcão na frente, mais baixo e mais largo que as prateleiras | ações como OBJETOS: sino, copo de dados, livro-razão |
| `scroll` | pergaminho pendurado à direita | o `CardDetailPanel` de hoje, com moldura de pergaminho em vez de coluna |
| `lantern` | lanterna fixa entre estante e pergaminho | fonte da luz âmbar (hoje é um gradiente solto) |

`validate()` exige: `shelfTop ∩ shelfBottom = ∅`, `counter` abaixo das duas,
`scroll` à direita sem interseção, todo objeto com o PÉ dentro da tábua (um
objeto flutuando acima da prateleira é falha de teste, não estilo). Quando
falta espaço (800×600), quem cede é a ESCALA dos objetos, nunca a posição das
bandas.

## 4. Objetos e interações (o "realista" do pedido)

Cada oferta vira um `ShelfItem` (rect, tábua onde apoia, oferta do
`ShopSystem`, estado hover/compra/vendido). Comportamento:

1. **Repouso**: apoiado na tábua, sombra curta no pé, etiqueta de preço
   pendurada por um barbante (1 px) na frente do objeto. Carta usa o suporte
   de madeira (pixel art, 3 variações); relíquia usa a arte do `UpgradeTile`
   sem a placa; pacote pendurado num gancho na ponta da prateleira.
2. **Hover**: o objeto LEVANTA 4–6 px com `Moveable.juice_up` (carta mantém o
   tilt 3D de hoje), a etiqueta balança (pêndulo amortecido, 0,6 s), a
   lanterna "olha" pro objeto (a luz âmbar desloca 10–20 px na direção dele,
   em degraus, nunca contínua) e o pergaminho à direita recebe a descrição
   (comportamento atual do `CardDetailPanel`, só muda a moldura).
3. **Clique com ouro**: a etiqueta é "arrancada" (cai e some), o objeto voa
   pro destino certo (carta → ícone do deck na TopBar, coringa → quadro de
   coringas, relíquia → painel do jogador, pacote → abre o `PackOpenScreen`
   como hoje) e no lugar fica a **marca de poeira** do objeto com um
   "VENDIDO" riscado a giz (i18n). Som: `coinTotalThud` + madeira.
4. **Clique sem ouro**: a etiqueta treme em vermelho 2 vezes e o ouro da
   TopBar pisca (já existe o ouro direcional). Som curto de recusa. Nada de
   toast.
5. **Sino (Novas ofertas)**: o sino balança e toca, as DUAS prateleiras
   deslizam pra fora da tela (esquerda), voltam com os objetos novos entrando
   um a um (stagger 60 ms), preço do sino sobe (4+2n). Com ouro insuficiente
   o sino fica sem badalo (apagado) e o preço em vermelho.
6. **Copo de dados** (Dados do Escriba): objeto no balcão; hover chacoalha
   (som `sceneWoodKnock` baixo); clique abre o modal atual. Depois da jogada
   da visita, os dois dados ficam JOGADOS no balcão mostrando a soma, e o copo
   deitado: a regra "1 jogada por visita" fica visível sem texto.
7. **Livro-razão (Continuar)**: livro fechado no canto direito do balcão com
   a etiqueta "+$N" (juros que vai receber). Hover: a capa abre um pouco.
   Clique: fecha a loja como hoje.
8. **Teclado/gamepad**: cada objeto é `NavCursor.target`; ordem = estante de
   cima → prateleira de baixo → balcão; ação principal = livro-razão.

## 5. Vida ambiente (sem poluir)

- Lanterna: chama em 3 quadros + flicker em degraus (padrão da vida do menu
  v3 e do `LuminaireEngine`), poeira lenta no feixe. É a única fonte de luz.
- Teia de aranha fina num canto da estante de cima (estática).
- Uma mariposa que cruza a lanterna a cada 20–40 s (1 sprite, 4 quadros).
- `reducedMotion`: chama e poeira estáticas, objetos sem levantar, etiquetas
  sem balançar; descrição, preço e "VENDIDO" iguais.

## 6. Ofertas novas (economia), por prioridade

Nenhuma liga por padrão sem bateria antes/depois (`python tools/balance.py`,
sem `--env` = jogo atual; com `--env BALANCE_SHOP_<X>=1` = variante).

1. **Oferta do dia** (F4): 1 objeto sorteado no stream `shop` recebe -25% e
   uma etiqueta vermelha diferente, pendurada torta. Mexe só em preço.
2. **Encomenda** (depois, se a bateria pedir): pagar $N agora pra garantir na
   PRÓXIMA loja uma carta de raridade mínima X (viaja no save). Dá uso ao
   ouro sobrando sem inflar o deck.
3. **Caixa de achados**: 1 carta básica/comum por $1 no canto da prateleira
   de baixo, numa caixinha. Barata de propósito pra quem está quebrado.

A **tesoura** e a **bancada** continuam fixas (decisão do dono).

## 7. Assets (PixelLab, estilo grimório sépia, contorno 1 px, `_style_reference.png`)

| asset | tamanho | uso |
|---|---|---|
| `shop/shelf_top.png`, `shop/shelf_bottom.png` | tileável em X (ponta esq, meio, ponta dir: 3 PNGs cada) | tábuas com suportes/pregos |
| `shop/card_stand_{1,2,3}.png` | 32×16 | suporte de carta em pé |
| `shop/price_tag.png`, `shop/price_tag_sale.png` | 24×16 | etiqueta pendurada (texto por cima) |
| `shop/counter_{left,mid,right}.png` | tileável | tampo do balcão |
| `shop/bell.png` (4 quadros) | 32×32 | sino de novas ofertas |
| `shop/dice_cup.png` (repouso, chacoalho 3q, deitado) + dados 6 faces | 32×32 | Dados do Escriba no balcão |
| `shop/ledger.png` (fechado, entreaberto) | 40×32 | Continuar |
| `shop/lantern.png` (3 quadros de chama) | 32×48 | luz |
| `shop/scroll_frame.png` (9-slice) + `shop/nail.png` | 9-slice | pergaminho de inspeção |
| `shop/dust_mark.png` + giz "VENDIDO" | 64×64 | lugar vazio |
| `shop/hook.png`, `shop/cobweb.png`, `shop/moth.png` (4q) | pequenos | detalhes |

Doutrina: abrir o PNG antes de somar efeito por código; nada de halo ou
cantoneira por cima do que a arte já pinta. Gerar via MCP PixelLab com
objeto-âncora (memória `pixellab-base64-mcp-http`).

## 8. Arquitetura

- `src/ui/shop/ShopLayout.lua` (puro): `layout(sw, sh, nCards, nRelics)` →
  zonas + rect de cada objeto; `validate(L)`; usado pela tela e pelos testes.
- `src/ui/shop/ShopScene.lua`: desenha as camadas (parede, estantes, balcão,
  lanterna, pergaminho), cuida da vida ambiente e das animações de
  compra/sino/dados. Sem regra de economia dentro.
- `src/ui/shop/ShelfItem.lua`: um objeto na prateleira (oferta + rect + tábua
  + estado + juice + etiqueta). Carta usa a `Card` de hoje; relíquia usa a
  arte do `UpgradeTile` (que fica só como fallback do modo recompensa).
- `components/CardRewardScreen.lua` modo `"shop"` passa a DELEGAR draw/update
  /input ao `ShopScene`; o modo recompensa (espólios) não muda nesta entrega.
- `ShopSystem`: ganha `offer.saleDiscount` (oferta do dia) atrás de flag.
- `UiScale.SCREENS` ganha a loja; `NavCursor` por objeto.
- i18n: `shop.sold`, `shop.sale_tag`, `shop.bell_hint` (tooltip do "?"),
  nomes dos objetos do balcão. 5 locales, sem travessão.

## 9. Fases e entregáveis (cada uma com commit, test_all verde e captura)

| fase | entrega | prova |
|---|---|---|
| F1 cena | assets de estante/balcão/pergaminho/lanterna; `ShopLayout` + `validate`; objetos estáticos apoiados; pergaminho de detalhe | `screenshot_shop` em 1024×768 / 1920×1080 / 2560×1440 + 5 idiomas; `test_shop_layout` (7 tamanhos: pé na tábua, zonas disjuntas) |
| F2 interação | hover (levanta, etiqueta balança, luz olha), compra (voa + VENDIDO), sem ouro (treme), sino com deslize, livro-razão | gif de uma compra e de um reroll; `test_shop_scene` (estado vendido, reroll repõe, sem ouro não compra) |
| F3 vida | copo de dados no balcão com dados jogados pós-visita, lanterna/poeira/mariposa, reducedMotion | captura antes/depois dos dados; `test_scribe_dice` cobre o copo |
| F4 oferta do dia | flag + etiqueta + bateria antes/depois | report em `reports/balance/shop-sale-*` |
| F5 fechamento | nav_flow sem mouse pela loja inteira, UiScale, perf (≤ +1 ms de frame em 1440p vs loja atual), docs (`memory/shop_layout.md` → v3) | `love . nav_flow`, `perf_probe :phases` |

Ordem de ataque dos agentes: F1 (arte + layout) e F3-arte (copo, lanterna,
mariposa) em paralelo, por dono de arquivo; F2 depois de F1; F4 em qualquer
momento (é economia + 1 etiqueta).

## 10. Riscos e o que evitar

- Voltar a "caixa sobre cenário": o balcão é a tela, não um painel.
- Objetos "flutuando" por ancoragem vizinho-a-vizinho: pé na tábua é
  invariante testado, como `FOOT_SINK` do inimigo.
- Animação por condição sem trava (regra do `EndTransition`): compra e sino
  são EVENTOS; a lanterna "olhando" é estado, com alvo e perseguição a 4/s.
- Estourar o frame com partícula: poeira e mariposa são 1 sprite batch;
  medir no `perf_probe` antes de fechar.
- Texto cravado ou com travessão: trava `test_no_hardcoded_pt` e
  `test_locale_dashes`.
- Som novo gerado no ElevenLabs free: entra na lista de regeneração
  (`known_gaps §0b`), nunca como asset final.

## 11. Critério de aceite

Em 1 s o jogador lê o que está à venda e quanto custa; tudo que é clicável
PARECE clicável sem texto; nada na tela existe só por ser bonito, exceto a
mariposa; 7 tamanhos × 5 idiomas sem sobreposição; run inteira sem mouse
passa pela loja; frame ≤ loja atual + 1 ms em 1440p.
