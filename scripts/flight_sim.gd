extends RefCounted
## Scaled planar patched-conic flight with 3D spacecraft visuals. Positions/metres, time/seconds.
const EARTH_R = 300000.0
const EARTH_MU = 882900000000.0
const MOON_R = 60000.0
const MOON_MU = 5832000000.0
const MOON_D = 3000000.0
const MOON_SOI = 440000.0
const TRANSFER_PASS_RADIUS = MOON_R + 140000.0
const ATMOSPHERE = 30000.0
const PARKING = 65000.0
const WARPS = [1, 2, 4, 8, 16, 32, 64]
const ASCENT_RESERVE = 1500.0
const REFERENCE_DRY_MASS = 25900.0
const LANDING_HAZARDS = {
	"boulders": {"title": "BOULDER FIELD", "detail": "Ground radar finds boulders in the landing ellipse. Divert to clear ground or attempt a precise landing between them.", "safe": "Divert to clear ground", "risk": "Hold course through boulders", "risk_note": "20% vehicle loss; 35% landing-gear damage.", "cost": 780.0},
	"radar": {"title": "RADAR BLACKOUT", "detail": "Dust and terrain echoes interrupt the altitude radar. Hover for a clean return or descend using an uncertain estimate.", "safe": "Hover and reacquire radar", "risk": "Trust the inertial estimate", "risk_note": "Displayed altitude may read 15–60 m too high.", "cost": 620.0},
	"engine": {"title": "ENGINE FEED SURGE", "detail": "Descent-engine pressure is oscillating. Purge the feed line now or continue with reduced thrust.", "safe": "Purge the feed line", "risk": "Continue at reduced thrust", "risk_note": "Descent thrust falls to 72% for the remaining flight.", "cost": 680.0},
	"slope": {"title": "UNSTABLE REGOLITH", "detail": "The intended touchdown patch slopes toward a soft crater lip. Shift to firmer ground or accept a narrow touchdown margin.", "safe": "Shift to firmer ground", "risk": "Land on the slope", "risk_note": "Touchdown must be under 2.5 m/s; 35% gear damage chance.", "cost": 740.0}
}
var pos = Vector3(0, EARTH_R + 12, 0)
var vel = Vector3.ZERO
var attitude = Basis.IDENTITY
var elapsed = 0.0
var countdown = -1.0
var launched = false
var engine = false
var throttle = 1.0
var stage = 0
var stage_times = [0.0,0.0,0.0]
var fuel: Array = []
var capacities: Array = []
var legacy_capacities: Array = []
var exhaust: Array = [3100.0, 3400.0, 3200.0]
var thrust: Array = [0.0, 0.0, 0.0]
var dry_mass = 40000.0
var stage_dry: Array = [9000.0, 5000.0, 0.0]
var body = "Earth"
var phase = "Launch pad"
var guide = false
var guide_parking_radius = 0.0
var hold = "Manual"
var warp_index = 0
var coast_orbit: Dictionary = {}
var paused = false
var crashed = false
var landed = false
var orbit_achieved = false
var lunar_orbit = false
var transfer_requested = false
var transfer_burning = false
var transfer_done = false
var descent_requested = false
var moon_phase = 0.4
var message = "SPACE starts the countdown. Set throttle and steer with A / D or W / S."
var events: Array = []
var campaign_key = ""
var design: Dictionary = {}
var payload_name = "Dawn Explorer"
var launch_mass = 0.0
var predicted_encounter = Vector3.ZERO
var predicted_moon = Vector3.ZERO
var predicted_encounter_time = 0.0
var prediction_encounter = false
var closest_approach = INF
var hazard_queue: Array = []
var hazard_rolls: Array = []
var hazard_index = 0
var hazard_pending = ""
var hazard_risks: Array = []
var landing_condition = ""
var launch_mass_ok = true
var launch_authorized = true
var launch_required_units = 0.0
var launch_capacity_units = 0.0
var lunar_capture_altitude = 20000.0
var landing_site: Dictionary = {}
var lunar_coast_started = -1.0
var lunar_coast_period = 0.0

