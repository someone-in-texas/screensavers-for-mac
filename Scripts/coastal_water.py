"""Maintainer-only coastline polygonization; requires Shapely 2.x.

OSM coastlines have land left / water right. Map coordinates here have y south,
so the water side has a positive cross product. Clip and node directed coastlines
against the extract boundary, then retain only their water-side polygons.
https://wiki.openstreetmap.org/wiki/Tag:natural%3Dcoastline
"""
from shapely.geometry import LineString, box
from shapely.ops import polygonize_full, unary_union
from shapely.strtree import STRtree


def coastal_water(coasts, extent):
    if not coasts:
        return []
    boundary = box(-extent, -extent, extent, extent)
    lines = [LineString(points).intersection(boundary) for points in coasts if len(points) >= 2]
    lines = [line for line in lines if not line.is_empty]
    if not lines:
        return []
    faces, cuts, dangles, invalid = polygonize_full(unary_union([boundary.boundary, *lines]))
    if not cuts.is_empty or not dangles.is_empty or not invalid.is_empty:
        raise ValueError('Incomplete coastline inside extract; fix source data before generating ocean fills.')
    segments = [LineString([a, b]) for points in coasts for a, b in zip(points, points[1:]) if a != b]
    tree = STRtree(segments)
    result = []
    for face in faces.geoms:
        sample = face.representative_point()
        segment = segments[int(tree.nearest(sample))]
        (ax, ay), (bx, by) = segment.coords
        side = (bx - ax) * (sample.y - ay) - (by - ay) * (sample.x - ax)
        if side > 0:
            result.append(face)
    return result
