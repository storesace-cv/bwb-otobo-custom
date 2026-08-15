// Move the visible Help menu after the global-search icon without changing
// OTOBO's internal FAQ navigation identifier or any menu priorities.
(function ($) {
    'use strict';

    $(function () {
        var $Help   = $('#nav-Ajuda');
        var $Search = $('#nav-search');

        if ($Help.length && $Search.length) {
            $Help.insertAfter($Search);
        }
    });
}(jQuery));
