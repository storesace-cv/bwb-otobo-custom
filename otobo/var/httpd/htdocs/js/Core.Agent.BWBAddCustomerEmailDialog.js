"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.BWBAddCustomerEmailDialog
 * @description
 *      Modal nativo OTOBO (ShowContentDialog) para associar o remetente
 *      a um utilizador de cliente como e-mail alternativo.
 *
 *      Usa <select> nativo (sem Modernize): o InputField cria um <input>
 *      de pesquisa que o browser trata como campo de e-mail e parte a UX.
 *      ShowContentDialog recria o DOM — handlers só depois de abrir.
 */
Core.Agent.BWBAddCustomerEmailDialog = (function (TargetNS) {

    function Baselink() {
        return Core.Config.Get('Baselink') || '';
    }

    function ShowFormError($Form, Message) {
        var $Error = $Form.find('.BWBAddCustomerEmailError');
        $Error.removeClass('Hidden').text(Message || 'Não foi possível concluir a associação.');
    }

    function LoadCustomerUsers($Form, CustomerID) {
        var $User = $Form.find('#BWBAddCustomerEmailUserLogin');

        $User.prop('disabled', true).empty().append(
            $('<option/>').val('').text(CustomerID ? 'A carregar…' : '— Selecionar o cliente primeiro —')
        );

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
                CustomerID: CustomerID
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
            if (!(Response.Users || []).length) {
                $User.find('option:first').text('— Sem utilizadores neste cliente —');
            }
            $User.prop('disabled', false);
        }).fail(function () {
            $User.empty().append($('<option/>').val('').text('— Erro ao carregar —'));
            ShowFormError($Form, 'Não foi possível carregar os utilizadores de cliente.');
        });
    }

    function BindForm($Dialog) {
        var $Form = $Dialog.find('#BWBAddCustomerEmailForm');
        var $Customer = $Form.find('#BWBAddCustomerEmailCustomerID');

        if (!$Form.length || !$Customer.length) {
            return;
        }

        $Customer.off('change.BWBAddCustomerEmail').on('change.BWBAddCustomerEmail', function () {
            LoadCustomerUsers($Form, $.trim($Customer.val() || ''));
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

            Core.UI.Dialog.ShowContentDialog(
                $Content[0].outerHTML,
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

            BindForm($('.Dialog:visible'));
        }).fail(function () {
            Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
            Core.UI.Dialog.ShowAlert(
                'Associar e-mail a utilizador de cliente',
                'Não foi possível abrir o formulário. Tente novamente.'
            );
        });
    }

    TargetNS.Init = function () {
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
