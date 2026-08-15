"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace Core.Agent.BWBFieldMode
 * @memberof Core.Agent
 * @description
 *      Field Mode for on-site collaborators: dark UI shell, reduced nav,
 *      Field↔Mobile switch only (no Desktop while in Field Mode).
 */
Core.Agent.BWBFieldMode = (function (TargetNS) {
    var STORAGE_KEY = 'BWBFieldMode';
    var ALLOWED_NAV = [
        'Action=AgentBWBFieldHome',
        'Action=AgentAppointmentCalendarOverview',
        'Action=AgentAppointmentAgendaOverview',
        'Action=AgentAppointmentList',
        'Action=AgentTicketSearch',
        'Action=AgentSearch',
        'Action=AgentFAQExplorer',
        'Action=AgentFAQSearch'
    ];

    function IsFieldDevice() {
        return window.matchMedia('(hover: none) and (pointer: coarse)').matches
            || window.matchMedia('(max-width: 1024px)').matches;
    }

    function GetLocalMode() {
        try {
            var Value = localStorage.getItem(STORAGE_KEY);
            if (Value === null || typeof Value === 'undefined') {
                return null;
            }
            return parseInt(Value, 10) > 0 ? 1 : 0;
        }
        catch (Exception) {
            return null;
        }
    }

    function SetLocalMode(On) {
        try {
            localStorage.setItem(STORAGE_KEY, On ? '1' : '0');
        }
        catch (Exception) {}
    }

    function PersistServer(Mode) {
        var Handle = (Core.Config.Get('Baselink') || 'index.pl?').replace(/\?$/, '');
        var Token = Core.Config.Get('ChallengeToken') || '';
        var Body = 'Action=AgentBWBFieldHome&Subaction=SetMode&Mode=' + encodeURIComponent(Mode)
            + '&ChallengeToken=' + encodeURIComponent(Token);
        try {
            fetch(Handle, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
                body: Body,
                credentials: 'same-origin'
            });
        }
        catch (Exception) {}
    }

    function MarkNav() {
        var Items = document.querySelectorAll('#Navigation a[href]');
        Items.forEach(function (Link) {
            var Href = Link.getAttribute('href') || '';
            var Allowed = ALLOWED_NAV.some(function (Needle) {
                return Href.indexOf(Needle) !== -1;
            });
            if (Allowed) {
                var Li = Link.closest('li');
                if (Li) {
                    Li.classList.add('BWBFieldNavItem');
                }
            }
        });
    }

    function EnsureSwitch() {
        var Footer = document.getElementById('Footer');
        if (!Footer || document.getElementById('BWBFieldModeSwitch')) {
            return;
        }
        var Link = document.createElement('a');
        Link.id = 'BWBFieldModeSwitch';
        Link.href = '#';
        Link.setAttribute('role', 'button');
        Footer.appendChild(Link);
        UpdateSwitchLabel(Link);
        Link.addEventListener('click', function (Event) {
            Event.preventDefault();
            var Next = document.body.classList.contains('BWBFieldMode') ? 0 : 1;
            SetLocalMode(Next);
            PersistServer(Next ? 'field' : 'mobile');
            window.location.reload();
        });
    }

    function UpdateSwitchLabel(Link) {
        if (!Link) {
            Link = document.getElementById('BWBFieldModeSwitch');
        }
        if (!Link) {
            return;
        }
        if (document.body.classList.contains('BWBFieldMode')) {
            Link.textContent = 'Versão mobile standard';
            Link.style.display = 'inline-flex';
        }
        else if (IsFieldDevice()) {
            Link.textContent = 'Modo de campo';
            Link.style.display = 'inline-flex';
            Link.style.minHeight = '48px';
            Link.style.padding = '10px 16px';
            Link.style.margin = '8px auto';
            Link.style.fontSize = '16px';
        }
        else {
            Link.style.display = 'none';
        }
    }

    function ApplyShell(On) {
        document.body.classList.toggle('BWBFieldMode', !!On);
        if (On) {
            MarkNav();
            var Desktop = document.getElementById('ViewModeSwitch');
            if (Desktop) {
                Desktop.style.display = 'none';
            }
        }
        EnsureSwitch();
        UpdateSwitchLabel();
    }

    function MaybeRedirectHome() {
        if (!document.body.classList.contains('BWBFieldMode')) {
            return;
        }
        var Action = Core.Config.Get('Action') || '';
        if (Action === 'AgentDashboard') {
            window.location.replace((Core.Config.Get('Baselink') || 'index.pl?') + 'Action=AgentBWBFieldHome');
        }
    }

    function BootstrapFromServer(Callback) {
        var Base = Core.Config.Get('Baselink') || 'index.pl?';
        var URL = Base + 'Action=AgentBWBFieldHome;Subaction=Bootstrap';
        fetch(URL, { credentials: 'same-origin' })
            .then(function (Response) { return Response.json(); })
            .then(function (Data) { Callback(Data || {}); })
            .catch(function () { Callback({}); });
    }

    TargetNS.Init = function () {
        if (document.body.classList.contains('LoginScreen')) {
            return;
        }

        var Local = GetLocalMode();
        if (Local === 1) {
            ApplyShell(1);
            MaybeRedirectHome();
            return;
        }
        if (Local === 0) {
            ApplyShell(0);
            EnsureSwitch();
            UpdateSwitchLabel();
            return;
        }

        // No explicit preference yet: default Field for collaborators on field devices.
        if (!IsFieldDevice()) {
            EnsureSwitch();
            UpdateSwitchLabel();
            return;
        }

        BootstrapFromServer(function (Data) {
            if (Data.Preference === '1' || Data.Preference === 1) {
                SetLocalMode(1);
                ApplyShell(1);
                MaybeRedirectHome();
                return;
            }
            if (Data.Preference === '0' || Data.Preference === 0) {
                SetLocalMode(0);
                ApplyShell(0);
                EnsureSwitch();
                UpdateSwitchLabel();
                return;
            }
            if (Data.Collaborator) {
                SetLocalMode(1);
                PersistServer('field');
                ApplyShell(1);
                MaybeRedirectHome();
                return;
            }
            EnsureSwitch();
            UpdateSwitchLabel();
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.BWBFieldMode || {}));
