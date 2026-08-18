-- Associar modelos de resposta (Answer) às filas BWB/ZS.
-- Sem isto, o OTOBO não mostra «Responder» / «Responder a todos» nas acções do artigo.
-- Verificado em produção 2026-08-17: bwb-in e zs-postmaster não tinham ligações;
-- zsangola-in já tinha «Resposta em branco».

INSERT IGNORE INTO queue_standard_template
  (queue_id, standard_template_id, create_time, create_by, change_time, change_by)
SELECT q.id, st.id, UTC_TIMESTAMP(), 1, UTC_TIMESTAMP(), 1
FROM queue q
CROSS JOIN standard_template st
WHERE q.name IN ('bwb-in', 'zs-postmaster')
  AND st.template_type = 'Answer'
  AND st.valid_id = 1
  AND NOT EXISTS (
    SELECT 1 FROM queue_standard_template x
    WHERE x.queue_id = q.id AND x.standard_template_id = st.id
  );