func configure(mission, validate_launch: bool = true) -> void:
	design = mission.installed.duplicate()
	var key_parts = [design, mission.crew, mission.site, mission.reserve, mission.day]
	if mission.orbit_profile != 0: key_parts.append(mission.orbit_profile)
	campaign_key = JSON.stringify(key_parts)
	var t = mission.totals()
	var launcher = mission.get_part(design["Launch vehicle"])
	var profile = mission.ORBITS[mission.orbit_profile]
	launch_required_units = t.mass + profile.lift_margin
	launch_capacity_units = launcher.capacity
	launch_mass_ok = launch_required_units <= launch_capacity_units
	lunar_capture_altitude = profile.capture_altitude
	landing_site = mission.SITES[mission.site].duplicate()

	# Tanks and engines have fixed ratings; extra payload and service-module mass
	# lower the available delta-v and thrust-to-weight ratio instead of spawning fuel.
	dry_mass = maxf(22000, (t.mass - launcher.mass - 10.0) * 700)
	stage_dry[0] = 9000.0 + (launcher.mass - 21.0) * 700.0
	var budgets = [float(mission.get_part(design["Launch vehicle"]).dv), float(mission.get_part(design["Service module"]).dv), float(mission.get_part(design["Lunar lander"]).dv + mission.reserve * 50)]
	fuel.resize(3)
	legacy_capacities.resize(3)
	var upper = REFERENCE_DRY_MASS
	var legacy_upper = maxf(22000, (t.mass - launcher.mass - mission.get_part(design["Service module"]).mass) * 700)
	for i in range(2, -1, -1):
		upper += stage_dry[i]
		fuel[i] = upper * (exp(budgets[i] / exhaust[i]) - 1.0)
		upper += fuel[i]
		legacy_upper += 9000.0 if i == 0 else stage_dry[i]
		legacy_capacities[i] = legacy_upper * (exp(budgets[i] / exhaust[i]) - 1.0)
		legacy_upper += legacy_capacities[i]
	capacities = fuel.duplicate()
	launch_mass = mass()
	thrust = [upper * (17.5 if design["Launch vehicle"] == "titan" else 16.0), (upper - fuel[0] - stage_dry[0]) * 13.0, (REFERENCE_DRY_MASS + fuel[2]) * 9.0]
	launch_authorized = mission.valid_design() if validate_launch else launch_mass_ok
	log_event("Vehicle loaded from the qualified mission manifest.")

func moon_position(at_time: float = -1.0) -> Vector3:
	var a = moon_phase + sqrt(EARTH_MU / pow(MOON_D, 3)) * (elapsed if at_time < 0 else at_time)
	return Vector3(sin(a), cos(a), 0) * MOON_D

func moon_velocity() -> Vector3:
	var p = moon_position()
	return Vector3(p.y, -p.x, 0).normalized() * sqrt(EARTH_MU / MOON_D)

func center() -> Vector3:
	return moon_position() if body == "Moon" else Vector3.ZERO

func relative_position() -> Vector3:
	return pos - center()

func site_position() -> Vector3:
	# Site locations are separated within the game's shared orbital plane.
	var angle = float(landing_site.get("map_angle", 2.35))
	return moon_position() + Vector3(sin(angle), cos(angle), 0) * MOON_R

func site_angle_error() -> float:
	var relative = pos - moon_position()
	return wrapf(float(landing_site.get("map_angle", 2.35)) - atan2(relative.x, relative.y), -PI, PI)

func site_distance() -> float:
	return absf(site_angle_error()) * MOON_R

func relative_velocity() -> Vector3:
	return vel - (moon_velocity() if body == "Moon" else Vector3.ZERO)

func radius() -> float: return MOON_R if body == "Moon" else EARTH_R
func mu() -> float: return MOON_MU if body == "Moon" else EARTH_MU
func altitude() -> float: return relative_position().length() - radius()
func indicated_altitude() -> float:
	if "radar" in hazard_risks:
		return altitude() + 15.0 + hazard_rolls[hazard_queue.find("radar")] * 45.0
	return altitude()
func radial() -> Vector3: return relative_position().normalized()
func vertical_speed() -> float: return relative_velocity().dot(radial())
func horizontal_speed() -> float: return (relative_velocity() - radial() * vertical_speed()).length()
func direction() -> Vector3: return attitude.y.normalized()
func planar_attitude(facing: Vector3) -> Basis:
	var flat = Vector3(facing.x, facing.y, 0)
	if flat.length_squared() < 0.000001: flat = Vector3.UP
	flat = flat.normalized()
	return Basis(Vector3.BACK, -atan2(flat.x, flat.y))
func tangent() -> Vector3:
	var t = Vector3(radial().y, -radial().x, 0)
	return t.normalized() if t.length() > 0.001 else Vector3.RIGHT

func mass() -> float:
	var m = dry_mass
	for i in range(stage, 3): m += fuel[i] + stage_dry[i]
	return m

func remaining_dv() -> float:
	var m = mass()
	var dv = 0.0
	for i in range(stage, 3):
		dv += exhaust[i] * log(m / maxf(1, m - fuel[i]))
		m -= fuel[i] + stage_dry[i]
	return dv

func orbit() -> Dictionary:
	var r = relative_position()
	var v = relative_velocity()
	var h = r.cross(v)
	var ev = v.cross(h) / mu() - r.normalized()
	var eccentricity = ev.length()
	var energy = v.length_squared() / 2 - mu() / r.length()
	var a = -mu() / (2 * energy) if absf(energy) > 0.001 else 1e12
	var pe = h.length_squared() / mu() / (1 + eccentricity) - radius()
	var ap = a * (1 + eccentricity) - radius() if energy < 0 else INF
	return {"pe": pe, "ap": ap, "e": eccentricity, "a": a, "bound": energy < 0, "period": TAU * sqrt(pow(a, 3) / mu()) if energy < 0 else INF}

func earth_orbit_ready() -> bool:
	if not launched or body != "Earth" or crashed or landed: return false
	var path = orbit()
	return path.bound and path.pe > ATMOSPHERE + 5000.0

