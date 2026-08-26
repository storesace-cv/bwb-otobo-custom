-- Lembrete diário ao cliente após 3 dias em «Pendente a aguardar cliente».
-- Sem encerramento automático. Agentes deixam de receber lembrete nativo neste estado.
--
-- Pré-requisito: backup
--   mysqldump otobo notification_event notification_event_item notification_event_message ticket \
--     > /root/otobo-backups/customer-waiting-reminder-before.sql
--
-- Reversão:
--   UPDATE notification_event SET valid_id = 2
--     WHERE name = 'BWB - Lembrete aguardar resposta cliente';
--   DELETE FROM notification_event_item
--     WHERE notification_id IN (9, 10) AND event_key = 'StateID'
--       AND event_value IN (
--         SELECT CAST(id AS CHAR) FROM ticket_state
--         WHERE name IN ('Pendente até determinada data', 'Aguardar fornecedor')
--       );
--   (Pending till / until_time do backfill não se reverte automaticamente.)

START TRANSACTION;

-- 1) Restringir lembretes agente (ids 9/10) aos outros estados pending reminder.
--    Com StateID = 12 e 13, o estado 11 («Pendente a aguardar cliente») deixa de os disparar.
INSERT INTO notification_event_item (notification_id, event_key, event_value)
SELECT ne.id, 'StateID', CAST(ts.id AS CHAR)
FROM notification_event ne
CROSS JOIN ticket_state ts
WHERE ne.name IN (
    'Notificação de lembrete de ticket pendente (bloqueado)',
    'Notificação de lembrete de ticket pendente (desbloqueado)'
)
  AND ts.name IN ('Pendente até determinada data', 'Aguardar fornecedor')
  AND NOT EXISTS (
    SELECT 1
    FROM notification_event_item nei
    WHERE nei.notification_id = ne.id
      AND nei.event_key = 'StateID'
      AND nei.event_value = CAST(ts.id AS CHAR)
  );

-- 2) Nova notificação: só cliente, estado «Pendente a aguardar cliente», OncePerDay.
INSERT INTO notification_event (name, valid_id, comments, create_time, create_by, change_time, change_by)
SELECT
    'BWB - Lembrete aguardar resposta cliente',
    1,
    'E-mail diário ao cliente após Pending till (+3 dias). Sem aviso ao agente. Sem fecho automático.',
    UTC_TIMESTAMP(),
    1,
    UTC_TIMESTAMP(),
    1
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM notification_event
    WHERE name = 'BWB - Lembrete aguardar resposta cliente'
);

SET @notif_id := (
    SELECT id FROM notification_event
    WHERE name = 'BWB - Lembrete aguardar resposta cliente'
    LIMIT 1
);

SET @waiting_state_id := (
    SELECT id FROM ticket_state
    WHERE name = 'Pendente a aguardar cliente'
    LIMIT 1
);

-- Itens (idempotente por chave/valor)
INSERT INTO notification_event_item (notification_id, event_key, event_value)
SELECT @notif_id, v.event_key, v.event_value
FROM (
    SELECT 'Events' AS event_key, 'NotificationPendingReminder' AS event_value
    UNION ALL SELECT 'Recipients', 'Customer'
    UNION ALL SELECT 'StateID', CAST(@waiting_state_id AS CHAR)
    UNION ALL SELECT 'OncePerDay', '1'
    UNION ALL SELECT 'IsVisibleForCustomer', '1'
    UNION ALL SELECT 'ArticleAttachmentInclude', '0'
    UNION ALL SELECT 'SendOnOutOfOffice', '1'
    UNION ALL SELECT 'Transports', 'Email'
    UNION ALL SELECT 'TransportEmailTemplate', 'Default'
    UNION ALL SELECT 'VisibleForAgent', '0'
    UNION ALL SELECT 'LanguageID', 'pt'
    UNION ALL SELECT 'LanguageID', 'en'
    UNION ALL SELECT 'NotificationType', 'Ticket'
) AS v
WHERE @notif_id IS NOT NULL
  AND @waiting_state_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM notification_event_item nei
    WHERE nei.notification_id = @notif_id
      AND nei.event_key = v.event_key
      AND nei.event_value = v.event_value
  );

