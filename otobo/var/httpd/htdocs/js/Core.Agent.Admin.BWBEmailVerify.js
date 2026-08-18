"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.Admin.BWBEmailVerify
 * @description
 *      Botão «Verificar» junto dos campos de e-mail na ficha
 *      AdminCustomerUser. Não submete o formulário.
 */
Core.Agent.Admin.BWBEmailVerify = (function (TargetNS) {

    var Fields = '#UserEmail, #BWBAdditionalEmail1, #BWBAdditionalEmail2';

    function Baselink() {
        return Core.Config.Get('Baselink') || '';
    }

    function SetStatus($Status, Kind, Technical, Plain) {
        $Status
            .removeClass('is-valid is-invalid is-inconclusive is-limited')
            .addClass(Kind ? 'is-' + Kind : '')
            .empty();

        if (Technical) {
            $Status.append(
                $('<div class="BWBEmailVerifyTechnical"/>').text(Technical)
            );
        }
        if (Plain) {
            $Status.append(
                $('<div class="BWBEmailVerifyPlain"/>').text(Plain)
            );
        }
    }

    function Verify($Input, $Button, $Status) {
        var Email = $.trim($Input.val() || '');
        if (!Email) {
            SetStatus(
                $Status,
                'invalid',
                'Campo vazio.',
                'Escreva um endereço de e-mail no campo e volte a clicar em Verificar.'
            );
            return;
        }

        $Button.prop('disabled', true);
        SetStatus($Status, 'inconclusive', '', 'A verificar…');

        $.ajax({
            url: Baselink(),
            type: 'POST',
            dataType: 'json',
            cache: false,
            data: {
                Action: 'AdminCustomerUser',
                Subaction: 'VerifyEmail',
                Email: Email,
                ChallengeToken: Core.Config.Get('ChallengeToken')
            }
        }).done(function (Response) {
            var Status = (Response && Response.Status) || 'inconclusive';
            var Technical = (Response && Response.Technical) || '';
            var Message = (Response && Response.Message) || 'Não foi possível verificar o endereço.';
            if (Status !== 'valid' && Status !== 'invalid' && Status !== 'inconclusive' && Status !== 'limited') {
                Status = 'inconclusive';
            }
            SetStatus($Status, Status, Technical, Message);
        }).fail(function () {
            SetStatus(
                $Status,
                'inconclusive',
                'Erro de comunicação.',
                'Não foi possível concluir a verificação. Tente novamente.'
            );
        }).always(function () {
            $Button.prop('disabled', false);
        });
    }

    function Bind($Input, $Button, $Status) {
        if ($Input.data('bwbEmailVerify')) {
            return;
        }
        $Input.data('bwbEmailVerify', 1);
        $Button.on('click.BWBEmailVerify', function (Event) {
            Event.preventDefault();
            Event.stopPropagation();
            Verify($Input, $Button, $Status);
        });
    }

    function Enhance($Input) {
        var Field = $Input.attr('id');
        var $Button = $Input.siblings('.BWBEmailVerifyButton').first();
        var $Status = $Input.siblings('.BWBEmailVerifyStatus').first();

        if (!$Button.length) {
            $Button = $('<button type="button" class="CallForAction BWBEmailVerifyButton"/>')
                .attr('aria-label', 'Verificar endereço de e-mail')
                .attr('data-email-field', Field)
                .append($('<span/>').text('Verificar'));
            $Status = $('<div class="BWBEmailVerifyStatus" role="status" aria-live="polite"/>');
            $Input.after($Status).after($Button);
        }

        if (!$Status.length) {
            $Status = $('<div class="BWBEmailVerifyStatus" role="status" aria-live="polite"/>');
            $Button.after($Status);
        }

        Bind($Input, $Button, $Status);
    }

    TargetNS.Init = function () {
        $(Fields).each(function () {
            Enhance($(this));
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');
    return TargetNS;
}(Core.Agent.Admin.BWBEmailVerify || {}));