func gravity(p: Vector3, time: float) -> Vector3:
	if body == "Moon":
		var r = p - moon_position(time)
		# Acceleration of the moving reference body's origin keeps relative motion consistent.
		return -r.normalized() * MOON_MU / maxf(r.length_squared(), 100) - moon_position(time).normalized() * EARTH_MU / pow(MOON_D, 2)
	return -p.normalized() * EARTH_MU / maxf(p.length_squared(), 100)

func start_coast_orbit() -> bool:
	var r = relative_position()
	var v = relative_velocity()
	var gravitational_parameter = mu()
	var energy = v.length_squared() * 0.5 - gravitational_parameter / r.length()
	if energy >= 0: return false
	var a = -gravitational_parameter / (2.0 * energy)
	var angular_momentum = r.cross(v)
	var eccentricity_vector = v.cross(angular_momentum) / gravitational_parameter - r.normalized()
	var eccentricity = eccentricity_vector.length()
	if eccentricity >= 0.999: return false
	var major_axis = eccentricity_vector.normalized() if eccentricity > 0.00001 else r.normalized()
	var minor_axis = angular_momentum.normalized().cross(major_axis)
	var true_anomaly = atan2(r.dot(minor_axis), r.dot(major_axis))
	var eccentric_anomaly = atan2(sqrt(1.0 - eccentricity * eccentricity) * sin(true_anomaly), eccentricity + cos(true_anomaly))
	coast_orbit = {"body": body, "epoch": elapsed, "a": a, "e": eccentricity,
		"mean_anomaly": eccentric_anomaly - eccentricity * sin(eccentric_anomaly),
		"mean_motion": sqrt(gravitational_parameter / pow(a, 3)),
		"major_axis": major_axis, "minor_axis": minor_axis}
	return true

func advance_coast_orbit(at_time: float) -> void:
	var e: float = coast_orbit.e
	var a: float = coast_orbit.a
	var mean_anomaly: float = coast_orbit.mean_anomaly + coast_orbit.mean_motion * (at_time - coast_orbit.epoch)
	var eccentric_anomaly = mean_anomaly
	for i in range(8):
		var correction = (eccentric_anomaly - e * sin(eccentric_anomaly) - mean_anomaly) / (1.0 - e * cos(eccentric_anomaly))
		eccentric_anomaly -= correction
		if absf(correction) < 0.000000000001: break
	var c = cos(eccentric_anomaly)
	var s = sin(eccentric_anomaly)
	var minor_scale = sqrt(1.0 - e * e)
	var radius_now = a * (1.0 - e * c)
	var orbit_position: Vector3 = a * ((c - e) * coast_orbit.major_axis + minor_scale * s * coast_orbit.minor_axis)
	var orbit_velocity: Vector3 = sqrt(mu() * a) / radius_now * (-s * coast_orbit.major_axis + minor_scale * c * coast_orbit.minor_axis)
	pos = orbit_position + (moon_position(at_time) if body == "Moon" else Vector3.ZERO)
	vel = orbit_velocity + (moon_velocity_at(at_time) if body == "Moon" else Vector3.ZERO)

func moon_velocity_at(at_time: float) -> Vector3:
	var p = moon_position(at_time)
	return Vector3(p.y, -p.x, 0).normalized() * sqrt(EARTH_MU / MOON_D)

func log_event(text: String) -> void:
	message = text
	events.append({"time": elapsed, "text": text})
	if events.size() > 40: events.pop_front()

func ignite_or_stage() -> void:
	if crashed or landed: return
	if not launched:
		if not launch_mass_ok:
			log_event("LAUNCH SCRUBBED: %.1f lift units required; launcher supports %.0f. Reduce mass or upgrade lift." % [launch_required_units, launch_capacity_units])
			return
		if not launch_authorized:
			log_event("LAUNCH SCRUBBED: engineering review requirements are unmet. Return to mission design.")
			return
		if countdown < 0:
			countdown = 5.0
			log_event("Launch sequence started. T minus 5 seconds.")
		return
	if stage >= 2:
		log_event("Final stage active. No more stages to separate.")
		return
	stage += 1
	stage_times[stage] = elapsed
	engine = true
	log_event("Stage separated. " + ["", "Service propulsion online.", "Lunar descent propulsion online."][stage])

func set_engine(value: bool) -> void:
	if not launched or crashed or landed: return
	engine = value

func toggle_autopilot() -> void:
	if crashed or landed: return
	guide = not guide
	if guide:
		hold = "Manual"
		guide_parking_radius = 0.0
		if earth_orbit_ready() and not transfer_done and orbit().e > 0.03:
			guide_parking_radius = relative_position().length()
			transfer_requested = false
			transfer_burning = false
		if body == "Moon" and descent_requested and lunar_orbit: request_descent()
		if not launched: ignite_or_stage()
	else:
		throttle = 0
		engine = false

func set_warp(index: int) -> void:
	warp_index = clampi(index, 0, WARPS.size() - 1)

func point_toward(d: Vector3, dt: float = 100.0) -> void:
	var flat = Vector3(d.x, d.y, 0)
	if flat.length_squared() < 0.000001: return
	var current = planar_attitude(direction()).get_rotation_quaternion()
	var target = planar_attitude(flat).get_rotation_quaternion()
	attitude = Basis(current.slerp(target, minf(1, dt * 2.5)))

