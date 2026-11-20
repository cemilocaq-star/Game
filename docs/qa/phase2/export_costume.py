from pathlib import Path
import bpy

out=Path(__file__).resolve().parents[3]/'assets/characters'
for name,prefix,target_height in [('Golden_Pilot_Troll',('Windblown scarf','Scarf hanging panel'),.27),('Neon_Cyan_Riot_Troll',('Shield rim','Shield face','Viewport frame','Viewport lens','Rivet','Rear shield handle','Shield legend','Shield insignia'),.88)]:
    collection=bpy.data.collections[name]
    parts=[o for o in collection.objects if o.name.startswith(prefix)]
    bpy.ops.object.select_all(action='DESELECT')
    from mathutils import Vector
    coords=[o.matrix_basis @ Vector(b) for o in parts for b in o.bound_box]
    low=Vector(tuple(min(p[i] for p in coords) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in coords) for i in range(3)))
    origin=Vector((low.x if name.startswith('Golden') else (low.x+high.x)/2,high.y,(low.z+high.z)/2))
    scale=target_height/(high.z-low.z)
    for o in parts:
        copy=o.copy()
        copy.data=o.data.copy()
        copy.parent=None
        copy.data.transform(o.matrix_basis)
        for v in copy.data.vertices:v.co=(v.co-origin)*scale
        copy.location=Vector()
        bpy.context.scene.collection.objects.link(copy)
        copy.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'_Gear.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
