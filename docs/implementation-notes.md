# Chapter 01 implementation notes

Both supplied briefs inform this prototype. Their source text is preserved alongside this document. The research brief has not been revalidated against current NASA program plans and must not be treated as a live reference.

## Decisions

- Native Godot 4 and a procedural 3D assembly view, with a slot-based builder. This gives visible spacecraft assembly without requiring a drag-and-drop structural solver.
- Start with a launch vehicle, crew capsule and service module. The player supplies the lander, habitat, power, communications, science and life-support systems.
- One fixed integrated architecture, three meaningful site variants and five specialists. Architecture comparison and a top-down campus are deferred so the first chapter has a complete design-to-qualification loop.
- Research unlocks optional improved variants; required baseline technologies come with the contract. The player cannot lock themselves out of the tutorial by spending prerequisite research funds.
- The component library offers only unlocked variants by default. Research-locked upgrades require an explicit reveal, and a slot's default always resolves to an installed or unlocked part.
- The interface uses the supplied lime, orange, shadow grey and platinum palette; lime signals primary actions and completed checks, orange signals cost and secondary information.
- Material consumption happens once at integration, and all nine essential systems must pass review. Module build times overlap; integration adds two days.
- A mission reserves enough funds and schedule for remaining tests before it can manufacture. Tests add one reliability point each and cannot be charged twice.
- No fabricated claim of realistic orbital physics: the aggregate velocity check is openly abstract. Surface power is likewise modeled in abstract units because the supplied technical notes mix differently scoped habitat demand figures.
- Generated models are assembly visualizations, with deployed arrays and lander legs visible for inspection. They are not aerodynamically packaged launch configurations.

## Continuation

Chapter 02 is now implemented; see [flight implementation](flight-implementation.md). Launch authorization opens the flight deck with the selected hardware, crew and propulsion budgets. The JSON export remains available.

Future work includes surface operations, return flight, phase-specific consumables, subsystem failures, repair use and return scoring.

## Layout pass

A small layout pass kept the three-column assembly view: part choices at left, spacecraft in the center, and resource checks at right. The module strip now sits directly above the 3D view, so selection precedes inspection. Funds and day are visible in the header on every tab. This follows the central-preview/loadout relationship seen in Cyberpunk 2077 and The Witcher 3, the parts-to-vehicle flow in Kerbal Space Program, and the edge-of-screen progress cues in Assassin's Creed IV: Black Flag. The fonts, colors, control styles, and gameplay rules did not change in this pass.
