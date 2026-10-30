"""Original Astral Forge art. Run: blender -b --python tools/create_assets.py
All geometry, UVs and PBR textures are generated here, with two exported LODs.
No asset downloads or Blender add-ons are required. Coordinates are Z-up in Blender.
"""
import bpy, math, os, random, sys
import numpy as np
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'models')
TEX = os.path.join(ROOT, 'assets', 'textures')
os.makedirs(OUT, exist_ok=True)
os.makedirs(TEX, exist_ok=True)
random.seed(47)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def image(name, pixels):
    h, w = pixels.shape[:2]
    im = bpy.data.images.new(name, width=w, height=h)
    im.pixels.foreach_set(pixels.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(TEX, name+'.png')
    im.file_format = 'PNG'
    im.save()
    return im

def material(name, color, metal=0, rough=.4, textured=False, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Metallic'].default_value = metal
    bs.inputs['Roughness'].default_value = rough
    if emission:
        bs.inputs['Emission Color'].default_value = (*color, 1)
        bs.inputs['Emission Strength'].default_value = emission
    if textured:
        size = 1024
        yy, xx = np.mgrid[0:size, 0:size] / size
        rng = np.random.default_rng(73)
        height = np.zeros((size, size))
        for f, a in [(3,.26),(9,.12),(24,.06),(61,.024)]:
            height += np.sin(xx*f*math.tau+np.sin(yy*f*.61*math.tau))*np.cos(yy*f*math.tau)*a
        height += rng.normal(0,.02, height.shape)
        if name == 'Veined marble':
            height = .6*height + .14*np.sin((xx+yy)*30+height*12)**12
        elif name == 'Oiled walnut':
            height = .35*height + .12*np.sin(xx*310+np.sin(yy*9)*3)
        elif metal:
            height = .24*height + .035*np.sin(yy*980)
        pixels = np.ones((size,size,4))
        for c in range(3): pixels[:,:,c] = np.clip(color[c]*(1+height*.8),0,1)
        albedo = image(name.lower().replace(' ','_')+'_albedo', pixels)
        node = m.node_tree.nodes.new('ShaderNodeTexImage'); node.image=albedo
        m.node_tree.links.new(node.outputs['Color'], bs.inputs['Base Color'])
        normal = np.ones((size,size,4))
        normal[:,:,0] = .5 + (np.roll(height,1,1)-np.roll(height,-1,1))*.65
        normal[:,:,1] = .5 + (np.roll(height,1,0)-np.roll(height,-1,0))*.65
        normal[:,:,2] = 1
        im = image(name.lower().replace(' ','_')+'_normal',normal)
        im.colorspace_settings.name='Non-Color'
        tx = m.node_tree.nodes.new('ShaderNodeTexImage'); tx.image=im
        nm = m.node_tree.nodes.new('ShaderNodeNormalMap')
        m.node_tree.links.new(tx.outputs['Color'],nm.inputs['Color'])
        m.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
        pixels[:,:,:3] = np.clip(rough+height[:,:,None]*.15,.05,.95)
        im = image(name.lower().replace(' ','_')+'_roughness',pixels)
        im.colorspace_settings.name='Non-Color'
        tx = m.node_tree.nodes.new('ShaderNodeTexImage'); tx.image=im
        m.node_tree.links.new(tx.outputs['Color'],bs.inputs['Roughness'])
    return m

gold=material('Brushed gold',(.66,.39,.115),.82,.28,True)
bronze=material('Patinated bronze',(.23,.13,.065),.72,.4,True)
stone=material('Weathered basalt',(.10,.14,.17),.10,.64,True)
marble=material('Veined marble',(.45,.48,.44),.04,.36,True)
wood=material('Oiled walnut',(.19,.075,.025),0,.6,True)
silver=material('Antique silver',(.51,.61,.65),.82,.25)
dark=material('Obsidian',(.018,.04,.051),.38,.23)
blue=material('Luminous aquamarine',(.07,.55,.70),.25,.16,emission=.26)
green=material('Cut emerald',(.035,.38,.21),.3,.18,emission=.08)
amber=material('Warm amber',(.95,.40,.075),.23,.19,emission=.8)
glass=material('Smoked crystal',(.22,.48,.56),.24,.12)
glass.diffuse_color=(.22,.48,.56,.48)
glass.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.48
glass.surface_render_method='DITHERED'
leafmat=material('Forest fern',(.10,.21,.075),0,.77)

def assign(o, mat):
    o.data.materials.append(mat)
    return o

def bevel(o, amount=.025, segments=3):
    mod=o.modifiers.new('Machined edges','BEVEL'); mod.width=amount; mod.segments=segments
    mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL'); mod.keep_sharp=True
    return o

def cube(name, loc, scale, mat, edge=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    assign(o,mat)
    if edge: bevel(o,edge)
    return o

def cyl(name, loc, radius, depth, mat, vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=bpy.context.object; o.name=name; assign(o,mat); bevel(o,.012,2)
    for p in o.data.polygons: p.use_smooth=len(p.vertices)==4
    return o

def sphere(name,loc,radius,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=radius,location=loc)
    o=bpy.context.object; o.name=name; assign(o,mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def ring(name,loc,major,minor,mat,rot=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=8,location=loc,major_radius=major,minor_radius=minor,rotation=rot)
    o=bpy.context.object; o.name=name; assign(o,mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def rod(name,a,b,r,mat):
    a,b=Vector(a),Vector(b)
    o=cyl(name,(a+b)/2,r,(a-b).length,mat,16)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o

def lathe(name,profile,mat,segments=48):
    verts=[]; faces=[]
    for radius,z in profile:
        for i in range(segments):
            a=i*math.tau/segments; verts.append((math.cos(a)*radius,math.sin(a)*radius,z))
    for j in range(len(profile)-1):
        for i in range(segments):
            k=j*segments+i; n=j*segments+(i+1)%segments
            faces.append((k,n,n+segments,k+segments))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); assign(o,mat)
    for p in mesh.polygons:p.use_smooth=True
    return o

def mesh(name,verts,faces,mat):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o); assign(o,mat); return o

def crystal(loc,r,h,mat):
    verts=[]
    for z,rad in [(0,r*.7),(h*.22,r),(h*.78,r*.8)]:
        for i in range(6):
            a=i*math.tau/6; verts.append((loc[0]+rad*math.cos(a),loc[1]+rad*math.sin(a),loc[2]+z))
    verts.append((loc[0]+r*.15,loc[1],loc[2]+h))
    faces=[]
    for j in range(2):
        for i in range(6):faces.append((j*6+i,j*6+(i+1)%6,(j+1)*6+(i+1)%6,(j+1)*6+i))
    for i in range(6):faces.append((12+i,12+(i+1)%6,18))
    faces.append(tuple(reversed(range(6))))
    return mesh('Hexagonal mineral',verts,faces,mat)

def export(name):
    bpy.ops.object.select_all(action='SELECT')
    # Apply bevels, generate UVs, batch geometry by material to limit draw calls.
    objects=list(bpy.context.selected_objects)
    for o in objects:
        bpy.context.view_layer.objects.active=o
        if o.type!='MESH':continue
        for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.012)
        bpy.ops.object.mode_set(mode='OBJECT')
    for mat in bpy.data.materials:
        group=[o for o in list(bpy.context.scene.objects) if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat]
        if not group:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:o.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        bpy.ops.object.join()
        group[0].name=mat.name.replace(' ','_')
    bpy.ops.object.select_all(action='SELECT')
    kwargs=dict(export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),**kwargs)
    for o in list(bpy.context.selected_objects):
        if o.type=='MESH' and len(o.data.polygons)>150:
            bpy.context.view_layer.objects.active=o
            mod=o.modifiers.new('Mobile LOD','DECIMATE');mod.ratio=.42
            bpy.ops.object.modifier_apply(modifier=mod.name)
    replacements=[]
    small_images={}
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image and node.image.size[0]>256:
                original=node.image
                if original.name not in small_images:
                    small=original.copy();small.name=original.name+'_mobile';small.scale(256,256)
                    small_images[original.name]=small
                node.image=small_images[original.name]
                replacements.append((node,original))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'_low.glb'),**kwargs)
    for node,original in replacements:node.image=original
    for small in small_images.values():bpy.data.images.remove(small)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def tile():
    cube('Beveled basalt body',(0,0,.105),(1.16,1.28,.21),stone,.065)
    cube('Gold reveal',(0,0,.215),(1.12,1.24,.055),gold,.045)
    cube('Obsidian inset',(0,0,.251),(1.035,1.155,.046),dark,.048)
    for x in [-.47,.47]:
        for y in [-.53,.53]:
            o=cube('Inlaid corner',(x,y,.284),(.105,.105,.012),gold,.009);o.rotation_euler.z=math.pi/4
    for i in range(9):
        for side in [-1,1]:cube('Incised scale',((i-4)*.075,side*.57,.28),(.018,.042,.008),bronze,.002)
    export('tile')