func manual_rotate(turn: float, dt: float) -> void:
	if absf(turn) < 0.001 or paused: return
	guide = false
	hold = "Manual"
	attitude = Basis(Vector3.BACK, -turn * dt * 0.6) * planar_attitude(direction())

func request_transfer() -> void:
	if not earth_orbit_ready() or transfer_done:
		log_event("Raise periapsis above the atmosphere in a bound Earth orbit before planning lunar transfer.")
		return
	transfer_requested = true
	log_event("Moon targeted. Coast to the transfer window, then burn prograde.")

func request_descent() -> void:
	if not lunar_orbit:
		log_event("Capture into a stable lunar orbit before beginning descent.")
		return
	descent_requested = true
	if hazard_queue.is_empty():
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var available = LANDING_HAZARDS.keys()
		for i in range(2):
			var selected = rng.randi_range(0, available.size() - 1)
			hazard_queue.append(available[selected])
			hazard_rolls.append(rng.randf())
			available.remove_at(selected)
	if guide:
		while stage < 2: ignite_or_stage()
	phase = "Lunar descent"
	log_event("Descent armed. Cancel horizontal speed, then brake for a soft touchdown.")

func hazard_info() -> Dictionary:
	return LANDING_HAZARDS.get(hazard_pending, {})

func can_avoid_hazard() -> bool:
	if hazard_pending == "": return false
	var cost = float(hazard_info().cost)
	return fuel[stage] >= mass() * (1.0 - exp(-cost / exhaust[stage]))

func resolve_hazard(avoid: bool) -> bool:
	if hazard_pending == "" or (avoid and not can_avoid_hazard()): return false
	var info = hazard_info()
	if avoid:
		fuel[stage] -= mass() * (1.0 - exp(-float(info.cost) / exhaust[stage]))
		log_event("%s: %s. %.0f m/s of delta-v spent." % [info.title, info.safe, info.cost])
	else:
		hazard_risks.append(hazard_pending)
		log_event("%s: %s. Touchdown risk increased." % [info.title, info.risk])
	hazard_pending = ""
	hazard_index += 1
	return true

func trigger_landing_hazard() -> void:
	if body != "Moon" or not descent_requested or hazard_pending != "" or hazard_index >= hazard_queue.size(): return
	var thresholds = [1400.0, 450.0]
	if altitude() > thresholds[hazard_index] or altitude() <= 8: return
	hazard_pending = hazard_queue[hazard_index]
	log_event("DESCENT ALERT: %s. Choose a response before flight continues." % hazard_info().title)

func transfer_window() -> float:
	var r = relative_position().length()
	var transfer_time = PI * sqrt(pow((r + MOON_D - TRANSFER_PASS_RADIUS) / 2, 3) / EARTH_MU)
	var desired_phase = PI - sqrt(EARTH_MU / pow(MOON_D, 3)) * transfer_time
	var moon_a = atan2(moon_position().x, moon_position().y)
	var ship_a = atan2(pos.x, pos.y)
	return wrapf(moon_a - ship_a - desired_phase, -PI, PI)

func transfer_plan() -> Dictionary:
	# Circular-orbit planning preview. The live coast predictor takes over after injection.
	var r = relative_position().length()
	var target_r = MOON_D - TRANSFER_PASS_RADIUS
	var moon_rate = sqrt(EARTH_MU / pow(MOON_D, 3))
	var ship_rate = sqrt(EARTH_MU / pow(r, 3))
	var flight_time = PI * sqrt(pow((r + target_r) * .5, 3) / EARTH_MU)
	var relative_rate = moon_rate - ship_rate
	var wait_time = fposmod(-transfer_window() / relative_rate, TAU / absf(relative_rate))
	if absf(transfer_window()) < .055: wait_time = 0.0
	var ship_angle = atan2(pos.x, pos.y) + ship_rate * wait_time
	# Intersect the departure ray with the actual osculating ellipse, not a circle
	# with the spacecraft's current radius.
	var departure_direction = Vector3(sin(ship_angle), cos(ship_angle), 0)
	var angular_momentum = pos.cross(vel)
	var eccentricity_vector = vel.cross(angular_momentum) / EARTH_MU - pos.normalized()
	var departure_radius = angular_momentum.length_squared() / EARTH_MU / maxf(0.00001, 1.0 + eccentricity_vector.dot(departure_direction))
	var departure = departure_direction * departure_radius
	flight_time = PI * sqrt(pow((departure_radius + target_r) * .5, 3) / EARTH_MU)
	var arrival_time = elapsed + wait_time + flight_time
	var injection_speed = sqrt(EARTH_MU * (2.0 / departure_radius - 2.0 / (departure_radius + target_r)))
	return {"wait": wait_time, "flight_time": flight_time, "arrival_time": arrival_time,
		"departure": departure, "moon_arrival": moon_position(arrival_time),
		"burn_dv": maxf(0, injection_speed - relative_velocity().length())}

