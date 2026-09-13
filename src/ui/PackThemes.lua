-- src/ui/PackThemes.lua
-- IDENTIDADE VISUAL POR TIPO DE BOOSTER PACK (data-driven).
--
-- Fonte das cores: os PNGs reais em assets/sprites/packs/pack_*.png. Cada cor
-- abaixo foi AMOSTRADA da arte (contagem de pixels dominantes), nao inventada --
-- o comentario ao lado traz o RGB 0-255 original pra auditoria.
--
-- Os nomes visiveis NAO ficam aqui: cada tema guarda `labelKey` e o texto vem
-- do i18n (namespace `pack`). Tabela de dados nao e lugar de string de tela.
--
-- Consumidores:
--   - src/ui/PackSleeve.lua         -> halo, cantoneiras, faiscas do envelope lacrado
--   - components/PackOpenScreen.lua -> flash, burst, onda de choque, destrocos,
--                                      cor do titulo, pitch dos SFX
--
-- Regra do projeto: NUNCA `if kind == "Arcana"` espalhado pelo codigo -- tudo
-- sai desta tabela. Adicionar um tipo novo de pacote = adicionar uma entrada
-- aqui (o fallback e Standard).
--
-- REMOVIDO (Set/2026): `burstTint` saiu junto com o tint do estouro -- cada
-- tipo ganhou sprite proprio (burstFile) e a cor passou a morar na ARTE.
-- REMOVIDO (Set/2026): `glowAmount` saiu daqui junto com o halo de silhueta do
-- PackSleeve, rejeitado pelo dono (lia como copia fantasma do pacote, nao como
-- brilho). `glow` continua, porque ainda pinta onda de choque, lavagem e
-- faiscas. Se um dia voltar a existir destaque de prateleira, ele NAO pode ter
-- a forma do pacote.
--
-- NOTA PRO CONSOLIDADOR: estas cores ainda NAO estao em src/ui/Palette.lua
-- (o arquivo estava sob edicao de outro agente). Quando forem promovidas, os
-- campos abaixo viram aliases de Palette e esta tabela mantem so os numeros
-- de comportamento (escalas, tempos, contagens).

local PackThemes = {}

-- Comportamento dos destrocos ("debris") do estouro. Cada tipo tem uma FISICA
-- propria -- e ela, mais que a cor, que faz Espectral parecer diferente de
-- Bufao:
--   count   - quantos fragmentos
--   speed   - velocidade radial inicial (px/s)
--   gravity - px/s2 (negativo = SOBE, usado no Espectral)
--   life    - segundos ate sumir
-- sealFile/sealCode/sealVolume: SOM DEDICADO do rompimento do lacre. Mesma
--   historia do burstFile, no eixo sonoro: os 5 tipos dividiam um unico
--   `packSealBreak` com pitch diferente, que e a versao auditiva de tingir um
--   sprite laranja de verde. Agora cada tipo tem gravacao propria e o pitch
--   volta a 1.0 -- o carater mora no arquivo.
--
--   sealVolume e calibrado PELO PICO de cada arquivo, nao no olho: os picos
--   variam 3.5x entre o Celestial (0.282) e o Padrao/Arcano (1.000), e
--   registrar os cinco no mesmo volume faria o Celestial sumir e o Padrao
--   estourar. Alvo de pico efetivo 0.42. Como love.Source:setVolume satura em
--   1.0, so da pra ABAIXAR os altos: Bufao e Celestial ficam no teto.
--   O Celestial fica 33% abaixo do alvo em amplitude, mas o conteudo dele e
--   cauda cristalina (agudos), que a audicao humana percebe bem mais alto que
--   banda larga no mesmo pico -- na pratica a diferenca e menor que o numero.
--
-- burstFile: ARTE DEDICADA do estouro (160x160). Cada tipo tem a sua, com
--   silhueta e densidade proprias -- por isso burstScale e calibrado pelo RAIO
--   VISIVEL medido no sprite, nao por gosto: o burst.png original so preenche
--   43px dos 80 do canvas, enquanto os novos chegam a 62-75px. Usar a mesma
--   escala pros dois deixaria os novos ~1.6x maiores.
--   O desenho NAO E TINGIDO: a cor mora na arte. Aplicar setColor colorido por
--   cima foi o que sujava o estouro do Espectral com respingos laranja.
--
--   size    - lado do quadrado em px (pixel art: sempre quadrado). Minimo
--             util a 1024x768 e ~5px: abaixo disso o destroco vira poeira
--             invisivel e a fisica por tipo (que e o que separa os pacotes)
--             deixa de ser perceptivel.
--   spin     - rad/s de rotacao propria
--   drag     - fator de amortecimento por segundo (1 = sem freio)
--   additive - true = destroco BRILHA (po arcano, estrela, ectoplasma);
--              false/nil = materia opaca (papel, confete)

