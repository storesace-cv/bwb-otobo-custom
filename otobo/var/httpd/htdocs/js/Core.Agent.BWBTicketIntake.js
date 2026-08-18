// BWB: Cliente → Utilizador (mesma cascata do Field Mode) nos ecrãs de registo.
"use strict";

(function () {
    Core.Agent = Core.Agent || {};
    Core.Agent.BWBTicketIntake = Core.Agent.BWBTicketIntake || {};

    Core.Agent.BWBTicketIntake.Init = function () {
        var Customer = document.getElementById('BWBCustomerID');
        var User = document.getElementById('BWBCustomerUser');
        if (!Customer || !User || Customer.getAttribute('data-bwb-intake-bound') === '1') {
            return;
        }
        Customer.setAttribute('data-bwb-intake-bound', '1');

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
            if (Placeholder) {
                Placeholder.textContent = CustomerID ? '— Selecionar —' : '— Selecionar o cliente primeiro —';
                Placeholder.selected = true;
            }
            if (CustomerID) {
                var Keep = Array.from(User.options).find(function (Option) {
                    return Option.value && !Option.disabled && Option.getAttribute('data-customer-id') === CustomerID && Option.selected;
                });
                User.value = Keep ? Keep.value : '';
            }
            else {
                User.value = '';
            }
        }

        Customer.addEventListener('change', FilterUsers);
        FilterUsers();
    };

    if (Core.Init && Core.Init.RegisterNamespace) {
        Core.Init.RegisterNamespace('Core.Agent.BWBTicketIntake', '0.1');
    }
}());

if (Core.Init && Core.Init.AddCallback) {
    Core.Init.AddCallback(function () {
        Core.Agent.BWBTicketIntake.Init();
    }, 'Core.Agent.BWBTicketIntake');
}
