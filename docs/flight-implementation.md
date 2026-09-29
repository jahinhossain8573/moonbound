# Chapter 02 — Launch & lunar flight

## Reference review

Reviewed the supplied asa video, “How to land on the Moon and back! | Spaceflight Simulator 1.5 Tutorial”: https://www.youtube.com/watch?v=yVVszEPLyjs

Inspected the video at launch (1:15), ascent/orbit aiming (2:39), staging (3:45), transfer encounter planning (5:00), lunar time acceleration (6:16), descent braking (7:31), touchdown (8:46), and the subsequent Earth-return segments (10:01, 11:17). The flow is adapted to original procedural 3D geometry and desktop controls. No video assets or game code were copied. This chapter ends at lunar touchdown; Earth return and surface work remain for subsequent work.

## Architecture

`flight_sim.gd` has no scene dependencies. It integrates Earth-relative positions and velocities in three dimensions, switching to the moving Moon’s influence at a defined sphere boundary. Local lunar gravity includes the acceleration of the reference body's origin. Coast uses velocity Verlet; thrust and drag are integrated with bounded substeps. Guidance computes attitude and throttle commands applied through the same finite-fuel engines used by manual control. Guidance may automatically stage; manual pilots stage with Space.

Each selected launcher, service module and lander supplies its assembly delta-v budget. Propellant masses are derived backward through the stack using the rocket equation. Payload selections alter dry mass and appearance. Selected launcher changes thrust; service and lander variants alter their own budgets; reserve fuel increases the lander budget. This remains balanced game physics rather than a NASA mission model.

`flight_world.gd` extends the existing vehicle renderer. It uses the actual selected module meshes; launch and service assemblies are hidden after separation, with temporary debris. The supplied textured Earth GLB appears in both the flight view and orbital map. Its imported 100-unit radius is normalized so it matches the simulation scale. The launch pad, Moon, stars, exhaust, map overlays and lunar surface are procedural. The flight view uses a floating local craft origin and apparent-size planet rendering; the orbital map uses a fixed system scale. Before injection, the map draws the planned burn point and transfer arc, the Moon's current position, its projected arrival position, and its orbital motion between them. After injection, the coast prediction drives the arrival marker and encounter or miss display. The timing and burn cues appear in the flight plan. The spacecraft view uses the third-person perspective camera and right-drag orbit controls. The orbital map uses an orthographic camera, opens at an Earth-orbit scale before transfer, renders the 3D spacecraft on its projected path, and pans with right drag. Moon lock keeps the target in view once clear of the launch surface, displays an on-screen target marker, and focuses the orbital map on the Moon.

`flight_ui.gd` adds an independent native Godot flight deck using the existing theme helpers. Entering flight is gated by campaign launch authorization. The assembly viewport is suspended while flying and restored on exit. Flight data is stored separately and validated against the campaign signature. JSON writes use a temporary file and rename; failed and malformed loads leave the live flight intact. Autosaves preserve the last good checkpoint on impact.

## Validation

- Campaign model: 49 existing checks.
- Flight model: 40 checks, including thrust, mass/fuel use, 3D steering, staging, warp limits, orbital-energy conservation, JSON checkpoint round trips, malformed/mismatched saves, collision, manual injection detection, trajectory prediction, and full flights at 10 and 60 FPS plus upgraded hardware.
- Flight UI: simulated keyboard input and slider/button interaction, countdown, pause, full physical launch-to-touchdown progression, stage visibility, save/reload and return to assembly. Screenshots cover pad, countdown, ascent, Earth orbit, transfer, encounter, descent and touchdown.
- Existing assembly UI interaction regression retained.

## Limits

The Moon is on a circular orbit, the system is scaled, and guidance favors an accessible first flight. There is no real-world ephemeris, atmospheric heating, n-body perturbation, precise geographic landing target, EVA or return mission. The selected landing-region name is expedition metadata; landing is on a generic procedural lunar surface. The pre-burn preview assumes a near-circular parking orbit. The coast prediction omits future thrust and atmospheric drag, and is intended for orbital planning above the atmosphere.
