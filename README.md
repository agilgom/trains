# Global population, terrain and railway map

Run the script from this directory with R installed:

```sh
Rscript -e 'install.packages(c("leaflet", "htmlwidgets", "htmltools"))'
Rscript script.R
```

The script generates `output/us_geography_railways.html` and its accompanying dependency
directory; keep them together. From this directory start the local server with
`python3 server.py` and open `http://127.0.0.1:8000/us_geography_railways.html`.
The server listens only on localhost and provides the Renfe feed proxy.
The basemaps, population
and railway layers require an internet connection. OpenRailwayMap requires a browser
referer, so its tiles may not work when opening the HTML file directly.

## Publish on GitHub Pages

Running `Rscript script.R` also generates `docs/index.html` and the accompanying
`docs/index_files/` directory. Commit both along with the source files. In the
repository's **Settings → Pages**, choose **Deploy from a branch**, select
`main` and `/docs`, and save. Once published, the map is available at
`https://agilgom.github.io/trains/`.

GitHub Pages hosts static files only: **Renfe trains will not work there**
without a separately hosted HTTPS backend and a corresponding change to the
map's feed URL. The local `server.py` is not deployed by Pages. The other
layers still depend on their external tile and image services.

The generated site includes any optional local railway data read by the
script. Review that data and its license before committing or publishing it.
The downloaded raster and local GeoPackage in `data/`, and the local `output/`
directory, are ignored by Git.

## Layers and limitations

- **Terrain** is Esri's shaded-relief basemap; the light basemap is an
  alternative. The initial view shows the contiguous US; pan and zoom worldwide.
- **Population density** uses the global
  [WorldPop 2020 density dataset](https://www.worldpop.org/doi/10.5258/SOTON/WP00674),
  served by [WorldPop and Esri](https://worldpop.arcgis.com/arcgis/rest/services/WorldPop_Population_Density_1km/ImageServer).
  It estimates residents per km² at approximately 1 km resolution. Areas
  below 1 person/km² and areas without data are transparent; other classes
  are displayed at 65% opacity so terrain remains visible. It is an estimate,
  not a census count. The service supplies images on demand; if unavailable,
  the map shows a warning. The reference World Population Density map uses
  a different dataset (GHSL 2023), so values and appearance will differ.
  The former US-only 2025 raster, if previously downloaded, is no longer used.
- **Railway speeds** uses OpenRailwayMap's live maximum-speed tiles based on
  OpenStreetMap. Zoom in to see details; coverage and speed tags can be
  incomplete. The on-map speed legend shows OpenRailwayMap's colors in km/h
  and follows the railway overlay; the separate population legend does not
  apply to rail lines. Scroll the legend to see the individual 10 km/h bins
  through 300 km/h, 20 km/h bins through 380 km/h, and the final above
  380 km/h bin. Lower bounds are exclusive and upper bounds inclusive;
  OpenRailwayMap converts mph tags to km/h before classifying. Pale colors represent
  disused or under-construction lines, and dashed lines indicate speed
  information for one direction. Tiles are images and do not provide
  clickable speed attributes.
  Consult the [speed legend](https://www.openrailwaymap.org/legend-generator.php?zoom=12&style=maxspeed&lang=en_GB)
  (in km/h) and [OpenRailwayMap](https://www.openrailwaymap.org/) for details.
  The tile service can be unavailable or block
  access; the map warns if a tile fails to load. Follow its
  [usage policy](https://wiki.openstreetmap.org/wiki/OpenRailwayMap/API):
  it is a volunteer service, not for bulk downloads or high-traffic use.
- **Renfe trains** is an optional, initially disabled overlay. Enable it and
  pan to Spain for high-speed, long-distance and medium-distance positions
  from [Renfe's GTFS-Realtime feed](https://data.renfe.com/dataset/posicion-vehiculos-av-ld-md)
  ([CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)). Click a marker
  for its train identifier, status and feed timestamp. This is not a global
  feed and does not include Renfe commuter trains. The map refreshes every
  30 seconds while enabled; the local server caches responses for 30 seconds.
  The provider states its feed updates every 15 seconds, but its HTTP cache
  and actual data can be older. The displayed feed timestamp is interpreted
  as UTC and flagged if over two minutes old or more than one minute in the
  future; it is not an individual vehicle's position timestamp. If updates
  fail, an error is displayed and previous markers may be outdated. A plain
  static file server cannot provide this overlay: use `server.py`.
- **geOps** is not integrated: its [Realtime API](https://developer.geops.io/apis/realtime)
  requires a personal API key and appropriate usage permission. Request a key
  from [geOps](https://developer.geops.io/guides) before integration; the
  public portal's own credentials are not for use in this map. Its positions
  may be based on scheduled times as well as real-time updates.

## Optional clickable railway data

To add clickable railway information, install the `sf` R package and place
`data/us_railways.gpkg` in this directory before running the script. Its
`railways` layer must have a CRS, line geometries and these columns:

| Column | Meaning |
| --- | --- |
| `name`, `railway`, `operator` | Text; missing values are allowed |
| `maxspeed_mph`, `freight_mph`, `passenger_mph` | Non-negative numeric speeds in mph; use NA when unknown |
| `speed_source` | Text describing the verified source; use NA when unknown |

An optional `stations` layer may contain point geometries with a CRS and the
text columns `name`, `railway` and `operator`. The local data is displayed as
a separate layer and is not included or downloaded by the script. Supply
only sourced speeds; do not infer speeds from track class or fill unknown
values with estimates. Disable **Local railway details** in the layer control
if its lines obscure the OpenRailwayMap speed colors.
# trains
