extends RefCounted
const Flight = preload("res://scripts/flight_sim.gd")
## Campaign model. All numbers are deliberately abstract game-balance values.
const SAVE_PATH = "user://lunar_dawn.json"
const SLOTS = ["Launch vehicle", "Crew capsule", "Service module", "Lunar lander", "Habitat", "Surface power", "Communications", "Science", "Life support", "Rover", "Repair kit"]
const MATERIALS = ["Metal", "Alloy", "Polymer", "Electronics", "Cells", "Solar", "Optics"]
const STOCK = {"Metal": 48, "Alloy": 25, "Polymer": 35, "Electronics": 40, "Cells": 16, "Solar": 15, "Optics": 10}
const SITES = [
	{"name": "Mons Mouton", "map_angle": 2.35, "landing_speed": 7.0, "tag": "BALANCED", "sun": 0.85, "shadow": 3.0, "earth": 80, "slope": 3, "science": 1.0, "description": "An elevated plateau with generous sunlight. A forgiving site for your first lunar outpost."},
	{"name": "Shackleton rim", "map_angle": 2.95, "landing_speed": 5.0, "tag": "POWER CHALLENGE", "sun": 0.68, "shadow": 7.0, "earth": 55, "slope": 5, "science": 1.3, "description": "Crater-edge samples are valuable, but long shadows demand stored energy and precise landing guidance."},
	{"name": "de Gerlache rim", "map_angle": 3.55, "landing_speed": 3.5, "tag": "COMMS CHALLENGE", "sun": 0.76, "shadow": 5.0, "earth": 35, "slope": 7, "science": 1.6, "description": "Rich science near shadowed terrain. Buffered communications and advanced landing guidance are essential."}
]
const ORBITS = [
	{"name": "Low approach orbit", "tag": "DESCENT FIRST", "detail": "Shortest descent and least propellant demand. Low passes make surface communications less forgiving.", "capture_altitude": 20000.0, "lift_margin": 8.0, "min_dv": 8600.0, "power_factor": 1.0, "extra_power": 0.0, "comms_adjust": 0, "science_bonus": 0.0, "science_min": 3.0},
	{"name": "High relay orbit", "tag": "LINK FIRST", "detail": "Better Earth visibility can save a radio upgrade. A higher descent and longer operations require more velocity and power.", "capture_altitude": 50000.0, "lift_margin": 10.0, "min_dv": 9000.0, "power_factor": 1.0, "extra_power": 1.0, "comms_adjust": 20, "science_bonus": 0.0, "science_min": 3.0},
	{"name": "Survey orbit", "tag": "SCIENCE FIRST", "detail": "Extended mapping rewards stronger instruments, but data handling and link gaps strain power and communications.", "capture_altitude": 35000.0, "lift_margin": 10.0, "min_dv": 8750.0, "power_factor": 1.0, "extra_power": 0.5, "comms_adjust": -15, "science_bonus": 1.0, "science_min": 4.5}
]
const CREW = [
	{"name": "Maya Chen", "role": "Commander", "initials": "MC", "detail": "Flight specialist · +2° landing tolerance", "bonus": "pilot"},
	{"name": "Idris Rahman", "role": "Systems engineer", "initials": "IR", "detail": "Integration specialist · +3 reliability", "bonus": "engineer"},
	{"name": "Elena Silva", "role": "Geologist", "initials": "ES", "detail": "Sample specialist · +30% science yield", "bonus": "science"},
	{"name": "Noah Okafor", "role": "Medical officer", "initials": "NO", "detail": "Crew health · +2 crew-days of support", "bonus": "medic"},
	{"name": "Yuki Tanaka", "role": "Robotics specialist", "initials": "YT", "detail": "Rover specialist · +2 science with rover", "bonus": "robotics"}
]
const RESEARCH = [
	{"id": "structures", "name": "Lightweight structures", "cost": 40, "days": 2, "detail": "Unlocks composite capsule and folding habitat."},
	{"id": "navigation", "name": "Precision navigation", "cost": 40, "days": 3, "detail": "Unlocks terrain-aware lander and buffered comms."},
	{"id": "energy", "name": "Polar energy storage", "cost": 40, "days": 2, "detail": "Unlocks extended batteries and closed-loop support."},
	{"id": "robotics", "name": "Surface robotics", "cost": 30, "days": 2, "detail": "Unlocks rover and advanced science payload."}
]
var catalog: Array = []
var installed: Dictionary = {}
var crew: Array = [0, 1]
var site: int = 0
var orbit_profile: int = 0
var reserve: int = 4
var unlocked: Array = []
var spent: int = 0
var day: int = 1
var integrated: bool = false
var tests: Array = []
var delivered: bool = false
var stock: Dictionary = STOCK.duplicate()
var paid_build: int = 0
var used_materials: Dictionary = {}
var log_entries: Array = ["Lunar Dawn approved. Design authorization received."]

