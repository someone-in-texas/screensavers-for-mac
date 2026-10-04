# Bundled starter street maps

`streets.json` contains simplified major- and minor-road centerlines, street names, water and park geometry,
and named places for Paris, Boston and
Tokyo, derived from **© OpenStreetMap contributors** via the Overpass API.
It is a derivative database licensed under **ODbL 1.0**, separately from this
repository's MIT-licensed software. The complete derivative database is provided
here in its editable JSON form, and the license is included in `ODbL-1.0.txt`.

- Source and attribution: https://www.openstreetmap.org/copyright
- License: https://opendatacommons.org/licenses/odbl/1-0/
- Extract service: https://overpass-api.de/api/interpreter
- Per-city source timestamps are recorded in the JSON.

Coordinates are Web Mercator pixel offsets from the corresponding CityCatalog
center at zoom 14; x points east and y points south. The query covers a square
with a 2,304-pixel half-width. Roads include motorway, trunk, primary, secondary
and tertiary classes and their links, plus residential, unclassified, living-street,
pedestrian, service and busway roads (rendered as minor roads), matching the online
vector renderer. Minor roads cover a 1,280-pixel half-width, beyond the vector
viewport cap plus camera drift; distant invisible minor roads are omitted to bound
bundle size and decode work. Major roads retain the full extent. Geometry is simplified with a 0.6-pixel
Douglas–Peucker tolerance. Water includes closed water polygons (with multipolygon island holes), rivers,
canals and coastal water. Directed coastlines are clipped and polygonized against
the extract boundary, preserving land and island holes; incomplete coastlines fail
the refresh instead of guessing water fills. See the [OSM coastline convention](https://wiki.openstreetmap.org/wiki/Tag:natural%3Dcoastline). Park areas
and named museum, attraction, viewpoint and railway-station nodes are optional.
Ring windings are normalized so holes remain holes with batched nonzero fills.
Road and detail extracts have separate timestamps. These are simplified display
maps, not navigation maps. Individual features may be incomplete in OSM.

Line maps remain entirely offline; the three cities are their complete catalog.
Online modes use these maps after a cache miss while loading the selected city.
Water is enabled by default. Only bundled-map city labels carry an asterisk.

Refresh manually from the repo root with
`uv run --with shapely==2.0.7 python Scripts/refresh-starter-maps.py` (or Python with
Shapely 2.x installed). Shapely is a maintainer-only geometry dependency; builds,
tests of the savers, and installed apps do not need it. Validate an extractor change
with `uv run --with shapely==2.0.7 python Tests/CoastalWaterTests.py`.
The script reuses raw responses in `build/starter-source` unless explicitly removed.
It is never invoked by CI, the build, the installed saver, or its preview host.

These data extracts do not use the standard raster tile service. No raster tile
archive is bundled. Runtime tile caching continues to honor the tile provider's
HTTP caching and usage rules.
