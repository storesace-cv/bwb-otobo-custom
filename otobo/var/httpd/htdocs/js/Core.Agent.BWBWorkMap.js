// BWB work sheet location map (Google Maps Embed) on AgentTicketZoom only.
// Secção 1: folha (iframe) + carimbo FECHADO. Secção 2: mapa Embed (fora do e-mail).

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.BWBWorkMap
 * @description
 *      Google Maps Embed for finished work sheet locations (helpdesk only).
 */
Core.Agent.BWBWorkMap = (function (TargetNS) {

    TargetNS._LastLocations = [];

    function HideLegacyMap(Doc) {
        if (!Doc || !Doc.body) {
            return false;
        }

        var Changed = false;

        Doc.querySelectorAll('.BWBWorkLocation').forEach(function (Loc) {
            if (Loc.style.display !== 'none') {
                Loc.style.display = 'none';
                Loc.setAttribute('aria-hidden', 'true');
                Changed = true;
            }
        });

        Doc.querySelectorAll('img[alt="Mapa da localização"]').forEach(function (Img) {
            var Outer = Img.closest('div[style*="margin:0 6px 28px"]');
            if (!Outer) {
                var Link = Img.closest('a');
                Outer = Link ? Link.parentElement : Img.parentElement;
            }
            if (Outer && Outer.parentNode) {
                var Prev = Outer.previousElementSibling;
                if (Prev && /Localiza/.test((Prev.textContent || ''))) {
                    Prev.parentNode.removeChild(Prev);
                }
                Outer.parentNode.removeChild(Outer);
                Changed = true;
            }
            else if (Img.style.display !== 'none') {
                Img.style.display = 'none';
                Changed = true;
            }
        });

        Doc.querySelectorAll('span[style*="rotate(-45deg)"]').forEach(function (Pin) {
            if (Pin.parentNode) {
                Pin.parentNode.removeChild(Pin);
                Changed = true;
            }
        });

        Doc.querySelectorAll('div').forEach(function (Node) {
            if (!Node || !Node.parentNode) {
                return;
            }
            var Text = (Node.textContent || '').replace(/\s+/g, ' ').trim();
            if (Text === 'Localização no fecho' || Text === 'Localização (coordenadas da loja)') {
                Node.parentNode.removeChild(Node);
                Changed = true;
            }
        });

        return Changed;
    }

    function AdjustIframeHeightOnce(Iframe) {
        var $Iframe = $(Iframe);
        if ($Iframe.data('BWBHeightAdjusted')) {
            return;
        }
        $Iframe.data('BWBHeightAdjusted', 1);
        if (Core.Agent && Core.Agent.TicketZoom && typeof Core.Agent.TicketZoom.IframeAutoHeight === 'function') {
            Core.Agent.TicketZoom.IframeAutoHeight($Iframe);
        }
    }

    function RetouchAllIframes() {
        $('iframe[id^="Iframe"]').each(function () {
            var Iframe = this;
            var Doc;
            try {
                Doc = Iframe.contentDocument || (Iframe.contentWindow && Iframe.contentWindow.document);
            }
            catch (E) {
                return;
            }
            // Nunca CheckIFrameHeight em loop: IframeAutoHeight faz height+25 e cresce sem fim.
            if (HideLegacyMap(Doc)) {
                AdjustIframeHeightOnce(Iframe);
            }
        });
    }

    function EnsureSheetSection($Iframe) {
        var $Wrapper = $Iframe.closest('.ArticleMailContentHTMLWrapper');
        if (!$Wrapper.length) {
            return $Iframe.parent();
        }
        var $Sheet = $Wrapper.closest('.BWBWorkSheetSection');
        if ($Sheet.length) {
            return $Sheet;
        }
        $Sheet = $('<div class="BWBWorkSheetSection"></div>');
        $Wrapper.before($Sheet);
        $Sheet.append($Wrapper);

        var $Stamp = $('.BWBClosedTicketStamp').first();
        if ($Stamp.length) {
            $Stamp.addClass('BWBClosedTicketStamp--sheet');
            $Sheet.append($Stamp);
        }
        return $Sheet;
    }

    function FormatCoords(Lat, Lon, Meta) {
        var Text = Number(Lat).toFixed(7) + ', ' + Number(Lon).toFixed(7);
        if (Meta && Meta.Coords) {
            return Meta.Coords;
        }
        if (Meta && Meta.Source === 'gps' && Meta.Accuracy) {
            Text += ' (±' + Meta.Accuracy + ' m)';
        }
        return Text;
    }

    function GoogleMapsOpenUrl(Lat, Lon) {
        return 'https://www.google.com/maps?q=' + encodeURIComponent(Lat + ',' + Lon);
    }

    function GoogleMapsEmbedUrl(Lat, Lon) {
        var Key = Core.Config.Get('BWBMapsEmbedAPIKey') || '';
        if (!Key) {
            return '';
        }
        // place + q: pin no ponto; maptype=satellite (vista aérea). center com ponto decimal.
        return 'https://www.google.com/maps/embed/v1/place'
            + '?key=' + encodeURIComponent(Key)
            + '&q=' + encodeURIComponent(Number(Lat) + ',' + Number(Lon))
            + '&zoom=17'
            + '&maptype=satellite';
    }

    function PlaceMap(Iframe, Lat, Lon, Meta) {
        var $Iframe = $(Iframe);
        if ($Iframe.data('BWBWorkMapDone') || $Iframe.data('BWBWorkMapPending')) {
            return;
        }
        $Iframe.data('BWBWorkMapPending', 1);
        PlaceMapEmbed(Iframe, Lat, Lon, Meta);
    }

    function PlaceMapEmbed(Iframe, Lat, Lon, Meta) {
        var $Iframe = $(Iframe);
        if ($Iframe.data('BWBWorkMapDone')) {
            $Iframe.removeData('BWBWorkMapPending');
            return;
        }

        var Doc;
        try {
            Doc = Iframe.contentDocument || (Iframe.contentWindow && Iframe.contentWindow.document);
        }
        catch (E) {
            Doc = null;
        }
        HideLegacyMap(Doc);
        AdjustIframeHeightOnce(Iframe);

        var $Article = $Iframe.closest('.ArticleMailContent');
        if (!$Article.length) {
            $Article = $Iframe.parent();
        }
        if ($Article.children('.BWBWorkMapSection').length) {
            $Iframe.data('BWBWorkMapDone', 1);
            $Iframe.removeData('BWBWorkMapPending');
            return;
        }
        EnsureSheetSection($Iframe);

        $Iframe.data('BWBWorkMapDone', 1);
        $Iframe.removeData('BWBWorkMapPending');

        var MapID = 'BWBWorkMap-' + (Iframe.id || 'x') + '-' + String(Date.now()).slice(-6);
        var CoordText = FormatCoords(Lat, Lon, Meta || {});
        var MapUrl = (Meta && Meta.MapUrl)
            ? Meta.MapUrl
            : GoogleMapsOpenUrl(Lat, Lon);
        var EmbedSrc = GoogleMapsEmbedUrl(Lat, Lon);
        var SourceNote = '';
        if (Meta && Meta.Note) {
            SourceNote = Meta.Note;
        }
        else if (Meta && Meta.Source === 'store') {
            SourceNote = 'Coordenadas da loja do ticket (GPS indisponível no fecho).';
        }

        var MapInner;
        if (EmbedSrc) {
            MapInner = '<iframe id="' + MapID + '" class="BWBWorkMapEmbed" title="Mapa da localização no fecho"'
                + ' src="' + EmbedSrc.replace(/"/g, '&quot;') + '"'
                + ' loading="lazy" referrerpolicy="strict-origin-when-cross-origin"'
                + ' allowfullscreen="" allow="fullscreen"></iframe>';
        }
        else {
            MapInner = '<div id="' + MapID + '" class="BWBWorkMap BWBWorkMap--missingKey" role="status">'
                + 'Mapa indisponível: chave Maps Embed não configurada (BWB::MapsEmbedAPIKey).'
                + '</div>';
        }

        var $Section = $(
            '<div class="BWBWorkMapSection">'
            + '<div class="BWBWorkMapSectionHeader">'
            + '<strong>Mapa da localização</strong>'
            + '<span class="BWBWorkMapSectionHint">Google Maps · só no helpdesk</span>'
            + '</div>'
            + '<p class="BWBWorkMapCoords">'
            + $('<div/>').text(CoordText).html()
            + ' · <a href="' + MapUrl.replace(/"/g, '&quot;') + '" target="_blank" rel="noopener noreferrer">Abrir no Google Maps</a>'
            + '</p>'
            + (SourceNote ? '<p class="BWBWorkMapSectionNote">' + $('<div/>').text(SourceNote).html() + '</p>' : '')
            + '<div class="BWBWorkMapFrame">' + MapInner + '</div>'
            + '</div>'
        );
        $Article.append($Section);

        var Side = Math.min(520, Math.max(280, Math.floor(($Section.outerWidth() || 520) - 28)));
        var $Frame = $Section.find('.BWBWorkMapEmbed, .BWBWorkMap');
        $Frame.css({
            width: Side + 'px',
            height: Side + 'px',
            maxWidth: '100%'
        });
    }

    function MetaFromLocation(Loc) {
        return {
            Source: Loc.getAttribute('data-bwb-source') || '',
            Accuracy: Loc.getAttribute('data-bwb-acc') || '',
            Coords: Loc.getAttribute('data-bwb-coords') || '',
            MapUrl: (Loc.getAttribute('data-bwb-map-url') || '').replace(/&amp;/g, '&'),
            Note: Loc.getAttribute('data-bwb-note') || ''
        };
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

        HideLegacyMap(Doc);

        var Loc = Doc.querySelector('.BWBWorkLocation[data-bwb-lat][data-bwb-lon]');
        if (!Loc) {
            return;
        }

        var Lat = parseFloat(Loc.getAttribute('data-bwb-lat'));
        var Lon = parseFloat(Loc.getAttribute('data-bwb-lon'));
        if (!isFinite(Lat) || !isFinite(Lon)) {
            return;
        }

        PlaceMap(Iframe, Lat, Lon, MetaFromLocation(Loc));
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
            PlaceMap(Iframe, Lat, Lon, {
                Source: Item.Source || '',
                Accuracy: Item.Accuracy || ''
            });
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

        RetouchAllIframes();
        ScanAllIframes();
        LoadFromSession();

        $(document).on('load', 'iframe[id^="Iframe"]', function () {
            HideLegacyMap(this.contentDocument);
            ScanIframe(this);
            RetouchAllIframes();
        });

        window.setInterval(function () {
            ScanAllIframes();
            ApplyFromSession(TargetNS._LastLocations);
        }, 2500);
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.BWBWorkMap || {}));
