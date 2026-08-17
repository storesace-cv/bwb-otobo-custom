"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

Core.Agent.BWBWorkSessionDialog = (function (TargetNS) {
    function Place() {
        var Source = document.querySelector('.ActionRow a[href*="Action=AgentBWBWorkSession"]');
        var IsFinish;
        var Text;

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
        new MutationObserver(Place).observe(document.body, { childList: true, subtree: true });

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