func _init() -> void:
	# id, slot, name, cost, mass, volume, power demand, reliability, build days, recipe, extra stats
	part("atlas", 0, "Atlas / medium lift", 160, 21, 0, 0, 96, 10, {"Metal": 10, "Alloy": 4, "Electronics": 2}, {"capacity": 80, "dv": 3200}, "A proven two-stage launcher. Balanced capacity and cost.")
	part("titan", 0, "Titan / heavy lift", 220, 25, 0, 0, 97, 12, {"Metal": 14, "Alloy": 6, "Electronics": 3}, {"capacity": 100, "dv": 3400}, "Extra lift for ambitious payloads; more funding and build time.")
	part("aurora", 1, "Aurora / command module", 110, 7, 2, 1, 97, 8, {"Metal": 5, "Alloy": 2, "Polymer": 3, "Electronics": 2}, {"seats": 2}, "Conical crew cabin with flight avionics and a blunt ablative return shield.")
	part("aurora_c", 1, "Aurora C / command module", 140, 4, 2, 1, 97, 9, {"Alloy": 4, "Polymer": 5, "Electronics": 2}, {"seats": 2, "tech": "structures"}, "A composite command shell saves three mass units.")
	part("vector", 2, "Vector / service module", 100, 10, 3, 0, 95, 8, {"Metal": 4, "Alloy": 3, "Electronics": 2}, {"dv": 1900, "volume_cap": 32}, "Cylindrical propulsion bus with radiator bays, thermal control and a standard cargo envelope.")
	part("vector_x", 2, "Vector X / long range", 140, 13, 3, 0, 96, 10, {"Metal": 5, "Alloy": 5, "Electronics": 3}, {"dv": 2350, "volume_cap": 40}, "A larger tank and cargo envelope; heavier but more flexible.")
	part("heron", 3, "Heron / lunar module", 135, 10, 7, 1, 94, 11, {"Metal": 6, "Alloy": 4, "Electronics": 3}, {"dv": 3500, "terrain": 4}, "Faceted descent stage, separate ascent cabin and four landing feet with conventional radar.")
	part("heron_p", 3, "Heron P / lunar module", 155, 10, 7, 1, 97, 12, {"Metal": 6, "Alloy": 4, "Electronics": 5}, {"dv": 3650, "terrain": 8, "tech": "navigation"}, "Terrain-relative navigation opens rougher, high-value sites.")
	part("haven", 4, "Haven / habitat kit", 95, 6, 6, 2, 95, 8, {"Metal": 6, "Polymer": 6, "Electronics": 3}, {"habitat": 6}, "A compact shelter for two people over a 72-hour surface stay.")
	part("haven_f", 4, "Haven F / folding", 115, 4, 4, 2, 93, 9, {"Alloy": 2, "Polymer": 8, "Electronics": 3}, {"habitat": 6, "tech": "structures"}, "Packs smaller and lighter, with a modest reliability trade-off.")
	part("sol", 5, "Sol / array + battery", 65, 3, 2, 0, 96, 5, {"Solar": 6, "Cells": 4, "Electronics": 2}, {"generation": 10, "storage": 36}, "Sun-tracking arrays with enough storage for short shadows.")
	part("sol_x", 5, "Sol X / polar reserve", 85, 5, 3, 0, 97, 7, {"Solar": 8, "Cells": 8, "Electronics": 3}, {"generation": 14, "storage": 80, "tech": "energy"}, "More array area and batteries for long polar shadow periods.")
	part("echo", 6, "Echo / direct-to-Earth", 40, 1, 1, 1, 95, 4, {"Metal": 2, "Electronics": 3, "Polymer": 1}, {"earth_min": 50}, "A light deployable mast. Needs clear Earth visibility.")
	part("echo_b", 6, "Echo B / buffered link", 55, 2, 2, 1.5, 98, 6, {"Metal": 2, "Electronics": 5, "Cells": 1}, {"earth_min": 25, "tech": "navigation"}, "Redundant radio and data storage bridge local blackouts.")
	part("prospect", 7, "Prospect / field lab", 45, 2, 2, 1, 95, 5, {"Optics": 3, "Electronics": 2, "Metal": 1}, {"science": 3}, "Camera, sample tools and spectrometer cover all three objectives.")
	part("prospect_x", 7, "Prospect X / drill lab", 80, 4, 3, 2, 94, 7, {"Optics": 5, "Electronics": 4, "Alloy": 2}, {"science": 5, "tech": "robotics"}, "Subsurface sampling increases science at a power and mass cost.")
	part("vital", 8, "Vital / crew provisions", 50, 4, 2, 1, 96, 4, {"Metal": 2, "Polymer": 5, "Electronics": 2}, {"support": 6, "suits": 2}, "Oxygen, water, food, filters and two EVA suits for the surface stay.")
	part("vital_r", 8, "Vital R / regenerative", 75, 3, 2, 1.5, 97, 6, {"Alloy": 2, "Polymer": 4, "Electronics": 4}, {"support": 10, "suits": 2, "tech": "energy"}, "More endurance from closed-loop support; needs more power.")
	part("nomad", 9, "Nomad / exploration rover", 50, 5, 4, 1.5, 93, 6, {"Metal": 4, "Cells": 3, "Electronics": 3}, {"science": 2, "tech": "robotics"}, "Optional mobility for farther samples and higher science yield.")
	part("spares", 10, "Patch / repair supplies", 30, 2, 1, 0, 99, 2, {"Metal": 2, "Polymer": 2, "Electronics": 1}, {"repair": 3}, "Optional spare filters, tools and electronics add reliability.")
	for id in ["atlas", "aurora", "vector"]:
		installed[get_part(id).slot] = id

