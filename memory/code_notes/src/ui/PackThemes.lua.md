---
name: code_notes/src/ui/PackThemes.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/PackThemes.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/PackThemes.lua`

Origem: `src/ui/PackThemes.lua` em `7dbdb60d` (18 de 67 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-31 (junto a `local PackThemes = {}`)

> src/ui/PackThemes.lua
> IDENTIDADE VISUAL POR TIPO DE BOOSTER PACK (data-driven).
>
> Fonte das cores: os PNGs reais em assets/sprites/packs/pack_*.png. Cada cor
> abaixo foi AMOSTRADA da arte (contagem de pixels dominantes), nao inventada --
> o comentario ao lado traz o RGB 0-255 original pra auditoria.
>
> Os nomes visiveis NAO ficam aqui: cada tema guarda `labelKey` e o texto vem
> do i18n (namespace `pack`). Tabela de dados nao e lugar de string de tela.
>
> Consumidores:
> src/ui/PackSleeve.lua         -> halo, cantoneiras, faiscas do envelope lacrado
> components/PackOpenScreen.lua -> flash, burst, onda de choque, destrocos,
> cor do titulo, pitch dos SFX
>
> Regra do projeto: NUNCA `if kind == "Arcana"` espalhado pelo codigo -- tudo
> sai desta tabela. Adicionar um tipo novo de pacote = adicionar uma entrada
> aqui (o fallback e Standard).
>
> REMOVIDO (Set/2026): `burstTint` saiu junto com o tint do estouro -- cada
> tipo ganhou sprite proprio (burstFile) e a cor passou a morar na ARTE.
> REMOVIDO (Set/2026): `glowAmount` saiu daqui junto com o halo de silhueta do
> PackSleeve, rejeitado pelo dono (lia como copia fantasma do pacote, nao como
> brilho). `glow` continua, porque ainda pinta onda de choque, lavagem e
> faiscas. Se um dia voltar a existir destaque de prateleira, ele NAO pode ter
> a forma do pacote.
>
> NOTA PRO CONSOLIDADOR: estas cores ainda NAO estao em src/ui/Palette.lua
> (o arquivo estava sob edicao de outro agente). Quando forem promovidas, os
> campos abaixo viram aliases de Palette e esta tabela mantem so os numeros
> de comportamento (escalas, tempos, contagens).

## L35-72 (em `PackThemes`, junto a `PackThemes.KINDS = {`)

> Comportamento dos destrocos ("debris") do estouro. Cada tipo tem uma FISICA
> propria -- e ela, mais que a cor, que faz Espectral parecer diferente de
> Bufao:
> count   - quantos fragmentos
> speed   - velocidade radial inicial (px/s)
> gravity - px/s2 (negativo = SOBE, usado no Espectral)
> life    - segundos ate sumir
> sealFile/sealCode/sealVolume: SOM DEDICADO do rompimento do lacre. Mesma
> historia do burstFile, no eixo sonoro: os 5 tipos dividiam um unico
> `packSealBreak` com pitch diferente, que e a versao auditiva de tingir um
> sprite laranja de verde. Agora cada tipo tem gravacao propria e o pitch
> volta a 1.0 -- o carater mora no arquivo.
>
> sealVolume e calibrado PELO PICO de cada arquivo, nao no olho: os picos
> variam 3.5x entre o Celestial (0.282) e o Padrao/Arcano (1.000), e
> registrar os cinco no mesmo volume faria o Celestial sumir e o Padrao
> estourar. Alvo de pico efetivo 0.42. Como love.Source:setVolume satura em
> 1.0, so da pra ABAIXAR os altos: Bufao e Celestial ficam no teto.
> O Celestial fica 33% abaixo do alvo em amplitude, mas o conteudo dele e
> cauda cristalina (agudos), que a audicao humana percebe bem mais alto que
> banda larga no mesmo pico -- na pratica a diferenca e menor que o numero.
>
> burstFile: ARTE DEDICADA do estouro (160x160). Cada tipo tem a sua, com
> silhueta e densidade proprias -- por isso burstScale e calibrado pelo RAIO
> VISIVEL medido no sprite, nao por gosto: o burst.png original so preenche
> 43px dos 80 do canvas, enquanto os novos chegam a 62-75px. Usar a mesma
> escala pros dois deixaria os novos ~1.6x maiores.
> O desenho NAO E TINGIDO: a cor mora na arte. Aplicar setColor colorido por
> cima foi o que sujava o estouro do Espectral com respingos laranja.
>
> size    - lado do quadrado em px (pixel art: sempre quadrado). Minimo
> util a 1024x768 e ~5px: abaixo disso o destroco vira poeira
> invisivel e a fisica por tipo (que e o que separa os pacotes)
> deixa de ser perceptivel.
> spin     - rad/s de rotacao propria
> drag     - fator de amortecimento por segundo (1 = sem freio)
> additive - true = destroco BRILHA (po arcano, estrela, ectoplasma);
> false/nil = materia opaca (papel, confete)

## L76-78 (em `PackThemes.KINDS`, junto a `Standard = {`)

> ==================================================================
> PADRAO -- pergaminho amarrado com lacre de cera. Sobrio, de papel.
> ==================================================================

## L94-96 (em `titleLo`, junto a `burstScale = 2.55,     -- raio visivel do sprite = 43px -> 110px na tela`)

> o burst_standard nao existe de proposito: pack_standard e pergaminho com
> LACRE DE CERA VERMELHO, e o burst.png original (laranja-
> avermelhado) casa com a cera melhor que qualquer sol amarelo

## L111 (em `debris`, junto a `sealVolume  = 0.42,`)

> pico medido 1.000 -- casado no alvo

## L119-122 (em `debris`, junto a `Buffoon = {`)

> ==================================================================
> BUFAO -- couro carmim, mascara de bode dourada. Circense, quente,
> girando. O estouro e o mais "show de picadeiro" dos cinco.
> ==================================================================

## L132 (em `titleLo`, junto a `sheenAmt     = 0.42,`)

> INTENSIDADE do foil (0 = arte crua): couro envernizado: reflete, mas o carmim tem que continuar fundo

## L152 (em `debris`, junto a `sealVolume  = 1.00,`)

> pico medido 0.402 -- no teto: 96% do alvo

## L160-163 (em `debris`, junto a `Arcana = {`)

> ==================================================================
> ARCANO -- indigo com olho dourado e fitas roxas. Mistico, denso,
> expande devagar como se o ar ficasse pesado.
> ==================================================================

## L193 (em `debris`, junto a `sealVolume  = 0.42,`)

> pico medido 1.000 -- casado no alvo

## L201-204 (em `debris`, junto a `Celestial = {`)

> ==================================================================
> CELESTIAL -- bau azul-noite com cantoneiras de prata e lua com
> estrelas. Frio, amplo, cristalino: o estouro e um CEU abrindo.
> ==================================================================

## L234 (em `debris`, junto a `sealVolume  = 1.00,`)

> pico medido 0.282 -- no teto: 67% do alvo, ver nota

## L242-245 (em `debris`, junto a `Spectral = {`)

> ==================================================================
> ESPECTRAL -- papel esverdeado apodrecido, caveira, cordas. Lento,
> frio, SOBE em vez de cair. Gira ao contrario (inquietante).
> ==================================================================

## L255 (em `titleLo`, junto a `sheenAmt     = 0.32,`)

> INTENSIDADE do foil (0 = arte crua): papel palido de novo: segura, senao o verde escuro vira verde-menta

## L275 (em `debris`, junto a `sealVolume  = 0.94,`)

> pico medido 0.448 -- casado no alvo

## L284-287 (em `debris`, junto a `function PackThemes.registerSealSounds(audio)`)

> Registra os sons de lacre no AudioManager. Idempotente: pula o que ja existe,
> entao pode ser chamado por main.lua no boot OU sob demanda na 1a abertura de
> pacote, sem registrar duas vezes. Cada um entra com o volume calibrado pelo
> seu proprio pico -- este e o ponto do helper existir em vez de 5 linhas soltas.

## L303 (em `PackThemes.registerSealSounds`, junto a `function PackThemes.get(kind)`)

> Tema de um kind, com fallback pra Standard (nunca retorna nil).

## L308-312 (em `PackThemes.get`, junto a `function PackThemes.label(kind)`)

> Rotulo LOCALIZADO do pacote (banner da cinematica e fallback procedural do
> sleeve). O nome nao mora mais na tabela: o tema guarda a CHAVE e a traducao
> vem do i18n, senao o jogo inteiro em alemao mostrava "Pacote Bufao" no
> banner. Require tardio: PackThemes e carregado por modulos de UI que o I18n
> tambem toca, e o require no topo fecha um ciclo.

