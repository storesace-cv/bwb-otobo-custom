-- Ceder folhas órfãs do responsável ZS Angola (UserID 4) ao colaborador
-- que já é proprietário do ticket, quando esse colaborador não tem outra
-- sessão aberta. Idempotente. Não altera folhas de colaboradores nem BWB.

UPDATE bwb_work_session s
INNER JOIN ticket t ON t.id = s.ticket_id
INNER JOIN bwb_agent_hierarchy h
    ON h.user_id = t.user_id AND h.responsible_user_id = 4
LEFT JOIN bwb_work_session other
    ON other.user_id = t.user_id
   AND other.end_time IS NULL
   AND other.id <> s.id
SET s.user_id = t.user_id
WHERE s.end_time IS NULL
  AND s.user_id = 4
  AND t.user_id <> 4
  AND other.id IS NULL;
