"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.BWBComposeApple
 * @description
 *      No Compose, a saudação da fila (ResponseFormat) fica acima do cartão
 *      mod-apple-01. O filtro Perl já a remove no HTML; isto cobre o CKEditor.
 */
Core.Agent.BWBComposeApple = (function (TargetNS) {

    function IsAppleCard(Root) {
        if (!Root) {
            return false;
        }
        if (Root.classList && Root.classList.contains('bwb-answer-card')) {
            return true;
        }
        if (Root.classList && Root.classList.contains('apple-style-body')) {
            return true;
        }
        return Root.querySelector && !!Root.querySelector('table.bwb-answer-card, table.apple-style-body');
    }

    function FindAppleCardRoot(Wrapper) {
        var Card = Wrapper.querySelector('table.bwb-answer-card, table.apple-style-body');
        if (!Card) {
            return null;
        }

        var Root = Card;
        var ParentFigure = Card.closest('figure');
        if (ParentFigure) {
            Root = ParentFigure;
        }

        while (Root && Root.parentNode && Root.parentNode !== Wrapper) {
            Root = Root.parentNode;
        }
        if (!Root || Root.parentNode !== Wrapper) {
            return null;
        }
        return Root;
    }

    function StripLeadingSalutation(HTML) {
        if (!HTML || (HTML.indexOf('bwb-answer-card') === -1 && HTML.indexOf('apple-style-body') === -1)) {
            return HTML;
        }

        var Wrapper = document.createElement('div');
        Wrapper.innerHTML = HTML;

        var Root = FindAppleCardRoot(Wrapper);
        if (!Root || !IsAppleCard(Root)) {
            return HTML;
        }

        while (Wrapper.firstChild && Wrapper.firstChild !== Root) {
            Wrapper.removeChild(Wrapper.firstChild);
        }

        return Wrapper.innerHTML;
    }

    function ApplyToEditor(Editor) {
        if (!Editor || typeof Editor.getData !== 'function') {
            return;
        }
        var Current = Editor.getData();
        var Next = StripLeadingSalutation(Current);
        if (Next !== Current) {
            Editor.setData(Next);
        }
    }

    TargetNS.Init = function () {
        if (typeof CKEDITOR === 'undefined' || !CKEDITOR.instances || !CKEDITOR.instances.RichText) {
            return;
        }

        var Editor = CKEDITOR.instances.RichText;
        if (Editor.status === 'ready') {
            ApplyToEditor(Editor);
        }
        Editor.on('instanceReady', function () {
            ApplyToEditor(Editor);
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.BWBComposeApple || {}));
