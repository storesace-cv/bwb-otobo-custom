"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

Core.Agent.Admin.BWBStoreUser = (function (TargetNS) {
    TargetNS.Init = function () {
        var $Original = $('#UserStoreID'),
            $Select,
            CurrentStoreID,
            LastCustomerID = null;

        if (!$Original.length) {
            return;
        }

        CurrentStoreID = String($Original.val() || '');
        $Select = $('<select/>', {
            id: 'UserStoreID',
            name: 'UserStoreID',
            'class': 'W50pc Modernize'
        });
        $Original.replaceWith($Select);

        // Keep the store immediately below the customer information.
        var $StoreLabel = $('label[for="UserStoreID"]'),
            $StoreField = $Select.closest('.Field'),
            $StoreClear = $StoreField.next('.Clear'),
            $CustomerLabel = $('label[for="UserCustomerID"]'),
            $CustomerField = $('#UserCustomerID').closest('.Field'),
            $CustomerClear = $CustomerField.next('.Clear'),
            $CompanyLabel = $('<label/>', {
                'for': 'BWBStoreCustomerCompanyName',
                text: 'Nome do Cliente:'
            }),
            $CompanyField = $('<div/>', { 'class': 'Field' }).append(
                $('<input/>', {
                    id: 'BWBStoreCustomerCompanyName',
                    type: 'text',
                    readonly: 'readonly',
                    'class': 'W50pc'
                })
            ),
            $CompanyClear = $('<div/>', { 'class': 'Clear' });

        if ($CustomerLabel.length && $CustomerField.length) {
            $CustomerClear.after($CompanyLabel, $CompanyField, $CompanyClear);
            $CompanyClear.after($StoreLabel, $StoreField, $StoreClear);
        }

        function CustomerIDGet() {
            return String($('#UserCustomerID').val() || '').trim();
        }

        function StoresLoad(CustomerID) {
            $Select.empty().append($('<option/>', { value: '', text: 'A carregar...' })).prop('disabled', true);
            if (!CustomerID) {
                $Select.empty().append($('<option/>', { value: '', text: 'Selecione primeiro o cliente' }));
                return;
            }

            Core.AJAX.FunctionCall(
                Core.Config.Get('CGIHandle'),
                { Action: 'AgentBWBStoreLookup', CustomerID: CustomerID },
                function (Response) {
                    var Selected = CurrentStoreID || String(Response.HeadquartersID || '');
                    $('#BWBStoreCustomerCompanyName').val(Response.CustomerCompanyName || '');
                    $Select.empty();
                    $.each(Response.Stores || [], function () {
                        $Select.append($('<option/>', { value: this.ID, text: this.Label }));
                    });
                    if (!$Select.children().length) {
                        $Select.append($('<option/>', { value: '', text: 'Sem lojas disponíveis' }));
                    }
                    $Select.val(Selected).prop('disabled', false).trigger('redraw.InputField');
                    if (!$Select.val() && Response.HeadquartersID) {
                        $Select.val(String(Response.HeadquartersID));
                    }
                    CurrentStoreID = '';
                },
                'json'
            );
        }

        function CustomerCheck() {
            var CustomerID = CustomerIDGet();
            if (CustomerID !== LastCustomerID) {
                LastCustomerID = CustomerID;
                StoresLoad(CustomerID);
            }
        }

        CustomerCheck();
        window.setInterval(CustomerCheck, 500);
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');
    return TargetNS;
}(Core.Agent.Admin.BWBStoreUser || {}));
