-- CTA do lembrete: botão centrado (#59B3FF, texto branco, cantos arredondados).
-- Ícone Unicode 🔗 dentro do botão (sem fundo; FA não funciona em e-mail).
-- color:#ffffff !important vence .bodyContent a { color:#3a3a3c !important } do Default.tt.
--
-- Pré-requisito:
--   mysqldump otobo notification_event_message > /root/otobo-backups/notification_event_message-before-waiting-button.sql

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
    '<table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin:24px auto;">',
    '<tr><td align="center" bgcolor="#59B3FF" style="background-color:#59B3FF;border-radius:10px;">',
    '<a href="&lt;OTOBO_CONFIG_HttpType&gt;://&lt;OTOBO_CONFIG_FQDN&gt;/&lt;OTOBO_CONFIG_ScriptAlias&gt;customer.pl?Action=CustomerTicketZoom;TicketNumber=&lt;OTOBO_TICKET_TicketNumber&gt;" ',
    'style="display:inline-block;color:#ffffff !important;background-color:#59B3FF;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:700;line-height:1.2;text-decoration:none !important;padding:14px 26px;border-radius:10px;" ',
    'target="_blank" rel="noopener noreferrer">Abrir o ticket no Helpdesk&nbsp;&#128279;</a>',
    '</td></tr></table>',
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
    '<table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin:24px auto;">',
    '<tr><td align="center" bgcolor="#59B3FF" style="background-color:#59B3FF;border-radius:10px;">',
    '<a href="&lt;OTOBO_CONFIG_HttpType&gt;://&lt;OTOBO_CONFIG_FQDN&gt;/&lt;OTOBO_CONFIG_ScriptAlias&gt;customer.pl?Action=CustomerTicketZoom;TicketNumber=&lt;OTOBO_TICKET_TicketNumber&gt;" ',
    'style="display:inline-block;color:#ffffff !important;background-color:#59B3FF;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:700;line-height:1.2;text-decoration:none !important;padding:14px 26px;border-radius:10px;" ',
    'target="_blank" rel="noopener noreferrer">Open the ticket in Helpdesk&nbsp;&#128279;</a>',
    '</td></tr></table>',
    '<p>If you need clarification, reply to this message — we look forward to hearing from you.</p>',
    '<p>Kind regards,<br><strong>Helpdesk</strong></p>'
)
WHERE ne.name = 'BWB - Lembrete aguardar resposta cliente'
  AND nem.language = 'en';
