# Global population density, terrain and railway speeds.
# Run from the map directory with: Rscript script.R
# See README.md for data sources, limitations and optional railway details.

required <- c("leaflet", "htmlwidgets", "htmltools")
missing <- required[
  !vapply(required, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing)) {
  stop("Install the required R packages first: ",
       paste(missing, collapse = ", "), call. = FALSE)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)
dir.create("output", showWarnings = FALSE, recursive = TRUE)
dir.create("docs", showWarnings = FALSE, recursive = TRUE)

density_colors <- c("#ffffb2", "#fecc5c", "#fd8d3c", "#f03b20", "#bd0026")

# OpenRailwayMap's maxspeed style uses 10 km/h bins up to 300 and 20 thereafter.
rail_speed_colors <- c(
  "#0100CB", "#001ECB", "#003DCB", "#005BCB", "#007ACB",
  "#0098CB", "#00B7CB", "#00CBC1", "#00CBA2", "#00CB84",
  "#00CB66", "#00CB47", "#00CB29", "#00CB0A", "#14CB00",
  "#33CB00", "#51CB00", "#70CB00", "#8ECB00", "#ADCB00",
  "#CBCB00", "#CBAD00", "#CB8E00", "#CB7000", "#CB5100",
  "#CB3300", "#CB1400", "#CB0007", "#CB0025", "#CB0044",
  "#CB0062", "#CB0081", "#CB009F", "#CB00BD", "#BA00CB"
)
rail_speed_bounds <- c(seq(0, 300, 10), 320, 340, 360, 380)
rail_speed_labels <- c(
  "&le; 10",
  paste0("&gt; ", rail_speed_bounds[2:34], "–", rail_speed_bounds[3:35]),
  "&gt; 380"
)

density_attribution <- paste0(
  'Population: <a href="https://www.worldpop.org/doi/10.5258/SOTON/WP00674">',
  'WorldPop</a> and Esri (2020)'
)

rail_attribution <- paste0(
  'Data: <a href="https://www.openstreetmap.org/copyright">',
  '&copy; OpenStreetMap contributors</a>; ',
  'Style: <a href="https://creativecommons.org/licenses/by-sa/2.0/">',
  'CC BY-SA 2.0</a> <a href="https://www.openrailwaymap.org/">',
  'OpenRailwayMap</a>'
)

m <- leaflet::leaflet(
  options = leaflet::leafletOptions(preferCanvas = TRUE, minZoom = 2, maxZoom = 19)
) |>
  leaflet::addProviderTiles(leaflet::providers$Esri.WorldShadedRelief,
                            group = "Terrain") |>
  # A transparent placeholder is replaced with the image service after rendering.
  leaflet::addTiles(
    urlTemplate = paste0(
      "data:image/gif;base64,",
      "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
    ),
    attribution = density_attribution, group = "Population density",
    options = leaflet::tileOptions(opacity = 0.65, maxNativeZoom = 13)
  ) |>
  leaflet::addTiles(
    urlTemplate = "https://tiles.openrailwaymap.org/maxspeed/{z}/{x}/{y}.png",
    attribution = rail_attribution, group = "Railway speeds",
    options = leaflet::tileOptions(maxNativeZoom = 19)
  ) |>
  leaflet::addTiles(
    urlTemplate = "https://tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png",
    attribution = rail_attribution, group = "Railway standard",
    options = leaflet::tileOptions(maxNativeZoom = 19)
  ) |>
  leaflet::addTiles(
    urlTemplate = "https://tiles.openrailwaymap.org/signaling/{z}/{x}/{y}.png",
    attribution = rail_attribution, group = "Railway signaling",
    options = leaflet::tileOptions(maxNativeZoom = 19)
  ) |>
  leaflet::addTiles(
    urlTemplate = "https://tiles.openrailwaymap.org/electrified/{z}/{x}/{y}.png",
    attribution = rail_attribution, group = "Railway electrification",
    options = leaflet::tileOptions(maxNativeZoom = 19)
  ) |>
  leaflet::addTiles(
    urlTemplate = "https://tiles.openrailwaymap.org/gauge/{z}/{x}/{y}.png",
    attribution = rail_attribution, group = "Railway gauge",
    options = leaflet::tileOptions(maxNativeZoom = 19)
  ) |>
  leaflet::setView(lng = -98, lat = 39, zoom = 4) |>
  leaflet::hideGroup(c("Light basemap", "Renfe trains"))

