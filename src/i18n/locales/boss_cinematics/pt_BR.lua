-- Cinemática de chefe (src/ui/BossCinematic): cartão de nome + epíteto e a
-- dica de pular. Sem travessão (test_locale_dashes). Nomes iguais aos de
-- end_screen.enemy.*; o epíteto é o elemento da entrada de cada um.
return {
    skip = "Pular  {key}",
    carrion_king   = { name = "Rei da Carniça",     epithet = "Soberano dos Corvos" },
    tower_lich     = { name = "Lich da Torre",      epithet = "Senhor das Runas Geladas" },
    abyss_tyrant   = { name = "Tirano do Abismo",   epithet = "Carrasco das Correntes de Fogo" },
    winter_monarch = { name = "Monarca do Inverno", epithet = "Coroa da Nevasca Eterna" },
    rot_colossus   = { name = "Colosso Pútrido",    epithet = "Coração das Raízes Podres" },
    eclipse_queen  = { name = "Rainha do Eclipse",  epithet = "Senhora do Sol Negro" },
}