func part(id: String, slot_index: int, title: String, cost: int, mass: float, volume: float, power: float, reliability: int, days: int, recipe: Dictionary, extra: Dictionary, description: String) -> void:
	var p = {"id": id, "slot": SLOTS[slot_index], "name": title, "cost": cost, "mass": mass, "volume": volume, "power": power, "reliability": reliability, "days": days, "recipe": recipe, "description": description}
	p.merge(extra)
	catalog.append(p)

func get_part(id: String) -> Dictionary:
	for p in catalog:
		if p.id == id: return p
	return {}

func has_role(role: String) -> bool:
	for index in crew:
		if CREW[index].bonus == role: return true
	return false

func available(p: Dictionary) -> bool:
	return not p.has("tech") or p.tech in unlocked

func default_part(slot: String) -> Dictionary:
	if installed.has(slot):
		var current = get_part(installed[slot])
		if not current.is_empty() and available(current): return current
	for p in catalog:
		if p.slot == slot and available(p): return p
	return {}

func equip(id: String) -> bool:
	var p = get_part(id)
	if integrated or p.is_empty() or not available(p): return false
	installed[p.slot] = id
	return true

func reference_design() -> void:
	if integrated: return
	installed.clear()
	for id in ["atlas", "aurora", "vector", "heron", "haven", "sol", "echo", "prospect", "vital"]:
		equip(id)
	crew = [0, 1]
	site = 0
	orbit_profile = 0
	reserve = 4

