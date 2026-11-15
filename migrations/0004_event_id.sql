-- Id do evento generate_lead (UUID gerado no navegador), o mesmo do dataLayer, para o Pixel e a CAPI da Meta deduplicarem depois.
ALTER TABLE notify ADD COLUMN event_id TEXT;