func command_velocity(target: Vector3, response: float, dt: float) -> void:
	var local_gravity = -radial() * mu() / relative_position().length_squared()
	var a = (target - relative_velocity()) / response - local_gravity
	point_toward(a, dt)
	throttle = clampf(a.length() * mass() / thrust[stage], 0, 1)
	engine = throttle > 0.002

func guidance(dt: float) -> void:
	if not guide: return
	if fuel[stage] <= 0.01 and stage < 2: ignite_or_stage()
	var h = altitude()
	var r = relative_position().length()
	var o = orbit()
	if body == "Moon":
		if not descent_requested:
			if lunar_coast_started >= 0 and (not o.bound or o.pe < 7000): lunar_coast_started = -1.0
			if lunar_coast_started < 0:
				phase = "Lunar capture / circularizing"
				var target_r = MOON_R + lunar_capture_altitude
				var vertical = clampf((target_r-r)/60.0,-100,60)
				command_velocity(radial()*vertical+tangent()*sqrt(MOON_MU/r),18,dt)
				if o.bound and o.pe > 7000 and o.e < 0.015 and absf(h-lunar_capture_altitude) < 1000:
					lunar_orbit = true
					lunar_coast_started = elapsed
					lunar_coast_period = o.period
					log_event("Parking orbit established. Completing one lunar orbit before the approach to %s." % landing_site.name)
				return
			engine = false
			throttle = 0
			phase = "Lunar parking orbit / " + str(landing_site.name)
			var descent_acceleration = thrust[2]/(dry_mass+stage_dry[2]+fuel[2])
			var orbital_speed = horizontal_speed()
			var lead_angle = clampf((orbital_speed*orbital_speed/(2.0*descent_acceleration)+orbital_speed*2.0)/r,0.02,0.2)
			if elapsed-lunar_coast_started >= lunar_coast_period and site_angle_error() > 0 and site_angle_error() < lead_angle:
				request_descent()
				log_event("Site approach window open. Descending to %s." % landing_site.name)
			else: return
		if descent_requested:
			var sensed_h = h + (15 + hazard_rolls[hazard_queue.find("radar")] * 45 if "radar" in hazard_risks else 0)
			var sideways = horizontal_speed()
			var falling = maxf(0, -vertical_speed())
			var gravity_here = MOON_MU / (r * r)
			var braking = maxf(1.0, thrust[stage] / mass() - gravity_here)
			var stopping_distance = maxf(0, falling * falling - 16.0) / (2.0 * braking)
			var site_speed = clampf(site_angle_error()*MOON_R/30.0,-25,25)
			if sensed_h < 80: site_speed = clampf(site_speed,-1,1)
			if sideways > 6.0:
				# Clear orbital speed before committing to the ballistic descent.
				phase = "Lunar deorbit burn"
				var approach_speed = -minf(60.0,sqrt(maxf(0,sensed_h-8.0)*1.5))
				command_velocity(radial() * approach_speed + tangent()*site_speed, 3.0, dt)
			elif falling > 20.0 and sensed_h > stopping_distance * 1.35 + 220.0 and site_distance() < 100:
				# Coasting here avoids paying for a long powered hover above the Moon.
				phase = "Ballistic descent"
				engine = false
				throttle = 0
				point_toward(radial(), dt)
			else:
				phase = "Lunar landing burn"
				var down = -minf(120.0, sqrt(maxf(0, sensed_h - 8.0) * 1.5))
				if sensed_h < 80.0: down = -clampf(sensed_h * 0.10, 0.8, 6.0)
				command_velocity(radial() * down + tangent()*site_speed, 3.0, dt)
		return
	if guide_parking_radius > 0:
		phase = "Circularizing Earth orbit"
		var radial_target = clampf((guide_parking_radius-r)/60.0,-100,100)
		command_velocity(radial()*radial_target+tangent()*sqrt(EARTH_MU/r),8,dt)
		if o.e < 0.005:
			guide_parking_radius = 0.0
			engine = false
			throttle = 0
		return
	if transfer_done:
		engine = false
		throttle = 0
		phase = "Lunar coast"
		return
	if orbit_achieved and not transfer_requested:
		request_transfer()
	if transfer_requested:
		if not transfer_burning:
			engine = false
			throttle = 0
			phase = "Transfer window"
			if absf(transfer_window()) < 0.055:
				transfer_burning = true
				log_event("Transfer window open. Prograde injection burn.")
		else:
			phase = "Translunar injection"
			point_toward(relative_velocity(), dt)
			engine = true
			throttle = 1.0 if o.ap < MOON_D - TRANSFER_PASS_RADIUS - EARTH_R - 80000 else 0.12
			if o.ap >= MOON_D - TRANSFER_PASS_RADIUS - EARTH_R:
				engine = false
				throttle = 0
				transfer_done = true
				log_event("Injection complete. Cutoff confirmed. Use time warp to coast to the Moon.")
		return
	if orbit_achieved:
		engine = false
		throttle = 0
		phase = "Earth parking orbit"
		return
	phase = "Gravity turn" if h > 2500 else "Liftoff"
	var target_vr = clampf((PARKING - h) / 160, 0, 170)
	if h < 2500: target_vr = 75
	var target_vt = sqrt(EARTH_MU / (EARTH_R + PARKING)) * clampf(h / 42000, 0, 1)
	command_velocity(radial() * target_vr + tangent() * target_vt, 8, dt)

