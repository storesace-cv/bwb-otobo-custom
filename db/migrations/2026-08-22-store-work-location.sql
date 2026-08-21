-- Coordenadas GPS nas lojas e no fecho da folha de trabalho.
-- Idempotente (MariaDB 10.11+).

ALTER TABLE bwb_store
  ADD COLUMN IF NOT EXISTS latitude DECIMAL(10,7) NULL AFTER street,
  ADD COLUMN IF NOT EXISTS longitude DECIMAL(10,7) NULL AFTER latitude;

ALTER TABLE bwb_work_session
  ADD COLUMN IF NOT EXISTS finish_latitude DECIMAL(10,7) NULL AFTER observation,
  ADD COLUMN IF NOT EXISTS finish_longitude DECIMAL(10,7) NULL AFTER finish_latitude,
  ADD COLUMN IF NOT EXISTS finish_accuracy_m DECIMAL(10,2) NULL AFTER finish_longitude,
  ADD COLUMN IF NOT EXISTS finish_location_source VARCHAR(16) NULL AFTER finish_accuracy_m,
  ADD COLUMN IF NOT EXISTS finish_location_note TEXT NULL AFTER finish_location_source;
