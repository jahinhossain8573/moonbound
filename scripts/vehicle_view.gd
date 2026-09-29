extends Node3D
signal slot_picked(slot: String)
var model
var ship: Node3D
var camera: Camera3D
var angle: float = -0.48
var elevation: float = 0.13
var zoom: float = 11.8
var exploded: bool = false
var selected_slot: String = "Lunar lander"
var material_cache: Dictionary = {}
var targets: Dictionary = {}
var selection_ring: MeshInstance3D
var dragging: bool = false
var drag_distance: float = 0.0
var pointer_start: Vector2
var auto_rotate: bool = false
const IVORY = Color("e7ecef")
const DARK = Color("272932")
const ORANGE = Color("fe5d26")
const GOLD = Color("c94b20")
const BLUE = Color("5c646c")
const CYAN = Color("c7ef00")

func _ready() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("272932")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("e7ecef")
	e.ambient_light_energy = 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, -15)
	key.light_color = Color("f6f6f2")
	key.light_energy = 1.7
	add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 130, 0)
	fill.light_color = Color("d9f795")
	fill.light_energy = 1.1
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.far = 100
	add_child(camera)
	camera.current = true
	build_hangar()
	rebuild()
	update_camera()

func mat(color: Color, metallic: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var key = str(color) + str(metallic) + str(glow)
	if material_cache.has(key): return material_cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.78
	m.metallic_specular = 0.25
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.4
	material_cache[key] = m
	return m

func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, metallic: float = 0.0, glow: bool = false) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.material_override = mat(color, metallic, glow)
	parent.add_child(n)
	return n

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metallic: float = 0.0, glow: bool = false) -> MeshInstance3D:
	var b = BoxMesh.new()
	b.size = size
	return mesh_node(parent, b, pos, color, metallic, glow)

func cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var c = CylinderMesh.new()
	c.bottom_radius = bottom
	c.top_radius = top
	c.height = height
	c.radial_segments = 48
	return mesh_node(parent, c, pos, color, metallic)

func ring(parent: Node3D, pos: Vector3, radius: float, color: Color, thick: float = 0.025) -> MeshInstance3D:
	var t = TorusMesh.new()
	t.inner_radius = radius - thick
	t.outer_radius = radius + thick
	t.rings = 48
	t.ring_segments = 10
	return mesh_node(parent, t, pos, color, 0.4, true)

func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var n = box(parent, (a+b)/2, Vector3(width, a.distance_to(b), width), color, 0.6)
	var dir = (b-a).normalized()
	var axis = Vector3.UP.cross(dir)
	if axis.length() > 0.001: n.quaternion = Quaternion(axis.normalized(), Vector3.UP.angle_to(dir))

func build_hangar() -> void:
	box(self, Vector3(0, -0.35, 0), Vector3(30, 0.5, 30), Color("2b2e37"))
	for i in range(-12, 13):
		box(self, Vector3(i, -0.091, 0), Vector3(0.013, 0.008, 26), Color("3c404a"))
		box(self, Vector3(0, -0.09, i), Vector3(26, 0.008, 0.013), Color("3c404a"))
	cylinder(self, Vector3(0, 0, 0), 3.2, 3.2, 0.16, Color("3c4049"), 0.55)
	ring(self, Vector3(0, 0.1, 0), 3.05, Color("c7ef00"), 0.018)
	ring(self, Vector3(0, 0.11, 0), 2.65, ORANGE, 0.022)
	for i in range(24):
		var a = i * TAU / 24
		var n = box(self, Vector3(sin(a)*2.85, 0.115, cos(a)*2.85), Vector3(0.07, 0.01, 0.20), ORANGE)
		n.rotation.y = a
	for side in [-1, 1]:
		var x = side * 4.5
		for z in [-2.3, -3.1]:
			box(self, Vector3(x, 5.5, z), Vector3(0.15, 11, 0.15), Color("51545e"), 0.4)
		for y in range(0, 12, 2):
			beam(self, Vector3(x, y, -2.3), Vector3(x, y+1.7, -3.1), 0.07, Color("60646b"))
			box(self, Vector3(x, y, -2.7), Vector3(1, 0.12, 1.1), Color("424550"))
		box(self, Vector3(x, 5.5, -2.2), Vector3(0.025, 10.5, 0.025), Color("c7ef00"), 0, true)
	box(self, Vector3(0, 10.7, -3), Vector3(9, 0.15, 0.2), Color("51545e"))

