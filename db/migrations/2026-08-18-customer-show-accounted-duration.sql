CREATE TABLE IF NOT EXISTS bwb_customer_company_setting (
  customer_id varchar(150) NOT NULL,
  show_accounted_duration tinyint(4) NOT NULL DEFAULT 1,
  create_time datetime NOT NULL,
  create_by int(11) NOT NULL,
  change_time datetime NOT NULL,
  change_by int(11) NOT NULL,
  PRIMARY KEY (customer_id),
  KEY fk_bwb_ccs_create_by (create_by),
  KEY fk_bwb_ccs_change_by (change_by),
  CONSTRAINT fk_bwb_ccs_change_by FOREIGN KEY (change_by) REFERENCES users (id),
  CONSTRAINT fk_bwb_ccs_create_by FOREIGN KEY (create_by) REFERENCES users (id),
  CONSTRAINT fk_bwb_ccs_customer FOREIGN KEY (customer_id) REFERENCES customer_company (customer_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