func step(delta: float) -> void:
	if guide and not paused and hazard_pending != "": resolve_hazard(can_avoid_hazard())
	if paused or crashed or landed or hazard_pending != "": return
	pos.z = 0
	vel.z = 0
	attitude = planar_attitude(direction())
	if not launched:
		if countdown >= 0:
			countdown -= minf(delta, 0.25) * WARPS[warp_index]
			if countdown <= 0:
				launched = true
				engine = true
				countdown = -1
				phase = "Liftoff"
				log_event("Liftoff. Pitch east as altitude builds. M opens the orbital map.")
		return
	var total = minf(delta, 0.25) * WARPS[warp_index]
	while total > 0.00001:
		var dt = minf(total, 0.05 if altitude() < 2000 else (0.2 if guide or engine or altitude() < 20000 else 2.0))
		# Event-sensitive substeps prevent warp from crossing approach/ground checks.
		if body == "Earth" and pos.distance_to(moon_position()) < MOON_SOI + 70000: dt = minf(dt, 0.5)
		integrate(dt)
		total -= dt
		if crashed or landed or hazard_pending != "": break

func integrate(dt: float) -> void:
	guidance(dt)
	if not guide and hold != "Manual":
		var d = relative_velocity()
		if hold == "Retrograde": d = -d
		if hold == "Radial": d = radial()
		point_toward(d, dt)
	var powered = engine and throttle > 0.001 and fuel[stage] > 0
	var in_atmosphere = body == "Earth" and altitude() < ATMOSPHERE
	var coast = not powered and not in_atmosphere
	if coast and coast_orbit.is_empty(): coast = start_coast_orbit()
	if coast:
		advance_coast_orbit(elapsed + dt)
	else:
		coast_orbit.clear()
		var initial_gravity = gravity(pos, elapsed)
		var acceleration = initial_gravity
		if in_atmosphere:
			var density = 1.225 * exp(-maxf(0, altitude()) / 4500)
			acceleration -= vel * vel.length() * density * 7.5 / mass()
		if powered:
			var burn = minf(fuel[stage], thrust[stage] * throttle / exhaust[stage] * dt)
			acceleration += direction() * burn * exhaust[stage] * (0.72 if "engine" in hazard_risks else 1.0) / (mass() - burn / 2) / dt
			fuel[stage] -= burn
			if fuel[stage] <= 0.001:
				fuel[stage] = 0
				engine = false
				log_event("Stage fuel exhausted. Press SPACE to separate and ignite the next stage.")
		# Velocity Verlet handles thrust and atmospheric drag.
		pos += vel * dt + acceleration * dt * dt * 0.5
		vel += (initial_gravity + gravity(pos, elapsed + dt)) * dt * 0.5 + (acceleration - initial_gravity) * dt
	pos.z = 0
	vel.z = 0
	elapsed += dt
	var distance = pos.distance_to(moon_position())
	if body == "Earth" and distance < MOON_SOI:
		body = "Moon"
		coast_orbit.clear()
		phase = "Lunar encounter"
		log_event("Entered lunar influence. Turn retrograde and brake into orbit.")
	elif body == "Moon" and distance > MOON_SOI * 1.1:
		body = "Earth"
		coast_orbit.clear()
		lunar_orbit = false
		lunar_coast_started = -1.0
		log_event("Leaving lunar influence. Use the map to review the trajectory.")
	var o = orbit()
	if not guide and body == "Earth" and launched and not orbit_achieved:
		phase = "Gravity turn" if altitude() > 2500 else "Liftoff"
	if not guide and transfer_requested and not transfer_done and o.ap >= MOON_D - EARTH_R - 50000 and (not engine or throttle <= 0.001):
		transfer_done = true
		phase = "Lunar coast"
		log_event("Lunar transfer trajectory established. Check the predicted encounter on the map.")
	if not orbit_achieved and earth_orbit_ready():
		orbit_achieved = true
		phase = "Earth orbit"
		log_event("Safe Earth orbit achieved. Select Navigate to Moon to plan your transfer.")
	if body == "Moon" and not lunar_orbit and o.pe > 7000 and o.ap < 110000:
		lunar_orbit = true
		phase = "Lunar orbit"
		log_event("Lunar capture confirmed. Begin descent when ready, or explore your orbit.")
	trigger_landing_hazard()
	if guide and hazard_pending != "": resolve_hazard(can_avoid_hazard())
	if altitude() < 8:
		var speed_limit = 2.5 if "slope" in hazard_risks else float(landing_site.get("landing_speed",7.0))
		var boulder_roll = hazard_rolls[hazard_queue.find("boulders")] if "boulders" in hazard_risks else 1.0
		if body == "Moon" and relative_velocity().length() < speed_limit and direction().dot(radial()) > 0.90 and boulder_roll >= 0.20:
			landed = true
			pos = moon_position() + radial() * (MOON_R + 8)
			vel = moon_velocity()
			throttle = 0
			phase = "Touchdown"
			var damaged = boulder_roll < 0.55 or ("slope" in hazard_risks and hazard_rolls[hazard_queue.find("slope")] < 0.35)
			var stranded = remaining_dv() < ASCENT_RESERVE
			landing_condition = "Damaged and stranded" if damaged and stranded else ("Crew stranded" if stranded else ("Landing gear damaged" if damaged else "Nominal"))
			phase = "Touchdown / " + landing_condition
			if site_distance() >= 500: phase += " / Off target"
			log_event("CONTACT LIGHT. Touchdown: %s. %.0f m/s remains; ascent reserve needs %.0f m/s." % [landing_condition, remaining_dv(), ASCENT_RESERVE])
			log_event("%s: %.0f m from %s." % ["Selected site reached" if site_distance()<500 else "Off-target landing",site_distance(),landing_site.name])
		else:
			crashed = true
			phase = "Vehicle lost"
			log_event("Impact at %.1f m/s. %sLoad your checkpoint or retry." % [relative_velocity().length(), "Boulder strike. " if boulder_roll < .20 else ""])
		engine = false

