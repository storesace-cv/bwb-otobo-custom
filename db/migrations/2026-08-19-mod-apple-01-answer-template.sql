-- Modelo de resposta Answer `mod-apple-01` (cartão Helpdesk, visual Apple).
-- Fonte versionada: otobo/Custom/Kernel/Output/HTML/Templates/Standard/BWBEmail/mod-apple-01.html
-- Não é envelope de notificação (Default.tt) nem e-mail de «Nova ocorrência registada».
-- Idempotente: actualiza o HTML se o nome já existir; liga às filas BWB/ZS.

INSERT INTO standard_template (
  name, text, content_type, template_type, comments, valid_id,
  create_time, create_by, change_time, change_by
)
SELECT
  'mod-apple-01',
  '<figure class="table" style="width:100%;">
    <table class="apple-style-body" style="background-color:#f5f5f7;border-width:0px;font-family:-apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, Helvetica, Arial, sans-serif;" cellspacing="0">
        <tbody>
            <tr>
                <td style="border-width:0px;padding:50px 20px;">
                    <figure class="table" style="max-width:580px;width:100%;">
                        <table style="background-color:#ffffff;border-radius:20px;border-width:0px;box-shadow:0 4px 24px rgba(0,0,0,0.03);overflow:hidden;" cellspacing="0">
                            <tbody>
                                <tr>
                                    <td style="border-width:0px;padding:44px 40px 24px;">
                                        <div style="color:#1d1d1f;font-size:21px;letter-spacing:-0.4px;text-align:center;">
                                            <strong>Helpdesk</strong>
                                        </div>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="border-width:0px;padding:20px 48px 48px;">
                                        <h1 style="color:#1d1d1f;font-size:34px;letter-spacing:-1.2px;line-height:1.12;margin:0 0 18px;text-align:center;">
                                            <strong>Olá, <OTOBO_CUSTOMER_REALNAME></strong>
                                        </h1>
                                        <p style="color:#1d1d1f;font-size:16px;font-weight:400;letter-spacing:-0.2px;line-height:1.5;margin:0 0 32px;text-align:center;">
                                            Escreva aqui a resposta ao cliente.
                                        </p>
                                        <figure class="table" style="width:100%;">
                                            <table style="background-color:#f5f5f7;border-radius:14px;border-width:0px;margin-bottom:32px;" cellspacing="0">
                                                <tbody>
                                                    <tr>
                                                        <td style="border-width:0px;padding:24px 28px;">
                                                            <p style="color:#86868b;font-size:11px;letter-spacing:0.8px;margin:0 0 10px;text-transform:uppercase;">
                                                                <strong>Resumo da ocorrência</strong>
                                                            </p>
                                                            <p style="color:#1d1d1f;font-size:14px;letter-spacing:-0.1px;line-height:1.42;margin:0 0 6px;">
                                                                <span style="color:#86868b;">Número:</span> &nbsp;<strong><OTOBO_TICKET_TicketNumber></strong>
                                                            </p>
                                                            <p style="color:#1d1d1f;font-size:14px;letter-spacing:-0.1px;line-height:1.42;margin:0;">
                                                                <span style="color:#86868b;">Estado:</span> &nbsp;<strong><OTOBO_TICKET_State></strong>
                                                            </p>
                                                        </td>
                                                    </tr>
                                                </tbody>
                                            </table>
                                        </figure>
                                        <figure class="table">
                                            <table style="border-width:0px;margin-bottom:0;margin-top:0;" cellspacing="0">
                                                <tbody>
                                                    <tr>
                                                        <td style="background-color:#000000;border-radius:24px;border-width:0px;padding:0px;">
                                                            <p style="text-align:center;">
                                                                <a style="color:#ffffff;display:inline-block;font-size:13px;font-weight:400;letter-spacing:-0.1px;padding:11px 26px;text-decoration:none;" target="_blank" rel="noopener noreferrer" href="<OTOBO_CONFIG_HttpType>://<OTOBO_CONFIG_FQDN>/<OTOBO_CONFIG_ScriptAlias>customer.pl?Action=CustomerTicketZoom;TicketID=<OTOBO_TICKET_TicketID>">Abrir no portal&nbsp;</a>
                                                            </p>
                                                        </td>
                                                    </tr>
                                                </tbody>
                                            </table>
                                        </figure>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="background-color:#f5f5f7;border-bottom-width:0px;border-left-width:0px;border-right-width:0px;border-top:1px solid #e8e8ed;padding:32px 48px;text-align:center;">
                                        <p style="color:#86868b;font-size:11px;letter-spacing:-0.1px;line-height:1.5;margin:0;">
                                            Helpdesk StoresAce. Esta mensagem faz parte da conversa do ticket.
                                        </p>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </figure>
                </td>
            </tr>
        </tbody>
    </table>
</figure>
',
  'text/html; charset=utf-8',
  'Answer',
  'Modelo de resposta Helpdesk (cartão). Escolhível em Responder. Não é envelope de notificação.',
  1,
  UTC_TIMESTAMP(), 1, UTC_TIMESTAMP(), 1
