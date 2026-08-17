"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.BWBAddCustomerEmailDialog
 * @description
 *      Modal nativo OTOBO (ShowContentDialog) para associar o remetente
 *      de um ticket a um utilizador de cliente como e-mail alternativo.
 */
Core.Agent.BWBAddCustomerEmailDialog = (function (TargetNS) {

    function Baselink() {
        return Core.Config.Get('Baselink') || '';
    }

    function ShowFormError($Form, Message) {
        var $Error = $Form.find('.BWBAddCustomerEmailError');
        $Error.removeClass('Hidden').text(Message || 'Não foi possível concluir a associação.');
    }

    function BindForm($Root) {
        var $Form = $Root.find('#BWBAddCustomerEmailForm');
        var $Customer = $Form.find('#BWBAddCustomerEmailCustomerID');
        var $User = $Form.find('#BWBAddCustomerEmailUserLogin');

        $Customer.off('change.BWBAddCustomerEmail').on('change.BWBAddCustomerEmail', function () {
            var CustomerID = $Customer.val() || '';
            $User.prop('disabled', true).empty().append(
                $('<option/>').val('').text(CustomerID ? 'A carregar…' : '— Selecionar o cliente primeiro —')
            );
            Core.UI.InputFields.Deactivate($User.parent());
            if (Core.UI.InputFields.IsEnabled($User)) {
                Core.UI.InputFields.Activate($User.parent());
            }
            if (!CustomerID) {
                return;
            }

            $.ajax({
                url: Baselink(),
                type: 'GET',
                dataType: 'json',
                cache: false,
                data: {
                    Action: 'AgentBWBAddCustomerEmail',
                    Subaction: 'CustomerUsers',
                    TicketID: $Form.find('input[name="TicketID"]').val(),
                    CustomerID: CustomerID,
                    Dialog: 1
                }
            }).done(function (Response) {
                $User.empty();
                if (!Response || !Response.Success) {
                    $User.append($('<option/>').val('').text('— Sem utilizadores —'));
                    ShowFormError($Form, (Response && Response.Error) || 'Não foi possível carregar os utilizadores.');
                    return;
                }
                $Form.find('.BWBAddCustomerEmailError').addClass('Hidden').text('');
                $User.append($('<option/>').val('').text('— Selecionar —'));
                $.each(Response.Users || [], function (Index, Item) {
                    $User.append($('<option/>').val(Item.Login).text(Item.Label));
                });
                $User.prop('disabled', false);
                if (Core.UI.InputFields.IsEnabled($User)) {
                    Core.UI.InputFields.Activate($User.parent());
                }
            }).fail(function () {
                $User.empty().append($('<option/>').val('').text('— Erro ao carregar —'));
                ShowFormError($Form, 'Não foi possível carregar os utilizadores de cliente.');
            });
        });
    }

    function SubmitForm($Form) {
        var $Submit = $('.Dialog:visible #DialogButton2');
        $Form.find('.BWBAddCustomerEmailError').addClass('Hidden').text('');
        $Submit.prop('disabled', true);

        $.ajax({
            url: $Form.attr('action') || Baselink(),
            type: 'POST',
            dataType: 'json',
            data: $Form.serialize()
        }).done(function (Response) {
            if (!Response || !Response.Success) {
                $Submit.prop('disabled', false);
                ShowFormError($Form, (Response && Response.Error) || 'Não foi possível concluir a associação.');
                return;
            }
            Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
            window.location.href = Baselink() + (Response.Redirect || ('Action=AgentTicketZoom;TicketID=' + $Form.find('input[name="TicketID"]').val()));
        }).fail(function (XHR) {
            var Message = 'Não foi possível concluir a associação.';
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
            var $Content = $('<div/>').append($.parseHTML(Source)).find('#BWBAddCustomerEmailDialog').first();

            Core.UI.Dialog.CloseDialog($('.Dialog:visible'));

            if (!$Content.length) {
                // Resposta JSON de erro (ex.: endereço já associado).
                try {
                    var Parsed = JSON.parse(Source);
                    if (Parsed && Parsed.Error) {
                        Core.UI.Dialog.ShowAlert('Associar e-mail a utilizador de cliente', Parsed.Error);
                        return;
                    }
                }
                catch (Ignore) {
                    // fall through
                }
                Core.UI.Dialog.ShowAlert(
                    'Associar e-mail a utilizador de cliente',
                    'Não foi possível preparar o formulário. Tente novamente.'
                );
                return;
            }

            BindForm($Content);

            Core.UI.Dialog.ShowContentDialog(
                $Content,
                'Associar e-mail a utilizador de cliente',
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
                        Label: 'Associar e atualizar ticket',
                        Type: 'Submit',
                        Class: 'Primary CallForAction',
                        Function: function () {
                            var $Form = $('.Dialog:visible #BWBAddCustomerEmailForm');
                            if (!$Form.length) {
                                return false;
                            }
                            if (!$Form.find('[name="CustomerID"]').val() || !$Form.find('[name="CustomerUserLogin"]').val()) {
                                ShowFormError($Form, 'Selecione o cliente e o utilizador de cliente.');
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
                'Associar e-mail a utilizador de cliente',
                'Não foi possível abrir o formulário. Tente novamente.'
            );
        });
    }

    TargetNS.Init = function () {
        // Captura na fase de captura: impede navegação/nova aba do menu do ticket.
        document.addEventListener('click', function (Event) {
            var Link = Event.target.closest('a[href*="Action=AgentBWBAddCustomerEmail"]');
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
}(Core.Agent.BWBAddCustomerEmailDialog || {}));