func prediction(samples: int = 260) -> PackedVector3Array:
	var result = PackedVector3Array()
	var p = pos
	var v = vel
	var at_time = elapsed
	var local_body = body
	var duration = minf(18000, orbit().period) if orbit().bound else 12000.0
	var sample_dt = duration / samples
	closest_approach = INF
	prediction_encounter = false
	predicted_encounter_time = elapsed
	for i in range(samples):
		result.append(p)
		var remaining = sample_dt
		while remaining > 0.001:
			var dt = minf(remaining, 4.0)
			var c = moon_position(at_time) if local_body == "Moon" else Vector3.ZERO
			var m = MOON_MU if local_body == "Moon" else EARTH_MU
			if p.distance_to(c) < (MOON_R if local_body == "Moon" else EARTH_R): return result
			var a = -(p-c).normalized() * m / maxf(100, p.distance_squared_to(c))
			if local_body == "Moon": a -= c.normalized() * EARTH_MU / pow(MOON_D,2)
			p += v * dt + a * dt * dt * .5
			var c2 = moon_position(at_time + dt) if local_body == "Moon" else Vector3.ZERO
			var a2 = -(p-c2).normalized() * m / maxf(100, p.distance_squared_to(c2))
			if local_body == "Moon": a2 -= c2.normalized() * EARTH_MU / pow(MOON_D,2)
			v += (a+a2)*dt*.5
			at_time += dt
			remaining -= dt
			var distance = p.distance_to(moon_position(at_time))
			if distance < closest_approach:
				closest_approach=distance
				predicted_encounter=p
				predicted_moon=moon_position(at_time)
				predicted_encounter_time=at_time
			if local_body == "Earth" and distance < MOON_SOI:
				local_body="Moon"
				prediction_encounter=true
			elif local_body == "Moon" and distance > MOON_SOI * 1.1: local_body="Earth"
	return result

func snapshot() -> Dictionary:
	return {"version": 1, "tank_balance_version": 2, "campaign": campaign_key, "pos": [pos.x,pos.y,pos.z], "vel": [vel.x,vel.y,vel.z], "attitude": [attitude.x.x,attitude.x.y,attitude.x.z,attitude.y.x,attitude.y.y,attitude.y.z,attitude.z.x,attitude.z.y,attitude.z.z], "elapsed": elapsed, "fuel": fuel.duplicate(), "stage": stage, "body": body, "launched": launched, "countdown": countdown, "warp_index": warp_index, "phase": phase, "orbit": orbit_achieved, "lunar": lunar_orbit, "lunar_coast_started": lunar_coast_started, "lunar_coast_period": lunar_coast_period, "transfer_requested": transfer_requested, "transfer_burning": transfer_burning, "transfer_done": transfer_done, "descent": descent_requested, "landed": landed, "crashed": crashed, "guide": guide, "throttle": throttle, "engine": engine, "events": events.duplicate(true), "landing_hazards": {"queue": hazard_queue.duplicate(), "rolls": hazard_rolls.duplicate(), "index": hazard_index, "pending": hazard_pending, "risks": hazard_risks.duplicate(), "condition": landing_condition}}