func group(slot: String, y: float) -> Node3D:
	var n = Node3D.new()
	n.position.y = y
	ship.add_child(n)
	targets[slot] = n
	return n

func ghost(parent: Node3D, radius: float, height: float) -> void:
	for y in [0, height]: ring(parent, Vector3(0, y, 0), radius, Color("62676e"), 0.012)
	for a in [0, PI/2, PI, PI*1.5]:
		beam(parent, Vector3(sin(a)*radius, 0, cos(a)*radius), Vector3(sin(a)*radius, height, cos(a)*radius), 0.018, Color("62676e"))

func rebuild() -> void:
	if ship:
		remove_child(ship)
		ship.queue_free()
	ship = Node3D.new()
	add_child(ship)
	targets.clear()
	var gap = 0.45 if exploded else 0.0
	var n = group("Launch vehicle", 0.4)
	if model.installed.has("Launch vehicle"):
		var heavy = model.installed["Launch vehicle"] == "titan"
		cylinder(n, Vector3(0, 2.25, 0), 0.78, 0.78, 3.8, IVORY, 0.3)
		cylinder(n, Vector3(0, 0.5, 0), 0.79, 0.79, 0.42, DARK, 0.6)
		cylinder(n, Vector3(0, 3.8, 0), 0.80, 0.80, 0.46, ORANGE, 0.35)
		for y in [0.8, 1.0, 3.35, 4.1]: cylinder(n, Vector3(0, y, 0), 0.80, 0.80, 0.055, DARK, 0.6)
		for x in [-0.4, 0.4]:
			cylinder(n, Vector3(x, 0.04, 0), 0.30, 0.17, 0.5, DARK, 0.8)
		for x in [-1.0, 1.0]:
			cylinder(n, Vector3(x, 1.5, 0), 0.31, 0.31, 2.4 if heavy else 2.0, ORANGE, 0.3)
			cylinder(n, Vector3(x, 2.8 if heavy else 2.6, 0), 0.31, 0.05, 0.35, IVORY)
			cylinder(n, Vector3(x, 0.3 if heavy else 0.5, 0), 0.30, 0.15, 0.35, DARK, 0.8)
			beam(n, Vector3(x, 0.6, 0), Vector3(x*1.65, 0.2, 0), 0.12, IVORY)
		for a in range(4):
			var p = Vector3(sin(a*PI/2)*0.79, 2.4, cos(a*PI/2)*0.79)
			var stripe = box(n, p, Vector3(0.14, 0.65, 0.018), DARK)
			stripe.rotation.y = a*PI/2
	else: ghost(n, 0.8, 4.2)
	n = group("Service module", 4.65 + gap)
	if model.installed.has("Service module"):
		# Apollo-inspired service bus: straight pressure hull, radiator bays and its own engine.
		cylinder(n, Vector3(0, 0.53, 0), 0.73, 0.73, 0.91, IVORY, 0.42)
		for y in [0.07, 0.99]: cylinder(n, Vector3(0, y, 0), 0.77, 0.77, 0.10, DARK, 0.65)
		for a in range(8):
			var v = a * TAU / 8
			var panel = box(n, Vector3(sin(v)*0.745, 0.53, cos(v)*0.745), Vector3(0.43, 0.66, 0.035), BLUE if a % 2 == 0 else DARK, 0.35)
			panel.rotation.y = v
		for a in range(4):
			var v = a * TAU / 4 + PI / 4
			box(n, Vector3(sin(v)*0.82, 0.86, cos(v)*0.82), Vector3(0.16, 0.15, 0.16), DARK, 0.55)
		cylinder(n, Vector3(0, -0.10, 0), 0.28, 0.17, 0.23, DARK, 0.7)
		if model.installed["Service module"] == "vector_x":
			cylinder(n, Vector3(0, 0.92, 0), 0.775, 0.775, 0.045, ORANGE, 0.4)
	else: ghost(n, 0.73, 1.05)
	n = group("Lunar lander", 5.75 + gap*2)
	if model.installed.has("Lunar lander"):
		# The faceted descent stage, ascent cabin and four landing feet read as one craft.
		var descent = cylinder(n, Vector3(0, 0.37, 0), 0.83, 0.75, 0.64, GOLD, 0.48)
		(descent.mesh as CylinderMesh).radial_segments = 8
		for a in range(8):
			var v = a * TAU / 8
			var foil = box(n, Vector3(sin(v)*0.81, 0.36, cos(v)*0.81), Vector3(0.34, 0.40, 0.025), ORANGE if a % 2 == 0 else GOLD, 0.35)
			foil.rotation.y = v
		var cabin = cylinder(n, Vector3(0, 0.98, 0), 0.56, 0.43, 0.61, IVORY, 0.38)
		(cabin.mesh as CylinderMesh).radial_segments = 8
		for x in [-0.23, 0.23]:
			box(n, Vector3(x, 1.04, 0.51), Vector3(0.27, 0.24, 0.035), DARK, 0.25)
		cylinder(n, Vector3(0, 1.30, 0), 0.38, 0.38, 0.07, DARK, 0.55)
		for a in range(4):
			var v = a * TAU / 4 + PI/4
			var top = Vector3(sin(v)*0.78, 0.73, cos(v)*0.78)
			var bottom = Vector3(sin(v)*1.65, -0.05, cos(v)*1.65)
			beam(n, top, bottom, 0.08, IVORY)
			beam(n, top-Vector3(0, 0.5, 0), bottom, 0.035, DARK)
			cylinder(n, bottom, 0.24, 0.24, 0.06, DARK, 0.5)
		if model.installed["Lunar lander"] == "heron_p":
			box(n, Vector3(0.54, 0.98, 0.47), Vector3(0.15, 0.15, 0.15), CYAN, 0, true)
	else: ghost(n, 0.85, 1.35)
	n = group("Habitat", 7.18 + gap*3)
	if model.installed.has("Habitat"):
		cylinder(n, Vector3(0, 0.42, 0), 0.78, 0.78, 0.82, IVORY, 0.1)
		for y in [0.1, 0.3, 0.55, 0.75]: cylinder(n, Vector3(0, y, 0), 0.80, 0.80, 0.025, GOLD, 0.4)
		box(n, Vector3(0, 0.4, 0.79), Vector3(0.38, 0.48, 0.04), DARK)
	else: ghost(n, 0.78, 0.82)
	n = group("Crew capsule", 8.08 + gap*4)
	if model.installed.has("Crew capsule"):
		# The return command module keeps its blunt heat shield and tapered crew cabin.
		cylinder(n, Vector3(0, 0.10, 0), 0.85, 0.85, 0.20, DARK, 0.62)
		cylinder(n, Vector3(0, 0.62, 0), 0.81, 0.29, 0.92, IVORY, 0.34)
		cylinder(n, Vector3(0, 0.26, 0), 0.77, 0.73, 0.045, ORANGE, 0.3)
		cylinder(n, Vector3(0, 1.17, 0), 0.29, 0.23, 0.20, DARK, 0.62)
		cylinder(n, Vector3(0, 1.37, 0), 0.19, 0.035, 0.20, IVORY)
		for x in [-0.23, 0.23]:
			var window = box(n, Vector3(x, 0.70, 0.59), Vector3(0.24, 0.20, 0.045), DARK, 0.55)
			window.rotation.x = -0.4
		if model.installed["Crew capsule"] == "aurora_c":
			cylinder(n, Vector3(0, 0.34, 0), 0.72, 0.68, 0.045, CYAN, 0.25)
	else: ghost(n, 0.75, 1.3)
	n = group("Surface power", 5.25 + gap)
	if model.installed.has("Surface power"):
		var wide = model.installed["Surface power"] == "sol_x"
		for side in [-1, 1]:
			beam(n, Vector3(side*0.7, 0, 0), Vector3(side*2.6, 0, 0), 0.06, GOLD)
			box(n, Vector3(side*2.05, 0.02, 0), Vector3(2.15 if wide else 1.75, 0.065, 1.30), DARK, 0.7)
			for ix in range(6):
				for iz in range(4): box(n, Vector3(side*2.05+(ix-2.5)*0.27, 0.06, (iz-1.5)*0.30), Vector3(0.245, 0.016, 0.27), BLUE, 0.8)
	n = group("Communications", 7.0 + gap*2)
	if model.installed.has("Communications"):
		beam(n, Vector3(0.6, 0, 0), Vector3(1.5, 0.45, 0), 0.045, IVORY)
		var dish = cylinder(n, Vector3(1.55, 0.52, 0), 0.38, 0.14, 0.20, IVORY, 0.7)
		dish.rotation.z = -0.65
		beam(n, Vector3(1.55, 0.52, 0), Vector3(1.8, 0.82, 0), 0.025, DARK)
	n = group("Science", 6.25 + gap*2)
	if model.installed.has("Science"):
		box(n, Vector3(-1.0, 0.1, 0.5), Vector3(0.35, 0.4, 0.38), DARK, 0.5)
		var lens = cylinder(n, Vector3(-1.0, 0.13, 0.72), 0.11, 0.11, 0.13, BLUE, 0.7)
		lens.rotation.x = PI/2
	n = group("Life support", 7.25 + gap*3)
	if model.installed.has("Life support"):
		for x in [-0.4, 0.4]: cylinder(n, Vector3(x, 0.3, -0.8), 0.16, 0.16, 0.62, ORANGE, 0.5)
	n = group("Rover", 6.1 + gap*2)
	if model.installed.has("Rover"):
		box(n, Vector3(0, 0, -1.1), Vector3(1.1, 0.32, 0.6), GOLD, 0.7)
		for x in [-0.5, 0.5]:
			for z in [-0.85, -1.35]:
				var wheel = cylinder(n, Vector3(x, -0.15, z), 0.20, 0.20, 0.12, DARK)
				wheel.rotation.z = PI/2
	n = group("Repair kit", 7.1 + gap*2)
	if model.installed.has("Repair kit"): box(n, Vector3(-0.8, 0, -0.4), Vector3(0.3, 0.4, 0.5), ORANGE)
	select_slot(selected_slot)

