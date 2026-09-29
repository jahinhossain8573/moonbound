extends "res://scripts/vehicle_view.gd"
const Flight = preload("res://scripts/flight_sim.gd")
const EARTH_SCENE = preload("res://assets/earth.glb")
const EARTH_SOURCE_RADIUS = 100.0
var sim
var map_mode = false
var map_zoom = 170.0
var moon_locked = false
var orbit_angle = 0.5
var camera_pitch = 0.2
var camera_distance = 24.0
var map_pan = Vector3.ZERO
var ground: Node3D
var lunar_ground: Node3D
var earth: Node3D
var moon: MeshInstance3D
var stars: MultiMeshInstance3D
var map_root: Node3D
var map_earth: Node3D
var map_moon: MeshInstance3D
var marker: MeshInstance3D
var trajectory: MeshInstance3D
var planned_trajectory: MeshInstance3D
var moon_motion: MeshInstance3D
var future_moon_ring: MeshInstance3D
var miss_line: MeshInstance3D
var future_moon: MeshInstance3D
var burn_marker: MeshInstance3D
var site_marker: MeshInstance3D
var site_label: Label3D
var moon_track: MeshInstance3D
var map_labels: Array = []
var plume: Node3D
var outer_flame: MeshInstance3D
var inner_flame: MeshInstance3D
var debris: Array = []
var last_stage = 0
var path_clock = 0.0
var clock = 0.0
const MAP_SCALE = 0.000125

func _ready() -> void:
	super._ready()
	selection_ring.visible = false
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48
	camera.far = 15000
	camera.near = 0.1
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.background_color = Color("272932")
			child.environment.ambient_light_energy = 0.65
	earth = earth_model(self, 1)
	moon = planet(self, 1, true)
	build_lunar_ground()
	build_stars()
	build_map()
	plume = Node3D.new()
	ship.add_child(plume)
	outer_flame = cylinder(plume, Vector3(0,-2.4,0),0.03,0.65,4.8,ORANGE)
	outer_flame.material_override = flame_material(ORANGE)
	inner_flame = cylinder(plume, Vector3(0,-1.4,0),0.02,0.36,2.8,IVORY)
	inner_flame.material_override = flame_material(IVORY)
	refresh_stage()
	update_flight(0)

