/* BWB Customer Ticket Zoom — Responder contextual + Fechar ocorrência.
 * Corre depois do Core.Customer.TicketZoom (BuildArticles / iframes).
 */

"use strict";

var Core = Core || {};
Core.Customer = Core.Customer || {};

/**
 * @namespace
 * @exports TargetNS as Core.Customer.BWBTicketZoom
 */
Core.Customer.BWBTicketZoom = (function (TargetNS) {

    function Root() {
        return document.getElementById('oooContent');
    }

    function ArticleList() {
        return document.querySelectorAll('#oooArticleListExpanded > li.BWBArticle');
    }

    function IsHelpdesk(ArticleEl) {
        return ArticleEl.classList.contains('BWBArticle--agent')
            || ArticleEl.classList.contains('BWBArticle--system');
    }

    function IsWorkSheet(ArticleEl) {
        var Subject = ArticleEl.querySelector('.MessageHeader > .oooSubject');
        return Subject && Subject.textContent.trim() === 'Folha de trabalho';
    }

    function LatestHelpdesk() {
        var List = ArticleList();
        for (var i = 0; i < List.length; i++) {
            if (IsHelpdesk(List[i])) {
                return List[i];
            }
        }
        return null;
    }

    function LatestWorkSheet() {
        var List = ArticleList();
        for (var i = 0; i < List.length; i++) {
            if (IsWorkSheet(List[i])) {
                return List[i];
            }
        }
        return null;
    }

    function EnsureActions(ArticleEl) {
        var Body = ArticleEl.querySelector('.MessageBody');
        if (!Body) {
            return null;
        }
        var Actions = Body.querySelector('.BWBArticleActions');
        if (!Actions) {
            Actions = document.createElement('div');
            Actions.className = 'BWBArticleActions DontPrint';
            Body.appendChild(Actions);
        }
        return Actions;
    }

    function WireReply(ArticleEl) {
        var Native = document.getElementById('ReplyButton');
        if (!Native) {
            return;
        }
        var Actions = EnsureActions(ArticleEl);
        if (!Actions || Actions.querySelector('.BWBReplyHere')) {
            return;
        }
        var Button = document.createElement('button');
        Button.type = 'button';
        Button.className = 'BWBReplyHere';
        Button.innerHTML = '<span>Responder</span><i class="ooofo ooofo-arrow_r2" aria-hidden="true"></i>';
        Button.addEventListener('click', function (Event) {
            Event.preventDefault();
            Native.click();
            Button.style.display = 'none';
        });
        Actions.appendChild(Button);

        var FollowUp = document.getElementById('FollowUp');
        if (FollowUp) {
            var Closes = FollowUp.querySelectorAll('.CloseButton');
            for (var i = 0; i < Closes.length; i++) {
                Closes[i].addEventListener('click', function () {
                    Button.style.display = '';
                });
            }
        }
    }

    function WireClose(ArticleEl, RootEl) {
        var Content = ArticleEl.querySelector('.MessageContent');
        if (!Content || Content.querySelector('.BWBCloseOccurrence')) {
            return;
        }
        var Toolbar = document.createElement('div');
        Toolbar.className = 'BWBWorkSheetToolbar DontPrint';
        var Button = document.createElement('button');
        Button.type = 'button';
        Button.className = 'BWBCloseOccurrence';
        Button.textContent = 'Fechar ocorrência';
        Button.addEventListener('click', function (Event) {
            Event.preventDefault();
            if (!window.confirm('Confirma que a ocorrência está resolvida e pretende encerrá-la?')) {
                return;
            }
            var Form = document.createElement('form');
            Form.method = 'post';
            Form.action = (Core.Config.Get('Baselink') || '') + 'Action=CustomerBWBTicketClose';
            Form.style.display = 'none';

            function Field(Name, Value) {
                var Input = document.createElement('input');
                Input.type = 'hidden';
                Input.name = Name;
                Input.value = Value || '';
                Form.appendChild(Input);
            }

            Field('ChallengeToken', Core.Config.Get('ChallengeToken') || '');
            Field('TicketID', RootEl.getAttribute('data-bwb-ticket-id') || '');
            document.body.appendChild(Form);
            Form.submit();
        });
        Toolbar.appendChild(Button);
        Content.insertBefore(Toolbar, Content.firstChild);
    }

    function Enhance() {
        var RootEl = Root();
        if (!RootEl || !RootEl.classList.contains('BWBTicketZoom')) {
            return;
        }

        var Helpdesk = LatestHelpdesk();
        if (document.getElementById('ReplyButton') && Helpdesk) {
            RootEl.classList.add('BWBReplyContextual');
            WireReply(Helpdesk);
        }

        if (RootEl.getAttribute('data-bwb-can-close') === '1') {
            var Sheet = LatestWorkSheet() || Helpdesk;
            if (Sheet) {
                WireClose(Sheet, RootEl);
            }
        }
    }

    TargetNS.Init = function () {
        // TicketZoom (T) corre depois deste módulo (B) no mesmo APP_MODULE.
        // Adiar para não interferir com BuildArticles / redimensionamento dos iframes.
        window.setTimeout(Enhance, 0);
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Customer.BWBTicketZoom || {}));
