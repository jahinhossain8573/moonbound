extends Control
const Mission = preload("res://scripts/mission.gd")
const VehicleView = preload("res://scripts/vehicle_view.gd")
const BG = Color("272932")
const PANEL = Color("30333d")
const CARD = Color("383c47")
const BORDER = Color("515562")
const TEXT = Color("e7ecef")
const MUTED = Color("b3bac2")
const LIME = Color("c7ef00")
const ORANGE = Color("fe5d26")
const RED = Color("ff7b66")
var model = Mission.new()
var save_path: String = Mission.SAVE_PATH
var page: int = 1
var selected_slot: String = "Lunar lander"
var show_locked_upgrades: bool = false
var ui: VBoxContainer
var view_container: SubViewportContainer
var viewport: SubViewport
var world
var overlay: Control
var status_label: Label
var status_text: String = "Choose a module, compare its trade-offs, then install it."
var save_notice: String = "AUTOSAVE ON"
var test_busy: bool = false
var mono: SystemFont
var sans: FontFile
var bold: FontFile
var logo_font: FontFile
var slider_thumb: Texture2D
var slider_thumb_hover: Texture2D
var export_dialog: FileDialog
var flight_screen: Control

func _ready() -> void:
	sans = load("res://fonts/Unbounded.ttf")
	bold = load("res://fonts/Audiowide-Regular.ttf")
	logo_font = load("res://fonts/Electrolize-Regular.ttf")
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "monospace"])
	slider_thumb = slider_handle(ORANGE)
	slider_thumb_hover = slider_handle(LIME)
	var theme = Theme.new()
	theme.default_font = sans
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	self.theme = theme
	var backdrop = ColorRect.new()
	backdrop.color = BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	if model.load_from(save_path):
		status_text = "Campaign restored. Continue your Lunar Dawn design."
		if model.integrated: page = 2
	elif FileAccess.file_exists(save_path):
		status_text = "Could not read the campaign save. A fresh draft is open; save manually to replace it."
		# Preserve an unreadable original until the player makes a new change.
	build_view()
	render()
	export_dialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = PackedStringArray(["*.json ; Mission manifest"])
	export_dialog.current_file = "lunar-dawn-manifest.json"
	export_dialog.file_selected.connect(func(path):
		var result = model.export_manifest(path)
		notify("Manifest exported to " + path if result == OK else "Export failed. Choose a writable folder.")
	)
	add_child(export_dialog)
	if "--flight" in OS.get_cmdline_user_args() and model.delivered: call_deferred("start_flight")

