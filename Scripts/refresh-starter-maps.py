#!/usr/bin/env python3
"""Maintainer-only refresh of three ODbL street extracts, never run by builds or savers.

Run from the repository root. Responses are reused from build/starter-source;
remove a city's response there explicitly to request a fresh extract. Public
Overpass queries are sequential and bounded; no raster tile server is contacted.
"""
import json, math, urllib.request, gzip
from pathlib import Path
Path('build/starter-source').mkdir(parents=True, exist_ok=True)
cities=[('Paris',48.857,2.352),('Boston',42.357,-71.061),('Tokyo',35.6812,139.7671)]
def point(lat,lon):
 n=256*2**14
 return ((lon+180)/360*n,(1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*n)
def lat_at(y): return math.degrees(math.atan(math.sinh(math.pi*(1-2*y/(256*2**14)))))
def simplify(points,tol=0.6):
 if len(points)<3:return points
 ax,ay=points[0]; bx,by=points[-1]; dx,dy=bx-ax,by-ay; den=dx*dx+dy*dy
 best=-1; at=0
 for i,(x,y) in enumerate(points[1:-1],1):
  t=max(0,min(1,((x-ax)*dx+(y-ay)*dy)/den)) if den else 0
  d=(x-ax-t*dx)**2+(y-ay-t*dy)**2
  if d>best:best,at=d,i
 if best>tol*tol:return simplify(points[:at+1],tol)[:-1]+simplify(points[at:],tol)
 return [points[0],points[-1]]
result=[]
for name,lat,lon in cities:
 cx,cy=point(lat,lon); extent=2304
 south,north=lat_at(cy+extent),lat_at(cy-extent)
 west,east=lon-extent/(256*2**14)*360,lon+extent/(256*2**14)*360
 query=f'[out:json][timeout:90][maxsize:67108864];way["highway"~"^(motorway|trunk|primary|secondary|tertiary)(_link)?$"]({south},{west},{north},{east});out geom;'
 rawpath=Path('build/starter-source')/(name+'.json')
 if not rawpath.exists():
  req=urllib.request.Request('https://overpass-api.de/api/interpreter',data=query.encode(),headers={'User-Agent':'ScreensaversForMac starter-data build (+https://github.com/someone-in-texas/screensavers-for-mac)','Content-Type':'text/plain','Accept-Encoding':'gzip'})
  with urllib.request.urlopen(req,timeout=120) as r:
   payload=r.read(128_000_000)
   if r.headers.get('Content-Encoding')=='gzip': payload=gzip.decompress(payload)
   rawpath.write_bytes(payload)
 data=json.loads(rawpath.read_bytes());roads=[]
 assert 'remark' not in data,data.get('remark')
 for way in data['elements']:
  points=[(point(p['lat'],p['lon'])[0]-cx,point(p['lat'],p['lon'])[1]-cy) for p in way.get('geometry',[])]
  if len(points)<2:continue
  kind=way['tags']['highway'].split('_')[0]
  roads.append({'kind':kind,'points':[[round(x,2),round(y,2)] for x,y in simplify(points)]})
 result.append({'name':name,'zoom':14,'extent':extent,'roads':roads,'sourceDate':data.get('osm3s',{}).get('timestamp_osm_base','unknown')})
 print(name,len(roads),'roads',flush=True)
out={'attribution':'© OpenStreetMap contributors','license':'ODbL-1.0','source':'https://overpass-api.de/api/interpreter','cities':result}
Path('Assets/StarterMaps/streets.json').write_text(json.dumps(out,separators=(',',':'))+'\n')
