class_name WorldBuilder
extends Node3D
var env_node: WorldEnvironment
var sunlight: DirectionalLight3D
var detail_root: Node3D
var dust: GPUParticles3D
var armillary: Node3D
var rotor: Node3D
var carriage: Node3D
var world_id := 0
const SKY_COLORS := [Color("0b1d34"), Color("0d2936"), Color("435368"), Color("67827a"), Color("526e91")]

func material(color: Color, metallic := 0.0, rough := 0.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = rough
	return mat

func block(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func asset(name_: String, pos: Vector3, scale_: Vector3, parent: Node3D = self, low := false) -> Node3D:
	var node := RelicTile.model(name_, low)
	node.position = pos
	node.scale = scale_
	parent.add_child(node)
	return node

func build(which: int, quality: int) -> void:
	world_id = which
	var stone := material(Color("293b43") if which != 2 else Color("6b6b5d"), 0.1, 0.66)
	stone.albedo_texture = load("res://assets/textures/weathered_basalt_albedo.png")
	stone.normal_enabled = true
	stone.normal_texture = load("res://assets/textures/weathered_basalt_normal.png")
	stone.uv1_scale = Vector3(4, 4, 4)
	var gold := material(Color("977044"), 0.78, 0.30)
	asset("plinth", Vector3.ZERO, Vector3.ONE, self, quality < 2)
	var floor_transforms: Array[Transform3D] = []
	for x in range(-5, 6):
		for z in range(-5, 5):
			if which == 4 and abs(x) + abs(z) > 7: continue
			floor_transforms.append(Transform3D(Basis(Vector3.UP,0.006*sin(float(x*19+z))),Vector3(x*2.05,-0.86,z*2.05)))
	var floor_node := MultiMeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(2,0.35,2)
	floor_mesh.material = stone
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = floor_mesh
	multi.instance_count = floor_transforms.size()
	for i in range(floor_transforms.size()): multi.set_instance_transform(i,floor_transforms[i])
	floor_node.multimesh = multi
	add_child(floor_node)
	# Two mechanisms are physical bronze platforms under the relevant tile groups.
	rotor = Node3D.new()
	add_child(rotor)
	rotor.position = BoardState.ROTOR_CENTER + Vector3(0, -0.02, 0)
	var rotor_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.02
	cylinder.bottom_radius = 2.10
	cylinder.height = 0.15
	rotor_mesh.mesh = cylinder
	rotor_mesh.material_override = gold
	rotor_mesh.position.y = -0.15
	rotor.add_child(rotor_mesh)
	for i in range(24):
		var a := i * TAU / 24
		var tooth := block(rotor, Vector3(cos(a) * 1.97, -0.12, sin(a) * 1.97), Vector3(0.19, 0.17, 0.18), gold)
		tooth.rotation.y = -a
	carriage = Node3D.new()
	add_child(carriage)
	carriage.position = BoardState.CARRIAGE_HOME
	block(carriage, Vector3.ZERO, Vector3(2.54, 0.17, 4.15), gold)
	if which >= 2:
		block(self,Vector3(0,BoardState.BRIDGE_HEIGHT-0.13,0),Vector3(2.52,0.26,4.20),stone)
		for z in [-1.8,1.8]: block(self,Vector3(0,0.42,z),Vector3(1.65,1.2,0.28),gold)
	for x in [-3.8, -1.2]: block(self, Vector3(x, -0.34, 0), Vector3(0.10, 0.10, 4.8), gold)
	detail_root = Node3D.new()
	add_child(detail_root)
	for side in [-1, 1]:
		for z in [-7.0, -2.5, 3.0]:
			var col := asset("column", Vector3(side * 7.5, -0.65, z), Vector3(1.3, 2.1, 1.3), self, quality < 2)
			if which == 3 and z == -2.5:
				col.rotation.z = side * 0.19
				col.scale.y = 1.2
		for z in [-5.0, 0.0]:
			var brace := asset("timber", Vector3(side * 7.3, 3.7, z), Vector3(1.3, 1.4, 1.3), detail_root, quality < 2)
			brace.rotation.x = PI / 2.0
	for x in [-7.2, -2.4, 2.4, 7.2]:
		asset("arch", Vector3(x, 4.8, -8.2), Vector3(1.15, 1.15, 1.15), self, quality < 2)
		if abs(x) < 5: asset("column", Vector3(x, -0.7, -8.2), Vector3(1.1, 1.65, 1.1), self, quality < 2)
	armillary = asset("relic_08", Vector3(-0.7, 2.4, -10.2), Vector3.ONE * 7.2, detail_root, quality < 2)
	# Each world has its own spatial dressing, architecture accents, light and atmosphere.
	if which == 1:
		for i in range(10):
			var a := i * TAU / 10
			asset("crystal_cluster", Vector3(cos(a) * 6.2, -0.6, sin(a) * 6.2), Vector3.ONE * (1.3 + float(i % 3) * 0.4), detail_root, quality < 2)
	elif which == 2:
		for side in [-1, 1]:
			for z in [-6, -2, 2]: asset("relic_07", Vector3(side * 6.3, 0.0, z), Vector3.ONE * 2.5, detail_root, quality < 2)
		var marble := material(Color("9c9984"), 0.20, 0.2)
		marble.albedo_texture = load("res://assets/textures/veined_marble_albedo.png")
		block(self, Vector3(0, -0.55, -6.8), Vector3(10, 0.3, 2), marble)
	elif which == 3:
		for i in range(22):
			var a := i * 2.399
			var r := 5.0 + float(i % 4) * 0.6
			asset("fern", Vector3(cos(a)*r, -0.55, sin(a)*r), Vector3.ONE * 1.5, detail_root, quality < 2)
		for i in range(9):
			var rubble := block(detail_root, Vector3(-6 + i * 1.4, -0.25, -6.8), Vector3(0.8, 0.7, 0.9), stone)
			rubble.rotation = Vector3(i * 0.2, i * 0.4, i * 0.1)
	elif which == 4:
		for i in range(5):
			asset("arch", Vector3(0, 6.0 + i * 1.6, -11.0 - i * 4.5), Vector3.ONE * (2.8 + i * 0.2), detail_root, quality < 2)
		for side in [-1, 1]: asset("relic_09", Vector3(side * 5.6, 0.8, -3), Vector3.ONE * 4, detail_root, quality < 2)
		# Sculpted cloud banks beneath the suspended terrace; no billboard geometry.
		var clouds := ShaderMaterial.new()
		var cloud_shader := Shader.new()
		cloud_shader.code = "shader_type spatial; render_mode blend_mix,depth_draw_never,cull_back,unshaded; void fragment(){float edge=pow(max(dot(normalize(NORMAL),normalize(VIEW)),0.0),1.7); ALBEDO=vec3(0.69,0.77,0.84); ALPHA=edge*0.72;}"
		clouds.shader = cloud_shader
		for i in range(24):
			var cloud := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radial_segments = 16
			sphere.rings = 8
			cloud.mesh = sphere
			cloud.material_override = clouds
			cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a := i * 2.399
			cloud.position = Vector3(cos(a)*(12+i%4*3),-4.0-float(i%3),sin(a)*(12+i%4*3))
			cloud.scale = Vector3(9,2.8,7)
			detail_root.add_child(cloud)
	make_environment(which)
	make_particles(quality)
	apply_quality(quality)

func make_environment(which: int) -> void:
	env_node = WorldEnvironment.new()
	var env := Environment.new()
	env_node.environment = env
	add_child(env_node)
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var shader := Shader.new()
	shader.code = """shader_type sky;
uniform vec3 zenith : source_color = vec3(0.04, 0.1, 0.18);
uniform float stars = 1.0;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void sky() {
 vec3 d=normalize(EYEDIR); float h=max(d.y,0.0);
 vec3 c=mix(zenith*2.3,zenith*0.45,pow(h,0.35));
 vec3 cell=floor(d*440.0); float star=step(0.9983,hash(cell));
 float core=pow(max(0.0,1.0-length(fract(d*440.0)-0.5)*2.0),4.0);
 c+=star*core*stars*vec3(1.4,1.5,1.7);
 float nebula=pow(max(0.0,1.0-abs(d.x*0.5+d.z*0.3-d.y*0.8)),9.0);
 c+=nebula*vec3(0.018,0.036,0.045)*stars;
 COLOR=c;
}"""
	var sm := ShaderMaterial.new()
	sm.shader = shader
	sm.set_shader_parameter("zenith", SKY_COLORS[which])
	sm.set_shader_parameter("stars", 1.0 if which <= 1 else 0.15)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("94abb8")
	env.ambient_light_energy = 0.52
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = SKY_COLORS[which].lightened(0.15)
	env.fog_density = 0.007 if which != 4 else 0.014
	env.fog_sky_affect = 0.15
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48, -32, 0)
	sunlight.light_color = Color("f7d4a0") if which != 1 else Color("b8e3ee")
	sunlight.light_energy = 1.8
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 40
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sunlight)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 145, 0)
	fill.light_color = Color("84bdd1")
	fill.light_energy = 0.65
	add_child(fill)
	for side in [-1, 1]:
		var light := OmniLight3D.new()
		light.position = Vector3(side * 5.3, 2.7, -3)
		light.light_color = Color("f8aa55") if which != 1 else Color("51cbdf")
		light.light_energy = 3.4
		light.omni_range = 7
		add_child(light)
		asset("relic_05", Vector3(side * 5.3, 1.5, -3), Vector3.ONE * 2.0)