func totals() -> Dictionary:
	var t = {"cost": reserve * 5, "mass": float(reserve), "volume": 0.0, "power": 0.0, "reliability": 0.0, "days": 0, "capacity": 0, "dv": reserve * 50, "volume_cap": 0, "seats": 0, "terrain": 0, "habitat": 0, "generation": 0.0, "storage": 0.0, "science": 0.0, "support": 0, "suits": 0, "repair": 0, "earth_min": 100, "materials": {}}
	for id in installed.values():
		var p = get_part(id)
		for key in ["cost", "mass", "volume", "power", "reliability", "capacity", "dv", "volume_cap", "seats", "terrain", "habitat", "generation", "storage", "science", "support", "suits", "repair"]:
			t[key] += p.get(key, 0)
		t.days = maxi(t.days, p.days)
		if p.has("earth_min"): t.earth_min = p.earth_min
		for material in p.recipe:
			t.materials[material] = t.materials.get(material, 0) + p.recipe[material]
	if installed.size() > 0: t.reliability /= installed.size()
	if has_role("pilot"): t.terrain += 2
	if has_role("engineer"): t.reliability += 3
	if has_role("medic"): t.support += 2
	if has_role("robotics") and installed.has("Rover"): t.science += 2
	if has_role("science"): t.science *= 1.3
	t.science *= SITES[site].science
	var orbit = ORBITS[orbit_profile]
	t.science += orbit.science_bonus
	t.power += orbit.extra_power
	t.earth_visibility = clampi(SITES[site].earth + orbit.comms_adjust, 0, 100)
	t.reliability = minf(99, t.reliability + t.repair * 0.5 + tests.size())
	t.effective_power = t.generation * SITES[site].sun * orbit.power_factor
	t.shadow_hours = t.storage / maxf(0.1, t.power)
	t.days += 2
	return t

func flight_performance() -> Dictionary:
	for slot in ["Launch vehicle", "Service module", "Lunar lander"]:
		if not installed.has(slot): return {"dv": 0.0, "twr": 0.0}
	var sim = Flight.new()
	sim.configure(self, false)
	return {"dv": sim.remaining_dv(), "twr": sim.thrust[0] / (sim.mass() * Flight.EARTH_MU / pow(Flight.EARTH_R, 2))}

