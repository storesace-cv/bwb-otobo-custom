// BWB work sheet location map (Leaflet + OSM) on AgentTicketZoom.
// Article HTML runs in a sandboxed iframe (no scripts / no external CSS).
// Leaflet stays in the parent page and is positioned over a spacer in the article.

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
    TargetNS._Overlays = [];

    function FindAnchor(Doc) {
        var Loc = Doc.querySelector('.BWBWorkLocation[data-bwb-lat]');
        if (Loc) {
            return Loc;
        }
        var Img = Doc.querySelector('img[alt="Mapa da localização"]');
        if (!Img) {
            return null;
        }
        return Img.closest('a') || Img.parentElement || Img;
    }

    function EnsureSpacer(Doc, Anchor) {
        var Spacer = Anchor.querySelector('.BWBWorkMapSpacer');
        if (Spacer) {
            return Spacer;
        }

        Anchor.querySelectorAll('img[alt="Mapa da localização"]').forEach(function (Img) {
            var Box = Img.closest('a') || Img;
            Box.style.display = 'none';
        });
        Anchor.querySelectorAll('span[style*="rotate(-45deg)"]').forEach(function (Pin) {
            Pin.style.display = 'none';
        });

        Spacer = Doc.createElement('div');
        Spacer.className = 'BWBWorkMapSpacer';
        Spacer.setAttribute('aria-hidden', 'true');
        Spacer.style.cssText = 'height:260px;width:100%;max-width:760px;margin:10px 0 12px;box-sizing:border-box;';

        var Title = Anchor.querySelector('div');
        if (Title && Title.parentNode === Anchor) {
            if (Title.nextSibling) {
                Anchor.insertBefore(Spacer, Title.nextSibling);
            }
            else {
                Anchor.appendChild(Spacer);
            }
        }
        else {
            Anchor.insertBefore(Spacer, Anchor.firstChild);
        }
        return Spacer;
    }

    function SyncOverlay(Entry) {
        if (!Entry || !Entry.Iframe || !Entry.Spacer || !Entry.Wrap) {
            return;
        }
        var Host = Entry.Iframe.closest('.ArticleMailContent') || Entry.Iframe.parentElement;
        if (!Host) {
            return;
        }
        if (window.getComputedStyle(Host).position === 'static') {
            Host.style.position = 'relative';
        }

        var HostRect = Host.getBoundingClientRect();
        var SpacerRect = Entry.Spacer.getBoundingClientRect();
        var Top = SpacerRect.top - HostRect.top + Host.scrollTop;
        var Left = SpacerRect.left - HostRect.left + Host.scrollLeft;
        var Width = Math.max(240, Math.min(760, SpacerRect.width || 560));

        Entry.Wrap.style.top = Math.round(Top) + 'px';
        Entry.Wrap.style.left = Math.round(Left) + 'px';
        Entry.Wrap.style.width = Math.round(Width) + 'px';
        Entry.Wrap.style.height = '260px';

        if (Entry.Map) {
            Entry.Map.invalidateSize();
        }
    }

    function RefreshIframeHeight(Iframe) {
        if (Iframe && Iframe.id && typeof window.CheckIFrameHeight === 'function') {
            window.CheckIFrameHeight(Iframe.id);
        }
    }

    function PlaceMap(Iframe, Lat, Lon) {
        var $Iframe = $(Iframe);
        if ($Iframe.data('BWBWorkMapDone')) {
            return;
        }

        var Doc;
        try {
            Doc = Iframe.contentDocument || (Iframe.contentWindow && Iframe.contentWindow.document);
        }
        catch (E) {
            return;
        }
        if (!Doc || !Doc.body) {
            return;
        }

        var Anchor = FindAnchor(Doc);
        if (!Anchor) {
            return;
        }

        if (typeof L === 'undefined') {
            return;
        }

        $Iframe.data('BWBWorkMapDone', 1);

        var Spacer = EnsureSpacer(Doc, Anchor);
        RefreshIframeHeight(Iframe);

        var Host = Iframe.closest('.ArticleMailContent') || Iframe.parentElement;
        var MapID = 'BWBWorkMap-' + (Iframe.id || String(Math.random()).slice(2));
        var Wrap = document.createElement('div');
        Wrap.className = 'BWBWorkMapWrap BWBWorkMapOverlay';
        Wrap.innerHTML = '<div id="' + MapID + '" class="BWBWorkMap" role="img" aria-label="Mapa OpenStreetMap da localização no fecho"></div>';
        Host.appendChild(Wrap);

        var Map = L.map(MapID, {
            scrollWheelZoom: false,
            attributionControl: true
        }).setView([Lat, Lon], 17);

        L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        }).addTo(Map);

        L.marker([Lat, Lon]).addTo(Map);

        var Entry = {
            Iframe: Iframe,
            Spacer: Spacer,
            Wrap: Wrap,
            Map: Map
        };
        TargetNS._Overlays.push(Entry);

        window.setTimeout(function () {
            SyncOverlay(Entry);
            RefreshIframeHeight(Iframe);
        }, 100);
        window.setTimeout(function () {
            SyncOverlay(Entry);
        }, 500);
    }

    function ScanIframe(Iframe) {
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

        PlaceMap(Iframe, Lat, Lon);
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
            PlaceMap(Iframe, Lat, Lon);
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

    function SyncAll() {
        TargetNS._Overlays.forEach(SyncOverlay);
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

        $(window).on('resize scroll', SyncAll);
        window.setInterval(function () {
            ScanAllIframes();
            ApplyFromSession(TargetNS._LastLocations);
            SyncAll();
        }, 2000);
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.BWBWorkMap || {}));
