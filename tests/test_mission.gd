extends SceneTree
const Mission = preload("res://scripts/mission.gd")
var count = 0
var failures = 0
func expect(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var m = Mission.new()
	expect(not m.valid_design(), "Incomplete starting design must fail")
	expect(not m.manufacture(), "Cannot manufacture missing essentials")
	expect(not m.run_test("structure"), "Cannot test before integration")
	expect(not m.equip("heron_p"), "Research gate enforced")
	for slot in Mission.SLOTS.slice(0, 9):
		expect(not m.default_part(slot).is_empty() and m.available(m.default_part(slot)), "Starting default is unlocked: " + slot)
	expect(m.default_part("Rover").is_empty(), "Locked-only slot has no default")
	expect(m.default_part("Lunar lander").id == "heron", "Basic lander is default")
	expect(m.research("navigation") and m.default_part("Lunar lander").id == "heron", "Research does not silently replace selected lander")
	m = Mission.new()
	m.reference_design()
	expect(m.valid_design(), "Reference design satisfies all constraints")
	var t = m.totals()
	expect(t.cost == 820 and t.mass == 68, "Reference economics are stable")
	m.reserve = 0
	expect(not m.valid_design(), "Fuel reserve deficit blocks manufacturing")
	m.reserve = 4
	m.crew = [0]
	expect(not m.valid_design(), "Two astronauts required")
	m.crew = [0, 1]
	m.site = 1
	expect(not m.valid_design(), "Shadow endurance constrains crater rim")
	expect(m.research("energy") and m.equip("sol_x"), "Unlock and install battery upgrade")
	expect(m.valid_design(), "Battery upgrade solves crater rim")
	m = Mission.new()
	m.reference_design()
	m.site = 2
	expect(not m.valid_design(), "Rough site requires navigation and communications upgrades")
	m.research("navigation")
	m.research("energy")
	m.equip("heron_p")
	m.equip("sol_x")
	m.equip("echo_b")
	expect(m.valid_design(), "Hard site has an achievable architecture")
	m = Mission.new()
	m.reference_design()
	m.stock.Metal = 0
	expect(not m.valid_design(), "Insufficient crafting stock blocks manufacture")
	m = Mission.new()
	m.reference_design()
	m.day = 20
	expect(not m.valid_design(), "Launch window reserves build and test time")
	m = Mission.new()
	m.reference_design()
	m.spent = 180
	expect(not m.valid_design(), "Test funding is reserved before manufacture")
	m = Mission.new()
	m.reference_design()
	expect(m.manufacture(), "Reference manufacture succeeds")
	expect(m.spent == 820 and m.day == 14, "Manufacturing consumes funds and time")
	expect(m.stock.Metal == 12, "Recipe stock consumed")
	expect(not m.equip("titan") and not m.research("energy"), "Integrated configuration locked")
	expect(not m.manufacture(), "No duplicate charge for manufacture")
	expect(m.run_test("structure"), "Structural qualification")
	expect(not m.run_test("structure"), "No duplicate test charge")
	expect(not m.run_test("unknown"), "Reject unknown test")
	expect(not m.deliver(), "No authorization before every test")
	expect(m.run_test("propulsion") and m.run_test("systems"), "Remaining qualification tests")
	expect(m.is_ready() and m.spent == 856 and m.day == 17, "Winnable final budget and schedule")
	expect(m.deliver() and not m.deliver(), "Completion is awarded exactly once")
	expect(m.save_to("/tmp/moonbound-test-save.json") == OK, "Save completed campaign")
	var loaded = Mission.new()
	expect(loaded.load_from("/tmp/moonbound-test-save.json"), "Load valid campaign")
	expect(loaded.delivered and loaded.is_ready() and loaded.spent == 856, "Loaded progress and readiness preserved")
	expect(loaded.export_manifest("/tmp/moonbound-test-manifest.json") == OK, "Export qualified manifest")
	m = Mission.new()
	expect(m.export_manifest("/tmp/moonbound-invalid.json") == ERR_UNAUTHORIZED, "Block premature manifest")
	m.reference_design()
	m.manufacture()
	m.run_test("structure")
	m.return_to_design()
	expect(m.spent == 12 and m.day == 15 and m.stock == Mission.STOCK, "Disassembly recovers hardware, preserves time and test expense")
	expect(m.tests.is_empty() and not m.integrated, "Disassembly invalidates tests")
	var f = FileAccess.open("/tmp/moonbound-bad-save.json", FileAccess.WRITE)
	f.store_string('{"version":1,"installed":{"Crew capsule":"bogus"},"crew":[]}')
	f.close()
	expect(not m.load_from("/tmp/moonbound-bad-save.json"), "Malformed save rejected")
	expect(m.spent == 12 and m.installed.size() == 9, "Malformed save never partially changes state")
	print("Moonbound: %d checks, %d failures" % [count, failures])
	quit(1 if failures else 0)
