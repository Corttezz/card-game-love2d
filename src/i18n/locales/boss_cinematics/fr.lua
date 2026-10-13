-- Cinématique de boss (src/ui/BossCinematic) : carte de nom + épithète et l'indice pour passer.
-- Noms identiques à end_screen.enemy.* ; l'épithète est l'élément de chaque entrée.
-- (Latin-1 seulement : "Coeur", pas "Cœur" — test_locale_glyphs.)
return {
    skip = "Passer  {key}",
    carrion_king   = { name = "Roi Charognard",      epithet = "Souverain des Corbeaux" },
    tower_lich     = { name = "Liche de la Tour",    epithet = "Seigneur des Runes Gelées" },
    abyss_tyrant   = { name = "Tyran de l'Abîme",    epithet = "Geôlier des Chaînes Ardentes" },
    winter_monarch = { name = "Monarque de l'Hiver", epithet = "Couronne du Blizzard Éternel" },
    rot_colossus   = { name = "Colosse Putride",     epithet = "Coeur des Racines Pourries" },
    eclipse_queen  = { name = "Reine de l'Éclipse",  epithet = "Dame du Soleil Noir" },
}
