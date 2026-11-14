-- Cenas de abertura de ato (docs/cenas_de_ato/STYLE.md). Um registro por ato; ato sem registro = sem cena.
-- Arte em assets/sprites/act_intro/act<N>/ (camadas da pintura do PixelLab + loops), SFX em audio/sfx/act_intro/.
-- Coordenadas na tela virtual da cena (480x270).
return {
    [1] = {
        dir = "assets/sprites/act_intro/act1/",
        -- profundidade de cada camada no parallax (0 = parada, 1 = acompanha a câmera)
        parallax = { far = 0.15, ground = 0.55, traveler = 0.6, arch = 1.25 },
        title = { kicker = "act_intro.kicker", name = "act_intro.act1_name", sub = "act_intro.act1_sub" },
        light = { 1.0, 0.86, 0.58 },           -- cor dos raios e da poeira (sol do entardecer)
        rays = { from = { 372, 112 }, count = 4, alpha = 0.075 },
        fog = { y = 138, h = 26, color = { 0.93, 0.80, 0.62 }, alpha = 0.42, speed = 3.0 },
        fog2 = { y = 196, h = 30, color = { 0.80, 0.70, 0.55 }, alpha = 0.18, speed = 5.0 },
        leaves = { count = 16, colors = { { 0.42, 0.55, 0.45 }, { 0.62, 0.58, 0.30 }, { 0.55, 0.38, 0.20 } } },
        dust = { count = 46, box = { 150, 60, 330, 170 } },
        lantern = { x = 285, y = 151, color = { 1.0, 0.72, 0.36 } },
        crows = {
            { at = 1.9, y = 72, scale = 0.5, speed = 34, from = -20 },
            { at = 2.5, y = 86, scale = 0.375, speed = 28, from = -24 },
        },
        sfx = {
            { code = "actIntro1Wind", file = "audio/sfx/act_intro/act1_wind.mp3", at = 0.0, volume = 0.9, loop = true },
            { code = "actIntro1Crows", file = "audio/sfx/act_intro/act1_crows.mp3", at = 2.2, volume = 0.6 },
        },
    },
    -- sino/harpa quando o nome do ato termina de escrever (o mesmo nos 6 atos)
    chime = { code = "actIntroChime", file = "audio/sfx/act_intro/title_chime.mp3", volume = 0.75 },
}