func checks() -> Array:
	var t = totals()
	var profile = ORBITS[orbit_profile]
	var performance = flight_performance()
	var missing: Array = []
	for slot in SLOTS.slice(0, 9):
		if not installed.has(slot): missing.append(slot)
	var material_ok = true
	for key in t.materials:
		if t.materials[key] > stock[key] + used_materials.get(key, 0): material_ok = false
	var committed = 0 if integrated else t.cost
	return [
		check("modules", "Required systems", missing.is_empty(), "All nine essential systems installed." if missing.is_empty() else "Missing: " + ", ".join(missing)),
		check("crew", "Crew & return capsule", crew.size() == 2 and t.seats >= 2, "%d / 2 astronauts assigned; %d capsule seats." % [crew.size(), t.seats]),
		check("mass", "Launch lift margin", t.capacity > 0 and t.mass + profile.lift_margin <= t.capacity, "%.1f mass + %.0f required lift margin / %d capacity. Reduce payload or upgrade the launcher." % [t.mass, profile.lift_margin, t.capacity]),
		check("volume", "Payload envelope", t.volume_cap > 0 and t.volume <= t.volume_cap, "%.1f / %d volume units in the service envelope." % [t.volume, t.volume_cap]),
		check("power", "Surface power", t.effective_power >= t.power and t.generation > 0, "%.1f generated / %.1f demand at this site's sunlight level." % [t.effective_power, t.power]),
		check("battery", "Shadow survival", t.shadow_hours >= SITES[site].shadow and t.storage > 0, "%.1f hours stored / %.1f hours required. Upgrade batteries if short." % [t.shadow_hours, SITES[site].shadow]),
		check("comms", "Earth communications", t.earth_min <= t.earth_visibility, "%d%% Earth visibility in %s; radio requires %d%%." % [t.earth_visibility, profile.name, t.earth_min]),
		check("landing", "Flight energy & landing", performance.dv >= profile.min_dv and performance.twr >= 1.45 and t.terrain >= SITES[site].slope and reserve >= 4, "%.0f / %.0f m/s available; %.2f / 1.45 launch thrust-to-weight; %d° terrain tolerance; %d / 4 reserve." % [performance.dv, profile.min_dv, performance.twr, t.terrain, reserve]),
		check("support", "Habitat, provisions & EVA", t.habitat >= 6 and t.support >= 6 and t.suits >= 2, "%d shelter crew-days; %d provision crew-days; %d EVA suits." % [t.habitat, t.support, t.suits]),
		check("science", "Science objectives", t.science >= profile.science_min, "%.1f / %.1f science yield for %s." % [t.science, profile.science_min, profile.name]),
		check("budget", "Funding & test reserve", spent + committed + (3 - tests.size()) * 12 <= 1000, "%d / 1000 funds committed, including remaining qualification tests." % (spent + committed + (3 - tests.size()) * 12)),
		check("schedule", "Launch window", day + (0 if integrated else t.days) + (3 - tests.size()) <= 24, "Day %d / 24 after build and remaining tests." % (day + (0 if integrated else t.days) + (3 - tests.size()))),
		check("materials", "Manufacturing inventory", material_ok, "Recipes checked against available processed materials.")
	]

func check(id: String, title: String, passed: bool, detail: String) -> Dictionary:
	return {"id": id, "title": title, "passed": passed, "detail": detail}

func valid_design() -> bool:
	for c in checks():
		if not c.passed: return false
	return true

func research(id: String) -> bool:
	if integrated or id in unlocked: return false
	for r in RESEARCH:
		if r.id == id and spent + r.cost <= 1000 and day + r.days <= 24:
			unlocked.append(id)
			spent += r.cost
			day += r.days
			log_entries.append("Research complete: " + r.name)
			return true
	return false

func manufacture() -> bool:
	if integrated or not valid_design(): return false
	var t = totals()
	paid_build = t.cost
	spent += paid_build
	day += t.days
	used_materials = t.materials.duplicate()
	for key in used_materials: stock[key] -= used_materials[key]
	integrated = true
	log_entries.append("Vehicle integrated. %d funds committed; qualification pending." % paid_build)
	return true

func return_to_design() -> void:
	if not integrated or (delivered and valid_design()): return
	delivered = false
	spent -= paid_build
	paid_build = 0
	for key in used_materials: stock[key] += used_materials[key]
	used_materials.clear()
	integrated = false
	tests.clear()
	log_entries.append("Vehicle disassembled. Hardware funds and materials recovered; elapsed days and test costs retained.")

func run_test(id: String) -> bool:
	if not integrated or id in tests or id not in ["structure", "propulsion", "systems"] or spent + 12 > 1000 or day + 1 > 24: return false
	if not valid_design(): return false
	spent += 12
	day += 1
	tests.append(id)
	log_entries.append("PASS / " + id.capitalize() + " qualification. +1 reliability.")
	return true

func is_ready() -> bool:
	return integrated and tests.size() == 3 and valid_design()

func deliver() -> bool:
	if not is_ready() or delivered: return false
	delivered = true
	log_entries.append("Lunar Dawn cleared for launch. Design phase complete.")
	return true

