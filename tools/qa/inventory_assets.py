import json,struct,hashlib,csv
from pathlib import Path
root=Path(__file__).resolve().parents[2];out=root/'docs';rows=[]
for p in sorted((root/'assets').rglob('*')):
 if not p.is_file() or p.suffix=='.import' or p.name=='.gdignore':continue
 row={'path':str(p.relative_to(root)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'meshes':'','vertices':'','triangles':'','materials':'','uv_primitives':'','skins':'','animation_clips':'','provenance':'supplied project; rights not independently established in this pass'}
 if p.suffix=='.glb':
  b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n]);a=g.get('accessors',[]);prims=[v for m in g.get('meshes',[]) for v in m['primitives']]
  row.update(meshes=len(g.get('meshes',[])),vertices=sum(a[v['attributes']['POSITION']]['count'] for v in prims),triangles=sum(a[v['indices']]['count']//3 if 'indices' in v else a[v['attributes']['POSITION']]['count']//3 for v in prims if v.get('mode',4)==4),materials=len(g.get('materials',[])),uv_primitives=sum('TEXCOORD_0' in v['attributes'] for v in prims),skins=len(g.get('skins',[])),animation_clips=len(g.get('animations',[])))
 if '/quaternius/' in str(p):row['provenance']='Quaternius CC0; assets/weapons/quaternius/CREDITS.md'
 elif '/audio/' in str(p):row['provenance']='supplied project; see docs/EVENT_AUDIO_ASSETS.md for verified subset'
 elif '/ui/' in str(p):row['provenance']='supplied project; see assets/ui/ICON_CREDITS.md; font provenance requires original license files'
 rows.append(row)
(out/'ASSET_INVENTORY.json').write_text(json.dumps(rows,indent=2))
with open(out/'ASSET_INVENTORY.csv','w') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
print('Assets',len(rows),'GLBs',sum(r['path'].endswith('.glb') for r in rows),'triangles',sum(int(r['triangles'] or 0) for r in rows))
