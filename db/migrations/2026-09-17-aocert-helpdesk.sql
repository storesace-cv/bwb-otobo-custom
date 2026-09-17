-- Ficha Heldesk AOcert por operação (BWB / ZS). Telefones em JSON.
-- Semente = conteúdo de aocert/helpdesk.txt na pen técnica em 2026-09-17
-- (YUMI). Sem valores inventados. Cada operação edita a sua ficha depois.
-- Idempotente.

CREATE TABLE IF NOT EXISTS bwb_aocert_helpdesk (
  operation ENUM('bwb','zs') NOT NULL,
  email VARCHAR(190) NOT NULL,
  portal VARCHAR(240) NOT NULL,
  contacts_json TEXT NOT NULL,
  create_time DATETIME NOT NULL,
  create_by INT NOT NULL,
  change_time DATETIME NOT NULL,
  change_by INT NOT NULL,
  PRIMARY KEY (operation),
  CONSTRAINT fk_bwb_aocert_helpdesk_create_by FOREIGN KEY (create_by) REFERENCES users (id),
  CONSTRAINT fk_bwb_aocert_helpdesk_change_by FOREIGN KEY (change_by) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO bwb_aocert_helpdesk
  (operation, email, portal, contacts_json, create_time, create_by, change_time, change_by)
VALUES
  ('bwb', 'helpdesk@bwb.pt', 'https://helpdesk.bwb.pt/', '["+351 912 420 686"]', UTC_TIMESTAMP(), 1, UTC_TIMESTAMP(), 1),
  ('zs',  'helpdesk@bwb.pt', 'https://helpdesk.bwb.pt/', '["+351 912 420 686"]', UTC_TIMESTAMP(), 1, UTC_TIMESTAMP(), 1)
ON DUPLICATE KEY UPDATE operation = operation;

SET @col_exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bwb_pos_device'
    AND COLUMN_NAME = 'contacts_window_start'
);
SET @sql := IF(
  @col_exists = 0,
  'ALTER TABLE bwb_pos_device ADD COLUMN contacts_window_start DATETIME NULL, ADD COLUMN contacts_window_count INT NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
