// --
// BWB: diálogo nativo de marcação na folha de trabalho (AgentBWBWorkSession).
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

Core.Agent.BWBWorkAppointment = (function (TargetNS) {
    var OriginalEditAppointment;

    TargetNS.Init = function () {
        if (Core.Config.Get('Action') !== 'AgentBWBWorkSession') {
            return;
        }

        var TicketID = Core.Config.Get('TicketID');
        if (!TicketID) {
            return;
        }

        TargetNS.BindScheduleUI(TicketID);
        TargetNS.PatchEditAppointment();
    };

    TargetNS.PatchEditAppointment = function () {
        if (!Core.Agent.AppointmentCalendar || OriginalEditAppointment) {
            return;
        }

        OriginalEditAppointment = Core.Agent.AppointmentCalendar.EditAppointment;
        Core.Agent.AppointmentCalendar.EditAppointment = function (Data) {
            if (Core.Config.Get('Action') !== 'AgentBWBWorkSession') {
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

    TargetNS.RefreshStatus = function () {
        var Status = document.getElementById('BWBAppointmentStatus');
        var Finish = document.getElementById('BWBFinish');
        if (!Status) {
            return;
        }

        var Form = document.getElementById('BWBWorkForm');
        if (!Form) {
            return;
        }

        var Data = new FormData(Form);
        Data.set('Subaction', 'CheckAppointment');

        fetch(Form.action, {
            method: 'POST',
            body: Data,
            credentials: 'same-origin'
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

            if (Finish) {
                Finish.disabled = false;
            }
        }).catch(function () {
            /* ignore */
        });
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
        var Block = document.getElementById('AppointmentSchedule');

        function refreshVisibility() {
            if (!Block) {
                return;
            }
            var ResultValue = Result ? Result.value : '';
            var StateValue = State ? State.value : '';
            var Show = ResultValue === 'A aguardar intervenção presencial'
                || (ResultValue === 'Outro' && StateValue === 'Pendente até determinada data');
            Block.style.display = Show ? 'block' : 'none';
        }

        if (Result) {
            Result.addEventListener('change', refreshVisibility);
        }
        if (State) {
            State.addEventListener('change', refreshVisibility);
        }
        refreshVisibility();
        TargetNS.RefreshStatus();
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.BWBWorkAppointment || {}));