def compass():
    cyl('Compass casing',(0,0,.32),.37,.1,gold)
    cyl('Enamel dial',(0,0,.38),.32,.035,dark)
    ring('Turned bezel',(0,0,.41),.335,.023,gold)
    for i in range(24):
        a=i*math.tau/24
        o=cube('Dial mark',(.278*math.sin(a),.278*math.cos(a),.412),(.012,.052 if i%3==0 else .024,.009),silver,.002);o.rotation_euler.z=-a
    mesh('Compass needle',[(0,.28,.44),(-.068,0,.44),(0,-.28,.44),(.068,0,.44),(0,0,.49)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],gold)
    sphere('Ruby pivot',(0,0,.49),.035,amber)
    export('relic_00')

def orb():
    cyl('Orb foot',(0,0,.31),.24,.07,silver)
    for i in range(3):
        a=i*math.tau/3
        rod('Cradle',(.2*math.cos(a),.2*math.sin(a),.32),(.24*math.cos(a),.24*math.sin(a),.56),.022,gold)
    sphere('Crystal sphere',(0,0,.58),.265,glass)
    crystal((0,0,.42),.08,.27,blue)
    ring('Equatorial armature',(0,0,.58),.28,.014,silver,rot=(.2,.3,0))
    export('relic_01')