FROM DUAL
WHERE NOT EXISTS (
  SELECT 1 FROM standard_template WHERE name = 'mod-apple-01'
);

UPDATE standard_template
SET
  text = '<figure class="table" style="width:100%;">
    <table class="apple-style-body" style="background-color:#f5f5f7;border-width:0px;font-family:-apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, Helvetica, Arial, sans-serif;" cellspacing="0">
        <tbody>
            <tr>
                <td style="border-width:0px;padding:50px 20px;">
                    <figure class="table" style="max-width:580px;width:100%;">
                        <table style="background-color:#ffffff;border-radius:20px;border-width:0px;box-shadow:0 4px 24px rgba(0,0,0,0.03);overflow:hidden;" cellspacing="0">
                            <tbody>
                                <tr>
                                    <td style="border-width:0px;padding:44px 40px 24px;">
                                        <div style="color:#1d1d1f;font-size:21px;letter-spacing:-0.4px;text-align:center;">
                                            <strong>Helpdesk</strong>
                                        </div>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="border-width:0px;padding:20px 48px 48px;">
                                        <h1 style="color:#1d1d1f;font-size:34px;letter-spacing:-1.2px;line-height:1.12;margin:0 0 18px;text-align:center;">
                                            <strong>Olá, <OTOBO_CUSTOMER_REALNAME></strong>
                                        </h1>
                                        <p style="color:#1d1d1f;font-size:16px;font-weight:400;letter-spacing:-0.2px;line-height:1.5;margin:0 0 32px;text-align:center;">
                                            Escreva aqui a resposta ao cliente.
                                        </p>
                                        <figure class="table" style="width:100%;">
                                            <table style="background-color:#f5f5f7;border-radius:14px;border-width:0px;margin-bottom:32px;" cellspacing="0">
                                                <tbody>
                                                    <tr>
                                                        <td style="border-width:0px;padding:24px 28px;">
                                                            <p style="color:#86868b;font-size:11px;letter-spacing:0.8px;margin:0 0 10px;text-transform:uppercase;">
                                                                <strong>Resumo da ocorrência</strong>
                                                            </p>
                                                            <p style="color:#1d1d1f;font-size:14px;letter-spacing:-0.1px;line-height:1.42;margin:0 0 6px;">
                                                                <span style="color:#86868b;">Número:</span> &nbsp;<strong><OTOBO_TICKET_TicketNumber></strong>
                                                            </p>
                                                            <p style="color:#1d1d1f;font-size:14px;letter-spacing:-0.1px;line-height:1.42;margin:0;">
                                                                <span style="color:#86868b;">Estado:</span> &nbsp;<strong><OTOBO_TICKET_State></strong>
                                                            </p>
                                                        </td>
                                                    </tr>
                                                </tbody>
                                            </table>
                                        </figure>
                                        <figure class="table">
                                            <table style="border-width:0px;margin-bottom:0;margin-top:0;" cellspacing="0">
                                                <tbody>
                                                    <tr>
                                                        <td style="background-color:#000000;border-radius:24px;border-width:0px;padding:0px;">
                                                            <p style="text-align:center;">
                                                                <a style="color:#ffffff;display:inline-block;font-size:13px;font-weight:400;letter-spacing:-0.1px;padding:11px 26px;text-decoration:none;" target="_blank" rel="noopener noreferrer" href="<OTOBO_CONFIG_HttpType>://<OTOBO_CONFIG_FQDN>/<OTOBO_CONFIG_ScriptAlias>customer.pl?Action=CustomerTicketZoom;TicketID=<OTOBO_TICKET_TicketID>">Abrir no portal&nbsp;</a>
                                                            </p>
                                                        </td>
                                                    </tr>
                                                </tbody>
                                            </table>
                                        </figure>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="background-color:#f5f5f7;border-bottom-width:0px;border-left-width:0px;border-right-width:0px;border-top:1px solid #e8e8ed;padding:32px 48px;text-align:center;">
                                        <p style="color:#86868b;font-size:11px;letter-spacing:-0.1px;line-height:1.5;margin:0;">
                                            Helpdesk StoresAce. Esta mensagem faz parte da conversa do ticket.
                                        </p>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </figure>
                </td>
            </tr>
        </tbody>
    </table>
</figure>
',
  content_type = 'text/html; charset=utf-8',
  template_type = 'Answer',
  comments = 'Modelo de resposta Helpdesk (cartão). Escolhível em Responder. Não é envelope de notificação.',
  valid_id = 1,
  change_time = UTC_TIMESTAMP(),
  change_by = 1
WHERE name = 'mod-apple-01';

INSERT INTO queue_standard_template
  (queue_id, standard_template_id, create_time, create_by, change_time, change_by)
SELECT q.id, st.id, UTC_TIMESTAMP(), 1, UTC_TIMESTAMP(), 1
FROM queue q
CROSS JOIN standard_template st
WHERE q.name IN ('bwb-in', 'zsangola-in', 'zs-postmaster')
  AND st.name = 'mod-apple-01'
  AND NOT EXISTS (
    SELECT 1 FROM queue_standard_template x
    WHERE x.queue_id = q.id AND x.standard_template_id = st.id
  );
