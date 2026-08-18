"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.BWBTicketStoreDialog
 * @description
 *      Modal nativo OTOBO (ShowContentDialog) para alterar a loja do ticket
 *      sem mudar a ficha do utilizador de cliente.
 *
 *      Usa <select> nativo (sem Modernize), como o diálogo Associar e-mail.
 */
Core.Agent.BWBTicketStoreDialog = (function (TargetNS) {

    function Baselink() {
        return Core.Config.Get('Baselink') || '';
    }

    function ShowFormError($Form, Message) {
        var $Error = $Form.find('.BWBTicketStoreError');
        $Error.removeClass('Hidden').text(Message || 'Não foi possível gravar a loja.');
    }

    function SubmitForm($Form) {
        var $Submit = $('.Dialog:visible #DialogButton2');
        $Form.find('.BWBTicketStoreError').addClass('Hidden').text('');
        $Submit.prop('disabled', true);

        $.ajax({
            url: $Form.attr('action') || Baselink(),
            type: 'POST',
            dataType: 'json',
            data: $Form.serialize()
        }).done(function (Response) {
            if (!Response || !Response.Success) {
                $Submit.prop('disabled', false);
                ShowFormError($Form, (Response && Response.Error) || 'Não foi possível gravar a loja.');
                return;
            }
            Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
            window.location.href = Baselink() + (Response.Redirect || ('Action=AgentTicketZoom;TicketID=' + $Form.find('input[name="TicketID"]').val()));
        }).fail(function (XHR) {
            var Message = 'Não foi possível gravar a loja.';
            try {
                var Parsed = JSON.parse(XHR.responseText || '{}');
                if (Parsed && Parsed.Error) {
                    Message = Parsed.Error;
                }
            }
            catch (Ignore) {
                // keep default
            }
            $Submit.prop('disabled', false);
            ShowFormError($Form, Message);
        });
    }

    function OpenDialog(URL) {
        var DialogURL = URL
            + (URL.indexOf('?') === -1 ? '?' : ';')
            + 'Dialog=1';

        Core.UI.Dialog.ShowWaitingDialog(
            Core.Language.Translate('Please wait...'),
            Core.Language.Translate('Loading...')
        );

        $.ajax({
            url: DialogURL,
            type: 'GET',
            cache: false,
            dataType: 'html'
        }).done(function (HTML) {
            var Source = typeof HTML === 'string' ? HTML : '';
            var $Content = $('<div/>').append($.parseHTML(Source)).find('#BWBTicketStoreDialog').first();

            Core.UI.Dialog.CloseDialog($('.Dialog:visible'));

            if (!$Content.length) {
                try {
                    var Parsed = JSON.parse(Source);
                    if (Parsed && Parsed.Error) {
                        Core.UI.Dialog.ShowAlert('Alterar loja', Parsed.Error);
                        return;
                    }
                }
                catch (Ignore) {
                    // fall through
                }
                Core.UI.Dialog.ShowAlert(
                    'Alterar loja',
                    'Não foi possível preparar o formulário. Tente novamente.'
                );
                return;
            }

            Core.UI.Dialog.ShowContentDialog(
                $Content[0].outerHTML,
                'Alterar loja',
                '15%',
                'Center',
                true,
                [
                    {
                        Label: 'Cancelar',
                        Type: 'Close',
                        Class: 'CallForAction'
                    },
                    {
                        Label: 'Gravar loja',
                        Type: 'Submit',
                        Class: 'Primary CallForAction',
                        Function: function () {
                            var $Form = $('.Dialog:visible #BWBTicketStoreForm');
                            if (!$Form.length) {
                                return false;
                            }
                            if (!$Form.find('[name="StoreID"]').val()) {
                                ShowFormError($Form, 'Selecione a loja.');
                                return false;
                            }
                            SubmitForm($Form);
                            return false;
                        }
                    }
                ],
                true
            );
        }).fail(function () {
            Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
            Core.UI.Dialog.ShowAlert(
                'Alterar loja',
                'Não foi possível abrir o formulário. Tente novamente.'
            );
        });
    }

    TargetNS.Init = function () {
        document.addEventListener('click', function (Event) {
            var Link = Event.target.closest('a[href*="Action=AgentBWBTicketStore"]');
            if (!Link) {
                return;
            }
            Event.preventDefault();
            Event.stopPropagation();
            if (Event.stopImmediatePropagation) {
                Event.stopImmediatePropagation();
            }
            OpenDialog(Link.href);
        }, true);
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');
    return TargetNS;
}(Core.Agent.BWBTicketStoreDialog || {}));
