"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace Core.Agent.BWBAssist
 * @description Sugestões de documentação no Ticket Zoom.
 */
Core.Agent.BWBAssist = (function (TargetNS) {

    function RenderResult($Box, Data) {
        var Html = '';
        if (!Data || !Data.ok || Data.unavailable) {
            var Msg = (Data && Data.message)
                ? Data.message
                : 'O Assistente não está disponível. Use a Ajuda (pesquisa standard).';
            $Box.html('<p class="BWBAssistUnavailableMsg">' + Core.App.EscapeHTML(Msg) + '</p>');
            return;
        }
        if (Data.summary) {
            Html += '<pre class="BWBAssistSummary">' + Core.App.EscapeHTML(Data.summary) + '</pre>';
        }
        if (Data.excerpts && Data.excerpts.length) {
            Html += '<ul class="Tablelike FAQMiniList">';
            Data.excerpts.forEach(function (Hit) {
                var ItemID = Hit.item_id || (String(Hit.doc_id || '').replace(/^faq-/, ''));
                var Link = Core.Config.Get('Baselink') + 'Action=AgentFAQZoom;ItemID=' + encodeURIComponent(ItemID);
                Html += '<li><a href="' + Link + '"><strong>'
                    + Core.App.EscapeHTML(Hit.number || '')
                    + '</strong> — '
                    + Core.App.EscapeHTML(Hit.title || '')
                    + '</a>';
                if (Hit.justification) {
                    Html += '<p class="BWBAssistWhy"><strong>Porquê este artigo:</strong> '
                        + Core.App.EscapeHTML(Hit.justification) + '</p>';
                }
                Html += '</li>';
            });
            Html += '</ul>';
        }
        if (Data.tickets && Data.tickets.length) {
            Html += '<h3>Casos semelhantes</h3><ul class="Tablelike FAQMiniList">';
            Data.tickets.forEach(function (Hit) {
                var TicketID = Hit.ticket_id || String(Hit.doc_id || '').replace(/^ticket-/, '');
                var Link = Core.Config.Get('Baselink') + 'Action=AgentTicketZoom;TicketID=' + encodeURIComponent(TicketID);
                Html += '<li><a href="' + Link + '"><strong>Ticket#'
                    + Core.App.EscapeHTML(Hit.number || '')
                    + '</strong> — '
                    + Core.App.EscapeHTML(Hit.title || '')
                    + '</a>';
                if (Hit.justification) {
                    Html += '<p class="BWBAssistWhy"><strong>Porquê este ticket:</strong> '
                        + Core.App.EscapeHTML(Hit.justification) + '</p>';
                }
                Html += '</li>';
            });
            Html += '</ul>';
        }
        if (!Html) {
            Html = '<p>Sem leituras sugeridas para este ticket.</p>';
        }
        $Box.html(Html);
    }

    TargetNS.Init = function () {
        var $Widget = $('#BWBAssistSuggest');
        if (!$Widget.length) {
            return;
        }
        $Widget.prop('hidden', false);
        $('#BWBAssistSuggestBtn').on('click.BWBAssist', function () {
            var TicketID = $Widget.data('ticket-id');
            var $Result = $('#BWBAssistSuggestResult');
            $Result.html('<p>A procurar…</p>');
            Core.AJAX.FunctionCall(
                Core.Config.Get('Baselink') + 'Action=AgentBWBAssist;Subaction=SuggestFromTicket;TicketID=' + encodeURIComponent(TicketID),
                {},
                function (Response) {
                    RenderResult($Result, Response);
                },
                'json'
            );
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');
    return TargetNS;
}(Core.Agent.BWBAssist || {}));
