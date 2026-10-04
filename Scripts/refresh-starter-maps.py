#!/usr/bin/env python3
"""Maintainer-only ODbL vector extracts. Never run by builds or installed savers.

Responses are reused from build/starter-source; remove the relevant response
explicitly to refresh it. Three bounded, sequential detail queries; no tile fetches.
"""
import gzip
from coastal_water import coastal_water
import json
import math
import urllib.request
from pathlib import Path

SOURCE = Path('build/starter-source')
SOURCE.mkdir(parents=True, exist_ok=True)
CITIES = [('Paris', 48.857, 2.352), ('Boston', 42.357, -71.061), ('Tokyo', 35.6812, 139.7671)]
ENDPOINT = 'https://overpass-api.de/api/interpreter'

def point(lat, lon):
    n = 256 * 2**14
    return ((lon + 180) / 360 * n, (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n)

def lat_at(y):
    return math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / (256 * 2**14)))))

def simplify(points, tol=0.6):
    if len(points) < 3:
        return points
    ax, ay = points[0]; bx, by = points[-1]; dx, dy = bx - ax, by - ay; den = dx * dx + dy * dy
    best, at = -1, 0
    for i, (x, y) in enumerate(points[1:-1], 1):
        t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / den)) if den else 0
        d = (x - ax - t * dx)**2 + (y - ay - t * dy)**2
        if d > best:
            best, at = d, i
    if best > tol * tol:
        return simplify(points[:at + 1], tol)[:-1] + simplify(points[at:], tol)
    return [points[0], points[-1]]

def fetch(path, query):
    if not path.exists():
        request = urllib.request.Request(ENDPOINT, data=query.encode(), headers={
            'User-Agent': 'ScreensaversForMac vector-data build (+https://github.com/someone-in-texas/screensavers-for-mac)',
            'Content-Type': 'text/plain', 'Accept-Encoding': 'gzip'})
        with urllib.request.urlopen(request, timeout=120) as response:
            payload = response.read(128_000_001)
            assert len(payload) <= 128_000_000, 'response too large'
            if response.headers.get('Content-Encoding') == 'gzip':
                payload = gzip.decompress(payload)
            data = json.loads(payload)
            assert 'remark' not in data, data.get('remark')
            path.write_bytes(payload)
    return json.loads(path.read_bytes())

def rings(parts):
    """Join multipolygon member ways; never fill an unclosed/incomplete ring."""
    pending = [p[:] for p in parts if len(p) >= 2]
    result = []
    while pending:
        ring = pending.pop()
        while ring[-1] != ring[0]:
            match = next(((i, p) for i, p in enumerate(pending) if ring[-1] in (p[0], p[-1])), None)
            if match is None:
                break
            i, p = match; pending.pop(i)
            ring.extend((p if p[0] == ring[-1] else p[::-1])[1:])
        if len(ring) >= 4 and ring[0] == ring[-1]:
            result.append(ring)
    return result