PackThemes.KINDS = {

    -- ==================================================================
    -- PADRAO -- pergaminho amarrado com lacre de cera. Sobrio, de papel.
    -- ==================================================================
    Standard = {
        labelKey  = "pack.kind_standard",
        base       = {0.894, 0.780, 0.627},  -- (228,199,160) pergaminho dominante
        accent     = {0.686, 0.376, 0.310},  -- (175, 96, 79) lacre de cera vermelho-tijolo
        glow       = {0.867, 0.663, 0.435},  -- (221,169,111) dourado-tan das dobras
        flash      = {1.000, 0.960, 0.865},  -- branco morno (papel sob luz)
        titleHi    = {1.000, 0.930, 0.760},
        titleLo    = {0.867, 0.663, 0.435},

        sheenAmt     = 0.28,   -- INTENSIDADE do foil (0 = arte crua): papel fosco quase nao e foil -- e o pacote de cor mais CLARA,
                               -- onde qualquer brilho some no branco e come as tiras de couro
        sparkles     = 4,      -- faiscas orbitando o sleeve
        sparkleSpeed = 0.55,

        burstFile  = "assets/sprites/packs/effects/burst.png",
                               -- o burst_standard nao existe de proposito: pack_standard e pergaminho com
                               -- LACRE DE CERA VERMELHO, e o burst.png original (laranja-
                               -- avermelhado) casa com a cera melhor que qualquer sol amarelo
        burstScale = 2.55,     -- raio visivel do sprite = 43px -> 110px na tela
        burstSpin  = 0.30,     -- rad totais durante o estouro
        burstTime  = 0.50,

        ringScale  = 1.00,     -- multiplicador do raio da onda de choque
        ringTime   = 0.45,

        debris = {
            count = 14, speed = 240, gravity = 520, life = 0.85,
            size = 6, spin = 6.0, drag = 0.90,
        },

        sealFile    = "audio/sfx/pack-seal-standard.mp3",
        sealCode    = "packSeal_standard",
        sealVolume  = 0.42,   -- pico medido 1.000 -- casado no alvo
        sfxAccent   = "sceneRustle",  -- papel rasgando por cima do seal-break
        accentVol   = 0.55,
        accentPitch = 1.00,
        sealPitch   = 1.00,
        revealPitch = 0.90,
    },

    -- ==================================================================
    -- BUFAO -- couro carmim, mascara de bode dourada. Circense, quente,
    -- girando. O estouro e o mais "show de picadeiro" dos cinco.
    -- ==================================================================
    Buffoon = {
        labelKey  = "pack.kind_buffoon",
        base       = {0.537, 0.133, 0.220},  -- (137, 34, 56) couro carmim dominante
        accent     = {0.914, 0.655, 0.165},  -- (233,167, 42) ouro da mascara
        glow       = {0.930, 0.560, 0.160},  -- ouro puxado pro laranja (brilha mais que ouro chapado)
        flash      = {1.000, 0.800, 0.350},
        titleHi    = {1.000, 0.850, 0.300},
        titleLo    = {0.800, 0.230, 0.240},  -- carmim clareado do (137,34,56)

        sheenAmt     = 0.42,   -- INTENSIDADE do foil (0 = arte crua): couro envernizado: reflete, mas o carmim tem que continuar fundo
        sparkles     = 6,
        sparkleSpeed = 1.30,

        burstFile  = "assets/sprites/packs/effects/burst_buffoon.png",
                               -- ouro/carmesim, confete -- o mais DENSO (44% de cobertura)
        burstScale = 2.00,     -- raio visivel do sprite = 63px -> 126px na tela
        burstSpin  = 0.95,     -- gira MUITO: roda de circo
        burstTime  = 0.45,

        ringScale  = 1.15,
        ringTime   = 0.40,

        debris = {  -- confete: muito, rapido, caindo e rodopiando
            count = 26, speed = 360, gravity = 700, life = 0.95,
            size = 6, spin = 11.0, drag = 0.88,
        },

        sealFile    = "audio/sfx/pack-seal-buffoon.mp3",
        sealCode    = "packSeal_buffoon",
        sealVolume  = 1.00,   -- pico medido 0.402 -- no teto: 96% do alvo
        sfxAccent   = "impactFire",
        accentVol   = 0.45,
        accentPitch = 1.05,
        sealPitch   = 0.95,
        revealPitch = 1.05,
    },

    -- ==================================================================
    -- ARCANO -- indigo com olho dourado e fitas roxas. Mistico, denso,
    -- expande devagar como se o ar ficasse pesado.
    -- ==================================================================
    Arcana = {
        labelKey  = "pack.kind_arcana",
        base       = {0.133, 0.184, 0.471},  -- ( 34, 47,120) indigo dominante
        accent     = {0.482, 0.216, 0.498},  -- (123, 55,127) fita roxa
        glow       = {0.660, 0.340, 0.760},  -- roxo da fita puxado pro brilho
        flash      = {0.720, 0.450, 0.950},
        titleHi    = {0.969, 0.835, 0.357},  -- (247,213, 91) ouro claro do olho
        titleLo    = {0.700, 0.420, 0.900},

        sheenAmt     = 0.36,   -- INTENSIDADE do foil (0 = arte crua): seda arcana
        sparkles     = 6,
        sparkleSpeed = 0.40,   -- lento: faiscas "flutuam", nao correm

        burstFile  = "assets/sprites/packs/effects/burst_arcana.png",
                               -- violeta/indigo, runas
        burstScale = 1.95,     -- raio visivel do sprite = 62px -> 121px na tela
        burstSpin  = 0.50,
        burstTime  = 0.60,     -- mais lento que os outros

        ringScale  = 1.05,
        ringTime   = 0.55,

        debris = {  -- po arcano: flutua pra fora, gravidade quase nula
            count = 20, speed = 190, gravity = 60, life = 1.20,
            size = 5, spin = 3.0, drag = 0.82, additive = true,
        },

        sealFile    = "audio/sfx/pack-seal-arcana.mp3",
        sealCode    = "packSeal_arcana",
        sealVolume  = 0.42,   -- pico medido 1.000 -- casado no alvo
        sfxAccent   = "impactArcane",
        accentVol   = 0.50,
        accentPitch = 0.95,
        sealPitch   = 0.92,
        revealPitch = 0.95,
    },

    -- ==================================================================
    -- CELESTIAL -- bau azul-noite com cantoneiras de prata e lua com
    -- estrelas. Frio, amplo, cristalino: o estouro e um CEU abrindo.
    -- ==================================================================
    Celestial = {
        labelKey  = "pack.kind_celestial",
        base       = {0.149, 0.149, 0.333},  -- ( 38, 38, 85) azul-noite dominante
        accent     = {0.541, 0.584, 0.749},  -- (138,149,191) prata das cantoneiras
        glow       = {0.682, 0.702, 0.863},  -- (174,179,220) prata-lavanda (highlight)
        flash      = {0.800, 0.880, 1.000},
        titleHi    = {0.973, 0.922, 0.647},  -- (248,235,165) creme das estrelas
        titleLo    = {0.682, 0.702, 0.863},

        sheenAmt     = 0.36,   -- INTENSIDADE do foil (0 = arte crua): prata polida
        sparkles     = 7,      -- e o pacote das ESTRELAS: mais faiscas
        sparkleSpeed = 0.30,

        burstFile  = "assets/sprites/packs/effects/burst_celestial.png",
                               -- azul-marinho, estilhacos de estrela -- o maior na tela
        burstScale = 2.15,     -- raio visivel do sprite = 65px -> 140px na tela
        burstSpin  = 0.15,     -- quase nao gira -- corpos celestes sao lentos
        burstTime  = 0.65,

        ringScale  = 1.30,     -- anel mais largo, como uma onda estelar
        ringTime   = 0.60,

        debris = {  -- estrelas: voam retas pra fora, sem gravidade, sem freio
            count = 24, speed = 300, gravity = 0, life = 1.10,
            size = 5, spin = 0.0, drag = 0.97, additive = true,
        },

        sealFile    = "audio/sfx/pack-seal-celestial.mp3",
        sealCode    = "packSeal_celestial",
        sealVolume  = 1.00,   -- pico medido 0.282 -- no teto: 67% do alvo, ver nota
        sfxAccent   = "impactHoly",
        accentVol   = 0.45,
        accentPitch = 1.10,
        sealPitch   = 1.08,
        revealPitch = 1.05,
    },

    -- ==================================================================
    -- ESPECTRAL -- papel esverdeado apodrecido, caveira, cordas. Lento,
    -- frio, SOBE em vez de cair. Gira ao contrario (inquietante).
    -- ==================================================================
    Spectral = {
        labelKey  = "pack.kind_spectral",
        base       = {0.706, 0.859, 0.651},  -- (180,219,166) verde palido dominante
        accent     = {0.349, 0.580, 0.353},  -- ( 89,148, 90) verde-musgo do desenho
        glow       = {0.550, 0.950, 0.620},
        flash      = {0.720, 1.000, 0.760},
        titleHi    = {0.850, 1.000, 0.820},
        titleLo    = {0.349, 0.580, 0.353},

        sheenAmt     = 0.32,   -- INTENSIDADE do foil (0 = arte crua): papel palido de novo: segura, senao o verde escuro vira verde-menta
        sparkles     = 5,
        sparkleSpeed = 0.22,   -- o mais lento: assombracao nao tem pressa

        burstFile  = "assets/sprites/packs/effects/burst_spectral.png",
                               -- verde-teal, veus esfarrapados -- sprite mais LARGO no canvas
        burstScale = 1.75,     -- raio visivel do sprite = 75px -> 131px na tela
        burstSpin  = -0.28,    -- ANTI-HORARIO: so este inverte
        burstTime  = 0.80,     -- dissipa devagar, como nevoa

        ringScale  = 0.90,
        ringTime   = 0.75,

        debris = {  -- ectoplasma: SOBE (gravidade negativa), lento, longo
            count = 18, speed = 130, gravity = -160, life = 1.45,
            size = 6, spin = 1.5, drag = 0.86, additive = true,
        },

        sealFile    = "audio/sfx/pack-seal-spectral.mp3",
        sealCode    = "packSeal_spectral",
        sealVolume  = 0.94,   -- pico medido 0.448 -- casado no alvo
        sfxAccent   = "impactDark",
        accentVol   = 0.50,
        accentPitch = 0.85,
        sealPitch   = 0.85,
        revealPitch = 0.88,
    },
}

