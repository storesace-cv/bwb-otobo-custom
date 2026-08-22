// BWB work sheet location map (Leaflet + OSM) on AgentTicketZoom.
// Article HTML lives in a sandboxed iframe (script-src none, frame-src none);
// the map is injected in the parent page next to the article.

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.BWBWorkMap
 * @description
 *      Leaflet map for finished work-sheet GPS/store coordinates.
 */
Core.Agent.BWBWorkMap = (function (TargetNS) {

    TargetNS._LastLocations = [];

    function MapAfterIframe($Iframe, Lat, Lon) {
        if ($Iframe.data('BWBWorkMapDone')) {
            return;
        }
        $Iframe.data('BWBWorkMapDone', 1);

        var $Host = $Iframe.closest('.ArticleMailContentHTMLWrapper');
        if (!$Host.length) {
            $Host = $Iframe.parent();
        }

        var MapID = 'BWBWorkMap-' + ($Iframe.attr('id') || String(Math.random()).slice(2));
        var $Wrap = $(
            '<div class="BWBWorkMapWrap">'
            + '<div id="' + MapID + '" class="BWBWorkMap" role="img" aria-label="Mapa OpenStreetMap da localização no fecho"></div>'
            + '</div>'
        );
        $Host.after($Wrap);

        if (typeof L === 'undefined') {
            return;
        }

        var Map = L.map(MapID, {
            scrollWheelZoom: false,
            attributionControl: true
        }).setView([Lat, Lon], 15);

        L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        }).addTo(Map);

        L.marker([Lat, Lon]).addTo(Map);

        window.setTimeout(function () {
            Map.invalidateSize();
        }, 200);
    }

    function ScanIframe(Iframe) {
        var $Iframe = $(Iframe);
        var Doc;
        try {
            Doc = Iframe.contentDocument || (Iframe.contentWindow && Iframe.contentWindow.document);
        }
        catch (E) {
            return;
        }
        if (!Doc || !Doc.querySelector) {
            return;
        }

        var Loc = Doc.querySelector('.BWBWorkLocation[data-bwb-lat][data-bwb-lon]');
        if (!Loc) {
            return;
        }

        var Lat = parseFloat(Loc.getAttribute('data-bwb-lat'));
        var Lon = parseFloat(Loc.getAttribute('data-bwb-lon'));
        if (!isFinite(Lat) || !isFinite(Lon)) {
            return;
        }

        MapAfterIframe($Iframe, Lat, Lon);
    }

    function ScanAllIframes() {
        $('iframe[id^="Iframe"]').each(function () {
            ScanIframe(this);
        });
    }

    function ApplyFromSession(Locations) {
        if (!Locations || !Locations.length) {
            return;
        }
        Locations.forEach(function (Item) {
            var Iframe = document.getElementById('Iframe' + Item.ArticleID);
            if (!Iframe) {
                return;
            }
            var Lat = parseFloat(Item.Latitude);
            var Lon = parseFloat(Item.Longitude);
            if (!isFinite(Lat) || !isFinite(Lon)) {
                return;
            }
            MapAfterIframe($(Iframe), Lat, Lon);
        });
    }

    function LoadFromSession() {
        var TicketID = Core.Config.Get('TicketID');
        if (!TicketID) {
            return;
        }
        Core.AJAX.FunctionCall(
            Core.Config.Get('CGIHandle'),
            {
                Action: 'AgentBWBWorkMap',
                TicketID: TicketID
            },
            function (Response) {
                if (!Response || !Response.Success) {
                    return;
                }
                TargetNS._LastLocations = Response.Locations || [];
                ApplyFromSession(TargetNS._LastLocations);
            },
            'json'
        );
    }

    TargetNS.Init = function () {
        if (Core.Config.Get('Action') !== 'AgentTicketZoom') {
            return;
        }

        ScanAllIframes();
        LoadFromSession();

        $(document).on('load', 'iframe[id^="Iframe"]', function () {
            ScanIframe(this);
        });

        window.setInterval(function () {
            ScanAllIframes();
            ApplyFromSession(TargetNS._LastLocations);
        }, 2000);
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.BWBWorkMap || {}));
