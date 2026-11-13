# Terrain, population density and railways map

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
- **Railway electrification** shows which rail lines are electrified via overhead
  catenary or third rail. Color coding indicates electrification type and status.
  Coverage varies by region; this layer is based on OpenStreetMap data.
- **Railway gauge** displays track gauge information (standard, broad, narrow gauge).
  Different colors represent different gauge widths. This helps identify
  interoperability constraints across rail networks.
