-- Medição da conversão (regra 21): de onde veio cada cadastro, sem dado pessoal novo.
ALTER TABLE notify ADD COLUMN biome TEXT;
ALTER TABLE notify ADD COLUMN variant TEXT;
ALTER TABLE notify ADD COLUMN source TEXT;
-- Contadores anônimos por dia: visitas (uma por sessão) e cadastros, por versão do botão (A/B) e idioma.
CREATE TABLE IF NOT EXISTS stats_daily (
  day     TEXT NOT NULL,
  variant TEXT NOT NULL,
  lang    TEXT NOT NULL,
  views   INTEGER NOT NULL DEFAULT 0,
  signups INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, variant, lang)
);
