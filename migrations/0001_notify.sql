-- "Me avise no lançamento": só e-mail, idioma e data (mais um token aleatório para a pessoa sair).
CREATE TABLE IF NOT EXISTS notify (
  email      TEXT PRIMARY KEY,
  lang       TEXT NOT NULL,
  created_at TEXT NOT NULL,
  token      TEXT NOT NULL UNIQUE
);
