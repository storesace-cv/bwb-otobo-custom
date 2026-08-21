-- Calendário de marcações Appointment «BWB» (grupo BWB).
-- Idempotente: só cria se o nome ainda não existir.

INSERT INTO calendar (
  group_id, name, salt_string, color, ticket_appointments, valid_id,
  create_time, create_by, change_time, change_by
)
SELECT
  (SELECT id FROM groups_table WHERE name = 'BWB' LIMIT 1),
  'BWB',
  'BpenB6LaqiwewC2VDVAVoCOf3GZcBDOQiRcJLChiKRmFGkNggeGQZbQJZEFDvbZe',
  '#0071E3',
  NULL,
  1,
  UTC_TIMESTAMP(), 1, UTC_TIMESTAMP(), 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM calendar WHERE name = 'BWB')
  AND EXISTS (SELECT 1 FROM groups_table WHERE name = 'BWB');
