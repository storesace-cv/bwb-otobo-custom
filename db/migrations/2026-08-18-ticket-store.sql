-- Loja persistida no ticket (independente da ficha do utilizador de cliente).
-- Aplicar em produção após cópia de segurança da BD. Depois: Maint::Cache::Delete.

CREATE TABLE IF NOT EXISTS bwb_ticket_store (
  ticket_id bigint(20) NOT NULL,
  store_id int(11) NOT NULL,
  create_time datetime NOT NULL,
  create_by int(11) NOT NULL,
  change_time datetime NOT NULL,
  change_by int(11) NOT NULL,
  PRIMARY KEY (ticket_id),
  KEY bwb_ticket_store_store_id (store_id),
  KEY fk_bwb_ticket_store_create_by (create_by),
  KEY fk_bwb_ticket_store_change_by (change_by),
  CONSTRAINT fk_bwb_ticket_store_change_by FOREIGN KEY (change_by) REFERENCES users (id),
  CONSTRAINT fk_bwb_ticket_store_create_by FOREIGN KEY (create_by) REFERENCES users (id),
  CONSTRAINT fk_bwb_ticket_store_store FOREIGN KEY (store_id) REFERENCES bwb_store (id),
  CONSTRAINT fk_bwb_ticket_store_ticket FOREIGN KEY (ticket_id) REFERENCES ticket (id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO dynamic_field (
  internal_field, name, label, field_order, field_type, object_type, config,
  valid_id, create_time, create_by, change_time, change_by
)
SELECT
  0, 'BWBStore', 'Loja', 5, 'Text', 'Ticket',
  CONCAT(
    '---', CHAR(10),
    'DefaultValue: ', CHAR(39), CHAR(39), CHAR(10),
    'Link: ', CHAR(39), CHAR(39), CHAR(10),
    'LinkPreview: ', CHAR(39), CHAR(39), CHAR(10),
    'MultiValue: ~', CHAR(10),
    'Tooltip: Loja persistida no ticket; independente da ficha do utilizador de cliente.', CHAR(10)
  ),
  1, UTC_TIMESTAMP(), 1, UTC_TIMESTAMP(), 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM dynamic_field WHERE name = 'BWBStore');

INSERT INTO bwb_ticket_store (ticket_id, store_id, create_time, create_by, change_time, change_by)
SELECT
  t.id,
  COALESCE(user_store.id, hq.id),
  UTC_TIMESTAMP(),
  COALESCE(NULLIF(t.create_by, 0), 1),
  UTC_TIMESTAMP(),
  COALESCE(NULLIF(t.change_by, 0), 1)
FROM ticket t
LEFT JOIN customer_user cu ON cu.login = t.customer_user_id
LEFT JOIN bwb_store user_store ON user_store.id = cu.bwb_store_id
LEFT JOIN bwb_store hq ON hq.customer_id = t.customer_id AND hq.store_number = 'S'
WHERE COALESCE(user_store.id, hq.id) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM bwb_ticket_store x WHERE x.ticket_id = t.id);

INSERT INTO dynamic_field_value (field_id, object_id, value_text)
SELECT df.id, ts.ticket_id, CONCAT(s.store_number, ' | ', s.name)
FROM bwb_ticket_store ts
INNER JOIN bwb_store s ON s.id = ts.store_id
INNER JOIN dynamic_field df ON df.name = 'BWBStore'
WHERE NOT EXISTS (
  SELECT 1 FROM dynamic_field_value v
  WHERE v.field_id = df.id AND v.object_id = ts.ticket_id
);

UPDATE notification_event_message
SET text = REPLACE(
  text,
  '<strong>Cliente:</strong> &lt;OTOBO_BWB_CUSTOMER_COMPANY&gt;<br><strong>Utilizador:</strong>',
  '<strong>Cliente:</strong> &lt;OTOBO_BWB_CUSTOMER_COMPANY&gt;<br>&lt;OTOBO_BWB_STORE&gt;<br>&lt;OTOBO_BWB_STORE_STREET&gt;<br><strong>Utilizador:</strong>'
)
WHERE notification_id = 1
  AND text LIKE '%<strong>Cliente:</strong> &lt;OTOBO_BWB_CUSTOMER_COMPANY&gt;<br><strong>Utilizador:</strong>%';