def key():
    ring('Openwork key bow',(0,.27,.36),.17,.045,gold)
    ring('Inner key bow',(0,.27,.36),.095,.018,bronze)
    rod('Octagonal stem',(0,.12,.36),(0,-.38,.36),.052,gold)
    for y,w in [(-.32,.18),(-.22,.13)]:cube('Key ward',(w/2,y,.36),(w,.065,.095),gold,.012)
    sphere('Bow jewel',(0,.27,.36),.052,blue)
    export('relic_02')

def gear():
    ring('Gear rim',(0,0,.38),.25,.075,bronze)
    for i in range(14):
        a=i*math.tau/14
        o=cube('Involute tooth',(.34*math.cos(a),.34*math.sin(a),.38),(.14,.10,.11),gold,.012);o.rotation_euler.z=a
    for i in range(6):
        a=i*math.tau/6
        rod('Wheel spoke',(.08*math.cos(a),.08*math.sin(a),.38),(.25*math.cos(a),.25*math.sin(a),.38),.025,gold)
    ring('Axle bearing',(0,0,.38),.095,.03,silver)
    export('relic_03')

def hourglass():
    for z in [.31,.85]:cyl('Silver capital',(0,0,z),.24,.055,silver)
    lathe('Blown hourglass',[(.17,.35),(.17,.43),(.11,.50),(.035,.57),(.11,.64),(.17,.72),(.17,.81)],glass)
    lathe('Golden sand',[(0,.37),(.15,.37),(.02,.49),(0,.49)],gold)
    for i in range(3):
        a=i*math.tau/3;rod('Turned support',(.205*math.cos(a),.205*math.sin(a),.34),(.205*math.cos(a),.205*math.sin(a),.82),.018,silver)
    rod('Falling sand',(0,0,.47),(0,0,.68),.007,gold)
    export('relic_04')

def lantern():
    for z in [.32,.75]:cyl('Hexagonal lantern cap',(0,0,z),.255,.07,bronze,6)
    for i in range(6):
        a=i*math.tau/6;rod('Lantern rib',(.22*math.cos(a),.22*math.sin(a),.35),(.22*math.cos(a),.22*math.sin(a),.73),.019,gold)
    cyl('Glass enclosure',(0,0,.54),.198,.36,glass,6)
    crystal((0,0,.37),.09,.29,amber)
    ring('Carrying loop',(0,0,.87),.095,.016,gold,rot=(math.pi/2,0,0))
    export('relic_05')