func make_particles(quality: int) -> void:
	dust = GPUParticles3D.new()
	dust.amount = 24 if quality < 2 else 90
	dust.lifetime = 16
	dust.preprocess = 4
	dust.visibility_aabb = AABB(Vector3(-10,-1,-10), Vector3(20,12,20))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(9, 4, 9)
	process.gravity = Vector3(0.006, -0.018, 0)
	process.initial_velocity_min = 0.01
	process.initial_velocity_max = 0.04
	process.scale_min = 0.008
	process.scale_max = 0.026
	process.color = Color(0.85, 0.74, 0.49, 0.6)
	dust.process_material = process
	var mesh := SphereMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := material(Color("c8aa71"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	dust.draw_pass_1 = mesh
	dust.position.y = 3
	add_child(dust)

func apply_quality(preset: int) -> void:
	var method := RenderingServer.get_current_rendering_method()
	var forward := method == "forward_plus"
	var env := env_node.environment
	env.ssao_enabled = forward and preset >= 2
	env.ssr_enabled = forward and preset == 3
	env.ssil_enabled = forward and preset == 3
	env.glow_enabled = forward and preset >= 2
	env.volumetric_fog_enabled = forward and preset == 3
	env.volumetric_fog_density = 0.012
	sunlight.shadow_enabled = preset > 0
	sunlight.light_angular_distance = 0.4 if forward and preset >= 2 else 0.0
	detail_root.visible = preset > 0
	dust.emitting = preset > 0
	get_viewport().msaa_3d = Viewport.MSAA_4X if preset >= 2 else Viewport.MSAA_DISABLED
	get_viewport().mesh_lod_threshold = 2.0 if preset < 2 else 1.0

func _process(delta: float) -> void:
	if is_instance_valid(armillary): armillary.rotation.y += delta * 0.035
