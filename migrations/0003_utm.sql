-- Origem da primeira visita (padrão de UTM de 14/11/2026): guardada no navegador e gravada com o cadastro. A saída da lista apaga a linha inteira.
ALTER TABLE notify ADD COLUMN utm_source TEXT;
ALTER TABLE notify ADD COLUMN utm_medium TEXT;
ALTER TABLE notify ADD COLUMN utm_campaign TEXT;
ALTER TABLE notify ADD COLUMN utm_content TEXT;
ALTER TABLE notify ADD COLUMN utm_term TEXT;
ALTER TABLE notify ADD COLUMN fbclid TEXT;