result = []
for name, lat, lon in CITIES:
    cx, cy = point(lat, lon); extent = 2304
    bbox = f'{lat_at(cy + extent)},{lon - extent / (256 * 2**14) * 360},{lat_at(cy - extent)},{lon + extent / (256 * 2**14) * 360}'
    prefix = '[out:json][timeout:90][maxsize:67108864];'
    roads_data = fetch(SOURCE / (name + '-roads-v2.json'), prefix + f'way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|unclassified|living_street|pedestrian|service|busway)(_link)?$"]({bbox});out geom;')
    details = fetch(SOURCE / (name + '-details.json'), prefix + f'''(
        way["natural"="water"]({bbox});relation["natural"="water"]["type"="multipolygon"]({bbox});
        way["waterway"~"^(river|canal|riverbank)$"]({bbox});relation["waterway"="riverbank"]({bbox});
        way["natural"="coastline"]({bbox});
        way["leisure"="park"]({bbox});relation["leisure"="park"]["type"="multipolygon"]({bbox});
        node["tourism"~"^(museum|attraction|viewpoint)$"]["name"]({bbox});
        node["railway"="station"]["name"]({bbox});
        );out geom;''')
    def geometry(points):
        return [(point(p['lat'], p['lon'])[0] - cx, point(p['lat'], p['lon'])[1] - cy) for p in points if 'lat' in p]
    def packed(points):
        return [[round(x, 2), round(y, 2)] for x, y in simplify(points)]
    def oriented(points, inner=False):
        area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(points, points[1:]))
        return packed(points[::-1] if (area < 0) != inner else points)
    roads = []
    for way in roads_data['elements']:
        points = geometry(way.get('geometry', []))
        if len(points) < 2:
            continue
        kind = way['tags']['highway'].removesuffix('_link')
        if kind not in ('motorway', 'trunk', 'primary', 'secondary', 'tertiary'):
            kind = 'minor'
            # Vector viewports cap at 1920px; 1280px includes the 160px camera
            # drift and edge margin. Avoid shipping distant minor roads that can
            # never enter either online/default or explicit offline viewports.
            if (min(p[0] for p in points) > 1280 or max(p[0] for p in points) < -1280 or
                    min(p[1] for p in points) > 1280 or max(p[1] for p in points) < -1280):
                continue
        roads.append({'kind': kind, 'points': packed(points), 'name': way['tags'].get('name', '')})
    areas, waterways, pois, coasts = [], [], [], []
    relation_ways = {m['ref'] for e in details['elements'] if e['type'] == 'relation' for m in e.get('members', []) if m['type'] == 'way'}
    for item in details['elements']:
        tags = item.get('tags', {})
        if item['type'] == 'node':
            x, y = point(item['lat'], item['lon'])
            pois.append({'name': tags['name'], 'point': [round(x - cx, 2), round(y - cy, 2)]})
            continue
        if tags.get('natural') == 'coastline':
            coasts.append(geometry(item.get('geometry', [])))
            continue
        kind = 'park' if tags.get('leisure') == 'park' else 'water'
        if item['type'] == 'relation':
            # Opposite inner-ring winding preserves islands in batched fills.
            joined = []
            for inner in [False, True]:
                parts = [geometry(m.get('geometry', [])) for m in item.get('members', []) if m['type'] == 'way' and (m.get('role', '') == 'inner') == inner and m.get('role', '') in ('', 'outer', 'inner')]
                joined.extend(oriented(r, inner) for r in rings(parts))
            if joined:
                areas.append({'kind': kind, 'rings': joined})
        elif item['id'] not in relation_ways:
            points = geometry(item.get('geometry', []))
            if len(points) < 2:
                continue
            if len(points) >= 4 and points[0] == points[-1] and tags.get('natural') != 'coastline':
                areas.append({'kind': kind, 'rings': [oriented(points)]})
            elif kind == 'water':
                waterways.append(packed(points))
    for ocean in coastal_water(coasts, extent):
        areas.append({'kind': 'water', 'rings': [oriented(list(ocean.exterior.coords))] +
                      [oriented(list(ring.coords), inner=True) for ring in ocean.interiors]})
    result.append({'name': name, 'zoom': 14, 'extent': extent, 'roads': roads, 'areas': areas,
                   'waterways': waterways, 'pointsOfInterest': pois, 'sourceDate': roads_data['osm3s']['timestamp_osm_base'],
                   'detailSourceDate': details['osm3s']['timestamp_osm_base']})
    print(name, len(roads), 'roads', len(areas), 'areas', len(pois), 'places', flush=True)
Path('Assets/StarterMaps/streets.json').write_text(json.dumps({
    'attribution': '© OpenStreetMap contributors', 'license': 'ODbL-1.0', 'source': ENDPOINT, 'cities': result
}, separators=(',', ':')) + '\n')