func flame_material(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	return m

func build_hangar() -> void:
	ground = Node3D.new()
	add_child(ground)
	box(ground, Vector3(0,-0.55,0), Vector3(3000,1,3000), Color("30333a"))
	cylinder(ground, Vector3(0,0,0),8,8,0.2,Color("454951"),0.4)
	ring(ground,Vector3(0,.12,0),7.3,CYAN,.07)
	for x in [-20,20]:
		box(ground,Vector3(x,.02,0),Vector3(.12,.03,160),IVORY)
	for z in range(-70,80,8):
		box(ground,Vector3(0,.02,z),Vector3(1,.03,3),ORANGE)
	for x in [-5.5,5.5]:
		for z in [-3.5,-4.5]:
			box(ground,Vector3(x,6,z),Vector3(.16,12,.16),Color("777e83"),.6)
		for y in range(0,12,2):
			beam(ground,Vector3(x,y,-3.5),Vector3(x,y+2,-4.5),.08,IVORY)
			box(ground,Vector3(x,y,-4),Vector3(.8,.12,1.3),Color("515562"))
		box(ground,Vector3(x,6,-3.4),Vector3(.05,11,.05),CYAN,0,true)
	for x in [-60,45,80]:
		box(ground,Vector3(x,3,-90),Vector3(24,6,16),Color("414550"))
	for x in range(-100,110,20):
		box(ground,Vector3(x,.2,30),Vector3(.25,.4,.25),ORANGE,0,true)

func build_lunar_ground() -> void:
	lunar_ground = Node3D.new()
	add_child(lunar_ground)
	box(lunar_ground,Vector3(0,-.6,0),Vector3(3000,1,3000),Color("73767b"))
	var rng = RandomNumberGenerator.new()
	rng.seed = 2037
	for i in range(90):
		var p = Vector3(rng.randf_range(-500,500),0,rng.randf_range(-500,500))
		if p.length() < 12: continue
		var r = rng.randf_range(2,25)
		cylinder(lunar_ground,p, r,r*.85,.22,Color("545760"))
		var rim = ring(lunar_ground,p+Vector3(0,.08,0),r,Color("85898e"),r*.05)
		rim.material_override = mat(Color("85898e"))
	for i in range(70):
		var p = Vector3(rng.randf_range(-90,90),.1,rng.randf_range(-90,90))
		if p.length()<6: continue
		var rock = box(lunar_ground,p,Vector3.ONE*rng.randf_range(.15,.7),Color("60646a"))
		rock.rotation=Vector3(rng.randf(),rng.randf(),rng.randf())

func earth_model(parent: Node3D, radius_value: float) -> Node3D:
	var anchor = Node3D.new()
	anchor.name = "Earth"
	parent.add_child(anchor)
	var instance = EARTH_SCENE.instantiate() as Node3D
	anchor.add_child(instance)
	instance.scale = Vector3.ONE / EARTH_SOURCE_RADIUS
	anchor.scale = Vector3.ONE * radius_value
	return anchor

func planet(parent: Node3D, radius_value: float, lunar: bool) -> MeshInstance3D:
	var sphere = SphereMesh.new()
	sphere.radius = radius_value
	sphere.height = radius_value * 2
	sphere.radial_segments = 96
	sphere.rings = 48
	var n = mesh_node(parent,sphere,Vector3.ZERO,IVORY)
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode specular_disabled;
uniform bool lunar = false;
varying vec3 local_normal;
void vertex(){local_normal=NORMAL;}
float hash(vec3 p){ return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p){ vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z); }
void fragment(){
 vec3 p=normalize(local_normal);
 float n=noise(p*5.0)+noise(p*13.0)*0.35+noise(p*36.0)*0.12;
 vec3 dark=vec3(0.153,0.161,0.196);
 vec3 light=vec3(0.906,0.925,0.937);
 if(lunar){ float cr=noise(p*38.0); ALBEDO=mix(vec3(.28,.29,.31),light*.7,n*.7)*(.8+.2*cr); ROUGHNESS=1.0; }
 else { float land=smoothstep(.62,.70,n); vec3 terrain=mix(dark,vec3(.38,.42,.31),land); float clouds=smoothstep(.72,.9,noise(p*10.0+vec3(3.0))+noise(p*25.0)*.25); ALBEDO=mix(terrain,light,clouds*.8); ROUGHNESS=.85; }
}
"""
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("lunar",lunar)
	n.material_override = material
	return n

func build_stars() -> void:
	stars = MultiMeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.4
	mesh.height = 2.8
	mesh.radial_segments = 4
	mesh.rings = 2
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 900
	var rng = RandomNumberGenerator.new()
	rng.seed = 426
	for i in range(900):
		var p = Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()*6500
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(.3,1.5)),p))
	stars.multimesh = multi
	stars.material_override = flame_material(IVORY.darkened(.2))
	add_child(stars)

func line_mesh(points: PackedVector3Array, color: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points: mesh.surface_add_vertex(p)
	mesh.surface_end()
	n.mesh = mesh
	n.material_override = flame_material(color)
	map_root.add_child(n)
	return n

func dashed_line(points: PackedVector3Array, color: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(0, points.size() - 1, 2):
		mesh.surface_add_vertex(points[i])
		mesh.surface_add_vertex(points[i + 1])
	mesh.surface_end()
	n.mesh = mesh
	n.material_override = flame_material(color)
	map_root.add_child(n)
	return n

func clear_forecast() -> void:
	for node in [planned_trajectory, moon_motion, future_moon_ring, miss_line]:
		if is_instance_valid(node): node.queue_free()
	planned_trajectory = null
	moon_motion = null
	future_moon_ring = null
	miss_line = null
	future_moon.visible = false
	burn_marker.visible = false
	map_labels[6].visible = false
	map_labels[7].visible = false

func show_future_moon(moon_at_arrival: Vector3, arrival_time: float) -> void:
	var future = moon_at_arrival * MAP_SCALE
	future_moon.position = future
	future_moon.visible = true
	map_labels[6].position = future + Vector3(0, 15, 0)
	map_labels[6].visible = true
	var circle = PackedVector3Array()
	for i in range(65):
		var a = TAU * i / 64.0
		circle.append(future + Vector3(sin(a), cos(a), 0) * 13.0)
	future_moon_ring = line_mesh(circle, ORANGE)
	var travel = PackedVector3Array()
	var start_angle = atan2(sim.moon_position().x, sim.moon_position().y)
	var angle_delta = sqrt(Flight.EARTH_MU / pow(Flight.MOON_D, 3)) * (arrival_time - sim.elapsed)
	for i in range(97):
		var a = start_angle + angle_delta * i / 96.0
		travel.append(Vector3(sin(a), cos(a), 0) * Flight.MOON_D * MAP_SCALE)
	moon_motion = dashed_line(travel, ORANGE.darkened(.25))

func draw_transfer_plan(plan: Dictionary) -> void:
	show_future_moon(plan.moon_arrival, plan.arrival_time)
	var departure: Vector3 = plan.departure
	burn_marker.position = departure * MAP_SCALE
	burn_marker.visible = true
	map_labels[7].position = burn_marker.position + Vector3(0, 12, 0)
	map_labels[7].visible = true
	var r = departure.length()
	var target_r = Flight.MOON_D - Flight.TRANSFER_PASS_RADIUS
	var eccentricity = (target_r - r) / (target_r + r)
	var p = r * (1.0 + eccentricity)
	var angle = atan2(departure.x, departure.y)
	var points = PackedVector3Array()
	for i in range(193):
		var anomaly = PI * i / 192.0
		var distance = p / (1.0 + eccentricity * cos(anomaly))
		points.append(Vector3(sin(angle + anomaly), cos(angle + anomaly), 0) * distance * MAP_SCALE)
	planned_trajectory = dashed_line(points, CYAN)

func map_label(text: String, color: Color) -> Label3D:
	var l = Label3D.new()
	l.text = text
	l.font = load("res://fonts/Audiowide-Regular.ttf")
	l.font_size = 32
	l.pixel_size = .22
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	map_root.add_child(l)
	map_labels.append(l)
	return l

func build_map() -> void:
	map_root = Node3D.new()
	add_child(map_root)
	map_earth = earth_model(map_root, Flight.EARTH_R * MAP_SCALE)
	map_moon = planet(map_root, Flight.MOON_R * MAP_SCALE, true)
	var dot = SphereMesh.new()
	dot.radius = 2.5
	dot.height = 5
	marker = mesh_node(map_root,dot,Vector3.ZERO,CYAN,0,true)
	marker.material_override = flame_material(CYAN)
	future_moon = mesh_node(map_root,dot,Vector3.ZERO,ORANGE,0,true)
	future_moon.material_override = flame_material(ORANGE)
	future_moon.scale = Vector3.ONE * 1.7
	future_moon.visible = false
	burn_marker = mesh_node(map_root,dot,Vector3.ZERO,CYAN,0,true)
	burn_marker.material_override = flame_material(CYAN)
	burn_marker.visible = false
	var points = PackedVector3Array()
	for i in range(181):
		var a = i*TAU/180
		points.append(Vector3(sin(a),cos(a),0)*Flight.MOON_D*MAP_SCALE)
	moon_track = line_mesh(points,Color("515562"))
	map_label("EARTH",IVORY)
	map_label("MOON / TARGET",ORANGE)
	map_label("SHIP",CYAN)
	map_label("AP",CYAN)
	map_label("PE",ORANGE)
	map_label("ENCOUNTER",ORANGE)
	map_label("MOON AT ARRIVAL",ORANGE).visible = false
	map_label("BURN",CYAN).visible = false
	site_marker = mesh_node(map_root,dot,sim.site_position()*MAP_SCALE,ORANGE,0,true)
	site_label = map_label(str(sim.landing_site.name).to_upper()+" / LANDING SITE",ORANGE)

func refresh_stage() -> void:
	if sim.stage > last_stage and sim.elapsed - sim.stage_times[sim.stage] < 30:
		var slot = "Launch vehicle" if last_stage == 0 else "Service module"
		var original = targets[slot]
		var detached = original.duplicate()
		add_child(detached)
		detached.global_transform = original.global_transform
		debris.append({"node":detached,"born":sim.stage_times[sim.stage],"age":0.0,"velocity":-sim.direction()*2 + Vector3(-.5,0,.4)})
	last_stage = sim.stage
	targets["Launch vehicle"].visible = sim.stage == 0
	targets["Service module"].visible = sim.stage < 2
	targets["Surface power"].position.y = 6.65 if sim.stage == 2 else 5.25
	if plume: plume.position.y = [0.2,4.65,5.75][sim.stage]

func update_camera() -> void:
	# The assembly base calls this during startup. Flight owns the camera afterward.
	if not is_instance_valid(camera): return
	if map_mode:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var focus = sim.moon_position()*MAP_SCALE if moon_locked else Vector3.ZERO
		var visible_size = map_zoom
		if moon_locked and future_moon.visible:
			focus = (focus + future_moon.position) * .5
			visible_size = maxf(visible_size, sim.moon_position().distance_to(future_moon.position / MAP_SCALE) * MAP_SCALE * 1.8 + 95)
		camera.size = visible_size
		focus += map_pan
		camera.position = focus + Vector3(0, 0, 950)
		camera.look_at(focus,Vector3.UP)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		var up = sim.radial()
		if moon_locked and (sim.body == "Moon" or sim.altitude() > 10000):
			var toward_moon = (sim.moon_position() - sim.pos).normalized()
			var right = up.cross(toward_moon)
			if right.length() < 0.01: right = Vector3(0,0,1).cross(toward_moon)
			right = right.normalized()
			camera.position = (-toward_moon + right*sin(orbit_angle)*0.35 + up*sin(camera_pitch)*0.25).normalized()*camera_distance
			camera.look_at(toward_moon * camera_distance * 0.15, up)
		else:
			var right = up.cross(Vector3(0,0,1)).normalized()
			var forward = right.cross(up).normalized()
			camera.position = (right*sin(orbit_angle)*cos(camera_pitch) + forward*cos(orbit_angle)*cos(camera_pitch) + up*sin(camera_pitch))*camera_distance
			camera.look_at(Vector3.ZERO, up)

func update_flight(dt: float) -> void:
	if not is_instance_valid(earth): return
	clock += dt
	refresh_stage()
	ship.basis = sim.attitude
	if map_mode:
		var icon_scale = map_zoom / 300.0
		ship.scale = Vector3.ONE * icon_scale
		ship.position = sim.pos * MAP_SCALE - sim.attitude * Vector3(0,[5.0,7.0,7.8][sim.stage],0) * icon_scale
	else:
		ship.scale = Vector3.ONE
		ship.position = -(sim.attitude * Vector3(0,[5.0,7.0,7.8][sim.stage],0))
	ship.visible = not sim.crashed
	ground.visible = not map_mode and sim.body == "Earth" and sim.altitude() < 2500
	ground.position = -sim.radial()*(maxf(0,sim.altitude()-12)*.25+5)
	ground.quaternion = Quaternion(Vector3.UP,sim.radial())
	lunar_ground.visible = not map_mode and sim.body == "Moon" and sim.altitude() < 3500
	lunar_ground.position = -sim.radial()*maxf(2.1,sim.altitude()*.25)
	lunar_ground.quaternion = Quaternion(Vector3.UP,sim.radial())
	for item in debris:
		item.age = sim.elapsed - item.born
		item.node.position += item.velocity*dt
		item.node.rotate_z(dt*.08)
		item.node.visible = not map_mode and item.age < 25
	plume.visible = sim.engine and sim.throttle > .005 and sim.fuel[sim.stage] > 0 and not sim.crashed
	plume.scale = Vector3(1,clampf(sim.throttle,.1,1)*(1+sin(clock*47)*.08),1)
	stars.visible = map_mode or sim.altitude() > 15000 or sim.body == "Moon"
	map_root.visible = map_mode
	earth.visible = not map_mode and (sim.body != "Earth" or sim.altitude() > 2000)
	moon.visible = not map_mode and not lunar_ground.visible
	place_earth()
	place_body(moon,sim.moon_position()-sim.pos,Flight.MOON_R)
	if map_mode:
		map_moon.position = sim.moon_position()*MAP_SCALE
		site_marker.position = sim.site_position()*MAP_SCALE
		site_marker.scale = Vector3.ONE*clampf(map_zoom/1500.0,0.04,0.5)
		site_label.position = site_marker.position+Vector3(0,-map_zoom*.035,0)
		marker.position = sim.pos*MAP_SCALE
		marker.scale = Vector3.ONE * clampf(map_zoom/600,.12,2)
		marker.visible = sim.crashed
		map_labels[0].position = Vector3(0,-46,0)
		map_labels[1].position = map_moon.position+Vector3(0,14,0)
		map_labels[2].position = marker.position+Vector3(-20,19,0)
		for l in map_labels: l.pixel_size = map_zoom*.0009
		path_clock -= dt
		if path_clock <= 0:
			path_clock = .5
			if is_instance_valid(trajectory): trajectory.queue_free()
			clear_forecast()
			var predicted = sim.prediction()
			var points = PackedVector3Array()
			var farthest = sim.pos
			var nearest = sim.pos
			for p in predicted:
				points.append(p*MAP_SCALE)
				if p.distance_to(sim.center()) > farthest.distance_to(sim.center()): farthest=p
				if p.distance_to(sim.center()) < nearest.distance_to(sim.center()): nearest=p
			if points.size()>1: trajectory=line_mesh(points,CYAN)
			map_labels[3].position = farthest*MAP_SCALE+Vector3(0,6,0)
			map_labels[4].position = nearest*MAP_SCALE-Vector3(0,6,0)
			map_labels[5].visible = sim.prediction_encounter and sim.body == "Earth"
			map_labels[5].position = sim.predicted_encounter*MAP_SCALE+Vector3(0,14,0)
			map_labels[3].visible = not sim.transfer_requested and sim.body == "Earth"
			map_labels[4].visible = not sim.transfer_requested and sim.body == "Earth"
			if sim.body == "Earth" and sim.transfer_requested and not sim.transfer_done:
				draw_transfer_plan(sim.transfer_plan())
			elif sim.body == "Earth" and sim.transfer_done and sim.closest_approach < Flight.MOON_D:
				show_future_moon(sim.predicted_moon, sim.predicted_encounter_time)
				if sim.prediction_encounter:
					map_labels[5].visible = false
					map_labels[6].text = "ENCOUNTER / MOON ARRIVAL"
				else:
					map_labels[6].text = "MOON AT ARRIVAL"
				if not sim.prediction_encounter:
					miss_line = line_mesh(PackedVector3Array([sim.predicted_encounter * MAP_SCALE, sim.predicted_moon * MAP_SCALE]), ORANGE)
			# Encounter text lives in the fixed flight HUD; only location markers
			# belong to the moving world-space trajectory.
			map_labels[5].visible = false
			map_labels[6].visible = false
	update_camera()

func place_body(n: Node3D, offset: Vector3, physical_radius: float) -> void:
	var distance = offset.length()
	var visual_distance = 2200.0
	n.position = offset.normalized()*visual_distance
	n.scale = Vector3.ONE * minf(2190,visual_distance*physical_radius/maxf(distance,physical_radius))

func place_earth() -> void:
	if sim.body != "Earth":
		place_body(earth, -sim.pos, Flight.EARTH_R)
		return
	var ratio = Flight.EARTH_R / maxf(sim.pos.length(), Flight.EARTH_R)
	var angle = minf(PI * .48, asin(ratio) + deg_to_rad(9))
	var distance = 2200.0
	earth.position = -sim.radial() * sin(angle) * distance + Vector3(0, 0, -cos(angle) * distance)
	earth.scale = Vector3.ONE * minf(2190, distance * ratio)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var factor = .85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.18
			if map_mode: map_zoom=clampf(map_zoom*factor,30,1500)
			else: camera_distance=clampf(camera_distance*factor,14,95)
	if event is InputEventMouseMotion and dragging:
		if map_mode:
			var container = get_viewport().get_parent() as Control
			var height = container.size.y if container else get_viewport().size.y
			var units_per_pixel = camera.size / maxf(1.0, height)
			map_pan += Vector3(-event.relative.x, event.relative.y, 0) * units_per_pixel
		else:
			orbit_angle -= event.relative.x*.006
			camera_pitch = clampf(camera_pitch+event.relative.y*.006,-.9,1.2)
	update_camera()

func _process(_dt: float) -> void:
	pass
