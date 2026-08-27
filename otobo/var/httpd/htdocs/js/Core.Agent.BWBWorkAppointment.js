// --
// BWB: diálogo nativo de marcação (folha, Compose, Pending).
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

Core.Agent.BWBWorkAppointment = (function (TargetNS) {
    var OriginalEditAppointment;
    var SupportedActions = {
        AgentBWBWorkSession: 1,
        AgentTicketCompose: 1,
        AgentTicketPending: 1
    };

    TargetNS.Init = function () {
        var Action = Core.Config.Get('Action');
        if (!SupportedActions[Action]) {
            return;
        }

        var TicketID = Core.Config.Get('TicketID');
        if (!TicketID) {
            return;
        }

        TargetNS.BindScheduleUI(TicketID);
        TargetNS.PatchEditAppointment();
        TargetNS.BindSubmitGuard(TicketID);
    };

    TargetNS.IsWorkSession = function () {
        return Core.Config.Get('Action') === 'AgentBWBWorkSession';
    };

    TargetNS.IsComposeOrPending = function () {
        var Action = Core.Config.Get('Action');
        return Action === 'AgentTicketCompose' || Action === 'AgentTicketPending';
    };

    TargetNS.PatchEditAppointment = function () {
        if (!Core.Agent.AppointmentCalendar || OriginalEditAppointment) {
            return;
        }

        OriginalEditAppointment = Core.Agent.AppointmentCalendar.EditAppointment;
        Core.Agent.AppointmentCalendar.EditAppointment = function (Data) {
            if (!SupportedActions[Core.Config.Get('Action')]) {
                return OriginalEditAppointment.call(Core.Agent.AppointmentCalendar, Data);
            }

            Core.AJAX.FunctionCall(
                Core.Config.Get('CGIHandle'),
                Data,
                function (Response) {
                    if (Response.Success) {
                        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                        TargetNS.RefreshStatus();
                    }
                    else if (Response.Error) {
                        alert(Response.Error);
                    }
                }
            );
        };
    };

    TargetNS.OpenScheduleDialog = function (TicketID) {
        if (!Core.Agent.AppointmentCalendar || !Core.Agent.AppointmentCalendar.OpenEditDialog) {
            return;
        }

        TargetNS.PatchEditAppointment();

        Core.Agent.AppointmentCalendar.OpenEditDialog({
            Start: $.fullCalendar.moment().add(1, 'hours').startOf('hour'),
            End: $.fullCalendar.moment().add(2, 'hours').startOf('hour'),
            PluginKey: '0100-Ticket',
            ObjectID: TicketID
        });
    };

    TargetNS.CheckURL = function () {
        return Core.Config.Get('Baselink') + 'Action=AgentBWBAppointmentCheck;TicketID='
            + encodeURIComponent(Core.Config.Get('TicketID') || '');
    };

    TargetNS.RefreshStatus = function () {
        var Status = document.getElementById('BWBAppointmentStatus');
        if (!Status) {
            return;
        }

        fetch(TargetNS.CheckURL(), {
            method: 'GET',
            credentials: 'same-origin',
            headers: { 'Accept': 'application/json' }
        }).then(function (Response) {
            return Response.json();
        }).then(function (Payload) {
            if (!Payload || !Payload.Success) {
                return;
            }

            Status.textContent = Payload.HasFutureAppointment
                ? ('Marcação registada' + (Payload.StartTimeLabel ? ' — ' + Payload.StartTimeLabel : ''))
                : 'Ainda sem marcação futura';
            Status.className = Payload.HasFutureAppointment
                ? 'BWBAppointmentStatus BWBAppointmentOk'
                : 'BWBAppointmentStatus BWBAppointmentMissing';

            Core.Config.Set('BWBHasFutureAppointment', Payload.HasFutureAppointment ? 1 : 0);

            var Finish = document.getElementById('BWBFinish');
            if (Finish) {
                Finish.disabled = false;
            }
        }).catch(function () {
            /* ignore */
        });
    };

    TargetNS.SelectedRequiresAppointment = function () {
        if (TargetNS.IsWorkSession()) {
            var Result = document.getElementById('Result');
            var State = document.getElementById('State');
            var ResultValue = Result ? Result.value : '';
            var StateValue = State ? State.value : '';
            return ResultValue === 'A aguardar intervenção presencial'
                || (ResultValue === 'Outro' && StateValue === 'Pendente até determinada data');
        }

        var StateID = document.getElementById('StateID');
        if (!StateID) {
            return false;
        }
        var TargetID = String(Core.Config.Get('BWBPendingScheduledStateID') || '');
        return TargetID !== '' && String(StateID.value) === TargetID;
    };

    TargetNS.RefreshVisibility = function () {
        var Block = document.getElementById('AppointmentSchedule');
        if (!Block) {
            return;
        }
        var Show = TargetNS.SelectedRequiresAppointment();
        Block.style.display = Show ? 'block' : 'none';
        TargetNS.ToggleNativePendingFields(!Show);
    };

    TargetNS.ToggleNativePendingFields = function (Show) {
        if (!TargetNS.IsComposeOrPending()) {
            return;
        }

        var NativeRow = document.getElementById('BWBNativePendingRow');
        if (NativeRow) {
            NativeRow.classList.toggle('BWBHiddenPendingRow', !Show);
            if (!Show) {
                NativeRow.style.display = 'none';
            }
            else {
                NativeRow.style.display = '';
            }
        }

        var PendingDate = document.getElementById('Day');
        var PendingHour = document.getElementById('Hour');
        var PendingMinute = document.getElementById('Minute');
        var Year = document.getElementById('Year');
        var Month = document.getElementById('Month');
        var ids = [PendingDate, PendingHour, PendingMinute, Year, Month];
        var display = Show ? '' : 'none';

        ids.forEach(function (El) {
            if (!El) {
                return;
            }
            var Row = El.closest ? El.closest('.Row') : null;
            if (Row && Row.id !== 'BWBNativePendingRow') {
                Row.style.display = display;
            }
            else if (Row && Row.id === 'BWBNativePendingRow') {
                Row.style.display = Show ? '' : 'none';
                Row.classList.toggle('BWBHiddenPendingRow', !Show);
            }
            else {
                El.style.display = display;
            }
        });

        document.querySelectorAll('label[for="Year"], label[for="Day"], label[for="Hour"], label[for="Minute"]').forEach(function (Label) {
            var Row = Label.closest ? Label.closest('.Row') : null;
            if (Row) {
                if (!Show) {
                    Row.style.display = 'none';
                    Row.classList.add('BWBHiddenPendingRow');
                }
                else if (Row.id !== 'BWBNativePendingRow') {
                    Row.style.display = '';
                    Row.classList.remove('BWBHiddenPendingRow');
                }
            }
        });
    };

    TargetNS.BindSubmitGuard = function (TicketID) {
        if (!TargetNS.IsComposeOrPending()) {
            return;
        }

        var Form = document.getElementById('Compose')
            || document.querySelector('form[name="compose"]')
            || document.querySelector('form.Validate');
        if (!Form) {
            Form = document.querySelector('#MainForm form, form#MainForm, form');
        }
        if (!Form) {
            return;
        }

        Form.addEventListener('submit', function (Event) {
            if (!TargetNS.SelectedRequiresAppointment()) {
                return;
            }
            if (Core.Config.Get('BWBHasFutureAppointment')) {
                return;
            }
            Event.preventDefault();
            Event.stopPropagation();
            alert('Para «Pendente com Agendamento» é obrigatório registar uma marcação futura no calendário (botão «Agendar no calendário»).');
            TargetNS.OpenScheduleDialog(TicketID);
        }, true);
    };

    TargetNS.BindScheduleUI = function (TicketID) {
        var Button = document.getElementById('BWBScheduleAppointment');
        if (Button) {
            Button.addEventListener('click', function () {
                TargetNS.OpenScheduleDialog(TicketID);
            });
        }

        var Result = document.getElementById('Result');
        var State = document.getElementById('State');
        var StateID = document.getElementById('StateID');

        if (Result) {
            Result.addEventListener('change', TargetNS.RefreshVisibility);
        }
        if (State) {
            State.addEventListener('change', TargetNS.RefreshVisibility);
        }
        if (StateID) {
            StateID.addEventListener('change', TargetNS.RefreshVisibility);
            $(StateID).on('change', TargetNS.RefreshVisibility);
        }

        TargetNS.RefreshVisibility();
        TargetNS.RefreshStatus();
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.BWBWorkAppointment || {}));
