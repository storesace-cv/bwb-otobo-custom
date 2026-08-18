"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.BWBWorkSessionDialog
 * @description
 *      Folha de trabalho no zoom do ticket.
 *
 *      Agentes responsáveis: a folha é opcional (menu «Iniciar trabalho»).
 *      Responder / Nota / e-mail do OTOBO ficam intactos — não é obrigatório
 *      abrir folha para comunicar com o cliente.
 *
 *      Colaboradores em Field Mode: mantém o atalho INICIAR/FECHAR TRABALHO
 *      nas acções de artigo (fluxo de terreno).
 */
Core.Agent.BWBWorkSessionDialog = (function (TargetNS) {

    function IsFieldMode() {
        return !!(document.body && document.body.classList.contains('BWBFieldMode'));
    }

    function Place() {
        var Source;
        var IsFinish;
        var Text;

        // Só no Field Mode: no Agent desktop a resposta nativa (Compose/Note)
        // tem de permanecer o caminho óbvio; a folha fica no menu do ticket.
        if (!IsFieldMode()) {
            return;
        }

        Source = document.querySelector('.ActionRow a[href*="Action=AgentBWBWorkSession"]');
        if (!Source) {
            return;
        }

        IsFinish = /Terminar|Fechar/i.test(Source.textContent);
        Text = IsFinish ? 'FECHAR TRABALHO' : 'INICIAR TRABALHO';

        document.querySelectorAll('#ArticleItems .ItemActions ul.Actions').forEach(function (List) {
            var Item;
            var Link;

            if (List.querySelector('.BWBArticleWorkAction')) {
                return;
            }

            Item = document.createElement('li');
            Link = document.createElement('a');
            Link.href = Source.href;
            Link.target = '_blank';
            Link.rel = 'noopener';
            Link.className = 'BWBArticleWorkAction ' + (IsFinish ? 'BWBWorkFinish' : 'BWBWorkStart');
            Link.textContent = Text;
            Item.appendChild(Link);
            List.insertBefore(Item, List.firstChild);
        });

        if (Source.closest('li')) {
            Source.closest('li').style.display = 'none';
        }
        else {
            Source.style.display = 'none';
        }
    }

    TargetNS.Init = function () {
        Place();
        new MutationObserver(Place).observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['class']
        });

        document.addEventListener('click', function (Event) {
            var Link = Event.target.closest('a[href*="Action=AgentBWBWorkSession"]');

            if (!Link) {
                return;
            }

            Event.preventDefault();
            window.open(Link.href, 'BWBWorkSheet');
        }, true);
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');
    return TargetNS;
}(Core.Agent.BWBWorkSessionDialog || {}));