-- Registra os sons de lacre no AudioManager. Idempotente: pula o que ja existe,
-- entao pode ser chamado por main.lua no boot OU sob demanda na 1a abertura de
-- pacote, sem registrar duas vezes. Cada um entra com o volume calibrado pelo
-- seu proprio pico -- este e o ponto do helper existir em vez de 5 linhas soltas.
function PackThemes.registerSealSounds(audio)
    audio = audio or _G.audioSystem
    if not (audio and audio.loadSound) then return 0 end
    local n = 0
    for _, th in pairs(PackThemes.KINDS) do
        if th.sealCode and th.sealFile
            and not (audio.sources and audio.sources[th.sealCode])
            and love.filesystem.getInfo(th.sealFile) then
            audio:loadSound(th.sealCode, th.sealFile, th.sealVolume or 0.5)
            n = n + 1
        end
    end
    return n
end

-- Tema de um kind, com fallback pra Standard (nunca retorna nil).
function PackThemes.get(kind)
    return PackThemes.KINDS[kind] or PackThemes.KINDS.Standard
end

-- Rotulo LOCALIZADO do pacote (banner da cinematica e fallback procedural do
-- sleeve). O nome nao mora mais na tabela: o tema guarda a CHAVE e a traducao
-- vem do i18n, senao o jogo inteiro em alemao mostrava "Pacote Bufao" no
-- banner. Require tardio: PackThemes e carregado por modulos de UI que o I18n
-- tambem toca, e o require no topo fecha um ciclo.
function PackThemes.label(kind)
    local I18n = require("src.i18n.I18n")
    local th = PackThemes.KINDS[kind]
    if th and th.labelKey then
        return I18n.t(th.labelKey)
    end
    return I18n.t("pack.kind_generic", { kind = tostring(kind or "?") })
end

-- {r,g,b} + alpha -> 4 numeros prontos pro love.graphics.setColor.
function PackThemes.rgba(c, a)
    c = c or {1, 1, 1}
    return c[1], c[2], c[3], a == nil and 1 or a
end

return PackThemes