func style(color: Color, border: Color = BORDER, radius: int = 7, padding: int = 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

func slider_handle(color: Color) -> Texture2D:
	var img = Image.create(22, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in range(22):
		for x in range(22):
			var distance = Vector2(x - 10.5, y - 10.5).length()
			if distance <= 9.8:
				img.set_pixel(x, y, LIME if distance > 7.4 else color)
	return ImageTexture.create_from_image(img)

func slider_track(color: Color) -> StyleBoxFlat:
	var s = style(color, color, 5, 0)
	s.set_border_width_all(0)
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

func label(text: String, size: int = 15, color: Color = TEXT, font: Font = null) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font: l.add_theme_font_override("font", font)
	return l

func paragraph(text: String, size: int = 14, color: Color = MUTED) -> Label:
	var l = label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func button(text: String, action: Callable, primary: bool = false, active: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 38
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_font_override("font", bold)
	b.add_theme_stylebox_override("normal", style(LIME if primary else (Color("414936") if active else CARD), LIME if active else BORDER, 5, 10))
	b.add_theme_stylebox_override("hover", style(Color("d7f94a") if primary else Color("454a54"), LIME, 5, 10))
	b.add_theme_stylebox_override("pressed", style(Color("afd000") if primary else Color("505660"), LIME, 5, 10))
	b.add_theme_stylebox_override("focus", style(Color(0,0,0,0), LIME, 5, 10))
	b.add_theme_stylebox_override("disabled", style(Color("343740"), Color("4b4e57"), 5, 10))
	b.add_theme_color_override("font_color", BG if primary else (LIME if active else TEXT))
	b.add_theme_color_override("font_hover_color", BG if primary else TEXT)
	b.add_theme_color_override("font_pressed_color", BG if primary else TEXT)
	b.add_theme_color_override("font_disabled_color", Color("858b92"))
	b.pressed.connect(action)
	return b

func column(gap: int = 10) -> VBoxContainer:
	var c = VBoxContainer.new()
	c.add_theme_constant_override("separation", gap)
	return c

func row(gap: int = 10) -> HBoxContainer:
	var r = HBoxContainer.new()
	r.add_theme_constant_override("separation", gap)
	return r

func panel(parent: Node, color: Color = PANEL, padding: int = 18) -> VBoxContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, BORDER, 8, padding))
	parent.add_child(p)
	var c = column()
	p.add_child(c)
	return c

func spacer(parent: Node) -> Control:
	var s = Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(s)
	return s

func separator(parent: Node) -> void:
	var line = HSeparator.new()
	line.add_theme_stylebox_override("separator", style(BORDER, BORDER, 0, 0))
	line.custom_minimum_size.y = 1
	parent.add_child(line)

func eyebrow(parent: Node, text: String) -> void:
	parent.add_child(label(text, 11, MUTED, mono))

func build_view() -> void:
	view_container = SubViewportContainer.new()
	view_container.stretch = true
	view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_container.custom_minimum_size = Vector2(340, 270)
	view_container.mouse_default_cursor_shape = Control.CURSOR_DRAG
	viewport = SubViewport.new()
	viewport.size = Vector2i(600, 580)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view_container.add_child(viewport)
	world = VehicleView.new()
	world.model = model
	viewport.add_child(world)
	world.slot_picked.connect(func(slot):
		if test_busy: return
		selected_slot = slot
		show_locked_upgrades = false
		page = 1
		render()
	)
	view_container.gui_input.connect(func(event): world.handle_input(event))

func render() -> void:
	if view_container.get_parent(): view_container.get_parent().remove_child(view_container)
	if ui:
		remove_child(ui)
		ui.queue_free()
	ui = column(0)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.offset_left = 24
	ui.offset_right = -24
	ui.offset_top = 18
	ui.offset_bottom = -16
	add_child(ui)
	build_header()
	build_nav()
	var content = row(16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.add_child(content)
	var left_scroll = ScrollContainer.new()
	left_scroll.custom_minimum_size.x = 296
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(left_scroll)
	var left = column(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	if page == 0: build_brief(left)
	elif page == 1: build_library(left)
	else: build_tests(left)
	build_center(content)
	var right_scroll = ScrollContainer.new()
	right_scroll.custom_minimum_size.x = 292
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(right_scroll)
	var right = column(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	if page == 0: build_crew(right)
	else: build_telemetry(right)
	build_footer()
	world.select_slot(selected_slot)

func build_header() -> void:
	var h = row(14)
	h.custom_minimum_size.y = 66
	ui.add_child(h)
	var logo = label("◈", 42, LIME)
	h.add_child(logo)
	var brand = column(0)
	h.add_child(brand)
	brand.add_child(label("MOONBOUND", 29, TEXT, logo_font))
	brand.add_child(label("MISSION DESIGN / LUNAR PROGRAM", 10, MUTED, mono))
	spacer(h)
	var mission_title = column(2)
	h.add_child(mission_title)
	mission_title.add_child(label("LUNAR DAWN", 14, TEXT, bold))
	mission_title.add_child(label("02 CREW  /  72 HOURS  /  "+Mission.ORBITS[model.orbit_profile].tag, 10, MUTED, mono))
	mission_title.add_child(label("%d FUNDS  /  DAY %02d OF 24" % [1000 - model.spent, model.day], 10, ORANGE, mono))
	spacer(h)
	h.add_child(button("?  Guide", show_help))
	h.add_child(button("Save", func():
		persist()
		notify("Campaign saved." if save_notice == "SAVED LOCALLY" else "Save failed. Check folder permissions.")
	))
	h.add_child(button("New", confirm_reset))

func build_nav() -> void:
	var n = row(8)
	n.custom_minimum_size.y = 64
	ui.add_child(n)
	for i in range(3):
		var b = button(["01   Mission planning", "02   Vehicle assembly", "03   Qualification"][i], func():
			if test_busy: return
			page = i
			render(), false, page == i)
		b.custom_minimum_size = Vector2(217, 40)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.add_child(b)
	spacer(n)
	var stamp = label("●  " + ("LAUNCH BLOCKED" if model.delivered and not model.valid_design() else ("FLIGHT CLEARED" if model.delivered else ("INTEGRATED" if model.integrated else "DESIGN IN PROGRESS"))), 11, RED if model.delivered and not model.valid_design() else LIME, mono)
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.add_child(stamp)

func build_center(parent: Node) -> void:
	var c = column(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	var top = PanelContainer.new()
	top.add_theme_stylebox_override("panel", style(PANEL, BORDER, 7, 15))
	c.add_child(top)
	var r = row()
	top.add_child(r)
	var title = column(3)
	r.add_child(title)
	eyebrow(title, "VEHICLE ASSEMBLY BAY  /  01")
	title.add_child(label("Dawn Explorer", 25, TEXT, bold))
	spacer(r)
	var designation = label("LD–01\n" + ("QUALIFIED" if model.is_ready() else "PROTOTYPE"), 11, LIME, mono)
	designation.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(designation)
	c.add_child(view_container)
	var tools_row = row(6)
	c.add_child(tools_row)
	var rotate_btn = button("↻  Orbit", func():
		world.auto_rotate = not world.auto_rotate
		render(), false, world.auto_rotate)
	tools_row.add_child(rotate_btn)
	tools_row.add_child(button("Exploded view", func():
		world.exploded = not world.exploded
		world.rebuild()
		world.update_camera()
		render(), false, world.exploded))
	tools_row.add_child(button("Reset view", func():
		world.angle = -0.48
		world.elevation = 0.13
		world.zoom = 11.8
		world.update_camera()
	))
	spacer(tools_row)
	var hint = label("DRAG TO ORBIT", 9, MUTED, mono)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tools_row.add_child(hint)
	var bottom = panel(c, PANEL, 14)
	var br = row()
	bottom.add_child(br)
	eyebrow(br, "ASSEMBLY MANIFEST")
	spacer(br)
	var essentials = 0
	for slot in Mission.SLOTS.slice(0, 9):
		if model.installed.has(slot): essentials += 1
	br.add_child(label("%02d / 09 REQUIRED" % essentials, 10, LIME if essentials == 9 else ORANGE, mono))
	var slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 4)
	bottom.add_child(slots_row)
	var short_names = ["LIFT", "CMD", "SVC", "LUNAR", "HAB", "PWR", "LINK", "SCI", "LIFE"]
	for i in range(9):
		var slot = Mission.SLOTS[i]
		var b = button(short_names[i], func():
			if test_busy: return
			selected_slot = slot
			show_locked_upgrades = false
			page = 1
			render(), false, selected_slot == slot)
		b.add_theme_font_size_override("font_size", 10)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_color_override("font_color", LIME if model.installed.has(slot) else MUTED)
		b.add_theme_stylebox_override("normal", style(Color("414936") if model.installed.has(slot) else CARD, LIME if selected_slot == slot else BORDER, 4, 4))
		b.tooltip_text = module_name(slot) + (" · installed" if model.installed.has(slot) else " · empty")
		slots_row.add_child(b)
	bottom.add_child(label("Click a system above or a module on the spacecraft to inspect it.", 12, MUTED))
	c.move_child(bottom.get_parent(), 1)

func module_name(slot: String) -> String:
	match slot:
		"Crew capsule": return "Command module"
		"Lunar lander": return "Lunar module"
		_: return slot

func build_library(parent: Node) -> void:
	var intro = column(4)
	parent.add_child(intro)
	eyebrow(intro, "DESIGN / INSTALL / ITERATE")
	intro.add_child(label("Component library", 23, TEXT, bold))
	var quick = button("Load reference design", func():
		model.reference_design()
		changed("Reference design loaded. Modify any module before manufacturing.")
	)
	quick.disabled = model.integrated
	intro.add_child(quick)
	var selector = OptionButton.new()
	selector.custom_minimum_size.y = 42
	selector.add_theme_stylebox_override("normal", style(CARD, LIME, 6, 12))
	selector.add_theme_stylebox_override("hover", style(Color("454a50"), LIME, 6, 12))
	selector.add_theme_stylebox_override("pressed", style(Color("414936"), ORANGE, 6, 12))
	selector.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, LIME, 6, 12))
	selector.add_theme_stylebox_override("disabled", style(PANEL, BORDER, 6, 12))
	selector.add_theme_icon_override("arrow", load("res://assets/dropdown-arrow.svg"))
	selector.add_theme_constant_override("arrow_margin", 14)
	selector.add_theme_font_override("font", bold)
	selector.add_theme_font_size_override("font_size", 14)
	selector.add_theme_color_override("font_color", TEXT)
	selector.add_theme_color_override("font_hover_color", TEXT)
	selector.add_theme_color_override("font_pressed_color", LIME)
	var menu = selector.get_popup()
	menu.add_theme_stylebox_override("panel", style(PANEL, LIME, 6, 8))
	menu.add_theme_stylebox_override("hover", style(Color("414936"), LIME, 4, 6))
	menu.add_theme_font_override("font", bold)
	menu.add_theme_font_size_override("font_size", 13)
	menu.add_theme_color_override("font_color", TEXT)
	menu.add_theme_color_override("font_hover_color", LIME)
	for slot in Mission.SLOTS:
		selector.add_item(module_name(slot) + ("  •" if model.installed.has(slot) else ""))
	selector.selected = Mission.SLOTS.find(selected_slot)
	selector.item_selected.connect(func(index):
		selected_slot = Mission.SLOTS[index]
		show_locked_upgrades = false
		render()
	)
	parent.add_child(selector)
	var available_parts: Array = []
	var locked_parts: Array = []
	for p in model.catalog:
		if p.slot != selected_slot: continue
		if model.available(p): available_parts.append(p)
		else: locked_parts.append(p)
	for p in available_parts: build_part_card(parent, p)
	if available_parts.is_empty():
		var empty = panel(parent, CARD, 15)
		empty.add_child(label("No unlocked module", 18, TEXT, bold))
		empty.add_child(paragraph("Research this system to make a buildable component available.", 13))
	if not locked_parts.is_empty():
		var toggle = button("Hide locked upgrades  ↑" if show_locked_upgrades else "Show locked upgrades (%d)  ↓" % locked_parts.size(), func():
			show_locked_upgrades = not show_locked_upgrades
			render()
		)
		parent.add_child(toggle)
		if show_locked_upgrades:
			for p in locked_parts: build_part_card(parent, p)
	if model.installed.has(selected_slot):
		var remove = button("Remove " + module_name(selected_slot).to_lower(), func():
			model.installed.erase(selected_slot)
			changed("Module removed. Check the revised resource budgets.")
		)
		remove.disabled = model.integrated
		parent.add_child(remove)
	parent.add_child(button("Research lab  ↗", show_research))
	parent.add_child(button("Materials & recipes  ↗", show_inventory))
	parent.add_child(paragraph("Blueprint changes are free. Funds and materials are committed when you manufacture.", 12))

func build_part_card(parent: Node, p: Dictionary) -> void:
	var card = panel(parent, CARD, 15)
	var installed = model.installed.get(p.slot) == p.id
	var locked = not model.available(p)
	var default_choice = not locked and model.default_part(p.slot).get("id", "") == p.id
	var tags = row()
	card.add_child(tags)
	eyebrow(tags, "● INSTALLED" if installed else ("RESEARCH REQUIRED" if locked else ("DEFAULT / AVAILABLE" if default_choice else "AVAILABLE TO BUILD")))
	spacer(tags)
	tags.add_child(label("%d F" % p.cost, 12, ORANGE, mono))
	card.add_child(paragraph(p.name, 19, TEXT))
	card.add_child(paragraph(p.description, 13))
	separator(card)
	card.add_child(label("%.1f MASS    %.1f VOL    %d%% REL" % [p.mass, p.volume, p.reliability], 10, LIME, mono))
	var special: Array = []
	if p.has("dv"): special.append("+%d velocity" % p.dv)
	if p.has("generation"): special.append("%d power / %d storage" % [p.generation, p.storage])
	if p.has("support"): special.append("%d crew-days / 2 EVA suits" % p.support)
	if p.has("habitat"): special.append("2 crew / 72-hour shelter")
	if p.has("science"): special.append("+%d science yield" % p.science)
	if p.has("earth_min"): special.append("Needs %d%% Earth visibility" % p.earth_min)
	if p.has("terrain"): special.append("%d° landing tolerance" % p.terrain)
	if p.has("capacity"): special.append("%d lift capacity" % p.capacity)
	if p.has("seats"): special.append("2 seats / return heat shield")
	if p.has("repair"): special.append("3 repair charges / +1.5 reliability")
	card.add_child(paragraph(" · ".join(special), 12, MUTED))
	var b = button("Installed  ✓" if installed else ("Research to unlock  ↗" if locked else "Install module  +"), func():
		if locked:
			show_research()
		else:
			if model.equip(p.id): changed("Installed " + p.name + ".")
	, not installed and not locked)
	b.disabled = installed or model.integrated
	card.add_child(b)

func build_telemetry(parent: Node) -> void:
	var t = model.totals()
	var profile = Mission.ORBITS[model.orbit_profile]
	var performance = model.flight_performance()
	var budget = panel(parent)
	eyebrow(budget, "MISSION RESOURCES")
	var budget_row = row()
	budget.add_child(budget_row)
	budget_row.add_child(label("%d" % (1000-model.spent-(0 if model.integrated else t.cost)), 34, LIME, bold))
	var unit = label("FUNDS LEFT\nafter hardware", 10, MUTED, mono)
	unit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	budget_row.add_child(unit)
	budget.add_child(label("%d hardware  /  %d spent" % [t.cost, model.spent], 11, ORANGE, mono))
	separator(budget)
	metric(budget, "Launch mass", t.mass, maxf(0,t.capacity-profile.lift_margin), "u", t.mass+profile.lift_margin <= t.capacity and t.capacity > 0)
	budget.add_child(label("%.0f u lift margin required  /  %.0f u launcher capacity" % [profile.lift_margin,t.capacity],11,ORANGE,mono))
	budget.add_child(label("FLIGHT ΔV  %.0f / %.0f m/s" % [performance.dv,profile.min_dv],12,LIME if performance.dv>=profile.min_dv else RED,mono))
	budget.add_child(label("LIFTOFF TWR  %.2f / 1.45" % performance.twr,11,LIME if performance.twr>=1.45 else RED,mono))
	metric(budget, "Payload volume", t.volume, t.volume_cap, "u", t.volume <= t.volume_cap and t.volume_cap > 0)
	metric(budget, "Power demand", t.power, t.effective_power, "u", t.power <= t.effective_power and t.effective_power > 0)
	budget.add_child(label("EARTH LINK  %d%% visible / %d%% radio need" % [t.earth_visibility,t.earth_min],11,LIME if t.earth_visibility>=t.earth_min else RED,mono))
	metric(budget, "Shadow coverage", t.shadow_hours, Mission.SITES[model.site].shadow, "h", t.shadow_hours >= Mission.SITES[model.site].shadow, true)
	var rel = row()
	budget.add_child(rel)
	rel.add_child(label("System reliability", 13, MUTED))
	spacer(rel)
	rel.add_child(label("%.1f%%" % t.reliability, 14, LIME, mono))
	var time = row()
	budget.add_child(time)
	time.add_child(label("Launch window", 13, MUTED))
	spacer(time)
	time.add_child(label("DAY %02d / 24" % model.day, 12, ORANGE, mono))
	var reserve_card = panel(parent, PANEL, 14)
	var rr = row()
	reserve_card.add_child(rr)
	rr.add_child(label("Propellant reserve", 14, TEXT, bold))
	spacer(rr)
	rr.add_child(label("%02d u" % model.reserve, 13, ORANGE, mono))
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 12
	slider.step = 1
	slider.value = model.reserve
	slider.editable = not model.integrated
	slider.custom_minimum_size.y = 30
	slider.add_theme_stylebox_override("slider", slider_track(Color("1c1e25")))
	slider.add_theme_stylebox_override("grabber_area", slider_track(LIME))
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_track(Color("defb58")))
	slider.add_theme_icon_override("grabber", slider_thumb)
	slider.add_theme_icon_override("grabber_highlight", slider_thumb_hover)
	slider.add_theme_icon_override("grabber_disabled", slider_handle(BORDER))
	slider.tooltip_text = "Each reserve unit adds 1 mass, 5 funding cost and 50 velocity units. Minimum safe reserve: 4."
	reserve_card.add_child(slider)
	slider.drag_ended.connect(func(changed_value):
		if changed_value:
			model.reserve = int(slider.value)
			changed("Propellant allocation updated.")
	)
	# Keyboard changes commit on focus exit, avoiding a rebuild while an arrow is held.
	slider.focus_exited.connect(func():
		if not model.integrated and model.reserve != int(slider.value):
			model.reserve = int(slider.value)
			changed.call_deferred("Propellant allocation updated.")
	)
	reserve_card.add_child(label("Minimum 4 u  ·  more fuel adds mass", 11, MUTED))
	var review = panel(parent, PANEL, 14)
	var checks = model.checks()
	var passed = 0
	for check in checks:
		if check.passed: passed += 1
	eyebrow(review, "DESIGN REVIEW  /  %02d OF 13 PASS" % passed)
	var shown = 0
	for check in checks:
		if check.passed: continue
		review.add_child(paragraph("!  " + check.title, 13, RED))
		shown += 1
		if shown == 3: break
	if passed == 13: review.add_child(paragraph("✓  All design constraints satisfied", 13, LIME))
	elif 13-passed > 3: review.add_child(label("+ %d more items to resolve" % (13-passed-3), 12, MUTED))
	review.add_child(button("Full engineering review  ↗", show_review))

func metric(parent: Node, title: String, value: float, maximum: float, unit: String, good: bool, inverse: bool = false) -> void:
	var r = row()
	parent.add_child(r)
	r.add_child(label(title, 13, MUTED))
	spacer(r)
	r.add_child(label("%.1f / %.1f %s" % [value, maximum, unit], 11, LIME if good else RED, mono))
	var bar = ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.show_percentage = false
	bar.max_value = maxf(0.1, maximum)
	bar.value = value
	bar.add_theme_stylebox_override("background", style(Color("4b4f59"), Color("4b4f59"), 2, 0))
	bar.add_theme_stylebox_override("fill", style(LIME if good else RED, LIME if good else RED, 2, 0))
	parent.add_child(bar)

func build_brief(parent: Node) -> void:
	var brief = panel(parent)
	eyebrow(brief, "MISSION 001 / CREWED DEMONSTRATION")
	brief.add_child(label("A foothold\non the Moon.", 28, TEXT, bold))
	brief.add_child(paragraph("Deliver two astronauts and a compact habitat to the lunar south pole. Equip a 72-hour stay and three science objectives, then preserve a safe return.", 14))
	separator(brief)
	brief.add_child(label("1,000 FUNDS  /  24-DAY WINDOW", 11, ORANGE, mono))
	brief.add_child(paragraph("This chapter ends with a manufactured, tested spacecraft and a launch-ready mission manifest.", 12))
	eyebrow(parent, "SELECT LUNAR ORBIT")
	for i in range(Mission.ORBITS.size()):
		var orbit = Mission.ORBITS[i]
		var orbit_card = panel(parent,CARD,13)
		eyebrow(orbit_card,orbit.tag)
		orbit_card.add_child(label(orbit.name,17,TEXT,bold))
		orbit_card.add_child(paragraph(orbit.detail,12))
		orbit_card.add_child(label("LIFT +%.0f u   •   ΔV %.0f m/s\nPOWER +%.1f u   •   LINK %+d%%" % [orbit.lift_margin,orbit.min_dv,orbit.extra_power,orbit.comms_adjust],10,LIME,mono))
		var choose = button("Selected  ✓" if model.orbit_profile==i else "Choose orbit",func():
			model.orbit_profile=i
			changed("Orbit changed. Recheck lift, power, communications and flight energy.")
		,false,model.orbit_profile==i)
		choose.disabled=model.integrated
		orbit_card.add_child(choose)
	eyebrow(parent, "SELECT LANDING REGION")
	for i in range(Mission.SITES.size()):
		var s = Mission.SITES[i]
		var site_card = panel(parent, CARD, 13)
		eyebrow(site_card, s.tag)
		site_card.add_child(label(s.name, 18, TEXT, bold))
		site_card.add_child(label("SUN %d%%   EARTH %d%%   %d° SLOPE" % [s.sun*100, s.earth, s.slope], 10, LIME, mono))
		site_card.add_child(paragraph(s.description, 12))
		var b = button("Selected  ✓" if model.site == i else "Choose region", func():
			model.site = i
			changed("Landing region changed. Recheck power, landing and communications.")
		, false, model.site == i)
		b.disabled = model.integrated
		site_card.add_child(b)
	parent.add_child(paragraph("Site modifiers and engineering units are illustrative game values, not NASA mission requirements.", 11))

func build_crew(parent: Node) -> void:
	eyebrow(parent, "ASTRONAUT COMPLEX")
	parent.add_child(label("Your flight crew", 23, TEXT, bold))
	parent.add_child(paragraph("Assign two specialists. Select an assigned astronaut to free a seat.", 13))
	for i in range(Mission.CREW.size()):
		var astronaut = Mission.CREW[i]
		var card = panel(parent, CARD, 13)
		var r = row()
		card.add_child(r)
		r.add_child(label(astronaut.initials, 24, LIME, mono))
		var names = column(0)
		r.add_child(names)
		names.add_child(label(astronaut.name, 16, TEXT, bold))
		names.add_child(label(astronaut.role, 12, MUTED))
		card.add_child(paragraph(astronaut.detail, 12))
		var b = button("Assigned  ✓" if i in model.crew else "Assign to mission", func():
			if i in model.crew: model.crew.erase(i)
			elif model.crew.size() < 2: model.crew.append(i)
			else:
				notify("Both seats are assigned. Unassign one astronaut first.")
				return
			changed("Crew roster updated.")
		, false, i in model.crew)
		b.disabled = model.integrated
		card.add_child(b)
	parent.add_child(button("Research lab  ↗", show_research))

func build_tests(parent: Node) -> void:
	eyebrow(parent, "INTEGRATION & QUALIFICATION")
	parent.add_child(label("Ready is earned.", 25, TEXT, bold))
	parent.add_child(paragraph("Manufacture your approved design, then qualify three systems. Tests cost 12 funds and one day each and improve reliability.", 14))
	var cards = [
		["structure", "01", "Structural loads", "Mass distribution, launch envelope, module interfaces and load margins."],
		["propulsion", "02", "Propulsion & guidance", "Velocity budget, reserve propellant, landing tolerance and return capability."],
		["systems", "03", "Crew & surface systems", "Power balance, shadow endurance, Earth link, provisions and science payload."]
	]
	for entry in cards:
		var c = panel(parent, CARD, 15)
		eyebrow(c, "TEST " + entry[1] + "  /  " + ("PASS" if entry[0] in model.tests else "PENDING"))
		c.add_child(label(entry[2], 18, TEXT, bold))
		c.add_child(paragraph(entry[3], 13))
		var b = button("Passed  ✓" if entry[0] in model.tests else "Run test  ·  12 F / 1 day", func(): run_qualification(entry[0]), entry[0] not in model.tests)
		b.disabled = not model.integrated or entry[0] in model.tests or test_busy or model.delivered
		c.add_child(b)
	if model.integrated and (not model.delivered or not model.valid_design()):
		var edit = button("Return to design", confirm_disassemble)
		edit.disabled = test_busy
		parent.add_child(edit)
	parent.add_child(button("Mission event log  ↗", show_log))
	if model.delivered and model.valid_design():
		parent.add_child(button("View completion report  ↗", show_completion, true))

func build_footer() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	ui.add_child(margin)
	var footer = row(18)
	margin.add_child(footer)
	var status = column(4)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(status)
	eyebrow(status, "CHAPTER 01 / DESIGN & BUILD    •    " + save_notice)
	status_label = paragraph(status_text, 13, TEXT)
	status.add_child(status_label)
	var cta_text = "Manufacture vehicle  →"
	var action = manufacture_vehicle
	if page == 0:
		cta_text = "Enter assembly bay  →"
		action = func():
			page = 1
			render()
	elif model.delivered and not model.valid_design():
		cta_text = "Launch blocked  →"
		action = show_review
	elif model.delivered:
		cta_text = "Enter flight deck  →"
		action = start_flight
	elif model.is_ready():
		cta_text = "Authorize for launch  →"
		action = authorize
	elif model.integrated:
		cta_text = "Continue qualification  →"
		action = func():
			page = 2
			render()
	var cta = button(cta_text, action, true)
	cta.custom_minimum_size = Vector2(272, 52)
	cta.disabled = test_busy
	footer.add_child(cta)

func changed(message: String) -> void:
	status_text = message
	persist()
	world.model = model
	world.rebuild()
	render()

func persist() -> void:
	save_notice = "SAVED LOCALLY" if model.save_to(save_path) == OK else "SAVE FAILED"

func notify(message: String) -> void:
	status_text = message
	if is_instance_valid(status_label): status_label.text = message

func manufacture_vehicle() -> void:
	if not model.valid_design():
		notify("Resolve the highlighted design constraints before manufacturing.")
		show_review()
		return
	var t = model.totals()
	confirm("Manufacture Dawn Explorer?", "Commit %d funds, consume recipe materials and advance %d days. Qualification needs another 36 funds and 3 days.\n\nYou can recover hardware and materials by returning to design; elapsed time and test costs are not refunded." % [t.cost, t.days], func():
		if model.manufacture():
			page = 2
			changed("Integration complete. Run all three qualification tests.")
		else: notify("Manufacturing could not proceed. Review the current design.")
	)

func run_qualification(id: String) -> void:
	if test_busy: return
	test_busy = true
	status_text = "Running " + id + " qualification … checking every interface."
	render()
	await get_tree().create_timer(1.2).timeout
	var passed = model.run_test(id)
	test_busy = false
	changed("PASS / " + id.capitalize() + " qualification complete. +1 reliability." if passed else "Test blocked. Check funding, schedule and design constraints.")

func authorize() -> void:
	if model.deliver():
		changed("Chapter complete. Dawn Explorer is cleared for the next mission phase.")
		show_completion()

func confirm_disassemble() -> void:
	confirm("Return to design?", "Recover hardware funding and recipe materials. All test certificates are invalidated. Elapsed days and test costs remain spent, so a second build may miss the launch window.", func():
		model.return_to_design()
		page = 1
		changed("Returned to design. Check the schedule before rebuilding.")
	)

func confirm_reset() -> void:
	if test_busy: return
	confirm("Start a new campaign?", "This replaces your saved design, research and qualification progress. You will begin with 1,000 funds and the three core spacecraft modules.", func():
		model = Mission.new()
		page = 0
		selected_slot = "Lunar lander"
		show_locked_upgrades = false
		changed("New mission authorized. Choose a landing region and crew.")
	)

func confirm(title: String, body: String, action: Callable) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = body
	dialog.min_size = Vector2i(520, 200)
	dialog.ok_button_text = "Confirm"
	dialog.confirmed.connect(func():
		action.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func modal(title: String, subtitle: String) -> VBoxContainer:
	close_modal()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade = ColorRect.new()
	shade.color = Color(0.10, 0.11, 0.13, 0.90)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(790, 690)
	p.add_theme_stylebox_override("panel", style(PANEL, BORDER, 12, 26))
	center.add_child(p)
	var content = column(14)
	p.add_child(content)
	var h = row()
	content.add_child(h)
	h.add_child(label(title, 26, TEXT, bold))
	spacer(h)
	h.add_child(button("Close  ×", close_modal))
	content.add_child(paragraph(subtitle, 14))
	separator(content)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(738, 520)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var body = column(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body

func close_modal() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay = null

func show_review() -> void:
	var body = modal("Engineering review", "Every constraint must pass before integration. Resolve an issue by changing hardware, crew, landing site or reserve fuel.")
	for check in model.checks():
		var c = panel(body, CARD, 12)
		c.add_child(label(("PASS  /  " if check.passed else "CHECK  /  ") + check.title, 16, LIME if check.passed else RED, bold))
		c.add_child(paragraph(check.detail, 13))
	body.add_child(paragraph("Flight Δv and liftoff thrust-to-weight use the selected engines' fixed tank and thrust ratings against your actual mass. Launch requires room below the lift limit for the selected orbit. Crew provisions cover the 72-hour surface stay; transit supplies are bundled with the capsule and service module.", 12))

func show_research() -> void:
	var body = modal("Research & development", "Foundation and basic lunar systems are available. Optional upgrades open new architectures at a funding and schedule cost.")
	var header = panel(body, CARD)
	header.add_child(label("FOUNDATION → ORBIT → LUNAR FLIGHT → SURFACE", 14, LIME, mono))
	header.add_child(paragraph("The Lunar Dawn contract includes core technologies. Research below develops the optional specialist branches.", 13))
	for r in Mission.RESEARCH:
		var card = panel(body, CARD, 16)
		card.add_child(label(r.name, 19, TEXT, bold))
		card.add_child(paragraph(r.detail, 14))
		var b = button("Researched  ✓" if r.id in model.unlocked else "Research  ·  %d funds / %d days" % [r.cost, r.days], func():
			if model.research(r.id):
				changed("Research complete: " + r.name + ".")
				show_research()
			else: notify("Research blocked by funds, schedule or vehicle integration.")
		)
		b.disabled = r.id in model.unlocked or model.integrated or model.spent + r.cost > 1000 or model.day + r.days > 24
		card.add_child(b)
	body.add_child(paragraph("Research is committed immediately. The engineering review reserves funding and days for hardware and tests, so check the totals after each unlock.", 13, ORANGE))

func show_inventory() -> void:
	var body = modal("Manufacturing inventory", "Processed materials are supplied by the mission contract. Parts are manufactured in parallel, followed by two days of integration.")
	var t = model.totals()
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	for title in ["MATERIAL", "BLUEPRINT NEED", "AVAILABLE"]: grid.add_child(label(title, 12, MUTED, mono))
	for material in Mission.MATERIALS:
		grid.add_child(label(material, 16))
		grid.add_child(label(str(t.materials.get(material, 0)), 16, ORANGE, mono))
		grid.add_child(label(str(model.stock[material]), 16, LIME, mono))
	separator(body)
	for id in model.installed.values():
		var p = model.get_part(id)
		var ingredients: Array = []
		for key in p.recipe: ingredients.append("%s ×%d" % [key, p.recipe[key]])
		var card = panel(body, CARD, 12)
		card.add_child(label(p.name, 16, TEXT, bold))
		card.add_child(paragraph("  ·  ".join(ingredients), 13))
		card.add_child(label("%d funds  /  %d build days" % [p.cost, p.days], 12, ORANGE, mono))
	body.add_child(paragraph("Propellant and crew consumables are included in funding and module mass. Optional parts can be removed before manufacturing to recover blueprint capacity.", 12))

func show_log() -> void:
	var body = modal("Mission event log", "Design, research, manufacturing and qualification history for this campaign.")
	for i in range(model.log_entries.size()-1, -1, -1):
		var c = panel(body, CARD, 14)
		c.add_child(paragraph("%02d  /  %s" % [i+1, model.log_entries[i]], 15, TEXT))

func show_help() -> void:
	var body = modal("Your first lunar spacecraft", "Design a complete mission, then prove the vehicle is ready. Your progress saves automatically after each decision.")
	var steps = [
		["01 / PLAN", "Choose a landing region and two specialists in Mission planning. Mons Mouton with a commander and engineer is a forgiving first mission."],
		["02 / ASSEMBLE", "Select a system from the component dropdown or the manifest above the spacecraft. Compare modules and press Install. Wireframe sections show missing hardware."],
		["03 / BALANCE", "Orbit and landing site change lift margin, flight energy, power and communications. Added instruments can exceed the safe launch envelope. Compare the live numbers with your budget before manufacturing."],
		["04 / BUILD", "Open Engineering review and resolve every failed constraint. Manufacture commits funds and ingredients and advances the schedule."],
		["05 / QUALIFY", "Run all three qualification tests, then authorize the spacecraft. Enter the flight deck to launch your spacecraft."],
		["CONTROLS", "Drag the spacecraft to orbit. Scroll to zoom. Click a module to inspect it. Use Exploded view to separate the stack. Escape closes an overlay. Ctrl/Cmd+S saves."],
		["NEED A STARTING POINT?", "Load reference design creates a complete, affordable configuration. You can keep experimenting with modules, crew and fuel before manufacturing."],
		["SIMULATION SCOPE", "Design, build, launch and fly to the Moon. The flight deck includes a scaled orbital simulation and lunar descent. Surface operations and return are future chapters. Values are game balance."]
	]
	for step in steps:
		var c = panel(body, CARD, 14)
		c.add_child(label(step[0], 13, LIME, mono))
		c.add_child(paragraph(step[1], 15, TEXT))

func show_completion() -> void:
	var t = model.totals()
	var body = modal("Dawn Explorer is flight ready.", "CHAPTER 01 COMPLETE  /  You turned a lunar objective into a manufactured and qualified spacecraft.")
	var report = panel(body, CARD, 20)
	report.add_child(label("GO FOR LUNAR DAWN", 28, LIME, bold))
	report.add_child(paragraph("Destination: " + Mission.SITES[model.site].name + "  ·  " + Mission.ORBITS[model.orbit_profile].name + "  ·  2 crew", 16, TEXT))
	for i in model.crew: report.add_child(label(Mission.CREW[i].name + " / " + Mission.CREW[i].role, 15, MUTED))
	separator(report)
	report.add_child(label("%.1f MASS     %.1f%% RELIABILITY" % [t.mass, t.reliability], 16, LIME, mono))
	report.add_child(label("%d FUNDS REMAINING     DAY %d / 24" % [1000-model.spent, model.day], 16, ORANGE, mono))
	report.add_child(label("3 / 3 QUALIFICATION TESTS PASSED", 14, LIME, mono))
	body.add_child(paragraph("The vehicle and campaign are saved. Your selected hardware, propellant budgets and crew are ready for launch.", 16, TEXT))
	body.add_child(button("Enter flight deck  →", start_flight, true))
	body.add_child(button("Export mission manifest  ↗", func(): export_dialog.popup_centered_ratio(0.65)))
	body.add_child(paragraph("Chapter 02: launch, Earth orbit, lunar transfer and touchdown. Pilot the craft with manual throttle, staging and attitude controls.", 14))

func start_flight() -> void:
	if not model.delivered or is_instance_valid(flight_screen): return
	if not model.valid_design():
		show_review()
		return
	close_modal()
	ui.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	flight_screen = load("res://scripts/flight_ui.gd").new()
	flight_screen.host = self
	add_child(flight_screen)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(flight_screen): return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE: close_modal()
		if event.keycode == KEY_S and (event.ctrl_pressed or event.meta_pressed):
			persist()
			notify("Campaign saved." if save_notice == "SAVED LOCALLY" else "Save failed.")
