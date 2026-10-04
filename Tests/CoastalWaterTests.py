"""Offline maintainer tests; run with uv run --with shapely==2.0.7 python ..."""
import importlib.util
import math
import json
from pathlib import Path
from shapely.geometry import Point, Polygon
from shapely.ops import unary_union

spec = importlib.util.spec_from_file_location('coasts', Path('Scripts/coastal_water.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
water = unary_union(module.coastal_water([[(0, -20), (0, 20)]], 10))
assert water.area == 200 and water.contains(Point(-5, 0)) and not water.contains(Point(5, 0))
island = [(-2, -2), (-2, 2), (2, 2), (2, -2), (-2, -2)]
water = unary_union(module.coastal_water([island], 10))
assert water.area == 384 and not water.contains(Point(0, 0)) and water.contains(Point(5, 5))
assert module.coastal_water([], 10) == []
try:
    module.coastal_water([[(0, 0), (0, 5)]], 10)
    raise AssertionError('Unclosed source must not flood the whole map')
except ValueError:
    pass

def mercator(lat, lon):
    n = 256 * 2**14
    return ((lon + 180) / 360 * n, (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n)

# Verify the shipped result, including island/airport land preservation.
cities = json.loads(Path('Assets/StarterMaps/streets.json').read_text())['cities']
for name, center, samples in [
    ('Boston', (42.357, -71.061), [(42.35, -71.0, True), (42.355, -71.065, False), (42.363, -71.01, False)]),
    ('Tokyo', (35.6812, 139.7671), [(35.625, 139.805, True), (35.6812, 139.7671, False)]),
]:
    city = next(c for c in cities if c['name'] == name)
    def winding(ring):
        return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(ring, ring[1:]))
    shapes = []
    for area in city['areas']:
        if area['kind'] != 'water':
            continue
        outer = [Polygon(r) for r in area['rings'] if winding(r) > 0 and len(r) >= 4]
        holes = [Polygon(r) for r in area['rings'] if winding(r) < 0 and len(r) >= 4]
        # Existing source polygon simplification may touch itself; repair only
        # for this containment assertion, never silently rewrite shipped data.
        shapes.append(unary_union([p.buffer(0) for p in outer]).difference(unary_union([p.buffer(0) for p in holes])))
    water = unary_union(shapes)
    cx, cy = mercator(*center)
    for lat, lon, expected in samples:
        x, y = mercator(lat, lon)
        assert water.contains(Point(x - cx, y - cy)) == expected, (name, lat, lon, expected)
print('Coastal-water geometry and shipped harbor/land checks passed.')
