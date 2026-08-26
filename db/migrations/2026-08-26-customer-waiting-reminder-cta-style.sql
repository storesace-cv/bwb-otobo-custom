-- Destacar o CTA «Abrir o ticket no Helpdesk» no lembrete ao cliente.
-- Cor #59B3FF + sublinhado + símbolo de ligação (Unicode).
-- Nota: Font Awesome não funciona em clientes de e-mail (sem CSS FA no envelope
-- NotificationEvent); o símbolo U+1F517 é o equivalente fiável a fa-link.
-- Inline style com !important para vencer .bodyContent a { color:#3a3a3c !important }
-- do Default.tt.
--
-- Pré-requisito:
--   mysqldump otobo notification_event_message > /root/otobo-backups/notification_event_message-before-waiting-cta.sql

UPDATE notification_event_message nem
INNER JOIN notification_event ne ON ne.id = nem.notification_id
SET nem.text = CONCAT(
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
)
WHERE ne.name = 'BWB - Lembrete aguardar resposta cliente'
  AND nem.language = 'pt';

UPDATE notification_event_message nem
INNER JOIN notification_event ne ON ne.id = nem.notification_id
SET nem.text = CONCAT(
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
)
WHERE ne.name = 'BWB - Lembrete aguardar resposta cliente'
  AND nem.language = 'en';