func restore(data: Dictionary) -> bool:
	if data.get("version") != 1 or data.get("campaign") != campaign_key: return false
	for key in ["pos", "vel", "fuel"]:
		if not data.get(key) is Array or data[key].size() != 3: return false
		for n in data[key]:
			if not (n is float or n is int) or not is_finite(n): return false
	if not data.get("attitude") is Array or data.attitude.size() != 9: return false
	for n in data.attitude:
		if not (n is float or n is int) or not is_finite(n): return false
	if data.get("body") not in ["Earth", "Moon"]: return false
	if not (data.get("stage") is int or data.get("stage") is float): return false
	if not is_finite(data.stage) or data.stage != int(data.stage) or int(data.stage) not in [0,1,2]: return false
	if not (data.get("elapsed") is float or data.get("elapsed") is int) or not is_finite(data.elapsed) or data.elapsed < 0: return false
	for key in ["lunar_coast_started", "lunar_coast_period"]:
		var value = data.get(key, -1.0 if key == "lunar_coast_started" else 0.0)
		if not (value is float or value is int) or not is_finite(value) or value < (-1.0 if key == "lunar_coast_started" else 0.0): return false
	var saved_countdown = data.get("countdown", -1.0)
	if not (saved_countdown is float or saved_countdown is int) or not is_finite(saved_countdown) or saved_countdown < -1 or saved_countdown > 5: return false
	var saved_warp = data.get("warp_index", 0)
	if not (saved_warp is int or saved_warp is float) or not is_finite(saved_warp) or saved_warp != int(saved_warp) or saved_warp < 0: return false
	var tank_version = data.get("tank_balance_version", 1)
	if not (tank_version is int or tank_version is float) or tank_version != int(tank_version) or int(tank_version) not in [1, 2]: return false
	for i in range(3):
		var allowed_capacity = capacities[i] if int(tank_version) == 2 else legacy_capacities[i]
		if data.fuel[i] < 0 or data.fuel[i] > allowed_capacity + 0.01: return false
	for key in ["launched", "orbit", "lunar", "transfer_requested", "transfer_burning", "transfer_done", "descent", "landed", "crashed", "guide", "engine"]:
		if not data.get(key) is bool: return false
	if not (data.get("throttle") is float or data.get("throttle") is int): return false
	if not is_finite(data.throttle) or data.throttle < 0 or data.throttle > 1: return false
	var hazards = data.get("landing_hazards", {"queue": [], "rolls": [], "index": 0, "pending": "", "risks": [], "condition": ""})
	if not hazards is Dictionary: return false
	if not hazards.get("queue") is Array or not hazards.get("rolls") is Array or not hazards.get("risks") is Array: return false
	if hazards.queue.size() != hazards.rolls.size() or hazards.queue.size() > 2: return false
	for id in hazards.queue:
		if not id is String or not LANDING_HAZARDS.has(id): return false
	for roll in hazards.rolls:
		if not (roll is float or roll is int) or not is_finite(roll) or roll < 0 or roll > 1: return false
	for id in hazards.risks:
		if not id is String or not id in hazards.queue: return false
	if not (hazards.get("index") is int or hazards.get("index") is float) or not is_finite(hazards.index) or hazards.index != int(hazards.index) or hazards.index < 0 or hazards.index > hazards.queue.size(): return false
	if not hazards.get("pending") is String or (hazards.pending != "" and (hazards.index >= hazards.queue.size() or hazards.pending != hazards.queue[hazards.index])): return false
	if not hazards.get("condition") is String or not hazards.condition in ["", "Nominal", "Crew stranded", "Landing gear damaged", "Damaged and stranded"]: return false
	var candidate_pos = Vector3(data.pos[0],data.pos[1],0)
	var rotation_data = data.attitude
	var candidate_basis = Basis(Vector3(rotation_data[0],rotation_data[1],rotation_data[2]),Vector3(rotation_data[3],rotation_data[4],rotation_data[5]),Vector3(rotation_data[6],rotation_data[7],rotation_data[8]))
	if candidate_pos.length() < 1 or candidate_pos.length() > 1e10 or absf(candidate_basis.determinant()-1) > .01: return false
	pos = candidate_pos
	vel = Vector3(data.vel[0],data.vel[1],0)
	attitude = planar_attitude(candidate_basis.y)
	elapsed = data.elapsed
	fuel = data.fuel.duplicate()
	if int(tank_version) == 1:
		for i in range(3): fuel[i] = minf(capacities[i], float(fuel[i]) * capacities[i] / legacy_capacities[i])
	stage = int(data.stage)
	body = data.body
	launched = data.launched
	countdown = -1.0 if launched else float(saved_countdown)
	phase = str(data.get("phase", "Flight resumed"))
	orbit_achieved = data.orbit
	lunar_orbit = data.lunar
	lunar_coast_started = float(data.get("lunar_coast_started", -1.0))
	lunar_coast_period = float(data.get("lunar_coast_period", 0.0))
	transfer_requested = data.transfer_requested
	transfer_burning = data.transfer_burning
	transfer_done = data.transfer_done
	descent_requested = data.descent
	landed = data.landed
	crashed = data.crashed
	# Earlier checkpoints may contain an enabled autopilot; resume them under manual control.
	guide = false
	throttle = data.throttle
	engine = data.engine
	hazard_queue = hazards.queue.duplicate()
	hazard_rolls = hazards.rolls.duplicate()
	hazard_index = int(hazards.index)
	hazard_pending = hazards.pending
	hazard_risks = hazards.risks.duplicate()
	landing_condition = hazards.condition
	events = data.get("events", []).duplicate(true) if data.get("events", []) is Array else []
	if earth_orbit_ready() and not orbit_achieved:
		orbit_achieved = true
		phase = "Earth orbit"
	warp_index = clampi(int(saved_warp), 0, WARPS.size() - 1)
	paused = false
	coast_orbit.clear()
	log_event("Flight checkpoint restored at %d× time." % WARPS[warp_index])
	return true
