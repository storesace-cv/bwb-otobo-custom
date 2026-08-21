-- Assinatura fila bwb-in: cargo genérico em vez do nome do consultor.
-- Idempotente.

UPDATE signature
SET
    name = 'Assinatura BWB Helpdesk',
    text = REPLACE(text, 'Jorge Peixinho | Consultor IT', 'Suporte Técnico'),
    change_by = 1,
    change_time = NOW()
WHERE id = 2
  AND text LIKE '%Jorge Peixinho | Consultor IT%';