overlays <- c("Population density", "Railway speeds", "Railway standard", 
             "Railway signaling", "Railway electrification", "Railway gauge", "Renfe trains")

# A prepared GeoPackage is optional; the speed tiles work without one.
rail_file <- "data/us_railways.gpkg"
if (file.exists(rail_file)) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Install the sf package to use ", rail_file, call. = FALSE)
  }
  layers <- sf::st_layers(rail_file)$name
  if (!"railways" %in% layers) {
    stop(rail_file, " must contain a railways layer", call. = FALSE)
  }
  rail <- sf::st_read(rail_file, layer = "railways", quiet = TRUE)
  columns <- c("name", "railway", "operator", "maxspeed_mph",
               "freight_mph", "passenger_mph", "speed_source")
  absent <- setdiff(columns, names(rail))
  if (length(absent)) {
    stop("Missing railway columns: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }
  speed_columns <- c("maxspeed_mph", "freight_mph", "passenger_mph")
  for (column in speed_columns) {
    if (!is.numeric(rail[[column]]) ||
        any(!is.na(rail[[column]]) &
            (!is.finite(rail[[column]]) | rail[[column]] < 0))) {
      stop(column, " must contain non-negative numeric mph values or NA",
           call. = FALSE)
    }
  }
  if (is.na(sf::st_crs(rail))) stop("Railway layer has no CRS", call. = FALSE)
  if (any(!as.character(sf::st_geometry_type(rail)) %in%
          c("LINESTRING", "MULTILINESTRING"))) {
    stop("Railway geometry must contain lines", call. = FALSE)
  }
  rail <- sf::st_transform(rail, 4326)
  display <- function(x, missing = "Unknown") {
    x <- as.character(x)
    x[is.na(x) | !nzchar(trimws(x))] <- missing
    htmltools::htmlEscape(x)
  }
  speed_text <- function(x) ifelse(is.na(x), "Unknown", paste(x, "mph"))
  rail$popup <- paste0(
    "<b>", display(rail$name, "Unnamed railway"), "</b><br>",
    "Type: ", display(rail$railway), "<br>",
    "Operator: ", display(rail$operator), "<br>",
    "Maximum speed: ", speed_text(rail$maxspeed_mph), "<br>",
    "Freight speed: ", speed_text(rail$freight_mph), "<br>",
    "Passenger speed: ", speed_text(rail$passenger_mph), "<br>",
    "Speed source: ", display(rail$speed_source)
  )
  m <- leaflet::addPolylines(
    m, data = rail, color = "#111827", weight = 3, opacity = 0.8,
    popup = ~popup, group = "Local railway details"
  )
  overlays <- c(overlays, "Local railway details")

  if ("stations" %in% layers) {
    stations <- sf::st_read(rail_file, layer = "stations", quiet = TRUE)
    absent <- setdiff(c("name", "railway", "operator"), names(stations))
    if (length(absent)) {
      stop("Missing station columns: ", paste(absent, collapse = ", "),
           call. = FALSE)
    }
    if (is.na(sf::st_crs(stations))) stop("Station layer has no CRS", call. = FALSE)
    if (any(!as.character(sf::st_geometry_type(stations)) %in% c("POINT"))) {
      stop("Station geometry must contain points", call. = FALSE)
    }
    stations <- sf::st_transform(stations, 4326)
    stations$popup <- paste0(
      "<b>", display(stations$name, "Unnamed station"), "</b><br>",
      "Type: ", display(stations$railway), "<br>",
      "Operator: ", display(stations$operator)
    )
    m <- leaflet::addCircleMarkers(
      m, data = stations, radius = 4, color = "#111827", fillOpacity = 0.9,
      popup = ~popup, group = "Railway stations",
      clusterOptions = leaflet::markerClusterOptions()
    )
    overlays <- c(overlays, "Railway stations")
  }
}

m <- m |>
  leaflet::addLayersControl(
    baseGroups = c("Terrain", "Light basemap"), overlayGroups = overlays,
    options = leaflet::layersControlOptions(collapsed = FALSE)
  ) |>
  leaflet::addLegend(
    position = "bottomright", colors = density_colors,
    labels = c("1–10", "10–100", "100–1,000", "1,000–10,000", "10,000+"),
    title = "People / km² (2020)<br>&lt;1 transparent", opacity = 0.65,
    group = "Population density"
  ) |>
  leaflet::addLegend(
    position = "bottomright", colors = c("gray", rail_speed_colors),
    labels = c("No speed information", rail_speed_labels),
    title = paste0(
      "Rail maximum speed (km/h)<br>",
      '<span style="font-size:10px">Scroll for all speeds<br>',
      'Dashed: one direction; pale: disused / under construction</span>'
    ),
    opacity = 1, group = "Railway speeds",
    className = "info legend rail-speed-legend"
  ) |>
  leaflet::addControl(
    html = paste0(
      '<a href="https://www.worldpop.org/">WorldPop 2020</a>; ',
      '<a href="https://www.openrailwaymap.org/legend-generator.php?',
      'zoom=12&amp;style=maxspeed&amp;lang=en_GB">',
      'Railway speed legend (km/h)</a>. ',
      'Railway tiles require an available external service.'
    ),
    position = "bottomleft"
  ) |>
  leaflet::addScaleBar(position = "bottomleft")

m <- htmlwidgets::onRender(m, "
function(el, x) {
  var map = this;
  var trains = map.layerManager.getLayerGroup('Renfe trains', false);
  var trainTimer = null;
  var trainRequest = null;
  var trainGeneration = 0;
  var trainStatus = L.control({position: 'topleft'});
  trainStatus.onAdd = function() {
    var status = L.DomUtil.create('div', 'leaflet-control renfe-status');
    status.style.cssText = 'background:#fff;padding:8px;max-width:260px;';
    status.setAttribute('role', 'status');
    L.DomEvent.disableClickPropagation(status);
    return status;
  };
  var renfeCredit = 'Train positions: <a href=\"https://data.renfe.com/dataset/posicion-vehiculos-av-ld-md\">Renfe</a> (<a href=\"https://creativecommons.org/licenses/by/4.0/\">CC BY 4.0</a>)';

  function setTrainStatus(text) {
    if (trainStatus.getContainer()) trainStatus.getContainer().textContent = text;
  }

  async function refreshTrains(generation) {
    if (trainRequest) return;
    var controller = new AbortController();
    trainRequest = controller;
    var timeout = setTimeout(function() { controller.abort(); }, 15000);
    try {
      var response = await fetch('api/renfe/vehicles', {
        cache: 'no-store', signal: controller.signal
      });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      var feed = await response.json();
      if (!feed.header || !Array.isArray(feed.entity)) {
        throw new Error('invalid feed format');
      }
      var seconds = Number(feed.header.timestamp);
      if (!Number.isFinite(seconds) || seconds <= 0 ||
          !Number.isFinite(new Date(seconds * 1000).getTime())) {
        throw new Error('missing or invalid feed timestamp');
      }
      var markers = [];
      var skipped = 0;
      feed.entity.forEach(function(entity) {
        var vehicle = entity && entity.vehicle;
        var pos = vehicle && vehicle.position;
        if (!pos || typeof pos.latitude !== 'number' ||
            typeof pos.longitude !== 'number' ||
            !Number.isFinite(pos.latitude) || !Number.isFinite(pos.longitude) ||
            Math.abs(pos.latitude) > 90 || Math.abs(pos.longitude) > 180) {
          skipped++;
          return;
        }
        var details = document.createElement('div');
        var name = document.createElement('strong');
        name.textContent = 'Renfe train ' +
          ((vehicle.vehicle && (vehicle.vehicle.label || vehicle.vehicle.id)) || entity.id || 'unknown');
        details.appendChild(name);
        var info = document.createElement('div');
        info.textContent = 'Status: ' + (vehicle.currentStatus || 'Unknown') +
          ' | Feed updated: ' + new Date(seconds * 1000).toLocaleString();
        details.appendChild(info);
        markers.push(L.circleMarker([pos.latitude, pos.longitude], {
          radius: 5, color: '#ffffff', weight: 1.5, fillColor: '#a42680',
          fillOpacity: 0.95
        }).bindPopup(details));
      });
      if (generation !== trainGeneration) return;
      trains.clearLayers();
      markers.forEach(function(marker) { trains.addLayer(marker); });
      var age = (Date.now() - seconds * 1000) / 1000;
      var freshness = age > 120 ? 'STALE - ' :
        age < -60 ? 'TIMESTAMP IN FUTURE - ' : '';
      setTrainStatus('Renfe: ' + freshness + markers.length + ' trains; feed updated ' +
        new Date(seconds * 1000).toLocaleString() +
        (skipped ? '; ' + skipped + ' invalid positions skipped' : ''));
    } catch (error) {
      if (generation === trainGeneration) {
        setTrainStatus('Renfe unavailable (' + error.message +
          '). Existing positions may be outdated. GitHub Pages requires a separate ' +
          'Renfe backend; for local use run server.py.');
        console.error('Renfe feed error:', error);
      }
    } finally {
      clearTimeout(timeout);
      if (trainRequest === controller) trainRequest = null;
    }
  }

  function startTrains() {
    trainGeneration++;
    trainStatus.addTo(map);
    map.attributionControl.addAttribution(renfeCredit);
    setTrainStatus('Loading Renfe train positions...');
    refreshTrains(trainGeneration);
    trainTimer = setInterval(function() { refreshTrains(trainGeneration); }, 30000);
  }
  function stopTrains() {
    trainGeneration++;
    clearInterval(trainTimer);
    trainTimer = null;
    if (trainRequest) trainRequest.abort();
    trainRequest = null;
    trains.clearLayers();
    trainStatus.remove();
    map.attributionControl.removeAttribution(renfeCredit);
  }
  map.on('overlayadd', function(event) {
    if (event.name === 'Renfe trains') startTrains();
  });
  map.on('overlayremove', function(event) {
    if (event.name === 'Renfe trains') stopTrains();
  });

  function prepareRailLegend() {
    var legend = el.querySelector('.rail-speed-legend');
    if (!legend) return;
    legend.style.maxHeight = 'min(35vh, 260px)';
    legend.style.maxWidth = '220px';
    legend.style.overflowY = 'auto';
    L.DomEvent.disableScrollPropagation(legend);
    L.DomEvent.disableClickPropagation(legend);
  }
  prepareRailLegend();
  this.on('overlayadd', function(event) {
    if (event.name === 'Railway speeds') setTimeout(prepareRailLegend, 0);
  });

  function warnOnce(className, message) {
    if (el.querySelector('.' + className)) return;
    var warning = document.createElement('div');
    warning.className = className + ' leaflet-control';
    warning.style.cssText = 'background:#fff;padding:8px;max-width:260px;';
    warning.textContent = message;
    el.querySelector('.leaflet-top.leaflet-left').appendChild(warning);
  }

  this.eachLayer(function(layer) {
    if (layer._url && layer._url.indexOf('data:image/gif;base64,') === 0) {
      var service = 'https://worldpop.arcgis.com/arcgis/rest/services/' +
        'WorldPop_Population_Density_1km/ImageServer/exportImage';
      var rule = {
        rasterFunction: 'Colormap',
        rasterFunctionArguments: {
          Raster: {
            rasterFunction: 'Remap',
            rasterFunctionArguments: {
              Raster: '$$',
              InputRanges: [1, 10, 10, 100, 100, 1000, 1000, 10000, 10000, 10000000],
              OutputValues: [1, 2, 3, 4, 5],
              AllowUnmatched: false
            }
          },
          Colormap: [[1,255,255,178], [2,254,204,92], [3,253,141,60],
                     [4,240,59,32], [5,189,0,38]]
        }
      };
      layer.getTileUrl = function(coords) {
        var half = 20037508.342789244;
        var width = 2 * half / Math.pow(2, coords.z);
        var left = -half + coords.x * width;
        var top = half - coords.y * width;
        var params = new URLSearchParams({
          bbox: [left, top - width, left + width, top].join(','),
          bboxSR: '3857', imageSR: '3857', size: '256,256',
          format: 'png32', transparent: 'true', f: 'image',
          time: '1577836800000', interpolation: 'RSP_NearestNeighbor',
          renderingRule: JSON.stringify(rule)
        });
        return service + '?' + params.toString();
      };
      layer.on('tileerror', function() {
        warnOnce('density-tile-error',
          'Population density tiles could not be loaded. Check the service and your network.');
      });
      layer.redraw();
    }
    if (layer._url && layer._url.indexOf('tiles.openrailwaymap.org/maxspeed/') !== -1) {
      layer.on('tileerror', function() {
        warnOnce('rail-tile-error',
          'Railway speed tiles could not be loaded. Check the service and your network; use local railway details if available.');
      });
    }
  });
}
")

htmlwidgets::saveWidget(m, "output/us_geography_railways.html",
                        selfcontained = FALSE)
htmlwidgets::saveWidget(m, "docs/index.html", selfcontained = FALSE)
message("Map created: output/us_geography_railways.html")
message("GitHub Pages map created: docs/index.html")