func save_to(path: String = SAVE_PATH) -> Error:
	var f = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": 1, "installed": installed, "crew": crew, "site": site, "orbit_profile": orbit_profile, "reserve": reserve, "unlocked": unlocked, "spent": spent, "day": day, "integrated": integrated, "tests": tests, "delivered": delivered, "stock": stock, "paid_build": paid_build, "used_materials": used_materials, "log_entries": log_entries}, "\t"))
	f.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_from(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1: return false
	# Validate into a temporary model so malformed saves cannot partially mutate play.
	var clean_installed: Dictionary = {}
	if not data.get("installed") is Dictionary or not data.get("crew") is Array: return false
	for slot in data.installed:
		if not data.installed[slot] is String: return false
		var p = get_part(data.installed[slot])
		if p.is_empty() or p.slot != slot: return false
		clean_installed[slot] = p.id
	var clean_crew: Array = []
	for i in data.crew:
		if not (i is float or i is int) or i != int(i) or i < 0 or i >= CREW.size() or int(i) in clean_crew: return false
		clean_crew.append(int(i))
	if clean_crew.size() > 2: return false
	for k in ["site", "reserve", "spent", "day", "paid_build"]:
		if not (data.get(k) is float or data.get(k) is int) or data[k] != int(data[k]): return false
	if data.site < 0 or data.site >= SITES.size() or data.reserve < 0 or data.reserve > 12 or data.spent < 0 or data.spent > 1000 or data.day < 1 or data.day > 24 or data.paid_build < 0 or data.paid_build > data.spent: return false
	var saved_orbit = data.get("orbit_profile", 0)
	if not (saved_orbit is float or saved_orbit is int) or saved_orbit != int(saved_orbit) or saved_orbit < 0 or saved_orbit >= ORBITS.size(): return false
	for k in ["integrated", "delivered"]:
		if not data.get(k) is bool: return false
	for k in ["unlocked", "tests", "log_entries"]:
		if not data.get(k) is Array: return false
	for k in ["stock", "used_materials"]:
		if not data.get(k) is Dictionary: return false
	for r in data.unlocked:
		if r not in ["structures", "navigation", "energy", "robotics"]: return false
	for p_id in clean_installed.values():
		var p = get_part(p_id)
		if p.has("tech") and p.tech not in data.unlocked: return false
	var clean_tests: Array = []
	for t in data.tests:
		if t not in ["structure", "propulsion", "systems"] or t in clean_tests: return false
		clean_tests.append(t)
	if not data.integrated and (not clean_tests.is_empty() or data.paid_build != 0 or not data.used_materials.is_empty()): return false
	if data.delivered and (not data.integrated or clean_tests.size() != 3): return false
	for k in MATERIALS:
		if not (data.stock.get(k) is float or data.stock.get(k) is int) or data.stock[k] < 0 or data.stock[k] > STOCK[k]: return false
		var used = data.used_materials.get(k, 0)
		if not (used is float or used is int) or used < 0 or data.stock[k] + used != STOCK[k]: return false
	for key in data.used_materials:
		if key not in MATERIALS: return false
	for entry in data.log_entries:
		if not entry is String: return false
	installed = clean_installed
	crew = clean_crew
	site = int(data.site)
	orbit_profile = int(saved_orbit)
	reserve = int(data.reserve)
	unlocked = data.unlocked
	spent = int(data.spent)
	day = int(data.day)
	integrated = data.integrated
	tests = clean_tests
	delivered = data.delivered
	stock = data.stock
	paid_build = int(data.paid_build)
	used_materials = data.used_materials
	log_entries = data.log_entries
	return true

func export_manifest(path: String) -> Error:
	if not delivered: return ERR_UNAUTHORIZED
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	var names: Array = []
	for i in crew: names.append(CREW[i].name)
	f.store_string(JSON.stringify({"schema_version": 1, "mission": "Lunar Dawn Demonstration", "phase": "launch_ready", "site": SITES[site].name, "orbit": ORBITS[orbit_profile].name, "crew": names, "surface_hours": 72, "parts": installed, "reserve": reserve, "totals": totals(), "flight_performance": flight_performance(), "funds_remaining": 1000 - spent, "day": day, "qualification": tests, "note": "Abstract game units. Not a validated flight or NASA mission model."}, "\t"))
	return OK