def telescope():
    cyl('Tripod foot',(0,0,.30),.21,.055,bronze)
    rod('Pivot',(0,0,.32),(0,0,.55),.035,gold)
    a=Vector((-.29,-.20,.45));b=Vector((.30,.20,.72));d=b-a
    rod('Optical barrel',a,b,.115,bronze)
    for f,r in [(0,.075),(.13,.13),(.62,.13),(1,.155)]:
        o=cyl('Turned lens housing',a+d*f,r,.045,gold);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    o=cyl('Objective lens',b+d.normalized()*.025,.128,.012,blue);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    export('relic_06')

def crown():
    lathe('Crown band',[(.31,.31),(.33,.33),(.32,.43),(.30,.45)],gold)
    for z in [.33,.42]:ring('Crown beading',(0,0,z),.32,.016,bronze)
    for i in range(7):
        a=i*math.tau/7
        verts=[]
        for r,angle,z in [(.31,a-.30,.41),(.31,a+.30,.41),(.37,a,.73),(.30,a,.49)]:verts.append((r*math.cos(angle),r*math.sin(angle),z))
        o=mesh('Royal fleur',verts,[(0,1,3),(0,3,2),(1,2,3)],gold)
        solid=o.modifiers.new('Cast thickness','SOLIDIFY');solid.thickness=.022
        sphere('Crown emerald',(.355*math.cos(a),.355*math.sin(a),.67),.04,green)
    export('relic_07')

def astrolabe():
    cyl('Armillary plinth',(0,0,.31),.20,.065,bronze)
    rod('Polar axis',(0,0,.34),(0,0,.85),.025,gold)
    for rot in [(math.pi/2,0,0),(.45,.7,0),(.1,0,0)]:ring('Armillary orbit',(0,0,.62),.29,.018,gold,rot)
    sphere('Celestial core',(0,0,.62),.10,blue)
    for i in range(12):
        a=i*math.tau/12;sphere('Ecliptic stud',(.29*math.cos(a),.29*math.sin(a),.62),.022,silver)
    export('relic_08')

def relic():
    cube('Relic plinth',(0,0,.32),(.46,.43,.08),bronze,.035)
    crystal((0,0,.35),.22,.55,stone)
    for z in [.43,.53,.63]:
        rod('Inlaid rune',(-.09,-.192,z),(.06,-.192,z+.05),.009,gold)
        rod('Inlaid rune',(.06,-.192,z+.05),(.08,-.192,z-.02),.009,gold)
    ring('Floating halo',(0,0,.68),.28,.012,gold)
    export('relic_09')

def emerald():
    cyl('Crystal socket',(0,0,.31),.27,.06,bronze,8)
    crystal((0,0,.34),.19,.54,green)
    crystal((-.22,.06,.32),.10,.27,blue)
    crystal((.17,-.12,.32),.095,.31,green)
    export('relic_10')

def vessel():
    lathe('Astral amphora',[(.10,.29),(.17,.32),(.20,.41),(.23,.55),(.18,.65),(.09,.70),(.09,.81),(.14,.83),(.14,.85),(.07,.85),(.07,.78)],blue)
    for z,r in [(.32,.17),(.64,.18),(.82,.14)]:ring('Amphora filigree',(0,0,z),r,.016,gold)
    for x in [-.21,.21]:ring('Amphora handle',(x,0,.65),.105,.024,gold,rot=(math.pi/2,0,0))
    export('relic_11')

def column():
    for z,r,d in [(.10,.55,.20),(.27,.43,.15),(.41,.36,.14),(3.3,.36,.13),(3.44,.43,.14),(3.57,.55,.15)]:cyl('Turned capital',(0,0,z),r,d,marble)
    cyl('Stone shaft',(0,0,1.83),.29,2.72,stone)
    for i in range(12):
        a=i*math.tau/12;rod('Carved flute',(.28*math.cos(a),.28*math.sin(a),.5),(.28*math.cos(a),.28*math.sin(a),3.15),.024,marble)
    for z in [.56,3.12]:ring('Bronze collar',(0,0,z),.31,.022,gold)
    export('column')