-- Mensagem PT
INSERT INTO notification_event_message (
    notification_id, language, subject, text, content_type
)
SELECT
    @notif_id,
    'pt',
    'Aguardando a sua resposta',
    CONCAT(
        '<p>Olá &lt;OTOBO_NOTIFICATION_RECIPIENT_UserFirstname&gt;,</p>',
        '<p>O pedido <strong>Ticket#&lt;OTOBO_TICKET_TicketNumber&gt;</strong> — «&lt;OTOBO_TICKET_Title&gt;» — continua <strong>à espera da sua resposta</strong>.</p>',
        '<p>Sem a sua confirmação ou informação adicional, <strong>não conseguimos avançar</strong> com este ticket.</p>',
        '<p>Pode:</p>',
        '<ul>',
        '<li><strong>responder a este e-mail</strong>, ou</li>',
        '<li><strong>abrir o pedido no portal</strong> e responder ou, se o assunto já estiver resolvido, <strong>fechar a ocorrência</strong>.</li>',
        '</ul>',
        '<p><a href="&lt;OTOBO_CONFIG_HttpType&gt;://&lt;OTOBO_CONFIG_FQDN&gt;/&lt;OTOBO_CONFIG_ScriptAlias&gt;customer.pl?Action=CustomerTicketZoom;TicketNumber=&lt;OTOBO_TICKET_TicketNumber&gt;" style="color:#59B3FF !important;text-decoration:underline !important;font-weight:700;font-size:14px;" target="_blank" rel="noopener noreferrer">Abrir o ticket no Helpdesk&nbsp;&#128279;</a></p>',
        '<p>Se precisar de esclarecimentos, responda a esta mensagem — ficamos a aguardar.</p>',
        '<p>Com os melhores cumprimentos,<br><strong>Helpdesk</strong></p>'
    ),
    'text/html'
FROM DUAL
WHERE @notif_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM notification_event_message
    WHERE notification_id = @notif_id AND language = 'pt'
  );

-- Mensagem EN (fallback)
INSERT INTO notification_event_message (
    notification_id, language, subject, text, content_type
)
SELECT
    @notif_id,
    'en',
    'Awaiting your reply',
    CONCAT(
        '<p>Hello &lt;OTOBO_NOTIFICATION_RECIPIENT_UserFirstname&gt;,</p>',
        '<p>Ticket <strong>#&lt;OTOBO_TICKET_TicketNumber&gt;</strong> — «&lt;OTOBO_TICKET_Title&gt;» — is still <strong>waiting for your reply</strong>.</p>',
        '<p>Without your confirmation or further information, <strong>we cannot progress</strong> this ticket.</p>',
        '<p>You can:</p>',
        '<ul>',
        '<li><strong>reply to this email</strong>, or</li>',
        '<li><strong>open the ticket in the portal</strong> to reply or, if already resolved, <strong>close the request</strong>.</li>',
        '</ul>',
        '<p><a href="&lt;OTOBO_CONFIG_HttpType&gt;://&lt;OTOBO_CONFIG_FQDN&gt;/&lt;OTOBO_CONFIG_ScriptAlias&gt;customer.pl?Action=CustomerTicketZoom;TicketNumber=&lt;OTOBO_TICKET_TicketNumber&gt;" style="color:#59B3FF !important;text-decoration:underline !important;font-weight:700;font-size:14px;" target="_blank" rel="noopener noreferrer">Open the ticket in Helpdesk&nbsp;&#128279;</a></p>',
        '<p>If you need clarification, reply to this message — we look forward to hearing from you.</p>',
        '<p>Kind regards,<br><strong>Helpdesk</strong></p>'
    ),
    'text/html'
FROM DUAL
WHERE @notif_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM notification_event_message
    WHERE notification_id = @notif_id AND language = 'en'
  );

-- 3) Backfill: tickets já «a aguardar cliente» passam a until_time = agora
--    para o próximo TicketPendingCheck disparar o 1.º lembrete (depois diário via OncePerDay).
UPDATE ticket t
INNER JOIN ticket_state s ON s.id = t.ticket_state_id
SET t.until_time = UNIX_TIMESTAMP(),
    t.change_time = UTC_TIMESTAMP(),
    t.change_by = 1
WHERE s.name = 'Pendente a aguardar cliente';

COMMIT;
