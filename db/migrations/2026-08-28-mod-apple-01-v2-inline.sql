-- mod-apple-01 v2: HTML inline-only, sem figure/style/!important.
-- Fonte: otobo/Custom/Kernel/Output/HTML/Templates/Standard/BWBEmail/mod-apple-01.html

UPDATE standard_template
SET
  text = '<!-- bwb-apple-v2 -->
<table class="bwb-answer-card" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;background-color:#f5f5f7;font-family:-apple-system,BlinkMacSystemFont,''Segoe UI'',Roboto,Helvetica,Arial,sans-serif;" role="presentation">
    <tbody>
        <tr>
            <td align="center" style="padding:50px 20px;">
                <table width="580" cellspacing="0" cellpadding="0" border="0" style="width:100%;max-width:580px;background-color:#ffffff;border-radius:20px;" role="presentation">
                    <tbody>
                        <tr>
                            <td style="padding:44px 40px 0;text-align:center;">
                                <strong style="color:#1d1d1f;font-size:21px;letter-spacing:-0.4px;">Helpdesk</strong>
                            </td>
                        </tr>
                        <tr>
                            <td style="padding:44px 40px 40px;">
                                <table width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;background-color:#f5f5f7;border-radius:14px;" role="presentation">
                                    <tbody>
                                        <tr>
                                            <td style="padding:24px 20px;">
                                                <p style="color:#86868b;font-size:11px;letter-spacing:0.8px;margin:0 0 10px;text-transform:uppercase;">
                                                    <strong>Resumo da ocorrência</strong>
                                                </p>
                                                <p style="color:#1d1d1f;font-size:14px;line-height:1.42;margin:0 0 6px;">
                                                    <span style="color:#86868b;">Número:</span> &nbsp;<strong>&lt;OTOBO_TICKET_TicketNumber&gt;</strong>
                                                </p>
                                                <p style="color:#1d1d1f;font-size:14px;line-height:1.42;margin:0;">
                                                    <span style="color:#86868b;">Estado:</span> &nbsp;<strong>&lt;OTOBO_TICKET_State&gt;</strong>
                                                </p>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                                <p style="font-size:16px;line-height:1.5;margin:0;">&nbsp;</p>
                                <p style="color:#1d1d1f;font-size:16px;line-height:1.5;margin:0;">
                                    Olá &lt;OTOBO_CUSTOMER_REALNAME&gt;, Obrigado pelo seu contacto.
                                </p>
                                <p style="font-size:16px;line-height:1.5;margin:0;">&nbsp;</p>
                                <p style="color:#1d1d1f;font-size:16px;line-height:1.5;margin:0;">
                                    Escreva aqui a resposta ao cliente.
                                </p>
                                <p style="font-size:16px;line-height:1.5;margin:0;">&nbsp;</p>
                                <p style="font-size:16px;line-height:1.5;margin:0;">&nbsp;</p>
                                <p style="font-size:16px;line-height:1.5;margin:0;">&nbsp;</p>
                                <p style="font-size:16px;line-height:1.5;margin:0;">&nbsp;</p>
                                <p style="font-size:16px;line-height:1.5;margin:0;">&nbsp;</p>
                                <table width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;" role="presentation">
                                    <tbody>
                                        <tr>
                                            <td style="background-color:#e8e8ed;border-radius:24px;padding:0;">
                                                <p style="text-align:center;margin:0;">
                                                    <a style="color:#1d1d1f;display:inline-block;font-size:13px;padding:11px 26px;text-decoration:none;" target="_blank" rel="noopener noreferrer" href="&lt;OTOBO_CONFIG_HttpType&gt;://&lt;OTOBO_CONFIG_FQDN&gt;/&lt;OTOBO_CONFIG_ScriptAlias&gt;customer.pl?Action=CustomerTicketZoom;TicketID=&lt;OTOBO_TICKET_TicketID&gt;">Abrir no portal&nbsp;</a>
                                                </p>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </td>
                        </tr>
                        <tr>
                            <td style="background-color:#f5f5f7;border-top:1px solid #e8e8ed;padding:32px 40px;text-align:center;">
                                <p style="color:#86868b;font-size:11px;line-height:1.5;margin:0;">
                                    Helpdesk StoresAce. Esta mensagem faz parte da conversa do ticket.
                                </p>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </td>
        </tr>
    </tbody>
</table>
',
  change_time = NOW(),
  change_by = 1
WHERE name = 'mod-apple-01';
