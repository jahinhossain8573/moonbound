Based on current NASA Artemis program data and lunar mission studies, here are the key technical parameters and constraints that should inform your Moonbound game design:

## Landing Site Constraints (Lunar South Pole)

NASA has narrowed Artemis III candidate landing regions from 13 to **9 specific sites** near the lunar south pole as of October 2024.  The nine candidate regions are: [ntrs.nasa](https://ntrs.nasa.gov/citations/20250011660)

- Peak near Cabeus B
- Haworth
- Malapert Massif
- Mons Mouton Plateau
- Mons Mouton
- Nobile Rim 1
- Nobile Rim 2
- de Gerlache Rim 2
- Slater Plain [ntrs.nasa](https://ntrs.nasa.gov/citations/20250011660)

**Critical site-selection criteria:**

- **Slope ≤ 5°** over at least 25% of a 2 km-radius exploration zone for safe landing and surface traverses [hou.usra](https://www.hou.usra.edu/meetings/lpsc2024/pdf/1695.pdf)
- **Solar illumination ≥ 33%** of the time during the mission [hou.usra](https://www.hou.usra.edu/meetings/lpsc2024/pdf/1695.pdf)
- **Direct-to-Earth (DTE) visibility ≥ 50%** of the time if using direct communications [hou.usra](https://www.hou.usra.edu/meetings/lpsc2024/pdf/1695.pdf)
- Sites must remain **sunlit for 6–6.5 days** continuously during the entire surface stay [nasa](https://www.nasa.gov/wp-content/uploads/2024/02/15-2024-architecture-workshop-white-paper-lunar-site-selection.pdf)
- Sun elevation never exceeds **~6° above the horizon**, creating extreme shadowing where a 0.5-meter boulder casts a 20-meter shadow [ntrs.nasa](https://ntrs.nasa.gov/api/citations/20220012445/downloads/IAC2022_LunarMissionAvailability_Paper.docx)

This directly validates your game's site-selection phase: players must balance sunlight (power), terrain safety (slope), science value (proximity to permanently shadowed regions), and communication coverage. [ntrs.nasa](https://ntrs.nasa.gov/citations/20250011660)

## Delta-V Budget (Mission Architecture)

For a crewed lunar landing mission, the delta-v requirements are:

| Maneuver | Delta-V (m/s) |
|----------|---------------|
| Trans-Lunar Injection (TLI) from LEO | ~3,200  [americaspace](https://www.americaspace.com/2025/06/09/op-ed-how-nasa-could-still-land-astronauts-on-the-moon-by-2029/) |
| Lunar Orbit Insertion (LOI) | ~900–1,000  [appel.nasa](https://appel.nasa.gov/wp-content/uploads/2013/04/396763main_mf18_connolly.pdf) |
| Descent and Landing (from low lunar orbit) | ~2,000  [appel.nasa](https://appel.nasa.gov/wp-content/uploads/2013/04/396763main_mf18_connolly.pdf) |
| Ascent from lunar surface to orbit | ~1,800–2,000  [en.wikipedia](https://en.wikipedia.org/wiki/Delta-v_budget) |
| Trans-Earth Injection (TEI) | ~900–1,000  [ntrs.nasa](https://ntrs.nasa.gov/citations/20080015975) |
| **Total mission delta-v** | **~8,000–9,000 m/s**  [ntrs.nasa](https://ntrs.nasa.gov/api/citations/19920005861/downloads/19920005861.pdf) |

Your 80 mass-unit launch limit for the first mission is reasonable for a simplified game scale. Real Artemis HLS (Human Landing System) designs require substantial propellant margins for landing safety reserves. [ntrs.nasa](https://ntrs.nasa.gov/citations/20250011660)

## Power Requirements

NASA studies indicate:

- **Crewed habitat power demand: ~20 kW** for 2–4 crew [ntrs.nasa](https://ntrs.nasa.gov/api/citations/20230002896/downloads/Csank_CP_20230002896_CURENT_Knoxville_TN_2023_04_18.pdf)
- **Uncrewed/standby mode: ~2 kW** [ntrs.nasa](https://ntrs.nasa.gov/api/citations/20230002896/downloads/Csank_CP_20230002896_CURENT_Knoxville_TN_2023_04_18.pdf)
- **Life support for 2-person crew adds ~1 kWe** [ntrs.nasa](https://ntrs.nasa.gov/api/citations/20190032521/downloads/20190032521.pdf)
- **EVA operations require additional power** for suit systems and communications [nasa](https://www.nasa.gov/wp-content/uploads/2020/01/topic_1-_eva_lunar_surface_concept_of_operations.pdf)

For your 72-hour, 2-crew mission, a surface power system generating **5–10 kW** with battery storage for eclipse periods would be realistic game stats. Solar arrays must be sized for the low sun angle (~6° max elevation) at the south pole. [ntrs.nasa](https://ntrs.nasa.gov/api/citations/20220012445/downloads/IAC2022_LunarMissionAvailability_Paper.docx)

## Surface Stay Duration & Operations

- **Artemis III planned surface stay: ~6.5 days (156 hours)** [nasa](https://www.nasa.gov/wp-content/uploads/2020/01/topic_1-_eva_lunar_surface_concept_of_operations.pdf)
- Your **72-hour (3-day) tutorial mission** is appropriately scaled down
- **EVA duration limits** depend on suit consumables and radiation exposure
- **Radiation exposure on lunar surface: ~0.5 mSv/day**; career limit is 600 mSv [nasa](https://www.nasa.gov/reference/4-0-human-performance/)
- **Short-term solar particle event limit: 250 mSv** per event [nasa](https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf)

This supports your game's consumable management (oxygen, power, EVA time) and risk mechanics.

## Habitat Mass Constraints

- NASA's lunar surface habitat allowable **landed mass: ~12 metric tons** [ntrs.nasa](https://ntrs.nasa.gov/api/citations/20220013669/downloads/Internal%20Layout%20of%20a%20Lunar%20Surface%20Habitat.pdf)
- Designed to support **2 crew for ~30 days** with power generation and storage [ntrs.nasa](https://ntrs.nasa.gov/api/citations/20220000245/downloads/Artemis%20Deep%20Space%20Habitation%20Enabling%20a%20Sustained%20Human%20Presence%20on%20the%20Moon%20and%20Beyond%20(3).pdf)
- Your simplified habitat kit for 72 hours should be substantially lighter in game terms

## Communications Architecture

- **Direct-to-Earth (DTE)** requires ≥50% Earth visibility from landing site [ntrs.nasa](https://ntrs.nasa.gov/citations/20250011660)
- Low sun angles and polar topography create communication blackouts
- Your communications mast with "range, bandwidth, blackout tolerance" stats directly mirrors real constraints [ntrs.nasa](https://ntrs.nasa.gov/citations/20250011660)

## Technology Recommendations for Moonbound

Based on NASA data, your four-tier tech tree aligns well:

**Tier 0–1 (Foundation/Orbit):** Chemical propulsion, basic life support, solar power [congress](https://www.congress.gov/crs-product/IF11643)

**Tier 2 (Lunar Flight):** Deep-space communications, landing guidance radar, thermal protection, EVA suits [ntrs.nasa](https://ntrs.nasa.gov/citations/20250011660)

**Tier 3 (Surface Operations):** Deployable habitat, surface comms mast, rover, advanced instruments [nasa](https://www.nasa.gov/news-release/nasa-provides-update-on-artemis-iii-moon-landing-regions/)

**Optional later tech:** ISRU (lunar resource extraction) for water ice from permanently shadowed regions—this is a major Artemis goal but not required for early missions. [nasa](https://www.nasa.gov/humans-in-space/nasas-artemis-base-camp-on-the-moon-will-need-light-water-elevation/)

## Game-Balance Numbers (Derived from NASA Data)

For your resource model and crafting:

- **Propellant** should be the dominant mass consumer (descent/ascent require ~2,000 m/s delta-v each) [en.wikipedia](https://en.wikipedia.org/wiki/Delta-v_budget)
- **Solar material** needs 3–5× area at poles vs. equator due to low sun angle [ntrs.nasa](https://ntrs.nasa.gov/api/citations/20220012445/downloads/IAC2022_LunarMissionAvailability_Paper.docx)
- **Advanced alloys** for landing legs and pressure vessels (high-load parts) [smithsonianmag](https://www.smithsonianmag.com/blogs/air-space-museum/2026/09/08/why-are-astronauts-making-daring-flights-through-the-mountains/)
- **Electronics** for avionics, comms, and science instruments (fragile but essential) [ntrs.nasa](https://ntrs.nasa.gov/api/citations/20230002896/downloads/Csank_CP_20230002896_CURENT_Knoxville_TN_2023_04_18.pdf)
- **Spare parts** reduce failure risk—NASA emphasizes redundancy for crew safety [ntrs.nasa](https://ntrs.nasa.gov/citations/20250011660)

Your mission sequence (brief → architecture → site selection → research → crew → design → build → test → launch → transit → landing → surface ops → return → debrief) closely matches actual NASA mission development. [ntrs.nasa](https://ntrs.nasa.gov/citations/20250011660)

Would you like me to pull specific data on any subsystem (life support consumables, rover specifications, science instrument mass/power, or trajectory windows)?
