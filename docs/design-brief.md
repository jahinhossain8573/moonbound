# Moonbound — Moon Mission Design Blueprint

## 1. Core direction

Moonbound is a mission-design game about turning a mission objective into a working spacecraft and then operating it under constraints.

The first playable campaign should focus on one complete mission:

> Land two astronauts near the lunar south-pole region, deploy a small habitat, complete science objectives, survive a short surface stay, and return safely.
> 

This is intentionally smaller than a complete space-program simulator. The player should still experience the full mission lifecycle, but each system should be readable and game-sized.

### The player fantasy

The player is the mission director. They decide what the mission is trying to achieve, spend limited funding, assign specialists, select and assemble hardware, test it, launch it, react to problems, and learn from the result.

The important lesson is not “build the biggest rocket.” It is:

> Every improvement in one area creates pressure somewhere else: mass, cost, power, schedule, reliability, communication, or science return.
> 

## 1.1 Concept-to-operation mission sequence

The challenge description can be translated into the following real mission-development sequence. In Moonbound, each phase should become either a player decision, a management screen, a simulation phase, or a result that changes the next phase.

1. **Mission need and objective** — define the problem the mission must solve. For example: investigate a permanently shadowed lunar crater, demonstrate a habitat, or return samples.
2. **Mission requirements** — turn the objective into measurable requirements: destination, crew, duration, science targets, landing accuracy, payload, communications, safety, budget, and schedule.
3. **Concept studies** — compare possible ways to achieve the mission. Decide whether the mission is robotic or crewed, direct or staged, cargo-first or crew-first, and what level of risk is acceptable.
4. **Mission architecture** — define the complete system: launch vehicle, spacecraft, lander, habitat, instruments, ground stations, crew, launch window, trajectory, and surface operations.
5. **Trade studies and resource budgets** — resolve competing demands using mass, power, volume, fuel, data, funding, time, reliability, and crew-consumable budgets.
6. **Preliminary design** — select technologies and create an initial vehicle and payload configuration. Check that the design can theoretically meet the requirements.
7. **Detailed design** — specify the actual equipment, interfaces, materials, software, communications links, operating procedures, and contingency plans.
8. **Procurement, research, and manufacturing** — research missing technology, obtain resources, craft components, and assemble the spacecraft and payload.
9. **Integration and testing** — combine the systems and test propulsion, structure, avionics, power, communications, thermal control, life support, instruments, and deployment sequences.
10. **Launch readiness** — choose a launch window, transport the vehicle to the pad, load consumables, check weather and range conditions, assign the crew, and make the go/no-go decision.
11. **Launch and early operations** — launch, reach the target orbit, deploy or activate systems, and resolve early failures.
12. **Transit and navigation** — operate the spacecraft during cruise, manage power and communications, perform trajectory corrections, monitor crew health, and protect consumables.
13. **Arrival and landing** — enter lunar orbit or the target trajectory, perform descent, avoid hazards, land within the selected site, and preserve enough reserve for recovery.
14. **Commissioning and deployment** — activate the habitat, power, communications, life support, instruments, and other surface equipment. Confirm that the landing site is safe before beginning the main mission.
15. **Mission operations** — schedule EVAs, science activities, maintenance, sample collection, rover drives, crew rest, communications windows, and emergency responses.
16. **Mission data and evaluation** — transmit science data, track mission health, compare results against requirements, and calculate science, safety, cost, and schedule performance.
17. **Return, recovery, and closeout** — return the crew or samples when required, recover the spacecraft, archive the data, debrief the crew, and convert the result into funding, reputation, and new technology.

### The minimum playable interpretation

For the first Moonbound prototype, these seventeen real-world steps can be compressed into eight player-facing phases:

1. Brief and requirements
2. Architecture and site selection
3. Research, crew, and resource planning
4. Build and integrate
5. Test and launch
6. Transit and landing
7. Surface operations
8. Return, scoring, and progression

This keeps the game faithful to the challenge while avoiding a separate menu for every engineering department.

## 2. Full mission lifecycle

The current concept has the base, research, crafting, launch, and exploration pieces. The main gap is that the game needs an explicit chain connecting them from mission idea to evaluation.

The complete loop should be:

1. **Mission brief** — choose the objective, crew size, landing region, science targets, duration, and reward.
2. **Mission concept** — choose a mission architecture: direct landing, cargo-first, or crew-and-habitat together.
3. **Site selection** — compare landing sites by sunlight, terrain risk, communication coverage, science value, and travel distance.
4. **Research** — unlock technologies that make certain architectures possible or safer.
5. **Crew selection and training** — assign specialists and prepare them for the mission; the wrong crew increases specific risks.
6. **Vehicle and payload design** — fit the launch vehicle, crew capsule, lander, habitat, power, communications, and science equipment inside mass and volume limits.
7. **Budget and schedule** — choose what to build now, what to reuse, and what to postpone. Delays can cause a missed launch window.
8. **Manufacturing and integration** — craft subassemblies, combine them into stages, and verify compatibility.
9. **Testing** — run structural, propulsion, avionics, thermal, communications, and life-support tests. Testing costs time and funds but reduces failure risk.
10. **Launch preparation** — transport the vehicle to the pad, load propellant, assign the launch crew, and choose a launch window.
11. **Launch and ascent** — manage a simplified launch sequence with a small number of meaningful decisions rather than requiring a full KSP simulator immediately.
12. **Transit and lunar orbit** — monitor power, communications, navigation, crew health, and consumables.
13. **Descent and landing** — make the highest-risk flight decisions: fuel reserve, landing zone, terrain avoidance, and landing mode.
14. **Surface deployment** — deploy the habitat, power system, communications mast, instruments, and rover if available.
15. **Surface operations** — schedule EVAs, science tasks, maintenance, and rest while managing oxygen, power, time, and radiation exposure.
16. **Return and recovery** — launch from the Moon, rendezvous if required, re-enter, and recover the crew and samples.
17. **Debrief** — score mission success, science value, safety, budget efficiency, and lessons learned. The result unlocks funding and future technology.

### What is missing from the current plan

The existing ideas are a good set of locations and systems, but these pieces still need to be explicit:

- mission objectives and success criteria;
- mission architecture and payload planning;
- landing-site selection;
- mass, power, communications, and consumables budgets;
- crew roles and training;
- manufacturing and integration dependencies;
- pre-launch testing and reliability;
- launch windows and schedule pressure;
- navigation, landing, and abort decisions;
- surface-operations scheduling;
- failure, redundancy, and recovery options;
- mission scoring, science return, and post-mission funding.

Without these, the player can craft objects but does not yet design a mission. These systems turn the game from a building sandbox into a mission-design game.

## 3. Recommended first mission

### Mission name

**Lunar Dawn Demonstration**

### Objective

Land two astronauts near a high-value lunar south-pole site, deploy a compact habitat, complete three science tasks, remain on the surface for 72 hours, and return with samples.

### Tutorial-scale constraints

These are game-balance values, not real mission requirements:

- crew: 2 astronauts;
- surface duration: 72 hours;
- science objectives: 3;
- initial launch mass limit: 80 mass units;
- initial budget: 1,000 funding units;
- required surface systems: habitat, power, communications, life support, and one science instrument;
- optional systems: rover, second science instrument, spare parts, and redundant communications;
- primary success: crew returns alive;
- secondary success: habitat deployed and science objectives completed.

The first mission should be winnable with a safe, moderately expensive design. Optimisation and ambitious shortcuts should be what create interesting replay value.

## 4. Base facilities

Keep the planned buildings, but give each one a clear gameplay responsibility.

| Facility | Player action | Minimum version |
| --- | --- | --- |
| Mission Control | Select missions, inspect constraints, plan operations, monitor active flights | Mission brief, timeline, alerts, mission score |
| R&D | Research technologies and inspect trade-offs | Small branching tech tree |
| Astronaut Complex | Recruit, assign, train, and manage crew | 4–6 astronauts with specialities |
| VAB / Integration | Assemble stages, payloads, and mission configurations | Drag or slot-based vehicle builder |
| Launch Pad | Perform final checks and launch | Countdown, weather/window decision, launch status |
| Administration | Accept contracts and convert success into funding/reputation | Contract board and campaign progression |

The buildings do not need deep simulation in the first build. Each one needs to create a meaningful decision and feed the next phase.

## 5. Minimum crew roster

Start with a small roster so the player learns the system quickly.

| Specialty | Strength | Risk reduced |
| --- | --- | --- |
| Commander / Pilot | Better launch, navigation, and landing decisions | Flight and abort risk |
| Systems Engineer | Better repair and power-management decisions | Equipment and power failures |
| Geologist | Higher science value and better site assessment | Science time and sample quality |
| Medical Officer | Better crew health and EVA endurance | Health and fatigue risk |
| Robotics Specialist | Better rover and habitat deployment | Deployment and mobility risk |

For the first mission, the player chooses two astronauts. A specialist can cover multiple responsibilities, but a crew member should not be equally good at everything.

## 6. Minimum equipment for the Moon MVP

Do not start with dozens of parts. The first mission needs only the following equipment families.