def arch():
    for i in range(13):
        a=(i+.5)*math.pi/13
        o=cube('Arch voussoir',(math.cos(a)*2,0,math.sin(a)*2),(.47,.65,.46),marble,.045);o.rotation_euler.y=-a
    for x in [-2,2]:cube('Arch support',(x,0,-.8),(.48,.65,1.6),stone,.055)
    export('arch')

def plinth():
    for z,r,d,mat in [(-.50,5.35,.30,stone),(-.28,5.05,.14,bronze),(-.13,4.92,.16,stone)]:cyl('Observatory dais',(0,0,z),r,d,mat,96)
    for r in [4.75,4.5,4.3]:ring('Celestial engraving',(0,0,-.035),r,.015,gold)
    for i in range(48):
        a=i*math.tau/48
        o=cube('Dais index',(4.6*math.cos(a),4.6*math.sin(a),-.027),(.11,.022,.012),gold,.002);o.rotation_euler.z=a
    export('plinth')

def foliage():
    for stem in range(9):
        a=stem*2.4;length=.5+stem*.06
        end=Vector((math.cos(a)*length,math.sin(a)*length,.3+length*.5))
        rod('Fern stem',(0,0,0),end,.008,leafmat)
        for i in range(1,7):
            p=end*i/8;side=Vector((-math.sin(a),math.cos(a),.1))*(.2-i*.018)
            for sign in [-1,1]:
                tip=p+side*sign+end*.09
                mesh('Fern frond',[p-end*.03,p+end*.08,tip+Vector((0,0,.025))],[(0,1,2)],leafmat)
    export('fern')

if '--special-only' not in sys.argv:
    tile();compass();orb();key();gear();hourglass();lantern();telescope();crown();astrolabe();relic();emerald();vessel()
    column();arch();plinth();foliage()
    cube('Ancient timber',(0,0,0),(.26,.28,3.8),wood,.04)
    for z in [-1.6,1.6]:cube('Iron timber band',(0,0,z),(.29,.31,.12),bronze,.015)
    export('timber')
    for i in range(7):crystal((random.uniform(-.6,.6),random.uniform(-.6,.6),0),random.uniform(.13,.30),random.uniform(.6,1.8),blue if i%2 else glass)
    export('crystal_cluster')

cube('Ice casing',(0,0,.50),(1.01,1.12,.46),glass,.07)
for i in range(5):
    a=i*1.27
    crystal((math.cos(a)*.40,math.sin(a)*.46,.65),.038,.11,glass)
export('frost_shell')

cube('Sealed chamber',(0,0,.46),(1.02,1.12,.38),bronze,.045)
cube('Carved stone lid',(0,0,.68),(1.04,1.14,.08),stone,.035)
cube('Inset panel',(0,0,.725),(.82,.92,.025),dark,.025)
for side in [-1,1]:
    cube('Lid filigree',(side*.46,0,.74),(.035,1.02,.025),gold,.008)
    cube('Lid filigree',(0,side*.51,.74),(.94,.035,.025),gold,.008)
for i in range(8):
    a=i*math.tau/8
    rod('Guardian star',(0,0,.75),(.31*math.cos(a),.31*math.sin(a),.75),.012,gold)
ring('Guardian seal',(0,0,.75),.20,.018,gold)
for x in [-.3,.3]:cyl('Lid hinge',(x,.53,.70),.045,.13,gold).rotation_euler.y=math.pi/2
export('compartment')

for row in [-.22,.22]:
    for i in range(10):
        ring('Forged chain link',(-.46+i*.10,row,.68),.055,.012,silver,rot=(math.pi/2 if i%2 else 0,0,0))
cube('Sealed padlock',(0,-.02,.74),(.20,.22,.18),gold,.025)
ring('Lock shackle',(0,.07,.80),.08,.020,bronze,rot=(math.pi/2,0,0))
sphere('Keyhole',(0,-.134,.76),.025,dark)
export('relic_seal')
print('ASTRAL FORGE: asset generation complete (22 designs, two LODs each).')
