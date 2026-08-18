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

    var FIELD_NAV = [
        { Action: 'AgentBWBFieldHome', Label: 'Painel de Controlo', Id: 'nav-BWBField-Painel' },
        { Action: 'AgentAppointmentCalendarOverview', Label: 'Calendário', Id: 'nav-BWBField-Calendario' },
        { Action: 'AgentTicketSearch', Label: 'Procurar', Id: 'nav-BWBField-Procurar' },
        { Action: 'AgentFAQExplorer', Label: 'Ajuda', Id: 'nav-BWBField-Ajuda' }
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
        var Nav = document.getElementById('Navigation');
        if (!Nav) {
            return;
        }

        // Hide the full OTOBO agent menu (Dashboard/Customers/Tickets/…).
        Array.from(Nav.children).forEach(function (Item) {
            Item.classList.add('BWBFieldNavHidden');
            Item.classList.remove('BWBFieldNavItem');
        });

        if (Nav.dataset.bwbFieldNavBuilt === '1') {
            Array.from(Nav.querySelectorAll('li.BWBFieldNavItem')).forEach(function (Item) {
                Item.classList.remove('BWBFieldNavHidden');
            });
            return;
        }

        var Base = Core.Config.Get('Baselink') || 'index.pl?';
        FIELD_NAV.forEach(function (Entry) {
            var Li = document.createElement('li');
            Li.id = Entry.Id;
            Li.className = 'BWBFieldNavItem';
            var Link = document.createElement('a');
            Link.href = Base + 'Action=' + Entry.Action;
            Link.textContent = Entry.Label;
            Link.title = Entry.Label;
            Li.appendChild(Link);
            Nav.appendChild(Li);
        });
        Nav.dataset.bwbFieldNavBuilt = '1';
    }

    function EnsureSwitch(Allowed) {
        var Footer = document.getElementById('Footer');
        var Existing = document.getElementById('BWBFieldModeSwitch');
        if (!Allowed) {
            if (Existing) {
                Existing.remove();
            }
            return;
        }
        if (!Footer || Existing) {
            if (Existing) {
                UpdateSwitchLabel(Existing);
            }
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

    function ApplyShell(On, Collaborator) {
        var AllowField = !!Collaborator && !!On;
        document.body.classList.toggle('BWBFieldMode', AllowField);
        if (AllowField) {
            MarkNav();
            var Desktop = document.getElementById('ViewModeSwitch');
            if (Desktop) {
                Desktop.style.display = 'none';
            }
        }
        EnsureSwitch(!!Collaborator);
        UpdateSwitchLabel();
    }

    function DisableFieldForAgent() {
        SetLocalMode(0);
        ApplyShell(0, 0);
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

    function QueryParam(Name) {
        var Search = (window.location.search || '').replace(/^\?/, '');
        var Parts = Search.split(/[;&]/);
        var Index;
        for (Index = 0; Index < Parts.length; Index++) {
            var Pair = Parts[Index].split('=');
            var Key = decodeURIComponent(Pair[0] || '').replace(/\+/g, ' ');
            if (Key === Name) {
                return decodeURIComponent((Pair[1] || '').replace(/\+/g, ' '));
            }
        }
        return '';
    }

    function CurrentTicketID() {
        var FromConfig = Core.Config.Get('TicketID');
        var FromURL = QueryParam('TicketID');
        var Field = document.querySelector('input[name="TicketID"]');
        var FromForm = Field ? Field.value : '';
        return String(FromConfig || FromURL || FromForm || '');
    }

    function SameTicketID(Left, Right) {
        var A = parseInt(Left, 10);
        var B = parseInt(Right, 10);
        return A > 0 && B > 0 && A === B;
    }

    function MaybeForceActiveWork(ActiveWork) {
        if (!document.body.classList.contains('BWBFieldMode') || !ActiveWork || !ActiveWork.TicketID) {
            return;
        }
        if (ActiveWork.Paused) {
            return;
        }
        var Action = Core.Config.Get('Action') || QueryParam('Action') || '';
        var TicketID = CurrentTicketID();
        var TargetID = String(ActiveWork.TicketID);
        // AgentBWBWorkSession does not publish TicketID in Core.Config like TicketZoom.
        // location.replace() of the same URL reloads the page: if we are already
        // on the sheet, never call replace() — even when TicketID cannot be read.
        if (Action === 'AgentBWBWorkSession') {
            if (!TicketID || SameTicketID(TicketID, TargetID)) {
                return;
            }
        }
        if (Action === 'AgentBWBFieldHome') {
            // Bootstrap/SetMode stay; other Field Home views are redirected by server guard.
            return;
        }
        window.location.replace(
            (Core.Config.Get('Baselink') || 'index.pl?')
            + 'Action=AgentBWBWorkSession;TicketID=' + encodeURIComponent(TargetID)
        );
    }

    function BootstrapFromServer(Callback) {
        var Base = Core.Config.Get('Baselink') || 'index.pl?';
        var URL = Base + 'Action=AgentBWBFieldHome;Subaction=Bootstrap';
        fetch(URL, { credentials: 'same-origin' })
            .then(function (Response) { return Response.json(); })
            .then(function (Data) { Callback(Data || {}); })
            .catch(function () { Callback({}); });
    }

    function EnhanceTactileSelect(Select) {
        if (!Select || Select.dataset.bwbTouchReady === '1') {
            return;
        }
        Select.dataset.bwbTouchReady = '1';

        var Label = document.querySelector('label[for="' + Select.id + '"]');
        var Title = Label ? Label.textContent.trim() : 'Selecionar';
        var Trigger = document.createElement('button');
        Trigger.type = 'button';
        Trigger.className = 'BWBTactileSelect';
        Trigger.setAttribute('aria-haspopup', 'listbox');

        function VisibleOptions() {
            return Array.from(Select.options).filter(function (Option) {
                return Option.value && !Option.disabled && !Option.hidden;
            });
        }

        function Refresh() {
            var Option = Select.options[Select.selectedIndex];
            var HasValue = Option && Option.value && !Option.disabled && !Option.hidden;
            Trigger.textContent = HasValue ? Option.textContent : (Select.disabled ? '— Selecionar cliente primeiro —' : '— Selecionar —');
            Trigger.classList.toggle('Placeholder', !HasValue);
            Trigger.disabled = !!Select.disabled;
        }

        Refresh();
        Select.classList.add('BWBNativeSelectHidden');
        Select.insertAdjacentElement('afterend', Trigger);
        Select.addEventListener('change', Refresh);

        Trigger.addEventListener('click', function () {
            if (Select.disabled) {
                return;
            }
            var Options = VisibleOptions();
            if (!Options.length) {
                return;
            }
            var Overlay = document.createElement('div');
            Overlay.className = 'BWBTactileOverlay';
            Overlay.setAttribute('role', 'dialog');
            Overlay.setAttribute('aria-modal', 'true');
            Overlay.setAttribute('aria-label', Title);

            var Panel = document.createElement('div');
            Panel.className = 'BWBTactilePanel';

            var Head = document.createElement('div');
            Head.className = 'BWBTactilePanelHeader';
            var Heading = document.createElement('strong');
            Heading.textContent = Title;
            var Close = document.createElement('button');
            Close.type = 'button';
            Close.className = 'BWBTactileClose';
            Close.setAttribute('aria-label', 'Fechar');
            Close.textContent = '×';
            Head.append(Heading, Close);

            var List = document.createElement('div');
            List.className = 'BWBTactileOptions';
            Options.forEach(function (Option) {
                var Button = document.createElement('button');
                Button.type = 'button';
                Button.className = 'BWBTactileOption' + (Option.selected ? ' Selected' : '');
                Button.textContent = Option.textContent;
                Button.addEventListener('click', function () {
                    Select.value = Option.value;
                    Select.dispatchEvent(new Event('change', { bubbles: true }));
                    Refresh();
                    Overlay.remove();
                    Trigger.focus();
                });
                List.appendChild(Button);
            });

            Panel.append(Head, List);
            Overlay.appendChild(Panel);
            document.body.appendChild(Overlay);
            Close.addEventListener('click', function () {
                Overlay.remove();
                Trigger.focus();
            });
            Overlay.addEventListener('click', function (Event) {
                if (Event.target === Overlay) {
                    Overlay.remove();
                    Trigger.focus();
                }
            });
            setTimeout(function () {
                var Focus = List.querySelector('.Selected') || List.querySelector('button');
                if (Focus) {
                    Focus.focus();
                }
            }, 0);
        });

        Select._BWBRefreshTactile = Refresh;
    }

    function WireCustomerCascade() {
        var Customer = document.getElementById('CustomerID');
        var User = document.getElementById('CustomerUser');
        if (!Customer || !User) {
            return;
        }

        function FilterUsers() {
            var CustomerID = Customer.value || '';
            var Placeholder = User.querySelector('option[value=""]');
            Array.from(User.options).forEach(function (Option) {
                if (!Option.value) {
                    return;
                }
                var Match = CustomerID && Option.getAttribute('data-customer-id') === CustomerID;
                Option.hidden = !Match;
                Option.disabled = !Match;
                if (!Match && Option.selected) {
                    Option.selected = false;
                }
            });
            User.disabled = !CustomerID;
            User.value = '';
            if (Placeholder) {
                Placeholder.textContent = CustomerID ? '— Selecionar —' : '— Selecionar cliente primeiro —';
                Placeholder.selected = true;
            }
            if (typeof User._BWBRefreshTactile === 'function') {
                User._BWBRefreshTactile();
            }
        }

        Customer.addEventListener('change', FilterUsers);
        FilterUsers();
    }

    function EnhanceFieldForms() {
        var Form = document.getElementById('BWBFieldTicketForm');
        if (!Form) {
            return;
        }
        // Always use finger-sized bottom sheet on this form (field creation path).
        Form.querySelectorAll('select').forEach(EnhanceTactileSelect);
        WireCustomerCascade();
    }

    TargetNS.Init = function () {
        if (document.body.classList.contains('LoginScreen')) {
            return;
        }

        var Finish = function (Data) {
            EnhanceFieldForms();
            if (Data && Data.Collaborator && Data.ActiveWork) {
                MaybeForceActiveWork(Data.ActiveWork);
            }
        };

        // Always ask the server: Field Mode is collaborators-only.
        BootstrapFromServer(function (Data) {
            var Collaborator = !!(Data && Data.Collaborator);
            if (!Collaborator) {
                DisableFieldForAgent();
                Finish({});
                return;
            }

            var Local = GetLocalMode();
            var Pref = Data.Preference;

            if (Pref === '0' || Pref === 0) {
                SetLocalMode(0);
                ApplyShell(0, 1);
                Finish(Data);
                return;
            }
            if (Pref === '1' || Pref === 1 || Local === 1) {
                SetLocalMode(1);
                ApplyShell(1, 1);
                MaybeRedirectHome();
                Finish(Data);
                return;
            }
            if (Local === 0) {
                ApplyShell(0, 1);
                Finish(Data);
                return;
            }

            // No preference yet: default Field only for collaborators on field devices.
            if (IsFieldDevice()) {
                SetLocalMode(1);
                PersistServer('field');
                ApplyShell(1, 1);
                MaybeRedirectHome();
                Finish(Data);
                return;
            }

            ApplyShell(0, 1);
            Finish(Data);
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.BWBFieldMode || {}));
