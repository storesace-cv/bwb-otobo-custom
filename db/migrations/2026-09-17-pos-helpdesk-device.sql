-- Dispositivos POS (pen técnica / PTcert) ligados a uma loja Helpdesk.
-- Idempotente.

CREATE TABLE IF NOT EXISTS bwb_pos_device (
  id INT NOT NULL AUTO_INCREMENT,
  token_hash CHAR(64) NOT NULL,
  customer_id VARCHAR(191) NOT NULL,
  store_id INT NOT NULL,
  customer_user VARCHAR(191) NOT NULL,
  agent_user_id INT NOT NULL,
  status ENUM('active','suspended','revoked') NOT NULL DEFAULT 'active',
  station_number VARCHAR(16) NULL,
  license VARCHAR(191) NULL,
  pos_version VARCHAR(64) NULL,
  pos_release VARCHAR(32) NULL,
  hostname VARCHAR(191) NULL,
  last_seen DATETIME NULL,
  ticket_window_start DATETIME NULL,
  ticket_window_count INT NOT NULL DEFAULT 0,
  create_time DATETIME NOT NULL,
  create_by INT NOT NULL,
  change_time DATETIME NOT NULL,
  change_by INT NOT NULL,
  revoked_time DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY bwb_pos_device_token_hash (token_hash),
  KEY bwb_pos_device_store_id (store_id),
  KEY bwb_pos_device_customer_id (customer_id),
  CONSTRAINT fk_bwb_pos_device_store FOREIGN KEY (store_id) REFERENCES bwb_store (id),
  CONSTRAINT fk_bwb_pos_device_create_by FOREIGN KEY (create_by) REFERENCES users (id),
  CONSTRAINT fk_bwb_pos_device_change_by FOREIGN KEY (change_by) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS bwb_pos_session (
  token_hash CHAR(64) NOT NULL,
  user_id INT NOT NULL,
  remote_addr VARCHAR(64) NOT NULL,
  expires DATETIME NOT NULL,
  PRIMARY KEY (token_hash),
  KEY bwb_pos_session_expires (expires),
  KEY bwb_pos_session_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS bwb_pos_auth_fail (
  remote_addr VARCHAR(64) NOT NULL,
  fail_count INT NOT NULL DEFAULT 0,
  window_start DATETIME NOT NULL,
  PRIMARY KEY (remote_addr)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