func select_slot(slot: String) -> void:
	selected_slot = slot
	if is_instance_valid(selection_ring): selection_ring.queue_free()
	if targets.has(slot):
		selection_ring = ring(ship, Vector3(0, targets[slot].position.y + 0.1, 0), 1.12, CYAN, 0.013)

func update_camera() -> void:
	var center = Vector3(0, 5.1 + (0.8 if exploded else 0), 0)
	camera.position = center + Vector3(sin(angle)*18, 5.0 + elevation*12, cos(angle)*18)
	camera.look_at(center)
	camera.size = zoom + (2 if exploded else 0)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed:
				drag_distance = 0
				pointer_start = event.position
			elif drag_distance < 6: pick_at(event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom + (-0.6 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.6), 10.5, 19)
			update_camera()
	if event is InputEventMouseMotion and dragging:
		drag_distance += event.relative.length()
		angle -= event.relative.x * 0.009
		elevation = clampf(elevation + event.relative.y * 0.004, -0.3, 0.6)
		update_camera()

func pick_at(pos: Vector2) -> void:
	var best = 65.0
	var picked = ""
	for slot in targets:
		var target = targets[slot].global_position + Vector3(0, 0.45, 0)
		if slot == "Launch vehicle": target += Vector3(0, 1.5, 0)
		if slot == "Surface power": target.x += 2
		var d = camera.unproject_position(target).distance_to(pos)
		if d < best:
			best = d
			picked = slot
	if picked != "": slot_picked.emit(picked)

func _process(delta: float) -> void:
	if auto_rotate and not dragging:
		angle += delta * 0.12
		update_camera()
