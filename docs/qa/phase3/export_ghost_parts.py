"""Extract articulated Ghost-Ops limb shells from the editable source catalog."""
from pathlib import Path
import bpy
from mathutils import Vector

directory = Path(__file__).resolve().parents[3] / 'assets/characters'
collection = bpy.data.collections['Ghost_Ops_Troll']
groups = {
    'UpperArm': ('Upper arm', 'Rounded shoulder'),
    'Forearm': ('Elbow', 'Forearm', 'Cuff'),
    'Thigh': ('Trousers leg',),
    'Shin': ('Shin', 'Knee protector'),
    'Foot': ('Left boot', 'Right boot', 'Separate toe', 'Flip-flop sole', 'Open flip-flop strap'),
}
targets = {
    'UpperArm': (.16, .38, .22, 0.0), 'Forearm': (.17, .33, .19, .006),
    'Thigh': (.22, .39, .29, .0), 'Shin': (.19, .38, .24, .0),
    'Foot': (.23, .16, .35, -.32),
}
for side, sign in [('L', -1), ('R', 1)]:
    for part, prefixes in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        objects = [o for o in collection.objects if o.type == 'MESH'
                   and o.name.startswith(prefixes)
                   and (o.matrix_basis @ (sum((Vector(b) for b in o.bound_box), Vector()) / 8)).x * sign > 0.10]
        # The original positional inventory stores mesh transforms in matrix_basis.
        if not objects:
            raise ValueError((side, part))
        points = [o.matrix_basis @ Vector(co) for o in objects for co in o.bound_box]
        low = Vector(tuple(min(v[i] for v in points) for i in range(3)))
        high = Vector(tuple(max(v[i] for v in points) for i in range(3)))
        w, h, d, y = targets[part]
        center = (low + high) / 2
        for original in objects:
            copy = original.copy()
            copy.data = original.data.copy()
            copy.parent = None
            copy.location = Vector()
            for vertex in copy.data.vertices:
                v = original.matrix_basis @ vertex.co
                vertex.co = Vector(((v.x-center.x)*w/(high.x-low.x), -(v.y-center.y)*d/(high.y-low.y) + .035, y + (v.z-high.z)*h/(high.z-low.z)))
            bpy.context.scene.collection.objects.link(copy)
            copy.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(directory/f'Ghost_{part}_{side}.glb'), export_format='GLB', use_selection=True, export_yup=True, export_animations=False)