| Equipment | Purpose | Key properties |
| --- | --- | --- |
| Launch vehicle stages | Lift the mission from Earth | Mass capacity, thrust, reliability, fuel cost |
| Guidance and avionics core | Navigation and control | Power draw, reliability, autonomy, failure tolerance |
| Communications package | Sends telemetry and science data | Range, bandwidth, power draw, blackout tolerance |
| Crew capsule | Carries crew during launch and return | Crew capacity, life-support duration, heat-shield safety |
| Service module | Provides power, propulsion, and consumable storage in transit | Delta-v, power generation, propellant, redundancy |
| Lunar lander | Performs lunar orbit descent and ascent | Landing fuel, thrust margin, landing accuracy, reserve fuel |
| Landing guidance / radar | Detects terrain and supports a safe landing | Terrain tolerance, landing-risk reduction, power draw |
| Life-support unit | Manages oxygen, carbon dioxide, water, and temperature | Crew-days, power draw, reliability, spare-filter use |
| EVA suits | Allows astronauts to work outside | EVA hours, oxygen use, mobility, radiation protection |
| Habitat kit | Provides a temporary surface base | Crew-days, power demand, storage, setup time, shelter rating |
| Surface power system | Keeps the habitat and instruments operating | Generation, storage, shadow tolerance, deployment risk |
| Surface communications mast | Maintains a local link from the landing site | Range, bandwidth, antenna alignment, power draw |
| Science instrument package | Produces science data and mission rewards | Mass, power, operation time, data value, specialist bonus |
| Rover | Extends exploration range and carries samples | Range, battery, cargo capacity, terrain ability, reliability |
| Spare-parts kit | Repairs damaged systems | Repair charges, mass, compatibility |

### Equipment that can wait

Leave these for later expansions:

- lunar resource extraction and fuel production;
- orbital refuelling;
- multi-launch assembly;
- relay satellite constellations;
- complex docking and rendezvous;
- radiation storms and detailed thermal modelling;
- multiple habitats and permanent settlements;
- Mars transfer vehicles.

## 7. Resource model

The crafting system should use a small number of readable resource types. The player should understand why an item is expensive without needing a manufacturing spreadsheet.

### Base materials

| Resource | Properties | Main uses |
| --- | --- | --- |
| Structural Metal | Reliable, medium mass, common | Frames, tanks, landing legs, habitat structure |
| Advanced Alloy | Strong and light, expensive, research-gated | Engines, pressure vessels, high-load parts |
| Polymer and Insulation | Light, protects from temperature and abrasion | Suits, habitat shells, cabling, thermal protection |
| Electronics | Compact but expensive and fragile | Computers, sensors, radios, power control |
| Energy Cells | Store electrical energy | Batteries, rovers, landers, emergency power |
| Solar Material | Generates power but needs sunlight | Solar arrays and habitat panels |
| Optical and Science Parts | Specialist components | Cameras, spectrometers, drills, sample analysers |
| Propellant | Mission consumable, not a permanent part | Launch, descent, ascent, manoeuvres |
| Life-support Consumables | Oxygen, water, food, filters | Crew survival and EVA operations |

Funding is a strategic resource and should not be treated as a crafting ingredient. The player spends it on contracts, research, manufacturing, testing, launch services, and recovery.

## 8. Crafting recipes for the first technology tier

The quantities below are intentionally abstract and should be tuned for fun. They are not real engineering bills of materials.

| Item | Ingredients | Important properties |
| --- | --- | --- |
| Avionics Unit | Electronics x2, Structural Metal x1 | 0.5 mass, low power draw, controls one vehicle stage |
| Communications Unit | Electronics x2, Structural Metal x1, Polymer x1 | Range and bandwidth; fails during poor alignment |
| Power Unit | Solar Material x3, Energy Cells x2, Electronics x1 | Generates power and stores emergency charge |
| Engine Unit | Advanced Alloy x3, Structural Metal x2, Electronics x1 | Thrust, efficiency, reliability, propellant use |
| Landing System | Advanced Alloy x2, Structural Metal x3, Electronics x1 | Terrain tolerance, landing accuracy, setup time |
| Life-support Unit | Structural Metal x2, Polymer x2, Electronics x2, Life-support Consumables x2 | Crew-days, power draw, filtration reliability |
| EVA Suit | Polymer x3, Electronics x1, Life-support Consumables x1 | EVA time, oxygen use, mobility, protection |
| Science Instrument | Optical and Science Parts x2, Electronics x2, Structural Metal x1 | Science value, data volume, operation time, power draw |
| Crew Capsule | Structural Metal x5, Advanced Alloy x2, Polymer x3, Avionics Unit x1, Life-support Unit x1 | 2 crew, launch safety, re-entry safety, 3-day endurance |
| Lunar Lander | Structural Metal x6, Advanced Alloy x4, Engine Unit x2, Avionics Unit x1, Landing System x1 | Descent/ascent fuel capacity, thrust margin, landing risk |
| Habitat Kit | Structural Metal x8, Polymer x6, Electronics x4, Power Unit x1, Life-support Unit x1 | 2 crew, 72-hour shelter, storage, setup time |
| Surface Comms Mast | Structural Metal x2, Electronics x3, Polymer x1, Power Unit x1 | Local range, bandwidth, blackout tolerance |
| Rover | Structural Metal x5, Polymer x2, Electronics x3, Energy Cells x2, Power Unit x1 | Exploration range, sample cargo, terrain ability |
| Spare-parts Kit | Structural Metal x2, Electronics x1, Polymer x1 | Repairs a limited number of failures |

