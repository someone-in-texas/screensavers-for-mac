# Bundled starter street maps

`streets.json` contains simplified major-road centerlines for Paris, Boston and
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
and tertiary classes and their links. Geometry is simplified with a 0.6-pixel
Douglas–Peucker tolerance. These are street outlines, not navigation maps.

Refresh manually with `python3 Scripts/refresh-starter-maps.py` from the repo root.
The script reuses raw responses in `build/starter-source` unless explicitly removed.
It is never invoked by CI, the build, the installed saver, or its preview host.

These data extracts do not use the standard raster tile service. No raster tile
archive is bundled. Runtime tile caching continues to honor the tile provider's
HTTP caching and usage rules.
