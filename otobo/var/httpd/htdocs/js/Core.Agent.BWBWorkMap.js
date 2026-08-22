// BWB work sheet location map (Leaflet) on AgentTicketZoom only.
// Secção 1: folha (iframe) + carimbo FECHADO. Secção 2: mapa (fora do e-mail).

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.BWBWorkMap
 * @description
 *      Aerial map + nearby commercial POIs for finished work sheets.
 */
Core.Agent.BWBWorkMap = (function (TargetNS) {

    TargetNS._LastLocations = [];

    var OverpassURL = 'https://overpass-api.de/api/interpreter';
    var POIFilters = [
        { Key: 'shop', Label: 'Loja', Color: '#0071e3' },
        { Key: 'amenity', Value: 'restaurant', Label: 'Restaurante', Color: '#e67e22' },
        { Key: 'amenity', Value: 'cafe', Label: 'Café', Color: '#d35400' },
        { Key: 'amenity', Value: 'fast_food', Label: 'Fast-food', Color: '#e74c3c' },
        { Key: 'amenity', Value: 'bank', Label: 'Banco', Color: '#27ae60' },
        { Key: 'amenity', Value: 'pharmacy', Label: 'Farmácia', Color: '#8e44ad' },
        { Key: 'amenity', Value: 'fuel', Label: 'Combustível', Color: '#2c3e50' }
    ];

    function HideLegacyMap(Doc) {
        if (!Doc || !Doc.body) {
            return false;
        }

        var Changed = false;

        Doc.querySelectorAll('.BWBWorkLocation').forEach(function (Loc) {
            Loc.style.display = 'none';
            Loc.setAttribute('aria-hidden', 'true');
            Changed = true;
        });

        Doc.querySelectorAll('img[alt="Mapa da localização"]').forEach(function (Img) {
            var Outer = Img.closest('div[style*="margin:0 6px 28px"]');
            if (!Outer) {
                var Link = Img.closest('a');
                Outer = Link ? Link.parentElement : Img.parentElement;
            }
            if (Outer) {
                var Prev = Outer.previousElementSibling;
                if (Prev && /Localiza/.test((Prev.textContent || ''))) {
                    Prev.parentNode.removeChild(Prev);
                }
                Outer.parentNode.removeChild(Outer);
                Changed = true;
            }
            else {
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
            if (HideLegacyMap(Doc) && Iframe.id && typeof window.CheckIFrameHeight === 'function') {
                window.CheckIFrameHeight(Iframe.id);
            }
        });
    }

    function ClassifyPOI(Tags) {
        if (!Tags) {
            return null;
        }
        var i, Rule;
        for (i = 0; i < POIFilters.length; i++) {
            Rule = POIFilters[i];
            if (Rule.Value) {
                if (Tags[Rule.Key] === Rule.Value) {
                    return Rule;
                }
            }
            else if (Tags[Rule.Key]) {
                return {
                    Key: Rule.Key,
                    Label: Rule.Label,
                    Color: Rule.Color,
                    Detail: Tags[Rule.Key]
                };
            }
        }
        return null;
    }

    function POIName(Tags, Rule) {
        if (Tags.name) {
            return Tags.name;
        }
        if (Rule.Detail) {
            return Rule.Label + ' (' + Rule.Detail + ')';
        }
        return Rule.Label;
    }

    function BuildOverpassQuery(Bounds) {
        var S = Bounds.getSouth().toFixed(6);
        var W = Bounds.getWest().toFixed(6);
        var N = Bounds.getNorth().toFixed(6);
        var E = Bounds.getEast().toFixed(6);
        var BBox = S + ',' + W + ',' + N + ',' + E;
        return '[out:json][timeout:15];('
            + 'node["shop"](' + BBox + ');'
            + 'way["shop"](' + BBox + ');'
            + 'node["amenity"="restaurant"](' + BBox + ');'
            + 'node["amenity"="cafe"](' + BBox + ');'
            + 'node["amenity"="fast_food"](' + BBox + ');'
            + 'node["amenity"="bank"](' + BBox + ');'
            + 'node["amenity"="pharmacy"](' + BBox + ');'
            + 'node["amenity"="fuel"](' + BBox + ');'
            + 'way["amenity"="restaurant"](' + BBox + ');'
            + 'way["amenity"="cafe"](' + BBox + ');'
            + 'way["amenity"="fast_food"](' + BBox + ');'
            + 'way["amenity"="bank"](' + BBox + ');'
            + 'way["amenity"="pharmacy"](' + BBox + ');'
            + 'way["amenity"="fuel"](' + BBox + ');'
            + ');out center tags;';
    }

    function LoadPOIs(Entry) {
        if (!Entry || !Entry.Map || !Entry.POILayer) {
            return;
        }
        var Bounds = Entry.Map.getBounds();
        if (!Bounds) {
            return;
        }

        Entry.POIStatus.textContent = 'A carregar estabelecimentos…';
        Entry.POIList.innerHTML = '';

        var Query = BuildOverpassQuery(Bounds);
        var Controller = window.AbortController ? new AbortController() : null;
        if (Entry.POIAbort && Entry.POIAbort.abort) {
            try {
                Entry.POIAbort.abort();
            }
            catch (E) { /* ignore */ }
        }
        Entry.POIAbort = Controller;

        var Timer = window.setTimeout(function () {
            if (Controller) {
                Controller.abort();
            }
            Entry.POIStatus.textContent = 'Tempo esgotado a carregar estabelecimentos. Pode aproximar/afastar o mapa para tentar de novo.';
        }, 15000);

        fetch(OverpassURL, {
            method: 'POST',
            body: 'data=' + encodeURIComponent(Query),
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            signal: Controller ? Controller.signal : undefined
        }).then(function (Res) {
            if (!Res.ok) {
                throw new Error('Overpass HTTP ' + Res.status);
            }
            return Res.json();
        }).then(function (Data) {
            window.clearTimeout(Timer);
            Entry.POILayer.clearLayers();
            var Items = [];
            (Data.elements || []).forEach(function (El) {
                var Lat = El.lat;
                var Lon = El.lon;
                if (El.type === 'way' && El.center) {
                    Lat = El.center.lat;
                    Lon = El.center.lon;
                }
                if (!isFinite(Lat) || !isFinite(Lon)) {
                    return;
                }
                var Rule = ClassifyPOI(El.tags);
                if (!Rule) {
                    return;
                }
                var Name = POIName(El.tags, Rule);
                Items.push({ Name: Name, Rule: Rule, Lat: Lat, Lon: Lon });
                var Marker = L.circleMarker([Lat, Lon], {
                    radius: 7,
                    color: '#ffffff',
                    weight: 1,
                    fillColor: Rule.Color,
                    fillOpacity: 0.95
                });
                Marker.bindPopup('<strong>' + $('<div/>').text(Name).html() + '</strong><br>' + Rule.Label);
                Entry.POILayer.addLayer(Marker);
            });

            Items.sort(function (A, B) {
                return A.Name.localeCompare(B.Name, 'pt');
            });

            if (!Items.length) {
                Entry.POIStatus.textContent = 'Sem lojas, restaurantes, bancos, farmácias ou combustível mapeados nesta área (OpenStreetMap).';
                return;
            }

            Entry.POIStatus.textContent = Items.length + ' estabelecimento(s) na área visível:';
            Items.forEach(function (Item) {
                var Li = document.createElement('li');
                Li.innerHTML = '<span class="BWBWorkMapPOIDot" style="background:' + Item.Rule.Color + '"></span>'
                    + '<strong>' + $('<div/>').text(Item.Name).html() + '</strong>'
                    + ' <span class="BWBWorkMapPOIType">' + $('<div/>').text(Item.Rule.Label).html() + '</span>';
                Li.style.cursor = 'pointer';
                Li.addEventListener('click', function () {
                    Entry.Map.setView([Item.Lat, Item.Lon], Math.max(Entry.Map.getZoom(), 18));
                });
                Entry.POIList.appendChild(Li);
            });
        }).catch(function (Err) {
            window.clearTimeout(Timer);
            if (Err && Err.name === 'AbortError') {
                return;
            }
            Entry.POIStatus.textContent = 'Não foi possível carregar estabelecimentos (Overpass). O mapa continua disponível.';
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

    function PlaceMap(Iframe, Lat, Lon, Meta) {
        var $Iframe = $(Iframe);
        if ($Iframe.data('BWBWorkMapDone')) {
            RetouchAllIframes();
            return;
        }
        if (typeof L === 'undefined') {
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

        $Iframe.data('BWBWorkMapDone', 1);

        var $Article = $Iframe.closest('.ArticleMailContent');
        if (!$Article.length) {
            $Article = $Iframe.parent();
        }
        EnsureSheetSection($Iframe);

        var MapID = 'BWBWorkMap-' + (Iframe.id || String(Math.random()).slice(2));
        var CoordText = FormatCoords(Lat, Lon, Meta || {});
        var MapUrl = (Meta && Meta.MapUrl)
            ? Meta.MapUrl
            : ('https://www.openstreetmap.org/?mlat=' + Lat + '&mlon=' + Lon + '#map=17/' + Lat + '/' + Lon);
        var SourceNote = '';
        if (Meta && Meta.Note) {
            SourceNote = Meta.Note;
        }
        else if (Meta && Meta.Source === 'store') {
            SourceNote = 'Coordenadas da loja do ticket (GPS indisponível no fecho).';
        }

        var $Section = $(
            '<div class="BWBWorkMapSection">'
            + '<div class="BWBWorkMapSectionHeader">'
            + '<strong>Mapa da localização</strong>'
            + '<span class="BWBWorkMapSectionHint">Vista aérea · só no helpdesk</span>'
            + '</div>'
            + '<p class="BWBWorkMapCoords">'
            + $('<div/>').text(CoordText).html()
            + ' · <a href="' + MapUrl.replace(/"/g, '&quot;') + '" target="_blank" rel="noopener noreferrer">Abrir no OpenStreetMap</a>'
            + '</p>'
            + (SourceNote ? '<p class="BWBWorkMapSectionNote">' + $('<div/>').text(SourceNote).html() + '</p>' : '')
            + '<div id="' + MapID + '" class="BWBWorkMap" role="img" aria-label="Mapa aéreo da localização no fecho (~200 m)"></div>'
            + '<div class="BWBWorkMapPOIBlock">'
            + '<div class="BWBWorkMapPOIStatus">A carregar estabelecimentos…</div>'
            + '<ul class="BWBWorkMapPOIList"></ul>'
            + '</div>'
            + '</div>'
        );
        $Article.append($Section);

        var MapEl = document.getElementById(MapID);
        var Side = Math.min(520, Math.max(280, Math.floor(($Section.outerWidth() || 520) - 28)));
        MapEl.style.width = Side + 'px';
        MapEl.style.height = Side + 'px';
        MapEl.style.minHeight = Side + 'px';
        MapEl.style.display = 'block';

        var Map = L.map(MapID, {
            scrollWheelZoom: false,
            attributionControl: true
        });

        var Aerial = L.tileLayer(
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            {
                maxZoom: 19,
                attribution: 'Tiles &copy; Esri'
            }
        );
        var Streets = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        });

        // OSM primeiro (fiável); vista aérea fica seleccionável e tenta-se activar a seguir.
        Streets.addTo(Map);
        L.control.layers(
            {
                'Vista aérea': Aerial,
                'Mapa OSM': Streets
            },
            null,
            { position: 'topright', collapsed: true }
        ).addTo(Map);

        var TileErrors = 0;
        Aerial.on('tileerror', function () {
            TileErrors += 1;
        });
        Aerial.on('load', function () {
            TileErrors = 0;
        });

        // Preferir aérea quando o contentor já tem tamanho.
        window.setTimeout(function () {
            try {
                Map.removeLayer(Streets);
                Aerial.addTo(Map);
            }
            catch (E) { /* ignore */ }
            window.setTimeout(function () {
                if (TileErrors >= 2) {
                    try {
                        Map.removeLayer(Aerial);
                        Streets.addTo(Map);
                    }
                    catch (E2) { /* ignore */ }
                }
            }, 2500);
        }, 300);

        var Radius = L.circle([Lat, Lon], {
            radius: 200,
            color: '#0071e3',
            weight: 1,
            fillColor: '#0071e3',
            fillOpacity: 0.08
        }).addTo(Map);

        L.circleMarker([Lat, Lon], {
            radius: 8,
            color: '#ffffff',
            weight: 2,
            fillColor: '#0071e3',
            fillOpacity: 1
        }).addTo(Map).bindPopup('Localização no fecho');

        Map.fitBounds(Radius.getBounds(), { padding: [16, 16], maxZoom: 18 });

        var POILayer = L.layerGroup().addTo(Map);
        var Entry = {
            Map: Map,
            POILayer: POILayer,
            POIStatus: $Section.find('.BWBWorkMapPOIStatus')[0],
            POIList: $Section.find('.BWBWorkMapPOIList')[0],
            POITimer: null,
            POIAbort: null,
            POIReady: false
        };

        function SchedulePOIs() {
            if (Entry.POITimer) {
                window.clearTimeout(Entry.POITimer);
            }
            Entry.POITimer = window.setTimeout(function () {
                LoadPOIs(Entry);
            }, 700);
        }

        Map.on('moveend', SchedulePOIs);

        function RefreshMap() {
            Map.invalidateSize(true);
            Map.fitBounds(Radius.getBounds(), { padding: [16, 16], maxZoom: 18 });
            if (!Entry.POIReady) {
                Entry.POIReady = true;
                SchedulePOIs();
            }
        }

        window.setTimeout(RefreshMap, 100);
        window.setTimeout(RefreshMap, 400);
        window.setTimeout(function () {
            RetouchAllIframes();
            RefreshMap();
        }, 800);
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
            RetouchAllIframes();
            ScanAllIframes();
            ApplyFromSession(TargetNS._LastLocations);
        }, 1500);
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.BWBWorkMap || {}));