### Common properties for every equipment card

Every item should expose the same small set of stats:

- **Mass** — affects launch capacity and fuel cost.
- **Volume** — affects whether it fits in the capsule, lander, or payload bay.
- **Power** — consumed or generated during operation.
- **Reliability** — affects failure probability.
- **Crew support** — how many crew-days or EVA-hours it enables.
- **Data / science value** — how much mission value it creates.
- **Research tier** — when the player can unlock it.
- **Build time and funding cost** — creates schedule and budget trade-offs.
- **Redundancy** — whether a spare or duplicate can cover its failure.

Avoid giving every item unique rules. The shared stats make the trade-offs visible and make balancing much easier.

## 9. Minimum technology tree

Use four short research tiers instead of a huge tree.

### Tier 0 — Foundation

- Basic materials
- Basic electronics
- Chemical propulsion
- Crew training
- Mission planning

### Tier 1 — Orbit

- Staged launch vehicles
- Guidance and telemetry
- Crew capsule
- Solar power and batteries
- Basic life support

### Tier 2 — Lunar flight

- Deep-space communications
- High-efficiency engines
- Lunar landing guidance
- Thermal protection
- EVA suits
- Sample return systems

### Tier 3 — Surface operations

- Deployable habitat
- Surface communications mast
- Long-duration power storage
- Rover
- Advanced science instruments
- Repair and redundancy systems

### Technology that should be optional

Lunar resource utilisation (ISRU) is an excellent later technology because it creates a major strategic choice: pay more to deliver supplies, or invest in extracting water and producing resources locally. It should not be required to complete the first mission.

## 10. How decisions become gameplay

The game needs visible trade-offs at each stage.

### Example trade-offs

- More fuel reserve increases landing safety but reduces payload capacity.
- A second communications path improves reliability but adds mass and power draw.
- A rover increases science potential but may force a smaller habitat or shorter mission.
- A geologist increases sample value but may replace a pilot or engineer.
- More solar panels help during normal operations but do not solve a long shadow period without batteries.
- More testing reduces failure risk but may miss the launch window.
- A lighter material may be expensive or fragile.
- A cheaper engine may work, but a test failure can delay the whole campaign.

The player should be able to inspect these consequences before committing to a design.

## 11. Presentation and scope recommendation

The top-down base is the right management view. Third-person should initially be limited to the moments where physical presence matters:

- lunar surface exploration;
- EVA and habitat deployment;
- rover driving;
- optionally, a short landing sequence.

The full launch and orbital simulation should begin as a readable phase-based simulation. For example, the player makes decisions at ascent, orbit insertion, transit, lunar orbit, descent, and landing. A fully manual rocket-physics mode can be added later if the core game is already fun.

This preserves the inspiration from Kerbal Space Program and Spaceflight Simulator without making the first version depend on building a complete orbital mechanics engine.

## 12. Suggested prototype order

1. Mission brief with one Moon mission.
2. Base view with Mission Control, R&D, Astronaut Complex, VAB, Launch Pad, and Administration.
3. Small technology tree with the four research tiers.
4. Crew selection with five specialties.
5. VAB screen that displays mass, power, cost, reliability, and missing components.
6. Crafting and assembly for the minimum equipment list.
7. Phase-based mission simulation from launch to lunar orbit.
8. Descent and landing decision sequence.
9. Third-person lunar surface loop with habitat deployment, EVA, science, and rover exploration.
10. Return, mission score, funding reward, and one unlocked technology.

The first playable milestone is complete when a player can start with a blank campaign, make a design, launch it, land on the Moon, perform at least one surface operation, and receive an understandable result.

## 13. Decisions to settle next

These choices will affect the next design pass:

1. **Crewed from the beginning or robotic precursor first?**
    - Recommended: make the first playable mission crewed, but offer a cheap robotic survey contract as the tutorial and funding source.
2. **How physical should flight be?**
    - Recommended: phase-based simulation first, with a focused landing interaction and third-person surface play.
3. **How large should the first mission be?**
    - Recommended: two crew, 72 hours, one habitat, one rover optional, three science objectives.
4. **Should players manufacture raw materials?**
    - Recommended: start with contract rewards and processed materials; add mining and refining later as a campaign layer.
